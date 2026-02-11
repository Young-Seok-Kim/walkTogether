import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../main.dart';
import '../../presentation/course/mine/my_course_detail_screen.dart';
import '../../viewmodel/navigation_notifier.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    // 💡 핵심 수정 포인트:
    // 최신 버전에서는 AndroidInitializationSettings에 아이콘 이름을 넣을 때
    // 'defaultIcon' 혹은 위치에 맞는 파라미터명이 요구될 수 있습니다.
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings();

    // 💡 여기서 에러가 나는 경우, 아래처럼 명시적으로 파라미터를 작성해야 합니다.
    const InitializationSettings initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        if (details.payload != null) {
          print("포그라운드 알림 클릭: ${details.payload}");
          // 💡 핵심: 전역 컨테이너를 통해 상태 변경
          globalContainer.read(pendingNotificationCourseIdProvider.notifier).state = details.payload!.trim();
        }
      },
    );

    // 채널 생성 부분
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: '중요한 알림 채널입니다.',
      importance: Importance.max,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await androidPlugin.createNotificationChannel(channel);
    }
  }

  static void showNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;

    if (notification != null) {
      _plugin.show(
        id : notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            channelDescription: '중요한 알림 채널입니다.',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data['courseId']?.toString().trim(),
      );
    }
  }

  static Future<void> setupInteractedMessage(WidgetRef ref) async {
    // 1. 앱이 완전히 종료된 상태에서 알림을 눌러 켰을 때
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();

    String? test = initialMessage?.data['courseId'];

    print("알림클릭: $test");

    if (initialMessage != null) {
      _handleMessage(initialMessage, ref);
    }

    // 2. 앱이 백그라운드에 있을 때 알림을 눌렀을 때
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      _handleMessage(message, ref);
    });
  }

  static void _handleMessage(RemoteMessage message, WidgetRef ref) {
    final String? courseId = message.data['courseId'];
    if (courseId != null && courseId.isNotEmpty) {
      // 💡 데이터가 확실할 때만 ViewModel 상태를 업데이트
      ref.read(pendingNotificationCourseIdProvider.notifier).state = courseId.trim();
    }
  }

  static void handleMessage(WidgetRef ref, RemoteMessage message) {
    // 알림 데이터에서 courseId 추출 (데이터 구조에 맞게 수정하세요)
    final String? courseId = message.data['courseId'];

    if (courseId != null) {
      // 💡 여기서 Provider 값을 업데이트하면 RootScreen의 ref.listen이 반응합니다.
      ref.read(pendingNotificationCourseIdProvider.notifier).state = courseId;
    }
  }
}