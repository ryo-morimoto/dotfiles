use crate::operation::Operation;
use crate::policy::Policy;

pub struct Matcher<'a> {
    policy: &'a Policy,
}

impl<'a> Matcher<'a> {
    pub fn new(policy: &'a Policy) -> Self {
        Self { policy }
    }

    pub fn check(&self, op: &Operation) -> MatchResult {
        match op {
            Operation::FileRead { path } => self.check_file_read(path),
            Operation::FileWrite { path } | Operation::FileDelete { path } => {
                self.check_file_write(path)
            }
            Operation::NetConnect { host, port } => self.check_net_connect(host, *port),
            Operation::NetBind { port } => self.check_net_bind(*port),
            Operation::CommandExec { argv } => self.check_command(argv),
            Operation::ProcessSignal { .. } => MatchResult::NoMatch,
        }
    }

    fn check_file_read(&self, path: &str) -> MatchResult {
        if self.matches_any(path, &self.policy.filesystem.read)
            || self.matches_any(path, &self.policy.filesystem.write)
        {
            MatchResult::Allow
        } else {
            MatchResult::NoMatch
        }
    }

    fn check_file_write(&self, path: &str) -> MatchResult {
        if self.matches_any(path, &self.policy.filesystem.write) {
            MatchResult::Allow
        } else {
            MatchResult::NoMatch
        }
    }

    fn check_net_connect(&self, host: &str, port: u16) -> MatchResult {
        let target = format!("{host}:{port}");
        for pattern in &self.policy.network.connect {
            if net_pattern_matches(pattern, &target) {
                return MatchResult::Allow;
            }
        }
        MatchResult::NoMatch
    }

    fn check_net_bind(&self, port: u16) -> MatchResult {
        if self.policy.network.bind.contains(&port) {
            MatchResult::Allow
        } else {
            MatchResult::NoMatch
        }
    }

    fn check_command(&self, argv: &[String]) -> MatchResult {
        for cmd_pattern in &self.policy.commands {
            if command_matches(&cmd_pattern.pattern, argv) {
                return MatchResult::Allow;
            }
        }
        MatchResult::NoMatch
    }

    fn matches_any(&self, path: &str, patterns: &[String]) -> bool {
        patterns.iter().any(|p| glob_match::glob_match(p, path))
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MatchResult {
    Allow,
    NoMatch,
}

fn net_pattern_matches(pattern: &str, target: &str) -> bool {
    if pattern.ends_with(":*") {
        let host_pattern = &pattern[..pattern.len() - 2];
        target.starts_with(host_pattern)
            || (host_pattern == "localhost" && target.starts_with("127.0.0.1"))
    } else if pattern.starts_with("*:") {
        let port_pattern = &pattern[2..];
        target.ends_with(&format!(":{port_pattern}"))
    } else {
        glob_match::glob_match(pattern, target)
    }
}

fn command_matches(pattern: &[String], argv: &[String]) -> bool {
    if pattern.len() > argv.len() {
        return false;
    }
    pattern.iter().zip(argv.iter()).all(|(p, a)| {
        p == "*" || glob_match::glob_match(p, a)
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::policy::{CommandPattern, FilesystemPolicy, NetworkPolicy, Policy, WorktreePolicy};

    fn test_policy() -> Policy {
        Policy {
            filesystem: FilesystemPolicy {
                read: vec!["./src/**".into(), "./package.json".into()],
                write: vec!["./src/**".into(), "./tests/**".into()],
            },
            network: NetworkPolicy {
                connect: vec!["localhost:*".into(), "registry.npmjs.org:443".into()],
                bind: vec![3000],
            },
            commands: vec![
                CommandPattern {
                    pattern: vec!["npm".into(), "install".into(), "*".into()],
                    scope: "deps".into(),
                },
                CommandPattern {
                    pattern: vec!["git".into(), "add".into(), "*".into()],
                    scope: "vcs".into(),
                },
            ],
            worktree: WorktreePolicy::default(),
        }
    }

    #[test]
    fn file_read_allowed() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::FileRead { path: "./src/main.ts".into() }),
            MatchResult::Allow
        );
    }

    #[test]
    fn file_read_denied() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::FileRead { path: "./.env".into() }),
            MatchResult::NoMatch
        );
    }

    #[test]
    fn file_write_allowed() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::FileWrite { path: "./tests/app.test.ts".into() }),
            MatchResult::Allow
        );
    }

    #[test]
    fn file_write_outside_policy() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::FileWrite { path: "./config/db.yaml".into() }),
            MatchResult::NoMatch
        );
    }

    #[test]
    fn net_connect_localhost() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::NetConnect { host: "localhost".into(), port: 8080 }),
            MatchResult::Allow
        );
    }

    #[test]
    fn net_connect_unknown_host() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::NetConnect { host: "evil.com".into(), port: 443 }),
            MatchResult::NoMatch
        );
    }

    #[test]
    fn command_allowed() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::CommandExec {
                argv: vec!["npm".into(), "install".into(), "lodash".into()]
            }),
            MatchResult::Allow
        );
    }

    #[test]
    fn command_not_allowed() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::CommandExec {
                argv: vec!["rm".into(), "-rf".into(), "/".into()]
            }),
            MatchResult::NoMatch
        );
    }

    #[test]
    fn net_bind_allowed() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::NetBind { port: 3000 }),
            MatchResult::Allow
        );
    }

    #[test]
    fn net_bind_denied() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::NetBind { port: 8080 }),
            MatchResult::NoMatch
        );
    }

    #[test]
    fn net_connect_specific_host_port() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::NetConnect {
                host: "registry.npmjs.org".into(),
                port: 443
            }),
            MatchResult::Allow
        );
    }

    #[test]
    fn net_connect_specific_host_wrong_port() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::NetConnect {
                host: "registry.npmjs.org".into(),
                port: 80
            }),
            MatchResult::NoMatch
        );
    }

    #[test]
    fn process_signal_always_no_match() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::ProcessSignal {
                target: "node".into(),
                signal: 15
            }),
            MatchResult::NoMatch
        );
    }

    #[test]
    fn file_read_allowed_from_write_patterns() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::FileRead {
                path: "./tests/app.test.ts".into()
            }),
            MatchResult::Allow
        );
    }

    #[test]
    fn file_delete_uses_write_patterns() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::FileDelete {
                path: "./src/old.ts".into()
            }),
            MatchResult::Allow
        );
        assert_eq!(
            m.check(&Operation::FileDelete {
                path: "./config/x.yaml".into()
            }),
            MatchResult::NoMatch
        );
    }

    #[test]
    fn command_shorter_argv_than_pattern() {
        let policy = test_policy();
        let m = Matcher::new(&policy);
        assert_eq!(
            m.check(&Operation::CommandExec {
                argv: vec!["npm".into()]
            }),
            MatchResult::NoMatch
        );
    }
}
