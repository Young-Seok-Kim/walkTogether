import 'package:google_maps_flutter/google_maps_flutter.dart';

class PathPoint {
  final LatLng latLng;
  final DateTime timestamp;
  final double speed; // km/h
  final bool isWalkStep;

  PathPoint({
    required this.latLng,
    required this.timestamp,
    this.speed = 0.0,
    this.isWalkStep = true, // 기본은 걷기라고 가정
  });

  Map<String, dynamic> toJson() => {
    'lat': latLng.latitude,
    'lng': latLng.longitude,
    'ts': timestamp.toIso8601String(),
    'speed': speed,
  };

  // 📖 데이터 복구용
  factory PathPoint.fromJson(Map<String, dynamic> json) => PathPoint(
    latLng: LatLng(json['lat'] as double, json['lng'] as double),
    timestamp: DateTime.parse(json['ts'] as String),
    speed: (json['speed'] as num).toDouble(),
  );
}