use crate::operation::Operation;
use crate::verdict::{PersistenceProposal, PolicyCategory, Risk, Verdict, Outcome, Source};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone)]
pub struct SubAgentConfig {
    pub api_key: String,
    pub model: String,
    pub base_url: String,
    pub timeout_secs: u64,
}

impl Default for SubAgentConfig {
    fn default() -> Self {
        Self {
            api_key: String::new(),
            model: "claude-haiku-4-5-20251001".into(),
            base_url: "https://api.anthropic.com".into(),
            timeout_secs: 5,
        }
    }
}

impl SubAgentConfig {
    pub fn from_env() -> Option<Self> {
        let api_key = std::env::var("ANTHROPIC_API_KEY").ok()?;
        Some(Self {
            api_key,
            model: std::env::var("SANDBOX_SUBAGENT_MODEL")
                .unwrap_or_else(|_| "claude-haiku-4-5-20251001".into()),
            base_url: std::env::var("ANTHROPIC_BASE_URL")
                .unwrap_or_else(|_| "https://api.anthropic.com".into()),
            timeout_secs: 5,
        })
    }
}

#[derive(Debug, Serialize)]
struct ApiRequest {
    model: String,
    max_tokens: u32,
    system: String,
    messages: Vec<Message>,
}

#[derive(Debug, Serialize)]
struct Message {
    role: String,
    content: String,
}

#[derive(Debug, Deserialize)]
struct ApiResponse {
    content: Vec<ContentBlock>,
}

#[derive(Debug, Deserialize)]
struct ContentBlock {
    text: Option<String>,
}

#[derive(Debug, Deserialize)]
struct SubAgentVerdict {
    outcome: String,
    risk: String,
    rationale: String,
    suggest_persist: bool,
    pattern: Option<String>,
}

pub async fn evaluate(
    config: &SubAgentConfig,
    op: &Operation,
    project_context: &str,
) -> Result<Verdict, SubAgentError> {
    let client = reqwest::Client::builder()
        .timeout(std::time::Duration::from_secs(config.timeout_secs))
        .build()
        .map_err(|e| SubAgentError::Network(e.to_string()))?;

    let prompt = build_prompt(op, project_context);

    let request = ApiRequest {
        model: config.model.clone(),
        max_tokens: 256,
        system: SYSTEM_PROMPT.into(),
        messages: vec![Message {
            role: "user".into(),
            content: prompt,
        }],
    };

    let response = client
        .post(format!("{}/v1/messages", config.base_url))
        .header("x-api-key", &config.api_key)
        .header("anthropic-version", "2023-06-01")
        .header("content-type", "application/json")
        .json(&request)
        .send()
        .await
        .map_err(|e| SubAgentError::Network(e.to_string()))?;

    if !response.status().is_success() {
        let status = response.status().as_u16();
        let body = response.text().await.unwrap_or_default();
        return Err(SubAgentError::Api(status, body));
    }

    let api_response: ApiResponse = response
        .json()
        .await
        .map_err(|e| SubAgentError::Parse(e.to_string()))?;

    let text = api_response
        .content
        .first()
        .and_then(|b| b.text.as_deref())
        .ok_or_else(|| SubAgentError::Parse("empty response".into()))?;

    parse_verdict(text, op)
}

fn build_prompt(op: &Operation, project_context: &str) -> String {
    format!(
        "Evaluate this operation for safety.\n\n\
         Operation: {} {}\n\
         Project context: {}\n\n\
         Respond with JSON only:\n\
         {{\"outcome\": \"allow\"|\"deny\", \"risk\": \"low\"|\"medium\"|\"high\", \
         \"rationale\": \"one line\", \"suggest_persist\": bool, \"pattern\": \"glob or null\"}}",
        op.kind_str(),
        op.target(),
        project_context
    )
}

fn parse_verdict(text: &str, op: &Operation) -> Result<Verdict, SubAgentError> {
    let json_start = text.find('{').ok_or_else(|| SubAgentError::Parse("no JSON found".into()))?;
    let json_end = text.rfind('}').ok_or_else(|| SubAgentError::Parse("no JSON end".into()))?;
    let json_str = &text[json_start..=json_end];

    let v: SubAgentVerdict =
        serde_json::from_str(json_str).map_err(|e| SubAgentError::Parse(e.to_string()))?;

    let outcome = match v.outcome.as_str() {
        "allow" => Outcome::Allow,
        _ => Outcome::Deny,
    };

    let risk = match v.risk.as_str() {
        "low" => Risk::Low,
        "medium" => Risk::Medium,
        _ => Risk::High,
    };

    let persistence = if v.suggest_persist {
        let category = match op {
            Operation::FileRead { .. } => PolicyCategory::FilesystemRead,
            Operation::FileWrite { .. } | Operation::FileDelete { .. } => {
                PolicyCategory::FilesystemWrite
            }
            Operation::NetConnect { .. } | Operation::NetBind { .. } => PolicyCategory::Network,
            Operation::CommandExec { .. } | Operation::ProcessSignal { .. } => {
                PolicyCategory::Command
            }
        };
        Some(PersistenceProposal {
            pattern: v.pattern.unwrap_or_else(|| op.target()),
            category,
        })
    } else {
        None
    };

    Ok(Verdict {
        outcome,
        source: Source::SubAgent,
        risk,
        rationale: v.rationale,
        persistence,
    })
}

const SYSTEM_PROMPT: &str = "\
You are a sandbox permission evaluator for an AI coding agent. \
Your job is to decide whether a filesystem, network, or command operation is safe. \
Consider: Is the target within expected project scope? Could this exfiltrate data? \
Could this cause damage outside the project? Is this a normal development operation? \
Respond ONLY with a JSON object, no other text.";

#[derive(Debug)]
pub enum SubAgentError {
    Network(String),
    Api(u16, String),
    Parse(String),
}

impl std::fmt::Display for SubAgentError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Network(e) => write!(f, "network error: {e}"),
            Self::Api(status, body) => write!(f, "API error {status}: {body}"),
            Self::Parse(e) => write!(f, "parse error: {e}"),
        }
    }
}

impl std::error::Error for SubAgentError {}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::operation::Operation;

    #[test]
    fn parse_allow_verdict() {
        let json = r#"{"outcome": "allow", "risk": "low", "rationale": "normal dev read", "suggest_persist": true, "pattern": "./src/**"}"#;
        let op = Operation::FileRead {
            path: "./src/main.ts".into(),
        };
        let v = parse_verdict(json, &op).unwrap();
        assert_eq!(v.outcome, Outcome::Allow);
        assert_eq!(v.risk, Risk::Low);
        assert_eq!(v.source, Source::SubAgent);
        assert!(v.persistence.is_some());
        assert_eq!(v.persistence.unwrap().pattern, "./src/**");
    }

    #[test]
    fn parse_deny_verdict() {
        let json = r#"{"outcome": "deny", "risk": "high", "rationale": "dangerous command", "suggest_persist": false, "pattern": null}"#;
        let op = Operation::CommandExec {
            argv: vec!["rm".into(), "-rf".into(), "/".into()],
        };
        let v = parse_verdict(json, &op).unwrap();
        assert_eq!(v.outcome, Outcome::Deny);
        assert_eq!(v.risk, Risk::High);
        assert!(v.persistence.is_none());
    }

    #[test]
    fn parse_verdict_with_surrounding_text() {
        let text = "Here is my analysis:\n{\"outcome\": \"allow\", \"risk\": \"medium\", \"rationale\": \"ok\", \"suggest_persist\": false, \"pattern\": null}\nEnd.";
        let op = Operation::FileRead {
            path: "./readme.md".into(),
        };
        let v = parse_verdict(text, &op).unwrap();
        assert_eq!(v.outcome, Outcome::Allow);
    }

    #[test]
    fn parse_verdict_no_json() {
        let text = "I cannot evaluate this.";
        let op = Operation::FileRead {
            path: "./a.ts".into(),
        };
        assert!(parse_verdict(text, &op).is_err());
    }

    #[test]
    fn parse_verdict_invalid_json() {
        let text = "{not valid json}";
        let op = Operation::FileRead {
            path: "./a.ts".into(),
        };
        assert!(parse_verdict(text, &op).is_err());
    }

    #[test]
    fn parse_verdict_persist_uses_target_when_no_pattern() {
        let json = r#"{"outcome": "allow", "risk": "low", "rationale": "ok", "suggest_persist": true, "pattern": null}"#;
        let op = Operation::FileWrite {
            path: "./config/db.yaml".into(),
        };
        let v = parse_verdict(json, &op).unwrap();
        let p = v.persistence.unwrap();
        assert_eq!(p.pattern, "./config/db.yaml");
        assert_eq!(p.category, PolicyCategory::FilesystemWrite);
    }

    #[test]
    fn parse_verdict_network_category() {
        let json = r#"{"outcome": "allow", "risk": "low", "rationale": "ok", "suggest_persist": true, "pattern": "api.example.com:443"}"#;
        let op = Operation::NetConnect {
            host: "api.example.com".into(),
            port: 443,
        };
        let v = parse_verdict(json, &op).unwrap();
        assert_eq!(v.persistence.unwrap().category, PolicyCategory::Network);
    }

    #[test]
    fn parse_verdict_command_category() {
        let json = r#"{"outcome": "allow", "risk": "low", "rationale": "ok", "suggest_persist": true, "pattern": "cargo build"}"#;
        let op = Operation::CommandExec {
            argv: vec!["cargo".into(), "build".into()],
        };
        let v = parse_verdict(json, &op).unwrap();
        assert_eq!(v.persistence.unwrap().category, PolicyCategory::Command);
    }

    #[test]
    fn build_prompt_contains_operation_info() {
        let op = Operation::FileRead {
            path: "./src/main.ts".into(),
        };
        let prompt = build_prompt(&op, "web app project");
        assert!(prompt.contains("file_read"));
        assert!(prompt.contains("./src/main.ts"));
        assert!(prompt.contains("web app project"));
    }
}
