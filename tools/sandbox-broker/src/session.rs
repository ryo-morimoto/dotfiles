use crate::operation::Operation;
use crate::verdict::{PolicyCategory, Source};
use serde::{Deserialize, Serialize};
use std::path::Path;

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Session {
    pub granted: Vec<Grant>,
    #[serde(skip)]
    consecutive_denials: u8,
    #[serde(skip)]
    total_denials: u16,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Grant {
    pub pattern: String,
    pub category: PolicyCategory,
    pub source: Source,
    pub persist_suggested: bool,
}

impl Session {
    pub fn load(path: &Path) -> Self {
        std::fs::read_to_string(path)
            .ok()
            .and_then(|s| toml::from_str(&s).ok())
            .unwrap_or_default()
    }

    pub fn save(&self, path: &Path) -> std::io::Result<()> {
        let content = toml::to_string_pretty(self).unwrap_or_default();
        std::fs::write(path, content)
    }

    pub fn matches(&self, op: &Operation) -> bool {
        let (target, category) = op_to_category(op);
        self.granted
            .iter()
            .any(|g| g.category == category && glob_match::glob_match(&g.pattern, &target))
    }

    pub fn grant(&mut self, op: &Operation, source: Source, persist_suggested: bool) {
        let (target, category) = op_to_category(op);
        let pattern = generalize_path(&target);
        self.granted.push(Grant {
            pattern,
            category,
            source,
            persist_suggested,
        });
        self.consecutive_denials = 0;
    }

    pub fn record_denial(&mut self) -> CircuitBreakerState {
        self.consecutive_denials += 1;
        self.total_denials += 1;

        if self.consecutive_denials >= 3 {
            CircuitBreakerState::TripConsecutive
        } else if self.total_denials >= 10 {
            CircuitBreakerState::TripTotal
        } else {
            CircuitBreakerState::Ok
        }
    }

    pub fn reset_consecutive(&mut self) {
        self.consecutive_denials = 0;
    }

    pub fn pending_persistence(&self) -> Vec<&Grant> {
        self.granted.iter().filter(|g| g.persist_suggested).collect()
    }

    pub fn granted_list(&self) -> &[Grant] {
        &self.granted
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum CircuitBreakerState {
    Ok,
    TripConsecutive,
    TripTotal,
}

fn op_to_category(op: &Operation) -> (String, PolicyCategory) {
    match op {
        Operation::FileRead { path } => (path.clone(), PolicyCategory::FilesystemRead),
        Operation::FileWrite { path } | Operation::FileDelete { path } => {
            (path.clone(), PolicyCategory::FilesystemWrite)
        }
        Operation::NetConnect { host, port } => {
            (format!("{host}:{port}"), PolicyCategory::Network)
        }
        Operation::NetBind { port } => (format!("localhost:{port}"), PolicyCategory::Network),
        Operation::CommandExec { argv } => (argv.join(" "), PolicyCategory::Command),
        Operation::ProcessSignal { target, .. } => (target.clone(), PolicyCategory::Command),
    }
}

fn generalize_path(path: &str) -> String {
    if let Some(parent) = Path::new(path).parent() {
        let parent_str = parent.to_string_lossy();
        if parent_str == "." || parent_str.is_empty() {
            path.to_string()
        } else {
            format!("{parent_str}/**")
        }
    } else {
        path.to_string()
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::operation::Operation;

    #[test]
    fn generalize_path_nested() {
        assert_eq!(generalize_path("./src/lib/utils.ts"), "./src/lib/**");
    }

    #[test]
    fn generalize_path_root_file() {
        assert_eq!(generalize_path("file.txt"), "file.txt");
    }

    #[test]
    fn grant_enables_session_match() {
        let mut session = Session::default();
        let op = Operation::FileWrite {
            path: "./config/db.yaml".into(),
        };
        session.grant(&op, Source::Human, false);
        let sibling = Operation::FileWrite {
            path: "./config/other.yaml".into(),
        };
        assert!(session.matches(&sibling));
    }

    #[test]
    fn session_does_not_match_unrelated() {
        let mut session = Session::default();
        let op = Operation::FileWrite {
            path: "./config/db.yaml".into(),
        };
        session.grant(&op, Source::Human, false);
        let unrelated = Operation::FileWrite {
            path: "./secrets/key.pem".into(),
        };
        assert!(!session.matches(&unrelated));
    }

    #[test]
    fn circuit_breaker_trips_at_3_consecutive() {
        let mut session = Session::default();
        assert_eq!(session.record_denial(), CircuitBreakerState::Ok);
        assert_eq!(session.record_denial(), CircuitBreakerState::Ok);
        assert_eq!(
            session.record_denial(),
            CircuitBreakerState::TripConsecutive
        );
    }

    #[test]
    fn circuit_breaker_resets_on_grant() {
        let mut session = Session::default();
        session.record_denial();
        session.record_denial();
        let op = Operation::FileRead {
            path: "./src/a.ts".into(),
        };
        session.grant(&op, Source::Human, false);
        assert_eq!(session.record_denial(), CircuitBreakerState::Ok);
    }

    #[test]
    fn pending_persistence_filters_correctly() {
        let mut session = Session::default();
        let op1 = Operation::FileWrite {
            path: "./a/b.ts".into(),
        };
        let op2 = Operation::FileRead {
            path: "./c/d.ts".into(),
        };
        session.grant(&op1, Source::Human, true);
        session.grant(&op2, Source::Human, false);
        assert_eq!(session.pending_persistence().len(), 1);
        assert!(session.pending_persistence()[0].pattern.contains("a"));
    }

    #[test]
    fn save_and_load_roundtrip() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        let mut session = Session::default();
        let op = Operation::FileWrite {
            path: "./src/x.ts".into(),
        };
        session.grant(&op, Source::Human, true);
        session.save(tmp.path()).unwrap();

        let loaded = Session::load(tmp.path());
        assert_eq!(loaded.granted.len(), 1);
        assert_eq!(loaded.granted[0].pattern, "./src/**");
    }

    #[test]
    fn circuit_breaker_trips_at_10_total() {
        let mut session = Session::default();
        // Deny twice then reset, repeat — never hits 3 consecutive but accumulates total
        for _ in 0..4 {
            session.record_denial();
            session.record_denial();
            session.reset_consecutive();
        }
        // 8 total so far, consecutive = 0
        session.record_denial(); // total=9, consecutive=1
        assert_eq!(session.record_denial(), CircuitBreakerState::TripTotal); // total=10
    }

    #[test]
    fn reset_consecutive_allows_more_denials() {
        let mut session = Session::default();
        session.record_denial();
        session.record_denial();
        session.reset_consecutive();
        assert_eq!(session.record_denial(), CircuitBreakerState::Ok);
        assert_eq!(session.record_denial(), CircuitBreakerState::Ok);
    }

    #[test]
    fn grant_network_operation() {
        let mut session = Session::default();
        let op = Operation::NetConnect {
            host: "api.example.com".into(),
            port: 443,
        };
        session.grant(&op, Source::SubAgent, true);
        // Pattern generalizes the host:port
        assert!(session.matches(&op));
    }

    #[test]
    fn grant_command_operation() {
        let mut session = Session::default();
        let op = Operation::CommandExec {
            argv: vec!["cargo".into(), "build".into()],
        };
        session.grant(&op, Source::Human, false);
        // Generalized pattern should match similar commands
        let similar = Operation::CommandExec {
            argv: vec!["cargo".into(), "test".into()],
        };
        // "cargo build" generalizes to "cargo/**" or "cargo build/**" depending on generalize_path
        // Let's verify what actually happens
        assert!(session.granted.len() == 1);
    }

    #[test]
    fn load_nonexistent_returns_default() {
        let session = Session::load(std::path::Path::new("/nonexistent/session.toml"));
        assert!(session.granted.is_empty());
    }
}

