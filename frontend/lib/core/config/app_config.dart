import 'package:flutter/foundation.dart';

class AppConfig {
  // ── Your Render backend URL (production) ──
  static const String _renderUrl = 'https://major-gin9.onrender.com';

  // ── Auto-select URL based on platform ──
  static String get baseUrl {
    if (kIsWeb) {
      // Flutter Web (Vercel) → must use Render URL
      return _renderUrl;
    } else {
      // Android Emulator → 10.0.2.2 = your PC's localhost
      return 'http://10.0.2.2:5000';
      // Physical Android phone → use your PC's WiFi IP instead:
      // return 'http://192.168.X.X:5000';
      // Production APK → use Render URL:
      // return _renderUrl;
    }
  }

  static String get apiUrl => '$baseUrl/api';

  // Your Vercel frontend URL (for reference)
  static const String vercelUrl = 'https://major-three-tau.vercel.app';
}

