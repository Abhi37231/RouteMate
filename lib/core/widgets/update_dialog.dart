import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class UpdateDialog extends StatelessWidget {
  final String version;
  final bool isForceUpdate;
  final VoidCallback onUpdate;
  final VoidCallback? onLater;

  const UpdateDialog({
    Key? key,
    required this.version,
    required this.isForceUpdate,
    required this.onUpdate,
    this.onLater,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !isForceUpdate,
      child: AlertDialog(
        backgroundColor: AppColors.darkSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.system_update, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Text(
              isForceUpdate ? 'Update Required' : 'Update Available',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A new version ($version) is available.',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              isForceUpdate
                  ? 'This version is no longer supported. Please update to continue using RouteMate.'
                  : 'We recommend updating to the latest version for new features and bug fixes.',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
        actions: [
          if (!isForceUpdate)
            TextButton(
              onPressed: onLater,
              child: const Text('Later', style: TextStyle(color: Colors.white54)),
            ),
          ElevatedButton(
            onPressed: onUpdate,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Update Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
