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
      appBar: AppBar(
        title: Text('${controller.nickname} 的轨迹'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(24),
          child: Obx(() => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  '${controller.presetLabel}  ·  '
                  '${controller.trackPoints.length} 点 → 显示 ${controller.simplifiedPoints.length} 点',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade400),
                ),
              )),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_outlined),
            tooltip: '选择时间范围',
            onPressed: () => _showTimeRangeSheet(context),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        if (controller.error.value != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline,
                    size: 64, color: Colors.grey.shade300),
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

        // 地图用简化点，时间轴 Slider 用原始点
        final mapPoints = controller.simplifiedPoints
            .map((p) => LatLng(p.latitude, p.longitude))
            .toList();
        final currentPoint = controller.currentPoint;

        return Column(
          children: [
            Expanded(
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: mapPoints.first,
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
                        points: mapPoints,
                        color: const Color(0xFF2196F3),
                        strokeWidth: 3,
                      ),
                    ],
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: mapPoints.first,
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
                        point: mapPoints.last,
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
                          point: LatLng(currentPoint.latitude,
                              currentPoint.longitude),
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
                                  color:
                                      Colors.black.withValues(alpha: 0.3),
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
            // 播放控制行（原有）
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
            // 起止时间行（原有）
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
            const SizedBox(height: 4),
            // 精度控制行（新增）
            Row(
              children: [
                Text(
                  '精度',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(width: 4),
                Text(
                  '高',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade400),
                ),
                Expanded(
                  child: Obx(() => Slider(
                        value: controller.precisionIndex.value.toDouble(),
                        min: 0,
                        max: 2,
                        divisions: 2,
                        onChanged: (v) =>
                            controller.changePrecision(v.toInt()),
                      )),
                ),
                Text(
                  '低',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade400),
                ),
                const SizedBox(width: 8),
                Obx(() => Text(
                      '${controller.simplifiedPoints.length} 点',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                    )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showTimeRangeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TimeRangeSheet(controller: controller),
    );
  }
}

class _TimeRangeSheet extends StatefulWidget {
  final TrackController controller;
  const _TimeRangeSheet({required this.controller});

  @override
  State<_TimeRangeSheet> createState() => _TimeRangeSheetState();
}

class _TimeRangeSheetState extends State<_TimeRangeSheet> {
  late String _selectedPreset;
  DateTime? _customStart;
  DateTime? _customEnd;

  @override
  void initState() {
    super.initState();
    _selectedPreset = widget.controller.selectedPreset.value;
    _customStart = widget.controller.customStart.value;
    _customEnd = widget.controller.customEnd.value;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
        left: 16,
        right: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('选择时间范围',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          // 快捷选项
          Wrap(
            spacing: 8,
            children: [
              for (final entry in const [
                ('today', '今天'),
                ('yesterday', '昨天'),
                ('3days', '近3天'),
                ('custom', '自定义'),
              ])
                ChoiceChip(
                  label: Text(entry.$2),
                  selected: _selectedPreset == entry.$1,
                  onSelected: (_) {
                    setState(() => _selectedPreset = entry.$1);
                    if (entry.$1 != 'custom') {
                      widget.controller.changePreset(entry.$1);
                      Navigator.pop(context);
                    }
                  },
                ),
            ],
          ),
          // 自定义时间选择（仅当 custom 被选中时展开）
          if (_selectedPreset == 'custom') ...[
            const SizedBox(height: 16),
            _DateTimePicker(
              label: '开始',
              value: _customStart,
              onChanged: (dt) => setState(() => _customStart = dt),
            ),
            const SizedBox(height: 8),
            _DateTimePicker(
              label: '结束',
              value: _customEnd,
              onChanged: (dt) => setState(() => _customEnd = dt),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_customStart != null && _customEnd != null)
                    ? () {
                        widget.controller
                            .setCustomRange(_customStart!, _customEnd!);
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text('确认'),
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _DateTimePicker extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;

  const _DateTimePicker({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 40,
          child: Text(label,
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade600)),
        ),
        Expanded(
          child: OutlinedButton(
            onPressed: () async {
              final now = DateTime.now();
              final date = await showDatePicker(
                context: context,
                initialDate: value ?? now,
                firstDate: now.subtract(const Duration(days: 30)),
                lastDate: now,
              );
              if (date == null || !context.mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime:
                    TimeOfDay.fromDateTime(value ?? now),
              );
              if (time == null) return;
              onChanged(DateTime(
                  date.year, date.month, date.day,
                  time.hour, time.minute));
            },
            child: Text(
              value != null
                  ? '${value!.month}/${value!.day} '
                    '${value!.hour.toString().padLeft(2, '0')}:'
                    '${value!.minute.toString().padLeft(2, '0')}'
                  : '请选择',
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}
