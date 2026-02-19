import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:way_together/model/path_point.dart';

class WalkState {
  final List<PathPoint> path;
  final DateTime? startTime;
  final double distance;
  final bool isWalking;
  final bool isLoading; // UI 로딩 뱅글뱅글용
  final bool hasError; // 에러 발생 체크용
  final String? error; // 에러 메시지 담기

  WalkState({
    this.path = const [],
    this.startTime,
    this.distance = 0.0,
    this.isWalking = false,
    this.isLoading = false,
    this.hasError = false,
    this.error,
  });

  // 상태를 부분적으로 변경할 때 쓰는 함수
  WalkState copyWith({
    List<PathPoint>? path,
    DateTime? startTime,
    double? distance,
    bool? isWalking,
    bool? isLoading,
    bool? hasError,
    String? error,
  }) {
    return WalkState(
      path: path ?? this.path,
      startTime: startTime ?? this.startTime,
      distance: distance ?? this.distance,
      isWalking: isWalking ?? this.isWalking,
      isLoading: isLoading ?? this.isLoading,
      hasError: hasError ?? this.hasError,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path.map((e) => e.toJson()).toList(),
    'startTime': startTime?.toIso8601String(),
    'isWalking': isWalking,
  };

  // 📖 복구용
  factory WalkState.fromJson(Map<String, dynamic> json) => WalkState(
    path: (json['path'] as List? ?? []) // 데이터가 없을 때를 대비해 null 체크 추가
        .map((e) => PathPoint.fromJson(e as Map<String, dynamic>)) // 🎯 PathPoint의 fromJson 호출!
        .toList(),
    startTime: json['startTime'] != null
        ? DateTime.parse(json['startTime'])
        : null,
    isWalking: json['isWalking'] ?? false,
  );
}