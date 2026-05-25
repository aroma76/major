# System Deep Dive: `authentication_flow_explained.md`

> This document traces the COMPLETE authentication flow end-to-end, from the moment the user opens the app to every screen transition. It covers session restoration, login, JWT storage, role-based routing, and logout with cache invalidation.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                      FRONTEND                           │
│                                                         │
│  LoginScreen                                            │
│      │ user submits credentials                         │
│      ▼                                                  │
│  AuthNotifier.login()                                   │
│      │ calls AuthService.login()                        │
│      ▼                                                  │
│  ApiService().dio.post('/auth/login', data: {...})       │
│      │ HTTP POST → backend                              │
└─────────────────────────────────────────────────────────┘
           │
           ▼ (HTTP over network)
┌─────────────────────────────────────────────────────────┐
│                      BACKEND                            │
│                                                         │
│  POST /api/auth/login                                   │
│      │ authMiddleware NOT applied (public route)        │
│      ▼                                                  │
│  authController.login()                                 │
│      │ queries DB: SELECT * FROM users WHERE ...        │
│      │ verifies bcrypt hash                             │
│      │ signs JWT with user payload                      │
│      ▼                                                  │
│  Response: { token: "eyJhbGci...", user: { id, name, role } }
└─────────────────────────────────────────────────────────┘
           │
           ▼ (HTTP response)
┌─────────────────────────────────────────────────────────┐
│                      FRONTEND                           │
│                                                         │
│  AuthService.login() receives response                  │
│      │ StorageService.saveToken(token)                  │
│      │ stores in SharedPreferences / Keychain           │
│      │ _currentUser = user payload                      │
│      ▼                                                  │
│  AuthNotifier.state = AsyncData(AuthState.authenticated)│
│      │ triggers _AuthGate rebuild                       │
│      ▼                                                  │
│  _AuthGate routes to MainDashboardScreen                │
│  SocketService().connect() called                       │
└─────────────────────────────────────────────────────────┘
```

---

## Phase 1: App Startup — Session Restoration

### What Happens When the App Opens

```dart
// main.dart
void main() {
  ApiService().init();              // 1. Dio singleton configured
  runApp(ProviderScope(child: MyApp()));
}

// MyApp.build()
home: const _AuthGate()

// _AuthGate.build()
final authAsync = ref.watch(authProvider);

// authProvider.build() runs:
Future<AuthState> build() async {
  final restored = await _auth.restoreSession();
  if (restored) {
    return AuthState(status: AuthStatus.authenticated, user: _auth.currentUser);
  }
  return const AuthState(status: AuthStatus.unauthenticated);
}
```

### `restoreSession()` in `AuthService`

```dart
Future<bool> restoreSession() async {
  final token = await StorageService().getToken();
  if (token == null) return false;

  try {
    // Decode JWT without verifying signature (frontend only)
    final parts = token.split('.');
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
    );
    final exp = payload['exp'] as int?;

    // Check if token is expired
    if (exp != null && DateTime.now().millisecondsSinceEpoch / 1000 > exp) {
      await StorageService().clearToken();
      return false;
    }

    _currentUser = payload;
    return true;
  } catch (_) {
    return false;
  }
}
```

**`token.split('.')`** — JWT has three parts: `header.payload.signature`. Split by `.` gives `['eyJhbGci...', 'eyJ1c2VySWQi...', 'signature']`.

**`base64Url.normalize(parts[1])`** — Base64 URL encoding omits padding `=` characters. `normalize` adds them back so the decoder works correctly.

**`jsonDecode(utf8.decode(base64Url.decode(...)))`** — decodes: Base64 → bytes → UTF-8 string → JSON object.

**Expiry check:** `DateTime.now().millisecondsSinceEpoch / 1000` converts milliseconds to seconds (JWT `exp` is in seconds since Unix epoch).

---

## Phase 2: The Login Screen

### What the User Sees

```
┌─────────────────────────────┐
│  ADTU Collab                │
│                             │
│  Welcome back!              │
│  Sign in to continue        │
│                             │
│  [Roll Number / Email    ]  │
│  [Password               ]  │
│                             │
│  [    Sign In →           ] │
│                             │
│  Error message (if any)     │
└─────────────────────────────┘
```

### Login Button Handler

```dart
onPressed: () async {
  ref.read(authProvider.notifier).login(
    _identifierController.text.trim(),
    _passwordController.text,
  );
}
```

**`.trim()`** — removes leading/trailing whitespace from the identifier. Prevents login failures due to accidental spaces.

**Note:** The handler is NOT `async` with `await`. Why? `login()` manages its own loading state via `isLoggingIn`. The login button watches `isLoggingIn` to show a spinner — no need for the caller to await.

### Loading State Display

```dart
final isLoading = ref.watch(authProvider.notifier).isLoggingIn;

ElevatedButton(
  onPressed: isLoading ? null : login,        // disabled while loading
  child: isLoading
      ? const SizedBox(width: 20, height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
      : const Text('Sign In →'),
),
```

`isLoggingIn = true` → button disabled + shows spinner. `isLoggingIn = false` → button enabled + shows text.

### Error Display

```dart
final authState = ref.watch(authProvider).value;
if (authState?.error != null)
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), ...),
    child: Row(children: [
      const Icon(Icons.error_outline, color: Colors.red, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(authState!.error!, style: TextStyle(color: Colors.red.shade700))),
    ]),
  ),
```

The error message from `_parseError()` in `AuthNotifier` is stored in `AuthState.error` and displayed directly.

---

## Phase 3: JWT in Every API Request

After login, `StorageService.saveToken(token)` stores the JWT. The `ApiService` singleton's `init()` method adds an interceptor:

```dart
// ApiService.init() — called once in main()
_dio.interceptors.add(
  InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await StorageService().getToken();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (error, handler) async {
      if (error.response?.statusCode == 401) {
        // Token expired or invalid → force logout
        await AuthService().logout();
        // AuthNotifier will react via ref.watch
      }
      return handler.next(error);
    },
  ),
);
```

**On every HTTP request:**
1. Read token from storage
2. Attach as `Authorization: Bearer <token>` header
3. Backend's `authMiddleware` verifies the header

**On 401 response:**
- Token is rejected by the backend (expired or tampered)
- `AuthService().logout()` clears local storage
- `authProvider` state updates → `_AuthGate` routes back to login

---

## Phase 4: Role-Based UI

After authentication, the app uses `authState.isFaculty` to show different UIs:

```dart
// main_dashboard_screen.dart
final isFaculty = ref.read(authProvider).value?.isFaculty ?? false;

// LazyIndexedStack index 0:
isFaculty ? const TeacherOverviewWidget() : const TodayOverviewWidget()

// sidebar_widget.dart
final items = isFaculty ? SidebarWidget.facultyItems : SidebarWidget.studentItems;

// top_bar_widget.dart
final sectionTitles = isFaculty ? facultyTitles : studentTitles;
```

**`isFaculty = userRole == 'faculty' || userRole == 'admin'`** — admins also see faculty-level UI.

---

## Phase 5: Logout

```dart
// sidebar_widget.dart
final confirm = await showDialog<bool>(...); // confirmation dialog
if (confirm == true) {
  await ref.read(authProvider.notifier).logout();
}

// AuthNotifier.logout():
Future<void> logout() async {
  await _auth.logout();                         // clear token, disconnect socket
  ref.invalidate(channelsProvider);             // clear all cached data
  ref.invalidate(allAssignmentsProvider);
  ref.invalidate(notificationsApiProvider);
  ref.invalidate(projectsProvider);
  ref.invalidate(teacherStatsProvider);
  ref.invalidate(dashboardRecentActivityProvider(true));
  ref.invalidate(dashboardRecentActivityProvider(false));
  state = const AsyncData(AuthState(status: AuthStatus.unauthenticated));
}
```

**`ref.invalidate` for all `keepAlive` providers** — without this, a new user logging in would see the previous user's data cached in memory.

**`state = AsyncData(AuthState.unauthenticated)`** → `_AuthGate` reacts → navigates to `LoginScreen`.

---

## Complete Flow Summary

```
App Open
  └─ restoreSession()
      ├─ Token found & valid → Dashboard + socket connect
      └─ No token / expired → LoginScreen

LoginScreen
  └─ submit → AuthNotifier.login()
      ├─ Success → token saved → Dashboard + socket connect
      └─ Error → error displayed in form, stays on LoginScreen

Dashboard (authenticated)
  └─ Every API request → JWT attached automatically
      ├─ 401 response → force logout → LoginScreen
      └─ Success → data displayed

Logout
  └─ Clear token → invalidate providers → socket disconnect → LoginScreen
```
