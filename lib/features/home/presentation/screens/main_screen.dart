import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/update_provider.dart';
import '../../../../core/widgets/update_dialog.dart';
import '../home_tab.dart';
import '../trips_tab.dart';
import '../shared_trips_tab.dart';
import '../profile_tab.dart';

/// Main screen with bottom navigation
class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    HomeTab(),
    TripsTab(),
    SharedTripsTab(),
    ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    // Check for updates on startup
    Future.microtask(() {
      ref.read(updateProvider.notifier).checkForUpdates();
    });
  }

  void _showUpdateDialog(UpdateState state) {
    if (state.updateInfo == null) return;
    
    showDialog(
      context: context,
      barrierDismissible: !state.isForceUpdate,
      builder: (context) => UpdateDialog(
        version: state.updateInfo!.latestVersion,
        isForceUpdate: state.isForceUpdate,
        onUpdate: () => ref.read(updateProvider.notifier).launchUpdate(),
        onLater: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Listen for update state changes
    ref.listen<UpdateState>(updateProvider, (previous, next) {
      if (next.hasUpdate && (previous == null || !previous.hasUpdate)) {
        _showUpdateDialog(next);
      }
    });

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Plan Trip',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outlined),
            selectedIcon: Icon(Icons.people),
            label: 'Shared',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outlined),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
