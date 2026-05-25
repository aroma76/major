# Word-by-Word Deep Dive: `frontend/lib/core/theme/app_colors.dart`

> This file is the **design system core** of the Flutter app. It defines every color, gradient, and theme-aware helper used across all widgets. It also houses the **theme toggle provider**, notification state, and settings toggles. Understanding this file means understanding exactly how dark/light mode works and where every color in the UI comes from.

---

## Before Reading — Flutter Theming Basics

**`ThemeMode`** — a Flutter enum: `ThemeMode.dark`, `ThemeMode.light`, `ThemeMode.system`

**`Theme.of(context).brightness`** — reads the current brightness from the widget tree:
- In dark mode → `Brightness.dark`
- In light mode → `Brightness.light`

**`BuildContext`** — represents the location of a widget in the widget tree. Required to look up the current theme because themes flow down the tree.

---

## Lines 4–14 — Global Providers

```dart
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(() => ThemeModeNotifier());
final notificationProvider =
    NotifierProvider<NotificationNotifier, List<AppNotification>>(
        () => NotificationNotifier());
final isNotificationsEnabledProvider =
    NotifierProvider<NotificationsEnabledNotifier, bool>(
        () => NotificationsEnabledNotifier());
final isEmailSummaryEnabledProvider =
    NotifierProvider<EmailSummaryEnabledNotifier, bool>(
        () => EmailSummaryEnabledNotifier());
```

**`NotifierProvider<TNotifier, TState>`** — a Riverpod provider that holds a `Notifier` (the controller) and its state value.
- `TNotifier` — the class that manages state (has methods to change it)
- `TState` — the type of state being managed

**`() => ThemeModeNotifier()`** — a factory function that creates the notifier. Called only once when the provider is first read.

These providers are declared at the **file level** (not inside a class) — this makes them globally accessible from any widget that has `ref`.

---

## Lines 16–36 — Simple Boolean Notifiers

```dart
class NotificationsEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void toggle() => state = !state;
  void set(bool value) => state = value;
}
```

**`extends Notifier<bool>`** — a Riverpod `Notifier`. The type parameter `bool` is the state type.

**`build()`** — returns the **initial state**. `true` means notifications are on by default.

**`state`** — the current value of the notifier. Setting `state = newValue` automatically rebuilds any widget that `watch`es this provider.

**`void toggle()`** — `!state` flips the boolean. If `true → false`, if `false → true`.

**`void set(bool value)`** — direct assignment. Used when loading settings from storage.

---

## Lines 30–36 — `ThemeModeNotifier`

```dart
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ThemeMode.dark;
  void toggle() =>
      state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
  void setTheme(ThemeMode mode) => state = mode;
}
```

**`ThemeMode build() => ThemeMode.dark`** — app starts in dark mode by default.

**`toggle()`** — switches between dark and light:
- `state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark`
- Ternary: if currently dark → become light; if currently light → become dark
- No `system` mode — explicit user control only.

**Used in `TopBarWidget`:**
```dart
ref.read(themeModeProvider.notifier).toggle()
```

---

## Lines 38–52 — `AppNotification` Data Class

```dart
class AppNotification {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  bool isRead;

  AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });
}
```

**`final String id`** — immutable after construction. `final` fields cannot be changed.

**`bool isRead`** — NOT final — can be mutated. However, the `NotificationNotifier.markAsRead()` creates a new object instead of mutating (immutable state pattern).

**`this.isRead = false`** — default parameter. If not provided, defaults to `false` (unread).

---

## Lines 54–94 — `NotificationNotifier`

```dart
class NotificationNotifier extends Notifier<List<AppNotification>> {
  @override
  List<AppNotification> build() => [
    AppNotification(id: '1', title: 'New Assignment', ...),
    AppNotification(id: '2', title: 'Project Deadline', ...),
    AppNotification(id: '3', title: 'New Message', ...),
  ];

  void add(AppNotification notification) => state = [notification, ...state];
  void remove(String id) => state = state.where((n) => n.id != id).toList();
  void clearAll() => state = [];
  void markAsRead(String id) {
    state = [
      for (final n in state)
        if (n.id == id)
          AppNotification(id: n.id, title: n.title, message: n.message,
              timestamp: n.timestamp, isRead: true)
        else
          n
    ];
  }
}
```

**`build()` returns a default list** — seed/demo notifications. These are UI placeholders; actual notifications come from the API.

### `void add(notification) => state = [notification, ...state]`

**`[notification, ...state]`** — creates a NEW list with `notification` at the front, followed by all existing items (spread). In Riverpod, setting `state = newList` triggers rebuilds. Mutating the list directly (`.add()`) would NOT trigger rebuilds.

### `void remove(id) => state.where((n) => n.id != id).toList()`

**`.where((n) => n.id != id)`** — Dart `Iterable.where()` is a filter. Returns all items where the condition is true. `n.id != id` means "keep everything except the one with this ID."

**`.toList()`** — converts the `Iterable` (lazy sequence) to a `List` (eagerly evaluated, reusable).

### `markAsRead` — Immutable Update Pattern

```dart
state = [
  for (final n in state)
    if (n.id == id)
      AppNotification(id: n.id, title: n.title, ..., isRead: true)
    else
      n
];
```

**Collection `for` with `if`** — a Dart collection expression inside a list literal:
- For each notification `n` in the current state
- If `n.id == id`: create a NEW `AppNotification` with `isRead: true`
- Otherwise: keep the original `n`

Result: a new list where only the targeted notification has changed. This pattern preserves immutability — we never mutate existing objects.

---

## Lines 96–117 — `AppColors` Static Color Definitions

```dart
class AppColors {
  static const Color background = Color(0xFF0D1117);
  static const Color surface = Color(0xFF161B22);
  static const Color cardBackground = Color(0xFF21262D);
  static const Color accent = Color(0xFF58A6FF);
  ...
```

**`static const`** — belongs to the CLASS (not instances), compile-time constant. Accessed as `AppColors.accent` — no need to create an `AppColors` object.

**`Color(0xFF0D1117)`** — a Flutter `Color` from a hex value:
- `0xFF` — alpha channel (FF = fully opaque = 255/255)
- `0D1117` — RGB hex: R=0x0D=13, G=0x11=17, B=0x17=23 → very dark navy (GitHub dark background)

**The color palette follows GitHub's dark mode:**
| Constant | Hex | Role |
|---|---|---|
| `background` | `#0D1117` | Main page background |
| `surface` | `#161B22` | Card/panel background |
| `cardBackground` | `#21262D` | Nested card background |
| `accent` | `#58A6FF` | GitHub's signature blue — buttons, highlights, selected items |
| `textBody` | `#8B949E` | Muted text, placeholders |
| `textHeading` | `#C9D1D9` | Primary readable text |

**Priority colors:**
```dart
static const Color priorityHigh = Color(0xFFFF4D4D);    // red
static const Color priorityMedium = Color(0xFFFFD93D);  // yellow
static const Color priorityLow = Color(0xFF4CAF50);     // green
```

**Kanban status colors:**
```dart
static const Color todoColor = Color(0xFF7D8590);       // gray
static const Color inProgressColor = Color(0xFFD29922); // amber
static const Color doneColor = Color(0xFF238636);       // GitHub green
```

---

## Lines 113–117 — `accentGradient`

```dart
static const LinearGradient accentGradient = LinearGradient(
  colors: [Color(0xFF58A6FF), Color(0xFF1F6FEB)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
```

**`LinearGradient`** — a gradient that transitions linearly from one color to another.

**`colors: [lightBlue, darkBlue]`** — starts at `#58A6FF` (lighter blue), ends at `#1F6FEB` (deeper blue).

**`Alignment.topLeft → Alignment.bottomRight`** — diagonal gradient (45° angle). Used on the "New Task / Post / Create" button.

---

## Lines 127–161 — Theme-Aware Color Getters

```dart
static Color getBackgroundColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? background
      : lightBackground;
}
```

**`Theme.of(context).brightness`** — reads the theme brightness from the widget tree. `Brightness.dark` or `Brightness.light`.

**`? background : lightBackground`** — ternary: dark mode uses dark constants, light mode uses light constants.

**Why static methods instead of just checking in widgets?**
Without these helpers, every widget would need:
```dart
Theme.of(context).brightness == Brightness.dark
    ? AppColors.background
    : AppColors.lightBackground
```
With helpers:
```dart
AppColors.getBackgroundColor(context)
```
DRY principle — one place to change if the colors need updating.

### `getBorderColor(BuildContext context)`

```dart
static Color getBorderColor(BuildContext context) {
  return Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF30363D)  // dark border: barely visible dark gray
      : const Color(0xFFD0D7DE); // light border: GitHub's light gray border
}
```

No named constant for border colors — they're defined inline since borders aren't used as frequently as the main palette.

---

## How Colors Flow Through the App

```
User toggles theme
  → ref.read(themeModeProvider.notifier).toggle()
  → state changes (ThemeMode.dark ↔ ThemeMode.light)
  → MaterialApp rebuilds with new themeMode
  → Theme.of(context).brightness changes
  → All AppColors.get*Color(context) return different values
  → Entire UI re-renders with correct colors
```
