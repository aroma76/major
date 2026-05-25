# Word-by-Word Deep Dive: `frontend/lib/core/services/storage_service.dart`

> This file handles **persistent secure storage** for the Flutter app — primarily storing and reading the JWT token between app sessions. The key challenge it solves is that Flutter runs on both mobile (iOS/Android) and web, and these platforms have different secure storage mechanisms. This service abstracts both behind one clean API.

---

## Before Reading — Why Two Storage Systems?

**Flutter Secure Storage (mobile):**
- On Android: uses the **Android Keystore** — a hardware-backed secure storage for cryptographic keys and secrets. Even if the device is rooted, keys stored here cannot be extracted.
- On iOS: uses the **Keychain** — Apple's secure encrypted storage for passwords and tokens.
- NOT available on web (no native binary, no OS keystore).

**SharedPreferences (web):**
- On web, Flutter uses `SharedPreferences` which maps to browser **localStorage** (a key-value store in the browser).
- Not as secure as Keystore/Keychain — localStorage can be read by JavaScript. But it's the best available option on web without additional infrastructure.
- NOT the same as "shared preferences" in Android development.

---

## Lines 8–11 — Singleton Pattern

```dart
class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;
  StorageService._internal();
```

Same pattern as `ApiService` and `SocketService`. One instance shared everywhere. Each `StorageService()` call returns the same object.

---

## Line 13 — `final _secure = const FlutterSecureStorage();`

**`FlutterSecureStorage`** — from the `flutter_secure_storage` package

**`const FlutterSecureStorage()`** — creates the secure storage instance with default options
- `const` — compile-time constant. Since the constructor takes no required parameters and always produces the same result, `const` makes it more efficient (the same instance is reused).

**`final _secure`** — private constant field. Initialized once, never reassigned.

---

## Lines 15–21 — SharedPreferences Caching

```dart
SharedPreferences? _prefs;

Future<SharedPreferences> _getPrefs() async {
  _prefs ??= await SharedPreferences.getInstance();
  return _prefs!;
}
```

### `SharedPreferences? _prefs;`

**`SharedPreferences?`** — nullable. Starts as `null` — the prefs instance hasn't been obtained yet.

### `_prefs ??= await SharedPreferences.getInstance();`

**`??=`** — the **null-aware assignment operator** in Dart:
- If `_prefs` is `null`: evaluate the right side and assign it
- If `_prefs` is NOT null: do nothing (skip the right side)

This is equivalent to:
```dart
if (_prefs == null) {
  _prefs = await SharedPreferences.getInstance();
}
```

**`SharedPreferences.getInstance()`** — an async static method that returns the SharedPreferences singleton. First call takes a few milliseconds (reads from disk). Subsequent calls return quickly.

**Why cache?** — `SharedPreferences.getInstance()` is async. Without caching, every `read()`, `write()`, or `delete()` call would need to `await SharedPreferences.getInstance()` first. With `_prefs` caching, only the FIRST call awaits it. All subsequent calls use the cached `_prefs` synchronously.

**`return _prefs!`** — `!` null assertion: after the `??=` assignment, `_prefs` is guaranteed non-null.

---

## Lines 23–30 — `write(key, value)`

```dart
Future<void> write(String key, String value) async {
  if (kIsWeb) {
    final prefs = await _getPrefs();
    await prefs.setString(key, value);
  } else {
    await _secure.write(key: key, value: value);
  }
}
```

### `kIsWeb`

**`kIsWeb`** — a constant from `package:flutter/foundation.dart`
- `true` when running in a web browser (Flutter Web)
- `false` on Android, iOS, desktop
- Evaluated at COMPILE TIME (not runtime) — the dead branch is removed from the compiled output

### Web Path: `prefs.setString(key, value)`

**`setString(key, value)`** — writes a string to localStorage under the given key
- Key-value: `'adtu_token'` → `'eyJhbGciOiJIUzI1NiJ9...'`

### Mobile Path: `_secure.write(key: key, value: value)`

**`_secure.write(key: key, value: value)`** — writes to the OS keystore
- Android: encrypted with AES-256, stored in the Keystore
- iOS: stored in the Keychain with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` attribute
- Both: automatically deleted if the app is uninstalled (unlike localStorage which persists)

**Named parameters** `key: key, value: value` — FlutterSecureStorage uses named params for clarity.

---

## Lines 32–39 — `read(key)`

```dart
Future<String?> read(String key) async {
  if (kIsWeb) {
    final prefs = await _getPrefs();
    return prefs.getString(key);
  } else {
    return _secure.read(key: key);
  }
}
```

### `Future<String?>`

Returns a nullable string:
- If the key doesn't exist (never stored): returns `null`
- If the key exists: returns the stored string

**On first launch (before login):** `read('adtu_token')` returns `null` → no token → no `Authorization` header → server returns 401.

**On subsequent launches:** `read('adtu_token')` returns the JWT → attached to requests → user is authenticated without re-logging in.

### `prefs.getString(key)` — returns `String?`

SharedPreferences returns `null` if the key doesn't exist, matching the expected return type.

### `_secure.read(key: key)` — returns `Future<String?>`

FlutterSecureStorage also returns `null` if the key isn't found.

---

## Lines 41–48 — `delete(key)`

```dart
Future<void> delete(String key) async {
  if (kIsWeb) {
    final prefs = await _getPrefs();
    await prefs.remove(key);
  } else {
    await _secure.delete(key: key);
  }
}
```

Called on logout:
```dart
await StorageService().delete('adtu_token');
```

**Web:** `prefs.remove(key)` — removes from localStorage

**Mobile:** `_secure.delete(key: key)` — removes from Keystore/Keychain

After this, `read('adtu_token')` returns `null` → no auth header → user effectively logged out.

---

## Where Storage is Used

| Location | Operation | Key |
|---|---|---|
| Login success | `write('adtu_token', token)` | JWT saved |
| ApiService interceptor | `read('adtu_token')` | JWT attached to every request |
| SocketService.connect() | `read('adtu_token')` | JWT sent in socket handshake |
| Logout | `delete('adtu_token')` | JWT cleared |
| App startup | `read('adtu_token')` | Check if already logged in |

---

## Security Comparison Table

| Platform | Storage Mechanism | Security Level | Notes |
|---|---|---|---|
| Android | Android Keystore | Hardware-backed, very high | AES-256 encrypted |
| iOS | Keychain | Hardware-backed, very high | Cleared on app uninstall |
| Web | localStorage via SharedPreferences | Low-medium | Accessible to JavaScript |

**The web limitation** — localStorage can be read by any JavaScript on the page. For the web version of this app, the JWT is in a fairly accessible place. Mitigations:
1. HTTPS only (token can't be intercepted in transit)
2. Short JWT expiry (7 days by default)
3. No `eval()` or inline scripts (CSP header in `server.js` prevents XSS attacks that would steal the token)
