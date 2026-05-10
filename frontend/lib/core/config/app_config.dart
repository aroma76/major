class AppConfig {
  // ── Backend URLs ──
  // Development:  'http://localhost:5000/api'
  // Production:   'https://major-gin9.onrender.com/api'
  static const String _productionUrl = 'https://major-gin9.onrender.com';
  static String get baseUrl => _productionUrl;

  static String get apiUrl => '$baseUrl/api';

  // Your Vercel frontend URL (for reference)
  static const String vercelUrl = 'https://major-three-tau.vercel.app';
}
