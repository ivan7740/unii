import 'dart:math';
import '../models/location.dart';

class TrackUtils {
  /// 容差级别（米）：索引 0=高精度 5m, 1=标准 15m, 2=低精度 50m
  static const tolerances = [5.0, 15.0, 50.0];

  static const _minPointsToSimplify = 100;

  /// Ramer–Douglas–Peucker 简化。
  /// 点数 < 100 时直接返回原列表（不复制）。
  /// toleranceMeters 使用经纬度欧氏近似（1° ≈ 111 000 m）。
  static List<TrackPoint> simplify(
      List<TrackPoint> points, double toleranceMeters) {
    if (points.length < _minPointsToSimplify) return points;
    final epsilon = toleranceMeters / 111000.0;
    return _rdp(points, epsilon);
  }

  static List<TrackPoint> _rdp(List<TrackPoint> points, double epsilon) {
    if (points.length < 3) return List.of(points);
    double maxDist = 0;
    int index = 0;
    for (int i = 1; i < points.length - 1; i++) {
      final d = _perpendicularDist(points[i], points.first, points.last);
      if (d > maxDist) {
        maxDist = d;
        index = i;
      }
    }
    if (maxDist > epsilon) {
      final left = _rdp(points.sublist(0, index + 1), epsilon);
      final right = _rdp(points.sublist(index), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    }
    return [points.first, points.last];
  }

  /// 点 p 到线段 (start, end) 的垂直距离（度数单位，与 epsilon 量纲一致）
  static double _perpendicularDist(
      TrackPoint p, TrackPoint start, TrackPoint end) {
    final dx = end.longitude - start.longitude;
    final dy = end.latitude - start.latitude;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) {
      final ex = p.longitude - start.longitude;
      final ey = p.latitude - start.latitude;
      return sqrt(ex * ex + ey * ey);
    }
    final t = ((p.longitude - start.longitude) * dx +
            (p.latitude - start.latitude) * dy) /
        lenSq;
    final tc = t.clamp(0.0, 1.0);
    final px = start.longitude + tc * dx;
    final py = start.latitude + tc * dy;
    final ex = p.longitude - px;
    final ey = p.latitude - py;
    return sqrt(ex * ex + ey * ey);
  }
}
