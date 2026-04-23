import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../widgets/empty_state.dart';
import '../controller/track_controller.dart';

class TrackView extends GetView<TrackController> {
  const TrackView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${controller.nickname} 的轨迹')),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.error.value != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text(controller.error.value!,
                    style: TextStyle(color: Colors.grey.shade500)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: controller.loadTrack,
                  child: const Text('重试'),
                ),
              ],
            ),
          );
        }

        if (controller.trackPoints.isEmpty) {
          return const EmptyStateWidget(
            icon: Icons.route_outlined,
            message: '暂无轨迹数据',
            hint: '开启定位后轨迹将在这里显示',
          );
        }

        final points = controller.trackPoints
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
        final currentPoint = controller.currentPoint;

        return Column(
          children: [
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: points.first,
                  initialZoom: 15,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.unii.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        color: const Color(0xFF2196F3),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: points.first,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.green,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.flag,
                              size: 12, color: Colors.white),
                        ),
                      ),
                      Marker(
                        point: points.last,
                        width: 24,
                        height: 24,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.red.shade700,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 2),
                          ),
                          child: const Icon(Icons.flag,
                              size: 12, color: Colors.white),
                        ),
                      ),
                      if (currentPoint != null)
                        Marker(
                          point: LatLng(
                              currentPoint.latitude, currentPoint.longitude),
                          width: 18,
                          height: 18,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: Colors.white, width: 2),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            _buildControlPanel(context),
          ],
        );
      }),
    );
  }

  Widget _buildControlPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Obx(() => IconButton(
                      icon: Icon(
                        controller.isPlaying.value
                            ? Icons.pause
                            : Icons.play_arrow,
                      ),
                      onPressed: controller.isPlaying.value
                          ? controller.pause
                          : controller.play,
                    )),
                Expanded(
                  child: Obx(() => Slider(
                        value: controller.currentIndex.value.toDouble(),
                        min: 0,
                        max: (controller.trackPoints.length - 1)
                            .toDouble()
                            .clamp(0, double.infinity),
                        onChanged: (v) => controller.seekTo(v.toInt()),
                      )),
                ),
                Obx(() => Text(
                      controller.currentTimeText,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500),
                    )),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Obx(() => Text(
                        controller.startTimeText,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      )),
                  Obx(() => Text(
                        '${controller.trackPoints.length} 个点',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade400),
                      )),
                  Obx(() => Text(
                        controller.endTimeText,
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade500),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
