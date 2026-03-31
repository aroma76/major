import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth_provider.dart';
import '../../../../core/theme/app_colors.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _rollController = TextEditingController();
  final _dobController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscureDob = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _rollController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await ref.read(authProvider.notifier).login(
          _rollController.text.trim(),
          _dobController.text.trim(), // YYYY-MM-DD format
        );
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final error = authState.valueOrNull?.error;

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
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo / Title
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: AppColors.accentGradient,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.school_rounded,
                              color: Colors.white, size: 36),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'ADTU Collab',
                          style: GoogleFonts.outfit(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textHeading,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Jira for Students — Academic Workspace',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppColors.textBody,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Roll Number
                  _label('Roll Number'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _rollController,
                    style: const TextStyle(color: AppColors.textHeading),
                    decoration: _inputDecoration(
                      hint: 'e.g. BSC-IT-2022-001',
                      icon: Icons.badge_outlined,
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Enter your roll number' : null,
                  ),
                  const SizedBox(height: 20),

                  // DOB
                  _label('Date of Birth (Password)'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _dobController,
                    style: const TextStyle(color: AppColors.textHeading),
                    decoration: _inputDecoration(
                      hint: 'YYYY-MM-DD  e.g. 2003-05-14',
                      icon: Icons.calendar_today_outlined,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your date of birth';
                      final exp = RegExp(r'^\d{4}-\d{2}-\d{2}$');
                      if (!exp.hasMatch(v)) return 'Format must be YYYY-MM-DD';
                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💡 Your DOB in YYYY-MM-DD format is your default password.',
                    style: GoogleFonts.outfit(
                        fontSize: 11, color: AppColors.textBody),
                  ),
                  const SizedBox(height: 24),

                  // Error
                  if (error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3D1A1A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF9D2727)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline,
                              color: Color(0xFFFF6B6B), size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(error,
                                style: const TextStyle(
                                    color: Color(0xFFFF6B6B), fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Login Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ))
                          : Text('Sign In',
                              style: GoogleFonts.outfit(
                                  fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: 24),

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
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.textBody,
        ),
      );

  InputDecoration _inputDecoration(
          {required String hint, required IconData icon}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF484F58), fontSize: 13),
        prefixIcon: Icon(icon, color: AppColors.textBody, size: 18),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF30363D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
      );
}
