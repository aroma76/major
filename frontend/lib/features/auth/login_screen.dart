import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'auth_provider.dart';
import '../../../../core/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _identifierCtrl = TextEditingController(); // roll no or email
  final _passwordCtrl   = TextEditingController();
  final _formKey        = GlobalKey<FormState>();

  bool _isLoading      = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await ref.read(authProvider.notifier).login(
          _identifierCtrl.text.trim(),
          _passwordCtrl.text.trim(),
        );
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final error     = authState.value?.error;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize     : MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Logo ─────────────────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          'assets/images/adtu_logo.svg',
                          height: 80,
                          fit   : BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ADTU Collab',
                          style: GoogleFonts.outfit(
                            fontSize  : 28,
                            fontWeight: FontWeight.bold,
                            color     : AppColors.textHeading,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Academic Workspace — Assam downtown University',
                          style: GoogleFonts.outfit(
                              fontSize: 12, color: AppColors.textBody),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Identifier (Roll No or Email) ─────────────────────────
                  _label('Roll Number or Email'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller : _identifierCtrl,
                    style      : const TextStyle(color: AppColors.textHeading),
                    keyboardType: TextInputType.emailAddress,
                    decoration : _inputDeco(
                      hint: 'e.g.  21CS001  or  john@adtu.in',
                      icon: Icons.person_outline,
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Enter your Roll Number or Email'
                        : null,
                  ),
                  const SizedBox(height: 20),

                  // ── Password ──────────────────────────────────────────────
                  _label('Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller   : _passwordCtrl,
                    obscureText  : _obscurePassword,
                    style        : const TextStyle(color: AppColors.textHeading),
                    decoration   : _inputDeco(
                      hint: 'Enter your password',
                      icon: Icons.lock_outline,
                    ).copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textBody,
                          size : 18,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your password';
                      if (v.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💡 First time? Your default password is your date of birth: YYYY-MM-DD',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.textBody),
                  ),
                  const SizedBox(height: 24),

                  // ── Error ─────────────────────────────────────────────────
                  if (error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color       : const Color(0xFF3D1A1A),
                        borderRadius: BorderRadius.circular(8),
                        border      : Border.all(color: const Color(0xFF9D2727)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFFF6B6B), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              error,
                              style: const TextStyle(
                                  color: Color(0xFFFF6B6B), fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Login Button ──────────────────────────────────────────
                  SizedBox(
                    width : double.infinity,
                    height: 50,
                    child : ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width : 20, height: 20,
                              child : CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              'Sign In',
                              style: GoogleFonts.outfit(
                                  fontSize  : 16,
                                  fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Center(
                    child: Text(
                      'Assam down town University, Guwahati',
                      style: GoogleFonts.outfit(
                          fontSize: 12, color: AppColors.textBody),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: GoogleFonts.outfit(
          fontSize  : 13,
          fontWeight: FontWeight.w500,
          color     : AppColors.textBody,
        ),
      );

  InputDecoration _inputDeco({required String hint, required IconData icon}) =>
      InputDecoration(
        hintText  : hint,
        hintStyle : const TextStyle(color: Color(0xFF484F58), fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textBody, size: 18),
        filled    : true,
        fillColor : AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide  : const BorderSide(color: Color(0xFF30363D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide  : const BorderSide(color: Color(0xFF30363D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide  : const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide  : const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide  : const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
        ),
      );
}
