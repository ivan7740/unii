import 'dart:math';
import '../models/location.dart';

class TrackUtils {
  /// 容差级别（米）：索引 0=高精度 5m, 1=标准 15m, 2=低精度 50m
  static const double toleranceHigh = 5.0;
  static const double toleranceMedium = 15.0;
  static const double toleranceLow = 50.0;
  static const tolerances = [toleranceHigh, toleranceMedium, toleranceLow];

  static const _minPointsToSimplify = 100;

  /// Ramer–Douglas–Peucker 简化（迭代实现，无栈溢出风险）。
  ///
  /// 点数 < 100 时直接返回原列表（不复制）。
  /// 使用经纬度欧氏近似：1° ≈ 111 000 m（经度轴在中纬度有约 22% 误差，
  /// 用于地图渲染时精度足够）。
  static List<TrackPoint> simplify(
      List<TrackPoint> points, double toleranceMeters) {
    if (toleranceMeters <= 0 || points.length < _minPointsToSimplify) {
      return points;
    }
    final epsilon = toleranceMeters / 111000.0;
    return _rdpIterative(points, epsilon);
  }

  /// 迭代版 RDP，使用显式索引栈避免大数据集时的栈溢出。
  static List<TrackPoint> _rdpIterative(
      List<TrackPoint> points, double epsilon) {
    if (points.length < 3) return List.of(points);

    // 记录需要保留的点索引（首尾始终保留）
    final keep = <int>{0, points.length - 1};
    // 待处理的 (startIndex, endIndex) 区间栈
    final stack = <(int, int)>[(0, points.length - 1)];

    while (stack.isNotEmpty) {
      final (start, end) = stack.removeLast();
      if (end - start < 2) continue; // 区间内无内部点

      double maxDist = 0;
      int splitIdx = start;
      for (int i = start + 1; i < end; i++) {
        final d = _perpendicularDist(points[i], points[start], points[end]);
        if (d > maxDist) {
          maxDist = d;
          splitIdx = i;
        }
      }

      if (maxDist > epsilon) {
        keep.add(splitIdx);
        stack.add((start, splitIdx));
        stack.add((splitIdx, end));
      }
    }

    final sortedIndices = keep.toList()..sort();
    return sortedIndices.map((i) => points[i]).toList();
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
