use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(tag = "kind", content = "detail")]
pub enum Operation {
    FileRead { path: String },
    FileWrite { path: String },
    FileDelete { path: String },
    NetConnect { host: String, port: u16 },
    NetBind { port: u16 },
    CommandExec { argv: Vec<String> },
    ProcessSignal { target: String, signal: i32 },
}

impl Operation {
    pub fn kind_str(&self) -> &'static str {
        match self {
            Self::FileRead { .. } => "file_read",
            Self::FileWrite { .. } => "file_write",
            Self::FileDelete { .. } => "file_delete",
            Self::NetConnect { .. } => "net_connect",
            Self::NetBind { .. } => "net_bind",
            Self::CommandExec { .. } => "command_exec",
            Self::ProcessSignal { .. } => "process_signal",
        }
    }

    pub fn target(&self) -> String {
        match self {
            Self::FileRead { path } | Self::FileWrite { path } | Self::FileDelete { path } => {
                path.clone()
            }
            Self::NetConnect { host, port } => format!("{host}:{port}"),
            Self::NetBind { port } => format!("localhost:{port}"),
            Self::CommandExec { argv } => argv.join(" "),
            Self::ProcessSignal { target, signal } => format!("{target}:{signal}"),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn serde_roundtrip_file_read() {
        let op = Operation::FileRead {
            path: "./src/main.ts".into(),
        };
        let json = serde_json::to_string(&op).unwrap();
        let parsed: Operation = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.kind_str(), "file_read");
        assert_eq!(parsed.target(), "./src/main.ts");
    }

    #[test]
    fn serde_roundtrip_net_connect() {
        let op = Operation::NetConnect {
            host: "localhost".into(),
            port: 3000,
        };
        let json = serde_json::to_string(&op).unwrap();
        let parsed: Operation = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.kind_str(), "net_connect");
        assert_eq!(parsed.target(), "localhost:3000");
    }

    #[test]
    fn serde_roundtrip_command_exec() {
        let op = Operation::CommandExec {
            argv: vec!["npm".into(), "install".into(), "lodash".into()],
        };
        let json = serde_json::to_string(&op).unwrap();
        let parsed: Operation = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.target(), "npm install lodash");
    }

    #[test]
    fn serde_roundtrip_process_signal() {
        let op = Operation::ProcessSignal {
            target: "node".into(),
            signal: 15,
        };
        let json = serde_json::to_string(&op).unwrap();
        let parsed: Operation = serde_json::from_str(&json).unwrap();
        assert_eq!(parsed.target(), "node:15");
    }

    #[test]
    fn serde_roundtrip_all_variants() {
        let ops = vec![
            Operation::FileRead { path: "./a".into() },
            Operation::FileWrite { path: "./b".into() },
            Operation::FileDelete { path: "./c".into() },
            Operation::NetConnect { host: "h".into(), port: 1 },
            Operation::NetBind { port: 2 },
            Operation::CommandExec { argv: vec!["x".into()] },
            Operation::ProcessSignal { target: "t".into(), signal: 9 },
        ];
        for op in &ops {
            let json = serde_json::to_string(op).unwrap();
            let _: Operation = serde_json::from_str(&json).unwrap();
        }
    }

    #[test]
    fn deserialize_from_api_format() {
        let json = r#"{"kind": "FileRead", "detail": {"path": "./src/main.ts"}}"#;
        let op: Operation = serde_json::from_str(json).unwrap();
        assert_eq!(op.kind_str(), "file_read");
    }

    #[test]
    fn kind_str_values() {
        assert_eq!(Operation::FileRead { path: "".into() }.kind_str(), "file_read");
        assert_eq!(Operation::FileWrite { path: "".into() }.kind_str(), "file_write");
        assert_eq!(Operation::FileDelete { path: "".into() }.kind_str(), "file_delete");
        assert_eq!(Operation::NetConnect { host: "".into(), port: 0 }.kind_str(), "net_connect");
        assert_eq!(Operation::NetBind { port: 0 }.kind_str(), "net_bind");
        assert_eq!(Operation::CommandExec { argv: vec![] }.kind_str(), "command_exec");
        assert_eq!(Operation::ProcessSignal { target: "".into(), signal: 0 }.kind_str(), "process_signal");
    }
}
