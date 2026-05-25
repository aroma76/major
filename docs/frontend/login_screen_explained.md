# Word-by-Word Deep Dive: `login_screen_explained.md`

> Covers `login_screen.dart` — the app's entry screen. Has two themed login cards (Student = blue/cyan, Faculty = purple/violet) that toggle with a fade+scale animation. Features form validation, a `CustomPainter` network background, and a shared `_field()` helper function that renders styled `TextFormField` widgets.

---

## Before Reading — `TickerProviderStateMixin` vs `SingleTickerProviderStateMixin`

Throughout the codebase we've seen `SingleTickerProviderStateMixin` — for ONE `AnimationController`.

Here, `LoginScreen` uses **`TickerProviderStateMixin`** — for potentially MULTIPLE controllers. The login screen only uses one `_stageCtrl`, but using `TickerProviderStateMixin` is also valid and is sometimes chosen by preference.

---

## Lines 22–68 — State Setup

```dart
class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  bool _isStudent = true;

  final _studentIdCtrl  = TextEditingController();
  final _studentPwdCtrl = TextEditingController();
  final _facultyIdCtrl  = TextEditingController();
  final _facultyPwdCtrl = TextEditingController();
  final _formKeyStudent = GlobalKey<FormState>();
  final _formKeyFaculty = GlobalKey<FormState>();

  bool _obscureStudent = true;
  bool _obscureFaculty = true;
```

**Two sets of controllers** — one for student, one for faculty. Both cards exist in the widget tree simultaneously (but only one is shown via `if/else`). Keeping separate controllers means switching roles doesn't clear the other form.

**`GlobalKey<FormState>`** — each `Form` widget gets its own key. Used to call `.validate()`:
```dart
if (!formKey.currentState!.validate()) return;
```
**`.validate()`** — triggers all `validator:` callbacks in the form. If any returns a non-null string, that field shows its error and `.validate()` returns `false`.

### Toggle Role Animation

```dart
void _toggleRole() {
  _stageCtrl.reverse().then((_) {
    setState(() => _isStudent = !_isStudent);
    _stageCtrl.forward();
  });
}
```

**`_stageCtrl.reverse()`** — plays the animation backward (fade out + scale down).

**`.then((_) { ... })`** — runs AFTER the reverse completes. `then` on a `Future` (here `reverse()` returns `TickerFuture` which extends `Future`).

Inside `.then`:
1. `setState(() => _isStudent = !_isStudent)` — flip the role flag
2. `_stageCtrl.forward()` — play animation forward again (fade in + scale up)

**Effect:** Student card fades out → Faculty card fades in. Seamless role switch.

---

## Lines 82–165 — Background Layers

### Radial Gradient Background

```dart
Container(
  decoration: BoxDecoration(
    color: bgColor,
    gradient: RadialGradient(
      center: const Alignment(0, -0.4),
      radius: 1.2,
      colors: [fadeColor, bgColor],
      stops: const [0.0, 0.8],
    ),
  ),
),
```

**`RadialGradient`** — circular gradient radiating from a center point.

**`center: Alignment(0, -0.4)`** — `Alignment(x, y)` where both axes range from -1 to 1. `(0, -0.4)` = horizontal center, 40% above vertical center. The glow radiates from the top-center of the screen.

**`stops: const [0.0, 0.8]`** — color transition: `fadeColor` at 0% → `bgColor` at 80% → `bgColor` at 100% (solid background at edges). The glow fades out before reaching the edges.

**`fadeColor`** — `Color(0xFF00CFFF).withValues(alpha: 0.12)` on dark, `0.08` on light. Cyan glow, barely visible but adds depth.

### Network Background Painter

```dart
const Positioned.fill(child: CustomPaint(painter: _NetPainter()))
```

**`Positioned.fill`** — inside a `Stack`, fills the entire stack area.

**`CustomPaint(painter: _NetPainter())`** — calls `_NetPainter.paint(canvas, size)` to draw directly on the canvas.

---

## Lines 704–810 — `_NetPainter` — Custom Canvas Drawing

```dart
class _NetPainter extends CustomPainter {
  const _NetPainter();

  static const _nodes = [
    [0.05, 0.08], [0.22, 0.03], [0.42, 0.10], ...
  ];

  static const _edges = [
    [0, 1], [1, 2], [2, 3], ...
  ];

  static const _lineColor = Color(0x1200CFFF); // ~7% opacity
  static const _nodeColor = Color(0x2200CFFF); // ~13% opacity
  static const _dotColor  = Color(0x3300CFFF); // ~20% opacity
```

**Node positions as fractions** — `[0.05, 0.08]` means 5% from left, 8% from top. Multiplied by `size.width` / `size.height` to get actual pixels. Screen-size agnostic — the network adapts to any screen.

**Edges as index pairs** — `[0, 1]` connects node 0 to node 1. Using indices avoids duplicating coordinates.

**Hex opacity:** `0x12` = 18 decimal = ~7%, `0x22` = 34 = ~13%, `0x33` = 51 = ~20%. Very subtle neon cyan network — visible but not distracting.

### Quadratic Bézier Curves

```dart
final mx = (a.dx + b.dx) / 2;   // midpoint x
final my = (a.dy + b.dy) / 2;   // midpoint y
final ex = b.dx - a.dx;          // edge vector x
final ey = b.dy - a.dy;          // edge vector y
final edgeLen = dart_math.sqrt(ex * ex + ey * ey);

const bend = 0.18;
// Perpendicular unit vector × 18% of edge length
final cx = mx + (-ey / edgeLen) * bend * edgeLen;
final cy = my + (ex / edgeLen) * bend * edgeLen;

final path = Path()
  ..moveTo(a.dx, a.dy)
  ..quadraticBezierTo(cx, cy, b.dx, b.dy);
canvas.drawPath(path, linePaint);
```

**Quadratic Bézier** — a curve defined by 3 points: start (`a`), control (`cx, cy`), end (`b`). The curve is pulled toward the control point without reaching it.

**Perpendicular offset:** The control point is displaced perpendicular to the edge direction. This makes each edge curve gently.

- `(-ey, ex)` — perpendicular to `(ex, ey)` vector (rotate 90°)
- Divided by `edgeLen` → unit vector
- Multiplied by `bend * edgeLen` → 18% of edge length displacement

**`dart_math.sqrt`** — Dart's `math.sqrt()` from `dart:math`. Imported as `dart_math` to avoid name conflict: `import 'dart:math' as dart_math`.

---

## Lines 223–394 — `_StudentLoginCard`

```dart
static const _blue  = Color(0xFF1E88E5);
static const _blueB = Color(0xFF1565C0);
```

Student card uses blue theme. The banner gradient is `[_blueB (dark blue), _blue, Color(0xFF26C6DA) (cyan)]`.

### Form Validation Fields

```dart
validator: (v) => (v == null || v.trim().isEmpty)
    ? 'Enter your Roll Number or Email'
    : null,
```

**`validator`** — the form calls this on every field when `.validate()` is triggered. Returns:
- `null` → field is valid
- `String` → field is invalid, shows this as error text below the field

**`v?.trim().isEmpty`** — `v` is the current field text. `trim()` removes whitespace. If the text is just spaces, it's still considered empty.

---

## Lines 636–694 — Shared `_field()` Helper

```dart
Widget _field({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  required Color accent,
  required BuildContext context,
  bool obscure = false,
  VoidCallback? onToggle,
  String? Function(String?)? validator,
}) => TextFormField(
  controller: controller,
  obscureText: obscure,
  validator: validator,
  decoration: InputDecoration(
    prefixIcon: Icon(icon, ...),
    filled: true,
    fillColor: AppColors.getBackgroundColor(context),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AppColors.getBorderColor(context))),
    enabledBorder: OutlineInputBorder(...),
    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: accent, width: 1.5)),
    errorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFF6B6B))),
    focusedErrorBorder: OutlineInputBorder(borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5)),
    suffixIcon: onToggle != null ? IconButton(...) : null,
  ),
);
```

**Four border states:**
- `border` — default (unfocused, valid)
- `enabledBorder` — same as border (both gray)
- `focusedBorder` — accent-colored when tapped (blue for student, purple for faculty)
- `errorBorder` / `focusedErrorBorder` — red when validation fails

**`String? Function(String?)?`** — the validator type. A function that takes a `String?` and returns a `String?`. The outer `?` makes the entire validator optional.

**Password visibility toggle:**
```dart
suffixIcon: onToggle != null
    ? IconButton(
        icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined),
        onPressed: onToggle,
      )
    : null,
```

Only shown when `onToggle` is provided (password fields). Tapping cycles between `visibility_off` (password hidden) and `visibility` (password visible).

---

## Summary: Login Screen Architecture

```
LoginScreen (ConsumerStatefulWidget)
  └─ Scaffold
     └─ Container (RadialGradient background)
        └─ Stack
           ├─ Positioned.fill → _NetPainter (decorative network)
           └─ FadeTransition + ScaleTransition (stage animation)
              └─ SingleChildScrollView → ConstrainedBox(maxWidth: 460)
                 ├─ _Logo (university branding)
                 ├─ if _isStudent → _StudentLoginCard (blue theme)
                 │   └─ Form(key: _formKeyStudent)
                 │      ├─ _field() (roll number)
                 │      ├─ _field() (password, obscure)
                 │      ├─ _errorBanner (if auth error)
                 │      ├─ ElevatedButton (Sign In)
                 │      └─ TextButton (switch to Faculty)
                 └─ else → _FacultyLoginCard (purple theme)
                     └─ Form(key: _formKeyFaculty)
                        ├─ Info box (IT support note)
                        ├─ _field() (email)
                        ├─ _field() (password, obscure)
                        ├─ _errorBanner (if auth error)
                        ├─ ElevatedButton (Sign In)
                        └─ TextButton (switch to Student)
```

| Feature | Detail |
|---|---|
| Role toggle | `reverse()` then `setState` then `forward()` |
| Student theme | Blue `#1E88E5` + Cyan `#26C6DA` |
| Faculty theme | Purple `#7B1FA2` + Light Purple `#AB47BC` |
| Background | `RadialGradient` + `_NetPainter` Bézier network |
| Form validation | `GlobalKey<FormState>.validate()` |
| Password visibility | `obscureText` toggle via `setState` |
| Error display | `_errorBanner()` only when `authState.value?.error != null` |
