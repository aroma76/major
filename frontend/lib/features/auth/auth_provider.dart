import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../core/services/api_service.dart';

// ── Auth State ────────────────────────────────────────────────────────────────

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final Map<String, dynamic>? user;
  final String? error;

  const AuthState({required this.status, this.user, this.error});

  bool get isAuthenticated => status == AuthStatus.authenticated;
  String get userName => user?['name'] as String? ?? 'Student';
  String get userRole => user?['role'] as String? ?? 'student';
  int get userId => user?['id'] as int? ?? 0;
  bool get isFaculty =>
      userRole == 'faculty' || userRole == 'admin';
}

class AuthNotifier extends AsyncNotifier<AuthState> {
  final _auth = AuthService();

  @override
  Future<AuthState> build() async {
    // Try restoring previous session on app startup
    final restored = await _auth.restoreSession();
    if (restored) {
      return AuthState(
        status: AuthStatus.authenticated,
        user: _auth.currentUser,
      );
    }
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Login — deliberately keeps state as AsyncData so _AuthGate never
  /// navigates away from LoginScreen. Loading is signalled via [isLoggingIn].
  bool isLoggingIn = false;

  Future<void> login(String identifier, String password) async {
    isLoggingIn = true;
    // Emit current data (unauthenticated) to refresh isLoggingIn flag
    state = AsyncData(AuthState(status: AuthStatus.unauthenticated));

    try {
      final user = await _auth.login(identifier, password);
      isLoggingIn = false;
      state = AsyncData(AuthState(status: AuthStatus.authenticated, user: user));
    } catch (e) {
      isLoggingIn = false;
      state = AsyncData(AuthState(
        status: AuthStatus.unauthenticated,
        error: _parseError(e),
      ));
    }
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    final api = ApiService();
    await api.dio.post(
      '/auth/change-password',
      data: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  Future<void> updateProfile({String? name, String? dob}) async {
    if (name == null && dob == null) return;
    final api = ApiService();
    final data = <String, dynamic>{};
    if (name != null && name.isNotEmpty) data['name'] = name;
    if (dob  != null && dob.isNotEmpty)  data['dob']  = dob;
    final response = await api.dio.put('/auth/profile', data: data);
    final updatedUser = response.data['user'] as Map<String, dynamic>;
    // Merge into current state so UI reflects the change immediately
    final current = state.value;
    if (current != null) {
      final merged = Map<String, dynamic>.from(current.user ?? {})..addAll(updatedUser);
      state = AsyncData(AuthState(status: AuthStatus.authenticated, user: merged));
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    state = const AsyncData(
      AuthState(status: AuthStatus.unauthenticated),
    );
  }

  String _parseError(Object? e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] != null) {
        return data['message'] as String;
      }
      switch (e.response?.statusCode) {
        case 400: return 'Roll Number / Email and password are required.';
        case 401: return 'Incorrect roll number / email or password.';
        case 404: return 'No account found with that Roll Number or Email.';
      }
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        return 'Connection timed out. Please check your internet.';
      }
    }
    return 'Login failed. Please check your connection and try again.';
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
