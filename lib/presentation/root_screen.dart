import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:walk_together/presentation/login/login_screen.dart';
import 'package:walk_together/presentation/main_screen.dart';
import 'package:walk_together/viewmodel/auth_notifier.dart';
import '../core/utils/notification_service.dart';
import '../main.dart';
import '../viewmodel/map_notifier.dart';
import '../viewmodel/navigation_notifier.dart';
import '../viewmodel/permission_notifier.dart';
import 'course/mine/my_course_detail_screen.dart';

class RootScreen extends ConsumerStatefulWidget {
  const RootScreen({super.key});

  @override
  ConsumerState<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends ConsumerState<RootScreen> with WidgetsBindingObserver {
  bool _isPermissionChecked = false;
  String? _pendingId;

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingNotificationCourseIdProvider, (previous, next) {
      // 1. null이 아닐 때만 진입
      if (next != null && next.isNotEmpty && next != 'null') {
        _pendingId = next; // ID 보관

        // 즉시 프로바이더 초기화 (중복 진입 방지)
        SchedulerBinding.instance.addPostFrameCallback((_) {
          ref.read(pendingNotificationCourseIdProvider.notifier).state = null;
        });

        // 권한이 이미 있고 앱이 활성화 상태라면 바로 이동
        if (_isPermissionChecked && WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
          _navigateToDetail();
        }
      }
    });

    // 1. 권한 체크가 먼저입니다.
    if (!_isPermissionChecked) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 2. 권한 통과 후 로그인 상태 확인 (AsyncValue 적용)
    final authState = ref.watch(authProvider);

    return authState.when(
      data: (user) => user == null ? const LoginScreen() : const MainScreen(),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, stack) => Scaffold(body: Center(child: Text("로그인 오류: $err"))),
    );
  }

  void _navigateToDetail() {
    if (_pendingId == null || !mounted) return;

    final idToMove = _pendingId!;
    _pendingId = null; // 사용한 ID 즉시 비움 (재진입 방지 핵심)

    print("🚀 상세 화면 이동: $idToMove");
    navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => CourseDetailScreen(courseId: idToMove),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("포그라운드 메시지 수신!");
      LocalNotificationService.showNotification(message);
    });

    FirebaseMessaging.instance.onTokenRefresh.listen((_) {
      ref.read(authProvider.notifier).syncUserToFirestore();
    });

    // 3. 💡 앱 시작 시 로그인 상태라면 토큰 갱신 시도
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(authProvider).value != null) {
        ref.read(authProvider.notifier).syncUserToFirestore();
      }
    });


    LocalNotificationService.setupInteractedMessage(ref); // 알림창을 클릭했을대 이벤트

    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.resumed) {
      // 1. 권한 체크 로직 (기존 코드 유지)
      final notifier = ref.read(permissionProvider.notifier);
      await notifier.checkInitialStatus();
      final status = ref.read(permissionProvider);

      bool hasLocationPermission =
          status[Permission.locationAlways] == PermissionStatus.granted ||
              status[Permission.location] == PermissionStatus.granted;

      if (hasLocationPermission) {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (mounted) {
          setState(() => _isPermissionChecked = true);
        }

        ref.read(mapProvider.notifier).moveToCurrentLocation();

        // 💡 2. 권한 확인 완료 후 보관된 알림 ID가 있다면 이동
        if (_pendingId != null) {
          _navigateToDetail();
        }
      } else {
        if (!_isPermissionChecked) {
          _checkPermissions();
        }
      }
    }
  }

  Future<void> _checkPermissions() async {
    final notifier = ref.read(permissionProvider.notifier);

    await Permission.notification.request();

    // 1. 현재 권한 상태 가져오기
    await notifier.checkInitialStatus();
    final status = ref.read(permissionProvider);

    // 2. 위치 권한이 이미 있다면 즉시 화면 넘기기
    if (status[Permission.locationAlways] == PermissionStatus.granted ||
        status[Permission.location] == PermissionStatus.granted) {
      if (mounted) {
        setState(() => _isPermissionChecked = true);
      }
      return; // 여기서 로직 종료 (지연 방지)
    }

    // 3. 권한이 없는 경우에만 다이얼로그 노출
    if (mounted && !_isPermissionChecked) {
      _showPermissionGuideDialog();
    }
  }


  void _showPermissionGuideDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.location_on, color: Colors.blueAccent),
            SizedBox(width: 8),
            Text("위치 권한 설정"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "정확한 산책 경로를 기록하기 위해\n위치 권한을 '항상 허용'으로 설정해주세요.",
              style: TextStyle(height: 1.5),
            ),
            const SizedBox(height: 20),
            // 💡 간단한 가이드 박스
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _buildStepRow("1", "설정에서 [권한] 클릭"),
                  const SizedBox(height: 8),
                  _buildStepRow("2", "[위치] 항목 선택"),
                  const SizedBox(height: 8),
                  _buildStepRow("3", "[항상 허용]에 체크", isLast: true),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(permissionProvider.notifier).openSystemSettings();
            },
            child: const Text("설정 열기", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(String step, String text, {bool isLast = false}) {
    return Row(
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: Colors.blueAccent,
          child: Text(step, style: const TextStyle(fontSize: 10, color: Colors.white)),
        ),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(fontSize: 13, fontWeight: isLast ? FontWeight.bold : FontWeight.normal)),
      ],
    );
  }
}