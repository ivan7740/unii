import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';

import '../utils/constants.dart';
import 'location_service.dart';
import 'storage_service.dart';
import 'ws_service.dart';

class LocationReporterService extends GetxService with WidgetsBindingObserver {
  final StorageService _storage = Get.find<StorageService>();
  final WsService _ws = Get.find<WsService>();
  final LocationService _locationService = Get.find<LocationService>();

  final isReporting = false.obs;
  final lastPosition = Rxn<Position>();

  Timer? _reportTimer;
  StreamSubscription<Position>? _backgroundStream;
  bool _permissionGranted = false;
  bool _isInBackground = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _reportTimer?.cancel();
    _backgroundStream?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _exitBackground();
    } else if (state == AppLifecycleState.paused) {
      _enterBackground();
    }
  }

  /// Start periodic location reporting. Call after login.
  Future<void> startReporting() async {
    if (isReporting.value) return;
    if (!_storage.isLoggedIn) return;

    if (!_permissionGranted) {
      _permissionGranted = await _checkAndRequestPermission();
      if (!_permissionGranted) return;
    }

    isReporting.value = true;
    _scheduleTimer(_currentFrequency());
    await _reportCurrentLocation();
  }

  /// Stop all reporting. Call on logout.
  void stopReporting() {
    _reportTimer?.cancel();
    _reportTimer = null;
    _backgroundStream?.cancel();
    _backgroundStream = null;
    isReporting.value = false;
    _isInBackground = false;
  }

  /// Restart timer with current frequency setting (foreground only).
  void updateFrequency() {
    if (!isReporting.value || _isInBackground) return;
    _reportTimer?.cancel();
    _scheduleTimer(_currentFrequency());
  }

  void _enterBackground() {
    if (!isReporting.value) return;
    _isInBackground = true;
    _reportTimer?.cancel();
    _scheduleTimer(AppConstants.frequencyBackground);
    if (Platform.isAndroid) {
      _startBackgroundStream();
    }
  }

  void _exitBackground() {
    _isInBackground = false;
    _backgroundStream?.cancel();
    _backgroundStream = null;
    if (!isReporting.value) {
      startReporting();
    } else {
      _reportTimer?.cancel();
      _scheduleTimer(_currentFrequency());
    }
  }

  /// Android only: start a position stream with foreground service notification
  /// so the OS keeps the process alive in the background.
  void _startBackgroundStream() {
    _backgroundStream?.cancel();
    _backgroundStream = Geolocator.getPositionStream(
      locationSettings: AndroidSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 0,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'UNII 位置共享',
          notificationText: '正在后台共享位置给团队成员',
          enableWakeLock: true,
        ),
      ),
    ).listen((position) {
      lastPosition.value = position;
    });
  }

  int _currentFrequency() {
    return _storage.read<int>(AppConstants.locationFrequencyKey) ??
        AppConstants.frequencyStandard;
  }

  void _scheduleTimer(int seconds) {
    _reportTimer = Timer.periodic(
      Duration(seconds: seconds),
      (_) => _reportCurrentLocation(),
    );
  }

  Future<void> _reportCurrentLocation() async {
    final activeTeamId = _storage.read<String>(AppConstants.activeTeamKey);
    if (activeTeamId == null) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: _isInBackground
              ? LocationAccuracy.medium
              : LocationAccuracy.high,
          distanceFilter: 0,
        ),
      );

      lastPosition.value = position;

      if (_ws.status.value == ConnectionStatus.connected) {
        _ws.sendLocationUpdate(
          teamId: activeTeamId,
          latitude: position.latitude,
          longitude: position.longitude,
          altitude: position.altitude,
          accuracy: position.accuracy,
          speed: position.speed,
        );
      } else {
        await _locationService.reportLocation(
          teamId: activeTeamId,
          latitude: position.latitude,
          longitude: position.longitude,
          altitude: position.altitude,
          accuracy: position.accuracy,
          speed: position.speed,
        );
      }
    } catch (_) {
      // GPS read failed — skip this cycle
    }
  }

  Future<bool> _checkAndRequestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    // Upgrade to always for background access (gracefully degrades if denied)
    if (permission == LocationPermission.whileInUse) {
      await Geolocator.requestPermission();
    }

    return true;
  }
}
