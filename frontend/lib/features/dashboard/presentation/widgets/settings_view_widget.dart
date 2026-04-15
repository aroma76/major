import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../features/auth/auth_provider.dart';

class SettingsViewWidget extends ConsumerWidget {
  const SettingsViewWidget({super.key});

  void _showEditProfile(BuildContext context, WidgetRef ref) {
    final authState = ref.read(authProvider).value;
    final nameCtrl = TextEditingController(text: authState?.userName ?? '');
    final dobCtrl  = TextEditingController(
      text: authState?.user?['dob'] != null
          ? (authState!.user!['dob'] as String).substring(0, 10)
          : '',
    );
    final email      = authState?.user?['email']       as String? ?? '';
    final rollNumber = authState?.user?['roll_number']  as String? ?? '';
    bool isLoading = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.getSurfaceColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Edit Profile',
              style: TextStyle(color: AppColors.getHeadingColor(context), fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (errorMsg != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ),
                _buildDialogField(context, 'Full Name', 'e.g. Aryan Sharma', controller: nameCtrl),
                const SizedBox(height: 14),
                _buildDialogField(context, 'Date of Birth', 'YYYY-MM-DD', controller: dobCtrl,
                    hint: 'e.g. 2003-05-26'),
                const SizedBox(height: 14),
                _buildReadOnlyField(context, 'Email Address', email),
                const SizedBox(height: 14),
                if (rollNumber.isNotEmpty) _buildReadOnlyField(context, 'Roll Number', rollNumber),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setState(() { isLoading = true; errorMsg = null; });
                      try {
                        await ref.read(authProvider.notifier).updateProfile(
                          name: nameCtrl.text.trim(),
                          dob:  dobCtrl.text.trim(),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('Profile updated!', style: TextStyle(color: Colors.white)),
                            backgroundColor: Colors.green,
                          ));
                        }
                      } catch (e) {
                        setState(() { isLoading = false; errorMsg = 'Failed to update. Please try again.'; });
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              child: isLoading
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePassword(BuildContext context, WidgetRef ref) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    bool isLoading = false;
    String? errorMsg;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.getSurfaceColor(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text('Change Password', style: TextStyle(color: AppColors.getHeadingColor(context), fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (errorMsg != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Text(errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                ),
              _buildDialogField(context, 'Current Password', '••••••••', controller: currentController, obscure: true),
              const SizedBox(height: 16),
              _buildDialogField(context, 'New Password', '', controller: newController, obscure: true),
              const SizedBox(height: 16),
              _buildDialogField(context, 'Confirm New Password', '', controller: confirmController, obscure: true),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: isLoading ? null : () async {
                if (newController.text != confirmController.text) {
                  setState(() => errorMsg = 'New passwords do not match');
                  return;
                }
                if (newController.text.length < 6) {
                  setState(() => errorMsg = 'Password must be at least 6 characters');
                  return;
                }
                setState(() { errorMsg = null; isLoading = true; });
                try {
                  await ref.read(authProvider.notifier).changePassword(
                    currentController.text,
                    newController.text,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password updated successfully!', style: TextStyle(color: Colors.white)), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  setState(() { 
                    isLoading = false; 
                    errorMsg = 'Failed. Check current password.';
                  });
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
              child: isLoading 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                  : const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Logout', style: TextStyle(color: AppColors.getHeadingColor(context), fontWeight: FontWeight.bold)),
        content: Text('Are you sure you want to sign out?', style: TextStyle(color: AppColors.getBodyColor(context))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authProvider.notifier).logout();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(BuildContext context, String label, String placeholder,
      {bool obscure = false, TextEditingController? controller, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.getHeadingColor(context), fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: TextStyle(color: AppColors.getHeadingColor(context), fontSize: 14),
          decoration: InputDecoration(
            hintText: hint ?? placeholder,
            hintStyle: TextStyle(color: AppColors.getBodyColor(context).withOpacity(0.5)),
            filled: true,
            fillColor: AppColors.getBackgroundColor(context),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.getHeadingColor(context), fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.getBorderColor(context).withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(value, style: TextStyle(color: AppColors.getBodyColor(context), fontSize: 14)),
              ),
              Icon(Icons.lock_outline, size: 14, color: AppColors.getBodyColor(context).withOpacity(0.4)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notificationsEnabled = ref.watch(isNotificationsEnabledProvider);
    final emailSummaryEnabled = ref.watch(isEmailSummaryEnabledProvider);
    final authState = ref.watch(authProvider).value;
    final userName = authState?.userName ?? 'Student';
    final userEmail = authState?.user?['email'] as String? ?? '';
    final userRole = authState?.userRole ?? 'student';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: AppColors.getHeadingColor(context)),
            ),
            const SizedBox(height: 8),
            Text(
              'Manage your preferences and account settings',
              style: TextStyle(color: AppColors.getBodyColor(context), fontSize: 16),
            ),
            const SizedBox(height: 48),
            
            // Profile Section
            _buildSectionHeader(context, 'Account Profile'),
            _buildSettingCard(
              context,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.accent.withOpacity(0.15),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'S',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.accent),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getHeadingColor(context)),
                        ),
                        Text(
                          userRole[0].toUpperCase() + userRole.substring(1),
                          style: TextStyle(fontSize: 14, color: AppColors.getBodyColor(context)),
                        ),
                        Text(
                          userEmail,
                          style: const TextStyle(fontSize: 14, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _showEditProfile(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.getBorderColor(context),
                      foregroundColor: AppColors.getHeadingColor(context),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Edit Profile'),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Preferences Section
            _buildSectionHeader(context, 'Preferences'),
            _buildSettingCard(
              context,
              child: Column(
                children: [
                  _buildToggleTile(
                    context,
                    'Dark Mode',
                    'Switch between dark and light themes',
                    themeMode == ThemeMode.dark,
                    (val) => ref.read(themeModeProvider.notifier).toggle(),
                    icon: themeMode == ThemeMode.dark ? FeatherIcons.moon : FeatherIcons.sun,
                  ),
                  Divider(color: AppColors.getBorderColor(context), height: 1),
                  _buildToggleTile(
                    context,
                    'Push Notifications',
                    'Receive alerts for deadlines and messages',
                    notificationsEnabled,
                    (val) => ref.read(isNotificationsEnabledProvider.notifier).set(val),
                    icon: FeatherIcons.bell,
                  ),
                  Divider(color: AppColors.getBorderColor(context), height: 1),
                  _buildToggleTile(
                    context,
                    'Email Summary',
                    'Get weekly progress reports via email',
                    emailSummaryEnabled,
                    (val) => ref.read(isEmailSummaryEnabledProvider.notifier).set(val),
                    icon: FeatherIcons.mail,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Security Section
            _buildSectionHeader(context, 'Security'),
            _buildSettingCard(
              context,
              child: Column(
                children: [
                  _buildActionTile(
                    context,
                    'Change Password',
                    'Update your password for better security',
                    Icons.lock_outline,
                    () => _showChangePassword(context, ref),
                  ),
                  Divider(color: AppColors.getBorderColor(context), height: 1),
                  _buildActionTile(
                    context,
                    'Logout',
                    'Sign out of your account on this device',
                    Icons.logout_rounded,
                    () => _showLogoutConfirmation(context, ref),
                    isDanger: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: AppColors.getBodyColor(context).withOpacity(0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingCard(BuildContext context, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.getSurfaceColor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorderColor(context), width: 1),
        boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: child,
    );
  }

  Widget _buildToggleTile(BuildContext context, String title, String subtitle, bool value, ValueChanged<bool> onChanged, {required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.getBorderColor(context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.getHeadingColor(context), size: 20),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.getHeadingColor(context))),
                Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.getBodyColor(context))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.accent,
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap, {bool isDanger = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isDanger ? Colors.red : AppColors.getBorderColor(context)).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isDanger ? Colors.red : AppColors.getHeadingColor(context), size: 20),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDanger ? Colors.red : AppColors.getHeadingColor(context))),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.getBodyColor(context))),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.getBodyColor(context).withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}
