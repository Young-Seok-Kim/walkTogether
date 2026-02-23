import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EnvConfig {
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static String get currentSha1 {
    String sha1 = '';
    if (kDebugMode) {
      sha1 = dotenv.env['DEBUG_SHA1'] ?? '';
    } else {
      sha1 = dotenv.env['RELEASE_SHA1'] ?? '';
    }

    // 🎯 [로그 출력] 현재 앱이 어떤 모드로 어떤 키를 쓰는지 터미널에 찍어줍니다.
    print('-----------------------------------------');
    print('📍 [EnvConfig] 현재 모드: ${kDebugMode ? "DEBUG" : "RELEASE"}');
    print('📍 [EnvConfig] 전송 중인 SHA-1: $sha1');
    print('📍 [EnvConfig] 사용 중인 API KEY: ${googleMapsApiKey.substring(0, 10)}...'); // 보안상 앞부분만
    print('-----------------------------------------');

    return sha1;
  }
}