import 'package:flutter_test/flutter_test.dart';
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

  @override
  void disconnect() {}

  @override
  void joinTeamChannel(String teamId) {}

  @override
  void leaveTeamChannel(String teamId) {}

  @override
  void sendLocationUpdate({
    required String teamId,
    required double latitude,
    required double longitude,
    double? altitude,
    double? accuracy,
    double? speed,
  }) {}
}

// ── FakeMessageCacheService ────────────────────────────────────────────────

class FakeMessageCacheService extends Fake implements MessageCacheService {
  @override
  Future<MessageCacheService> init() async => this;

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
