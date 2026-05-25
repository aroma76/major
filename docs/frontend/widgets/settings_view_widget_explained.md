# Word-by-Word Deep Dive: `settings_view_widget_explained.md`

> Covers `settings_view_widget.dart` — the complete Settings screen. Contains three sections: Account Profile, Preferences (toggles for dark mode, notifications, email summary), and Security (change password, logout). Uses `StatefulBuilder` for dialogs that need local loading/error state without a full `StatefulWidget`.

---

## Before Reading — `StatefulBuilder`

**Problem:** A `showDialog()` builder function creates a `StatelessWidget`-like context. You can't call `setState()` inside it to update loading spinners or error messages in the dialog.

**`StatefulBuilder`** — wraps a builder function and gives it its own `setState`. The dialog can rebuild itself independently from the parent widget.

```dart
showDialog(
  context: context,
  builder: (context) => StatefulBuilder(
    builder: (context, setState) => AlertDialog(
      // 'setState' here only rebuilds THIS dialog, not the whole screen
    ),
  ),
);
```

This pattern is used in all three dialogs in this file.

---

## Lines 11–109 — `_showEditProfile()` Dialog

```dart
void _showEditProfile(BuildContext context, WidgetRef ref) {
  final authState = ref.read(authProvider).value;
  final nameCtrl = TextEditingController(text: authState?.userName ?? '');
  final dobCtrl = TextEditingController(
    text: authState?.user?['dob'] != null
        ? (authState!.user!['dob'] as String).substring(0, 10)
        : '',
  );
  bool isLoading = false;
  String? errorMsg;
```

**`ref.read(authProvider).value`** — reads current auth state once. `ref.read` (not `ref.watch`) because we just need the initial value to pre-fill fields. No subscription needed.

**`TextEditingController(text: ...)`** — pre-fills the text field with existing data. If the user's name is "Aryan Sharma", the Name field opens already populated.

**`authState?.user?['dob'] as String`** — DOB from the raw user JSON (ISO 8601 format: `'2003-05-26T00:00:00.000Z'`). `.substring(0, 10)` extracts just `'2003-05-26'`.

**`bool isLoading = false`** — local variable in the function scope. Shared between the dialog's `StatefulBuilder` closure and the button handler. When the Save button is pressed, `setState(() => isLoading = true)` updates this, and the button rebuilds to show a spinner.

### Save Button Logic

```dart
onPressed: isLoading
    ? null
    : () async {
        setState(() {
          isLoading = true;
          errorMsg = null;
        });
        try {
          await ref.read(authProvider.notifier).updateProfile(
                name: nameCtrl.text.trim(),
                dob: dobCtrl.text.trim(),
              );
          if (context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile updated!'),
                  backgroundColor: Colors.green),
            );
          }
        } catch (e) {
          setState(() {
            isLoading = false;
            errorMsg = 'Failed to update. Please try again.';
          });
        }
      },
```

**Three-state logic:**
1. Initial: `isLoading = false`, `errorMsg = null`
2. Saving: `isLoading = true`, button shows spinner, both buttons disabled
3a. Success: `Navigator.pop` → dialog closes → green snackbar
3b. Failure: `isLoading = false`, `errorMsg` shown in red

**`context.mounted`** — after `await`, the dialog may have been closed by the user. Checking `context.mounted` prevents calling `Navigator.pop` on a dead context.

---

## Lines 111–205 — `_showChangePassword()` Dialog

```dart
if (newController.text != confirmController.text) {
  setState(() => errorMsg = 'New passwords do not match');
  return;  // Early return — don't call the API
}
if (newController.text.length < 6) {
  setState(() => errorMsg = 'Password must be at least 6 characters');
  return;
}
```

**Client-side validation before API call** — two checks happen BEFORE calling `changePassword()`:
1. New and confirm passwords match
2. New password is at least 6 characters

**`return`** — exits the `onPressed` handler early. The API is NOT called. `setState` shows the error message in the dialog.

This prevents unnecessary API round-trips for obviously invalid input.

---

## Lines 207–235 — `_showLogoutConfirmation()` Dialog

```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Logout'),
    content: Text('Are you sure you want to sign out?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      ElevatedButton(
        onPressed: () async {
          Navigator.pop(context);       // Close dialog FIRST
          await ref.read(authProvider.notifier).logout();
        },
        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
        child: const Text('Sign Out'),
      ),
    ],
  ),
);
```

**No `StatefulBuilder`** — this dialog has no loading state. The logout is fast (just clears tokens locally and notifies Riverpod).

**`Navigator.pop(context)` BEFORE `logout()`** — closes the dialog FIRST, then performs logout. If logout was called first, the navigation to LoginScreen might interfere with the dialog's Navigator context.

**Red button** — `ElevatedButton.styleFrom(backgroundColor: Colors.red)` clearly signals danger. Users are less likely to accidentally tap a clearly red button.

---

## Lines 237–304 — Dialog Field Builders

### `_buildDialogField`

```dart
Widget _buildDialogField(BuildContext context, String label, String placeholder, {
  bool obscure = false,
  TextEditingController? controller,
  String? hint,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontWeight: FontWeight.bold, ...)),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: hint ?? placeholder,
          filled: true,
          fillColor: AppColors.getBackgroundColor(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,  // ← removes visible border
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    ],
  );
}
```

**`obscureText: obscure`** — when `true`, replaces characters with `●`. Used for all password fields.

**`borderSide: BorderSide.none`** — removes the TextField's default border line. The field is styled by `fillColor` only, giving a clean, modern look.

**`hintText: hint ?? placeholder`** — `hint` overrides `placeholder` if provided. Allows different hint text from the label.

### `_buildReadOnlyField`

```dart
Container(
  decoration: BoxDecoration(
    color: AppColors.getBorderColor(context).withValues(alpha: 0.3),
    borderRadius: BorderRadius.circular(12),
  ),
  child: Row(children: [
    Expanded(child: Text(value, ...)),
    Icon(Icons.lock_outline, size: 14, ...),  // lock icon
  ]),
),
```

**Lock icon** — visually signals "this cannot be edited". Email and roll number come from the backend and cannot be changed in this dialog.

**`withValues(alpha: 0.3)`** — slightly grayed-out background, reinforcing the "read-only" concept visually.

---

## Lines 306–545 — `build()` — Main Settings Screen

### Provider Watching

```dart
final themeMode = ref.watch(themeModeProvider);
final notificationsEnabled = ref.watch(isNotificationsEnabledProvider);
final emailSummaryEnabled = ref.watch(isEmailSummaryEnabledProvider);
final authState = ref.watch(authProvider).value;
```

Four providers watched — each toggle reflects live provider state and immediately reacts to changes from any source.

### Role Display (Capitalization)

```dart
Text(
  userRole[0].toUpperCase() + userRole.substring(1),
  // 'student' → 'Student'
  // 'faculty' → 'Faculty'
),
```

**`userRole[0].toUpperCase()`** — first character, uppercased.
**`+ userRole.substring(1)`** — rest of the string from index 1 onward.

Result: `'student' → 'S' + 'tudent' = 'Student'`. Manual title-case without importing a formatting library.

---

## Lines 547–619 — `_buildSectionHeader` and `_buildToggleTile`

### Section Header

```dart
Text(
  title.toUpperCase(),
  style: TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.bold,
    color: AppColors.getBodyColor(context).withValues(alpha: 0.7),
    letterSpacing: 1.2,
  ),
),
```

**`letterSpacing: 1.2`** — adds 1.2 logical pixels between each character. Combined with uppercase text and small font size, this creates a "label" look (like CSS `text-transform: uppercase; letter-spacing: 0.1em`).

**`withValues(alpha: 0.7)`** — 70% opacity, subdued. Section headers are secondary to the content below them.

### Toggle Tile

```dart
Switch(
  value: value,
  onChanged: onChanged,
  activeThumbColor: AppColors.accent,
),
```

**`Switch`** — Flutter's built-in toggle. `activeThumbColor` changes the thumb (the circle) to accent blue when ON. The track color uses the system default (slightly transparent accent on Android, green on iOS).

**`onChanged: onChanged`** — the callback from the parent. For Dark Mode:
```dart
(val) => ref.read(themeModeProvider.notifier).toggle()
```
Note: the `val` parameter (new bool) is ignored — the notifier toggles based on current state.

---

## Lines 622–672 — `_buildActionTile` — Danger Flag

```dart
Widget _buildActionTile(
  BuildContext context, String title, String subtitle,
  IconData icon, VoidCallback onTap,
  {bool isDanger = false}
) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      child: Row(children: [
        Container(
          decoration: BoxDecoration(
            color: (isDanger ? Colors.red : AppColors.getBorderColor(context))
                .withValues(alpha: 0.1),
          ),
          child: Icon(icon,
              color: isDanger ? Colors.red : AppColors.getHeadingColor(context)),
        ),
        Expanded(
          child: Column(children: [
            Text(title, style: TextStyle(
                color: isDanger ? Colors.red : AppColors.getHeadingColor(context))),
            Text(subtitle, ...),
          ]),
        ),
        Icon(Icons.chevron_right, color: ..., size: 20),
      ]),
    ),
  );
}
```

**`{bool isDanger = false}`** — named optional parameter. "Change Password" calls it without `isDanger` → default `false`. "Logout" calls with `isDanger: true` → everything turns red.

**`isDanger` affects three things:**
1. Icon background: red tint vs gray tint
2. Icon color: red vs heading color
3. Title color: red vs heading color

**`Icons.chevron_right`** — standard "tap to go somewhere" affordance. Even though these open dialogs (not navigate), the chevron signals interactivity.

---

## Summary Table

| Section | Providers Read/Watched | Action |
|---|---|---|
| Profile | `authProvider.value` | `authProvider.notifier.updateProfile()` |
| Dark Mode toggle | `themeModeProvider` | `themeModeProvider.notifier.toggle()` |
| Notifications toggle | `isNotificationsEnabledProvider` | `.notifier.set(val)` |
| Email Summary toggle | `isEmailSummaryEnabledProvider` | `.notifier.set(val)` |
| Change Password | — | `authProvider.notifier.changePassword()` |
| Logout | — | `authProvider.notifier.logout()` |
