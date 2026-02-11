import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../model/path_point.dart'; // PathPoint 모델 경로 확인

class MapUtils {
  /// 속도에 따라 색상이 변하는 폴리라인 세트를 생성합니다.
  static Set<Polyline> createGradientPolylines(List<PathPoint> path, double targetSpeed) {
    final Set<Polyline> polylines = {};

    for (int i = 0; i < path.length - 1; i++) {
      final p1 = path[i];
      final p2 = path[i + 1];

      final Color segmentColor = p2.speed >= targetSpeed
          ? Colors.redAccent
          : Colors.blueAccent;

      polylines.add(
        Polyline(
          polylineId: PolylineId('segment_${i}_${p2.timestamp.millisecondsSinceEpoch}'),
          points: [p1.latLng, p2.latLng],
          color: segmentColor,
          width: 6,
          jointType: JointType.round,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
        ),
      );
    }
    return polylines;
  }

  static List<LatLng> toLatLngList(List<PathPoint> path) {
    return path.map((p) => p.latLng).toList();
  }
}