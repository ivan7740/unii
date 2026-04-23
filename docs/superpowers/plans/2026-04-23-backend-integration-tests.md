# 后端集成测试实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 unii-server 添加 26 个集成测试，覆盖 auth/team/location/message/user 全部 5 个 API 模块，每个测试通过真实 HTTP 请求打完整调用链至 PostgreSQL。

**Architecture:** 首先将 `main.rs` 中的 `AppState`、`build_router`、`rate_limit_mw` 提取到 `lib.rs`（集成测试必须通过 library target import）；测试使用 `#[sqlx::test]` 自动创建/清理独立测试数据库，`axum-test::TestServer` 发送 HTTP 请求；`tests/common/mod.rs` 提供跨测试文件共享的 `build_app`、`create_user`、`create_team` 辅助函数。

**Tech Stack:** Rust, axum 0.8, sqlx 0.8 (`#[sqlx::test]`), axum-test 15.x, tokio, serde_json

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| 新建 | `unii-server/src/lib.rs` | 公开 AppState、build_router、make_limiter、rate_limit_mw |
| 修改 | `unii-server/src/main.rs` | 仅保留启动逻辑，调用 lib.rs |
| 修改 | `unii-server/Cargo.toml` | 添加 dev-dependencies |
| 新建 | `unii-server/tests/common/mod.rs` | build_app / create_user / create_team / auth_header |
| 新建 | `unii-server/tests/auth_test.rs` | 7 个 auth 测试 |
| 新建 | `unii-server/tests/team_test.rs` | 7 个 team 测试 |
| 新建 | `unii-server/tests/location_test.rs` | 4 个 location 测试 |
| 新建 | `unii-server/tests/message_test.rs` | 4 个 message 测试 |
| 新建 | `unii-server/tests/user_test.rs` | 4 个 user 测试 |

---

### Task 1: 提取 lib.rs + 更新 Cargo.toml + 简化 main.rs

**Files:**
- Create: `unii-server/src/lib.rs`
- Modify: `unii-server/src/main.rs`
- Modify: `unii-server/Cargo.toml`

- [ ] **Step 1: 在 Cargo.toml 末尾追加 dev-dependencies**

在 `unii-server/Cargo.toml` 末尾添加：

```toml
[dev-dependencies]
axum-test = "15"
sqlx = { version = "0.8", features = [
    "runtime-tokio",
    "tls-rustls",
    "postgres",
    "uuid",
    "chrono",
    "migrate",
    "macros",
] }
tokio = { version = "1", features = ["full"] }
```

- [ ] **Step 2: 创建 src/lib.rs**

创建文件 `unii-server/src/lib.rs`，内容如下：

```rust
pub mod auth;
pub mod config;
pub mod db;
pub mod error;
pub mod extractors;
pub mod location;
pub mod message;
pub mod models;
pub mod team;
pub mod user;
pub mod utils;
pub mod ws;

use axum::http::Method;
use axum::middleware;
use axum::response::IntoResponse;
use axum::routing::get;
use axum::Router;
use governor::{DefaultKeyedRateLimiter, Quota, RateLimiter};
use std::net::{IpAddr, SocketAddr};
use std::num::NonZeroU32;
use std::sync::Arc;
use tower_http::cors::{Any, CorsLayer};
use tower_http::trace::TraceLayer;

use ws::manager::WsManager;

#[derive(Clone)]
pub struct AppState {
    pub db: sqlx::PgPool,
    pub config: config::AppConfig,
    pub ws_manager: WsManager,
}

pub fn make_limiter(per_minute: u32) -> Arc<DefaultKeyedRateLimiter<IpAddr>> {
    Arc::new(RateLimiter::keyed(
        Quota::per_minute(NonZeroU32::new(per_minute).unwrap()),
    ))
}

pub fn build_router(
    state: AppState,
    auth_lim: Arc<DefaultKeyedRateLimiter<IpAddr>>,
    api_lim: Arc<DefaultKeyedRateLimiter<IpAddr>>,
) -> Router {
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods([Method::GET, Method::POST, Method::PUT, Method::DELETE])
        .allow_headers(Any);

    let auth_lim_c = Arc::clone(&auth_lim);
    let api_lim_c = Arc::clone(&api_lim);
    let api_lim_c2 = Arc::clone(&api_lim);
    let api_lim_c3 = Arc::clone(&api_lim);
    let api_lim_c4 = Arc::clone(&api_lim);

    Router::new()
        .route("/health", get(health_check))
        .route("/ws", get(ws::handler::ws_handler))
        .nest(
            "/api/auth",
            auth::handler::router().layer(middleware::from_fn(
                move |req: axum::extract::Request, next: middleware::Next| {
                    let lim = Arc::clone(&auth_lim_c);
                    async move { rate_limit_mw(req, next, lim).await }
                },
            )),
        )
        .nest(
            "/api/teams",
            team::handler::router().layer(middleware::from_fn(
                move |req: axum::extract::Request, next: middleware::Next| {
                    let lim = Arc::clone(&api_lim_c);
                    async move { rate_limit_mw(req, next, lim).await }
                },
            )),
        )
        .nest(
            "/api/locations",
            location::handler::router().layer(middleware::from_fn(
                move |req: axum::extract::Request, next: middleware::Next| {
                    let lim = Arc::clone(&api_lim_c2);
                    async move { rate_limit_mw(req, next, lim).await }
                },
            )),
        )
        .nest(
            "/api/messages",
            message::handler::router().layer(middleware::from_fn(
                move |req: axum::extract::Request, next: middleware::Next| {
                    let lim = Arc::clone(&api_lim_c3);
                    async move { rate_limit_mw(req, next, lim).await }
                },
            )),
        )
        .nest(
            "/api/users",
            user::handler::router().layer(middleware::from_fn(
                move |req: axum::extract::Request, next: middleware::Next| {
                    let lim = Arc::clone(&api_lim_c4);
                    async move { rate_limit_mw(req, next, lim).await }
                },
            )),
        )
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state)
}

async fn health_check() -> &'static str {
    "OK"
}

pub async fn rate_limit_mw(
    req: axum::extract::Request,
    next: middleware::Next,
    limiter: Arc<DefaultKeyedRateLimiter<IpAddr>>,
) -> axum::response::Response {
    use axum::extract::ConnectInfo;
    let raw_ip = req
        .extensions()
        .get::<ConnectInfo<SocketAddr>>()
        .map(|ci| ci.0.ip());

    let Some(raw_ip) = raw_ip else {
        // ConnectInfo missing in test environment — pass through
        return next.run(req).await;
    };

    let ip = match raw_ip {
        IpAddr::V6(v6) => v6.to_ipv4_mapped().map(IpAddr::V4).unwrap_or(raw_ip),
        v4 => v4,
    };

    if let Err(not_until) = limiter.check_key(&ip) {
        use governor::clock::Clock as _;
        let wait_secs = not_until
            .wait_time_from(governor::clock::DefaultClock::default().now())
            .as_secs()
            .max(1)
            .to_string();
        let mut resp = (
            axum::http::StatusCode::TOO_MANY_REQUESTS,
            axum::Json(serde_json::json!({"error": "Too many requests", "code": 429})),
        )
            .into_response();
        if let Ok(val) = axum::http::HeaderValue::from_str(&wait_secs) {
            resp.headers_mut()
                .insert(axum::http::header::RETRY_AFTER, val);
        }
        return resp;
    }
    next.run(req).await
}
```

- [ ] **Step 3: 简化 src/main.rs**

将 `unii-server/src/main.rs` 替换为：

```rust
use std::net::SocketAddr;
use unii_server::{build_router, make_limiter, AppState};
use unii_server::config::AppConfig;
use unii_server::ws::manager::WsManager;
use std::sync::Arc;

#[tokio::main]
async fn main() {
    dotenvy::dotenv().ok();

    tracing_subscriber::fmt()
        .with_env_filter(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| "info".into()),
        )
        .init();

    let config = AppConfig::from_env();
    let server_addr = config.server_addr();

    let pool = unii_server::db::pool::create_pool(&config.database_url).await;

    sqlx::migrate!("./migrations")
        .run(&pool)
        .await
        .expect("Failed to run migrations");

    tracing::info!("Database migrations completed");

    let state = AppState {
        db: pool,
        config,
        ws_manager: WsManager::new(),
    };

    let auth_lim = make_limiter(5);
    let api_lim = make_limiter(60);

    // Periodically clean up stale rate limiter entries
    let auth_lim_gc = Arc::clone(&auth_lim);
    let api_lim_gc = Arc::clone(&api_lim);
    tokio::spawn(async move {
        let mut interval = tokio::time::interval(std::time::Duration::from_secs(60));
        loop {
            interval.tick().await;
            auth_lim_gc.retain_recent();
            api_lim_gc.retain_recent();
        }
    });

    let app = build_router(state, auth_lim, api_lim);

    let listener = tokio::net::TcpListener::bind(&server_addr)
        .await
        .expect("Failed to bind address");

    tracing::info!("Server listening on {}", server_addr);

    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await
    .expect("Server failed");
}
```

- [ ] **Step 4: 编译确认无错误**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo build 2>&1
```

期望：`Finished` 无 error。

- [ ] **Step 5: 运行现有测试确认通过**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test --lib 2>&1
```

期望：所有现有单元测试（extract_mentions 等）通过。

- [ ] **Step 6: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/src/lib.rs unii-server/src/main.rs unii-server/Cargo.toml && git commit -m "refactor(server): extract lib.rs with AppState and build_router for integration tests"
```

---

### Task 2: tests/common/mod.rs — 测试辅助函数

**Files:**
- Create: `unii-server/tests/common/mod.rs`

- [ ] **Step 1: 创建 tests/common/mod.rs**

```bash
mkdir -p /Users/mac/rust_flutter_app/study_dw/unii-server/tests/common
```

创建文件 `unii-server/tests/common/mod.rs`：

```rust
use axum::http::StatusCode;
use axum_test::TestServer;
use sqlx::PgPool;
use unii_server::{build_router, make_limiter, AppState};
use unii_server::config::AppConfig;
use unii_server::ws::manager::WsManager;

pub fn test_config() -> AppConfig {
    AppConfig {
        database_url: String::new(), // pool is provided directly by sqlx::test
        jwt_secret: "test-jwt-secret-key-for-testing-purposes-only!!".to_string(),
        jwt_expiration: 3600,
        refresh_token_expiration: 604800,
        server_host: "127.0.0.1".to_string(),
        server_port: 3000,
    }
}

pub fn build_app(pool: PgPool) -> TestServer {
    let state = AppState {
        db: pool,
        config: test_config(),
        ws_manager: WsManager::new(),
    };
    // High limits so tests are never rate-limited
    let router = build_router(state, make_limiter(10_000), make_limiter(10_000));
    TestServer::new(router).expect("failed to build test server")
}

/// Register a user and return their access token.
pub async fn create_user(
    server: &TestServer,
    phone: &str,
    password: &str,
    nickname: &str,
) -> String {
    let resp = server
        .post("/api/auth/register")
        .json(&serde_json::json!({
            "phone": phone,
            "password": password,
            "nickname": nickname
        }))
        .await;
    resp.assert_status(StatusCode::CREATED);
    let body: serde_json::Value = resp.json();
    body["access_token"].as_str().unwrap().to_string()
}

/// Create a team and return (team_id, invite_code).
pub async fn create_team(server: &TestServer, token: &str, name: &str) -> (String, String) {
    let resp = server
        .post("/api/teams")
        .add_header(
            axum::http::header::AUTHORIZATION,
            format!("Bearer {}", token),
        )
        .json(&serde_json::json!({ "name": name }))
        .await;
    resp.assert_status(StatusCode::CREATED);
    let body: serde_json::Value = resp.json();
    let team_id = body["id"].as_str().unwrap().to_string();
    let invite_code = body["invite_code"].as_str().unwrap().to_string();
    (team_id, invite_code)
}
```

- [ ] **Step 2: 编译测试代码确认无错误**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test --tests 2>&1 | head -20
```

期望：编译通过（即使还没有测试文件也不报错）。

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/tests/ && git commit -m "test(server): add common test helpers (build_app, create_user, create_team)"
```

---

### Task 3: auth_test.rs — 7 个认证测试

**Files:**
- Create: `unii-server/tests/auth_test.rs`

- [ ] **Step 1: 创建 tests/auth_test.rs**

```rust
mod common;

use axum::http::StatusCode;
use serde_json::json;

#[sqlx::test(migrations = "./migrations")]
async fn register_success(pool: sqlx::PgPool) {
    let server = common::build_app(pool);

    let resp = server
        .post("/api/auth/register")
        .json(&json!({
            "phone": "13800000001",
            "password": "password123",
            "nickname": "Alice"
        }))
        .await;

    resp.assert_status(StatusCode::CREATED);
    let body: serde_json::Value = resp.json();
    assert!(body["access_token"].is_string(), "access_token missing");
    assert!(body["refresh_token"].is_string(), "refresh_token missing");
    assert_eq!(body["user"]["nickname"], "Alice");
    assert_eq!(body["user"]["phone"], "13800000001");
}

#[sqlx::test(migrations = "./migrations")]
async fn register_duplicate_phone(pool: sqlx::PgPool) {
    let server = common::build_app(pool);

    let payload = json!({
        "phone": "13800000001",
        "password": "password123",
        "nickname": "Alice"
    });
    server.post("/api/auth/register").json(&payload).await;

    let resp = server
        .post("/api/auth/register")
        .json(&json!({
            "phone": "13800000001",
            "password": "other_password",
            "nickname": "Bob"
        }))
        .await;

    resp.assert_status(StatusCode::CONFLICT);
}

#[sqlx::test(migrations = "./migrations")]
async fn login_success(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    common::create_user(&server, "13800000001", "password123", "Alice").await;

    let resp = server
        .post("/api/auth/login")
        .json(&json!({
            "phone": "13800000001",
            "password": "password123"
        }))
        .await;

    resp.assert_status_ok();
    let body: serde_json::Value = resp.json();
    assert!(body["access_token"].is_string());
    assert!(body["refresh_token"].is_string());
}

#[sqlx::test(migrations = "./migrations")]
async fn login_wrong_password(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    common::create_user(&server, "13800000001", "password123", "Alice").await;

    let resp = server
        .post("/api/auth/login")
        .json(&json!({
            "phone": "13800000001",
            "password": "wrongpassword"
        }))
        .await;

    resp.assert_status(StatusCode::UNAUTHORIZED);
}

#[sqlx::test(migrations = "./migrations")]
async fn refresh_token_success(pool: sqlx::PgPool) {
    let server = common::build_app(pool);

    let register_resp = server
        .post("/api/auth/register")
        .json(&json!({
            "phone": "13800000001",
            "password": "password123",
            "nickname": "Alice"
        }))
        .await;
    let body: serde_json::Value = register_resp.json();
    let refresh_token = body["refresh_token"].as_str().unwrap();

    let resp = server
        .post("/api/auth/refresh")
        .json(&json!({ "refresh_token": refresh_token }))
        .await;

    resp.assert_status_ok();
    let body: serde_json::Value = resp.json();
    assert!(body["access_token"].is_string());
}

#[sqlx::test(migrations = "./migrations")]
async fn get_me_authenticated(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "password123", "Alice").await;

    let resp = server
        .get("/api/auth/me")
        .add_header(
            axum::http::header::AUTHORIZATION,
            format!("Bearer {}", token),
        )
        .await;

    resp.assert_status_ok();
    let body: serde_json::Value = resp.json();
    assert_eq!(body["nickname"], "Alice");
}

#[sqlx::test(migrations = "./migrations")]
async fn get_me_unauthenticated(pool: sqlx::PgPool) {
    let server = common::build_app(pool);

    let resp = server.get("/api/auth/me").await;

    resp.assert_status(StatusCode::UNAUTHORIZED);
}
```

- [ ] **Step 2: 运行 auth 测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && DATABASE_URL=postgres://mac@localhost/unii_db cargo test --test auth_test 2>&1
```

期望：`test result: ok. 7 passed`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/tests/auth_test.rs && git commit -m "test(auth): add 7 integration tests for auth API"
```

---

### Task 4: team_test.rs — 7 个团队测试

**Files:**
- Create: `unii-server/tests/team_test.rs`

- [ ] **Step 1: 创建 tests/team_test.rs**

```rust
mod common;

use axum::http::StatusCode;
use serde_json::json;

#[sqlx::test(migrations = "./migrations")]
async fn create_team_success(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "pass123", "Alice").await;

    let resp = server
        .post("/api/teams")
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .json(&json!({ "name": "Hikers" }))
        .await;

    resp.assert_status(StatusCode::CREATED);
    let body: serde_json::Value = resp.json();
    assert_eq!(body["name"], "Hikers");
    assert!(body["id"].is_string());
    assert!(body["invite_code"].is_string());
}

#[sqlx::test(migrations = "./migrations")]
async fn list_teams(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "pass123", "Alice").await;
    common::create_team(&server, &token, "Hikers").await;

    let resp = server
        .get("/api/teams")
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .await;

    resp.assert_status_ok();
    let body: serde_json::Value = resp.json();
    assert!(body.as_array().unwrap().len() >= 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn join_team_by_invite_code(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token_a = common::create_user(&server, "13800000001", "pass123", "Alice").await;
    let token_b = common::create_user(&server, "13800000002", "pass123", "Bob").await;
    let (team_id, invite_code) = common::create_team(&server, &token_a, "Hikers").await;

    let resp = server
        .post("/api/teams/join")
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token_b))
        .json(&json!({ "invite_code": invite_code }))
        .await;

    resp.assert_status_ok();

    // Bob should now appear in team members
    let detail_resp = server
        .get(&format!("/api/teams/{}", team_id))
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token_b))
        .await;
    detail_resp.assert_status_ok();
    let body: serde_json::Value = detail_resp.json();
    let members = body["members"].as_array().unwrap();
    let nicknames: Vec<&str> = members
        .iter()
        .filter_map(|m| m["nickname"].as_str())
        .collect();
    assert!(nicknames.contains(&"Bob"), "Bob not in team members");
}

#[sqlx::test(migrations = "./migrations")]
async fn get_team_detail(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "pass123", "Alice").await;
    let (team_id, _) = common::create_team(&server, &token, "Hikers").await;

    let resp = server
        .get(&format!("/api/teams/{}", team_id))
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .await;

    resp.assert_status_ok();
    let body: serde_json::Value = resp.json();
    assert_eq!(body["team"]["name"], "Hikers");
    assert!(body["members"].as_array().unwrap().len() >= 1);
}

#[sqlx::test(migrations = "./migrations")]
async fn leave_team(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token_a = common::create_user(&server, "13800000001", "pass123", "Alice").await;
    let token_b = common::create_user(&server, "13800000002", "pass123", "Bob").await;
    let (team_id, invite_code) = common::create_team(&server, &token_a, "Hikers").await;

    // Bob joins
    server
        .post("/api/teams/join")
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token_b))
        .json(&json!({ "invite_code": invite_code }))
        .await;

    // Bob leaves
    let resp = server
        .delete(&format!("/api/teams/{}/leave", team_id))
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token_b))
        .await;

    resp.assert_status_ok();
}

#[sqlx::test(migrations = "./migrations")]
async fn owner_dissolve_team(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "pass123", "Alice").await;
    let (team_id, _) = common::create_team(&server, &token, "Hikers").await;

    let resp = server
        .delete(&format!("/api/teams/{}", team_id))
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .await;

    resp.assert_status(StatusCode::NO_CONTENT);
}

#[sqlx::test(migrations = "./migrations")]
async fn non_owner_cannot_dissolve(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token_a = common::create_user(&server, "13800000001", "pass123", "Alice").await;
    let token_b = common::create_user(&server, "13800000002", "pass123", "Bob").await;
    let (team_id, invite_code) = common::create_team(&server, &token_a, "Hikers").await;

    server
        .post("/api/teams/join")
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token_b))
        .json(&json!({ "invite_code": invite_code }))
        .await;

    let resp = server
        .delete(&format!("/api/teams/{}", team_id))
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token_b))
        .await;

    resp.assert_status(StatusCode::FORBIDDEN);
}
```

- [ ] **Step 2: 运行 team 测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && DATABASE_URL=postgres://mac@localhost/unii_db cargo test --test team_test 2>&1
```

期望：`test result: ok. 7 passed`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/tests/team_test.rs && git commit -m "test(team): add 7 integration tests for team API"
```

---

### Task 5: location_test.rs — 4 个位置测试

**Files:**
- Create: `unii-server/tests/location_test.rs`

- [ ] **Step 1: 创建 tests/location_test.rs**

```rust
mod common;

use axum::http::StatusCode;
use serde_json::json;

#[sqlx::test(migrations = "./migrations")]
async fn report_location_success(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "pass123", "Alice").await;
    let (team_id, _) = common::create_team(&server, &token, "Hikers").await;

    let resp = server
        .post("/api/locations")
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .json(&json!({
            "team_id": team_id,
            "latitude": 39.9042,
            "longitude": 116.4074
        }))
        .await;

    resp.assert_status(StatusCode::CREATED);
}

#[sqlx::test(migrations = "./migrations")]
async fn get_team_locations(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "pass123", "Alice").await;
    let (team_id, _) = common::create_team(&server, &token, "Hikers").await;

    // Report a location first
    server
        .post("/api/locations")
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .json(&json!({
            "team_id": team_id,
            "latitude": 39.9042,
            "longitude": 116.4074
        }))
        .await;

    let resp = server
        .get(&format!("/api/locations/team/{}", team_id))
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .await;

    resp.assert_status_ok();
    let body: serde_json::Value = resp.json();
    let locations = body.as_array().unwrap();
    assert!(!locations.is_empty());
    assert!(locations[0]["latitude"].is_number());
    assert!(locations[0]["longitude"].is_number());
}

#[sqlx::test(migrations = "./migrations")]
async fn get_user_track(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "pass123", "Alice").await;
    let (team_id, _) = common::create_team(&server, &token, "Hikers").await;

    // Report two locations
    for (lat, lon) in [(39.9042, 116.4074), (39.9050, 116.4080)] {
        server
            .post("/api/locations")
            .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
            .json(&json!({
                "team_id": team_id,
                "latitude": lat,
                "longitude": lon
            }))
            .await;
    }

    // Get user id from /api/auth/me
    let me_resp = server
        .get("/api/auth/me")
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .await;
    let me: serde_json::Value = me_resp.json();
    let user_id = me["id"].as_str().unwrap();

    let resp = server
        .get(&format!("/api/locations/track/{}", user_id))
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .await;

    resp.assert_status_ok();
    let body: serde_json::Value = resp.json();
    let points = body.as_array().unwrap();
    assert!(points.len() >= 2);
}

#[sqlx::test(migrations = "./migrations")]
async fn non_member_cannot_view_team_locations(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token_a = common::create_user(&server, "13800000001", "pass123", "Alice").await;
    let token_b = common::create_user(&server, "13800000002", "pass123", "Bob").await;
    let (team_id, _) = common::create_team(&server, &token_a, "Hikers").await;

    // Bob is not in the team
    let resp = server
        .get(&format!("/api/locations/team/{}", team_id))
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token_b))
        .await;

    resp.assert_status(StatusCode::FORBIDDEN);
}
```

- [ ] **Step 2: 运行 location 测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && DATABASE_URL=postgres://mac@localhost/unii_db cargo test --test location_test 2>&1
```

期望：`test result: ok. 4 passed`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/tests/location_test.rs && git commit -m "test(location): add 4 integration tests for location API"
```

---

### Task 6: message_test.rs — 4 个消息测试

**Files:**
- Create: `unii-server/tests/message_test.rs`

- [ ] **Step 1: 创建 tests/message_test.rs**

```rust
mod common;

use axum::http::StatusCode;
use serde_json::json;

#[sqlx::test(migrations = "./migrations")]
async fn send_message_success(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "pass123", "Alice").await;
    let (team_id, _) = common::create_team(&server, &token, "Hikers").await;

    let resp = server
        .post("/api/messages")
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .json(&json!({
            "team_id": team_id,
            "content": "Hello team!",
            "msg_type": "text"
        }))
        .await;

    resp.assert_status(StatusCode::CREATED);
    let body: serde_json::Value = resp.json();
    assert!(body["id"].is_number());
    assert_eq!(body["content"], "Hello team!");
    assert_eq!(body["sender_nickname"], "Alice");
}

#[sqlx::test(migrations = "./migrations")]
async fn get_message_history(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "pass123", "Alice").await;
    let (team_id, _) = common::create_team(&server, &token, "Hikers").await;

    // Send two messages
    for content in ["First message", "Second message"] {
        server
            .post("/api/messages")
            .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
            .json(&json!({
                "team_id": team_id,
                "content": content,
                "msg_type": "text"
            }))
            .await;
    }

    let resp = server
        .get(&format!("/api/messages/team/{}", team_id))
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .await;

    resp.assert_status_ok();
    let body: serde_json::Value = resp.json();
    let messages = body.as_array().unwrap();
    assert!(messages.len() >= 2);
}

#[sqlx::test(migrations = "./migrations")]
async fn paginated_history(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "pass123", "Alice").await;
    let (team_id, _) = common::create_team(&server, &token, "Hikers").await;

    // Send 5 messages, collect ids
    let mut last_id: Option<i64> = None;
    for i in 0..5 {
        let resp = server
            .post("/api/messages")
            .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
            .json(&json!({
                "team_id": team_id,
                "content": format!("Message {}", i),
                "msg_type": "text"
            }))
            .await;
        let body: serde_json::Value = resp.json();
        last_id = Some(body["id"].as_i64().unwrap());
    }

    // Fetch history before the last message id → should return earlier messages
    let resp = server
        .get(&format!(
            "/api/messages/team/{}?before_id={}&limit=3",
            team_id,
            last_id.unwrap()
        ))
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .await;

    resp.assert_status_ok();
    let body: serde_json::Value = resp.json();
    let messages = body.as_array().unwrap();
    // Should return up to 3 messages before last_id
    assert!(messages.len() <= 3);
    // All returned messages should have id < last_id
    for msg in messages {
        assert!(msg["id"].as_i64().unwrap() < last_id.unwrap());
    }
}

#[sqlx::test(migrations = "./migrations")]
async fn non_member_cannot_send_message(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token_a = common::create_user(&server, "13800000001", "pass123", "Alice").await;
    let token_b = common::create_user(&server, "13800000002", "pass123", "Bob").await;
    let (team_id, _) = common::create_team(&server, &token_a, "Hikers").await;

    // Bob is not in the team
    let resp = server
        .post("/api/messages")
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token_b))
        .json(&json!({
            "team_id": team_id,
            "content": "Intruder message",
            "msg_type": "text"
        }))
        .await;

    resp.assert_status(StatusCode::FORBIDDEN);
}
```

- [ ] **Step 2: 运行 message 测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && DATABASE_URL=postgres://mac@localhost/unii_db cargo test --test message_test 2>&1
```

期望：`test result: ok. 4 passed`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/tests/message_test.rs && git commit -m "test(message): add 4 integration tests for message API"
```

---

### Task 7: user_test.rs — 4 个用户测试

**Files:**
- Create: `unii-server/tests/user_test.rs`

- [ ] **Step 1: 创建 tests/user_test.rs**

```rust
mod common;

use axum::http::StatusCode;
use serde_json::json;

#[sqlx::test(migrations = "./migrations")]
async fn get_profile(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "pass123", "Alice").await;

    let resp = server
        .get("/api/users/me")
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .await;

    resp.assert_status_ok();
    let body: serde_json::Value = resp.json();
    assert_eq!(body["nickname"], "Alice");
    assert_eq!(body["phone"], "13800000001");
}

#[sqlx::test(migrations = "./migrations")]
async fn update_nickname(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "pass123", "Alice").await;

    let resp = server
        .put("/api/users/me")
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .json(&json!({ "nickname": "AliceUpdated" }))
        .await;

    resp.assert_status_ok();
    let body: serde_json::Value = resp.json();
    assert_eq!(body["nickname"], "AliceUpdated");
}

#[sqlx::test(migrations = "./migrations")]
async fn change_password_success(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "pass123", "Alice").await;

    let resp = server
        .put("/api/users/me/password")
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .json(&json!({
            "current_password": "pass123",
            "new_password": "newpass456"
        }))
        .await;

    resp.assert_status_ok();

    // Verify new password works
    let login_resp = server
        .post("/api/auth/login")
        .json(&json!({
            "phone": "13800000001",
            "password": "newpass456"
        }))
        .await;
    login_resp.assert_status_ok();
}

#[sqlx::test(migrations = "./migrations")]
async fn change_password_wrong_old(pool: sqlx::PgPool) {
    let server = common::build_app(pool);
    let token = common::create_user(&server, "13800000001", "pass123", "Alice").await;

    let resp = server
        .put("/api/users/me/password")
        .add_header(axum::http::header::AUTHORIZATION, format!("Bearer {}", token))
        .json(&json!({
            "current_password": "wrongoldpass",
            "new_password": "newpass456"
        }))
        .await;

    resp.assert_status(StatusCode::BAD_REQUEST);
}
```

- [ ] **Step 2: 运行 user 测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && DATABASE_URL=postgres://mac@localhost/unii_db cargo test --test user_test 2>&1
```

期望：`test result: ok. 4 passed`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/tests/user_test.rs && git commit -m "test(user): add 4 integration tests for user API"
```

---

### Task 8: 最终验证 + todolist 更新

**Files:** （无代码修改）

- [ ] **Step 1: 运行全部集成测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && DATABASE_URL=postgres://mac@localhost/unii_db cargo test --test '*' 2>&1
```

期望：`test result: ok. 26 passed`

- [ ] **Step 2: 运行全部测试（含单元测试）**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && DATABASE_URL=postgres://mac@localhost/unii_db cargo test 2>&1
```

期望：全部通过，无 error。

- [ ] **Step 3: 更新 todolist.md**

将 `todolist.md` 中以下行标记为完成：

```
- [ ] **[B]** 后端集成测试：test database，覆盖完整 API 流程
```

改为：

```
- [x] **[B]** 后端集成测试：test database，覆盖完整 API 流程
```

- [ ] **Step 4: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add todolist.md && git commit -m "chore: mark backend integration tests as done"
```
