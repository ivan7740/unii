# 错误处理三件套实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 UNII Flutter 前端补全全局异常捕获、网络异常统一 Snackbar、空状态共享组件三项基础设施。

**Architecture:** `main.dart` 注册两个全局错误钩子；新建 `ErrorHelper` 工具类，在 `ApiService._onError` 拦截器层统一弹 Snackbar；新建 `EmptyStateWidget` 共享组件，重构三个页面的内联空状态代码。`login_controller` / `register_controller` 的网络错误分支删除（改由 ApiService 统一处理），保留表单验证和业务错误内联提示。

**Tech Stack:** Flutter 3.x, GetX, Dio 5.x

---

## 文件结构

| 操作 | 文件 |
|------|------|
| 修改 | `unii_app/lib/main.dart` |
| 新建 | `unii_app/lib/utils/error_helper.dart` |
| 修改 | `unii_app/lib/services/api_service.dart` |
| 修改 | `unii_app/lib/modules/auth/controller/login_controller.dart` |
| 修改 | `unii_app/lib/modules/auth/controller/register_controller.dart` |
| 新建 | `unii_app/lib/widgets/empty_state.dart` |
| 修改 | `unii_app/lib/modules/message/view/message_list_view.dart` |
| 修改 | `unii_app/lib/modules/message/view/chat_view.dart` |
| 修改 | `unii_app/lib/modules/location/view/track_view.dart` |

---

### Task 1: 全局异常捕获

**Files:**
- Modify: `unii_app/lib/main.dart`

- [ ] **Step 1: 在 main() 最前面注册全局错误处理器**

在 `main.dart` 的 `main()` 函数第一行（`WidgetsFlutterBinding.ensureInitialized();` 之前）追加，并在文件顶部添加 `import 'dart:ui';`：

完整修改后的 `main()` 头部：

```dart
import 'dart:ui';
// ... 其余 import 保持不变

void main() async {
  FlutterError.onError = (details) {
    debugPrint('[FlutterError] ${details.exception}\n${details.stack}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('[AsyncError] $error\n$stack');
    return true;
  };

  WidgetsFlutterBinding.ensureInitialized();
  // ... 其余初始化保持不变
```

- [ ] **Step 2: 静态分析确认无问题**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/main.dart 2>&1
```

期望：`No issues found!`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/main.dart && git commit -m "feat(error): register global FlutterError and PlatformDispatcher handlers"
```

---

### Task 2: ErrorHelper 工具类

**Files:**
- Create: `unii_app/lib/utils/error_helper.dart`

- [ ] **Step 1: 创建 error_helper.dart**

```dart
import 'package:dio/dio.dart';

class ErrorHelper {
  static String message(dynamic e) {
    if (e is DioException) {
      switch (e.type) {
        case DioExceptionType.connectionError:
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return '网络连接失败，请检查网络';
        case DioExceptionType.badResponse:
          final status = e.response?.statusCode ?? 0;
          if (status >= 500) return '服务器错误，请稍后重试';
          final data = e.response?.data;
          final msg = data is Map ? data['message'] as String? : null;
          return (msg != null && msg.isNotEmpty) ? msg : '请求失败';
        default:
          return '网络异常，请重试';
      }
    }
    return '未知错误，请重试';
  }
}
```

- [ ] **Step 2: 静态分析确认无问题**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/utils/error_helper.dart 2>&1
```

期望：`No issues found!`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/utils/error_helper.dart && git commit -m "feat(error): add ErrorHelper utility for consistent Dio error messages"
```

---

### Task 3: ApiService 接入 Snackbar

**Files:**
- Modify: `unii_app/lib/services/api_service.dart`

- [ ] **Step 1: 添加 ErrorHelper import 并修改 _onError**

在 `api_service.dart` 顶部现有 import 之后追加：

```dart
import '../utils/error_helper.dart';
```

将现有的 `_onError` 方法替换为：

```dart
Future<void> _onError(
    DioException err, ErrorInterceptorHandler handler) async {
  if (err.response?.statusCode == 401) {
    final refreshed = await _tryRefreshToken();
    if (refreshed) {
      final opts = err.requestOptions;
      opts.headers['Authorization'] = 'Bearer ${_storage.accessToken}';
      try {
        final response = await dio.fetch(opts);
        return handler.resolve(response);
      } on DioException catch (e) {
        return handler.next(e);
      }
    } else {
      _storage.clearAuth();
      Get.offAllNamed('/login');
    }
  } else {
    Get.snackbar(
      '提示',
      ErrorHelper.message(err),
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(8),
    );
  }
  handler.next(err);
}
```

- [ ] **Step 2: 静态分析确认无问题**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/services/api_service.dart 2>&1
```

期望：`No issues found!`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/services/api_service.dart && git commit -m "feat(error): show network error snackbar in ApiService interceptor"
```

---

### Task 4: 简化 Controller 网络错误处理

**Files:**
- Modify: `unii_app/lib/modules/auth/controller/login_controller.dart`
- Modify: `unii_app/lib/modules/auth/controller/register_controller.dart`

- [ ] **Step 1: 修改 login_controller.dart**

在文件顶部 import 区追加（现有 imports 之后）：

```dart
import 'package:dio/dio.dart';
```

将现有 `_parseError` 方法替换为：

```dart
String _parseError(dynamic e) {
  if (e is DioException && e.response?.statusCode == 401) {
    return '手机号或密码错误';
  }
  return ''; // 网络/服务器错误已由 ApiService 统一弹出 Snackbar
}
```

- [ ] **Step 2: 修改 register_controller.dart**

在文件顶部 import 区追加：

```dart
import 'package:dio/dio.dart';
```

将现有 `_parseError` 方法替换为：

```dart
String _parseError(dynamic e) {
  if (e is DioException) {
    final status = e.response?.statusCode ?? 0;
    if (status == 409) return '该手机号已注册';
    if (status == 400) return '请检查输入信息';
    return ''; // 网络/服务器错误已由 ApiService 统一弹出 Snackbar
  }
  return '注册失败，请重试';
}
```

- [ ] **Step 3: 静态分析确认无问题**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/auth/controller/ 2>&1
```

期望：`No issues found!`

- [ ] **Step 4: 运行全部测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test 2>&1
```

期望：全部通过。

- [ ] **Step 5: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/auth/controller/login_controller.dart unii_app/lib/modules/auth/controller/register_controller.dart && git commit -m "refactor(error): remove network error handling from auth controllers, rely on ApiService snackbar"
```

---

### Task 5: EmptyStateWidget 共享组件

**Files:**
- Create: `unii_app/lib/widgets/empty_state.dart`

- [ ] **Step 1: 创建 widgets 目录并创建 empty_state.dart**

```bash
mkdir -p /Users/mac/rust_flutter_app/study_dw/unii_app/lib/widgets
```

创建文件 `unii_app/lib/widgets/empty_state.dart`：

```dart
import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
            ),
            if (hint != null) ...[
              const SizedBox(height: 8),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 静态分析确认无问题**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/widgets/empty_state.dart 2>&1
```

期望：`No issues found!`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/widgets/empty_state.dart && git commit -m "feat(ui): add shared EmptyStateWidget component"
```

---

### Task 6: message_list_view 接入 EmptyStateWidget

**Files:**
- Modify: `unii_app/lib/modules/message/view/message_list_view.dart`

当前空状态是内联代码且没有行动按钮。替换为 `EmptyStateWidget` 并补上按钮。

- [ ] **Step 1: 添加 import 并替换内联空状态**

在文件顶部 import 区追加：

```dart
import '../../../widgets/empty_state.dart';
```

找到并替换现有内联空状态代码（当前 `if (controller.teams.isEmpty)` 块）：

```dart
        if (controller.teams.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.chat_bubble_outline,
            message: '还没有加入任何团队',
            hint: '加入团队后即可开始聊天',
            actionLabel: '去创建团队',
            onAction: () => Get.toNamed('/team/create'),
          );
        }
```

- [ ] **Step 2: 静态分析确认无问题**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/message/view/message_list_view.dart 2>&1
```

期望：`No issues found!`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/message/view/message_list_view.dart && git commit -m "feat(ui): use EmptyStateWidget in message list view with action button"
```

---

### Task 7: chat_view 接入 EmptyStateWidget

**Files:**
- Modify: `unii_app/lib/modules/message/view/chat_view.dart`

- [ ] **Step 1: 添加 import 并替换内联空状态**

在文件顶部 import 区追加：

```dart
import '../../../widgets/empty_state.dart';
```

找到并替换当前 `if (controller.messages.isEmpty)` 块（位于 `Expanded` 内的 `Obx` 里）：

```dart
              if (controller.messages.isEmpty) {
                return const EmptyStateWidget(
                  icon: Icons.forum_outlined,
                  message: '还没有消息',
                  hint: '发一条消息打个招呼吧',
                );
              }
```

- [ ] **Step 2: 静态分析确认无问题**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/message/view/chat_view.dart 2>&1
```

期望：`No issues found!`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/message/view/chat_view.dart && git commit -m "refactor(ui): use EmptyStateWidget in chat view"
```

---

### Task 8: track_view 接入 EmptyStateWidget

**Files:**
- Modify: `unii_app/lib/modules/location/view/track_view.dart`

- [ ] **Step 1: 添加 import 并替换内联空状态**

在文件顶部 import 区追加：

```dart
import '../../../widgets/empty_state.dart';
```

找到并替换当前 `if (controller.trackPoints.isEmpty)` 块：

```dart
        if (controller.trackPoints.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.route_outlined,
            message: '暂无轨迹数据',
            hint: '开启定位后轨迹将在这里显示',
          );
        }
```

- [ ] **Step 2: 静态分析确认无问题**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze lib/modules/location/view/track_view.dart 2>&1
```

期望：`No issues found!`

- [ ] **Step 3: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add unii_app/lib/modules/location/view/track_view.dart && git commit -m "refactor(ui): use EmptyStateWidget in track view"
```

---

### Task 9: 最终验证

**Files:** （无代码修改）

- [ ] **Step 1: 全项目静态分析**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter analyze 2>&1
```

期望：`No issues found!`

- [ ] **Step 2: 全部测试**

```bash
cd /Users/mac/rust_flutter_app/study_dw/unii_app && flutter test 2>&1
```

期望：全部通过。

- [ ] **Step 3: 更新 todolist.md**

将 `todolist.md` 中以下三行标记为完成：

```
- [ ] **[F]** 全局异常捕获 + Flutter 异常上报
- [ ] **[F]** 网络异常友好提示：断网、超时、服务不可用
- [ ] **[F]** 空状态页面：无团队引导、无消息提示
```

改为：

```
- [x] **[F]** 全局异常捕获 + Flutter 异常上报
- [x] **[F]** 网络异常友好提示：断网、超时、服务不可用
- [x] **[F]** 空状态页面：无团队引导、无消息提示
```

- [ ] **Step 4: 提交**

```bash
cd /Users/mac/rust_flutter_app/study_dw && git add todolist.md && git commit -m "chore: mark error handling tasks as done"
```
