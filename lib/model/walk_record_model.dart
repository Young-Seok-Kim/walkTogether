import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:walk_together/model/path_point.dart';

class WalkRecord {
  final String? id;
  final String firebaseUserId;
  final String kakaoUserId;
  final String kakaoUserNickname;
  final String? kakaoUserProfileUrl;
  final String title;
  final DateTime startTime;
  final int duration;
  final double distance;
  final List<PathPoint> path;
  final double? startLatitude;
  final double? startLongitude;
  final double? endLatitude;
  final double? endLongitude;
  final bool isWalking;
  final bool isPublic;
  final int likeCount;
  final int commentCount;
  final List<String> likedUserIds; // 좋아요 누른 유저 ID 리스트
  final bool isLiked; // 내가 좋아요를 눌렀는지 여부 (UI용)

  WalkRecord({
    this.id,
    required this.firebaseUserId,
    required this.kakaoUserId,
    required this.kakaoUserNickname,
    required this.kakaoUserProfileUrl,
    required this.title,
    required this.startTime,
    required this.duration,
    required this.distance,
    required this.path,
    this.startLatitude,
    this.startLongitude,
    this.endLatitude,
    this.endLongitude,
    this.isWalking = false,
    this.isPublic = false,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedUserIds = const [], // 초기값 빈 리스트
    this.isLiked = false,         // 초기값 false
  });

  DateTime get endTime => startTime.add(Duration(seconds: duration));

  Map<String, dynamic> toMap() {
    return {
      'firebaseUserId': firebaseUserId,
      'kakaoUserId': kakaoUserId,
      'kakaoUserNickname': kakaoUserNickname,
      'kakaoUserProfileUrl': kakaoUserProfileUrl,
      'title': title,
      'startTime': startTime,
      'duration': duration,
      'distance': distance,
      'path': path.map((p) => {
        'lat': double.parse(p.latLng.latitude.toStringAsFixed(6)),
        'lng': double.parse(p.latLng.longitude.toStringAsFixed(6)),
        'speed': p.speed, // ✅ 속도 추가!
        'ts': p.timestamp.toIso8601String(), // ✅ 시간 정보도 저장하면 나중에 유용함
      }).toList(),

      // 시작/종료 지점 (PathPoint의 latLng 사용)
      'startLatitude': startLatitude ?? (path.isNotEmpty ? path.first.latLng.latitude : 0.0),
      'startLongitude': startLongitude ?? (path.isNotEmpty ? path.first.latLng.longitude : 0.0),
      'endLatitude': endLatitude ?? (path.isNotEmpty ? path.last.latLng.latitude : 0.0),
      'endLongitude': endLongitude ?? (path.isNotEmpty ? path.last.latLng.longitude : 0.0),
      'isPublic': isPublic,
      'likeCount': likeCount,
      'commentCount': commentCount,
      'likedUserIds': likedUserIds, // ✅ 서버에 저장
    };
  }

  factory WalkRecord.fromFirestore(Map<String, dynamic> data, String documentId, {String? currentUserId}) {
    // 서버에서 가져온 좋아요 명단
    final List<String> likedUsers = List<String>.from(data['likedUserIds'] ?? []);


    final List<dynamic> rawPath = data['path'] ?? [];
    final List<PathPoint> parsedPath = rawPath.map((p) {
      return PathPoint(
        latLng: LatLng(
          (p['lat'] as num).toDouble(),
          (p['lng'] as num).toDouble(),
        ),
        // ✅ 기존 데이터에는 speed가 없을 수 있으므로 0.0으로 기본값 설정
        speed: (p['speed'] as num? ?? 0.0).toDouble(),
        // ✅ 기존 데이터에는 ts가 없을 수 있으므로 현재 시간이나 startTime으로 설정
        timestamp: p['ts'] != null
            ? DateTime.parse(p['ts'])
            : (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }).toList();

    return WalkRecord(
      id: documentId,
      firebaseUserId: data['firebaseUserId'] ?? '',
      kakaoUserId: data['kakaoUserId'] ?? '',
      kakaoUserNickname: data['kakaoUserNickname'] ?? '익명',
      kakaoUserProfileUrl: data['kakaoUserProfileUrl'],
      title: data['title'] ?? '제목 없음',
      startTime: (data['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      duration: data['duration'] ?? 0,
      distance: (data['distance'] as num? ?? 0.0).toDouble(),
      path: parsedPath, // 👈 위에서 변환한 PathPoint 리스트 주입

      // 시작/종료 좌표 접근 시 .latLng를 붙여줘야 함
      startLatitude: data['startLatitude']?.toDouble() ??
          (parsedPath.isNotEmpty ? parsedPath.first.latLng.latitude : 0.0),
      startLongitude: data['startLongitude']?.toDouble() ??
          (parsedPath.isNotEmpty ? parsedPath.first.latLng.longitude : 0.0),
      endLatitude: data['endLatitude']?.toDouble() ??
          (parsedPath.isNotEmpty ? parsedPath.last.latLng.latitude : 0.0),
      endLongitude: data['endLongitude']?.toDouble() ??
          (parsedPath.isNotEmpty ? parsedPath.last.latLng.longitude : 0.0),
      isWalking: data['isWalking'] ?? false,
      isPublic: data['isPublic'] ?? false,
      likeCount: data['likeCount'] ?? 0,
      commentCount: data['commentCount'] ?? 0,
      likedUserIds: likedUsers,
      isLiked: currentUserId != null && likedUsers.contains(currentUserId),

      // 🎯 [추가 포인트] 만약 모델 클래스 필드에 startLatitude를 따로 만드셨다면 여기서 받으면 됩니다.
      // 여기서 따로 변수에 담지 않아도 path.first로 접근 가능하니 문제는 없습니다!
    );
  }

  WalkRecord copyWith({
    String? id,
    String? firebaseUserId,
    String? kakaoUserId,
    String? kakaoUserNickname,
    String? kakaoUserProfileUrl,
    String? title,
    DateTime? startTime,
    int? duration,
    double? distance,
    List<PathPoint>? path,
    bool? isPublic,
    int? likeCount,
    int? commentCount,
    List<String>? likedUserIds,
    bool? isLiked,
  }) {
    return WalkRecord(
      id: id ?? this.id,
      firebaseUserId: firebaseUserId ?? this.firebaseUserId,
      kakaoUserId: kakaoUserId ?? this.kakaoUserId,
      kakaoUserNickname: kakaoUserNickname ?? this.kakaoUserNickname,
      kakaoUserProfileUrl: kakaoUserProfileUrl ?? this.kakaoUserProfileUrl,
      title: title ?? this.title,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      distance: distance ?? this.distance,
      path: path ?? this.path,
      isWalking: isWalking ?? this.isWalking,
      isPublic: isPublic ?? this.isPublic,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedUserIds: likedUserIds ?? this.likedUserIds,
      isLiked: isLiked ?? this.isLiked,
    );
  }

  Map<String, dynamic> toJson() => {
    'path': path.map((e) => e.toJson()).toList(), // 👈 PathPoint 내부 메서드 사용
    'startTime': startTime.toIso8601String(),
    'isWalking': isWalking,
  };
}