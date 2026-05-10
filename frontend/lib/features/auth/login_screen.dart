import 'dart:math' as dart_math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'auth_provider.dart';
import '../../../../core/theme/app_colors.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Login Screen — 3 stages:
//   stage 0  → Role selection landing
//   stage 1  → Student login form  (blue/cyan theme)
//   stage 2  → Faculty login form  (purple/violet theme)
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  bool _isStudent = true;

  final _studentIdCtrl = TextEditingController();
  final _studentPwdCtrl = TextEditingController();
  final _facultyIdCtrl = TextEditingController();
  final _facultyPwdCtrl = TextEditingController();
  final _formKeyStudent = GlobalKey<FormState>();
  final _formKeyFaculty = GlobalKey<FormState>();

  bool _obscureStudent = true;
  bool _obscureFaculty = true;

  late AnimationController _stageCtrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _stageCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _stageCtrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.94, end: 1.0).animate(
        CurvedAnimation(parent: _stageCtrl, curve: Curves.easeOutCubic));
    _stageCtrl.forward();
  }

  @override
  void dispose() {
    _stageCtrl.dispose();
    _studentIdCtrl.dispose();
    _studentPwdCtrl.dispose();
    _facultyIdCtrl.dispose();
    _facultyPwdCtrl.dispose();
    super.dispose();
  }

  void _toggleRole() {
    _stageCtrl.reverse().then((_) {
      setState(() => _isStudent = !_isStudent);
      _stageCtrl.forward();
    });
  }

  Future<void> _login(bool isStudent) async {
    final formKey = isStudent ? _formKeyStudent : _formKeyFaculty;
    if (!formKey.currentState!.validate()) return;
    final id =
        isStudent ? _studentIdCtrl.text.trim() : _facultyIdCtrl.text.trim();
    final pwd =
        isStudent ? _studentPwdCtrl.text.trim() : _facultyPwdCtrl.text.trim();
    await ref.read(authProvider.notifier).login(id, pwd);
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.getBackgroundColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Smooth, glowing cyan gradient fade radiating from the top center
    final fadeColor = isDark
        ? const Color(0xFF00CFFF).withValues(alpha: 0.12)
        : const Color(0xFF00CFFF).withValues(alpha: 0.08);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: bgColor,
          gradient: RadialGradient(
            center: const Alignment(0, -0.4),
            radius: 1.2,
            colors: [fadeColor, bgColor],
            stops: const [0.0, 0.8],
          ),
        ),
        child: Stack(
          children: [
            // ── Static Curved Network Background ──
            const Positioned.fill(child: CustomPaint(painter: _NetPainter())),

            // ── Main Content ──
            FadeTransition(
              opacity: _fadeAnim,
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Logo (always visible) ────────────────────────────
                          _Logo(),
                          const SizedBox(height: 36),
                          // ── Stage content ────────────────────────────────────
                          if (_isStudent)
                            _StudentLoginCard(
                              idCtrl: _studentIdCtrl,
                              pwdCtrl: _studentPwdCtrl,
                              formKey: _formKeyStudent,
                              obscure: _obscureStudent,
                              onToggleObscure: () => setState(
                                  () => _obscureStudent = !_obscureStudent),
                              onLogin: () => _login(true),
                              onToggleRole: _toggleRole,
                              ref: ref,
                            )
                          else
                            _FacultyLoginCard(
                              idCtrl: _facultyIdCtrl,
                              pwdCtrl: _facultyPwdCtrl,
                              formKey: _formKeyFaculty,
                              obscure: _obscureFaculty,
                              onToggleObscure: () => setState(
                                  () => _obscureFaculty = !_obscureFaculty),
                              onLogin: () => _login(false),
                              onToggleRole: _toggleRole,
                              ref: ref,
                            ),
                          const SizedBox(height: 24),
                          Text(
                            'Assam down town University, Guwahati',
                            style: GoogleFonts.outfit(
                                fontSize: 12, color: AppColors.textBody),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Logo
// ─────────────────────────────────────────────────────────────────────────────

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/images/adtu_logo.png',
            height: 72, fit: BoxFit.contain),
        const SizedBox(height: 14),
        Text(
          'ADTU Collab',
          style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.textHeading),
        ),
        const SizedBox(height: 4),
        Text(
          'Academic Workspace — Assam downtown University',
          style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textBody),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage 1 — Student Login
// ─────────────────────────────────────────────────────────────────────────────

class _StudentLoginCard extends StatelessWidget {
  final TextEditingController idCtrl;
  final TextEditingController pwdCtrl;
  final GlobalKey<FormState> formKey;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;
  final VoidCallback onToggleRole;
  final WidgetRef ref;

  const _StudentLoginCard({
    required this.idCtrl,
    required this.pwdCtrl,
    required this.formKey,
    required this.obscure,
    required this.onToggleObscure,
    required this.onLogin,
    required this.onToggleRole,
    required this.ref,
  });

  static const _blue = Color(0xFF1E88E5);
  static const _blueB = Color(0xFF1565C0);

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final error = authState.value?.error;
    final isLoading = ref.watch(authProvider.notifier).isLoggingIn;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _blue.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _blue.withValues(alpha: 0.15),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Banner ────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_blueB, _blue, Color(0xFF26C6DA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                const Icon(Icons.school_rounded, color: Colors.white, size: 26),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Student Login',
                        style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text('Enter your credentials to continue',
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ],
            ),
          ),

          // ── Form ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Roll Number or Email', AppColors.textBody),
                  const SizedBox(height: 8),
                  _field(
                    controller: idCtrl,
                    hint: 'e.g.  21CS001  or  aarav@adtu.in',
                    icon: Icons.person_outline,
                    accent: _blue,
                    context: context,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your Roll Number or Email'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  _label('Password', AppColors.textBody),
                  const SizedBox(height: 8),
                  _field(
                    controller: pwdCtrl,
                    hint: 'Enter your password',
                    icon: Icons.lock_outline,
                    accent: _blue,
                    obscure: obscure,
                    context: context,
                    onToggle: onToggleObscure,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your password';
                      if (v.length < 6) return 'At least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline,
                          size: 13, color: Color(0xFF26C6DA)),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          'First time? Default password is your date of birth: YYYY-MM-DD',
                          style: GoogleFonts.outfit(
                              fontSize: 11, color: AppColors.textBody),
                        ),
                      ),
                    ],
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    _errorBanner(error),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : onLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        shadowColor: _blue.withValues(alpha: 0.5),
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.login_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text('Sign In as Student',
                                    style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: onToggleRole,
                      style: TextButton.styleFrom(
                        foregroundColor: _blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Are you a Faculty member? Login here',
                          style: GoogleFonts.outfit(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Stage 2 — Faculty Login
// ─────────────────────────────────────────────────────────────────────────────

class _FacultyLoginCard extends StatelessWidget {
  final TextEditingController idCtrl;
  final TextEditingController pwdCtrl;
  final GlobalKey<FormState> formKey;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onLogin;
  final VoidCallback onToggleRole;
  final WidgetRef ref;

  const _FacultyLoginCard({
    required this.idCtrl,
    required this.pwdCtrl,
    required this.formKey,
    required this.obscure,
    required this.onToggleObscure,
    required this.onLogin,
    required this.onToggleRole,
    required this.ref,
  });

  static const _purple = Color(0xFF7B1FA2);
  static const _purpleL = Color(0xFFAB47BC);

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final error = authState.value?.error;
    final isLoading = ref.watch(authProvider.notifier).isLoggingIn;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _purple.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _purple.withValues(alpha: 0.2),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header Banner ────────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF4A148C), _purple, _purpleL],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                const Icon(Icons.badge_rounded, color: Colors.white, size: 26),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Faculty Login',
                        style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    Text('Institutional email required',
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8))),
                  ],
                ),
              ],
            ),
          ),

          // ── Form ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Faculty info box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _purple.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: _purple.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: _purpleL, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Faculty accounts are provisioned by the admin. Contact IT support if you need access.',
                            style: GoogleFonts.outfit(
                                fontSize: 11, color: AppColors.textBody),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _label('Institutional Email', AppColors.textBody),
                  const SizedBox(height: 8),
                  _field(
                    controller: idCtrl,
                    hint: 'e.g.  name@adtu.in',
                    icon: Icons.alternate_email_rounded,
                    accent: _purple,
                    context: context,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty)
                        return 'Enter your email';
                      if (!v.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 18),
                  _label('Password', AppColors.textBody),
                  const SizedBox(height: 8),
                  _field(
                    controller: pwdCtrl,
                    hint: 'Enter your password',
                    icon: Icons.lock_outline,
                    accent: _purple,
                    obscure: obscure,
                    context: context,
                    onToggle: onToggleObscure,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your password';
                      if (v.length < 6) return 'At least 6 characters';
                      return null;
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 14),
                    _errorBanner(error),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : onLogin,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        shadowColor: _purple.withValues(alpha: 0.5),
                        elevation: 6,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.badge_rounded, size: 18),
                                const SizedBox(width: 8),
                                Text('Sign In as Faculty',
                                    style: GoogleFonts.outfit(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: onToggleRole,
                      style: TextButton.styleFrom(
                        foregroundColor: _purple,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('Are you a Student? Login here',
                          style: GoogleFonts.outfit(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

Widget _label(String text, Color color) => Text(
      text,
      style: GoogleFonts.outfit(
          fontSize: 13, fontWeight: FontWeight.w600, color: color),
    );

Widget _errorBanner(String error) => Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3D1A1A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF9D2727)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(error,
                style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13)),
          ),
        ],
      ),
    );

Widget _field({
  required TextEditingController controller,
  required String hint,
  required IconData icon,
  required Color accent,
  required BuildContext context,
  bool obscure = false,
  VoidCallback? onToggle,
  String? Function(String?)? validator,
}) =>
    TextFormField(
      controller: controller,
      obscureText: obscure,
      validator: validator,
      style: TextStyle(color: AppColors.getHeadingColor(context)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: AppColors.getBodyColor(context), fontSize: 13),
        prefixIcon:
            Icon(icon, color: AppColors.getBodyColor(context), size: 18),
        filled: true,
        fillColor: AppColors.getBackgroundColor(context),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.getBorderColor(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.getBorderColor(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
        ),
        suffixIcon: onToggle != null
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: AppColors.getBodyColor(context),
                  size: 18,
                ),
                onPressed: onToggle,
              )
            : null,
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Animated Flowing Network Background
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// Static Curved Network Background
// ─────────────────────────────────────────────────────────────────────────────

class _NetPainter extends CustomPainter {
  const _NetPainter();

  // Node positions as fractions [x, y] of screen size
  static const _nodes = [
    [0.05, 0.08],
    [0.22, 0.03],
    [0.42, 0.10],
    [0.63, 0.05],
    [0.80, 0.12],
    [0.96, 0.04],
    [0.10, 0.28],
    [0.30, 0.22],
    [0.50, 0.32],
    [0.70, 0.25],
    [0.90, 0.30],
    [0.04, 0.50],
    [0.24, 0.46],
    [0.44, 0.54],
    [0.64, 0.48],
    [0.84, 0.52],
    [0.97, 0.44],
    [0.12, 0.70],
    [0.33, 0.67],
    [0.53, 0.73],
    [0.73, 0.66],
    [0.90, 0.72],
    [0.05, 0.90],
    [0.26, 0.94],
    [0.46, 0.87],
    [0.66, 0.92],
    [0.86, 0.88],
    [0.97, 0.95],
  ];

  // Edge pairs
  static const _edges = [
    [0, 1], [1, 2], [2, 3], [3, 4], [4, 5],
    [0, 6], [1, 7], [2, 8], [3, 9], [4, 10], [5, 10],
    [6, 7], [7, 8], [8, 9], [9, 10],
    [6, 11], [7, 12], [8, 13], [9, 14], [10, 15], [10, 16],
    [11, 12], [12, 13], [13, 14], [14, 15], [15, 16],
    [11, 17], [12, 18], [13, 19], [14, 20], [15, 21],
    [17, 18], [18, 19], [19, 20], [20, 21],
    [17, 22], [18, 23], [19, 24], [20, 25], [21, 26], [21, 27],
    [22, 23], [23, 24], [24, 25], [25, 26], [26, 27],
    // a few long-range diagonals for depth
    [1, 8], [3, 9], [5, 15], [7, 13], [9, 19], [15, 25],
  ];

  // Low-opacity neon cyan
  static const _lineColor = Color(0x1200CFFF); // ~7% opacity
  static const _nodeColor = Color(0x2200CFFF); // ~13% opacity
  static const _dotColor = Color(0x3300CFFF); // ~20% opacity

  @override
  void paint(Canvas canvas, Size size) {
    // Map fractional positions → real pixel offsets
    final pts = _nodes
        .map((n) => Offset(n[0] * size.width, n[1] * size.height))
        .toList();

    final linePaint = Paint()
      ..color = _lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw curved edges using quadratic Bézier
    for (final e in _edges) {
      final a = pts[e[0]];
      final b = pts[e[1]];

      // Control point: perpendicular offset at midpoint for a gentle bend
      final mx = (a.dx + b.dx) / 2;
      final my = (a.dy + b.dy) / 2;
      final ex = b.dx - a.dx; // edge vector
      final ey = b.dy - a.dy;
      final edgeLen =
          (ex * ex + ey * ey) < 1 ? 1.0 : dart_math.sqrt(ex * ex + ey * ey);
      // Perpendicular unit vector scaled to 18% of edge length for gentle bend
      const bend = 0.18;
      final cx = mx + (-ey / edgeLen) * bend * edgeLen;
      final cy = my + (ex / edgeLen) * bend * edgeLen;

      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(cx, cy, b.dx, b.dy);
      canvas.drawPath(path, linePaint);
    }

    // Draw nodes: subtle halo + tiny dot
    final haloPaint = Paint()
      ..color = _nodeColor
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final dotPaint = Paint()..color = _dotColor;

    for (final p in pts) {
      canvas.drawCircle(p, 6, haloPaint);
      canvas.drawCircle(p, 2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
