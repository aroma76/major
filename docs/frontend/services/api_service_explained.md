# Word-by-Word Deep Dive: `frontend/lib/core/services/api_service.dart`

> This is the **network gateway** of the entire Flutter frontend. Every single HTTP request to the Node.js backend flows through this class. Understanding this file means understanding how the Flutter app talks to the server, how authentication tokens are attached to every request, and how every backend endpoint maps to a Dart method.

---

## Before Reading — Key Concepts

### What is Dio?
**`Dio`** is a Dart HTTP client library (similar to `axios` in JavaScript or `requests` in Python). It's chosen over Dart's built-in `http` package because it supports:
- Interceptors (middleware that runs before/after every request)
- FormData for file uploads
- Automatic timeout handling
- Better error types (`DioException` instead of generic errors)

### What is a Singleton?
A **singleton** is a design pattern where a class has exactly ONE instance, shared everywhere. Instead of creating a new `ApiService()` each time you need it, the same object is returned every time.

**Why?** Dio maintains a **connection pool** (a set of pre-established TCP connections to the server). Creating a new Dio instance per API call would:
1. Create a new connection each time → slower (TCP handshake takes ~100ms)
2. Abandon existing connections → resource leak

With singleton: one Dio instance reuses connections across all requests.

---

## Lines 5–11 — The Singleton Pattern

```dart
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final _storage = StorageService();
  late final Dio dio;
```

### `static final ApiService _instance = ApiService._internal();`

**`static`** — Dart keyword meaning this belongs to the CLASS, not to any particular object. `_instance` is created once when the class is first loaded.

**`final`** — once assigned, `_instance` can never be reassigned to a different object.

**`ApiService _instance`** — the type and name. This holds the single shared instance.

**`= ApiService._internal()`** — immediately creates the instance by calling the private constructor.

**`_instance`** — the underscore prefix means "private to this library" in Dart. Cannot be accessed outside `api_service.dart`.

### `factory ApiService() => _instance;`

**`factory`** — a Dart constructor modifier. A factory constructor can return an existing instance instead of always creating a new one.

**`ApiService()`** — this looks like creating a new object, but with `factory`, it returns `_instance` — the SAME object every time.

**`=> _instance`** — single-expression syntax. Equivalent to:
```dart
factory ApiService() {
  return _instance;
}
```

**Usage throughout the codebase:**
```dart
final api = ApiService(); // returns the singleton
final api2 = ApiService(); // returns the SAME singleton
```
`api == api2` is `true`. They're the same object.

### `ApiService._internal();`

**`._internal()`** — a **named constructor** with a private name (underscore prefix). This is the ONLY way to create an ApiService instance. Because it's private, external code cannot call it.

This enforces that no one outside this file can create a second ApiService instance.

### `final _storage = StorageService();`

Creates a StorageService instance (also a singleton — same pattern). Used to read the JWT token.

### `late final Dio dio;`

**`late`** — Dart keyword. Declares a non-nullable field that will be initialized LATER (not at declaration time). Before `init()` is called, accessing `dio` would throw an error.

**`final`** — once `init()` sets `dio`, it can't be reassigned.

**`Dio dio`** — public (no underscore) — intentionally exposed via getter for advanced use cases.

---

## Lines 13–36 — `init()` — Setting Up the Dio Client

```dart
void init() {
  dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiUrl,
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _storage.read('adtu_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (DioException e, handler) {
      return handler.next(e);
    },
  ));
}
```

### `void init()`

Not called in the constructor — called from `main.dart` or app initialization before any API calls happen. Separating `init()` from the constructor allows the singleton to exist before the Dio client is ready (useful for dependency injection patterns).

### `Dio(BaseOptions(...))`

**`Dio(BaseOptions(...))`** — creates a new Dio instance with configuration

**`baseUrl: AppConfig.apiUrl`**
- `AppConfig.apiUrl` — a static constant in `app_config.dart`
- In development: `'http://localhost:5000/api'`
- In production: `'https://your-app.onrender.com/api'`
- All request paths are **relative** to this base URL
- `dio.get('/channels')` → actual URL: `http://localhost:5000/api/channels`

**`connectTimeout: const Duration(seconds: 30)`**
- `connectTimeout` — how long Dio waits to ESTABLISH the connection (TCP handshake)
- `const Duration(seconds: 30)` — 30 seconds
- **Why 30s?** The backend is hosted on Render's free tier. Render spins down servers after inactivity and takes ~20-30 seconds to "cold start." The 30-second timeout covers this cold start time.
- `const` — compile-time constant (more efficient than runtime construction)

**`receiveTimeout: const Duration(seconds: 30)`**
- How long Dio waits to receive the FULL response after connection is established
- Separate from `connectTimeout`

**`headers: {'Content-Type': 'application/json'}`**
- Default headers applied to EVERY request
- Tells the server: "I'm sending JSON data"
- The backend's `express.json()` middleware reads this header to parse the body

---

### The Interceptor — Auto Token Injection

```dart
dio.interceptors.add(InterceptorsWrapper(
  onRequest: (options, handler) async {
    final token = await _storage.read('adtu_token');
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    return handler.next(options);
  },
  onError: (DioException e, handler) {
    return handler.next(e);
  },
));
```

**`dio.interceptors`** — a list of interceptor objects. Applied in order to every request/response.

**`InterceptorsWrapper`** — Dio's built-in class for wrapping multiple callbacks (onRequest, onResponse, onError) in one interceptor object.

**`onRequest: (options, handler) async {...}`** — called BEFORE every request is sent

- **`options`** — a `RequestOptions` object containing everything about the outgoing request: URL, method, headers, body, timeout
- **`handler`** — controls the interceptor chain
  - `handler.next(options)` — pass request to the next interceptor (or send it)
  - `handler.reject(error)` — cancel the request with an error
  - `handler.resolve(response)` — short-circuit with a fake response

**`await _storage.read('adtu_token')`**
- `_storage` — the `StorageService` instance
- `'adtu_token'` — the key under which the JWT is stored (on mobile: Flutter Secure Storage = Keychain/Keystore; on web: SharedPreferences/localStorage)
- `await` — StorageService.read is async (reading from storage takes a moment)

**`options.headers['Authorization'] = 'Bearer $token'`**
- `options.headers` — a mutable Map
- `'Authorization'` — the header name the backend's `protect` middleware reads
- `'Bearer $token'` — Dart string interpolation. `$token` inserts the token string.
- The format `Bearer <token>` is the standard HTTP Bearer authentication scheme.
- The backend code: `const authHeader = req.headers['authorization']?.split(' ');` then `authHeader[1]` = the token

**`return handler.next(options);`** — MUST be called to continue the request chain. Without this, the request would hang forever.

**`onError: (DioException e, handler) { return handler.next(e); }`** — passes errors through unchanged. A comment says: "You can add global 401 logout handling here." — a planned improvement to automatically log out when the JWT expires.

---

## Lines 38–145 — All API Methods

Each method follows the same concise pattern:

```dart
Future<Response> methodName(params) => dio.METHOD('/path', data: {...});
```

**`Future<Response>`** — returns a Dart Future (like a JavaScript Promise). The caller must `await` it or chain `.then(...)`.

**`Response`** — Dio's response object. Key properties:
- `response.data` — the parsed JSON body (Dart `Map<String, dynamic>`)
- `response.statusCode` — HTTP status code (200, 201, 400, etc.)

### Line 39–40 — `login`

```dart
Future<Response> login(String rollNumber, String dob) =>
    dio.post('/auth/login', data: {'identifier': rollNumber, 'password': dob});
```

**`String rollNumber, String dob`** — two named parameters
- `rollNumber` — the student's roll number (e.g., `'CS2021001'`)
- `dob` — date of birth used as default password (e.g., `'2003-05-15'`)

**`dio.post('/auth/login', data: {...})`** — HTTP POST to `/api/auth/login`
- `data: {...}` — the request body. The `Content-Type: application/json` header (from `BaseOptions`) makes this JSON-encoded automatically.

### Lines 53–57 — `getMessages` with Collection If

```dart
Future<Response> getMessages(int channelId, {int? cursor, int limit = 50}) =>
    dio.get('/channels/$channelId/messages', queryParameters: {
      if (cursor != null) 'cursor': cursor,
      'limit': limit,
    });
```

**`{int? cursor, int limit = 50}`** — named parameters in curly braces
- `int? cursor` — optional nullable integer (the cursor can be null)
- `int limit = 50` — optional with default value 50

**`queryParameters: {...}`** — these become URL query parameters
- `if (cursor != null) 'cursor': cursor` — **collection if** in Dart: a conditional entry in a map literal. If cursor is null, this entry is NOT added. Result: `?limit=50` or `?cursor=150&limit=50`

### Lines 59–61 — `sendMessage` with FormData

```dart
Future<Response> sendMessage(int channelId, FormData formData) =>
    dio.post('/channels/$channelId/messages',
        data: formData, options: Options(contentType: 'multipart/form-data'));
```

**`FormData formData`** — for file uploads. `FormData` encodes both text fields and binary file data in `multipart/form-data` format.

**`options: Options(contentType: 'multipart/form-data')`** — overrides the default `application/json` Content-Type for this specific request. Multer on the backend recognizes this format.

### Line 118–119 — `updateProjectProgress`

```dart
Future<Response> updateProjectProgress(int id, int progress) =>
    dio.patch('/projects/$id/progress', data: {'progress': progress});
```

**`dio.patch`** — HTTP PATCH (partial update). Changes only the `progress` field of the project.

---

## How the App Uses ApiService

```dart
// In a provider or repository:
final api = ApiService(); // gets the singleton
final response = await api.getChannels();
final channels = response.data['channels'] as List;
```

**`response.data`** — automatically parsed JSON. The Dio client reads the `Content-Type: application/json` response header and calls `json.decode()` automatically.

**`as List`** — Dart type cast. `response.data['channels']` is `dynamic` — casting to `List` gives access to list methods.

---

## Complete Method Reference Table

| Method | HTTP | Backend URL | Notes |
|---|---|---|---|
| `login(rollNumber, dob)` | POST | `/auth/login` | Returns JWT token |
| `signup(data)` | POST | `/auth/register` | Registration |
| `getMe()` | GET | `/auth/me` | Current user profile |
| `getChannels()` | GET | `/channels` | Role-filtered |
| `getChannelById(id)` | GET | `/channels/:id` | Single channel |
| `getMessages(channelId, cursor?, limit)` | GET | `/channels/:id/messages` | Paginated with cursor |
| `sendMessage(channelId, formData)` | POST | `/channels/:id/messages` | Multipart (text+file) |
| `deleteMessage(channelId, msgId)` | DELETE | `/channels/:id/messages/:msgId` | — |
| `getAssignments(channelId)` | GET | `/channels/:id/assignments` | Role-aware response |
| `submitAssignment(channelId, assignId, formData)` | POST | `.../submit` | Multipart file upload |
| `updateAssignmentStatus(channelId, assignId, status)` | PATCH | `.../status` | Kanban drag-drop |
| `getAnnouncements(channelId)` | GET | `/channels/:id/announcements` | — |
| `createAnnouncement(channelId, title, content)` | POST | `/channels/:id/announcements` | — |
| `getNotes(channelId)` | GET | `/channels/:id/notes` | — |
| `getNotifications()` | GET | `/notifications` | — |
| `markNotificationRead(id)` | PATCH | `/notifications/:id/read` | — |
| `getAcademicEvents(month?, year?, type?)` | GET | `/academic-events` | Dynamic query params |
| `getProjects()` | GET | `/projects` | — |
| `getProject(id)` | GET | `/projects/:id` | Nested members + tasks |
| `createProject(data)` | POST | `/projects` | — |
| `updateProjectProgress(id, progress)` | PATCH | `/projects/:id/progress` | Manual % |
| `deleteProject(id)` | DELETE | `/projects/:id` | Creator only |
| `createProjectTask(projectId, data)` | POST | `/projects/:id/tasks` | — |
| `updateProjectTaskStatus(projectId, taskId, status)` | PATCH | `.../tasks/:taskId/status` | Auto-updates project % |
| `getTeacherStats()` | GET | `/teacher/stats` | Faculty dashboard |
| `getTeacherRecentActivity()` | GET | `/teacher/recent-activity` | Faculty feed |
| `getStudentRecentActivity()` | GET | `/teacher/student-activity` | Student feed |
