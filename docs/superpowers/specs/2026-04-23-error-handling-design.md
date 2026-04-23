# 错误处理三件套设计文档

**目标：** 补全 UNII Flutter 前端的错误处理基础设施，覆盖全局异常捕获、网络异常统一提示、空状态页面三个维度，提升 app 生产环境成熟度。

**方案选择：** 分层 + 共享组件（轻量抽象，不重构现有 controller 架构）

---

## 一、全局异常捕获

### 改动文件
- `unii_app/lib/main.dart`

### 设计

在 `main()` 最前面注册两个全局错误处理器：

```dart
FlutterError.onError = (details) {
  debugPrint('[FlutterError] ${details.exception}\n${details.stack}');
};
PlatformDispatcher.instance.onError = (error, stack) {
  debugPrint('[AsyncError] $error\n$stack');
  return true;
};
```

- `FlutterError.onError`：捕获 Flutter 框架层同步异常（widget build 错误、布局溢出等）
- `PlatformDispatcher.instance.onError`：捕获所有未处理的异步异常（Future 链泄漏的异常）
- 两者均只记录 `debugPrint` 日志，不展示给用户（崩溃级错误通常无法优雅恢复，强行弹框反而更差）
- 返回 `true` 表示错误已被处理，阻止默认的黑屏/红屏

### 边界

不接入外部崩溃上报服务（Sentry / Crashlytics），当前阶段本地日志足够。未来接入时只需在两个 handler 内追加上报调用。

---

## 二、网络异常统一 Snackbar

### 改动文件
- 新建：`unii_app/lib/utils/error_helper.dart`
- 修改：`unii_app/lib/services/api_service.dart`
- 简化：各 controller 中仅用于网络错误的 `_parseError` 分支

### 设计

#### 2.1 ErrorHelper

```dart
// lib/utils/error_helper.dart
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
          // 4xx：优先取服务器返回的 message 字段
          final msg = e.response?.data?['message'] as String?;
          return msg?.isNotEmpty == true ? msg! : '请求失败';
        default:
          return '网络异常，请重试';
      }
    }
    return '未知错误，请重试';
  }
}
```

#### 2.2 ApiService._onError 统一弹出

在现有 `_onError` 末尾（401 处理之后）追加：

```dart
// 非 401 错误统一提示（401 已处理跳转登录，不需再弹）
if (err.response?.statusCode != 401) {
  Get.snackbar(
    '提示',
    ErrorHelper.message(err),
    snackPosition: SnackPosition.BOTTOM,
    duration: const Duration(seconds: 3),
  );
}
handler.next(err);
```

#### 2.3 Controller 简化

各 controller 的 catch 块只保留表单验证逻辑，移除网络错误分支。示例：

```dart
// Before
} catch (e) {
  errorMessage.value = _parseError(e); // 混合了表单验证和网络错误
}

// After（login_controller 保留手机号/密码验证，网络错误由 ApiService 处理）
} catch (_) {
  // 网络错误已由 ApiService 统一弹出，此处无需重复处理
}
```

表单验证错误（`errorMessage.value = '请输入手机号'`）保持内联，不受影响。

### 覆盖范围

所有通过 `ApiService.dio` 发出的请求自动受保护，包括：
- 位置上报
- 团队操作（创建/加入/退出）
- 消息发送/历史加载
- 用户资料更新

---

## 三、空状态页面

### 改动文件
- 新建：`unii_app/lib/widgets/empty_state.dart`
- 修改：`unii_app/lib/modules/message/view/message_list_view.dart`
- 修改：`unii_app/lib/modules/message/view/chat_view.dart`
- 修改：`unii_app/lib/modules/location/view/track_view.dart`

### 设计

#### 3.1 EmptyStateWidget

```dart
// lib/widgets/empty_state.dart
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;
  // ...
}
```

样式与现有 `team_list_view` 的空状态保持一致（大图标 + 灰色文字 + 可选按钮）。

#### 3.2 各页面空状态规格

| 页面 | 触发条件 | 图标 | 主文字 | 副文字 | 按钮 |
|------|----------|------|--------|--------|------|
| `message_list_view` | 无团队 | `chat_bubble_outline` | 还没有消息 | 先加入或创建一个团队 | 去创建团队 |
| `message_list_view` | 有团队但无最近消息 | `chat_bubble_outline` | 还没有消息 | 发一条消息开始聊天 | 无 |
| `chat_view` | 历史记录为空 | `forum_outlined` | 还没有消息 | 发一条消息打个招呼吧 | 无 |
| `track_view` | 无轨迹数据 | `route_outlined` | 暂无轨迹数据 | 开启定位后轨迹将在这里显示 | 无 |

#### 3.3 不改动

- `team_list_view`：已有完整空状态（图标 + 文字 + 创建/加入按钮）
- `map_view`：已有"请先选择活动团队"空状态

---

## 文件清单

| 操作 | 文件 |
|------|------|
| 修改 | `unii_app/lib/main.dart` |
| 新建 | `unii_app/lib/utils/error_helper.dart` |
| 修改 | `unii_app/lib/services/api_service.dart` |
| 新建 | `unii_app/lib/widgets/empty_state.dart` |
| 修改 | `unii_app/lib/modules/message/view/message_list_view.dart` |
| 修改 | `unii_app/lib/modules/message/view/chat_view.dart` |
| 修改 | `unii_app/lib/modules/location/view/track_view.dart` |
| 简化 | `unii_app/lib/modules/auth/controller/login_controller.dart`（及其他 controller） |
