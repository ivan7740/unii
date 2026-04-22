# 后端安全加固设计文档

**日期：** 2026-04-23
**范围：** Phase 8 — 接口限流、输入校验、日志脱敏
**技术栈：** Rust + Axum 0.8 + tower-governor + validator

---

## 背景

Phase 8 安全加固需要在现有后端补充三项生产级安全措施：接口限流防止暴力破解、统一输入校验替代散落的手动判断、以及日志脱敏保护用户 PII。

两项 todolist 条目（WS JWT 握手验证、argon2 密码 hash）已在 Phase 4/5 中实现，本文档仅涵盖需要新增代码的三项。

---

## 一、接口限流

### 方案

使用 `tower-governor` crate，基于令牌桶算法，按客户端 IP 限速。

### 依赖

```toml
tower-governor = { version = "0.4", features = ["axum"] }
```

### 两套限速配置

| 层 | 路由 | 限制 | 补充速率 |
|---|---|---|---|
| `login_governor` | `POST /api/auth/login` | 5 次/分钟 | 每 12s 补 1 个 |
| `api_governor` | 所有 `/api/*` 路由 | 60 次/分钟 | 每 1s 补 1 个 |

### main.rs 集成

```rust
use tower_governor::{governor::GovernorConfigBuilder, GovernorLayer};

// 登录专用限速（5/min）
let login_governor = Arc::new(
    GovernorConfigBuilder::default()
        .per_second(12)
        .burst_size(5)
        .finish()
        .unwrap(),
);

// 通用限速（60/min）
let api_governor = Arc::new(
    GovernorConfigBuilder::default()
        .per_second(1)
        .burst_size(60)
        .finish()
        .unwrap(),
);
```

登录路由单独提取并叠加 `login_governor`；其余 API 路由共享 `api_governor`。

### 超限响应

- HTTP 429 Too Many Requests
- 响应头：`X-RateLimit-Remaining: 0`、`Retry-After: <seconds>`
- tower-governor 默认自动处理

---

## 二、输入校验

### 方案

使用 `validator` crate 的 derive 宏，新增 `ValidatedJson<T>` extractor 统一处理校验失败，替代散落的手动 `if` 判断。

### 依赖

```toml
validator = { version = "0.18", features = ["derive"] }
```

### ValidatedJson Extractor

新建 `src/extractors.rs`：

```rust
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
        value.validate().map_err(|e| AppError::Validation(e))?;
        Ok(ValidatedJson(value))
    }
}
```

`AppError` 新增 `Validation(ValidationErrors)` 变体，序列化为：

```json
{
  "error": "validation_error",
  "fields": {
    "password": [{ "code": "length", "message": "密码长度须为 6-128 位" }]
  }
}
```

### DTO 校验规则

**auth/models（RegisterRequest）**

```rust
#[derive(Validate, Deserialize)]
pub struct RegisterRequest {
    #[validate(custom(function = "validate_phone_or_email"))]
    pub phone: Option<String>,
    #[validate(email)]
    pub email: Option<String>,
    #[validate(length(min = 6, max = 128))]
    pub password: String,
    #[validate(length(min = 1, max = 50))]
    pub nickname: String,
}
```

**auth/models（LoginRequest）**

```rust
#[derive(Validate, Deserialize)]
pub struct LoginRequest {
    pub phone: Option<String>,
    pub email: Option<String>,
    #[validate(length(min = 1))]
    pub password: String,
}
```

**message/models（SendMessageRequest）**

```rust
#[derive(Validate, Deserialize)]
pub struct SendMessageRequest {
    pub team_id: Uuid,
    #[validate(length(min = 1, max = 1000))]
    pub content: String,
    #[validate(custom(function = "validate_msg_type"))]
    pub msg_type: String,
}
```

**team/models（CreateTeamRequest、UpdateTeamRequest）**

```rust
#[validate(length(min = 1, max = 50))]
pub name: String,
```

**location/models（UpdateLocationRequest）**

```rust
#[validate(range(min = -90.0, max = 90.0))]
pub latitude: f64,
#[validate(range(min = -180.0, max = 180.0))]
pub longitude: f64,
```

### Handler 迁移

所有 `Json<T>` extractor 替换为 `ValidatedJson<T>`，移除等效的手动校验代码（如 auth/handler.rs 中的 `if req.password.len() < 6` 等）。

---

## 三、日志脱敏

### 脱敏字段

| 字段 | 策略 |
|---|---|
| 密码/password_hash | 不出现在任何日志（已确认，加保护注释） |
| JWT token | 替换为 `[REDACTED]` |
| 手机号 | `mask_phone()` → `138****1234` |
| 邮箱 | `mask_email()` → `u***@example.com` |

### 工具函数

新建 `src/utils/mask.rs`：

```rust
pub fn mask_phone(phone: &str) -> String {
    if phone.len() < 7 { return "[MASKED]".to_string(); }
    format!("{}****{}", &phone[..3], &phone[phone.len()-4..])
}

pub fn mask_email(email: &str) -> String {
    match email.split_once('@') {
        Some((user, domain)) => format!("{}***@{}", &user[..1.min(user.len())], domain),
        None => "[MASKED]".to_string(),
    }
}
```

### 应用位置

- `auth/handler.rs`：注册/登录成功日志使用 `mask_phone`/`mask_email`
- `ws/handler.rs`：连接日志只记录 `user_id`（已合规，无需修改）
- `TraceLayer`：默认不记录请求体，无需修改

---

## 四、已完成项确认

| 条目 | 位置 | 状态 |
|---|---|---|
| WS JWT 握手验证 | `ws/handler.rs` L26-35，升级前验证，无效返回 401 | ✅ 已完成 |
| argon2 密码 hash | `auth/handler.rs` L72-77，注册时 hash，登录时 verify | ✅ 已完成 |

---

## 文件变更清单

| 文件 | 操作 |
|---|---|
| `Cargo.toml` | 新增 `tower-governor`、`validator` |
| `src/main.rs` | 添加两套 GovernorLayer，调整路由结构 |
| `src/extractors.rs` | 新建，ValidatedJson extractor |
| `src/error.rs` | 新增 Validation 变体 |
| `src/utils/mask.rs` | 新建，mask_phone / mask_email |
| `src/utils/mod.rs` | 新建（或更新） |
| `src/models/user.rs` | RegisterRequest、LoginRequest 添加 Validate derive |
| `src/models/message.rs` | SendMessageRequest 添加 Validate derive |
| `src/models/team.rs` | Create/UpdateTeamRequest 添加 Validate derive |
| `src/models/location.rs` | UpdateLocationRequest 添加 Validate derive |
| `src/auth/handler.rs` | Json → ValidatedJson，移除手动校验，添加脱敏日志 |
| `src/team/handler.rs` | Json → ValidatedJson |
| `src/message/handler.rs` | Json → ValidatedJson |
| `src/location/handler.rs` | Json → ValidatedJson |
| `todolist.md` | 全部 Phase 8 后端安全条目标记为完成 |

---

## 测试策略

- 限流：发送 6 次登录请求，验证第 6 次返回 429
- 输入校验：发送缺失字段/超长字段请求，验证返回 422 + 字段错误
- 日志脱敏：注册/登录后检查日志输出，确认手机号被掩码
- 回归：`cargo test` 全部通过
