use crate::policy::Policy;
use crate::session::Grant;
use crate::verdict::PolicyCategory;
use std::path::Path;

pub fn promote_grants(policy_path: &Path, grants: &[Grant]) -> Result<(), PersistError> {
    let mut policy = if policy_path.exists() {
        Policy::load(policy_path).map_err(|e| PersistError::Load(e.to_string()))?
    } else {
        Policy::default()
    };

    for grant in grants {
        match grant.category {
            PolicyCategory::FilesystemRead => {
                if !policy.filesystem.read.contains(&grant.pattern) {
                    policy.filesystem.read.push(grant.pattern.clone());
                }
            }
            PolicyCategory::FilesystemWrite => {
                if !policy.filesystem.write.contains(&grant.pattern) {
                    policy.filesystem.write.push(grant.pattern.clone());
                }
            }
            PolicyCategory::Network => {
                if !policy.network.connect.contains(&grant.pattern) {
                    policy.network.connect.push(grant.pattern.clone());
                }
            }
            PolicyCategory::Command => {
                let parts: Vec<String> = grant.pattern.split(' ').map(|s| s.to_string()).collect();
                let already_exists = policy
                    .commands
                    .iter()
                    .any(|c| c.pattern == parts);
                if !already_exists {
                    policy.commands.push(crate::policy::CommandPattern {
                        pattern: parts,
                        scope: "session-promoted".into(),
                    });
                }
            }
        }
    }

    let content = toml::to_string_pretty(&policy).map_err(|e| PersistError::Serialize(e.to_string()))?;
    std::fs::write(policy_path, content).map_err(|e| PersistError::Write(e.to_string()))?;

    Ok(())
}

#[derive(Debug)]
pub enum PersistError {
    Load(String),
    Serialize(String),
    Write(String),
}

impl std::fmt::Display for PersistError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Load(e) => write!(f, "load: {e}"),
            Self::Serialize(e) => write!(f, "serialize: {e}"),
            Self::Write(e) => write!(f, "write: {e}"),
        }
    }
}

impl std::error::Error for PersistError {}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::verdict::{PolicyCategory, Source};

    #[test]
    fn promote_creates_new_policy_file() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        let path = tmp.path().to_path_buf();
        std::fs::remove_file(&path).ok();

        let grants = vec![Grant {
            pattern: "./lib/**".into(),
            category: PolicyCategory::FilesystemRead,
            source: Source::Human,
            persist_suggested: true,
        }];

        promote_grants(&path, &grants).unwrap();
        let policy = Policy::load(&path).unwrap();
        assert!(policy.filesystem.read.contains(&"./lib/**".to_string()));
    }

    #[test]
    fn promote_appends_to_existing() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        std::fs::write(
            tmp.path(),
            "[filesystem]\nread = [\"./src/**\"]\nwrite = []\n[network]\nconnect = []\nbind = []\n",
        )
        .unwrap();

        let grants = vec![Grant {
            pattern: "./docs/**".into(),
            category: PolicyCategory::FilesystemRead,
            source: Source::Human,
            persist_suggested: true,
        }];

        promote_grants(tmp.path(), &grants).unwrap();
        let policy = Policy::load(tmp.path()).unwrap();
        assert!(policy.filesystem.read.contains(&"./src/**".to_string()));
        assert!(policy.filesystem.read.contains(&"./docs/**".to_string()));
    }

    #[test]
    fn promote_deduplicates() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        std::fs::write(
            tmp.path(),
            "[filesystem]\nread = [\"./src/**\"]\nwrite = []\n[network]\nconnect = []\nbind = []\n",
        )
        .unwrap();

        let grants = vec![Grant {
            pattern: "./src/**".into(),
            category: PolicyCategory::FilesystemRead,
            source: Source::Human,
            persist_suggested: true,
        }];

        promote_grants(tmp.path(), &grants).unwrap();
        let policy = Policy::load(tmp.path()).unwrap();
        assert_eq!(
            policy.filesystem.read.iter().filter(|r| *r == "./src/**").count(),
            1
        );
    }

    #[test]
    fn promote_command_pattern() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        std::fs::remove_file(tmp.path()).ok();

        let grants = vec![Grant {
            pattern: "npm run build".into(),
            category: PolicyCategory::Command,
            source: Source::Human,
            persist_suggested: true,
        }];

        promote_grants(tmp.path(), &grants).unwrap();
        let policy = Policy::load(tmp.path()).unwrap();
        assert_eq!(policy.commands.len(), 1);
        assert_eq!(policy.commands[0].pattern, vec!["npm", "run", "build"]);
    }

    #[test]
    fn promote_network_grant() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        std::fs::remove_file(tmp.path()).ok();

        let grants = vec![Grant {
            pattern: "api.example.com:443".into(),
            category: PolicyCategory::Network,
            source: Source::SubAgent,
            persist_suggested: true,
        }];

        promote_grants(tmp.path(), &grants).unwrap();
        let policy = Policy::load(tmp.path()).unwrap();
        assert!(policy.network.connect.contains(&"api.example.com:443".to_string()));
    }

    #[test]
    fn promote_multiple_categories() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        std::fs::remove_file(tmp.path()).ok();

        let grants = vec![
            Grant {
                pattern: "./docs/**".into(),
                category: PolicyCategory::FilesystemRead,
                source: Source::Human,
                persist_suggested: true,
            },
            Grant {
                pattern: "./dist/**".into(),
                category: PolicyCategory::FilesystemWrite,
                source: Source::Human,
                persist_suggested: true,
            },
            Grant {
                pattern: "cdn.example.com:443".into(),
                category: PolicyCategory::Network,
                source: Source::Human,
                persist_suggested: true,
            },
        ];

        promote_grants(tmp.path(), &grants).unwrap();
        let policy = Policy::load(tmp.path()).unwrap();
        assert_eq!(policy.filesystem.read.len(), 1);
        assert_eq!(policy.filesystem.write.len(), 1);
        assert_eq!(policy.network.connect.len(), 1);
    }
}

