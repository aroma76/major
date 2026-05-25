# Word-by-Word Deep Dive: `subjects_and_projects_view_widgets_explained.md`

> Covers `subjects_view_widget.dart` and `projects_view_widget.dart`. Both are read-data screens backed by `FutureProvider`, both feature responsive grid/list layouts, hover animations, color palettes, and navigation into a detail screen or hub sheet. They share many patterns, making them ideal to study together.

---

## PART 1: `subjects_view_widget.dart`

---

## Lines 14–22 — Static Color Palette

```dart
static const _palette = [
  Color(0xFF58A6FF), // blue
  Color(0xFFD29922), // amber
  Color(0xFF3FB950), // green
  Color(0xFFA475F9), // purple
  Color(0xFFFF6B6B), // coral-red
  Color(0xFF26C6DA), // teal
  Color(0xFFFF9800), // orange
];
```

**`static const`** — belongs to the CLASS (not each instance). Only one copy of the list exists in memory.

**Why a palette instead of one color?** — Each subject card gets a distinct color, making the grid visually varied and easier to scan. Color is assigned by index:

```dart
final color = _palette[index % _palette.length];
```

**`index % _palette.length`** — modulo wraps around. With 7 colors and 8+ subjects, the 8th subject gets `7 % 7 = 0` (first color again). The first 7 subjects each get a unique color.

---

## Lines 29–164 — `build()` — Three-State `.when()`

```dart
return channelsAsync.when(
  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
  error: (e, _) => Center(
    child: Column([
      Icon(FeatherIcons.alertCircle, color: Colors.red),
      Text('Failed to load subjects'),
      ElevatedButton.icon(
        onPressed: () => ref.invalidate(channelsProvider),
        label: const Text('Retry'),
      ),
    ]),
  ),
  data: (channels) => SingleChildScrollView(...),
);
```

The Retry button calls `ref.invalidate(channelsProvider)` — the provider discards its error state and re-fetches. This is the standard "pull-to-try-again" pattern.

### Responsive Grid

```dart
LayoutBuilder(
  builder: (ctx, constraints) {
    final cols = constraints.maxWidth > 900 ? 3 : 2;
    final ratio = isMobile ? 2.1 : 1.75;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: isMobile ? 10 : 20,
        mainAxisSpacing: isMobile ? 10 : 20,
        childAspectRatio: ratio,
      ),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final color = _palette[index % _palette.length];
        return _SubjectCard(channel: ch, color: color, isMobile: isMobile);
      },
    );
  },
),
```

**`constraints.maxWidth > 900 ? 3 : 2`** — breakpoint inside `LayoutBuilder`. `LayoutBuilder` provides the ACTUAL available width (not screen width). On desktop with a sidebar, this is narrower than the full screen.

**`SliverGridDelegateWithFixedCrossAxisCount`** — configures the grid:
- `crossAxisCount` — number of columns
- `crossAxisSpacing` — horizontal gap between columns
- `mainAxisSpacing` — vertical gap between rows
- `childAspectRatio` — width ÷ height for each cell. `2.1` = wide and short (compact mobile cards). `1.75` = slightly taller (desktop cards).

**`shrinkWrap: true`** — the `GridView` sizes itself to fit its children (doesn't take infinite space). Required when nested inside a `SingleChildScrollView`.

**`physics: NeverScrollableScrollPhysics()`** — disables the grid's own scrolling. The parent `SingleChildScrollView` handles all scrolling. Without this, two conflicting scroll behaviors fight each other.

---

## Lines 168–319 — `_SubjectCard`

### `ConsumerStatefulWidget` — Why Stateful?

```dart
class _SubjectCard extends ConsumerStatefulWidget {
  ...
  @override
  ConsumerState<_SubjectCard> createState() => _SubjectCardState();
}

class _SubjectCardState extends ConsumerState<_SubjectCard> {
  bool _hovered = false;
```

Cards need `_hovered` state for hover animation. This is widget-local state → `StatefulWidget`. They also potentially need `ref` for invalidation → `ConsumerStatefulWidget`.

**`ConsumerStatefulWidget`** — Riverpod's version of `StatefulWidget`. Its state class extends `ConsumerState` instead of `State`.

### Hover Animation

```dart
MouseRegion(
  onEnter: (_) => setState(() => _hovered = true),
  onExit: (_) => setState(() => _hovered = false),
  child: GestureDetector(
    onTap: () {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SubjectHubSheet(channel: widget.channel, color: widget.color),
      );
    },
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _hovered
            ? color.withValues(alpha: 0.07)
            : AppColors.getSurfaceColor(context),
        border: Border.all(
          color: _hovered ? color.withValues(alpha: 0.5) : AppColors.getBorderColor(context),
          width: 1.5,
        ),
        boxShadow: _hovered ? [BoxShadow(color: color.withValues(alpha: 0.18), ...)] : [],
      ),
    ),
  ),
),
```

**Three properties animate together on hover:**
1. Background: transparent → 7% tinted
2. Border: gray → 50% tinted colored
3. Shadow: none → colored glow

All smooth via `AnimatedContainer` (200ms).

**`showModalBottomSheet`** — displays the `SubjectHubSheet` sliding up from the bottom of the screen. Available on both mobile and desktop.

**`isScrollControlled: true`** — allows the bottom sheet to take up more than 50% of screen height (full-height sheets).

**`backgroundColor: Colors.transparent`** — removes the default white/dark background. The `SubjectHubSheet` itself defines its own background.

### Subject Name Fallback

```dart
Text(
  ch.subjectName.isNotEmpty ? ch.subjectName : ch.channelName,
  ...
),
```

If `subjectName` is empty (not set in the database), fall back to `channelName`. Always shows something.

### Teacher Name Guard

```dart
if (ch.teacherName != null && !m)
  Row(children: [Icon(FeatherIcons.user), Text(ch.teacherName!)])
```

Two conditions: `teacherName != null` (a teacher is assigned) AND NOT mobile (`!m`). On mobile, screen space is too tight for the teacher row.

**`ch.teacherName!`** — non-null assertion. We've already checked `teacherName != null`, so `!` is safe here.

---

## PART 2: `projects_view_widget.dart`

---

## Lines 232–251 — Raw JSON to `ProjectModel`

```dart
final progress = ((p['progress'] as num?) ?? 0) / 100.0;
final members = (p['members'] as List<dynamic>?)
        ?.map((m) => (m['name'] ?? m['roll_number'] ?? '?').toString())
        .toList() ??
    [];

final projectModel = ProjectModel(
  id: id.toString(),
  title: title,
  teamMembers: members,
  progress: progress,
  deadline: deadline ?? DateTime.now().add(const Duration(days: 30)),
  description: description,
  color: color,
);
```

**`(p['progress'] as num?) ?? 0) / 100.0`** — the backend stores progress as `0–100` (integer percent). The `ProjectModel` uses `0.0–1.0` (float). Division by 100 converts. `cast as num?` handles both `int` and `double` from JSON.

**Member name extraction:**
```dart
(m['name'] ?? m['roll_number'] ?? '?').toString()
```
- `m['name']` — try the full name first
- `?? m['roll_number']` — fall back to roll number (if name not set)
- `?? '?'` — ultimate fallback

**`ProjectModel` constructed from raw JSON** — `ProjectsViewWidget` uses `projectsProvider` which returns `List<Map<String, dynamic>>` (raw). Here we construct a typed `ProjectModel` for the detail screen.

### Navigation to Detail Screen

```dart
onTap: () => Navigator.of(context).push(
  MaterialPageRoute(
      builder: (_) => ProjectDetailScreen(project: projectModel)),
),
```

**`Navigator.of(context).push(route)`** — pushes a new screen onto the navigation stack. The user can press Back to return.

**`MaterialPageRoute(builder: (_) => ...)`** — a route that uses platform-appropriate transitions (slide from right on iOS, fade on Android).

### Member Avatars (Overlapping Stack)

```dart
for (int i = 0; i < members.take(4).length; i++)
  Align(
    widthFactor: 0.65,
    child: CircleAvatar(
      radius: 14,
      backgroundColor: AppColors.getSurfaceColor(context), // border ring
      child: CircleAvatar(
        radius: 12,
        backgroundColor: color.withValues(alpha: 0.15),
        child: Text(members[i][0].toUpperCase(), ...),
      ),
    ),
  ),
```

**`members.take(4)`** — takes at most 4 members. If there are 10, only 4 avatars show.

**`Align(widthFactor: 0.65)`** — `widthFactor: 0.65` makes the `Align` widget only 65% of the child's width. When placed in a `Row`, consecutive avatars overlap (each takes only 65% of the space). This creates the "stacked faces" effect.

**Outer CircleAvatar** — `radius: 14`, surface background color — acts as a ring/border.
**Inner CircleAvatar** — `radius: 12`, colored background — the actual avatar with the initial letter.

```dart
if (members.length > 4)
  Text('+${members.length - 4} more')
```

If more than 4 members, show "+6 more" after the avatars.

```dart
'${members.length} member${members.length != 1 ? 's' : ''}'
```

**Pluralization guard:** `1 member` vs `3 members`. `members.length != 1 ? 's' : ''` — only add `'s'` if count isn't 1.

### Deadline Color

```dart
color: deadline.isBefore(DateTime.now())
    ? Colors.red.shade400
    : AppColors.getHeadingColor(context),
```

If the deadline has passed → red text. Otherwise → normal heading color. Simple urgency indicator without a custom widget.

### Progress Bar

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(8),
  child: LinearProgressIndicator(
    value: progress,
    backgroundColor: AppColors.getBorderColor(context).withValues(alpha: 0.4),
    valueColor: AlwaysStoppedAnimation<Color>(color),
    minHeight: 7,
  ),
),
```

**`ClipRRect`** — clips its child with rounded corners. `LinearProgressIndicator` doesn't support `borderRadius` natively, so wrapping with `ClipRRect` rounds the bar.

**`AlwaysStoppedAnimation<Color>(color)`** — a `ColorTween` wrapper that always returns a fixed color (doesn't animate between colors). Required by `valueColor` parameter, which expects an `Animation<Color>`.

**`minHeight: 7`** — default progress bar height is 4px. 7px makes it thicker and more visible.

---

## Summary Table

| Feature | `SubjectsViewWidget` | `ProjectsViewWidget` |
|---|---|---|
| Data source | `channelsProvider` | `projectsProvider` |
| Layout | `GridView` (2 or 3 columns) | `ListView` (vertical list) |
| Card navigation | `showModalBottomSheet` (SubjectHub) | `Navigator.push` (ProjectDetail) |
| Hover | Colored border + bg tint + glow | Same pattern |
| Color assignment | `index % palette.length` | Same |
| Empty state | Large icon + admin contact message | Prompt to create first project |
| Retry | `ref.invalidate(channelsProvider)` | `ref.invalidate(projectsProvider)` |
| Key patterns | `shrinkWrap` + `NeverScrollableScrollPhysics`, `childAspectRatio` | Overlapping avatars via `widthFactor`, `ClipRRect` progress bar |
