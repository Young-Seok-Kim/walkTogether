import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:way_together/viewmodel/settings_notifier.dart';
import 'package:way_together/viewmodel/walk_notifier.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/config/env_config.dart';
import '../model/path_point.dart';

final timerProvider = StateProvider<int>((ref) => 0);

class IsTrackingNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void toggle(bool value) => state = value;
}

final isTrackingProvider = NotifierProvider<IsTrackingNotifier, bool>(
  () => IsTrackingNotifier(),
);

final mapProvider = NotifierProvider<MapNotifier, List<LatLng>>(
  () => MapNotifier(),
);

final toiletMarkersProvider = StateProvider<Set<Marker>>((ref) => {});

class MapNotifier extends Notifier<List<LatLng>> {
  GoogleMapController? _mapController;
  StreamSubscription<Position>? _positionStream;
  Timer? _timer;
  DateTime? _lastUpdateTime;
  BitmapDescriptor toiletIcon = BitmapDescriptor.defaultMarker;

  Set<Marker> _toiletMarkers = {};

  Set<Marker> get toiletMarkers => _toiletMarkers;

  @override
  List<LatLng> build() => []; // 초기 상태는 빈 리스트

  // 지도가 생성될 때 컨트롤러 등록
  void setController(GoogleMapController controller) {
    _mapController = controller;
  }

  // 현재 위치로 카메라 이동
  Future<void> moveToCurrentLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      Position? position = await Geolocator.getLastKnownPosition();

      position ??= await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 16, // 적당한 확대 레벨
          ),
        ),
      );
    } catch (e) {
      print("위치 가져오기 실패: $e");
    }
  }

  Future<void> findNearbyToilets() async {
    print("🔍 [테스트] 화장실 찾기 시작 (모드: ${kDebugMode ? '디버그' : '릴리즈'})");

    // 1. 현재 위치 파악
    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final lat = position.latitude;
    final lng = position.longitude;

    // 2. API 키와 SHA1 가져오기 (EnvConfig 직접 사용)
    final String apiKey = EnvConfig.googleMapsApiKey;
    final String sha1 = EnvConfig.currentSha1;

    if (apiKey.isEmpty) {
      print("❌ API 키가 비어있습니다.");
      return;
    }

    final url =
        "https://maps.googleapis.com/maps/api/place/nearbysearch/json"
        "?location=$lat,$lng"
        "&radius=2000" // 1km는 너무 좁을 수 있으니 2km로 추천!
        "&keyword=화장실"
        "&key=$apiKey"
        "&language=ko";

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          "X-Android-Package": "com.youngs.way_together",
          "X-Android-Cert": sha1.trim(),
          // 🎯 추가: 구글 서버가 요구하는 Referer 형식을 강제로 넣어봅니다.
          "Referer": "http://com.youngs.way_together",
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // 구글 응답 상태 확인 (OK가 아니면 제한사항 위반일 확률 높음)
        if (data['status'] == 'OK') {
          final List results = data['results'];

          if (toiletIcon == BitmapDescriptor.defaultMarker) {
            await loadCustomMarker();
          }

          final newMarkers = results.map((place) {
            final location = place['geometry']['location'];
            return Marker(
              markerId: MarkerId(place['place_id']),
              position: LatLng(location['lat'], location['lng']),
              infoWindow: InfoWindow(
                title: place['name'],
                snippet: place['vicinity'] ?? "주변 화장실",
              ),
              icon: toiletIcon,
            );
          }).toSet();

          // 🎯 상태 업데이트
          _toiletMarkers = newMarkers;
          ref.read(toiletMarkersProvider.notifier).state = newMarkers;

          print("🚽 화장실 ${newMarkers.length}개 발견 및 마커 표시 완료!");
        } else {
          print("❌ 구글 응답 에러 상태: ${data['status']}");
          print("❌ 에러 내용: ${data['error_message'] ?? '없음'}");
        }
      }
    } catch (e) {
      print("❌ 화장실 검색 오류: $e");
    }
  }

  // [추가] 화장실 마커 지우기 (산책 집중용 ㅋ)
  void clearToiletMarkers() {
    _toiletMarkers = {};
    state = [...state];
  }

  // [추가] 좌표 소수점 최적화 함수 (6자리까지 제한)
  LatLng _optimizeLatLng(LatLng point) {
    double lat = double.parse(point.latitude.toStringAsFixed(6));
    double lng = double.parse(point.longitude.toStringAsFixed(6));
    return LatLng(lat, lng);
  }

  void toggleTracking(BuildContext context) async {
    final isTracking = ref.read(isTrackingProvider);

    if (isTracking) {
      stopTrackingAndPrepareSave();
    } else {
      ref.read(walkNotifierProvider.notifier).startWalk();
      ref.read(isTrackingProvider.notifier).toggle(true);

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        ref.read(timerProvider.notifier).state++;
      });

      // [3] 실시간 위치 스트림
      _startLocationListening();
    }
  }

  Future<String> _getPlaceName(LatLng point) async {
    try {
      // 한국어 설정
      await setLocaleIdentifier("ko_KR");

      List<Placemark> placemarks = await placemarkFromCoordinates(
        point.latitude,
        point.longitude,
      );

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;

        // 1. '동' 이름 가져오기 (thoroughfare가 보통 '역삼동' 같은 이름입니다)
        String? dongName = p.thoroughfare;

        // 2. 만약 thoroughfare가 비어있다면 subLocality 확인
        if (dongName == null || dongName.isEmpty) {
          dongName = p.subLocality;
        }

        // 3. 동 이름이 있으면 "OO동 산책", 없으면 건물명이나 구 이름 조합
        if (dongName != null && dongName.isNotEmpty) {
          // '번지수'가 포함된 경우를 대비해 숫자가 있다면 제거하는 로직을 넣을 수도 있지만,
          // 보통은 동 이름만 나옵니다.
          return "$dongName";
        } else {
          return "${p.locality ?? p.name ?? '우리 동네'}";
        }
      }
    } catch (e) {
      debugPrint("주소 변환 실패: $e");
    }
    return "새로운 산책 코스";
  }

  Future<String> stopTrackingAndPrepareSave() async {
    await _positionStream?.cancel();
    _positionStream = null;
    _timer?.cancel();

    if (state.isEmpty || state.length < 2) {
      _resetTrackingState();
      return "";
    }

    // 🎯 주소 찾지 말고 그냥 현재 시간만 제목으로 일단 줌
    final now = DateTime.now();
    return "${now.month}월 ${now.day}일 산책";
  }

  // 1. 기록 삭제하고 초기화하기
  void cancelAndReset() {
    // [즉시 실행] 통신과 추적 상태만 바로 끊습니다.
    _positionStream?.cancel();
    _positionStream = null;
    _timer?.cancel();
    _timer = null;

    // 🎯 문을 먼저 엽니다 (시스템에 나갈 수 있다고 알림)
    ref.read(isTrackingProvider.notifier).toggle(false);

    // [지연 실행] 지도의 컨트롤러와 데이터는 화면이 완전히 사라진 뒤에 청소합니다.
    // 300ms -> 800ms 정도로 늘려보세요. 애니메이션이 끝날 시간을 벌어주는 겁니다.
    Future.delayed(const Duration(milliseconds: 800), () {
      _mapController = null; // 지도가 완전히 사라진 뒤에 참조를 끊음
      state = [];
      ref.read(timerProvider.notifier).state = 0;
      _lastUpdateTime = null;
      debugPrint("🧹 백그라운드 자원 정리 완료");
    });
  }

  // 2. 다시 산책 계속하기 (실수로 종료 눌렀을 때)
  void resumeTracking() {
    // 1. 이미 스트림이 돌고 있다면 중복 실행 방지
    if (_positionStream != null) return;

    // 2. 타이머 다시 시작
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      ref.read(timerProvider.notifier).state++;
    });

    // 3. 위치 스트림 다시 시작 (기존 설정 그대로)
    _startLocationListening();

    debugPrint("산책 재개됨 - 현재까지의 경로 수: ${state.length}");
  }

  Future<void> completeAndSave(String title) async {
    final List<LatLng> pathForSaving = List.from(state);
    final DateTime? startTimeForSaving = ref
        .read(walkNotifierProvider)
        .startTime;

    await _positionStream?.cancel();
    _positionStream = null;
    _timer?.cancel();
    _timer = null;
    final walkState = ref.read(walkNotifierProvider);
    final List<PathPoint> rawPath = walkState.path;

    _resetTrackingState();
    await Future.delayed(const Duration(milliseconds: 100));

    ref
        .read(walkNotifierProvider.notifier)
        .processWalkSaving(title, path: rawPath, startTime: startTimeForSaving);
  }

  // 공통 초기화 로직
  void _resetTrackingState() {
    _lastUpdateTime = null;
    ref.read(timerProvider.notifier).state = 0;
    state = [];
    ref.read(isTrackingProvider.notifier).toggle(false);
  }

  Future<String> getPlaceNameAsync(LatLng? firstPoint) async {
    if (firstPoint == null) return "";

    try {
      print("DEBUG: 주소 변환 시작... 좌표: $firstPoint");

      // 🎯 1. 한국어로 설정 (함수 내부에서 호출)
      await setLocaleIdentifier("ko_KR");

      // 🎯 2. 주소 가져오기 (localeIdentifier 파라미터 제거)
      final List<Placemark> placemarks = await placemarkFromCoordinates(
        firstPoint.latitude,
        firstPoint.longitude,
      ).timeout(const Duration(seconds: 4));

      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        // thoroughfare: 동 이름 (예: 역삼동)
        // subLocality: 구/동 이름
        final dong =
            p.thoroughfare ?? p.subLocality ?? p.name ?? p.locality ?? "";
        print("DEBUG: 찾은 주소 -> $dong");
        return dong;
      }
    } catch (e) {
      print("DEBUG: 내부 주소 변환 실패: $e");
    }
    return "";
  }

  void _startLocationListening() {
    // 이미 실행 중이면 중복 실행 방지
    if (_positionStream != null) return;

    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 3,
            foregroundNotificationConfig: const ForegroundNotificationConfig(
              notificationText: "산책 경로를 실시간으로 기록하고 있습니다.",
              notificationTitle: "산책 중",
              enableWakeLock: true,
              setOngoing: true,
            ),
          ),
        ).listen((Position position) {
          // 🎯 여기에 사용자님이 고생해서 만든 '철벽 필터 로직'을 딱 한 번만 씁니다.
          if (position.accuracy > 25) return;

          final targetSpeed = ref.read(settingsProvider);
          final currentSpeedKm = position.speed * 3.6;
          final optimizedPoint = _optimizeLatLng(
            LatLng(position.latitude, position.longitude),
          );
          final now = DateTime.now();

          debugPrint(
            "🚀 [실시간 위치] 속도: ${currentSpeedKm.toStringAsFixed(2)} km/h (기준: $targetSpeed)",
          );

          // 1. 데이터 저장 (isWalkStep 판단 포함 - 아까 논의한 대로!)
          bool isValid = currentSpeedKm <= targetSpeed;
          // (여기서 distance 비교 로직도 포함하면 완벽!)

          final PathPoint newPathPoint = PathPoint(
            latLng: optimizedPoint,
            timestamp: now,
            speed: currentSpeedKm,
            isWalkStep: isValid, // 모델 수정했다면 이거 추가!
          );
          ref.read(walkNotifierProvider.notifier).addLocation(newPathPoint);

          // 2. 실시간 거리 누적 (정상 속도일 때만)
          if (state.isNotEmpty) {
            final lastPoint = state.last;
            double distance = Geolocator.distanceBetween(
              lastPoint.latitude,
              lastPoint.longitude,
              optimizedPoint.latitude,
              optimizedPoint.longitude,
            );

            if (isValid && distance < 50.0) {
              ref.read(walkNotifierProvider.notifier).updateDistance(distance);
            }
          }

          // 3. 지도 상태 업데이트
          _lastUpdateTime = now;
          state = [...state, optimizedPoint];
        });
  }

  Future<void> loadCustomMarker() async {
    toiletIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)), // 화면에 보일 논리적 크기
      'assets/icon/ic_toilet.png',
    );
  }
}
