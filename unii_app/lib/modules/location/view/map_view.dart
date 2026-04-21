import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';
import '../controller/map_controller.dart' as app;

class MapView extends GetView<app.MapController> {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Obx(() {
        if (controller.activeTeamId == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text('请先选择一个活动团队',
                    style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
                const SizedBox(height: 8),
                Text('在团队列表中点击团队进入',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
              ],
            ),
          );
        }

        final members = controller.memberLocations;

        return Stack(
          children: [
            // OpenStreetMap 地图
            FlutterMap(
              mapController: controller.fmController,
              options: MapOptions(
                initialCenter: members.isNotEmpty
                    ? LatLng(members.first.latitude, members.first.longitude)
                    : const LatLng(39.9042, 116.4074), // 默认北京
                initialZoom: 14,
                onMapReady: () {
                  controller.mapCamera.value = controller.fmController.camera;
                },
                onMapEvent: controller.onMapEvent,
              ),
              children: [
                Obx(() => TileLayer(
                      urlTemplate:
                          app.MapController.tileUrl(controller.mapStyle.value),
                      userAgentPackageName: 'com.unii.app',
                    )),
                // 成员标记
                if (members.isNotEmpty)
                  MarkerLayer(
                    markers: members
                        .map((m) => Marker(
                              point: LatLng(m.latitude, m.longitude),
                              width: 120,
                              height: 60,
                              child: _MemberMarker(
                                nickname: m.nickname,
                                avatarUrl: m.avatarUrl,
                                isStale: m.isStale,
                                timeAgoText: m.timeAgoText,
                                isOnline: m.isOnline,
                              ),
                            ))
                        .toList(),
                  ),
              ],
            ),

            // 地图样式切换按钮
            Positioned(
              top: 48,
              left: 12,
              child: _buildStyleButtons(),
            ),

            // 底部成员面板
            if (members.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildMemberPanel(context),
              ),

            // 刷新按钮
            Positioned(
              right: 16,
              bottom: members.isNotEmpty ? 200 : 16,
              child: FloatingActionButton.small(
                onPressed: controller.refreshLocations,
                child: Obx(() => controller.isLoading.value
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh)),
              ),
            ),

            // 屏幕外成员方向箭头
            Positioned.fill(
              child: IgnorePointer(
                child: _buildOffScreenArrows(),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMemberPanel(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '团队成员位置 (${controller.memberLocations.length})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: controller.memberLocations.length,
              itemBuilder: (context, index) {
                final member = controller.memberLocations[index];
                return GestureDetector(
                  onTap: () => Get.toNamed('/track', arguments: {
                    'user_id': member.userId,
                    'team_id': controller.activeTeamId,
                    'nickname': member.nickname,
                  }),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Stack(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              child: Text(
                                member.nickname.isNotEmpty ? member.nickname[0] : '?',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            if (member.isOnline)
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 1.5),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(member.nickname,
                                  style: const TextStyle(fontWeight: FontWeight.w500)),
                              Text(
                                member.isStale
                                    ? '${member.latitude.toStringAsFixed(6)}, ${member.longitude.toStringAsFixed(6)} · ${member.timeAgoText}'
                                    : '${member.latitude.toStringAsFixed(6)}, ${member.longitude.toStringAsFixed(6)}',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: member.isStale ? Colors.grey.shade400 : Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ),
                        if (member.speed != null && member.speed! > 0)
                          Text(
                            '${member.speed!.toStringAsFixed(1)} m/s',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey.shade600),
                          ),
                        Obx(() {
                          final dist = controller.distanceTo(member);
                          if (dist == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              dist,
                              style: TextStyle(
                                  fontSize: 12, color: Colors.blue.shade600),
                            ),
                          );
                        }),
                        const Icon(Icons.chevron_right, size: 16, color: Colors.grey),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleButtons() {
    final styles = [
      ('standard', Icons.map, '标准'),
      ('satellite', Icons.satellite_alt, '卫星'),
      ('terrain', Icons.terrain, '地形'),
    ];
    return Obx(() => Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: styles.map((s) {
              final isSelected = controller.mapStyle.value == s.$1;
              return IconButton(
                icon: Icon(
                  s.$2,
                  color: isSelected
                      ? Theme.of(Get.context!).colorScheme.primary
                      : Colors.grey.shade400,
                  size: 20,
                ),
                tooltip: s.$3,
                onPressed: () => controller.setMapStyle(s.$1),
                padding: const EdgeInsets.all(8),
                constraints:
                    const BoxConstraints(minWidth: 36, minHeight: 36),
              );
            }).toList(),
          ),
        ));
  }

  Widget _buildOffScreenArrows() {
    return Obx(() {
      final camera = controller.mapCamera.value;
      final members = controller.memberLocations;
      if (camera == null || members.isEmpty) return const SizedBox.shrink();

      return LayoutBuilder(
        builder: (context, constraints) {
          const padding = 24.0;
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final center = Offset(w / 2, h / 2);

          final arrows = <Widget>[];
          for (final member in members) {
            final screenPt = camera.latLngToScreenPoint(
              LatLng(member.latitude, member.longitude),
            );
            final pt = Offset(screenPt.x.toDouble(), screenPt.y.toDouble());

            // Skip members that are on screen
            if (pt.dx >= padding &&
                pt.dx <= w - padding &&
                pt.dy >= padding &&
                pt.dy <= h - padding) {
              continue;
            }

            final dx = pt.dx - center.dx;
            final dy = pt.dy - center.dy;
            final angle = math.atan2(dy, dx) + math.pi / 2;

            final edgePt = _clampToEdge(center, pt, w, h, padding);
            final label = member.nickname.length > 4
                ? '${member.nickname.substring(0, 4)}..'
                : member.nickname;

            arrows.add(
              Positioned(
                left: edgePt.dx - 20,
                top: edgePt.dy - 16,
                child: SizedBox(
                  width: 40,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Transform.rotate(
                        angle: angle,
                        child: const Icon(
                          Icons.navigation,
                          size: 20,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 9,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (arrows.isEmpty) return const SizedBox.shrink();
          return Stack(children: arrows);
        },
      );
    });
  }

  static Offset _clampToEdge(
    Offset center,
    Offset target,
    double w,
    double h,
    double padding,
  ) {
    final dx = target.dx - center.dx;
    final dy = target.dy - center.dy;

    double scale = double.infinity;
    if (dx > 0) scale = math.min(scale, (w - padding - center.dx) / dx);
    if (dx < 0) scale = math.min(scale, (padding - center.dx) / dx);
    if (dy > 0) scale = math.min(scale, (h - padding - center.dy) / dy);
    if (dy < 0) scale = math.min(scale, (padding - center.dy) / dy);

    return Offset(
      (center.dx + dx * scale).clamp(padding, w - padding),
      (center.dy + dy * scale).clamp(padding, h - padding),
    );
  }
}

/// 自定义成员标记组件
class _MemberMarker extends StatelessWidget {
  final String nickname;
  final String? avatarUrl;
  final bool isStale;
  final String timeAgoText;
  final bool isOnline;

  const _MemberMarker({
    required this.nickname,
    this.avatarUrl,
    this.isStale = false,
    this.timeAgoText = '',
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isStale
        ? const Color(0xFF9E9E9E)
        : Theme.of(context).colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                nickname,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (isStale && timeAgoText.isNotEmpty)
                Text(
                  timeAgoText,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 9,
                  ),
                ),
            ],
          ),
        ),
        CustomPaint(
          size: const Size(10, 6),
          painter: _TrianglePainter(color: color),
        ),
        SizedBox(
          width: 16,
          height: 16,
          child: Stack(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
