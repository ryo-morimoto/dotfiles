use crate::learning::LearningLog;
use crate::matcher::{MatchResult, Matcher};
use crate::operation::Operation;
use crate::policy::Policy;
use crate::session::{CircuitBreakerState, Session};
use crate::subagent::{self, SubAgentConfig};
use crate::verdict::{Outcome, Risk, Source, Verdict};
use std::path::{Path, PathBuf};
use std::sync::Mutex;

pub struct Broker {
    policy: Policy,
    session: Mutex<Session>,
    session_path: PathBuf,
    learning: Mutex<Option<LearningLog>>,
    learning_path: PathBuf,
    subagent_config: Option<SubAgentConfig>,
    project_context: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Mode {
    Enforce,
    Learning,
}

impl Broker {
    pub fn new(policy: Policy, sandbox_dir: &Path, mode: Mode) -> Self {
        let session_path = sandbox_dir.join("session.toml");
        let learning_path = sandbox_dir.join("learned.toml");
        let session = Session::load(&session_path);

        let learning = match mode {
            Mode::Learning => Some(LearningLog::load(&learning_path)),
            Mode::Enforce => None,
        };

        let subagent_config = SubAgentConfig::from_env();

        Self {
            policy,
            session: Mutex::new(session),
            session_path,
            learning: Mutex::new(learning),
            learning_path,
            subagent_config,
            project_context: String::new(),
        }
    }

    pub fn set_project_context(&mut self, ctx: String) {
        self.project_context = ctx;
    }

    pub fn is_learning(&self) -> bool {
        self.learning.lock().unwrap().is_some()
    }

    pub fn evaluate(&self, op: &Operation) -> Verdict {
        if let Some(ref mut log) = *self.learning.lock().unwrap() {
            log.record(op);
            let _ = log.save(&self.learning_path);
            return Verdict::allow(Source::PolicyMatch);
        }

        if let Some(v) = self.check_policy(op) {
            return v;
        }

        if let Some(v) = self.check_session(op) {
            return v;
        }

        if let Some(v) = self.programmatic_check(op) {
            return v;
        }

        Verdict {
            outcome: Outcome::Escalate,
            source: Source::ProgrammaticCheck,
            risk: Risk::Medium,
            rationale: format!("no policy match for {} {}", op.kind_str(), op.target()),
            persistence: None,
        }
    }

    pub async fn evaluate_with_subagent(&self, op: &Operation) -> Verdict {
        let initial = self.evaluate(op);
        if initial.outcome != Outcome::Escalate {
            return initial;
        }

        match &self.subagent_config {
            Some(config) if !config.api_key.is_empty() => {
                match subagent::evaluate(config, op, &self.project_context).await {
                    Ok(verdict) => {
                        if verdict.outcome == Outcome::Allow {
                            self.record_grant(op, Source::SubAgent, verdict.persistence.is_some());
                        }
                        verdict
                    }
                    Err(e) => {
                        tracing::warn!("sub-agent failed: {e}, denying (fail-closed)");
                        Verdict {
                            outcome: Outcome::Deny,
                            source: Source::SubAgent,
                            risk: Risk::Medium,
                            rationale: format!("sub-agent unavailable: {e}"),
                            persistence: None,
                        }
                    }
                }
            }
            _ => Verdict {
                outcome: Outcome::Escalate,
                source: Source::SubAgent,
                risk: Risk::Medium,
                rationale: "no sub-agent configured, requires human approval".into(),
                persistence: None,
            },
        }
    }

    pub fn record_grant(&self, op: &Operation, source: Source, persist_suggested: bool) {
        let mut session = self.session.lock().unwrap();
        session.grant(op, source, persist_suggested);
        let _ = session.save(&self.session_path);
    }

    pub fn record_denial(&self) -> CircuitBreakerState {
        let mut session = self.session.lock().unwrap();
        let state = session.record_denial();
        let _ = session.save(&self.session_path);
        state
    }

    pub fn pending_persistence(&self) -> Vec<crate::session::Grant> {
        let session = self.session.lock().unwrap();
        session.pending_persistence().into_iter().cloned().collect()
    }

    pub fn finalize_learning(&self) -> Option<Policy> {
        let log = self.learning.lock().unwrap();
        log.as_ref().map(|l| l.generate_policy())
    }

    fn check_policy(&self, op: &Operation) -> Option<Verdict> {
        let matcher = Matcher::new(&self.policy);
        match matcher.check(op) {
            MatchResult::Allow => Some(Verdict::allow(Source::PolicyMatch)),
            MatchResult::NoMatch => None,
        }
    }

    fn check_session(&self, op: &Operation) -> Option<Verdict> {
        let session = self.session.lock().unwrap();
        if session.matches(op) {
            Some(Verdict::allow(Source::SessionMatch))
        } else {
            None
        }
    }

    fn programmatic_check(&self, op: &Operation) -> Option<Verdict> {
        match op {
            Operation::FileWrite { path } | Operation::FileDelete { path }
                if path.contains("/.") && !path.contains("/.sandbox/") =>
            {
                Some(Verdict {
                    outcome: Outcome::Escalate,
                    source: Source::ProgrammaticCheck,
                    risk: Risk::Medium,
                    rationale: "write to hidden file".into(),
                    persistence: None,
                })
            }
            Operation::FileRead { path } if self.policy.worktree.allow_siblings => {
                if path.contains("-wt/") {
                    Some(Verdict::allow(Source::ProgrammaticCheck))
                } else {
                    None
                }
            }
            _ => None,
        }
    }
}
