import 'dart:async';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart';

// 이 함수가 바로 main.dart에서 호출할 녀석입니다.
Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      // 서비스가 시작될 때 실행될 함수
      autoStart: false,
      // 일단은 버튼 누를 때만 시작하게 false
      isForegroundMode: true,
      notificationChannelId: 'my_foreground',
      initialNotificationTitle: '산책 기록 중',
      initialNotificationContent: '위치 데이터를 수집하고 있습니다.',
    ),
    iosConfiguration: IosConfiguration(),
  );
}

// 백그라운드에서 실제로 돌아가는 로직 (위치 수집 등)
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // 1. 위치 설정 (정확도 높게)
  const locationSettings = LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5, // 5미터 이동할 때마다 업데이트
  );

  // 2. 위치 스트림 구독
  Geolocator.getPositionStream(locationSettings: locationSettings).listen((Position position) async {

    // 메인 앱으로 좌표 전달
    service.invoke('updateLocation', {
      "lat": position.latitude,
      "lng": position.longitude,
    });

    // 안드로이드 알림창 업데이트
    if (service is AndroidServiceInstance) {
      // 이제 여기서 await를 마음껏 쓸 수 있습니다 ㅋ
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "열심히 산책 중!",
          content: "현재까지 이동 경로를 안전하게 기록하고 있습니다.",
        );
      }
    }
  });
}
