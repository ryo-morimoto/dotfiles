use serde::{Deserialize, Serialize};
use std::fmt;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Outcome {
    Allow,
    Deny,
    Escalate,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Risk {
    Low,
    Medium,
    High,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Source {
    PolicyMatch,
    SessionMatch,
    ProgrammaticCheck,
    SubAgent,
    Human,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PersistenceProposal {
    pub pattern: String,
    pub category: PolicyCategory,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum PolicyCategory {
    FilesystemRead,
    FilesystemWrite,
    Network,
    Command,
}

impl fmt::Display for PolicyCategory {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::FilesystemRead => write!(f, "fs:read"),
            Self::FilesystemWrite => write!(f, "fs:write"),
            Self::Network => write!(f, "network"),
            Self::Command => write!(f, "command"),
        }
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Verdict {
    pub outcome: Outcome,
    pub source: Source,
    pub risk: Risk,
    pub rationale: String,
    pub persistence: Option<PersistenceProposal>,
}

impl Verdict {
    pub fn allow(source: Source) -> Self {
        Self {
            outcome: Outcome::Allow,
            source,
            risk: Risk::Low,
            rationale: String::new(),
            persistence: None,
        }
    }

    pub fn deny(source: Source, rationale: impl Into<String>) -> Self {
        Self {
            outcome: Outcome::Deny,
            source,
            risk: Risk::High,
            rationale: rationale.into(),
            persistence: None,
        }
    }
}
