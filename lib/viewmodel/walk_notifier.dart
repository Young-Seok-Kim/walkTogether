import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:walk_together/model/path_point.dart';
import 'package:walk_together/viewmodel/settings_notifier.dart';

import '../model/walk_record_model.dart';
import '../model/walk_state.dart';
import '../repository/walk_repository.dart';
import '../utils/map_utils.dart';
import 'auth_notifier.dart';

class WalkNotifier extends Notifier<WalkState> {
  static const _storageKey = 'temp_walk_data';

  @override
  WalkState build() {
    _loadFromLocal(); // 앱 켜질 때 주머니 뒤지기

    // 백그라운드 서비스에서 좌표 날아오면 낚아채기
    FlutterBackgroundService().on('updateLocation').listen((event) {
      if (event != null) {
          // 🎯 여기서 PathPoint를 생성해서 넘겨줍니다.
          final newPoint = PathPoint(
            latLng: LatLng(event['lat'], event['lng']),
            timestamp: DateTime.now(),
            // 서비스에서 속도를 주면 사용하고, 없으면 0.0
            speed: (event['speed'] as num? ?? 0.0).toDouble(),
          );

          addLocation(newPoint);
      }
    });

    return WalkState();
  }

  // --- [데이터 생존 로직] ---
  Future<void> _loadFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final rawData = prefs.getString(_storageKey);
    if (rawData != null) {
      state = WalkState.fromJson(jsonDecode(rawData));
      print("🧟 좀비 부활! 좌표 ${state.path.length}개 복구됨");
    }
  }

  Future<void> _saveToLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(state.toJson()));
  }

  // --- [산책 컨트롤] ---
  void startWalk() {
    state = WalkState(path: [], startTime: DateTime.now(), isWalking: true);
    _saveToLocal();
  }

  void addLocation(PathPoint loc) {
    if (!state.isWalking) return;
    state = state.copyWith(path: [...state.path, loc]);
    if (state.path.length % 3 == 0) {
      _saveToLocal();
    }
  }

  Future<WalkRecord?> processWalkSaving(String title, {List<PathPoint>? path, DateTime? startTime}) async {
    final stopwatch = Stopwatch()..start();
    print("⏱️ [로그 시작] 저장 프로세스 진입");

    // 1. 상태 업데이트 시간 측정
    state = state.copyWith(isLoading: true, hasError: false);
    print("⏱️ [1. State Copy] 완료: ${stopwatch.elapsedMilliseconds}ms (좌표수: ${state.path.length})");

    try {
      // 1. 카카오 유저 정보 가져오기
      final kakaoUser = await ref
          .read(authProvider.notifier)
          .getOrFetchKakaoUser();
      print("⏱️ [2. Kakao User] 완료: ${stopwatch.elapsedMilliseconds}ms");

      final finalPath = path ?? [];
      final finalStartTime = startTime ?? state.startTime ?? DateTime.now();

      // 2. 저장할 데이터 생성 (프사, 닉네임 포함)
      final record = WalkRecord(
        firebaseUserId: FirebaseAuth.instance.currentUser?.uid ?? '',
        kakaoUserId: kakaoUser.id.toString(),
        kakaoUserNickname: kakaoUser.nickname,
        kakaoUserProfileUrl: kakaoUser.profileUrl,
        title: title,
        startTime: state.startTime ?? DateTime.now(),
        duration: DateTime.now()
            .difference(state.startTime ?? DateTime.now())
            .inSeconds,
        distance: _calculateTotalDistance(finalPath),
        path: finalPath,
        isWalking: true,
        isPublic: true,
      );
      print("⏱️ [3. Record 생성] 완료: ${stopwatch.elapsedMilliseconds}ms");

      print("⏱️ [4. Firestore 전송 시작] 데이터 직렬화 중...");
      // 3. 서버(Firestore)에 먼저 저장 시도
      final savedId = await ref
          .read(walkRepositoryProvider)
          .saveWalkToFirebase(record);
      print("⏱️ [4. Firestore 전송 완료] 완료: ${stopwatch.elapsedMilliseconds}ms");

      // ✅ 4. 서버 저장이 완전히 성공한 후에만 로컬 임시 저장 데이터를 비웁니다.
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey); // 임시 저장 키 삭제
      print("⏱️ [5. Prefs 삭제] 완료: ${stopwatch.elapsedMilliseconds}ms");

      // 5. 현재 트래킹 중인 메모리 상태 초기화
      state = WalkState();
      stopwatch.stop();
      print("🚀 [로그 종료] 총 소요시간: ${stopwatch.elapsedMilliseconds}ms");

      print("🚀 서버 저장 완료 및 로컬 데이터 초기화 성공!");

      // 6. 저장된 ID를 포함한 레코드 반환
      return record.copyWith(id: savedId);
    } catch (e) {
      // 🔥 서버 저장 중 에러가 나면 이쪽으로 빠집니다.
      // 이때는 로컬 데이터(SharedPreferences)를 삭제하지 않으므로 데이터가 보존됩니다.
      state = state.copyWith(
        isLoading: false,
        hasError: true,
        error: e.toString(),
      );
      print("❌ 서버 저장 실패: $e");
      return null;
    }
  }


  double _calculateTotalDistance(List<PathPoint> path) {
    if (path.length < 2) return 0;

    double total = 0;
    final targetSpeed = ref.read(settingsProvider); // 설정된 기준 속도 가져오기

    for (int i = 0; i < path.length - 1; i++) {
      if (path.length < 2) return 0; // 점이 0개나 1개면 바로 0 리턴하고 종료!
      final nextPoint = path[i + 1];

      double distance = Geolocator.distanceBetween(
        path[i].latLng.latitude,
        path[i].latLng.longitude,
        path[i + 1].latLng.latitude,
        path[i + 1].latLng.longitude,
      );

      if (distance < 50.0 && distance >= 1.5 /*&& nextPoint.speed <= targetSpeed*/) {
        total += distance;
      } else {
        // 속도가 빠르거나 거리가 너무 멀면(차 이동) 합산에서 제외
        print("🚀 제외 구간: ${distance.toStringAsFixed(1)}m, 속도: ${nextPoint.speed.toStringAsFixed(1)}km/h");
      }
    }
    debugPrint("📊 [최종 합산 결과] 총 거리: ${total.toStringAsFixed(2)}m");
    return total;
  }

  void updateDistance(double gap) {
    // 기존의 총 거리에 방금 들어온 gap(검증된 거리)을 더해서 상태를 업데이트합니다.
    state = state.copyWith(
        distance: state.distance + gap
    );

    // 로그로 실시간 확인 (나중에 지우셔도 됩니다 ㅋ)
    print("📏 거리 업데이트: +${gap.toStringAsFixed(2)}m (총: ${state.distance.toStringAsFixed(2)}m)");
  }
}

// 3. [Provider] 밖에서 이 뷰모델을 부를 때 쓰는 이름
final walkNotifierProvider = NotifierProvider<WalkNotifier, WalkState>(() {
  return WalkNotifier();
});
