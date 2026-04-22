# 后端安全加固实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 UNII 后端添加接口限流（5/60次/分钟）、全模块输入校验（validator crate）、日志脱敏（手机号/token 掩码）。

**Architecture:** 限流使用 `governor` crate 配合 Axum `middleware::from_fn`，按 IP 限速；校验通过 `ValidatedJson<T>` extractor 统一处理，替换所有 `Json<T>` 入参；脱敏通过 `utils::mask` 工具函数在日志输出点使用。

**Tech Stack:** Rust, Axum 0.8, governor 0.6, validator 0.18, thiserror 2

---

## 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `Cargo.toml` | 修改 | 新增 governor、validator 依赖 |
| `src/extractors.rs` | 新建 | ValidatedJson<T> extractor |
| `src/error.rs` | 修改 | 新增 AppError::Validation 变体 |
| `src/utils/mod.rs` | 新建 | utils 模块入口 |
| `src/utils/mask.rs` | 新建 | mask_phone / mask_email 工具函数 |
| `src/main.rs` | 修改 | 声明新模块，添加限流中间件，更新 serve |
| `src/models/user.rs` | 修改 | RegisterRequest/LoginRequest/UpdateProfileRequest/ChangePasswordRequest 加 Validate |
| `src/models/message.rs` | 修改 | SendMessageRequest 加 Validate |
| `src/models/team.rs` | 修改 | CreateTeamRequest/UpdateTeamRequest 加 Validate |
| `src/models/location.rs` | 修改 | ReportLocationRequest 加 Validate |
| `src/auth/handler.rs` | 修改 | Json → ValidatedJson，移除手动校验，添加脱敏日志 |
| `src/user/handler.rs` | 修改 | Json → ValidatedJson |
| `src/message/handler.rs` | 修改 | Json → ValidatedJson |
| `src/team/handler.rs` | 修改 | Json → ValidatedJson |
| `src/location/handler.rs` | 修改 | Json → ValidatedJson |
| `todolist.md` | 修改 | Phase 8 后端安全条目标记为完成 |

---

### Task 1: 依赖 + 基础设施（ValidatedJson、AppError::Validation、mask 工具）

**Files:**
- Modify: `unii-server/Cargo.toml`
- Create: `unii-server/src/extractors.rs`
- Modify: `unii-server/src/error.rs`
- Create: `unii-server/src/utils/mod.rs`
- Create: `unii-server/src/utils/mask.rs`

- [ ] **Step 1: 在 Cargo.toml 添加依赖**

在 `[dependencies]` 末尾追加：

```toml
# 限流
governor = "0.6"

# 输入校验
validator = { version = "0.18", features = ["derive"] }
```

- [ ] **Step 2: 为 mask 函数写测试**

创建 `src/utils/mask.rs`：

```rust
pub fn mask_phone(phone: &str) -> String {
    if phone.len() < 7 {
        return "[MASKED]".to_string();
    }
    format!("{}****{}", &phone[..3], &phone[phone.len() - 4..])
}

pub fn mask_email(email: &str) -> String {
    match email.split_once('@') {
        Some((user, domain)) => {
            let prefix = &user[..1.min(user.len())];
            format!("{}***@{}", prefix, domain)
        }
        None => "[MASKED]".to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_mask_phone_normal() {
        assert_eq!(mask_phone("13812345678"), "138****5678");
    }

    #[test]
    fn test_mask_phone_too_short() {
        assert_eq!(mask_phone("123"), "[MASKED]");
    }

    #[test]
    fn test_mask_email_normal() {
        assert_eq!(mask_email("user@example.com"), "u***@example.com");
    }

    #[test]
    fn test_mask_email_invalid() {
        assert_eq!(mask_email("notanemail"), "[MASKED]");
    }

    #[test]
    fn test_mask_email_single_char_user() {
        assert_eq!(mask_email("a@b.com"), "a***@b.com");
    }
}
```

- [ ] **Step 3: 创建 src/utils/mod.rs**

```rust
pub mod mask;
```

- [ ] **Step 4: 运行 mask 测试确认通过**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test utils::mask 2>&1
```

期望：5 项测试全部通过。

- [ ] **Step 5: 在 error.rs 新增 Validation 变体**

在 `AppError` 枚举末尾（`Database` 之后）添加：

```rust
    #[error("Validation error: {0}")]
    Validation(#[from] validator::ValidationErrors),
```

在 `IntoResponse` 实现的 `match &self` 末尾（`Database` 分支之后）添加：

```rust
            AppError::Validation(errors) => {
                let message = errors
                    .field_errors()
                    .iter()
                    .map(|(field, errs)| {
                        let msgs: Vec<String> = errs
                            .iter()
                            .map(|e| {
                                e.message
                                    .as_ref()
                                    .map(|m| m.to_string())
                                    .unwrap_or_else(|| e.code.to_string())
                            })
                            .collect();
                        format!("{}: {}", field, msgs.join(", "))
                    })
                    .collect::<Vec<_>>()
                    .join("; ");

                let body = json!({
                    "error": format!("Validation failed: {}", message),
                    "code": 422,
                });
                (StatusCode::UNPROCESSABLE_ENTITY, axum::Json(body)).into_response()
            }
```

在 error.rs 顶部 use 语句区添加缺失的 import（若尚未存在）：

```rust
use std::collections::HashMap as _;  // 不需要，validator::ValidationErrors 已实现 Display
```

实际上不需要额外 import，validator::ValidationErrors 已自动引入。只需确保 `error.rs` 顶部有：

```rust
use axum::http::StatusCode;
use axum::response::{IntoResponse, Response};
use serde_json::json;
```

这三行已存在，无需修改。

- [ ] **Step 6: 创建 src/extractors.rs**

```rust
use axum::{
    async_trait,
    extract::{FromRequest, Request},
    Json,
};
use serde::de::DeserializeOwned;
use validator::Validate;

use crate::error::AppError;

/// 反序列化后自动运行 validator 校验的 JSON extractor。
/// 校验失败返回 422 Unprocessable Entity。
pub struct ValidatedJson<T>(pub T);

#[async_trait]
impl<T, S> FromRequest<S> for ValidatedJson<T>
where
    T: DeserializeOwned + Validate,
    S: Send + Sync,
{
    type Rejection = AppError;

    async fn from_request(req: Request, state: &S) -> Result<Self, Self::Rejection> {
        let Json(value) = Json::<T>::from_request(req, state)
            .await
            .map_err(|e| AppError::BadRequest(e.to_string()))?;
        value.validate()?;
        Ok(ValidatedJson(value))
    }
}
```

- [ ] **Step 7: 在 main.rs 中声明新模块**

在 `mod ws;` 之后添加：

```rust
mod extractors;
mod utils;
```

- [ ] **Step 8: 编译确认**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo build 2>&1
```

期望：编译成功，无 error。

- [ ] **Step 9: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/Cargo.toml unii-server/src/extractors.rs unii-server/src/error.rs unii-server/src/utils/mod.rs unii-server/src/utils/mask.rs unii-server/src/main.rs && git commit -m "feat(security): add ValidatedJson extractor, AppError::Validation, and mask utils"
```

---

### Task 2: 接口限流（governor + Axum 中间件）

**Files:**
- Modify: `unii-server/src/main.rs`

- [ ] **Step 1: 在 main.rs 顶部添加限流相关 import**

在 `use axum::Router;` 之后添加：

```rust
use axum::middleware;
use axum::response::IntoResponse;
use governor::{DefaultKeyedRateLimiter, Quota, RateLimiter};
use std::net::{IpAddr, SocketAddr};
use std::num::NonZeroU32;
use std::sync::Arc;
```

- [ ] **Step 2: 在 main.rs 底部添加 rate_limit 辅助函数**

在 `health_check` 函数之后追加：

```rust
fn make_limiter(per_minute: u32) -> Arc<DefaultKeyedRateLimiter<IpAddr>> {
    Arc::new(RateLimiter::keyed(
        Quota::per_minute(NonZeroU32::new(per_minute).unwrap()),
    ))
}

/// 从请求扩展中提取客户端 IP，调用限流器，超限返回 429。
async fn rate_limit_mw(
    req: axum::extract::Request,
    next: middleware::Next,
    limiter: Arc<DefaultKeyedRateLimiter<IpAddr>>,
) -> axum::response::Response {
    use axum::extract::ConnectInfo;
    let ip = req
        .extensions()
        .get::<ConnectInfo<SocketAddr>>()
        .map(|ci| ci.0.ip())
        .unwrap_or_else(|| IpAddr::from([127, 0, 0, 1]));

    if limiter.check_key(&ip).is_err() {
        return (
            axum::http::StatusCode::TOO_MANY_REQUESTS,
            axum::Json(serde_json::json!({"error": "Too many requests", "code": 429})),
        )
            .into_response();
    }
    next.run(req).await
}
```

- [ ] **Step 3: 在 main() 中创建限流器并应用到路由**

在 `let state = AppState { ... };` 之后添加：

```rust
    // 限流器：auth 路由 5次/分钟，其余 60次/分钟
    let auth_lim = make_limiter(5);
    let api_lim = make_limiter(60);
```

将原来的路由构建代码（`let app = Router::new()...`）替换为：

```rust
    let auth_lim_c = Arc::clone(&auth_lim);
    let api_lim_c  = Arc::clone(&api_lim);
    let api_lim_c2 = Arc::clone(&api_lim);
    let api_lim_c3 = Arc::clone(&api_lim);
    let api_lim_c4 = Arc::clone(&api_lim);

    let app = Router::new()
        .route("/health", get(health_check))
        .route("/ws", get(ws::handler::ws_handler))
        .nest(
            "/api/auth",
            auth::handler::router().layer(middleware::from_fn(move |req, next| {
                let lim = Arc::clone(&auth_lim_c);
                async move { rate_limit_mw(req, next, lim).await }
            })),
        )
        .nest(
            "/api/teams",
            team::handler::router().layer(middleware::from_fn(move |req, next| {
                let lim = Arc::clone(&api_lim_c);
                async move { rate_limit_mw(req, next, lim).await }
            })),
        )
        .nest(
            "/api/locations",
            location::handler::router().layer(middleware::from_fn(move |req, next| {
                let lim = Arc::clone(&api_lim_c2);
                async move { rate_limit_mw(req, next, lim).await }
            })),
        )
        .nest(
            "/api/messages",
            message::handler::router().layer(middleware::from_fn(move |req, next| {
                let lim = Arc::clone(&api_lim_c3);
                async move { rate_limit_mw(req, next, lim).await }
            })),
        )
        .nest(
            "/api/users",
            user::handler::router().layer(middleware::from_fn(move |req, next| {
                let lim = Arc::clone(&api_lim_c4);
                async move { rate_limit_mw(req, next, lim).await }
            })),
        )
        .layer(cors)
        .layer(TraceLayer::new_for_http())
        .with_state(state);
```

- [ ] **Step 4: 更新 serve 调用以启用 ConnectInfo**

将最后的 serve 调用：

```rust
    axum::serve(listener, app)
        .await
        .expect("Server failed");
```

替换为：

```rust
    axum::serve(
        listener,
        app.into_make_service_with_connect_info::<SocketAddr>(),
    )
    .await
    .expect("Server failed");
```

- [ ] **Step 5: 编译确认**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo build 2>&1
```

期望：编译成功，无 error。

- [ ] **Step 6: 验证限流生效（curl 测试）**

启动服务器后执行（需要服务在运行，可跳过，留给集成测试）：

```bash
for i in {1..7}; do
  curl -s -o /dev/null -w "%{http_code}\n" \
    -X POST http://localhost:3000/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"phone":"13800000000","password":"wrong"}'; 
done
```

期望：前 5 次返回 401，第 6~7 次返回 429。

- [ ] **Step 7: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/src/main.rs && git commit -m "feat(security): add IP-based rate limiting (auth: 5/min, api: 60/min)"
```

---

### Task 3: 用户 DTO 校验（models/user.rs + auth/handler.rs + user/handler.rs）

**Files:**
- Modify: `unii-server/src/models/user.rs`
- Modify: `unii-server/src/auth/handler.rs`
- Modify: `unii-server/src/user/handler.rs`

- [ ] **Step 1: 为 user.rs 中的请求 DTO 写校验测试**

在 `src/models/user.rs` 末尾添加：

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use validator::Validate;

    #[test]
    fn test_register_password_too_short() {
        let req = RegisterRequest {
            phone: Some("13812345678".to_string()),
            email: None,
            password: "123".to_string(),
            nickname: "Alice".to_string(),
        };
        assert!(req.validate().is_err());
    }

    #[test]
    fn test_register_nickname_empty() {
        let req = RegisterRequest {
            phone: Some("13812345678".to_string()),
            email: None,
            password: "password123".to_string(),
            nickname: "".to_string(),
        };
        assert!(req.validate().is_err());
    }

    #[test]
    fn test_register_invalid_email() {
        let req = RegisterRequest {
            phone: None,
            email: Some("not-an-email".to_string()),
            password: "password123".to_string(),
            nickname: "Alice".to_string(),
        };
        assert!(req.validate().is_err());
    }

    #[test]
    fn test_register_valid() {
        let req = RegisterRequest {
            phone: Some("13812345678".to_string()),
            email: None,
            password: "password123".to_string(),
            nickname: "Alice".to_string(),
        };
        assert!(req.validate().is_ok());
    }

    #[test]
    fn test_change_password_new_too_short() {
        let req = ChangePasswordRequest {
            current_password: "oldpass".to_string(),
            new_password: "123".to_string(),
        };
        assert!(req.validate().is_err());
    }
}
```

- [ ] **Step 2: 运行测试确认当前失败**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test models::user::tests 2>&1
```

期望：编译错误（validate 方法不存在），确认测试驱动。

- [ ] **Step 3: 为请求 DTO 添加 Validate derive**

在 `src/models/user.rs` 顶部 use 区添加：

```rust
use validator::Validate;
```

将 4 个请求 DTO 的 derive 宏更新如下：

```rust
#[derive(Debug, Deserialize, Validate)]
pub struct RegisterRequest {
    #[validate(length(min = 11, max = 11))]
    pub phone: Option<String>,
    #[validate(email)]
    pub email: Option<String>,
    #[validate(length(min = 6, max = 128))]
    pub password: String,
    #[validate(length(min = 1, max = 50))]
    pub nickname: String,
}

#[derive(Debug, Deserialize, Validate)]
pub struct LoginRequest {
    pub phone: Option<String>,
    pub email: Option<String>,
    #[validate(length(min = 1, max = 128))]
    pub password: String,
}

#[derive(Debug, Deserialize, Validate)]
pub struct UpdateProfileRequest {
    #[validate(length(min = 1, max = 50))]
    pub nickname: Option<String>,
    pub avatar_url: Option<String>,
    #[validate(email)]
    pub email: Option<String>,
    pub phone: Option<String>,
}

#[derive(Debug, Deserialize, Validate)]
pub struct ChangePasswordRequest {
    #[validate(length(min = 1))]
    pub current_password: String,
    #[validate(length(min = 6, max = 128))]
    pub new_password: String,
}
```

（`RefreshRequest` 无需校验，保持不变）

- [ ] **Step 4: 运行测试确认通过**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test models::user::tests 2>&1
```

期望：5 项测试全部通过。

- [ ] **Step 5: 更新 auth/handler.rs**

在 `auth/handler.rs` 顶部 use 区，将：

```rust
use axum::{Json, Router};
```

替换为：

```rust
use axum::{Json, Router};
use crate::extractors::ValidatedJson;
```

在 `register` 函数签名中，将 `Json(req): Json<RegisterRequest>` 替换为 `ValidatedJson(req): ValidatedJson<RegisterRequest>`，并删除函数体内的以下手动校验代码（这些已由 validator 处理）：

```rust
    // 删除这 10 行：
    if req.phone.is_none() && req.email.is_none() {
        return Err(AppError::BadRequest(
            "Phone or email is required".to_string(),
        ));
    }

    if req.password.len() < 6 {
        return Err(AppError::BadRequest(
            "Password must be at least 6 characters".to_string(),
        ));
    }

    if req.nickname.is_empty() || req.nickname.len() > 50 {
        return Err(AppError::BadRequest(
            "Nickname must be 1-50 characters".to_string(),
        ));
    }
```

保留 "phone or email is required" 业务逻辑检查（这是多字段约束，不是单字段格式校验）：

```rust
    if req.phone.is_none() && req.email.is_none() {
        return Err(AppError::BadRequest(
            "Phone or email is required".to_string(),
        ));
    }
```

在 `login` 函数签名中，将 `Json(req): Json<LoginRequest>` 替换为 `ValidatedJson(req): ValidatedJson<LoginRequest>`。

- [ ] **Step 6: 更新 user/handler.rs**

在 `user/handler.rs` 顶部 use 区添加：

```rust
use crate::extractors::ValidatedJson;
```

将 `update_profile` 和 `change_password` 函数签名中的 `Json(req): Json<T>` 分别替换为 `ValidatedJson(req): ValidatedJson<T>`。

完整的两个函数签名变更：

```rust
async fn update_profile(
    State(state): State<AppState>,
    auth: AuthUser,
    ValidatedJson(req): ValidatedJson<UpdateProfileRequest>,
) -> AppResult<Json<UserResponse>> {

async fn change_password(
    State(state): State<AppState>,
    auth: AuthUser,
    ValidatedJson(req): ValidatedJson<ChangePasswordRequest>,
) -> AppResult<impl IntoResponse> {
```

- [ ] **Step 7: 编译 + 全部测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test 2>&1
```

期望：全部测试通过，无 error。

- [ ] **Step 8: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/src/models/user.rs unii-server/src/auth/handler.rs unii-server/src/user/handler.rs && git commit -m "feat(security): add validator rules to user DTOs and migrate to ValidatedJson"
```

---

### Task 4: 消息 DTO 校验（models/message.rs + message/handler.rs）

**Files:**
- Modify: `unii-server/src/models/message.rs`
- Modify: `unii-server/src/message/handler.rs`

- [ ] **Step 1: 为 message DTO 写校验测试**

在 `src/models/message.rs` 末尾添加：

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use validator::Validate;

    #[test]
    fn test_send_message_content_empty() {
        let req = SendMessageRequest {
            team_id: uuid::Uuid::new_v4(),
            content: "".to_string(),
            msg_type: None,
            latitude: None,
            longitude: None,
        };
        assert!(req.validate().is_err());
    }

    #[test]
    fn test_send_message_content_too_long() {
        let req = SendMessageRequest {
            team_id: uuid::Uuid::new_v4(),
            content: "a".repeat(1001),
            msg_type: None,
            latitude: None,
            longitude: None,
        };
        assert!(req.validate().is_err());
    }

    #[test]
    fn test_send_message_valid() {
        let req = SendMessageRequest {
            team_id: uuid::Uuid::new_v4(),
            content: "Hello team!".to_string(),
            msg_type: Some("text".to_string()),
            latitude: None,
            longitude: None,
        };
        assert!(req.validate().is_ok());
    }
}
```

- [ ] **Step 2: 运行测试确认当前失败**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test models::message::tests 2>&1
```

期望：编译错误（Validate 未实现），确认测试驱动。

- [ ] **Step 3: 为 SendMessageRequest 添加 Validate**

在 `src/models/message.rs` 顶部添加：

```rust
use validator::Validate;
```

将 `SendMessageRequest` 的 derive 宏更新为：

```rust
#[derive(Debug, Deserialize, Validate)]
pub struct SendMessageRequest {
    pub team_id: Uuid,
    #[validate(length(min = 1, max = 1000))]
    pub content: String,
    pub msg_type: Option<String>,
    pub latitude: Option<f64>,
    pub longitude: Option<f64>,
}
```

（`WsSendMessage` 和 `MessageQuery` 保持不变）

- [ ] **Step 4: 运行测试确认通过**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test models::message::tests 2>&1
```

期望：3 项测试全部通过。

- [ ] **Step 5: 更新 message/handler.rs**

在 `message/handler.rs` 顶部 use 区添加：

```rust
use crate::extractors::ValidatedJson;
```

找到 `send_message` 函数（HTTP 路径），将签名中的 `Json(req): Json<SendMessageRequest>` 替换为 `ValidatedJson(req): ValidatedJson<SendMessageRequest>`。

- [ ] **Step 6: 编译 + 全部测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test 2>&1
```

期望：全部通过。

- [ ] **Step 7: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/src/models/message.rs unii-server/src/message/handler.rs && git commit -m "feat(security): add validator rules to message DTOs"
```

---

### Task 5: 团队 DTO 校验（models/team.rs + team/handler.rs）

**Files:**
- Modify: `unii-server/src/models/team.rs`
- Modify: `unii-server/src/team/handler.rs`

- [ ] **Step 1: 为 team DTO 写校验测试**

在 `src/models/team.rs` 末尾添加：

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use validator::Validate;

    #[test]
    fn test_create_team_name_empty() {
        let req = CreateTeamRequest {
            name: "".to_string(),
            is_temporary: None,
            expires_at: None,
        };
        assert!(req.validate().is_err());
    }

    #[test]
    fn test_create_team_name_too_long() {
        let req = CreateTeamRequest {
            name: "a".repeat(51),
            is_temporary: None,
            expires_at: None,
        };
        assert!(req.validate().is_err());
    }

    #[test]
    fn test_create_team_valid() {
        let req = CreateTeamRequest {
            name: "登山队".to_string(),
            is_temporary: None,
            expires_at: None,
        };
        assert!(req.validate().is_ok());
    }

    #[test]
    fn test_update_team_name_too_long() {
        let req = UpdateTeamRequest {
            name: Some("a".repeat(51)),
            is_temporary: None,
            expires_at: None,
        };
        assert!(req.validate().is_err());
    }

    #[test]
    fn test_update_team_name_none_ok() {
        let req = UpdateTeamRequest {
            name: None,
            is_temporary: Some(false),
            expires_at: None,
        };
        assert!(req.validate().is_ok());
    }
}
```

- [ ] **Step 2: 运行测试确认当前失败**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test models::team::tests 2>&1
```

期望：编译错误，确认测试驱动。

- [ ] **Step 3: 为 team DTO 添加 Validate**

在 `src/models/team.rs` 顶部添加：

```rust
use validator::Validate;
```

将 `CreateTeamRequest` 和 `UpdateTeamRequest` 更新为：

```rust
#[derive(Debug, Deserialize, Validate)]
pub struct CreateTeamRequest {
    #[validate(length(min = 1, max = 50))]
    pub name: String,
    pub is_temporary: Option<bool>,
    pub expires_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Deserialize, Validate)]
pub struct UpdateTeamRequest {
    #[validate(length(min = 1, max = 50))]
    pub name: Option<String>,
    pub is_temporary: Option<bool>,
    pub expires_at: Option<DateTime<Utc>>,
}
```

（`JoinTeamRequest` 无需校验，保持不变）

- [ ] **Step 4: 运行测试确认通过**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test models::team::tests 2>&1
```

期望：5 项测试全部通过。

- [ ] **Step 5: 更新 team/handler.rs**

在 `team/handler.rs` 顶部 use 区，将：

```rust
use axum::{Json, Router};
```

替换为：

```rust
use axum::{Json, Router};
use crate::extractors::ValidatedJson;
```

将 `create_team` 函数签名中的 `Json(req): Json<CreateTeamRequest>` 替换为 `ValidatedJson(req): ValidatedJson<CreateTeamRequest>`：

```rust
async fn create_team(
    State(state): State<AppState>,
    auth: AuthUser,
    ValidatedJson(req): ValidatedJson<CreateTeamRequest>,
) -> AppResult<impl IntoResponse> {
```

将 `update_team` 函数签名中的 `Json(req): Json<UpdateTeamRequest>` 替换为 `ValidatedJson(req): ValidatedJson<UpdateTeamRequest>`：

```rust
async fn update_team(
    State(state): State<AppState>,
    auth: AuthUser,
    Path(id): Path<Uuid>,
    ValidatedJson(req): ValidatedJson<UpdateTeamRequest>,
) -> AppResult<Json<crate::models::team::Team>> {
```

注：`join_team` 使用 `JoinTeamRequest`（无 Validate），保持 `Json<JoinTeamRequest>`，不修改。

- [ ] **Step 6: 编译 + 全部测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test 2>&1
```

期望：全部通过。

- [ ] **Step 7: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/src/models/team.rs unii-server/src/team/handler.rs && git commit -m "feat(security): add validator rules to team DTOs"
```

---

### Task 6: 位置 DTO 校验（models/location.rs + location/handler.rs）

**Files:**
- Modify: `unii-server/src/models/location.rs`
- Modify: `unii-server/src/location/handler.rs`

- [ ] **Step 1: 为 location DTO 写校验测试**

在 `src/models/location.rs` 末尾添加：

```rust
#[cfg(test)]
mod tests {
    use super::*;
    use validator::Validate;

    #[test]
    fn test_location_invalid_latitude() {
        let req = ReportLocationRequest {
            team_id: uuid::Uuid::new_v4(),
            latitude: 91.0,
            longitude: 120.0,
            altitude: None,
            accuracy: None,
            speed: None,
        };
        assert!(req.validate().is_err());
    }

    #[test]
    fn test_location_invalid_longitude() {
        let req = ReportLocationRequest {
            team_id: uuid::Uuid::new_v4(),
            latitude: 39.9,
            longitude: 181.0,
            altitude: None,
            accuracy: None,
            speed: None,
        };
        assert!(req.validate().is_err());
    }

    #[test]
    fn test_location_valid() {
        let req = ReportLocationRequest {
            team_id: uuid::Uuid::new_v4(),
            latitude: 39.9042,
            longitude: 116.4074,
            altitude: Some(50.0),
            accuracy: None,
            speed: None,
        };
        assert!(req.validate().is_ok());
    }
}
```

- [ ] **Step 2: 运行测试确认当前失败**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test models::location::tests 2>&1
```

期望：编译错误，确认测试驱动。

- [ ] **Step 3: 为 ReportLocationRequest 添加 Validate**

在 `src/models/location.rs` 顶部添加：

```rust
use validator::Validate;
```

将 `ReportLocationRequest` 更新为：

```rust
#[derive(Debug, Deserialize, Validate)]
pub struct ReportLocationRequest {
    pub team_id: Uuid,
    #[validate(range(min = -90.0, max = 90.0))]
    pub latitude: f64,
    #[validate(range(min = -180.0, max = 180.0))]
    pub longitude: f64,
    pub altitude: Option<f64>,
    pub accuracy: Option<f64>,
    pub speed: Option<f64>,
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test models::location::tests 2>&1
```

期望：3 项测试全部通过。

- [ ] **Step 5: 更新 location/handler.rs**

在 `location/handler.rs` 顶部 use 区添加：

```rust
use crate::extractors::ValidatedJson;
```

将 `report_location` 函数中的 `Json(req): Json<ReportLocationRequest>` 替换为 `ValidatedJson(req): ValidatedJson<ReportLocationRequest>`。

- [ ] **Step 6: 编译 + 全部测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test 2>&1
```

期望：全部通过。

- [ ] **Step 7: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/src/models/location.rs unii-server/src/location/handler.rs && git commit -m "feat(security): add validator rules to location DTOs"
```

---

### Task 7: 日志脱敏 + 最终验证 + todolist

**Files:**
- Modify: `unii-server/src/auth/handler.rs`
- Modify: `todolist.md`

- [ ] **Step 1: 在 auth/handler.rs 中添加脱敏日志**

在 `auth/handler.rs` 顶部 use 区添加：

```rust
use crate::utils::mask::{mask_email, mask_phone};
```

在 `register` 函数中，找到注册成功返回前（`Ok((StatusCode::CREATED, ...))` 之前），添加：

```rust
    tracing::info!(
        "User registered: phone={}, email={}",
        req.phone.as_deref().map(mask_phone).unwrap_or_default(),
        req.email.as_deref().map(mask_email).unwrap_or_default(),
    );
```

在 `login` 函数中，找到返回 `Ok(Json(AuthResponse {...}))` 之前，添加：

```rust
    tracing::info!(
        "User logged in: phone={}, email={}",
        req.phone.as_deref().map(mask_phone).unwrap_or_default(),
        req.email.as_deref().map(mask_email).unwrap_or_default(),
    );
```

注意：`mask_phone` / `mask_email` 接受 `&str`，`as_deref()` 将 `Option<String>` 转为 `Option<&str>`，然后 `.map()` 调用即可。

- [ ] **Step 2: 编译 + 全部测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test 2>&1
```

期望：全部测试通过。

- [ ] **Step 3: 确认 password_hash 不出现在日志**

审查 `auth/handler.rs`，确认没有任何 `tracing::` 调用打印了 `password_hash`、`password`、`req.password`、token 字符串等敏感字段。代码审查后在文件顶部添加注释：

```rust
// SECURITY: 日志中不得打印 password、password_hash、access_token、refresh_token。
// 用户标识符使用 mask_phone/mask_email 脱敏。
```

- [ ] **Step 4: 运行全部测试（最终验证）**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii-server && cargo test 2>&1
```

期望：全部测试通过（含 message::service 的 6 项 + 新增的 16 项 DTO 校验测试）。

- [ ] **Step 5: 更新 todolist.md**

将以下 4 行从 `[ ]` 改为 `[x]`：

```markdown
- [x] **[B]** 接口限流：登录 5次/分钟，其他 60次/分钟
- [x] **[B]** 输入校验：validator crate 严格校验所有请求参数
- [x] **[B]** WebSocket 安全：握手强制验证 JWT，无效 token 立即关闭
- [x] **[B]** 敏感数据：密码 argon2 hash，日志脱敏
```

- [ ] **Step 6: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii-server/src/auth/handler.rs todolist.md && git commit -m "feat(security): add log masking for phone/email and mark Phase 8 backend security as done"
```
