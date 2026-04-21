import 'package:flutter_test/flutter_test.dart';
import 'package:unii_app/models/user.dart';
import 'package:unii_app/utils/constants.dart';
import 'package:unii_app/modules/location/controller/map_controller.dart' as app;
import 'package:unii_app/services/message_cache_service.dart';

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

  test('MapController.tileUrl returns correct tile URLs', () {
    expect(app.MapController.tileUrl('standard'), contains('openstreetmap.org'));
    expect(app.MapController.tileUrl('satellite'), contains('arcgisonline.com'));
    expect(app.MapController.tileUrl('terrain'), contains('opentopomap.org'));
    expect(app.MapController.tileUrl('unknown'), contains('openstreetmap.org'));
  });

  test('MapController.formatDistance formats distances correctly', () {
    expect(app.MapController.formatDistance(50), '< 100 m');
    expect(app.MapController.formatDistance(99.9), '< 100 m');
    expect(app.MapController.formatDistance(100), '100 m');
    expect(app.MapController.formatDistance(350.6), '351 m');
    expect(app.MapController.formatDistance(999), '999 m');
    expect(app.MapController.formatDistance(1000), '1.0 km');
    expect(app.MapController.formatDistance(1234), '1.2 km');
  });

  test('MessageCacheService.parseMessages returns empty list for empty string',
      () {
    expect(MessageCacheService.parseMessages(''), isEmpty);
  });

  test(
      'MessageCacheService.parseMessages returns empty list for corrupt JSON',
      () {
    expect(MessageCacheService.parseMessages('not-json'), isEmpty);
    expect(MessageCacheService.parseMessages('{invalid}'), isEmpty);
  });

  test(
      'MessageCacheService.parseMessages returns empty list for empty array',
      () {
    expect(MessageCacheService.parseMessages('[]'), isEmpty);
  });
}
