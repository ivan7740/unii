import 'package:get/get.dart';
import 'package:unii_app/models/message.dart';
import 'package:unii_app/models/team.dart';
import 'package:unii_app/models/user.dart';
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

class FakeAuthService extends GetxService {
  final Rx<User?> currentUser = Rx<User?>(null);

  bool get isLoggedIn => true;

  bool shouldLoginFail = false;
  int loginCallCount = 0;

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

  Future<AuthResponse> register({
    String? phone,
    String? email,
    required String nickname,
    required String password,
  }) async {
    currentUser.value = kTestUser;
    return kTestAuthResponse;
  }

  Future<User?> fetchMe() async => kTestUser;

  void logout() {}
}

// ── FakeTeamService ────────────────────────────────────────────────────────

class FakeTeamService extends GetxService {
  List<Team> teamsToReturn = [];
  bool shouldGetTeamsFail = false;
  int getMyTeamsCallCount = 0;

  Future<List<Team>> getMyTeams() async {
    getMyTeamsCallCount++;
    if (shouldGetTeamsFail) throw Exception('network error');
    return teamsToReturn;
  }

  Future<TeamDetail> getTeamDetail(String teamId) async {
    return TeamDetail(team: makeTeam(), members: [makeTeamMember()]);
  }

  Future<Team> createTeam({required String name, bool isTemporary = false}) async {
    return makeTeam(name: name);
  }

  Future<Team> joinTeam(String inviteCode) async => makeTeam();

  Future<void> leaveTeam(String teamId) async {}

  Future<void> disbandTeam(String teamId) async {}

  Future<Team> updateTeam(String teamId, {String? name}) async => makeTeam();
}

// ── FakeMessageService ─────────────────────────────────────────────────────

class FakeMessageService extends GetxService {
  List<Message> messagesToReturn = [];
  String? lastSentContent;

  Future<List<Message>> getTeamMessages(
    String teamId, {
    int? beforeId,
    int limit = 50,
  }) async {
    return messagesToReturn;
  }

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

class FakeWsService extends GetxService {
  final status = ConnectionStatus.disconnected.obs;

  void on(String type, void Function(Map<String, dynamic> data) callback) {}

  void off(String type, void Function(Map<String, dynamic> data) callback) {}

  void send(String type, Map<String, dynamic> data) {}

  void connect() {}

  void disconnect() {}

  void joinTeamChannel(String teamId) {}

  void leaveTeamChannel(String teamId) {}

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

class FakeMessageCacheService extends GetxService {
  List<Message> loadMessages(String teamId) => [];

  void saveMessages(String teamId, List<Message> messages) {}

  void prependMessage(String teamId, Message message) {}
}

// ── FakeStorageService ─────────────────────────────────────────────────────

class FakeStorageService extends GetxService {
  final _data = <String, dynamic>{};

  T? read<T>(String key) => _data[key] as T?;

  Future<void> write(String key, dynamic value) async => _data[key] = value;

  Future<void> remove(String key) async => _data.remove(key);

  bool get isLoggedIn => false;

  String? get accessToken => _data['access_token'] as String?;

  set accessToken(String? v) => _data['access_token'] = v;

  String? get refreshToken => _data['refresh_token'] as String?;

  set refreshToken(String? v) => _data['refresh_token'] = v;

  void clearAuth() {
    _data.remove('access_token');
    _data.remove('refresh_token');
  }

  Future<FakeStorageService> init() async => this;
}
