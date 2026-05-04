import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateInfo {
  final String latestVersion;
  final String minRequiredVersion;
  final String updateUrl;
  final bool isForceUpdate;

  UpdateInfo({
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.updateUrl,
    required this.isForceUpdate,
  });

  factory UpdateInfo.fromFirestore(Map<String, dynamic> data) {
    try {
      return UpdateInfo(
        latestVersion: data['latest_version']?.toString() ?? '1.0.0',
        minRequiredVersion: data['min_required_version']?.toString() ?? '1.0.0',
        updateUrl: data['update_url']?.toString() ?? '',
        isForceUpdate: data['is_force_update'] == true || data['is_force_update'] == 'true',
      );
    } catch (e) {
      print('Error parsing UpdateInfo: $e');
      return UpdateInfo(
        latestVersion: '1.0.0',
        minRequiredVersion: '1.0.0',
        updateUrl: '',
        isForceUpdate: false,
      );
    }
  }
}

class UpdateService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<UpdateInfo?> getUpdateInfo() async {
    try {
      final doc = await _firestore.collection('app_config').doc('version').get();
      if (doc.exists) {
        return UpdateInfo.fromFirestore(doc.data()!);
      }
    } catch (e) {
      print('UpdateService Error: $e');
    }
    return null;
  }

  Future<String> getCurrentVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  bool shouldUpdate(String current, String latest) {
    return _compareVersions(current, latest) < 0;
  }

  bool isForceUpdateRequired(String current, String minRequired) {
    return _compareVersions(current, minRequired) < 0;
  }

  int _compareVersions(String v1, String v2) {
    try {
      // Clean up strings (remove +build number or -beta suffix)
      String cleanV1 = v1.split('+')[0].split('-')[0].trim();
      String cleanV2 = v2.split('+')[0].split('-')[0].trim();

      List<int> v1Parts = cleanV1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      List<int> v2Parts = cleanV2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

      for (int i = 0; i < 3; i++) {
        int p1 = i < v1Parts.length ? v1Parts[i] : 0;
        int p2 = i < v2Parts.length ? v2Parts[i] : 0;
        if (p1 < p2) return -1;
        if (p1 > p2) return 1;
      }
      return 0;
    } catch (e) {
      print('Version compare error: $e');
      return 0;
    }
  }

  Future<void> launchUpdateUrl(String url) async {
    if (url.isEmpty) return;
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      print('Could not launch update URL: $e');
    }
  }
}
