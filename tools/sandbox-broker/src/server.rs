use axum::extract::State;
use axum::http::StatusCode;
use axum::routing::{get, post};
use axum::{Json, Router};
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tokio::net::UnixListener;

use crate::broker::Broker;
use crate::operation::Operation;
use crate::persist;
use crate::policy::Policy;
use crate::session::Grant;
use crate::verdict::{Source, Verdict};

pub fn create_router(broker: Arc<Broker>) -> Router {
    Router::new()
        .route("/evaluate", post(evaluate))
        .route("/evaluate-deep", post(evaluate_deep))
        .route("/grant", post(grant))
        .route("/deny", post(deny))
        .route("/pending", get(pending))
        .route("/persist", post(persist_grants))
        .route("/finalize-learning", post(finalize_learning))
        .route("/health", get(health))
        .with_state(broker)
}

async fn evaluate(State(broker): State<Arc<Broker>>, Json(op): Json<Operation>) -> Json<Verdict> {
    let verdict = broker.evaluate(&op);
    Json(verdict)
}

async fn evaluate_deep(
    State(broker): State<Arc<Broker>>,
    Json(op): Json<Operation>,
) -> Json<Verdict> {
    let verdict = broker.evaluate_with_subagent(&op).await;
    Json(verdict)
}

#[derive(serde::Deserialize)]
struct GrantRequest {
    operation: Operation,
    persist_suggested: bool,
}

async fn grant(State(broker): State<Arc<Broker>>, Json(req): Json<GrantRequest>) -> StatusCode {
    broker.record_grant(&req.operation, Source::Human, req.persist_suggested);
    StatusCode::OK
}

#[derive(serde::Serialize)]
struct DenyResponse {
    circuit_breaker_tripped: bool,
}

async fn deny(State(broker): State<Arc<Broker>>) -> Json<DenyResponse> {
    let state = broker.record_denial();
    Json(DenyResponse {
        circuit_breaker_tripped: state != crate::session::CircuitBreakerState::Ok,
    })
}

async fn pending(State(broker): State<Arc<Broker>>) -> Json<Vec<Grant>> {
    Json(broker.pending_persistence())
}

#[derive(serde::Deserialize)]
struct PersistRequest {
    policy_path: PathBuf,
    grants: Vec<Grant>,
}

async fn persist_grants(Json(req): Json<PersistRequest>) -> Result<StatusCode, StatusCode> {
    persist::promote_grants(&req.policy_path, &req.grants)
        .map(|_| StatusCode::OK)
        .map_err(|e| {
            tracing::error!("persist failed: {e}");
            StatusCode::INTERNAL_SERVER_ERROR
        })
}

async fn finalize_learning(State(broker): State<Arc<Broker>>) -> Result<Json<Policy>, StatusCode> {
    broker
        .finalize_learning()
        .map(Json)
        .ok_or(StatusCode::NOT_FOUND)
}

async fn health() -> &'static str {
    "ok"
}

pub fn socket_path(sandbox_dir: &Path) -> PathBuf {
    sandbox_dir.join("broker.sock")
}

pub async fn serve(broker: Arc<Broker>, sock: &Path) -> Result<(), Box<dyn std::error::Error>> {
    if sock.exists() {
        std::fs::remove_file(sock)?;
    }
    let app = create_router(broker);
    let listener = UnixListener::bind(sock)?;
    tracing::info!(socket = %sock.display(), "broker listening");
    axum::serve(listener, app).await?;
    Ok(())
}
