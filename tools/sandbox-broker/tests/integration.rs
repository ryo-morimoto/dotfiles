use tempfile::TempDir;

use axum::body::Body;
use hyper::Request;
use tower::ServiceExt;

// We test by directly calling the router (in-process), no actual socket needed for unit-integration.
// For full E2E, we test with actual UDS.

mod helpers {
    use sandbox_broker::broker::{Broker, Mode};
    use sandbox_broker::policy::{
        CommandPattern, FilesystemPolicy, NetworkPolicy, Policy, WorktreePolicy,
    };
    use sandbox_broker::server;
    use std::path::Path;
    use std::sync::Arc;

    pub fn test_policy() -> Policy {
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
                    pattern: vec!["npm".into(), "run".into(), "*".into()],
                    scope: "scripts".into(),
                },
                CommandPattern {
                    pattern: vec!["git".into(), "add".into(), "*".into()],
                    scope: "vcs".into(),
                },
            ],
            worktree: WorktreePolicy {
                allow_siblings: true,
            },
        }
    }

    pub fn create_broker(dir: &Path) -> Arc<Broker> {
        std::fs::create_dir_all(dir).unwrap();
        Arc::new(Broker::new(test_policy(), dir, Mode::Enforce))
    }

    pub fn create_learning_broker(dir: &Path) -> Arc<Broker> {
        std::fs::create_dir_all(dir).unwrap();
        Arc::new(Broker::new(Policy::default(), dir, Mode::Learning))
    }

    pub fn router(broker: Arc<Broker>) -> axum::Router {
        server::create_router(broker)
    }
}

#[tokio::test]
async fn evaluate_allowed_file_read() {
    let tmp = TempDir::new().unwrap();
    let broker = helpers::create_broker(tmp.path());
    let app = helpers::router(broker);

    let body = serde_json::json!({"kind": "FileRead", "detail": {"path": "./src/main.ts"}});
    let req = Request::builder()
        .method("POST")
        .uri("/evaluate")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_vec(&body).unwrap()))
        .unwrap();

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), 200);

    let body = axum::body::to_bytes(resp.into_body(), 10240).await.unwrap();
    let verdict: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(verdict["outcome"], "allow");
    assert_eq!(verdict["source"], "policy_match");
}

#[tokio::test]
async fn evaluate_denied_file_read() {
    let tmp = TempDir::new().unwrap();
    let broker = helpers::create_broker(tmp.path());
    let app = helpers::router(broker);

    let body = serde_json::json!({"kind": "FileRead", "detail": {"path": "./.env"}});
    let req = Request::builder()
        .method("POST")
        .uri("/evaluate")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_vec(&body).unwrap()))
        .unwrap();

    let resp = app.oneshot(req).await.unwrap();
    let body = axum::body::to_bytes(resp.into_body(), 10240).await.unwrap();
    let verdict: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(verdict["outcome"], "escalate");
}

#[tokio::test]
async fn evaluate_allowed_command() {
    let tmp = TempDir::new().unwrap();
    let broker = helpers::create_broker(tmp.path());
    let app = helpers::router(broker);

    let body =
        serde_json::json!({"kind": "CommandExec", "detail": {"argv": ["npm", "install", "lodash"]}});
    let req = Request::builder()
        .method("POST")
        .uri("/evaluate")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_vec(&body).unwrap()))
        .unwrap();

    let resp = app.oneshot(req).await.unwrap();
    let body = axum::body::to_bytes(resp.into_body(), 10240).await.unwrap();
    let verdict: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(verdict["outcome"], "allow");
}

#[tokio::test]
async fn evaluate_denied_command() {
    let tmp = TempDir::new().unwrap();
    let broker = helpers::create_broker(tmp.path());
    let app = helpers::router(broker);

    let body =
        serde_json::json!({"kind": "CommandExec", "detail": {"argv": ["rm", "-rf", "/"]}});
    let req = Request::builder()
        .method("POST")
        .uri("/evaluate")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_vec(&body).unwrap()))
        .unwrap();

    let resp = app.oneshot(req).await.unwrap();
    let body = axum::body::to_bytes(resp.into_body(), 10240).await.unwrap();
    let verdict: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(verdict["outcome"], "escalate");
}

#[tokio::test]
async fn evaluate_network_allowed() {
    let tmp = TempDir::new().unwrap();
    let broker = helpers::create_broker(tmp.path());
    let app = helpers::router(broker);

    let body =
        serde_json::json!({"kind": "NetConnect", "detail": {"host": "localhost", "port": 3000}});
    let req = Request::builder()
        .method("POST")
        .uri("/evaluate")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_vec(&body).unwrap()))
        .unwrap();

    let resp = app.oneshot(req).await.unwrap();
    let body = axum::body::to_bytes(resp.into_body(), 10240).await.unwrap();
    let verdict: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(verdict["outcome"], "allow");
}

#[tokio::test]
async fn evaluate_network_denied() {
    let tmp = TempDir::new().unwrap();
    let broker = helpers::create_broker(tmp.path());
    let app = helpers::router(broker);

    let body =
        serde_json::json!({"kind": "NetConnect", "detail": {"host": "evil.com", "port": 443}});
    let req = Request::builder()
        .method("POST")
        .uri("/evaluate")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_vec(&body).unwrap()))
        .unwrap();

    let resp = app.oneshot(req).await.unwrap();
    let body = axum::body::to_bytes(resp.into_body(), 10240).await.unwrap();
    let verdict: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(verdict["outcome"], "escalate");
}

#[tokio::test]
async fn grant_then_evaluate_allows() {
    let tmp = TempDir::new().unwrap();
    let broker = helpers::create_broker(tmp.path());
    let app = helpers::router(broker.clone());

    // First, grant access to ./config/**
    let grant_body = serde_json::json!({
        "operation": {"kind": "FileWrite", "detail": {"path": "./config/db.yaml"}},
        "persist_suggested": true
    });
    let req = Request::builder()
        .method("POST")
        .uri("/grant")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_vec(&grant_body).unwrap()))
        .unwrap();

    let resp = app.clone().oneshot(req).await.unwrap();
    assert_eq!(resp.status(), 200);

    // Now evaluate a write to the same directory
    let eval_body =
        serde_json::json!({"kind": "FileWrite", "detail": {"path": "./config/other.yaml"}});
    let req = Request::builder()
        .method("POST")
        .uri("/evaluate")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_vec(&eval_body).unwrap()))
        .unwrap();

    let resp = app.oneshot(req).await.unwrap();
    let body = axum::body::to_bytes(resp.into_body(), 10240).await.unwrap();
    let verdict: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(verdict["outcome"], "allow");
    assert_eq!(verdict["source"], "session_match");
}

#[tokio::test]
async fn circuit_breaker_trips_after_consecutive_denials() {
    let tmp = TempDir::new().unwrap();
    let broker = helpers::create_broker(tmp.path());
    let app = helpers::router(broker);

    for i in 0..3 {
        let req = Request::builder()
            .method("POST")
            .uri("/deny")
            .header("content-type", "application/json")
            .body(Body::empty())
            .unwrap();

        let resp = app.clone().oneshot(req).await.unwrap();
        let body = axum::body::to_bytes(resp.into_body(), 10240).await.unwrap();
        let result: serde_json::Value = serde_json::from_slice(&body).unwrap();

        if i < 2 {
            assert_eq!(result["circuit_breaker_tripped"], false);
        } else {
            assert_eq!(result["circuit_breaker_tripped"], true);
        }
    }
}

#[tokio::test]
async fn learning_mode_allows_everything() {
    let tmp = TempDir::new().unwrap();
    let broker = helpers::create_learning_broker(tmp.path());
    let app = helpers::router(broker);

    // Even dangerous operations are allowed in learning mode
    let body =
        serde_json::json!({"kind": "CommandExec", "detail": {"argv": ["rm", "-rf", "/"]}});
    let req = Request::builder()
        .method("POST")
        .uri("/evaluate")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_vec(&body).unwrap()))
        .unwrap();

    let resp = app.oneshot(req).await.unwrap();
    let body_bytes = axum::body::to_bytes(resp.into_body(), 10240).await.unwrap();
    let verdict: serde_json::Value = serde_json::from_slice(&body_bytes).unwrap();
    assert_eq!(verdict["outcome"], "allow");
}

#[tokio::test]
async fn finalize_learning_generates_policy() {
    let tmp = TempDir::new().unwrap();
    let broker = helpers::create_learning_broker(tmp.path());
    let app = helpers::router(broker);

    // Record some operations
    let ops = vec![
        serde_json::json!({"kind": "FileRead", "detail": {"path": "./src/a.ts"}}),
        serde_json::json!({"kind": "FileRead", "detail": {"path": "./src/b.ts"}}),
        serde_json::json!({"kind": "FileRead", "detail": {"path": "./src/c.ts"}}),
        serde_json::json!({"kind": "FileWrite", "detail": {"path": "./src/a.ts"}}),
        serde_json::json!({"kind": "CommandExec", "detail": {"argv": ["npm", "run", "dev"]}}),
    ];

    for op in &ops {
        let req = Request::builder()
            .method("POST")
            .uri("/evaluate")
            .header("content-type", "application/json")
            .body(Body::from(serde_json::to_vec(op).unwrap()))
            .unwrap();
        app.clone().oneshot(req).await.unwrap();
    }

    // Finalize
    let req = Request::builder()
        .method("POST")
        .uri("/finalize-learning")
        .body(Body::empty())
        .unwrap();

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), 200);

    let body = axum::body::to_bytes(resp.into_body(), 10240).await.unwrap();
    let policy: serde_json::Value = serde_json::from_slice(&body).unwrap();

    // Should have generalized ./src/ reads to ./src/**
    let reads = policy["filesystem"]["read"].as_array().unwrap();
    assert!(reads.iter().any(|r| r.as_str() == Some("./src/**")));
}

#[tokio::test]
async fn persist_grants_updates_policy_file() {
    let tmp = TempDir::new().unwrap();
    let policy_path = tmp.path().join("policy.toml");

    // Start with a minimal policy
    std::fs::write(
        &policy_path,
        "[filesystem]\nread = [\"./src/**\"]\nwrite = []\n[network]\nconnect = []\nbind = []\n",
    )
    .unwrap();

    let broker = helpers::create_broker(tmp.path());
    let app = helpers::router(broker);

    let req_body = serde_json::json!({
        "policy_path": policy_path.to_str().unwrap(),
        "grants": [{
            "pattern": "./config/**",
            "category": "filesystem_write",
            "source": "human",
            "persist_suggested": true
        }]
    });

    let req = Request::builder()
        .method("POST")
        .uri("/persist")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_vec(&req_body).unwrap()))
        .unwrap();

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), 200);

    // Verify the file was updated
    let content = std::fs::read_to_string(&policy_path).unwrap();
    assert!(content.contains("./config/**"));
}

#[tokio::test]
async fn worktree_sibling_read_allowed() {
    let tmp = TempDir::new().unwrap();
    let broker = helpers::create_broker(tmp.path());
    let app = helpers::router(broker);

    let body = serde_json::json!({"kind": "FileRead", "detail": {"path": "../project-wt/feat-1/src/main.ts"}});
    let req = Request::builder()
        .method("POST")
        .uri("/evaluate")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_vec(&body).unwrap()))
        .unwrap();

    let resp = app.oneshot(req).await.unwrap();
    let body = axum::body::to_bytes(resp.into_body(), 10240).await.unwrap();
    let verdict: serde_json::Value = serde_json::from_slice(&body).unwrap();
    assert_eq!(verdict["outcome"], "allow");
    assert_eq!(verdict["source"], "programmatic_check");
}

#[tokio::test]
async fn health_endpoint() {
    let tmp = TempDir::new().unwrap();
    let broker = helpers::create_broker(tmp.path());
    let app = helpers::router(broker);

    let req = Request::builder()
        .method("GET")
        .uri("/health")
        .body(Body::empty())
        .unwrap();

    let resp = app.oneshot(req).await.unwrap();
    assert_eq!(resp.status(), 200);
}

#[tokio::test]
async fn pending_returns_grants_with_persist_flag() {
    let tmp = TempDir::new().unwrap();
    let broker = helpers::create_broker(tmp.path());
    let app = helpers::router(broker.clone());

    // Grant with persist_suggested = true
    let grant_body = serde_json::json!({
        "operation": {"kind": "FileWrite", "detail": {"path": "./new-dir/file.ts"}},
        "persist_suggested": true
    });
    let req = Request::builder()
        .method("POST")
        .uri("/grant")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_vec(&grant_body).unwrap()))
        .unwrap();
    app.clone().oneshot(req).await.unwrap();

    // Grant with persist_suggested = false
    let grant_body2 = serde_json::json!({
        "operation": {"kind": "FileRead", "detail": {"path": "./tmp/scratch.txt"}},
        "persist_suggested": false
    });
    let req = Request::builder()
        .method("POST")
        .uri("/grant")
        .header("content-type", "application/json")
        .body(Body::from(serde_json::to_vec(&grant_body2).unwrap()))
        .unwrap();
    app.clone().oneshot(req).await.unwrap();

    // Get pending
    let req = Request::builder()
        .method("GET")
        .uri("/pending")
        .body(Body::empty())
        .unwrap();
    let resp = app.oneshot(req).await.unwrap();
    let body = axum::body::to_bytes(resp.into_body(), 10240).await.unwrap();
    let pending: Vec<serde_json::Value> = serde_json::from_slice(&body).unwrap();

    // Only the one with persist_suggested = true
    assert_eq!(pending.len(), 1);
    assert!(pending[0]["pattern"].as_str().unwrap().contains("new-dir"));
}
