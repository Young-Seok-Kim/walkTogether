import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart'; // 추가 필수
import 'core/utils/notification_service.dart';
import 'presentation/root_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
late ProviderContainer globalContainer;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. 환경 변수 로드 (.env 파일을 가장 먼저 읽어야 함)
  await dotenv.load(fileName: ".env");
  print("🔥 확인된 프로젝트 ID: ${dotenv.env['FIREBASE_PROJECT_ID']}");
  // 2. Firebase 초기화 (env에서 값을 가져옴)
  // const FirebaseOptions는 런타임 변수를 쓸 수 없으므로 const를 제거합니다.
  await Firebase.initializeApp(
    options: FirebaseOptions(
      apiKey: dotenv.env['FIREBASE_API_KEY'] ?? '',
      appId: dotenv.env['FIREBASE_APP_ID'] ?? '',
      messagingSenderId: dotenv.env['FIREBASE_MESSAGING_SENDER_ID'] ?? '',
      projectId: dotenv.env['FIREBASE_PROJECT_ID'] ?? '',
      storageBucket: dotenv.env['FIREBASE_STORAGE_BUCKET'] ?? '',
    ),
  );
  globalContainer = ProviderContainer();
  await LocalNotificationService.init();

  // 3. 카카오 SDK 초기화
  KakaoSdk.init(nativeAppKey: dotenv.env['KAKAO_NATIVE_KEY'] ?? '');

  // 디버깅용 로그
  print("실제 카카오 전송 키 해시: ${await KakaoSdk.origin}");

  runApp(
    UncontrolledProviderScope(
      container: globalContainer,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: '함께,이길',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueAccent,
      ),
      home: const RootScreen(),
    );
  }
}