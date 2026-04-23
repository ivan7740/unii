# UNII 项目开发流程 (Todolist)

> **策略**：后端先行，前端跟进联调。每个 Phase 内 [B] 任务优先完成，[F] 任务随后进行，阶段末尾前后端联调。

---

## Phase 0: 项目初始化与基础设施

### 后端初始化
- [x] **[B]** `cargo init unii-server`，配置 Cargo.toml 添加依赖：axum 0.8+, sqlx (postgres, uuid, chrono, migrate), tokio, serde/serde_json, jsonwebtoken, tower-http (cors, trace), tracing, tracing-subscriber, uuid, chrono, dotenvy, dashmap
- [x] **[B]** 创建 `.env`，定义 DATABASE_URL, JWT_SECRET, JWT_EXPIRATION, SERVER_HOST, SERVER_PORT
- [x] **[B]** 实现 `src/config.rs`：环境变量加载，AppConfig 结构体
- [x] **[B]** 实现 `src/error.rs`：AppError 枚举（NotFound, Unauthorized, BadRequest, Internal, Conflict），实现 IntoResponse，统一 JSON 错误格式
- [x] **[B]** 实现 `src/db/pool.rs`：sqlx PgPool 连接池初始化
- [x] **[B]** 搭建 `src/main.rs` 骨架：初始化 tracing → 加载配置 → 创建连接池 → 构建 Router → 启动 server
- [x] **[B]** 配置 tower-http 中间件：CorsLayer + TraceLayer

### 数据库初始化
- [x] **[B]** 安装 PostgreSQL 17（升级自 16 以兼容 PostGIS），创建数据库 `unii_db`，启用 PostGIS 3.6 扩展
- [x] **[B]** 安装 sqlx-cli 0.8.6：`cargo install sqlx-cli --no-default-features --features postgres`
- [x] **[B]** 迁移 1：创建 users 表
- [x] **[B]** 迁移 2：创建 teams 表 + team_members 表
- [x] **[B]** 迁移 3：创建 locations 表（PostGIS GEOGRAPHY 列 + 索引）
- [x] **[B]** 迁移 4：创建 messages 表 + 索引
- [x] **[B]** 运行 `sqlx migrate run` 验证全部迁移

### 前端初始化
- [x] **[F]** `flutter create unii_app`，清理模板代码
- [x] **[F]** 配置 pubspec.yaml 依赖：get, dio, web_socket_channel, hive, hive_flutter, geolocator, google_maps_flutter, flutter_local_notifications, path_provider, json_annotation, build_runner, json_serializable
- [x] **[F]** 搭建目录结构：`lib/app/{routes,bindings,theme}/`, `lib/modules/`, `lib/models/`, `lib/services/`, `lib/utils/`
- [x] **[F]** 实现 `app_theme.dart`：亮色/暗色主题，品牌色系
- [x] **[F]** 实现 `constants.dart`：API 基础 URL, WebSocket URL, 存储 key 常量
- [x] **[F]** 配置 Android/iOS/macOS 权限：位置、后台定位、网络、通知
- [x] **[F]** ~~配置 Google Maps API Key~~ 已切换为 flutter_map + OpenStreetMap（免费无需 Key）

### 前端全局服务层
- [x] **[F]** 实现 `storage_service.dart`：Hive 初始化，token 存取，通用 KV 存储封装
- [x] **[F]** 实现 `api_service.dart`：dio 封装，拦截器（自动附加 JWT、统一错误处理、401 自动 refresh）
- [x] **[F]** 实现 `app_pages.dart`：GetX 路由表
- [x] **[F]** 实现 `initial_binding.dart`：注册全局服务
- [x] **[F]** 实现 `main.dart`：初始化 Hive → GetMaterialApp 启动

---

## Phase 1: 认证模块

### 后端 Auth
- [x] **[B]** 实现 `models/user.rs`：User 结构体 (sqlx::FromRow)，RegisterRequest / LoginRequest / RefreshRequest / AuthResponse / UserResponse DTO
- [x] **[B]** 实现 `auth/jwt.rs`：Claims 定义，encode_access_token / encode_refresh_token / decode_token
- [x] **[B]** 实现 `auth/middleware.rs`：AuthUser extractor，从 Authorization header 提取验证 JWT，注入 user_id
- [x] **[B]** 实现 `auth/handler.rs`：register（argon2 hash）、login、refresh、sms-code（桩实现）、get_me
- [x] **[B]** 注册 `/api/auth/*` 路由组
- [x] **[B]** 编写 auth 模块测试：注册、登录、token 刷新、无效 token 拒绝（13 项 curl 测试全部通过）

### 前端 Auth
- [x] **[F]** 实现 `models/user.dart`：User, AuthResponse model
- [x] **[F]** 实现 `auth_service.dart`：GetxService，register / login / fetchMe / logout / isLoggedIn
- [x] **[F]** 实现 `login_controller.dart` + `register_controller.dart`
- [x] **[F]** 实现 `login_view.dart`（手机号+密码输入）+ `register_view.dart`
- [x] **[F]** 实现 `auth_binding.dart` + auth 路由 + splash 路由 + home 占位路由
- [x] **[F]** 实现 SplashScreen：检查 token 有效性，分流到主页或登录页
- [x] **[F]** 联调：注册 → 登录 → token 存储 → 自动附加 token → refresh 流程（7 步联调全部通过）

---

## Phase 2: 团队模块

### 后端 Team
- [x] **[B]** 实现 `models/team.rs`：Team, TeamMember 结构体，相关 DTO
- [x] **[B]** 实现 `team/service.rs`：创建团队（生成 6 位邀请码）、加入、退出、解散、更新、列表、详情
- [x] **[B]** 实现 `team/handler.rs`：7 个接口（POST/GET/PUT/DELETE），鉴权中间件
- [x] **[B]** 注册 `/api/teams/*` 路由组
- [x] **[B]** 编写 team 模块测试（18 项 curl 测试全部通过）

### 前端 Team
- [x] **[F]** 实现 `models/team.dart`：Team, TeamMember model
- [x] **[F]** 实现 team_list_controller / team_detail_controller / create_team_controller / join_team_controller
- [x] **[F]** 实现 team_list_view（卡片列表）/ team_detail_view（成员+邀请码）/ create_team_view / join_team_view
- [x] **[F]** 实现 team_binding
- [x] **[F]** 实现主页底部导航栏（地图、团队、消息、设置四个 tab）
- [x] **[F]** 联调：创建团队 → 获取邀请码 → 加入 → 查看成员 → 退出/解散

---

## Phase 3: 定位模块 - HTTP 部分

### 后端 Location (REST)
- [x] **[B]** 实现 `models/location.rs`：Location 结构体（PostGIS point 处理），相关 DTO
- [x] **[B]** 实现 `location/service.rs`：上报位置（ST_MakePoint）、获取团队成员最新位置、获取轨迹、计算距离（ST_Distance）
- [x] **[B]** 实现 `location/handler.rs`：POST 上报 / GET 团队位置 / GET 用户轨迹
- [x] **[B]** 注册 `/api/locations/*` 路由组
- [x] **[B]** 编写 location 模块测试（26 项 curl 测试全部通过，含 PostGIS 坐标验证）
- [x] **[B]** 修复 locations 表外键 CASCADE（迁移 000005）

### 前端 Location (基础地图)
- [x] **[F]** 实现 `location_service.dart`：GetxService，HTTP 位置上报/查询封装
- [x] **[F]** 实现 `models/location.dart`：LocationData, MemberLocation, TrackPoint model
- [x] **[F]** 实现 map_controller：加载成员位置，自动刷新
- [x] **[F]** 实现 member_marker widget：自定义成员标记（昵称标签+定位圆点）
- [x] **[F]** 实现 map_view：flutter_map + OpenStreetMap 地图 + markers + 底部成员面板 + 刷新按钮
- [x] **[F]** 实现 location_binding
- [x] **[F]** 实现 HTTP 位置上报逻辑（WebSocket 降级方案）
- [x] **[F]** 联调：上报位置 → 查询团队位置 → 轨迹查询（API 层联调通过）

---

## Phase 4: WebSocket 核心

### 后端 WebSocket
- [x] **[B]** 实现 `ws/manager.rs`：连接管理器
  - `DashMap<Uuid, UserConnection>`（sender + 已订阅 team_ids）
  - `DashMap<Uuid, HashSet<Uuid>>`（team_id → 在线 user_ids）
  - 方法：add/remove_connection, subscribe/unsubscribe_team, broadcast_to_team, send_to_user
- [x] **[B]** 实现 WS 握手：`GET /ws`，JWT 验证，升级 WebSocket
- [x] **[B]** 实现消息分发器：按 `type` 分发（location_update / send_message / join_team_channel / leave_team_channel / ping）
- [x] **[B]** 实现连接生命周期：注册、清理、心跳超时检测
- [x] **[B]** 实现 `location/ws.rs`：位置更新处理 + 团队广播
- [x] **[B]** 实现 `message/ws.rs`：消息处理 + 团队广播
- [x] **[B]** 实现在线状态广播：上线/下线时广播 `member_online` 到所有团队
- [x] **[B]** 注册 `/ws` 路由，WsManager 作为 Axum State

### 前端 WebSocket
- [x] **[F]** 实现 `ws_service.dart`：GetxService
  - 连接管理：JWT 附带、自动重连（指数退避 1s→2s→4s→8s→max 30s）
  - 消息收发：JSON 序列化，按 `type` 分发回调
  - 心跳：定时 ping，超时重连
  - 连接状态：Rx\<ConnectionStatus\>（connected/connecting/disconnected）
- [x] **[F]** 更新 map_controller：监听 `member_location` 实时更新 markers
- [x] **[F]** 实现位置上报 worker：WS 定时发送 location_update，断连自动切 HTTP
- [x] **[F]** 实现团队频道订阅：切换活动团队时发送 join/leave_team_channel
- [x] **[F]** 联调：WS 连接 → 位置实时推送 → 地图实时更新 → 断连重连 → 降级 HTTP

---

## Phase 5: 消息模块

### 后端 Message
- [x] **[B]** 实现 `models/message.rs`：Message 结构体，SendMessageRequest, MessageResponse DTO
- [x] **[B]** 实现 `message/service.rs`：发送消息、分页查询历史（cursor-based）、SOS 消息处理
- [x] **[B]** 实现 `message/handler.rs`：GET 历史消息（before_id + limit）/ POST 发送消息
- [x] **[B]** 注册 `/api/messages/*` 路由组
- [x] **[B]** 更新 WS 处理：send_message 存储后广播 new_message，SOS 广播 sos_alert（Phase 4 已实现）
- [x] **[B]** 编写 message 模块测试（9 项 curl 测试全部通过）

### 前端 Message
- [x] **[F]** 实现 `models/message.dart`：Message model，QuickMessage 预设短语列表
- [x] **[F]** 实现 chat_controller：加载历史（分页）、WS 发送/接收消息、监听 sos_alert 弹窗
- [x] **[F]** 实现 chat_view：消息列表 + 输入框 + 发送按钮 + 快捷消息栏
- [x] **[F]** 实现 message_list_view：消息 tab 页（各团队最近消息预览）
- [x] **[F]** 实现 message_bubble widget：气泡组件（自己/他人、文字/快捷/SOS 不同样式）
- [x] **[F]** 实现 quick_message_bar widget
- [x] **[F]** 实现 SOS 功能：长按 SOS 按钮 → 发送附位置的 SOS 消息 → 全团队弹窗
- [x] **[F]** 实现 message_binding
- [x] **[F]** 联调：文字消息 → 实时接收 → 历史加载 → 快捷消息 → SOS 求助

---

## Phase 6: 设置模块与用户资料

### 后端 Settings/User
- [x] **[B]** 实现用户资料接口：GET/PUT `/api/users/me`、PUT `/api/users/me/password`、DELETE `/api/users/me`
- [x] **[B]** 注册 `/api/users/*` 路由组

### 前端 Settings
- [x] **[F]** 实现 settings_controller：加载/更新资料、位置频率、隐私、通知设置
- [x] **[F]** 实现 profile_controller：资料编辑表单
- [x] **[F]** 实现 settings_view：设置主页（资料卡片 + 设置项列表）
- [x] **[F]** 实现 profile_edit_view / location_settings_view（三档切换）/ privacy_settings_view
- [x] **[F]** 实现 settings_binding
- [x] **[F]** Hive 本地持久化设置项（位置频率、地图样式等偏好）
- [x] **[F]** 联调：查看资料 → 编辑 → 修改密码 → 设置项生效

---

## Phase 7: 增强功能与优化

### 在线状态
- [x] **[B]** 完善在线状态逻辑：WS 连接/断开时广播状态变更到所有团队
- [x] **[F]** 团队成员列表和地图 marker 显示在线/离线状态（绿色/灰色圆点）

### 轨迹功能
- [ ] **[B]** 优化轨迹查询：时间范围筛选、Douglas-Peucker 轨迹简化
- [x] **[F]** 实现 track_view：Polyline 轨迹绘制、时间轴回放、播放/暂停
- [x] **[F]** 实现 track_controller：轨迹数据加载、回放动画

### 地图增强
- [x] **[F]** 地图样式切换：标准/卫星/地形
- [x] **[F]** 成员间距离显示：底部面板列出各成员距离
- [x] **[F]** 成员方向指示：地图边缘箭头指示屏幕外成员方向

### 消息增强
- [x] **[F]** 消息本地缓存：Hive 存储已加载消息，离线可查看
- [x] **[F]** @ 成员功能：输入 @ 弹出成员选择列表
- [x] **[B]** 后端 @ 消息处理：解析 @ 内容，对被 @ 用户发专门通知

### 通知
- [x] **[F]** 集成 flutter_local_notifications：SOS 本地通知、新消息通知（后台时）
- [x] **[F]** 通知点击跳转到对应团队聊天页

### 后台定位
- [x] **[F]** 集成 flutter_background_service：后台继续上报位置
- [x] **[F]** 电量优化：后台自动降低上报频率

---

## Phase 8: 安全加固与测试

### 后端安全
- [x] **[B]** 接口限流：登录 5次/分钟，其他 60次/分钟
- [x] **[B]** 输入校验：validator crate 严格校验所有请求参数
- [x] **[B]** WebSocket 安全：握手强制验证 JWT，无效 token 立即关闭
- [x] **[B]** 敏感数据：密码 argon2 hash，日志脱敏

### 测试
- [ ] **[B]** 后端集成测试：test database，覆盖完整 API 流程
- [ ] **[F]** 前端 Controller 单元测试（mockito mock ApiService）
- [ ] **[F]** 前端 Widget 测试：关键页面渲染测试

### 错误处理
- [x] **[F]** 全局异常捕获 + Flutter 异常上报
- [x] **[F]** 网络异常友好提示：断网、超时、服务不可用
- [x] **[F]** 空状态页面：无团队引导、无消息提示

---

## Phase 9: 打磨与发布准备

- [ ] **[F]** UI 打磨：动画过渡、骨架屏、下拉刷新
- [ ] **[F]** 暗色模式适配
- [ ] **[B]** 生产环境配置：环境变量、连接池调优、日志级别
- [ ] **[B]** Docker 容器化：Dockerfile (multi-stage build) + docker-compose.yml
- [ ] **[F]** APP 图标和启动页定制
- [ ] **[F]** Android release 签名 / iOS 证书配置
- [ ] **[B]** API 文档（可选：utoipa 生成 OpenAPI/Swagger）
- [ ] **[F]** 端到端冒烟测试

---

## 依赖关系

```
Phase 0 → Phase 1 → Phase 2 → Phase 3 → Phase 4 → Phase 5 → Phase 7 → Phase 8 → Phase 9
                                                      ↘ Phase 6（可并行）↗
```
