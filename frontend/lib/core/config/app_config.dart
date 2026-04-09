import 'package:flutter/foundation.dart';

class AppConfig {
  // ── Your Render backend URL (production) ──
  static const String _renderUrl = 'https://major-gin9.onrender.com';

  // ── Auto-select URL based on platform ──
  static String get baseUrl {
    // ALWAYS USE RENDER URL SO THE VERCEL APP WORKS ONLINE!
    return _renderUrl;
  }

  static String get apiUrl => '$baseUrl/api';

  // Your Vercel frontend URL (for reference)
  static const String vercelUrl = 'https://major-three-tau.vercel.app';
}

