import 'storage_service.dart';
import 'api_service.dart';
import 'socket_service.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final _storage = StorageService();
  final _api = ApiService();

  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? get currentUser => _currentUser;

  /// Login with roll number OR email + password
  Future<Map<String, dynamic>> login(String identifier, String password) async {
    final response = await _api.login(identifier, password);
    final data = response.data as Map<String, dynamic>;
    final token = data['token'] as String;
    _currentUser = data['user'] as Map<String, dynamic>;
    await _storage.write('adtu_token', token);
    return _currentUser!;
  }

  /// Register a new student account
  Future<Map<String, dynamic>> signup({
    required String name,
    required String email,
    required String rollNumber,
    required String dob,
    required int programmeId,
    required int batchYear,
    required int currentSemester,
  }) async {
    final response = await _api.signup({
      'name': name,
      'email': email,
      'roll_number': rollNumber,
      'dob': dob,
      'programme_id': programmeId,
      'batch_year': batchYear,
      'current_semester': currentSemester,
      'role': 'student',
    });
    final data = response.data as Map<String, dynamic>;
    final token = data['token'] as String;
    _currentUser = data['user'] as Map<String, dynamic>;
    await _storage.write('adtu_token', token);
    return _currentUser!;
  }

  /// Restore session from stored token
  Future<bool> restoreSession() async {
    final token = await _storage.read('adtu_token');
    if (token == null) return false;
    try {
      final response = await _api.getMe();
      _currentUser = (response.data as Map<String, dynamic>)['user'];
      return true;
    } catch (_) {
      await logout();
      return false;
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    // Disconnect the socket so the old JWT connection is fully closed
    // before a new user logs in and creates a fresh authenticated connection.
    SocketService().disconnect();
    await _storage.delete('adtu_token');
  }

  bool get isLoggedIn => _currentUser != null;
}
