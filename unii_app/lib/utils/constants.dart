class AppConstants {
  static const String appName = 'UNII';

  // API
  static const String baseUrl = 'http://localhost:3000/api';
  static const String wsUrl = 'ws://localhost:3000/ws';

  // Storage keys
  static const String accessTokenKey = 'access_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userKey = 'current_user';
  static const String activeTeamKey = 'active_team_id';
  static const String locationFrequencyKey = 'location_frequency';
  static const String mapStyleKey = 'map_style';
  static const String shareLocationKey = 'share_location';

  // 位置更新频率（秒）
  static const int frequencyPowerSave = 30;
  static const int frequencyStandard = 10;
  static const int frequencyHighAccuracy = 3;
  static const int frequencyBackground = 60;
}
