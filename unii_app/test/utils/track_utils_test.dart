import 'package:flutter_test/flutter_test.dart';
import 'package:unii_app/models/location.dart';
import 'package:unii_app/utils/track_utils.dart';

TrackPoint pt(double lat, double lng) => TrackPoint(
      latitude: lat,
      longitude: lng,
      recordedAt: '2026-01-01T00:00:00Z',
    );

void main() {
  group('TrackUtils.simplify', () {
    test('returns original list when points < 100', () {
      final points = List.generate(50, (i) => pt(39.0 + i * 0.001, 116.0));
      final result = TrackUtils.simplify(points, 15.0);
      expect(result, same(points));
    });

    test('collinear points simplified to just endpoints', () {
      // 200 evenly-spaced collinear points along longitude axis
      final points = List.generate(
          200, (i) => pt(39.0, 116.0 + i * 0.0001));
      final result = TrackUtils.simplify(points, 15.0);
      expect(result.length, 2);
      expect(result.first.longitude, closeTo(116.0, 1e-9));
      expect(result.last.longitude, closeTo(116.0 + 199 * 0.0001, 1e-9));
    });

    test('significant bend is preserved', () {
      // 200 points: straight east then sharp north turn
      final straight = List.generate(100, (i) => pt(39.0, 116.0 + i * 0.001));
      final turn = List.generate(100, (i) => pt(39.0 + (i + 1) * 0.001, 116.099));
      final points = [...straight, ...turn];
      final result = TrackUtils.simplify(points, 5.0);
      // Must keep more than 2 points (the bend is significant)
      expect(result.length, greaterThan(2));
      // Must keep start and end
      expect(result.first.longitude, closeTo(116.0, 1e-9));
      expect(result.last.latitude, closeTo(39.0 + 100 * 0.001, 1e-9));
    });

    test('lower precision produces fewer points', () {
      final points = List.generate(200, (i) {
        // Sinusoidal path
        final lat = 39.0 + (i % 10) * 0.0001;
        final lng = 116.0 + i * 0.001;
        return pt(lat, lng);
      });
      final high = TrackUtils.simplify(points, TrackUtils.tolerances[0]);
      final low = TrackUtils.simplify(points, TrackUtils.tolerances[2]);
      expect(low.length, lessThanOrEqualTo(high.length));
    });
  });
}
