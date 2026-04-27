class AppConfig {
  // ── Backend URLs ──
  // Production (Render): 'https://major-gin9.onrender.com'
  static const String _localUrl = 'http://localhost:5000';

  // ── Auto-select URL based on environment ──
  static const String _productionUrl = 'https://major-gin9.onrender.com';
  static String get baseUrl => _productionUrl;

  static String get apiUrl => '$baseUrl/api';

  // Your Vercel frontend URL (for reference)
  static const String vercelUrl = 'https://major-three-tau.vercel.app';
}
