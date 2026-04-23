# 后端集成测试设计文档

**目标：** 为 UNII Rust/Axum 后端补全集成测试，覆盖全部 5 个 API 模块（auth、team、location、message、user），每个测试通过真实 HTTP 请求打完整调用链（路由→中间件→handler→service→PostgreSQL）。

**方案选择：** sqlx::test 宏（独立 DB 隔离）+ axum-test（HTTP 测试客户端）

---

## 一、基础架构

### 目录结构

```
unii-server/
  tests/
    common/
      mod.rs        ← 共享辅助函数
    auth_test.rs
    team_test.rs
    location_test.rs
    message_test.rs
    user_test.rs
```

### 隔离机制

每个测试函数标注 `#[sqlx::test(migrations = "./migrations")]`：
- sqlx 自动创建独立 PgPool（随机命名的临时数据库）
- 运行所有迁移（与生产环境完全一致）
- 测试结束后自动删除数据库
- 测试之间完全隔离，可并发运行

### 新增 dev-dependencies

```toml
[dev-dependencies]
axum-test = "15"
tokio = { version = "1", features = ["full"] }
```

### common/mod.rs 辅助函数

```rust
// 构建与生产完全一致的 Axum Router（含 JWT 中间件、限流、CORS）
pub async fn build_app(pool: PgPool) -> Router

// 注册用户并返回 JWT access token
pub async fn create_user(server: &TestServer, phone: &str, password: &str) -> String

// 生成 Authorization header 值
pub fn auth_header(token: &str) -> String  // "Bearer <token>"
```

`build_app` 复用 `main.rs` 中现有的 Router 构建逻辑，确保测试路由与生产路由完全一致。

---

## 二、测试覆盖范围

### auth_test.rs（7 个测试）

| 测试名 | 请求 | 期望状态码 |
|--------|------|------------|
| register_success | POST /api/auth/register | 201，返回 access_token |
| register_duplicate_phone | POST /api/auth/register（同手机号两次） | 409 |
| login_success | POST /api/auth/login | 200，返回 tokens |
| login_wrong_password | POST /api/auth/login（密码错） | 401 |
| refresh_token_success | POST /api/auth/refresh | 200，返回新 access_token |
| get_me_authenticated | GET /api/auth/me（有效 token） | 200，返回用户信息 |
| get_me_unauthenticated | GET /api/auth/me（无 token） | 401 |

### team_test.rs（7 个测试）

| 测试名 | 请求 | 期望状态码 |
|--------|------|------------|
| create_team_success | POST /api/teams | 201，返回 team_id 和 invite_code |
| list_teams | GET /api/teams | 200，返回数组 |
| join_team_by_invite_code | POST /api/teams/join | 200 |
| get_team_detail | GET /api/teams/:id | 200，含成员列表 |
| leave_team | DELETE /api/teams/:id/leave | 200 |
| owner_dissolve_team | DELETE /api/teams/:id | 204 |
| non_owner_cannot_dissolve | DELETE /api/teams/:id（非队长） | 403 |

### location_test.rs（4 个测试）

| 测试名 | 请求 | 期望状态码 |
|--------|------|------------|
| report_location_success | POST /api/locations | 201 |
| get_team_locations | GET /api/locations/team/:id | 200，含成员位置数组 |
| get_user_track | GET /api/locations/track/:user_id | 200，含轨迹点数组 |
| non_member_cannot_view | GET /api/locations/team/:id（非成员） | 403 |

### message_test.rs（4 个测试）

| 测试名 | 请求 | 期望状态码 |
|--------|------|------------|
| send_message_success | POST /api/messages | 201，返回消息 id |
| get_message_history | GET /api/messages/team/:id | 200，返回消息数组 |
| paginated_history | GET /api/messages/team/:id?before_id= | 200，返回 cursor 分页结果 |
| non_member_cannot_send | POST /api/messages（非成员） | 403 |

### user_test.rs（4 个测试）

| 测试名 | 请求 | 期望状态码 |
|--------|------|------------|
| get_profile | GET /api/users/me | 200，含 nickname |
| update_nickname | PUT /api/users/me | 200，nickname 已更新 |
| change_password_success | PUT /api/users/me/password | 200 |
| change_password_wrong_old | PUT /api/users/me/password（旧密码错） | 400 |

**总计：26 个集成测试**

---

## 三、测试数据流

典型的多步骤测试（如 `join_team_by_invite_code`）：

```
1. create_user(server, "130...", "pass") → token_a
2. create_user(server, "131...", "pass") → token_b
3. POST /api/teams [token_a] → { team_id, invite_code }
4. POST /api/teams/join [token_b] { invite_code } → 200
5. GET /api/teams/:team_id [token_b] → members 含 token_b 用户 ✓
```

每个测试完全自洽（自己创建所需数据），不依赖其他测试的状态。

---

## 四、文件清单

| 操作 | 文件 |
|------|------|
| 修改 | `unii-server/Cargo.toml`（添加 dev-dependencies） |
| 新建 | `unii-server/tests/common/mod.rs` |
| 新建 | `unii-server/tests/auth_test.rs` |
| 新建 | `unii-server/tests/team_test.rs` |
| 新建 | `unii-server/tests/location_test.rs` |
| 新建 | `unii-server/tests/message_test.rs` |
| 新建 | `unii-server/tests/user_test.rs` |

---

## 五、运行方式

```bash
# 运行全部集成测试
cd unii-server && cargo test --test '*' 2>&1

# 运行单个模块
cargo test --test auth_test 2>&1
cargo test --test team_test 2>&1
```

注意：`sqlx::test` 需要 `DATABASE_URL` 环境变量指向一个有权限创建/删除数据库的 PostgreSQL 用户。当前 `.env` 中 `DATABASE_URL=postgres://mac@localhost/unii_db` 满足条件（本地 mac 用户默认有 superuser 权限）。
