import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:permission_handler/permission_handler.dart';
// ✅ 임포트 경로가 정확한지 다시 한번 확인해주세요.
import 'package:android_intent_plus/android_intent.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:fluttertoast/fluttertoast.dart';

final permissionProvider = StateNotifierProvider<PermissionNotifier, Map<Permission, PermissionStatus>>((ref) {
  return PermissionNotifier();
});

class PermissionNotifier extends StateNotifier<Map<Permission, PermissionStatus>> {
  PermissionNotifier() : super({});

  final List<Permission> _requiredPermissions = [
    Permission.location,
    Permission.locationAlways,
    Permission.notification,
  ];

  Future<bool> requestAllPermissions() async {
    // 1. 기본 권한 요청 (위치 사용 중 허용, 알림)
    Map<Permission, PermissionStatus> statuses = await [
      Permission.location,
      Permission.notification,
    ].request();

    // 2. 위치 권한이 허용되었다면 '항상 허용' 상태만 확인해서 state에 저장
    if (statuses[Permission.location]?.isGranted ?? false) {
      var alwaysStatus = await Permission.locationAlways.status;
      statuses[Permission.locationAlways] = alwaysStatus;
    }

    state = statuses;

    return (statuses[Permission.location]?.isGranted ?? false) &&
        (statuses[Permission.notification]?.isGranted ?? false);
  }

  Future<void> checkInitialStatus() async {
    Map<Permission, PermissionStatus> currentStatuses = {};
    for (var permission in _requiredPermissions) {
      currentStatuses[permission] = await permission.status;
    }
    state = currentStatuses;
  }

  Future<void> _openDeepLocationSettings() async {
    if (Platform.isAndroid) {
      try {
        final packageInfo = await PackageInfo.fromPlatform();
        final String packageName = packageInfo.packageName;

        //  '어플리케이션 정보'가 아니라 '위치 권한 상세 설정'으로 유도
        final intent = AndroidIntent(
          action: 'android.settings.LOCATION_SOURCE_SETTINGS', // 혹은 아래 action 시도
          // 일부 제조사/버전에서는 아래 액션이 위치 권한 리스트로 바로 보냅니다.
          // action: 'android.settings.location.PERMISSION_DETAILS',
          // arguments: {'package': packageName},
        );

        // 만약 위 설정이 안 먹히면 가장 확실한 방법은 아래 '권한' 페이지 직접 호출입니다.
        const intentPermission = AndroidIntent(
          action: 'android.intent.action.MANAGE_APP_PERMISSIONS',
          arguments: {
            'android.intent.extra.PACKAGE_NAME': 'com.youngs.way_together', // 본인 패키지명
          },
        );

        await intent.launch();
      } catch (e) {
        debugPrint("인텐트 실행 에러: $e");
        // 실패 시 차선책으로 기본 설정창 열기
        await openAppSettings();
      }
    } else {
      await openAppSettings();
    }
  }
  // viewmodel/permission_notifier.dart

  Future<void> openSystemSettings() async {
    if (Platform.isAndroid) {
      try {
        // 가장 확실하게 해당 앱의 권한 설정 페이지로 보내는 인텐트
        final intent = AndroidIntent(
          action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
          data: 'package:com.youngs.way_together',
        );
        await intent.launch();
      } catch (e) {
        await openAppSettings();
      }
    } else {
      await openAppSettings();
    }
  }
}