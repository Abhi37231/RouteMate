import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/timeline_service.dart';
import '../../../../data/models/trip_model.dart';
import '../../../../data/models/stop_model.dart';
import '../../../../core/services/weather_service.dart';
import '../../presentation/providers/trip_providers.dart';
import '../../presentation/widgets/timeline_card_widget.dart';
import '../../presentation/widgets/edit_stop_bottom_sheet.dart';
import '../../../map/presentation/screens/map_screen.dart';

/// Full-screen trip timeline display
class TripTimelineScreen extends ConsumerWidget {
  final Trip trip;

  const TripTimelineScreen({
    Key? key,
    required this.trip,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timelineAsync = ref.watch(tripTimelineProvider(trip.id));

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppColors.darkBackground,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                trip.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryBlue, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.share, color: Colors.white),
                onPressed: () => _shareTrip(context, ref),
                tooltip: 'Share Trip',
              ),
              IconButton(
                icon: const Icon(Icons.map, color: Colors.white),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MapScreen(trip: trip),
                    ),
                  );
                },
                tooltip: 'View on Map',
              ),
              _buildTripPopupMenu(context, ref),
            ],
          ),

          // Timeline Content
          SliverToBoxAdapter(
            child: timelineAsync.when(
              data: (timeline) {
                if (timeline.entries.isEmpty) {
                  return const TimelineEmptyCard();
                }

                return Column(
                  children: [
                    // Summary Header Card
                    TimelineSummaryHeader(
                      timeline: timeline,
                      onRecalculate: () {
                        ref.invalidate(tripTimelineProvider(trip.id));
                      },
                    ),

                    // Stats Row
                    _buildStatsRow(timeline),

                    const SizedBox(height: 16),

                    // Timeline List
                    _buildTimelineList(context, ref, timeline),

                    const SizedBox(height: 24),

                    // View on Map Button
                    _buildViewMapButton(context),

                    const SizedBox(height: 32),
                  ],
                );
              },
              loading: () => const TimelineLoadingCard(),
              error: (error, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading timeline',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(TripTimeline timeline) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.play_arrow,
            label: 'Start',
            value: _formatTime(timeline.startTime),
            color: AppColors.startGreen,
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            icon: Icons.directions_car,
            label: 'Travel',
            value: timeline.totalTravelTimeFormatted,
            color: AppColors.primaryBlue,
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            icon: Icons.hourglass_empty,
            label: 'Stay',
            value: timeline.totalStayTimeFormatted,
            color: AppColors.accentAmber,
          ),
          const SizedBox(width: 8),
          _buildStatCard(
            icon: Icons.flag,
            label: 'End',
            value: timeline.endTimeFormatted,
            color: AppColors.endRed,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.darkCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineList(
    BuildContext context,
    WidgetRef ref,
    TripTimeline timeline,
  ) {
    // Group entries by date
    final Map<String, List<TimelineEntry>> groupedEntries = {};
    for (var entry in timeline.entries) {
      final dateKey = '${entry.arrivalTime.year}-${entry.arrivalTime.month}-${entry.arrivalTime.day}';
      if (!groupedEntries.containsKey(dateKey)) {
        groupedEntries[dateKey] = [];
      }
      groupedEntries[dateKey]!.add(entry);
    }

    final dateKeys = groupedEntries.keys.toList();
    dateKeys.sort();

    return Column(
      children: [
        for (int i = 0; i < dateKeys.length; i++) ...[
          _buildDayHeader(i + 1, _parseDate(dateKeys[i])),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: groupedEntries[dateKeys[i]]!.length,
            itemBuilder: (context, index) {
              final entriesInDay = groupedEntries[dateKeys[i]]!;
              final entry = entriesInDay[index];
              final isFirstInTrip = i == 0 && index == 0;
              final isLastInTrip = i == dateKeys.length - 1 && index == entriesInDay.length - 1;

              return Column(
                children: [
                  // Transport segment (before stop, except the very first one of the trip)
                  if (!isFirstInTrip)
                    RouteSegmentCardWidget(
                      entry: entry,
                      showTransport: true,
                    ),

                  // Stop card
                  StopCardWidget(
                    entry: entry,
                    isFirst: isFirstInTrip,
                    isLast: isLastInTrip,
                    onTap: () {},
                    onEdit: () => _showEditStopBottomSheet(context, ref, entry),
                    onDelete: () => _showDeleteConfirmation(context, ref, entry),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildDayHeader(int dayNumber, DateTime date) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Day $dayNumber',
              style: const TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${date.day}/${date.month}/${date.year}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.wb_sunny_outlined, size: 12, color: AppColors.accentAmber),
                  const SizedBox(width: 4),
                  Text(
                    'Sunny • 24°C',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Expanded(child: Divider(indent: 16, color: Colors.white24)),
        ],
      ),
    );
  }

  DateTime _parseDate(String dateKey) {
    final parts = dateKey.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
  }

  void _shareTrip(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.darkSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Share Trip',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            // Option 1: Share Trip Code
            _buildShareOption(
              context,
              icon: Icons.vpn_key_outlined,
              title: 'Share Trip Code',
              subtitle: 'Invite friends to join this trip using a code.',
              color: AppColors.primaryBlue,
              onTap: () {
                Navigator.pop(context);
                _showCodeDialog(context);
              },
            ),
            const SizedBox(height: 16),
            // Option 2: Share Trip Plan (Existing)
            _buildShareOption(
              context,
              icon: Icons.description_outlined,
              title: 'Share Trip Plan',
              subtitle: 'Send a text summary of your itinerary.',
              color: Colors.greenAccent,
              onTap: () {
                Navigator.pop(context);
                _shareTripPlanText(ref);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  void _showCodeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Trip Share Code', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Friends can join your trip by entering this code in the Shared tab.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primaryBlue.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    trip.shareCode ?? 'NO-CODE',
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.white54),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: trip.shareCode ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Code copied to clipboard!')),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              Share.share('Join my trip on RouteMate using code: ${trip.shareCode}');
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            child: const Text('Share Code', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _shareTripPlanText(WidgetRef ref) {
    final timelineAsync = ref.read(tripTimelineProvider(trip.id));
    
    timelineAsync.whenData((timeline) {
      String shareText = 'Check out my trip: ${trip.name}\n\n';
      shareText += 'Timeline:\n';
      
      for (var entry in timeline.entries) {
        shareText += '- ${entry.stopName} (${_formatTime(entry.arrivalTime)})\n';
      }
      
      shareText += '\nPlanned with RouteMate';
      
      Share.share(shareText);
    });
  }

  void _showEditStopBottomSheet(
    BuildContext context,
    WidgetRef ref,
    TimelineEntry entry,
  ) {
    // Get the actual stop from the provider to pass to edit sheet
    final stopsAsync = ref.read(stopsProvider(trip.id));
    stopsAsync.when(
      data: (stops) {
        final stop = stops.firstWhere(
          (s) => s.id == entry.stopId,
          orElse: () => Stop(
            id: entry.stopId,
            tripId: trip.id,
            name: entry.stopName,
            latitude: entry.location.latitude,
            longitude: entry.location.longitude,
            note: null,
            durationMinutes: entry.stayDurationMinutes,
            orderIndex: entry.index,
            arrivalTime: entry.arrivalTime,
            departureTime: entry.departureTime,
            transportType: entry.arrivalSegment?.transportType.id ?? 'car',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => EditStopBottomSheet(
            stop: stop,
            onSave: (updatedStop) async {
              await ref
                  .read(stopsProvider(trip.id).notifier)
                  .updateStop(updatedStop);
              // Refresh timeline
              ref.invalidate(tripTimelineProvider(trip.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Stop updated successfully')),
              );
            },
          ),
        );
      },
      loading: () {},
      error: (_, __) {},
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    WidgetRef ref,
    TimelineEntry entry,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Stop?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${entry.stopName}"? This action cannot be undone.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(stopsProvider(trip.id).notifier)
                  .deleteStop(entry.stopId);
              // Refresh timeline
              ref.invalidate(tripTimelineProvider(trip.id));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Stop deleted')),
              );
            },
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripPopupMenu(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white),
      color: AppColors.darkElevated,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (value) {
        switch (value) {
          case 'edit':
            _showEditTripDialog(context, ref);
            break;
          case 'delete':
            _showDeleteTripConfirmation(context, ref);
            break;
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              const Icon(Icons.edit, color: AppColors.primaryBlue, size: 20),
              const SizedBox(width: 12),
              Text(
                'Edit Trip',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete, color: AppColors.error, size: 20),
              const SizedBox(width: 12),
              Text(
                'Delete Trip',
                style: TextStyle(color: AppColors.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showEditTripDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController(text: trip.name);
    final descController = TextEditingController(text: trip.description ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Edit Trip',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Trip Name',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.darkElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Description (optional)',
                labelStyle: TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.darkElevated,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Trip name cannot be empty')),
                );
                return;
              }
              Navigator.pop(context);
              final updatedTrip = trip.copyWith(
                name: nameController.text.trim(),
                description: descController.text.trim().isEmpty
                    ? null
                    : descController.text.trim(),
                updatedAt: DateTime.now(),
              );
              await ref.read(tripsProvider.notifier).updateTrip(updatedTrip);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Trip updated successfully')),
              );
            },
            icon: const Icon(Icons.save, color: Colors.white),
            label: const Text(
              'Save',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteTripConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Delete Trip?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "${trip.name}"? All stops and data will be permanently removed.',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(tripsProvider.notifier).deleteTrip(trip.id);
              Navigator.pop(context); // Go back to trips list
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${trip.name} deleted')),
              );
            },
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text(
              'Delete',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildViewMapButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => MapScreen(trip: trip),
              ),
            );
          },
          icon: const Icon(Icons.map),
          label: const Text(
            'View on Map',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
