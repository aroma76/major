import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/auth_service.dart';

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

  Future<void> login(String rollNumber, String dob) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final user = await _auth.login(rollNumber, dob);
      return AuthState(status: AuthStatus.authenticated, user: user);
    });

    if (state.hasError) {
      state = AsyncData(AuthState(
        status: AuthStatus.unauthenticated,
        error: _parseError(state.error),
      ));
    }
  }

  Future<void> logout() async {
    await _auth.logout();
    state = const AsyncData(
      AuthState(status: AuthStatus.unauthenticated),
    );
  }

  String _parseError(Object? e) {
    return e?.toString().contains('401') == true
        ? 'Invalid roll number or date of birth.'
        : 'Login failed. Please check your connection.';
  }
}

final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
