import 'dart:async';

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
  bool _permissionGranted = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _reportTimer?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startReporting();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      stopReporting();
    }
  }

  /// Start periodic location reporting. Call after login / app resume.
  Future<void> startReporting() async {
    if (isReporting.value) return;
    if (!_storage.isLoggedIn) return;

    if (!_permissionGranted) {
      _permissionGranted = await _checkAndRequestPermission();
      if (!_permissionGranted) return;
    }

    isReporting.value = true;
    _scheduleTimer();
    // Report immediately on start
    await _reportCurrentLocation();
  }

  /// Stop periodic location reporting. Call on logout / app pause.
  void stopReporting() {
    _reportTimer?.cancel();
    _reportTimer = null;
    isReporting.value = false;
  }

  /// Restart timer with current frequency setting.
  void updateFrequency() {
    if (!isReporting.value) return;
    _reportTimer?.cancel();
    _scheduleTimer();
  }

  void _scheduleTimer() {
    final seconds = _storage.read<int>(AppConstants.locationFrequencyKey) ??
        AppConstants.frequencyStandard;
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
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

    return true;
  }
}
