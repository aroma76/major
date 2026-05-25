# 📄 `main.dart` — Complete Explanation

**File Path:** `frontend/lib/main.dart`
**Lines:** 129
**Role:** Flutter application entry point — initializes services, wraps the app in Riverpod, defines both Material themes, and implements the authentication gate widget.

---

## 1. 📌 File Purpose

`main.dart` is the **root of the Flutter application**. It does exactly four things:
1. Initializes `ApiService` (Dio HTTP client) before the widget tree builds
2. Wraps the entire app in `ProviderScope` (Riverpod's dependency injection container)
3. Defines dark and light `ThemeData` objects
4. Implements `_AuthGate` — the routing logic that sends users to Login or Dashboard

---

## 2. 📤 Imports

| Import | Purpose |
|---|---|
| `flutter/material.dart` | `MaterialApp`, `ThemeData`, `Scaffold`, etc. |
| `flutter_riverpod` | `ProviderScope`, `ConsumerWidget`, `WidgetRef` |
| `google_fonts` | `GoogleFonts.outfit()` — the app's primary font |
| `app_colors.dart` | Color constants and `themeModeProvider` |
| `api_service.dart` | `ApiService().init()` — Dio initialization |
| `socket_service.dart` | `SocketService().connect()` — WebSocket connection |
| `auth_provider.dart` | `authProvider` — authentication state |
| `login_screen.dart` | Destination for unauthenticated users |
| `main_dashboard_screen.dart` | Destination for authenticated users |

---

## 3. ⚡ `main()` — Application Entry Point

```dart
void main() {
  ApiService().init();
  runApp(const ProviderScope(child: MyApp()));
}
```

**`ApiService().init()`:**
- Called BEFORE `runApp()` — initializes the Dio HTTP client (base URL, interceptors, timeouts)
- Must be called before any widget tries to make an API call
- `ApiService()` is a singleton — every call to `ApiService()` returns the same instance

**`ProviderScope(child: MyApp())`:**
- `ProviderScope` is Riverpod's root widget — it hosts all providers
- ALL Riverpod providers become accessible within `ProviderScope`'s widget subtree
- Must be the outermost widget (ancestor of everything)
- `const` — `ProviderScope` is a compile-time constant, no heap allocation at runtime

---

## 4. 🏗️ `MyApp` — Material App Shell

```dart
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

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

- `ConsumerWidget` — A Riverpod widget that has access to `WidgetRef ref`
- `ref.watch(themeModeProvider)` — Subscribes to theme changes; when the user toggles dark/light mode in Settings, `MyApp` rebuilds with the new `ThemeMode`
- `debugShowCheckedModeBanner: false` — Hides the "DEBUG" banner in the top-right corner
- `themeMode: themeMode` — Drives Flutter's built-in theme switching
- `home: const _AuthGate()` — The first widget shown; decides Login vs Dashboard

---

## 5. 🎨 `_buildDarkTheme()` — Dark Theme Data

```dart
ThemeData _buildDarkTheme() => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,          // 0xFF0D1117
    primaryColor: AppColors.accent,                          // 0xFF58A6FF
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      surface: AppColors.surface,
    ),
    useMaterial3: true,
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
      titleLarge: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textHeading),
      titleMedium: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textHeading),
      bodyLarge: GoogleFonts.outfit(fontSize: 16, color: AppColors.textHeading),
      bodyMedium: GoogleFonts.outfit(fontSize: 14, color: AppColors.textBody),
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

**Key decisions:**

**`useMaterial3: true`** — Opts into Flutter's Material Design 3 system (updated components, better typography scaling, dynamic color). Required for modern Flutter app feel.

**`GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme)`:**
- `ThemeData.dark().textTheme` — Flutter's default dark text theme (all white/grey scales)
- `GoogleFonts.outfitTextTheme(...)` — Replaces the font family of EVERY text style to "Outfit" from Google Fonts
- `.copyWith(...)` — Overrides specific styles while keeping the Outfit font for all others

**`cardTheme.elevation: 0`** — Cards don't have shadows in this flat design (border handles visual separation).

**`borderRadius: BorderRadius.circular(16)`** — Consistent 16px rounded corners on all cards throughout the app.

---

## 6. 🎨 `_buildLightTheme()` — Light Theme Data

Same structure as dark theme but with light palette:
- `scaffoldBackgroundColor: AppColors.lightBackground` (0xFFF6F8FA)
- `ColorScheme.light(...)` instead of `.dark(...)`
- `lightTextHeading`, `lightTextBody` colors
- Card border: `Color(0xFFD0D7DE)` (GitHub light border)

---

## 7. 🚪 `_AuthGate` — Route Decision Widget

```dart
class _AuthGate extends ConsumerWidget {
  const _AuthGate();

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

**`ref.watch(authProvider)`** — `authProvider` is an `AsyncNotifierProvider`. It returns an `AsyncValue<AuthState>`.

**`.when(loading, error, data)`** — Pattern matches on the async state:

| State | Returned Widget |
|---|---|
| `AsyncLoading` | Full-screen loading spinner |
| `AsyncError` | `LoginScreen()` (safe fallback — treat errors as unauthenticated) |
| `AsyncData(unauthenticated)` | `LoginScreen()` |
| `AsyncData(authenticated)` | Connect socket → `MainDashboardScreen()` |

**`SocketService().connect()`:**
- Called ONLY when the user is confirmed authenticated
- Called every time `_AuthGate` rebuilds with an authenticated state
- `SocketService` is a singleton — calling `connect()` when already connected is a no-op (the `socket.connected` guard inside `connect()` prevents double-connection)

**Why `error → LoginScreen` not `error → error screen`?**
- Auth errors (token expired, network down) should not show a broken error screen
- Redirecting to LoginScreen is the safest recovery — user can re-authenticate
- This prevents the app from being "stuck" on an error state

---

## 8. 🔄 Startup Sequence

```
main() runs
  │
  ├── ApiService().init() — Dio configured
  └── runApp(ProviderScope(child: MyApp()))
        │
        ▼
MyApp.build() runs
  │
  ├── ref.watch(themeModeProvider) → ThemeMode.dark (default)
  └── MaterialApp(themeMode: dark, home: _AuthGate())
        │
        ▼
_AuthGate.build() runs
  │
  └── ref.watch(authProvider)
        │
        ├── authProvider.build() runs → await restoreSession()
        │     → GET /api/auth/me
        │
        ├── While running: AsyncLoading → Loading spinner
        │
        ├── Token invalid/expired: AsyncData(unauthenticated) → LoginScreen
        └── Token valid: AsyncData(authenticated) → SocketService.connect() → MainDashboardScreen
```

---

## 9. ✅ Final Summary

`main.dart` is deliberately minimal — it delegates all complexity to `_AuthGate` (routing), `AppColors` (theme data), and `ApiService` (initialization). The `ProviderScope` wrapping, `AsyncValue.when()` routing, and theme-driven `MaterialApp` are all Flutter/Riverpod best practices. The file is the perfect entry point to understand the app's initialization order.
