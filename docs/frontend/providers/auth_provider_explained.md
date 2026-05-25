# 📄 `features/auth/auth_provider.dart` — Complete Explanation

**File Path:** `frontend/lib/features/auth/auth_provider.dart`
**Lines:** 133
**Role:** Riverpod state container for the entire authentication lifecycle. Controls what screen the user sees and all auth state transitions.

---

## 1. 📌 File Purpose

`auth_provider.dart` contains the **authentication state machine** for the Flutter app. It:
- Manages `AuthStatus` (loading → authenticated / unauthenticated)
- Runs session restoration on app startup
- Executes login and updates state accordingly
- Handles profile updates in place (without full re-fetch)
- Orchestrates logout and cache invalidation

> **Beginner Analogy:** Think of `AuthNotifier` as the bouncer at a club. When someone arrives (app start), it checks their ID (restoreSession). If their ID is valid (token verifies), they enter (authenticated). If they don't have one, they wait at the door (unauthenticated → show login). When someone logs in successfully (login), the bouncer lets them in. When they leave (logout), the bouncer clears their spot and tells all other departments to forget this person.

---

## 2. 📊 `AuthStatus` Enum

```dart
enum AuthStatus { loading, authenticated, unauthenticated }
```

Three states:
| State | When | UI Result |
|---|---|---|
| `loading` | App startup, before `restoreSession()` completes | Splash/loading screen |
| `authenticated` | Token verified, user data available | `MainDashboardScreen` |
| `unauthenticated` | No token or verification failed | `LoginScreen` |

---

## 3. 🏗️ `AuthState` Data Class

```dart
class AuthState {
  final AuthStatus status;
  final Map<String, dynamic>? user;
  final String? error;

  const AuthState({required this.status, this.user, this.error});

  bool get isAuthenticated => status == AuthStatus.authenticated;
  String get userName => user?['name'] as String? ?? 'Student';
  String get userRole => user?['role'] as String? ?? 'student';
  int get userId => user?['id'] as int? ?? 0;
  bool get isFaculty => userRole == 'faculty' || userRole == 'admin';
}
```

**Computed getters:**
- `isAuthenticated` — Shorthand for `status == AuthStatus.authenticated`.
- `userName` / `userRole` / `userId` — Extract from `user` map with null-safe fallbacks.
- `isFaculty` — Both `'faculty'` and `'admin'` get faculty-level access. Used to show teacher-specific UI (create assignments, view all submissions, etc.).

---

## 4. 🔄 `AuthNotifier.build()` — App Startup

```dart
class AuthNotifier extends AsyncNotifier<AuthState> {
  final _auth = AuthService();

  @override
  Future<AuthState> build() async {
    final restored = await _auth.restoreSession();
    if (restored) {
      return AuthState(
        status: AuthStatus.authenticated,
        user: _auth.currentUser,
      );
    }
    return const AuthState(status: AuthStatus.unauthenticated);
  }
```

- `AsyncNotifier.build()` runs **once** when the provider is first accessed.
- `await _auth.restoreSession()` — Reads the stored JWT and calls `/auth/me` to verify.
- If restored → returns `authenticated` state with user data.
- If not → returns `unauthenticated` state.
- The `main.dart` `_AuthGate` widget watches this provider and shows the appropriate screen based on this return value.

**What shows during `build()`?**
`AsyncNotifier.build()` returns a Future, so the provider is in `AsyncLoading` state while `restoreSession()` runs. `_AuthGate` shows a loading screen during this time.

---

## 5. 🔓 `login()` — Careful State Management Design

```dart
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
```

### The `isLoggingIn` Pattern — Why Not Use `AsyncLoading`?

The comment explains: **"deliberately keeps state as AsyncData so _AuthGate never navigates away from LoginScreen."**

If `state = AsyncLoading()` were used during login:
1. Provider goes to loading state
2. `_AuthGate` sees loading → shows a blank/loading screen
3. Login form disappears
4. User can't cancel
5. UX feels janky

Instead:
- `isLoggingIn = true` sets a flag on the notifier itself.
- `state = AsyncData(unauthenticated)` — **force-triggers a rebuild** of widgets watching `authProvider` so `isLoggingIn` is re-read.
- The `LoginScreen` reads `ref.watch(authProvider.notifier).isLoggingIn` and shows a spinner inside the button.
- The login screen stays visible throughout — no navigation.

This is a **sophisticated UX decision** baked into the state management design.

### Error State
```dart
state = AsyncData(AuthState(
  status: AuthStatus.unauthenticated,
  error: _parseError(e),
));
```
- Even on error, state remains `AsyncData` (not `AsyncError`).
- The `error` field on `AuthState` carries the error message.
- Login screen reads `authState.value?.error` and shows the error banner.

---

## 6. 🔐 `changePassword()`

```dart
Future<void> changePassword(String currentPassword, String newPassword) async {
  final api = ApiService();
  await api.dio.post(
    '/auth/change-password',
    data: {'currentPassword': currentPassword, 'newPassword': newPassword},
  );
}
```

- Directly uses `ApiService().dio` — one of the places that bypasses the named method pattern.
- Doesn't update state on success — password change doesn't affect the user object.
- Throws `DioException` on failure — UI catches and shows error.

---

## 7. ✏️ `updateProfile()` — In-Place Merge

```dart
Future<void> updateProfile({String? name, String? dob}) async {
  if (name == null && dob == null) return;
  final api = ApiService();
  final data = <String, dynamic>{};
  if (name != null && name.isNotEmpty) data['name'] = name;
  if (dob != null && dob.isNotEmpty) data['dob'] = dob;
  final response = await api.dio.put('/auth/profile', data: data);
  final updatedUser = response.data['user'] as Map<String, dynamic>;
  
  // Merge into current state so UI reflects the change immediately
  final current = state.value;
  if (current != null) {
    final merged = Map<String, dynamic>.from(current.user ?? {})
      ..addAll(updatedUser);
    state = AsyncData(AuthState(status: AuthStatus.authenticated, user: merged));
  }
}
```

### The Merge Pattern
```dart
final merged = Map<String, dynamic>.from(current.user ?? {})
  ..addAll(updatedUser);
```
- `Map.from(...)` — Creates a mutable copy of the current user map.
- `..addAll(updatedUser)` — Cascade: overwrites only the fields that were updated.
- Example: if only `name` was updated, the merged map has the new name but keeps the original `email`, `role`, `id`, etc.
- Result: The UI immediately shows the new name without requiring logout/login.

---

## 8. 🚪 `logout()` — Cache Invalidation

```dart
Future<void> logout() async {
  await _auth.logout();
  // Invalidate all keepAlive user-specific providers
  ref.invalidate(channelsProvider);
  ref.invalidate(allAssignmentsProvider);
  ref.invalidate(notificationsApiProvider);
  ref.invalidate(projectsProvider);
  ref.invalidate(teacherStatsProvider);
  ref.invalidate(dashboardRecentActivityProvider(true));
  ref.invalidate(dashboardRecentActivityProvider(false));
  state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
}
```

**Why invalidate all those providers?**
`ref.keepAlive()` on providers means they persist their data even after widgets are disposed. If User A logs in, loads channels, logs out, and User B logs in — without invalidation, User B would see User A's channels! The `ref.invalidate()` calls force each provider to re-fetch from the API on the next access.

---

## 9. 🔍 `_parseError()` — User-Friendly Error Messages

```dart
String _parseError(Object? e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'] as String;  // Use backend's specific message
    }
    switch (e.response?.statusCode) {
      case 400: return 'Roll Number / Email and password are required.';
      case 401: return 'Incorrect roll number / email or password.';
      case 404: return 'No account found with that Roll Number or Email.';
    }
    if (e.type == DioExceptionType.connectionTimeout || ...)
      return 'Connection timed out. Please check your internet.';
  }
  return 'Login failed. Please check your connection and try again.';
}
```

Three levels of error mapping:
1. **Backend message** — If the backend returned a specific `{ message: "..." }` in the error response, use it verbatim.
2. **HTTP status code** — Map common status codes to user-friendly messages.
3. **Network errors** — Detect timeout errors specifically.
4. **Fallback** — Generic message for anything unexpected.

---

## 10. 📤 Provider Declaration

```dart
final authProvider = AsyncNotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
```

- `AsyncNotifierProvider` — Wraps an `AsyncNotifier` (which has an async `build()` method).
- `AuthNotifier.new` — Equivalent to `() => AuthNotifier()`. Dart's constructor tear-off syntax.
- This single line is what makes `ref.watch(authProvider)` and `ref.read(authProvider.notifier)` work across the entire app.

---

## 11. ✅ Final Summary

`auth_provider.dart` implements a production-quality authentication state machine. The key design decisions are:
1. **`isLoggingIn` flag** instead of `AsyncLoading` — preserves the login form during auth.
2. **Error as `AuthState.error`** instead of `AsyncError` — keeps the login screen visible with an inline error banner.
3. **Profile merge** instead of full re-fetch — instant UI update.
4. **`ref.invalidate()`** on logout — prevents data leakage between different user accounts.
