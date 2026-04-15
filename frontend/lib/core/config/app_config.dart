import 'package:flutter/foundation.dart';

class AppConfig {
  // ── Your Render backend URL (production) ──
  static const String _renderUrl = 'https://major-gin9.onrender.com';

  static const String _localUrl = 'http://127.0.0.1:5000';

  // ── Auto-select URL based on platform ──
  static String get baseUrl {
    // Use Web debug mode to point to local backend
    return kDebugMode ? _localUrl : _renderUrl;
  }

  static String get apiUrl => '$baseUrl/api';

  // Your Vercel frontend URL (for reference)
  static const String vercelUrl = 'https://major-three-tau.vercel.app';
}

