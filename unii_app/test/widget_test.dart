import 'package:flutter_test/flutter_test.dart';
import 'package:unii_app/models/user.dart';
import 'package:unii_app/utils/constants.dart';

void main() {
  test('User model parses from JSON', () {
    final json = {
      'id': '123e4567-e89b-12d3-a456-426614174000',
      'phone': '13800138001',
      'email': null,
      'nickname': 'TestUser',
      'avatar_url': null,
      'created_at': '2026-04-16T03:07:42.573738Z',
    };

    final user = User.fromJson(json);
    expect(user.id, '123e4567-e89b-12d3-a456-426614174000');
    expect(user.phone, '13800138001');
    expect(user.nickname, 'TestUser');
    expect(user.email, isNull);
  });

  test('AuthResponse model parses from JSON', () {
    final json = {
      'access_token': 'test_access_token',
      'refresh_token': 'test_refresh_token',
      'user': {
        'id': '123e4567-e89b-12d3-a456-426614174000',
        'phone': '13800138001',
        'email': null,
        'nickname': 'TestUser',
        'avatar_url': null,
        'created_at': '2026-04-16T03:07:42.573738Z',
      },
    };

    final auth = AuthResponse.fromJson(json);
    expect(auth.accessToken, 'test_access_token');
    expect(auth.refreshToken, 'test_refresh_token');
    expect(auth.user.nickname, 'TestUser');
  });

  test('frequencyBackground constant is 60 seconds', () {
    expect(AppConstants.frequencyBackground, 60);
  });
}
