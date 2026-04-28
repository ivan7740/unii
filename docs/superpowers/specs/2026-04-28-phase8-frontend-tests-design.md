# Phase 8 前端测试设计规格

**目标：** 为 unii_app 添加 16 个测试（9 个 Controller 单元测试 + 7 个 Widget 测试），
覆盖 4 个核心 Controller 的业务逻辑和 3 个关键页面的渲染与交互。

**现有基线：** `test/widget_test.dart` 已有 8 个测试全部通过，本次不改动。

---

## 架构

### 依赖变更

在 `pubspec.yaml` 的 `dev_dependencies` 中添加：

```yaml
mockito: ^5.4.0
```

`build_runner` 已存在，无需重复添加。每个测试文件用 `@GenerateMocks([XxxService])` 注解，
运行 `flutter pub run build_runner build` 生成 `.mocks.dart` 文件。

### 文件结构

```
test/
  widget_test.dart                          (已有，不改动)
  controllers/
    login_controller_test.dart             (3 个测试)
    team_list_controller_test.dart         (3 个测试)
    chat_controller_test.dart              (3 个测试)
  widgets/
    login_view_test.dart                   (3 个测试)
    team_list_view_test.dart               (2 个测试)
    chat_view_test.dart                    (2 个测试)
```

### GetX 测试模式

每个 Controller 测试遵循相同的三步模式：

```dart
setUp(() {
  Get.put(MockXxxService());     // 注入 mock 依赖
  Get.put(XxxController());      // 创建被测 Controller
});
tearDown(() => Get.reset());     // 清理 GetX 容器
```

Widget 测试用 `GetMaterialApp(home: XxxView())` 包裹，并在 `setUp` 中注册全部所需 mock 服务。

---

## Controller 单元测试

### LoginController（3 个测试）

**Mock：** `AuthService`

| 测试 | 步骤 | 断言 |
|------|------|------|
| 手机号为空不调 API | 不填手机号直接调 `login()` | `errorMessage == '请输入手机号'`，`verify(mockAuth.login(...)).called(0)` |
| 登录成功 | stub `login()` 返回正常，调 `login()` | `isLoading.value == false` |
| 登录失败 | stub `login()` 抛 `DioException`，调 `login()` | `errorMessage` 非空，`isLoading.value == false` |

### TeamListController（3 个测试）

**Mock：** `TeamService`，`StorageService`

| 测试 | 步骤 | 断言 |
|------|------|------|
| 加载成功 | stub `getMyTeams()` 返回 2 个团队，等待 `loadTeams()` | `teams.length == 2`，`isLoading.value == false` |
| 加载失败 | stub `getMyTeams()` 抛异常 | `error.value` 非空，`teams.isEmpty == true` |
| 刷新后重新加载 | 调两次 `loadTeams()` | `verify(mockTeam.getMyTeams()).called(2)` |

### ChatController（3 个测试）

**Mock：** `MessageService`，`AuthService`，`WsService`，`MessageCacheService`，`TeamService`

| 测试 | 步骤 | 断言 |
|------|------|------|
| loadHistory 填充消息 | stub `getMessages()` 返回 3 条消息，等待加载 | `messages.length == 3`，`isLoading.value == false` |
| filteredMembers 按 mentionQuery 过滤 | 设置 `members = [Alice, Bob]`，`mentionQuery = 'ali'` | `filteredMembers` 只含 Alice |
| sendMessage 成功后清空输入框 | stub `sendMessage()` 成功，调 `sendMessage()` | `textController.text.isEmpty == true` |

> ChatController 在 `onInit` 读取 `Get.arguments`，测试时需通过 `Get.arguments = {'team_id': 'xxx', 'team_name': 'yyy'}` 注入。

---

## Widget 测试

### LoginView（3 个测试）

**Mock：** `AuthService`，`StorageService`

| 测试 | 步骤 | 断言 |
|------|------|------|
| 渲染不崩溃 | `pumpWidget(GetMaterialApp(home: LoginView()))` | `find.byType(LoginView)` 存在 |
| 字段存在 | 同上 | `find.byType(TextField)` 出现 ≥ 2 个 |
| 空字段点击登录显示错误 | tap 登录按钮，`pumpAndSettle()` | `find.text('请输入手机号')` 存在 |

### TeamListView（2 个测试）

**Mock：** `TeamService`，`StorageService`

| 测试 | 步骤 | 断言 |
|------|------|------|
| 空列表显示空状态 | stub `getMyTeams()` 返回 `[]`，pump | `find.byType(EmptyStateWidget)` 存在 |
| 有团队显示列表项 | stub `getMyTeams()` 返回 1 个团队，pump | `find.text('测试团队')` 存在 |

### ChatView（2 个测试）

**Mock：** `MessageService`，`AuthService`，`WsService`，`MessageCacheService`，`TeamService`

| 测试 | 步骤 | 断言 |
|------|------|------|
| 渲染不崩溃，输入框存在 | pump ChatView（注入 team_id arguments） | `find.byType(TextField)` 存在 |
| 输入文字后点击发送 | enterText → tap 发送按钮，`pumpAndSettle()` | `verify(mockMessage.sendMessage(...)).called(1)` |

---

## 完成标准

- `flutter test` 全部 24 个测试通过（8 个已有 + 16 个新增）
- `flutter analyze` 无 error
- `todolist.md` 中两项前端测试标记为 `[x]`
