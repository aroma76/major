# Code Quality Review: `code_quality_review.md`

> A comprehensive review of the codebase: patterns used, why they work, potential improvements, and anything a developer should know before modifying the code.

---

## Architecture Assessment

### ✅ What the Codebase Does Well

#### 1. Clean Separation of Concerns

The frontend follows a strict layered architecture:

```
UI (Widgets)
  └─ calls ref.watch / ref.read
      └─ Providers (State layer)
          └─ calls Repositories
              └─ Repositories call ApiService
                  └─ ApiService uses Dio
```

No widget directly calls `ApiService` or `SocketService`. All data flows through providers. This makes testing, debugging, and refactoring straightforward.

#### 2. Consistent State Management

Every piece of state has exactly ONE home:
- Navigation index → `navigationProvider`
- Search query → `searchQueryProvider`
- Theme → `themeModeProvider`
- Auth → `authProvider`
- Messages per channel → `messagesNotifierProvider(channelId)`

No duplicate state. No "lift state up" confusion.

#### 3. Cache-First Loading in MessagesNotifier

```dart
// Show cache immediately
state = state.copyWith(messages: cachedMsgs, isLoading: true);
// Then replace with fresh data
state = state.copyWith(messages: freshMsgs, isLoading: false);
```

This is a professional UX pattern — users see content instantly, even on slow connections.

#### 4. Lazy Loading (`_LazyIndexedStack`)

Screens are only built when first visited. 8 screens in the stack means without lazy loading, all 8 fire API calls at startup. With lazy loading, only the initial screen loads.

#### 5. `mounted` Guards

Async callbacks consistently check `mounted` / `_disposed`:

```dart
if (_disposed) return;       // in MessagesNotifier
if (!mounted) return;        // in AnnouncementsPanel
```

Prevents setState-on-disposed-widget errors that plague many Flutter apps.

#### 6. Socket Cleanup

```dart
@override
void dispose() {
  SocketService().off('announcement:new');
  super.dispose();
}
```

Every `initState` socket listener is cleaned up in `dispose`. No memory leaks from dangling event listeners.

#### 7. `RepaintBoundary` on Static Widgets

```dart
const RepaintBoundary(child: SidebarWidget()),
const RepaintBoundary(child: TopBarWidget()),
```

Sidebar and top bar don't need to repaint when the content area updates. `RepaintBoundary` creates independent paint layers.

---

## Backend Quality

### ✅ Consistent Controller Pattern

All controllers follow the same shape:
```javascript
exports.functionName = async (req, res) => {
  try {
    const { param } = req.body / req.params / req.query;
    // validate
    // query DB
    res.json({ key: value });
  } catch (err) {
    console.error('context:', err.message);
    res.status(500).json({ message: 'Error description' });
  }
};
```

Predictable structure makes it easy to add new endpoints.

### ✅ JWT Middleware Applied Correctly

All routes use `authMiddleware` except:
- `POST /auth/login`
- `POST /auth/register`
- `GET /auth/check-setup`

No route accidentally exposes protected data.

### ✅ Role Checks in Controllers

Faculty-only operations check `req.user.role`:

```javascript
if (req.user.role !== 'faculty' && req.user.role !== 'admin') {
  return res.status(403).json({ message: 'Only faculty can post announcements.' });
}
```

Security is enforced at the controller layer (not just the frontend).

---

## Potential Improvements

### 🟡 Tasks Not Persisted to Backend

**Issue:** `taskProvider` is local-only. Kanban tasks are lost on app restart.

```dart
// task_provider.dart
static final List<TaskModel> _initialTasks = [];  // always starts empty
```

**Fix:** Add a task creation API endpoint. On `addTask()`, call the API and save to the DB. On app start, fetch tasks from the backend. The local `taskProvider` state should be seeded from the API.

---

### ✅ Optimistic Updates for Messages (Implemented)

**Send flow:** A temporary message with a local timestamp ID is appended instantly. When the socket broadcast arrives, the deduplication check (`senderId == myId`) skips it — so the user only ever sees one copy.

**Delete flow:** The message is removed from the UI instantly before the API call completes. If the API fails, a SnackBar appears, but the message stays removed (acceptable UX trade-off).

```dart
// Optimistic delete
ref.read(messagesNotifierProvider(chanId).notifier).optimisticRemove(msg.id);
await ApiService().deleteMessage(chanId, msg.id);
```

---

### ✅ `AppConfig._devMode` — Easy Environment Switching

The `AppConfig` class uses a single boolean flag to switch between local development and production:

```dart
// lib/core/config/app_config.dart
static const bool _devMode = false; // set to true for local backend
static String get baseUrl => _devMode ? _devUrl : _productionUrl;
```

**To develop locally:** flip `_devMode = true` — one line change, no hunting for hardcoded URLs.

**Before pushing to production:** flip back to `false`.

Both URLs are always present in the code (no `unused_field` warnings) because `baseUrl` references both in the conditional.

---

### 🟡 File Uploads Don't Show Upload Progress

**Current:** File uploads are "fire and forget" — the user sees nothing until complete.

**Fix:** Use `Dio`'s `onSendProgress` callback:

```dart
await _api.dio.post('/messages/upload', data: formData,
  onSendProgress: (sent, total) {
    setState(() => _uploadProgress = sent / total);
  }
);
```

---

### 🟡 No Pagination in Channels/Assignments

**Current:** `getMyChannels()` fetches ALL channels at once. For a student with 10+ subjects, this is fine. For a faculty managing 30+ channels, this could be slow.

**Fix:** Add cursor-based pagination similar to messages (already implemented well in `MessagesNotifier`).

---

### 🟡 Task Model Has No Backend ID

**Current:**
```dart
id: DateTime.now().millisecondsSinceEpoch.toString(), // local ID
```

If tasks are ever synced to the backend, this ID scheme won't work (the backend uses auto-increment `int` IDs). Should plan ahead with UUIDs or backend-assigned IDs.

---

### 🟢 Minor Positives Worth Noting

| Pattern | Location | Why it's Good |
|---|---|---|
| `_disposed` flag | `MessagesNotifier` | Prevents state updates after disposal |
| `addPostFrameCallback` in `initState` | `AnnouncementsPanel` | Avoids calling `ref` during build |
| `conditional keepAlive` | `dashboardRecentActivityProvider` | Error states remain retryable |
| `base64Url.normalize()` | `AuthService.restoreSession` | Correctly handles JWT padding |
| `SizedBox.shrink()` fallback | `NotificationPanel` | Clean empty widget idiom |
| `Tween<double>(begin: 1.0, end: 0.88)` | Bottom nav tile | Tactile press feedback |

---

## File Organization Summary

```
frontend/lib/
├─ core/
│   ├─ services/      api_service, socket_service, auth_service, storage_service
│   ├─ theme/         app_colors (colors + theme providers)
│   └─ utils/         responsive (breakpoints)
│
├─ features/
│   ├─ auth/
│   │   ├─ auth_provider.dart
│   │   └─ login_screen.dart
│   │
│   └─ dashboard/
│       ├─ data/
│       │   ├─ models/       (5 model files)
│       │   └─ repositories/ (6 repository files)
│       └─ presentation/
│           ├─ providers/    (4 provider files)
│           ├─ screens/      (main_dashboard, project_detail, login)
│           └─ widgets/      (15+ widget files)
│
└─ main.dart
```

**Backend:**
```
backend/
├─ config/           db.js, supabase.js
├─ controllers/      (8 controller files)
├─ middleware/        auth.js, errorHandler.js
├─ routes/           (8 route files)
├─ socket/           socket.js (all socket events)
└─ server.js
```

---

## Glossary of Key Terms Used Throughout the Codebase

| Term | Meaning |
|---|---|
| `ref.watch` | Subscribe to a provider — widget rebuilds when it changes |
| `ref.read` | Read once — no subscription, used in callbacks |
| `ref.listen` | Subscribe to changes for side effects (no rebuild) |
| `ref.invalidate` | Force provider to discard cache and re-fetch |
| `ref.keepAlive` | Prevent autoDispose from cleaning up the provider |
| `AsyncValue<T>` | Wrapper for async state: `AsyncLoading`, `AsyncData<T>`, `AsyncError` |
| `copyWith` | Create a new object with one field changed (immutable update) |
| `mounted` | Whether the widget is still in the tree (safe to call setState) |
| `_disposed` | Custom flag in Notifiers to check if provider was disposed |
| `autoDispose` | Provider is cleaned up when no widgets watch it |
| `family` | Provider variant that accepts a parameter |
| `FutureProvider` | Async data that fetches once |
| `NotifierProvider` | Mutable state with methods |
| `ConsumerWidget` | Riverpod-aware `StatelessWidget` |
| `ConsumerStatefulWidget` | Riverpod-aware `StatefulWidget` |
| `SocketService` | Singleton WebSocket client |
| `ApiService` | Singleton Dio HTTP client |
| `RepaintBoundary` | Performance isolation: prevents unnecessary repaints |
| `LazyIndexedStack` | Custom widget that only builds screens on first visit |
| `breakpoint` | 850px: below = mobile layout, above = desktop layout |
| `_devMode` | `AppConfig` flag to switch between local and production backend |

---

## Build & Deployment Notes

### Flutter Version Pinned to 3.41.9

The Vercel build (`frontend/build.sh`) and GitHub Actions (`.github/workflows/frontend-ci.yml`) both pin Flutter to **3.41.9**.

**Why pinned?** Flutter 3.44.0 (released May 2026) made `IconData` a `final` class. The `flutter_feather_icons: ^2.0.0+1` package extends `IconData` internally and hasn't been updated since 2021 — it breaks on 3.44.0.

> **When upgrading Flutter:** First check if a newer `flutter_feather_icons` (or replacement) supports the target version. The pin is in two files:
> - `frontend/build.sh` — line: `FLUTTER_URL="...flutter_linux_3.41.9-stable.tar.xz"`
> - `.github/workflows/frontend-ci.yml` — the `Setup Flutter` step

### Vercel Build Pipeline

Vercel calls `bash build.sh` (configured in `frontend/vercel.json`). The script:

1. Downloads the pinned Flutter SDK as a **tarball** from Google's CDN (fast, no git history)
2. Adds `git config --global --add safe.directory` (required because Vercel runs as root)
3. Runs `flutter pub get`
4. Runs `flutter build web --release --no-tree-shake-icons`

Output goes to `frontend/build/web/` which Vercel serves directly.

### GitHub Actions CI

The `frontend-ci.yml` workflow runs on every push to `main` that touches `frontend/**`. It:
1. Downloads Flutter 3.41.9
2. Runs `flutter analyze --no-fatal-infos` (warnings ARE fatal, infos are not)
3. Checks formatting (warning only, won't block build)
4. Builds `flutter build web --release --no-tree-shake-icons --no-wasm-dry-run`
5. Uploads the build artifact for 7 days
