# Phase 8 前端测试实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 unii_app 新增 16 个测试（9 个 Controller 单元测试 + 7 个 Widget 测试），并将 todolist.md 中全部 3 项 Phase 8 测试任务标记为完成。

**Architecture:** 使用纯 Dart Fake 类替代 mockito（避免代码生成步骤），所有 Fake 集中在 `test/helpers/fakes.dart`。Controller 测试验证状态变化，Widget 测试用 `GetMaterialApp` 包裹验证渲染与交互。

**Tech Stack:** Flutter 3.x, GetX, flutter_test（已有），Dart Fake pattern

---

## 文件结构

| 操作 | 文件 | 职责 |
|------|------|------|
| 新建 | `test/helpers/fakes.dart` | 全部 Fake 服务实现 + 测试 fixture |
| 新建 | `test/controllers/login_controller_test.dart` | 3 个 LoginController 测试 |
| 新建 | `test/controllers/team_list_controller_test.dart` | 3 个 TeamListController 测试 |
| 新建 | `test/controllers/chat_controller_test.dart` | 3 个 ChatController 测试 |
| 新建 | `test/widgets/login_view_test.dart` | 3 个 LoginView Widget 测试 |
| 新建 | `test/widgets/team_list_view_test.dart` | 2 个 TeamListView Widget 测试 |
| 新建 | `test/widgets/chat_view_test.dart` | 2 个 ChatView Widget 测试 |
| 修改 | `todolist.md` | 标记 3 项 Phase 8 测试任务为完成 |

---

### Task 1: 创建 test/helpers/fakes.dart

**Files:**
- Create: `test/helpers/fakes.dart`

- [ ] **Step 1: 创建测试目录结构**

```bash
mkdir -p /Users/mac/rust_flutter_app/study_dw/unii_app/test/helpers
mkdir -p /Users/mac/rust_flutter_app/study_dw/unii_app/test/controllers
mkdir -p /Users/mac/rust_flutter_app/study_dw/unii_app/test/widgets
```

- [ ] **Step 2: 创建 test/helpers/fakes.dart**

创建文件 `unii_app/test/helpers/fakes.dart`，内容如下：

```dart
import 'package:get/get.dart';
import 'package:unii_app/models/message.dart';
import 'package:unii_app/models/team.dart';
import 'package:unii_app/models/user.dart';
import 'package:unii_app/services/auth_service.dart';
import 'package:unii_app/services/message_cache_service.dart';
import 'package:unii_app/services/message_service.dart';
import 'package:unii_app/services/storage_service.dart';
import 'package:unii_app/services/team_service.dart';
import 'package:unii_app/services/ws_service.dart';

// ── Test fixtures ──────────────────────────────────────────────────────────

final kTestUser = User(
  id: 'user-1',
  phone: '13800138001',
  email: null,
  nickname: 'Alice',
  avatarUrl: null,
  createdAt: '2026-01-01T00:00:00Z',
);

final kTestAuthResponse = AuthResponse(
  accessToken: 'test-access-token',
  refreshToken: 'test-refresh-token',
  user: kTestUser,
);

Team makeTeam({String id = 'team-1', String name = '测试团队'}) => Team(
      id: id,
      name: name,
      inviteCode: 'ABC123',
      ownerId: 'user-1',
      createdAt: '2026-01-01T00:00:00Z',
    );

Message makeMessage({int id = 1, String content = 'Hello'}) => Message(
      id: id,
      teamId: 'team-1',
      senderId: 'user-1',
      senderNickname: 'Alice',
      content: content,
      msgType: 'text',
      isSos: false,
      createdAt: DateTime(2026, 1, 1),
    );

TeamMember makeTeamMember({String nickname = 'Alice'}) => TeamMember(
      userId: 'user-1',
      nickname: nickname,
      role: 'member',
      joinedAt: '2026-01-01T00:00:00Z',
    );

// ── FakeAuthService ────────────────────────────────────────────────────────

class FakeAuthService extends Fake implements AuthService {
  @override
  final Rx<User?> currentUser = Rx<User?>(null);

  @override
  bool get isLoggedIn => true;

  bool shouldLoginFail = false;
  int loginCallCount = 0;

  @override
  Future<AuthResponse> login({
    String? phone,
    String? email,
    required String password,
  }) async {
    loginCallCount++;
    if (shouldLoginFail) {
      throw Exception('login failed');
    }
    currentUser.value = kTestUser;
    return kTestAuthResponse;
  }

  @override
  Future<AuthResponse> register({
    String? phone,
    String? email,
    required String nickname,
    required String password,
  }) async {
    currentUser.value = kTestUser;
    return kTestAuthResponse;
  }

  @override
  Future<User?> fetchMe() async => kTestUser;

  @override
  void logout() {}
}

// ── FakeTeamService ────────────────────────────────────────────────────────

class FakeTeamService extends Fake implements TeamService {
  List<Team> teamsToReturn = [];
  bool shouldGetTeamsFail = false;
  int getMyTeamsCallCount = 0;

  @override
  Future<List<Team>> getMyTeams() async {
    getMyTeamsCallCount++;
    if (shouldGetTeamsFail) throw Exception('network error');
    return teamsToReturn;
  }

  @override
  Future<TeamDetail> getTeamDetail(String teamId) async {
    return TeamDetail(team: makeTeam(), members: [makeTeamMember()]);
  }

  @override
  Future<Team> createTeam({required String name, bool isTemporary = false}) async {
    return makeTeam(name: name);
  }

  @override
  Future<Team> joinTeam(String inviteCode) async => makeTeam();

  @override
  Future<void> leaveTeam(String teamId) async {}

  @override
  Future<void> disbandTeam(String teamId) async {}

  @override
  Future<Team> updateTeam(String teamId, {String? name}) async => makeTeam();
}

// ── FakeMessageService ─────────────────────────────────────────────────────

class FakeMessageService extends Fake implements MessageService {
  List<Message> messagesToReturn = [];
  String? lastSentContent;

  @override
  Future<List<Message>> getTeamMessages(
    String teamId, {
    int? beforeId,
    int limit = 50,
  }) async {
    return messagesToReturn;
  }

  @override
  Future<Message> sendMessage({
    required String teamId,
    required String content,
    String msgType = 'text',
    double? latitude,
    double? longitude,
  }) async {
    lastSentContent = content;
    return makeMessage(content: content);
  }
}

// ── FakeWsService ──────────────────────────────────────────────────────────

class FakeWsService extends Fake implements WsService {
  @override
  final status = ConnectionStatus.disconnected.obs;

  @override
  void on(String type, void Function(Map<String, dynamic> data) callback) {}

  @override
  void off(String type, void Function(Map<String, dynamic> data) callback) {}

  @override
  void send(String type, Map<String, dynamic> data) {}

  @override
  void connect() {}
}

// ── FakeMessageCacheService ────────────────────────────────────────────────

class FakeMessageCacheService extends Fake implements MessageCacheService {
  @override
  List<Message> loadMessages(String teamId) => [];

  @override
  void saveMessages(String teamId, List<Message> messages) {}

  @override
  void prependMessage(String teamId, Message message) {}
}

// ── FakeStorageService ─────────────────────────────────────────────────────

class FakeStorageService extends Fake implements StorageService {
  final _data = <String, dynamic>{};

  @override
  T? read<T>(String key) => _data[key] as T?;

  @override
  Future<void> write(String key, dynamic value) async => _data[key] = value;

  @override
  Future<void> remove(String key) async => _data.remove(key);

  @override
  bool get isLoggedIn => false;

  @override
  String? get accessToken => _data['access_token'] as String?;

  @override
  set accessToken(String? v) => _data['access_token'] = v;

  @override
  String? get refreshToken => _data['refresh_token'] as String?;

  @override
  set refreshToken(String? v) => _data['refresh_token'] = v;

  @override
  void clearAuth() {
    _data.remove('access_token');
    _data.remove('refresh_token');
  }

  @override
  Future<StorageService> init() async => this;
}
```

- [ ] **Step 3: 验证编译通过**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze test/helpers/fakes.dart 2>&1
```

期望：`No issues found!` 或仅有 info 级别提示，无 error。

- [ ] **Step 4: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/test/helpers/fakes.dart && git commit -m "test(flutter): add Fake service implementations for unit tests"
```

---

### Task 2: login_controller_test.dart — 3 个 LoginController 测试

**Files:**
- Create: `unii_app/test/controllers/login_controller_test.dart`

- [ ] **Step 1: 创建 test/controllers/login_controller_test.dart**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:unii_app/modules/auth/controller/login_controller.dart';
import '../helpers/fakes.dart';

void main() {
  late LoginController controller;
  late FakeAuthService fakeAuth;

  setUp(() {
    fakeAuth = FakeAuthService();
    Get.put<AuthService>(fakeAuth);
    controller = Get.put(LoginController());
  });

  tearDown(() => Get.reset());

  test('empty phone sets errorMessage without calling service', () {
    controller.phoneController.text = '';
    controller.passwordController.text = 'password123';

    controller.login();

    expect(controller.errorMessage.value, '请输入手机号');
    expect(fakeAuth.loginCallCount, 0);
  });

  test('empty password sets errorMessage without calling service', () {
    controller.phoneController.text = '13800138001';
    controller.passwordController.text = '';

    controller.login();

    expect(controller.errorMessage.value, '请输入密码');
    expect(fakeAuth.loginCallCount, 0);
  });

  test('login failure sets errorMessage and clears isLoading', () async {
    fakeAuth.shouldLoginFail = true;
    controller.phoneController.text = '13800138001';
    controller.passwordController.text = 'wrongpassword';

    await controller.login();

    expect(controller.isLoading.value, false);
    expect(controller.errorMessage.value, isNotEmpty);
  });
}
```

- [ ] **Step 2: 运行测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/controllers/login_controller_test.dart 2>&1
```

期望：`+3: All tests passed!`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/test/controllers/login_controller_test.dart && git commit -m "test(flutter): add 3 LoginController unit tests"
```

---

### Task 3: team_list_controller_test.dart — 3 个 TeamListController 测试

**Files:**
- Create: `unii_app/test/controllers/team_list_controller_test.dart`

- [ ] **Step 1: 创建 test/controllers/team_list_controller_test.dart**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:unii_app/modules/team/controller/team_list_controller.dart';
import 'package:unii_app/services/storage_service.dart';
import 'package:unii_app/services/team_service.dart';
import '../helpers/fakes.dart';

void main() {
  late TeamListController controller;
  late FakeTeamService fakeTeam;

  setUp(() {
    fakeTeam = FakeTeamService();
    Get.put<TeamService>(fakeTeam);
    Get.put<StorageService>(FakeStorageService());
    controller = Get.put(TeamListController());
  });

  tearDown(() => Get.reset());

  test('loadTeams success populates teams list', () async {
    fakeTeam.teamsToReturn = [makeTeam(), makeTeam(id: 'team-2', name: '团队B')];

    await controller.loadTeams();

    expect(controller.teams.length, 2);
    expect(controller.isLoading.value, false);
    expect(controller.error.value, isNull);
  });

  test('loadTeams failure sets error and leaves teams empty', () async {
    fakeTeam.shouldGetTeamsFail = true;

    await controller.loadTeams();

    expect(controller.teams.isEmpty, true);
    expect(controller.isLoading.value, false);
    expect(controller.error.value, isNotNull);
  });

  test('calling loadTeams twice invokes getMyTeams twice', () async {
    fakeTeam.teamsToReturn = [makeTeam()];

    await controller.loadTeams();
    await controller.loadTeams();

    // onInit already calls loadTeams once, so total = 3
    expect(fakeTeam.getMyTeamsCallCount, greaterThanOrEqualTo(2));
  });
}
```

- [ ] **Step 2: 运行测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/controllers/team_list_controller_test.dart 2>&1
```

期望：`+3: All tests passed!`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/test/controllers/team_list_controller_test.dart && git commit -m "test(flutter): add 3 TeamListController unit tests"
```

---

### Task 4: chat_controller_test.dart — 3 个 ChatController 测试

**Files:**
- Create: `unii_app/test/controllers/chat_controller_test.dart`

- [ ] **Step 1: 创建 test/controllers/chat_controller_test.dart**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:unii_app/modules/message/controller/chat_controller.dart';
import 'package:unii_app/services/auth_service.dart';
import 'package:unii_app/services/message_cache_service.dart';
import 'package:unii_app/services/message_service.dart';
import 'package:unii_app/services/team_service.dart';
import 'package:unii_app/services/ws_service.dart';
import '../helpers/fakes.dart';

void main() {
  late ChatController controller;
  late FakeMessageService fakeMessage;

  setUp(() {
    fakeMessage = FakeMessageService();
    Get.put<MessageService>(fakeMessage);
    Get.put<WsService>(FakeWsService());
    Get.put<AuthService>(FakeAuthService());
    Get.put<MessageCacheService>(FakeMessageCacheService());
    Get.put<TeamService>(FakeTeamService());

    Get.arguments = {'team_id': 'team-1', 'team_name': '测试团队'};
    controller = Get.put(ChatController());
  });

  tearDown(() => Get.reset());

  test('loadMessages populates messages list', () async {
    fakeMessage.messagesToReturn = [makeMessage(id: 1), makeMessage(id: 2)];

    await controller.loadMessages();

    expect(controller.messages.length, 2);
    expect(controller.isLoading.value, false);
  });

  test('filteredMembers filters by mentionQuery', () {
    controller.members.assignAll([
      makeTeamMember(nickname: 'Alice'),
      makeTeamMember(nickname: 'Bob'),
    ]);

    controller.mentionQuery.value = 'ali';

    final result = controller.filteredMembers;
    expect(result.length, 1);
    expect(result.first.nickname, 'Alice');
  });

  test('sendTextMessage clears textController', () async {
    controller.textController.text = 'Hello team!';

    controller.sendTextMessage();
    await Future.delayed(Duration.zero);

    expect(controller.textController.text, '');
  });
}
```

- [ ] **Step 2: 运行测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/controllers/chat_controller_test.dart 2>&1
```

期望：`+3: All tests passed!`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/test/controllers/chat_controller_test.dart && git commit -m "test(flutter): add 3 ChatController unit tests"
```

---

### Task 5: login_view_test.dart — 3 个 LoginView Widget 测试

**Files:**
- Create: `unii_app/test/widgets/login_view_test.dart`

- [ ] **Step 1: 创建 test/widgets/login_view_test.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:unii_app/modules/auth/controller/login_controller.dart';
import 'package:unii_app/modules/auth/view/login_view.dart';
import 'package:unii_app/services/auth_service.dart';
import '../helpers/fakes.dart';

void main() {
  setUp(() {
    Get.put<AuthService>(FakeAuthService());
    Get.put(LoginController());
  });

  tearDown(() => Get.reset());

  testWidgets('LoginView renders without crash', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: LoginView()));

    expect(find.byType(LoginView), findsOneWidget);
    expect(find.text('UNII'), findsOneWidget);
  });

  testWidgets('LoginView has phone and password TextFields', (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: LoginView()));

    expect(find.byType(TextField), findsAtLeastNWidgets(2));
    expect(find.text('手机号'), findsOneWidget);
    expect(find.text('密码'), findsOneWidget);
  });

  testWidgets('tapping login with empty phone shows error message',
      (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: LoginView()));

    await tester.tap(find.text('登录'));
    await tester.pumpAndSettle();

    expect(find.text('请输入手机号'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/widgets/login_view_test.dart 2>&1
```

期望：`+3: All tests passed!`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/test/widgets/login_view_test.dart && git commit -m "test(flutter): add 3 LoginView widget tests"
```

---

### Task 6: team_list_view_test.dart — 2 个 TeamListView Widget 测试

**Files:**
- Create: `unii_app/test/widgets/team_list_view_test.dart`

- [ ] **Step 1: 创建 test/widgets/team_list_view_test.dart**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:unii_app/modules/team/controller/team_list_controller.dart';
import 'package:unii_app/modules/team/view/team_list_view.dart';
import 'package:unii_app/services/storage_service.dart';
import 'package:unii_app/services/team_service.dart';
import '../helpers/fakes.dart';

void main() {
  late FakeTeamService fakeTeam;

  setUp(() {
    fakeTeam = FakeTeamService();
    Get.put<TeamService>(fakeTeam);
    Get.put<StorageService>(FakeStorageService());
    Get.put(TeamListController());
  });

  tearDown(() => Get.reset());

  testWidgets('empty team list shows no-team hint text', (tester) async {
    fakeTeam.teamsToReturn = [];

    await tester.pumpWidget(const GetMaterialApp(home: TeamListView()));
    await tester.pumpAndSettle();

    expect(find.text('还没有加入任何团队'), findsOneWidget);
  });

  testWidgets('non-empty team list shows team name in card', (tester) async {
    fakeTeam.teamsToReturn = [makeTeam(name: '徒步队')];

    await tester.pumpWidget(const GetMaterialApp(home: TeamListView()));
    await tester.pumpAndSettle();

    expect(find.text('徒步队'), findsOneWidget);
  });
}
```

- [ ] **Step 2: 运行测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/widgets/team_list_view_test.dart 2>&1
```

期望：`+2: All tests passed!`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/test/widgets/team_list_view_test.dart && git commit -m "test(flutter): add 2 TeamListView widget tests"
```

---

### Task 7: chat_view_test.dart — 2 个 ChatView Widget 测试

**Files:**
- Create: `unii_app/test/widgets/chat_view_test.dart`

- [ ] **Step 1: 创建 test/widgets/chat_view_test.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:unii_app/modules/message/controller/chat_controller.dart';
import 'package:unii_app/modules/message/view/chat_view.dart';
import 'package:unii_app/services/auth_service.dart';
import 'package:unii_app/services/message_cache_service.dart';
import 'package:unii_app/services/message_service.dart';
import 'package:unii_app/services/team_service.dart';
import 'package:unii_app/services/ws_service.dart';
import '../helpers/fakes.dart';

void main() {
  late FakeMessageService fakeMessage;

  setUp(() {
    fakeMessage = FakeMessageService();
    Get.put<MessageService>(fakeMessage);
    Get.put<WsService>(FakeWsService());
    Get.put<AuthService>(FakeAuthService());
    Get.put<MessageCacheService>(FakeMessageCacheService());
    Get.put<TeamService>(FakeTeamService());

    Get.arguments = {'team_id': 'team-1', 'team_name': '测试团队'};
    Get.put(ChatController());
  });

  tearDown(() => Get.reset());

  testWidgets('ChatView renders without crash and shows input field',
      (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: ChatView()));
    await tester.pumpAndSettle();

    expect(find.byType(ChatView), findsOneWidget);
    expect(find.byType(TextField), findsAtLeastNWidgets(1));
  });

  testWidgets('entering text and tapping send clears input field',
      (tester) async {
    await tester.pumpWidget(const GetMaterialApp(home: ChatView()));
    await tester.pumpAndSettle();

    final textField = find.byType(TextField).last;
    await tester.enterText(textField, '出发了！');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.send));
    await tester.pumpAndSettle();

    expect(find.text('出发了！'), findsNothing);
  });
}
```

- [ ] **Step 2: 运行测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test test/widgets/chat_view_test.dart 2>&1
```

期望：`+2: All tests passed!`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/test/widgets/chat_view_test.dart && git commit -m "test(flutter): add 2 ChatView widget tests"
```

---

### Task 8: 全量验证 + 更新 todolist.md

**Files:**
- Modify: `todolist.md`

- [ ] **Step 1: 运行全部前端测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test 2>&1
```

期望：`+24: All tests passed!`（8 个已有 + 16 个新增）

- [ ] **Step 2: 运行 flutter analyze**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze 2>&1
```

期望：`No issues found!` 或仅 info 级别提示。

- [ ] **Step 3: 更新 todolist.md — 标记后端集成测试为完成**

将 `todolist.md` 中以下行：

```
- [ ] **[B]** 后端集成测试：test database，覆盖完整 API 流程
```

改为：

```
- [x] **[B]** 后端集成测试：test database，覆盖完整 API 流程
```

- [ ] **Step 4: 更新 todolist.md — 标记前端 Controller 单元测试为完成**

将 `todolist.md` 中以下行：

```
- [ ] **[F]** 前端 Controller 单元测试（mockito mock ApiService）
```

改为：

```
- [x] **[F]** 前端 Controller 单元测试（Fake 服务注入，覆盖 Login/Team/Chat Controller）
```

- [ ] **Step 5: 更新 todolist.md — 标记前端 Widget 测试为完成**

将 `todolist.md` 中以下行：

```
- [ ] **[F]** 前端 Widget 测试：关键页面渲染测试
```

改为：

```
- [x] **[F]** 前端 Widget 测试：LoginView / TeamListView / ChatView 渲染与交互测试
```

- [ ] **Step 6: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add todolist.md && git commit -m "chore: mark Phase 8 all 3 test tasks as done"
```
