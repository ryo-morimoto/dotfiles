use crate::operation::Operation;
use crate::policy::{CommandPattern, FilesystemPolicy, NetworkPolicy, Policy, WorktreePolicy};
use serde::{Deserialize, Serialize};
use std::collections::BTreeSet;
use std::path::Path;

#[derive(Debug, Default, Serialize, Deserialize)]
pub struct LearningLog {
    pub reads: BTreeSet<String>,
    pub writes: BTreeSet<String>,
    pub connects: BTreeSet<String>,
    pub binds: BTreeSet<u16>,
    pub commands: Vec<Vec<String>>,
}

impl LearningLog {
    pub fn record(&mut self, op: &Operation) {
        match op {
            Operation::FileRead { path } => {
                self.reads.insert(path.clone());
            }
            Operation::FileWrite { path } | Operation::FileDelete { path } => {
                self.writes.insert(path.clone());
            }
            Operation::NetConnect { host, port } => {
                self.connects.insert(format!("{host}:{port}"));
            }
            Operation::NetBind { port } => {
                self.binds.insert(*port);
            }
            Operation::CommandExec { argv } => {
                if !self.commands.contains(argv) {
                    self.commands.push(argv.clone());
                }
            }
            Operation::ProcessSignal { .. } => {}
        }
    }

    pub fn generate_policy(&self) -> Policy {
        Policy {
            filesystem: FilesystemPolicy {
                read: generalize_paths(&self.reads),
                write: generalize_paths(&self.writes),
            },
            network: NetworkPolicy {
                connect: self.connects.iter().cloned().collect(),
                bind: self.binds.iter().cloned().collect(),
            },
            commands: generalize_commands(&self.commands),
            worktree: WorktreePolicy::default(),
        }
    }

    pub fn save(&self, path: &Path) -> std::io::Result<()> {
        let content = toml::to_string_pretty(self).unwrap_or_default();
        std::fs::write(path, content)
    }

    pub fn load(path: &Path) -> Self {
        std::fs::read_to_string(path)
            .ok()
            .and_then(|s| toml::from_str(&s).ok())
            .unwrap_or_default()
    }
}

fn generalize_paths(paths: &BTreeSet<String>) -> Vec<String> {
    let mut dir_counts: std::collections::HashMap<String, usize> =
        std::collections::HashMap::new();

    for path in paths {
        if let Some(parent) = Path::new(path).parent() {
            let parent_str = parent.to_string_lossy().to_string();
            *dir_counts.entry(parent_str).or_insert(0) += 1;
        }
    }

    let mut patterns: BTreeSet<String> = BTreeSet::new();

    for path in paths {
        if let Some(parent) = Path::new(path).parent() {
            let parent_str = parent.to_string_lossy().to_string();
            let count = dir_counts.get(&parent_str).copied().unwrap_or(0);
            if count >= 3 {
                patterns.insert(format!("{parent_str}/**"));
            } else {
                patterns.insert(path.clone());
            }
        } else {
            patterns.insert(path.clone());
        }
    }

    patterns.into_iter().collect()
}

fn generalize_commands(commands: &[Vec<String>]) -> Vec<CommandPattern> {
    let mut seen_prefixes: std::collections::HashMap<String, Vec<Vec<String>>> =
        std::collections::HashMap::new();

    for argv in commands {
        if let Some(first) = argv.first() {
            seen_prefixes
                .entry(first.clone())
                .or_default()
                .push(argv.clone());
        }
    }

    let mut patterns = Vec::new();
    for (base, usages) in &seen_prefixes {
        if usages.len() >= 3 {
            patterns.push(CommandPattern {
                pattern: vec![base.clone(), "*".into()],
                scope: "learned".into(),
            });
        } else {
            for argv in usages {
                patterns.push(CommandPattern {
                    pattern: argv.clone(),
                    scope: "learned".into(),
                });
            }
        }
    }

    patterns
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn generalize_groups_by_directory() {
        let mut paths = BTreeSet::new();
        paths.insert("./src/a.ts".into());
        paths.insert("./src/b.ts".into());
        paths.insert("./src/c.ts".into());
        paths.insert("./config/db.yaml".into());

        let result = generalize_paths(&paths);
        assert!(result.contains(&"./src/**".to_string()));
        assert!(result.contains(&"./config/db.yaml".to_string()));
        assert!(!result.contains(&"./src/a.ts".to_string()));
    }

    #[test]
    fn generalize_commands_collapses_repeated_base() {
        let commands = vec![
            vec!["npm".into(), "install".into(), "a".into()],
            vec!["npm".into(), "install".into(), "b".into()],
            vec!["npm".into(), "install".into(), "c".into()],
            vec!["git".into(), "status".into()],
        ];

        let result = generalize_commands(&commands);
        let npm_pattern = result.iter().find(|p| p.pattern[0] == "npm").unwrap();
        assert_eq!(npm_pattern.pattern, vec!["npm", "*"]);

        let git_pattern = result.iter().find(|p| p.pattern[0] == "git").unwrap();
        assert_eq!(git_pattern.pattern, vec!["git", "status"]);
    }

    #[test]
    fn two_files_same_dir_not_generalized() {
        let mut paths = BTreeSet::new();
        paths.insert("./src/a.ts".into());
        paths.insert("./src/b.ts".into());
        let result = generalize_paths(&paths);
        assert!(result.contains(&"./src/a.ts".to_string()));
        assert!(result.contains(&"./src/b.ts".to_string()));
        assert!(!result.contains(&"./src/**".to_string()));
    }

    #[test]
    fn exactly_three_files_generalizes() {
        let mut paths = BTreeSet::new();
        paths.insert("./lib/x.ts".into());
        paths.insert("./lib/y.ts".into());
        paths.insert("./lib/z.ts".into());
        let result = generalize_paths(&paths);
        assert_eq!(result, vec!["./lib/**"]);
    }

    #[test]
    fn record_all_operation_types() {
        let mut log = LearningLog::default();
        log.record(&Operation::FileRead { path: "./a".into() });
        log.record(&Operation::FileWrite { path: "./b".into() });
        log.record(&Operation::FileDelete { path: "./c".into() });
        log.record(&Operation::NetConnect { host: "h".into(), port: 80 });
        log.record(&Operation::NetBind { port: 3000 });
        log.record(&Operation::CommandExec { argv: vec!["ls".into()] });
        log.record(&Operation::ProcessSignal { target: "n".into(), signal: 9 });

        assert_eq!(log.reads.len(), 1);
        assert_eq!(log.writes.len(), 2); // FileWrite + FileDelete
        assert_eq!(log.connects.len(), 1);
        assert_eq!(log.binds.len(), 1);
        assert_eq!(log.commands.len(), 1);
    }

    #[test]
    fn record_deduplicates() {
        let mut log = LearningLog::default();
        log.record(&Operation::FileRead { path: "./a".into() });
        log.record(&Operation::FileRead { path: "./a".into() });
        log.record(&Operation::CommandExec { argv: vec!["ls".into()] });
        log.record(&Operation::CommandExec { argv: vec!["ls".into()] });
        assert_eq!(log.reads.len(), 1);
        assert_eq!(log.commands.len(), 1);
    }

    #[test]
    fn generate_policy_includes_network_and_binds() {
        let mut log = LearningLog::default();
        log.record(&Operation::NetConnect { host: "api.com".into(), port: 443 });
        log.record(&Operation::NetBind { port: 8080 });
        let policy = log.generate_policy();
        assert_eq!(policy.network.connect, vec!["api.com:443"]);
        assert_eq!(policy.network.bind, vec![8080]);
    }

    #[test]
    fn save_and_load_roundtrip() {
        let tmp = tempfile::NamedTempFile::new().unwrap();
        let mut log = LearningLog::default();
        log.record(&Operation::FileRead { path: "./x.ts".into() });
        log.record(&Operation::CommandExec { argv: vec!["npm".into(), "test".into()] });
        log.save(tmp.path()).unwrap();

        let loaded = LearningLog::load(tmp.path());
        assert_eq!(loaded.reads.len(), 1);
        assert_eq!(loaded.commands.len(), 1);
    }

    #[test]
    fn two_commands_same_base_not_generalized() {
        let commands = vec![
            vec!["npm".into(), "install".into()],
            vec!["npm".into(), "test".into()],
        ];
        let result = generalize_commands(&commands);
        assert_eq!(result.len(), 2);
        assert!(result.iter().all(|p| p.pattern.len() == 2));
    }
}
