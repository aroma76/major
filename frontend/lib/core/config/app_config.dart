class AppConfig {
  // ── Backend URLs ──
  // Development:  'http://localhost:5000'
  // Production:   'https://major-gin9.onrender.com'
  static const String _productionUrl = 'https://major-gin9.onrender.com';
  static const String _devUrl        = 'http://localhost:5000';
  static String get baseUrl => _productionUrl; // ← switch to _devUrl for local dev

  static String get apiUrl => '$baseUrl/api';

  // Your Vercel frontend URL (for reference)
  static const String vercelUrl = 'https://major-three-tau.vercel.app';
}
