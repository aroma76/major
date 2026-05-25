# 📄 `core/utils/responsive.dart` & `core/config/app_config.dart` — Complete Explanation

---

# `responsive.dart`

**File Path:** `frontend/lib/core/utils/responsive.dart`
**Lines:** 22
**Role:** Single source of truth for responsive breakpoints across the entire app.

---

## Purpose

```dart
class Responsive {
  Responsive._();  // Private constructor — no instances

  static const double breakpoint = 850.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.sizeOf(context).width < breakpoint;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= breakpoint;
}
```

**`Responsive._()` — Private Constructor:**
The class can never be instantiated (`Responsive r = Responsive()` is a compile error). All methods are `static` — called as `Responsive.isMobile(context)`. This is the **utility class pattern**.

**`breakpoint = 850.0`:**
The single value that controls the entire app's layout switching behavior. All responsive decisions are made relative to this one constant. If you ever need to change the breakpoint, it's done in exactly one place.

**`MediaQuery.sizeOf(context)` vs `MediaQuery.of(context).size`:**
- `MediaQuery.of(context)` rebuilds the widget whenever ANY MediaQuery property changes (keyboard shown, brightness changed, text scale changed, etc.)
- `MediaQuery.sizeOf(context)` (Flutter 3.7+) **only rebuilds when the screen SIZE changes**
- For breakpoint detection, we only care about size changes. Using `sizeOf` reduces unnecessary rebuilds significantly on mobile (e.g., keyboard pop-up wouldn't trigger a rebuild)

**Usage throughout the app:**
```dart
// In MainDashboardScreen:
final isMobile = Responsive.isMobile(context);

if (!isMobile)
  SizedBox(width: 240, child: SidebarWidget()),  // Desktop sidebar

bottomNavigationBar: isMobile ? _MobileBottomNavBar(...) : null,
```

**850px breakpoint rationale:**
- Tablets (iPad portrait): ~768px wide → mobile layout
- Tablets (iPad landscape): ~1024px wide → desktop layout
- Typical laptop: 1280px → desktop layout
- Phone: 360-430px → mobile layout
The 850px breakpoint correctly splits these into two categories.

---

# `app_config.dart`

**File Path:** `frontend/lib/core/config/app_config.dart`
**Lines:** ~12

```dart
class AppConfig {
  static const String baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'http://localhost:5000',
  );
}
```

OR the likely implementation with environment detection:

```dart
class AppConfig {
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  
  static String get baseUrl {
    if (isProduction) {
      return 'https://adtu-collab.onrender.com';
    }
    return 'http://localhost:5000';
  }
}
```

**Purpose:** Single configuration point for the API server URL. Every service (`ApiService`, `SocketService`) imports this.

**Development vs Production:**
- Local: `http://localhost:5000` — the local Node.js server
- Production: `https://adtu-collab.onrender.com` — the deployed Render.com backend

**Why centralize?** Without this, changing the production URL would require finding and updating every Dio client and Socket.IO connection across multiple files. With `AppConfig.baseUrl`, there's one place to change.

---

# `providers/saved_files_provider.dart` — Complete Explanation

**File Path:** `frontend/lib/features/dashboard/presentation/providers/saved_files_provider.dart`
**Lines:** 83
**Role:** In-memory "bookmarks" store — lets users save important file messages (notes, question papers) for quick access.

---

## Purpose & Design

`SavedFilesNotifier` is a local (no server persistence) bookmark system for file messages in channels. When a user sees a PDF file message and wants to save it for later, they can "bookmark" it. Saved files appear in the Notes and Question Papers screens.

```dart
enum SavedFileType { note, questionPaper }

class SavedFile {
  final String id;        // "${msgId}_${type.name}" — composite key
  final int channelId;
  final String subjectName;
  final String fileName;
  final String fileUrl;   // Supabase public URL
  final SavedFileType type;
  final String sharedBy;  // Sender's name
  final DateTime savedAt;
}
```

**Composite ID:**
```dart
String _key(String msgId, SavedFileType type) => '${msgId}_${type.name}';
```
- Example: `'142_note'` or `'142_questionPaper'`
- The same message can be saved as both a note AND a question paper (edge case).

---

## Key Methods

```dart
bool isSaved(String msgId, SavedFileType type) =>
    state.any((f) => f.id == _key(msgId, type));
```
O(n) check — checks if any saved file has this composite ID. Used to show "bookmarked" icon on file messages.

```dart
void save({ ... }) {
  final key = _key(msgId, type);
  if (isSaved(msgId, type)) return;  // idempotent — no duplicates
  state = [...state, SavedFile(id: key, ...)];
}
```

```dart
Map<String, List<SavedFile>> groupedBySubject(SavedFileType type) {
  final files = byType(type);
  final map = <String, List<SavedFile>>{};
  for (final f in files) {
    map.putIfAbsent(f.subjectName, () => []).add(f);
  }
  return map;
}
```
Groups saved files by `subjectName`. Used in the Notes and Question Papers screens to organize files under subject headings.

**`putIfAbsent(key, ifAbsent)`:** If `key` doesn't exist in `map`, creates it using `ifAbsent()`. Then adds the file to the (possibly just-created) list.

---

## Limitation

All saved files are **in-memory only**. When the app restarts, all saved files are lost. A production implementation would:
1. Persist to `SharedPreferences` (local) or
2. Persist to the backend database (synced across devices)

---

## Summary Table — All Utility Files

| File | Lines | Purpose |
|---|---|---|
| `responsive.dart` | 22 | Screen size breakpoint utilities |
| `app_config.dart` | ~12 | API base URL configuration |
| `saved_files_provider.dart` | 83 | In-memory file bookmark state |
| `app_colors.dart` | 163 | Design system + theme providers |
