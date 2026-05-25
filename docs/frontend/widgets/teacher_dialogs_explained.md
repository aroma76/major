# Word-by-Word Deep Dive: `teacher_dialogs_explained.md`

> Covers two teacher-only dialogs:
> - `teacher_create_assignment_dialog.dart` — form to create and publish a new assignment to a subject channel
> - `teacher_post_announcement_dialog.dart` — form to broadcast an announcement to a subject channel
>
> Both are `ConsumerStatefulWidget` dialogs with form validation, dropdown subject selection, API submission, provider cache invalidation, and loading/error states.

---

## Common Pattern: Both Dialogs

Both dialogs share the same lifecycle:

```
1. Teacher fills form (subject, title, content, etc.)
2. Presses submit button
3. Client-side validation runs
4. API call made → loading state
5. Success: invalidate relevant providers → close dialog
6. Failure: show error message → allow retry
```

---

## `teacher_create_assignment_dialog.dart`

### State Fields

```dart
class _TeacherCreateAssignmentDialogState extends ConsumerState<...> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  final _marksCtrl = TextEditingController(text: '100');  // pre-filled

  ChannelModel? _selectedChannel;   // null = not selected yet
  DateTime? _dueDate;               // null = not selected yet
  String _priority = 'medium';      // default
  bool _loading = false;
  String? _error;
}
```

**`TextEditingController(text: '100')`** — pre-fills the Max Marks field with `'100'`. Teachers can override if needed, but the most common value is 100.

**`ChannelModel? _selectedChannel`** — the channel is selected from a dropdown. `null` until the teacher picks one.

**`DateTime? _dueDate`** — the date is picked via `showDatePicker`. `null` until picked.

### Date Picker

```dart
Future<void> _pickDate() async {
  final now = DateTime.now();
  final picked = await showDatePicker(
    context: context,
    initialDate: now.add(const Duration(days: 7)),  // default: 1 week from now
    firstDate: now,
    lastDate: now.add(const Duration(days: 365)),    // max: 1 year ahead
    builder: (ctx, child) => Theme(
      data: Theme.of(ctx).copyWith(
        colorScheme: ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
        ),
      ),
      child: child!,
    ),
  );
  if (picked != null) setState(() => _dueDate = picked);
}
```

**`showDatePicker`** — Flutter's built-in calendar picker. Returns a `Future<DateTime?>` — `null` if the user cancels.

**`initialDate: now.add(const Duration(days: 7))`** — defaults to one week from today. Most assignments are due within a week.

**`builder: (ctx, child) => Theme(data: ..., child: child!)`** — overrides the date picker's theme to use the app's accent color for the selected date highlight and surface color for the background. Without this, the date picker uses Material's default blue.

**`child!`** — the `child` parameter is a `Widget?`. The `!` asserts it's not null (it's always provided by `showDatePicker`).

### Due Date Field (Custom Styled)

```dart
GestureDetector(
  onTap: _pickDate,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    decoration: BoxDecoration(
      color: AppColors.getBackgroundColor(context),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.getBorderColor(context)),
    ),
    child: Row(children: [
      Icon(FeatherIcons.calendar, ...),
      Text(
        _dueDate == null
            ? 'Pick a date'
            : '${_dueDate!.day}/${_dueDate!.month}/${_dueDate!.year}',
        style: GoogleFonts.outfit(
          color: _dueDate == null
              ? AppColors.getBodyColor(context)    // gray hint
              : AppColors.getHeadingColor(context)  // white when selected
        ),
      ),
    ]),
  ),
),
```

**Why `GestureDetector` instead of a `TextFormField`?** — The date isn't typed; it's picked from a calendar. A tappable container that LOOKS like a text field is the correct UX. The color change (gray → white text) after picking visually confirms selection.

### Submit Function

```dart
Future<void> _submit() async {
  if (!_formKey.currentState!.validate()) return;
  if (_selectedChannel == null) {
    setState(() => _error = 'Please select a subject');
    return;
  }
  if (_dueDate == null) {
    setState(() => _error = 'Please select a due date');
    return;
  }

  setState(() { _loading = true; _error = null; });

  try {
    await ApiService().dio.post(
      '/channels/${_selectedChannel!.id}/assignments',
      data: {
        'title':       _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'due_date':    _dueDate!.toIso8601String(),
        'max_marks':   int.tryParse(_marksCtrl.text.trim()) ?? 100,
        'priority':    _priority,
      },
    );

    ref.invalidate(channelAssignmentsProvider(_selectedChannel!.id));
    ref.invalidate(allAssignmentsProvider);

    if (mounted) Navigator.pop(context, true);
  } catch (e) {
    setState(() { _error = '...'; _loading = false; });
  }
}
```

**Three validations before API call:**
1. `_formKey.validate()` — checks title field (required)
2. `_selectedChannel == null` — checks subject selected
3. `_dueDate == null` — checks date selected

`Form` validation only covers `TextFormField` widgets. Dropdown and date picker are outside the form, so they must be manually validated.

**`_dueDate!.toIso8601String()`** — converts `DateTime` to backend-compatible string: `'2025-05-31T00:00:00.000'`. The backend stores this in the DB's `TIMESTAMP` column.

**`int.tryParse(_marksCtrl.text.trim()) ?? 100`** — safely converts the marks text to an integer. If the text is empty or non-numeric, defaults to `100`.

**`ref.invalidate(channelAssignmentsProvider(_selectedChannel!.id))`** — invalidates the per-channel assignments cache. Next time the student opens that subject's hub, fresh data is loaded.

**`ref.invalidate(allAssignmentsProvider)`** — invalidates the global assignments cache (used in `TodayOverviewWidget` progress calculation).

**`Navigator.pop(context, true)`** — closes dialog AND returns `true` to the caller. The caller can check `final created = await showDialog(...)` and refresh UI if `true`.

### Generic Dropdown `_styledDropdown<T>`

```dart
Widget _styledDropdown<T>({
  required BuildContext context,
  required T value,
  required List<DropdownMenuItem<T>> items,
  required void Function(T?) onChanged,
}) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 12),
  decoration: BoxDecoration(
    color: AppColors.getBackgroundColor(context),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(color: AppColors.getBorderColor(context)),
  ),
  child: DropdownButtonHideUnderline(
    child: DropdownButton<T>(
      value: value,
      items: items,
      onChanged: onChanged,
      dropdownColor: AppColors.getSurfaceColor(context),
      isExpanded: true,
    ),
  ),
);
```

**`<T>`** — generic type parameter. The same `_styledDropdown` works for `DropdownButton<ChannelModel?>` (subject picker) and `DropdownButton<String>` (priority picker). Dart infers `T` from the `items` list type.

**`DropdownButtonHideUnderline`** — wraps `DropdownButton` and removes the default underline border. The outer `Container` provides our custom border instead.

**`isExpanded: true`** — makes the dropdown stretch to fill the available width.

---

## `teacher_post_announcement_dialog.dart`

### Differences from Assignment Dialog

| Feature | Assignment Dialog | Announcement Dialog |
|---|---|---|
| Theme color | Blue (`AppColors.accent`) | Purple (`#A855F7`) |
| Extra fields | Due date, Max marks, Priority | "Mark as Important" toggle |
| API call | `POST /channels/:id/assignments` | `api.createAnnouncement()` |
| Provider invalidations | `channelAssignmentsProvider` + `allAssignmentsProvider` | `channelAnnouncementsProvider` + `dashboardRecentActivityProvider` (both roles) |

### "Mark as Important" Toggle

```dart
GestureDetector(
  onTap: () => setState(() => _isImportant = !_isImportant),
  child: AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    decoration: BoxDecoration(
      color: _isImportant
          ? Colors.red.withValues(alpha: 0.08)  // red tint when active
          : AppColors.getBackgroundColor(context),
      border: Border.all(
        color: _isImportant
            ? Colors.red.withValues(alpha: 0.4)  // red border when active
            : AppColors.getBorderColor(context),
      ),
    ),
    child: Row(children: [
      Icon(
        _isImportant ? FeatherIcons.alertCircle : FeatherIcons.circle,
        color: _isImportant ? Colors.red : AppColors.getBodyColor(context),
      ),
      Expanded(child: Text('Mark as Important', ...)),
      Text(_isImportant ? 'ON' : 'OFF', ...),
    ]),
  ),
),
```

**`AnimatedContainer`** — smoothly transitions background color and border color between states. When tapped, the container "blushes" red over 180ms.

**Icon change:** `FeatherIcons.circle` (off) → `FeatherIcons.alertCircle` (on). The icon itself changes — not just color.

**`'ON'` / `'OFF'` text** — a clear status indicator next to the label. More explicit than an icon or checkbox alone.

### Double Provider Invalidation

```dart
ref.invalidate(channelAnnouncementsProvider(_selectedChannel!.id));
ref.invalidate(dashboardRecentActivityProvider(true));   // faculty view
ref.invalidate(dashboardRecentActivityProvider(false));  // student view
```

After posting, THREE caches are cleared:

1. `channelAnnouncementsProvider(channelId)` — the per-channel announcement list (shown in Subject Hub tab)
2. `dashboardRecentActivityProvider(true)` — faculty dashboard recent activity
3. `dashboardRecentActivityProvider(false)` — student dashboard announcements panel

**Why both `true` and `false`?** — `dashboardRecentActivityProvider` takes an `isFaculty` parameter. Clearing both ensures all dashboard views reflect the new announcement regardless of who's looking.

---

## Summary: Both Dialogs Together

```
TeacherCreateAssignmentDialog          TeacherPostAnnouncementDialog
  Fields:                                Fields:
  ├─ Subject dropdown (channelsProvider)  ├─ Subject dropdown (channelsProvider)
  ├─ Title (TextFormField, required)      ├─ Title (TextFormField, required)
  ├─ Description (multiline)             ├─ Content (multiline, required)
  ├─ Due Date (custom date picker)       └─ "Mark as Important" (toggle)
  ├─ Max Marks (number field, default 100)
  └─ Priority dropdown (low/med/high)
  
  Submit:                                Submit:
  POST /channels/:id/assignments          api.createAnnouncement(...)
  
  Invalidates:                           Invalidates:
  channelAssignmentsProvider(id)          channelAnnouncementsProvider(id)
  allAssignmentsProvider                  dashboardRecentActivityProvider(true)
                                          dashboardRecentActivityProvider(false)
```
