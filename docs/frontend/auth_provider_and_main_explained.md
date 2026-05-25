# Word-by-Word Deep Dive: `auth_provider.dart` + `main.dart`

> This document covers two critical files: `auth_provider.dart` (the authentication state machine) and `main.dart` (the app entry point). Together they control: how the app starts, how the user's session is restored, how login/logout work, and how the entire widget tree is configured.

---

# PART 1: `auth_provider.dart`

---

## Before Reading — `AsyncNotifier` vs `Notifier`

**`Notifier<T>`** — synchronous state. `build()` returns `T` directly.

**`AsyncNotifier<T>`** — asynchronous state. `build()` returns `Future<T>`. The provider wraps the result in `AsyncValue<T>` (loading/data/error).

`authProvider` uses `AsyncNotifier` because on startup it must await `restoreSession()` (reads from secure storage) before knowing if the user is logged in.

---

## Lines 9–23 — State Classes

### `AuthStatus` enum

```dart
enum AuthStatus { loading, authenticated, unauthenticated }
```

**`enum`** — a type-safe set of named constants. Can only be one of three values. Prevents invalid states like `'loggedIn'` (typo) or `2` (magic number).

### `AuthState`

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

**`Map<String, dynamic>? user`** — the user data from the JWT payload (name, role, id, etc.). `null` when not authenticated.

**Computed getters:**

**`bool get isAuthenticated`** — no parentheses when read. Returns `true` only when status is `authenticated`. Used in `_AuthGate`: `if (authState.isAuthenticated)`.

**`String get userName => user?['name'] as String? ?? 'Student'`**
- `user?` — optional chaining: if `user` is null, returns null
- `['name']` — access the 'name' key
- `as String?` — cast to nullable string (key might exist but have null value)
- `?? 'Student'` — fallback for null (not logged in or name not set)

**`bool get isFaculty => userRole == 'faculty' || userRole == 'admin'`** — admins also get faculty-level UI access (can manage subjects, see all submissions).

---

## Lines 25–39 — `AuthNotifier.build()` — Session Restoration

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

**`AsyncNotifier<AuthState>`** — the provider holds `AsyncValue<AuthState>`.

**`Future<AuthState> build()`** — `build()` is async here! On first access, the provider is in `AsyncLoading` state while this executes. Once it resolves, transitions to `AsyncData<AuthState>`.

**`_auth.restoreSession()`** — reads `'adtu_token'` from `StorageService`, decodes the JWT, and stores the payload in `AuthService.currentUser`. Returns `true` if a valid token exists.

**Why restore session in `build()`?** — `build()` runs once when the provider is first watched. `_AuthGate` watches `authProvider` immediately on app startup → session restoration happens automatically → the app navigates to Dashboard or Login accordingly.

---

## Lines 41–62 — `login()` — Why No `AsyncLoading` State

```dart
bool isLoggingIn = false;

Future<void> login(String identifier, String password) async {
  isLoggingIn = true;
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

### Why `isLoggingIn` instead of `AsyncLoading`?

**The problem with `state = AsyncLoading()`:**
- `_AuthGate` watches `authProvider`
- When `state = AsyncLoading()`, `_AuthGate`'s `authAsync.when(loading: ...)` shows a full-screen loader
- This unmounts `LoginScreen` from the tree → the login form disappears!

**The solution:**
- Keep `state` as `AsyncData` throughout login
- Use a separate `bool isLoggingIn` flag
- `LoginScreen` reads `ref.read(authProvider.notifier).isLoggingIn` to show a button spinner WITHOUT unmounting itself

**`state = AsyncData(AuthState(status: AuthStatus.unauthenticated))`** — explicitly emits the current data (unauthenticated) to trigger `_AuthGate` to rebuild and read the updated `isLoggingIn` flag.

### Error Handling

```dart
state = AsyncData(AuthState(
  status: AuthStatus.unauthenticated,
  error: _parseError(e),
));
```

Even on login failure, state stays `AsyncData` (not `AsyncError`). The error message is stored in `AuthState.error` and displayed by the `LoginScreen`.

---

## Lines 64–89 — `changePassword()` and `updateProfile()`

### `updateProfile()` — Optimistic Merge

```dart
Future<void> updateProfile({String? name, String? dob}) async {
  if (name == null && dob == null) return;
  final data = <String, dynamic>{};
  if (name != null && name.isNotEmpty) data['name'] = name;
  if (dob != null && dob.isNotEmpty) data['dob'] = dob;
  final response = await api.dio.put('/auth/profile', data: data);
  final updatedUser = response.data['user'] as Map<String, dynamic>;
  final current = state.value;
  if (current != null) {
    final merged = Map<String, dynamic>.from(current.user ?? {})
      ..addAll(updatedUser);
    state = AsyncData(AuthState(status: AuthStatus.authenticated, user: merged));
  }
}
```

**`if (name == null && dob == null) return`** — guard: if nothing to update, return early. No unnecessary API call.

**`<String, dynamic>{}`** — an empty typed map. Only include fields that were provided and are non-empty.

**`Map<String, dynamic>.from(current.user ?? {})`** — creates a MUTABLE copy of the current user map. `current.user` might be null if somehow called while unauthenticated.

**`..addAll(updatedUser)`** — cascade operator: calls `addAll()` on the new map (merges updated fields from backend). The `..` returns the map itself, so `merged` contains the merged result.

**Why merge instead of replace?** The PUT endpoint only returns the changed fields. Merging preserves other fields (like `id`, `role`) that the PUT response might not include.

---

## Lines 91–105 — `logout()` — Provider Cache Invalidation

```dart
Future<void> logout() async {
  await _auth.logout();
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

**`_auth.logout()`** — clears the JWT from `StorageService`, calls `SocketService().disconnect()`, sets `_currentUser = null`.

**`ref.invalidate(provider)`** — forces the provider to discard its cached state. On next `ref.watch()`, it re-fetches.

**Why invalidate all these providers on logout?**

All these providers have `ref.keepAlive()` which prevents automatic disposal. Without explicit invalidation:
- User A logs out
- User B logs in on the same device
- User B sees User A's cached channels/assignments/notifications!

`ref.invalidate` ensures every data provider is fresh for the new session.

---

## Lines 107–127 — `_parseError()` — Human-Readable Errors

```dart
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
```

**`e is DioException`** — Dart `is` operator: runtime type check. Only Dio errors have `.response?.statusCode`.

**Priority of error messages:**
1. Backend message from JSON (`data['message']`) — most specific
2. HTTP status code mapping — fallback
3. Timeout check — no network
4. Generic fallback — unknown error

**`e.type == DioExceptionType.connectionTimeout`** — `DioExceptionType` is an enum with values like `connectionTimeout`, `receiveTimeout`, `connectionError`, etc.

---

# PART 2: `main.dart`

---

## Line 11–15 — `main()` Function

```dart
void main() {
  ApiService().init();
  runApp(const ProviderScope(child: MyApp()));
}
```

**`void main()`** — the entry point of every Dart program. Flutter calls this function when the app starts.

**`ApiService().init()`** — initializes the Dio singleton BEFORE the widget tree is built. This sets up the base URL and any interceptors.

**`ProviderScope`** — the ROOT of the Riverpod provider tree. ALL providers in the app must be descendants of `ProviderScope`. Without it, `ref.watch()` would throw an error.

**`const MyApp()`** — `const` constructor: the widget doesn't change, so it's a compile-time constant. More efficient.

**`runApp(widget)`** — Flutter's entry point. Inflates the given widget and attaches it to the screen.

---

## Lines 17–31 — `MyApp` — MaterialApp Configuration

```dart
class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp(
      title: 'ADTU Collab',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      darkTheme: _buildDarkTheme(),
      theme: _buildLightTheme(),
      home: const _AuthGate(),
    );
  }
```

**`ConsumerWidget`** — a Riverpod-aware `StatelessWidget`. Has access to `ref`.

**`ref.watch(themeModeProvider)`** — when the user toggles dark/light mode, `themeMode` changes → `MyApp.build()` rebuilds → `MaterialApp` rebuilds with the new `themeMode` → entire app re-renders in the new theme.

**`title: 'ADTU Collab'`** — the app name shown in the OS task switcher.

**`debugShowCheckedModeBanner: false`** — removes the red "DEBUG" banner in the top-right corner. Common for development builds shared with stakeholders.

**`home: const _AuthGate()`** — the first screen. `_AuthGate` decides whether to show LoginScreen or DashboardScreen.

---

## Lines 33–99 — Theme Building

```dart
ThemeData _buildDarkTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.background,
  primaryColor: AppColors.accent,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.accent,
    surface: AppColors.surface,
  ),
  useMaterial3: true,
  textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
    titleLarge: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHeading),
    ...
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFF30363D), width: 1),
    ),
    elevation: 0,
  ),
);
```

**`ThemeData`** — Flutter's global theme configuration. Defines default styles for all Material widgets.

**`brightness: Brightness.dark`** — tells Flutter this is the dark theme. Used by `Theme.of(context).brightness` in `AppColors.get*()` methods.

**`scaffoldBackgroundColor`** — the background color of all `Scaffold` widgets (the page background).

**`primaryColor`** — the main brand color. Used by various Material widgets as default.

**`ColorScheme`** — Material 3's color system. More granular than `primaryColor`. The `primary` color affects buttons, selections, active states.

**`useMaterial3: true`** — opts into Material Design 3 (Material You). Changes button shapes, typography, spacing.

**`GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme)`** — replaces the default system font with "Outfit" from Google Fonts for ALL text in the app. The parameter `ThemeData.dark().textTheme` provides the base text styles to apply the font to.

**`.copyWith(titleLarge: GoogleFonts.outfit(...))`** — overrides specific text styles while inheriting the rest from the Outfit theme.

**`cardTheme`** — default style for all `Card` widgets:
- `elevation: 0` — no shadow (flat design with border instead)
- `borderRadius: 16` — rounded corners
- `BorderSide` — subtle 1px border instead of shadow

---

## Lines 102–128 — `_AuthGate` — The Navigation Router

```dart
class _AuthGate extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authProvider);

    return authAsync.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      ),
      error: (_, __) => const LoginScreen(),
      data: (authState) {
        if (authState.isAuthenticated) {
          SocketService().connect();
          return const MainDashboardScreen();
        }
        return const LoginScreen();
      },
    );
  }
}
```

**`ref.watch(authProvider)`** — `AsyncValue<AuthState>`. Rebuilds `_AuthGate` whenever auth state changes.

**`.when(loading, error, data)`** — exhaustive handler for all three async states:
- `loading` — session restoration in progress: show spinner
- `error` — session restoration threw an exception: show login (safe fallback)
- `data` — session check complete: route to the right screen

**`SocketService().connect()`** — called ONLY when authenticated (not on the login screen). Connects the WebSocket with the current JWT. Safe to call here because `_AuthGate` only calls this when `isAuthenticated` is true.

**Why is `_AuthGate` in `main.dart` (private)?** — The `_` prefix makes it library-private. It's ONLY used as `home: const _AuthGate()` in `MyApp`. No other file should navigate to it directly.

---

## Complete App Startup Sequence

```
1. main() called
     │
     ▼
2. ApiService().init() — Dio singleton configured
     │
     ▼
3. runApp(ProviderScope(child: MyApp()))
     │
     ▼
4. MyApp builds → MaterialApp with theme + _AuthGate
     │
     ▼
5. _AuthGate watches authProvider
     │
     ▼
6. authProvider.build() called:
   await _auth.restoreSession()
   → reads 'adtu_token' from StorageService
     │
     ├─ Token found & valid → AuthStatus.authenticated
     │       ↓
     │   _AuthGate routes to MainDashboardScreen
     │   SocketService().connect() called
     │
     └─ No token → AuthStatus.unauthenticated
             ↓
         _AuthGate routes to LoginScreen
```
