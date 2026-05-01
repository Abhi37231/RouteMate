import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/presentation/providers/auth_providers.dart';
import '../../auth/presentation/screens/edit_profile_screen.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/providers/update_provider.dart';
import '../../../core/widgets/update_dialog.dart';

/// Profile tab for user settings
class ProfileTab extends ConsumerWidget {
  const ProfileTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final themeMode = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: userAsync.when(
        data: (user) => ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Profile header
            Center(
              child: Column(
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.primaryBlue, width: 2),
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.darkCard,
                      backgroundImage: user?.photoURL != null 
                          ? NetworkImage(user!.photoURL!) 
                          : null,
                      child: user?.photoURL == null 
                          ? Text(
                              user?.email?.substring(0, 1).toUpperCase() ?? '?',
                              style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    user?.displayName ?? 'Traveler',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Account Section
            _buildSectionHeader('ACCOUNT'),
            _SettingsTile(
              icon: Icons.person_outline,
              title: 'Edit Profile',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                );
              },
            ),
            
            // Preferences Section
            const SizedBox(height: 16),
            _buildSectionHeader('PREFERENCES'),
            _SettingsTile(
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              trailing: Switch(
                value: true,
                onChanged: (val) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Notifications ${val ? 'enabled' : 'disabled'}')),
                  );
                },
                activeColor: AppColors.primaryBlue,
              ),
            ),
            _SettingsTile(
              icon: Icons.dark_mode_outlined,
              title: 'Dark Mode',
              trailing: Switch(
                value: themeMode == ThemeMode.dark,
                onChanged: (value) {
                  ref.read(themeProvider.notifier).toggleTheme();
                },
                activeColor: AppColors.primaryBlue,
              ),
            ),
            _SettingsTile(
              icon: Icons.language,
              title: 'Language',
              trailing: const Text('English', style: TextStyle(color: AppColors.primaryBlue)),
              onTap: () => _showLanguageDialog(context),
            ),
            
            // Support Section
            const SizedBox(height: 16),
            _buildSectionHeader('SUPPORT'),
            _SettingsTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: () => _showHelpDialog(context),
            ),
            _SettingsTile(
              icon: Icons.info_outline,
              title: 'About',
              onTap: () => _showAboutDialog(context),
            ),
            _SettingsTile(
              icon: Icons.system_update_outlined,
              title: 'Check for Updates',
              trailing: ref.watch(updateProvider).isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue),
                    )
                  : null,
              onTap: () async {
                await ref.read(updateProvider.notifier).checkForUpdates();
                final updateState = ref.read(updateProvider);
                
                if (context.mounted) {
                  if (updateState.hasUpdate) {
                    _showManualUpdateDialog(context, updateState);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('RouteMate is up to date!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
            ),
            
            const Divider(height: 48, color: Colors.white10),
            
            _SettingsTile(
              icon: Icons.logout,
              title: 'Sign Out',
              textColor: Colors.redAccent,
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign Out'),
                    content: const Text('Are you sure you want to sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign Out'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await ref.read(authStateProvider.notifier).signOut();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login',
                      (route) => false,
                    );
                  }
                }
              },
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.primaryBlue,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text('Select Language', style: TextStyle(color: Colors.white)),
        children: [
          _buildLanguageOption(context, 'English', isSelected: true),
          _buildLanguageOption(context, 'Spanish'),
          _buildLanguageOption(context, 'French'),
          _buildLanguageOption(context, 'German'),
          _buildLanguageOption(context, 'Hindi'),
        ],
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext context, String lang, {bool isSelected = false}) {
    return SimpleDialogOption(
      onPressed: () => Navigator.pop(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(lang, style: const TextStyle(color: Colors.white)),
          if (isSelected) const Icon(Icons.check, color: AppColors.primaryBlue, size: 20),
        ],
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        title: const Text('Help & Support', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Contact us at:', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('support@routemate.app', style: TextStyle(color: AppColors.primaryBlue, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('FAQ', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 8),
            Text('Visit our website for more help.', style: TextStyle(color: Colors.white54, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showManualUpdateDialog(BuildContext context, UpdateState state) {
    if (state.updateInfo == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: !state.isForceUpdate,
      builder: (context) => Consumer(
        builder: (context, ref, child) => UpdateDialog(
          version: state.updateInfo!.latestVersion,
          isForceUpdate: state.isForceUpdate,
          onUpdate: () => ref.read(updateProvider.notifier).launchUpdate(),
          onLater: () => Navigator.pop(context),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'RouteMate',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2024 RouteMate',
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? textColor;

  const _SettingsTile({
    required this.icon,
    required this.title,
    this.trailing,
    this.onTap,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      trailing:
          trailing ?? (onTap != null ? const Icon(Icons.chevron_right) : null),
      onTap: onTap,
    );
  }
}
