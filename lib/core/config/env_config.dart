import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class EnvConfig {
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  static String get currentSha1 {
    if (kDebugMode) {
      return dotenv.env['DEBUG_SHA1'] ?? '';
    } else {
      return dotenv.env['RELEASE_SHA1'] ?? '';
    }
  }
}