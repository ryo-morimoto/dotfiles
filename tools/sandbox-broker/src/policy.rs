use serde::{Deserialize, Serialize};
use std::path::Path;

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct Policy {
    #[serde(default)]
    pub filesystem: FilesystemPolicy,
    #[serde(default)]
    pub network: NetworkPolicy,
    #[serde(default)]
    pub commands: Vec<CommandPattern>,
    #[serde(default)]
    pub worktree: WorktreePolicy,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct FilesystemPolicy {
    #[serde(default)]
    pub read: Vec<String>,
    #[serde(default)]
    pub write: Vec<String>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct NetworkPolicy {
    #[serde(default)]
    pub connect: Vec<String>,
    #[serde(default)]
    pub bind: Vec<u16>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CommandPattern {
    pub pattern: Vec<String>,
    #[serde(default)]
    pub scope: String,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct WorktreePolicy {
    #[serde(default)]
    pub allow_siblings: bool,
}

impl Policy {
    pub fn load(path: &Path) -> Result<Self, PolicyError> {
        let content = std::fs::read_to_string(path)
            .map_err(|e| PolicyError::Io(path.to_path_buf(), e))?;
        toml::from_str(&content).map_err(PolicyError::Parse)
    }

    pub fn merge(&mut self, other: &Policy) {
        self.filesystem.read.extend(other.filesystem.read.iter().cloned());
        self.filesystem.write.extend(other.filesystem.write.iter().cloned());
        self.network.connect.extend(other.network.connect.iter().cloned());
        self.network.bind.extend(other.network.bind.iter().cloned());
        self.commands.extend(other.commands.iter().cloned());
        if other.worktree.allow_siblings {
            self.worktree.allow_siblings = true;
        }
    }
}

#[derive(Debug)]
pub enum PolicyError {
    Io(std::path::PathBuf, std::io::Error),
    Parse(toml::de::Error),
}

impl std::fmt::Display for PolicyError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Io(path, e) => write!(f, "failed to read {}: {e}", path.display()),
            Self::Parse(e) => write!(f, "invalid policy: {e}"),
        }
    }
}

impl std::error::Error for PolicyError {}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn load_valid_policy() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        std::fs::write(
            tmp.path(),
            r#"
[filesystem]
read = ["./src/**"]
write = ["./src/**", "./tests/**"]

[network]
connect = ["localhost:*"]
bind = [3000]

[[commands]]
pattern = ["npm", "run", "*"]
scope = "scripts"

[worktree]
allow_siblings = true
"#,
        )
        .unwrap();

        let policy = Policy::load(tmp.path()).unwrap();
        assert_eq!(policy.filesystem.read, vec!["./src/**"]);
        assert_eq!(policy.filesystem.write.len(), 2);
        assert_eq!(policy.network.bind, vec![3000]);
        assert_eq!(policy.commands.len(), 1);
        assert!(policy.worktree.allow_siblings);
    }

    #[test]
    fn load_missing_file_errors() {
        let result = Policy::load(std::path::Path::new("/nonexistent/policy.toml"));
        assert!(result.is_err());
    }

    #[test]
    fn load_invalid_toml_errors() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        std::fs::write(tmp.path(), "this is not [valid toml").unwrap();
        let result = Policy::load(tmp.path());
        assert!(result.is_err());
    }

    #[test]
    fn load_empty_file_gives_defaults() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        std::fs::write(tmp.path(), "").unwrap();
        let policy = Policy::load(tmp.path()).unwrap();
        assert!(policy.filesystem.read.is_empty());
        assert!(policy.commands.is_empty());
    }

    #[test]
    fn merge_combines_policies() {
        let mut base = Policy {
            filesystem: FilesystemPolicy {
                read: vec!["./src/**".into()],
                write: vec![],
            },
            ..Default::default()
        };
        let other = Policy {
            filesystem: FilesystemPolicy {
                read: vec!["./lib/**".into()],
                write: vec!["./dist/**".into()],
            },
            network: NetworkPolicy {
                connect: vec!["api.example.com:443".into()],
                bind: vec![8080],
            },
            commands: vec![CommandPattern {
                pattern: vec!["cargo".into(), "build".into()],
                scope: "build".into(),
            }],
            worktree: WorktreePolicy {
                allow_siblings: true,
            },
        };

        base.merge(&other);
        assert_eq!(base.filesystem.read.len(), 2);
        assert_eq!(base.filesystem.write.len(), 1);
        assert_eq!(base.network.connect.len(), 1);
        assert_eq!(base.network.bind, vec![8080]);
        assert_eq!(base.commands.len(), 1);
        assert!(base.worktree.allow_siblings);
    }

    #[test]
    fn default_policy_is_deny_all() {
        let policy = Policy::default();
        assert!(policy.filesystem.read.is_empty());
        assert!(policy.filesystem.write.is_empty());
        assert!(policy.network.connect.is_empty());
        assert!(policy.network.bind.is_empty());
        assert!(policy.commands.is_empty());
        assert!(!policy.worktree.allow_siblings);
    }

    #[test]
    fn policy_error_display() {
        let e = PolicyError::Io(
            std::path::PathBuf::from("/tmp/x.toml"),
            std::io::Error::new(std::io::ErrorKind::NotFound, "not found"),
        );
        assert!(e.to_string().contains("/tmp/x.toml"));
    }
}
