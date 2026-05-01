import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/update_service.dart';

class UpdateState {
  final bool hasUpdate;
  final bool isForceUpdate;
  final UpdateInfo? updateInfo;
  final bool isLoading;

  UpdateState({
    this.hasUpdate = false,
    this.isForceUpdate = false,
    this.updateInfo,
    this.isLoading = false,
  });

  UpdateState copyWith({
    bool? hasUpdate,
    bool? isForceUpdate,
    UpdateInfo? updateInfo,
    bool? isLoading,
  }) {
    return UpdateState(
      hasUpdate: hasUpdate ?? this.hasUpdate,
      isForceUpdate: isForceUpdate ?? this.isForceUpdate,
      updateInfo: updateInfo ?? this.updateInfo,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier();
});

class UpdateNotifier extends StateNotifier<UpdateState> {
  final UpdateService _service = UpdateService();

  UpdateNotifier() : super(UpdateState());

  Future<void> checkForUpdates() async {
    state = state.copyWith(isLoading: true);
    
    final currentVersion = await _service.getCurrentVersion();
    final info = await _service.getUpdateInfo();

    print('🔍 UPDATE CHECK:');
    print('   - Current App Version: $currentVersion');
    
    if (info != null) {
      print('   - Firestore Latest: ${info.latestVersion}');
      print('   - Firestore Min Required: ${info.minRequiredVersion}');
      
      final hasUpdate = _service.shouldUpdate(currentVersion, info.latestVersion);
      final forceUpdate = _service.isForceUpdateRequired(currentVersion, info.minRequiredVersion);
      
      print('   - Has Update Available: $hasUpdate');
      print('   - Force Update Needed: ${info.isForceUpdate || forceUpdate}');

      state = state.copyWith(
        hasUpdate: hasUpdate,
        isForceUpdate: info.isForceUpdate || forceUpdate,
        updateInfo: info,
        isLoading: false,
      );
    } else {
      print('   - Error: Could not fetch update info from Firestore');
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> launchUpdate() async {
    if (state.updateInfo != null) {
      await _service.launchUpdateUrl(state.updateInfo!.updateUrl);
    }
  }
}
