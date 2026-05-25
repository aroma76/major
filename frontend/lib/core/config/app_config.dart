class AppConfig {
  // ── Backend URLs ──
  static const String _productionUrl = 'https://major-gin9.onrender.com';
  static const String _devUrl        = 'http://localhost:5000';

  /// Set to true when running the backend locally.
  /// Flip this back to false before pushing to production.
  static const bool _devMode = false;

  static String get baseUrl => _devMode ? _devUrl : _productionUrl;

  static String get apiUrl => '$baseUrl/api';

  // Your Vercel frontend URL (for reference)
  static const String vercelUrl = 'https://major-three-tau.vercel.app';
}
