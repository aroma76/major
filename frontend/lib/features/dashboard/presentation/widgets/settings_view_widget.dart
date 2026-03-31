import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../providers/task_provider.dart';

class SettingsViewWidget extends ConsumerWidget {
  const SettingsViewWidget({super.key});

  void _showEditProfile(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Edit Profile', style: TextStyle(color: AppColors.getHeadingColor(context), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(context, 'Full Name', 'John Doe'),
            const SizedBox(height: 16),
            _buildDialogField(context, 'Bio', 'Software Engineering Student'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            child: const Text('Save Changes'),
          ),
        ],
      ),
    );
  }

  void _showChangePassword(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.getSurfaceColor(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Change Password', style: TextStyle(color: AppColors.getHeadingColor(context), fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDialogField(context, 'Current Password', '••••••••', obscure: true),
            const SizedBox(height: 16),
            _buildDialogField(context, 'New Password', '', obscure: true),
            const SizedBox(height: 16),
            _buildDialogField(context, 'Confirm New Password', '', obscure: true),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
            child: const Text('Update Password'),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
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
            onPressed: () {
              // Redirection to Login could be handled here or by a provider
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out successfully')));
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }

  Widget _buildDialogField(BuildContext context, String label, String hint, {bool obscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: AppColors.getHeadingColor(context), fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          obscureText: obscure,
          style: TextStyle(color: AppColors.getHeadingColor(context), fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final notificationsEnabled = ref.watch(isNotificationsEnabledProvider);
    final emailSummaryEnabled = ref.watch(isEmailSummaryEnabledProvider);

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
                  const CircleAvatar(
                    radius: 32,
                    backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=11'),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'John Doe',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.getHeadingColor(context)),
                        ),
                        Text(
                          'Software Engineering Student',
                          style: TextStyle(fontSize: 14, color: AppColors.getBodyColor(context)),
                        ),
                        Text(
                          'john.doe@university.edu',
                          style: const TextStyle(fontSize: 14, color: AppColors.accent),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _showEditProfile(context),
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
                    () => _showChangePassword(context),
                  ),
                  Divider(color: AppColors.getBorderColor(context), height: 1),
                  _buildActionTile(
                    context,
                    'Logout',
                    'Sign out of your account on this device',
                    Icons.logout_rounded,
                    () => _showLogoutConfirmation(context),
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
