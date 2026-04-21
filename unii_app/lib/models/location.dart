class LocationData {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final String? recordedAt;

  LocationData({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    this.recordedAt,
  });

  factory LocationData.fromJson(Map<String, dynamic> json) {
    return LocationData(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      recordedAt: json['recorded_at'],
    );
  }

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        if (altitude != null) 'altitude': altitude,
        if (accuracy != null) 'accuracy': accuracy,
        if (speed != null) 'speed': speed,
      };
}

class MemberLocation {
  final String userId;
  final String nickname;
  final String? avatarUrl;
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? accuracy;
  final double? speed;
  final String recordedAt;
  final bool isOnline;

  MemberLocation({
    required this.userId,
    required this.nickname,
    this.avatarUrl,
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.accuracy,
    this.speed,
    required this.recordedAt,
    this.isOnline = false,
  });

  factory MemberLocation.fromJson(Map<String, dynamic> json) {
    return MemberLocation(
      userId: json['user_id'],
      nickname: json['nickname'],
      avatarUrl: json['avatar_url'],
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      recordedAt: json['recorded_at'],
      isOnline: json['is_online'] ?? false,
    );
  }

  MemberLocation copyWith({bool? isOnline}) {
    return MemberLocation(
      userId: userId,
      nickname: nickname,
      avatarUrl: avatarUrl,
      latitude: latitude,
      longitude: longitude,
      altitude: altitude,
      accuracy: accuracy,
      speed: speed,
      recordedAt: recordedAt,
      isOnline: isOnline ?? this.isOnline,
    );
  }

  /// Whether this location is older than 5 minutes
  bool get isStale {
    final recorded = DateTime.tryParse(recordedAt);
    if (recorded == null) return true;
    return DateTime.now().difference(recorded).inMinutes >= 5;
  }

  /// Human-readable time ago string (only shown when stale)
  String get timeAgoText {
    final recorded = DateTime.tryParse(recordedAt);
    if (recorded == null) return '';
    final diff = DateTime.now().difference(recorded);
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    return '${diff.inMinutes}分钟前';
  }
}

class TrackPoint {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final String recordedAt;

  TrackPoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    required this.recordedAt,
  });

  factory TrackPoint.fromJson(Map<String, dynamic> json) {
    return TrackPoint(
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      recordedAt: json['recorded_at'],
    );
  }
}
