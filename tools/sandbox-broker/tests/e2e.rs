use std::sync::Arc;
use std::time::Duration;
use tempfile::TempDir;
use tokio::net::UnixStream;
use tokio::time::timeout;

use hyper::body::Bytes;
use hyper::Request;
use hyper_util::client::legacy::Client;
use hyper_util::rt::TokioExecutor;

use sandbox_broker::broker::{Broker, Mode};
use sandbox_broker::policy::{
    CommandPattern, FilesystemPolicy, NetworkPolicy, Policy, WorktreePolicy,
};
use sandbox_broker::server;
use sandbox_broker::worktree;

type UdsClient = Client<UdsConnector, http_body_util::Full<Bytes>>;

fn test_policy() -> Policy {
    Policy {
        filesystem: FilesystemPolicy {
            read: vec!["./src/**".into()],
            write: vec!["./src/**".into()],
        },
        network: NetworkPolicy {
            connect: vec!["localhost:*".into()],
            bind: vec![],
        },
        commands: vec![CommandPattern {
            pattern: vec!["npm".into(), "run".into(), "*".into()],
            scope: "scripts".into(),
        }],
        worktree: WorktreePolicy {
            allow_siblings: true,
        },
    }
}

#[derive(Clone)]
struct UdsConnector {
    path: std::path::PathBuf,
}

impl tower::Service<hyper::Uri> for UdsConnector {
    type Response = hyper_util::rt::TokioIo<UnixStream>;
    type Error = std::io::Error;
    type Future = std::pin::Pin<
        Box<dyn std::future::Future<Output = Result<Self::Response, Self::Error>> + Send>,
    >;

    fn poll_ready(
        &mut self,
        _cx: &mut std::task::Context<'_>,
    ) -> std::task::Poll<Result<(), Self::Error>> {
        std::task::Poll::Ready(Ok(()))
    }

    fn call(&mut self, _uri: hyper::Uri) -> Self::Future {
        let path = self.path.clone();
        Box::pin(async move {
            let stream = UnixStream::connect(path).await?;
            Ok(hyper_util::rt::TokioIo::new(stream))
        })
    }
}

struct TestBroker {
    client: UdsClient,
    sock: std::path::PathBuf,
    _tmp: TempDir,
}

impl TestBroker {
    async fn new() -> Self {
        Self::with_mode(test_policy(), Mode::Enforce).await
    }

    async fn with_mode(policy: Policy, mode: Mode) -> Self {
        let tmp = TempDir::new().unwrap();
        let sandbox_dir = tmp.path().join(".sandbox");
        std::fs::create_dir_all(&sandbox_dir).unwrap();

        let broker = Arc::new(Broker::new(policy, &sandbox_dir, mode));
        let sock = server::socket_path(&sandbox_dir);

        let sock_clone = sock.clone();
        tokio::spawn(async move {
            server::serve(broker, &sock_clone).await.unwrap();
        });

        for _ in 0..50 {
            if sock.exists() {
                break;
            }
            tokio::time::sleep(Duration::from_millis(10)).await;
        }
        assert!(sock.exists(), "broker socket not created");

        let connector = UdsConnector { path: sock.clone() };
        let client = Client::builder(TokioExecutor::new()).build(connector);
        Self { client, sock, _tmp: tmp }
    }

    async fn post_json(&self, uri: &str, body: &serde_json::Value) -> serde_json::Value {
        let req = Request::builder()
            .method("POST")
            .uri(format!("http://localhost{uri}"))
            .header("content-type", "application/json")
            .body(http_body_util::Full::new(Bytes::from(
                serde_json::to_vec(body).unwrap(),
            )))
            .unwrap();

        let resp = timeout(Duration::from_secs(5), self.client.request(req))
            .await
            .expect("timeout")
            .expect("request failed");

        let status = resp.status().as_u16();
        let bytes = http_body_util::BodyExt::collect(resp.into_body())
            .await
            .unwrap()
            .to_bytes();
        if bytes.is_empty() {
            serde_json::json!({"status": status})
        } else {
            serde_json::from_slice(&bytes).unwrap()
        }
    }

    async fn post_empty(&self, uri: &str) -> serde_json::Value {
        let req = Request::builder()
            .method("POST")
            .uri(format!("http://localhost{uri}"))
            .body(http_body_util::Full::new(Bytes::new()))
            .unwrap();

        let resp = timeout(Duration::from_secs(5), self.client.request(req))
            .await
            .expect("timeout")
            .expect("request failed");

        let bytes = http_body_util::BodyExt::collect(resp.into_body())
            .await
            .unwrap()
            .to_bytes();
        serde_json::from_slice(&bytes).unwrap()
    }

    async fn get_json(&self, uri: &str) -> serde_json::Value {
        let req = Request::builder()
            .method("GET")
            .uri(format!("http://localhost{uri}"))
            .body(http_body_util::Full::new(Bytes::new()))
            .unwrap();

        let resp = timeout(Duration::from_secs(5), self.client.request(req))
            .await
            .expect("timeout")
            .expect("request failed");

        let bytes = http_body_util::BodyExt::collect(resp.into_body())
            .await
            .unwrap()
            .to_bytes();
        serde_json::from_slice(&bytes).unwrap()
    }

    async fn get_status(&self, uri: &str) -> u16 {
        let req = Request::builder()
            .method("GET")
            .uri(format!("http://localhost{uri}"))
            .body(http_body_util::Full::new(Bytes::new()))
            .unwrap();

        let resp = timeout(Duration::from_secs(5), self.client.request(req))
            .await
            .expect("timeout")
            .expect("request failed");

        resp.status().as_u16()
    }

    async fn evaluate(&self, op: &serde_json::Value) -> serde_json::Value {
        self.post_json("/evaluate", op).await
    }
}

// --- Tests ---

#[tokio::test]
async fn e2e_evaluate_via_uds() {
    let b = TestBroker::new().await;
    let v = b.evaluate(&serde_json::json!({"kind": "FileRead", "detail": {"path": "./src/main.ts"}})).await;
    assert_eq!(v["outcome"], "allow");
}

#[tokio::test]
async fn e2e_denied_operation_via_uds() {
    let b = TestBroker::new().await;
    let v = b.evaluate(&serde_json::json!({"kind": "FileRead", "detail": {"path": "./.env"}})).await;
    assert_eq!(v["outcome"], "escalate");
}

#[tokio::test]
async fn e2e_grant_and_evaluate_flow() {
    let b = TestBroker::new().await;

    b.post_json("/grant", &serde_json::json!({
        "operation": {"kind": "FileWrite", "detail": {"path": "./config/app.yaml"}},
        "persist_suggested": true
    })).await;

    let v = b.evaluate(&serde_json::json!({"kind": "FileWrite", "detail": {"path": "./config/other.yaml"}})).await;
    assert_eq!(v["outcome"], "allow");
    assert_eq!(v["source"], "session_match");
}

#[tokio::test]
async fn e2e_health_check() {
    let b = TestBroker::new().await;
    assert_eq!(b.get_status("/health").await, 200);
}

#[tokio::test]
async fn e2e_concurrent_workspaces() {
    let b1 = TestBroker::new().await;
    let b2 = TestBroker::new().await;

    let op = serde_json::json!({"kind": "FileRead", "detail": {"path": "./src/a.ts"}});
    let (v1, v2) = tokio::join!(b1.evaluate(&op), b2.evaluate(&op));
    assert_eq!(v1["outcome"], "allow");
    assert_eq!(v2["outcome"], "allow");
}

#[tokio::test]
async fn e2e_worktree_shares_broker() {
    let tmp = TempDir::new().unwrap();
    let base = tmp.path().join("repo");
    let wt = tmp.path().join("repo-wt-feat");

    std::fs::create_dir_all(&base).unwrap();
    std::process::Command::new("git").args(["init"]).current_dir(&base).output().unwrap();
    std::process::Command::new("git").args(["commit", "--allow-empty", "-m", "init"]).current_dir(&base).output().unwrap();
    std::process::Command::new("git").args(["worktree", "add", wt.to_str().unwrap(), "-b", "feat"]).current_dir(&base).output().unwrap();

    assert_eq!(
        worktree::resolve_base_repo(&wt).canonicalize().unwrap(),
        base.canonicalize().unwrap()
    );

    let sandbox_dir = base.join(".sandbox");
    std::fs::create_dir_all(&sandbox_dir).unwrap();
    let broker = Arc::new(Broker::new(test_policy(), &sandbox_dir, Mode::Enforce));
    let sock = server::socket_path(&sandbox_dir);

    let sock_clone = sock.clone();
    tokio::spawn(async move { server::serve(broker, &sock_clone).await.unwrap() });

    for _ in 0..50 {
        if sock.exists() { break; }
        tokio::time::sleep(Duration::from_millis(10)).await;
    }

    let wt_sock = server::socket_path(&worktree::resolve_base_repo(&wt).join(".sandbox"));
    assert_eq!(wt_sock.canonicalize().unwrap(), sock.canonicalize().unwrap());

    let connector = UdsConnector { path: sock.clone() };
    let client: UdsClient = Client::builder(TokioExecutor::new()).build(connector);
    let req = Request::builder()
        .method("GET")
        .uri("http://localhost/health")
        .body(http_body_util::Full::new(Bytes::new()))
        .unwrap();
    let resp = timeout(Duration::from_secs(5), client.request(req)).await.expect("timeout").expect("failed");
    assert_eq!(resp.status(), 200);
}

#[tokio::test]
async fn e2e_circuit_breaker_via_uds() {
    let b = TestBroker::new().await;
    for i in 0..3 {
        let result = b.post_empty("/deny").await;
        if i < 2 {
            assert_eq!(result["circuit_breaker_tripped"], false);
        } else {
            assert_eq!(result["circuit_breaker_tripped"], true);
        }
    }
}

#[tokio::test]
async fn e2e_learning_mode_via_uds() {
    let b = TestBroker::with_mode(Policy::default(), Mode::Learning).await;
    let v = b.evaluate(&serde_json::json!({"kind": "CommandExec", "detail": {"argv": ["rm", "-rf", "/"]}})).await;
    assert_eq!(v["outcome"], "allow");
}

#[tokio::test]
async fn e2e_learning_finalize_via_uds() {
    let b = TestBroker::with_mode(Policy::default(), Mode::Learning).await;

    for path in ["./src/a.ts", "./src/b.ts", "./src/c.ts"] {
        b.evaluate(&serde_json::json!({"kind": "FileRead", "detail": {"path": path}})).await;
    }

    let policy = b.post_empty("/finalize-learning").await;
    let reads = policy["filesystem"]["read"].as_array().unwrap();
    assert!(reads.iter().any(|r| r.as_str() == Some("./src/**")));
}

#[tokio::test]
async fn e2e_pending_grants_via_uds() {
    let b = TestBroker::new().await;

    b.post_json("/grant", &serde_json::json!({
        "operation": {"kind": "FileWrite", "detail": {"path": "./new/file.ts"}},
        "persist_suggested": true
    })).await;

    let pending: Vec<serde_json::Value> = serde_json::from_value(b.get_json("/pending").await).unwrap();
    assert_eq!(pending.len(), 1);
    assert!(pending[0]["pattern"].as_str().unwrap().contains("new"));
}
