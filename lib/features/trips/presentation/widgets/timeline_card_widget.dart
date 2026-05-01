import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/timeline_service.dart';

/// Modern dark-themed stop card for timeline
class StopCardWidget extends StatelessWidget {
  final TimelineEntry entry;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const StopCardWidget({
    Key? key,
    required this.entry,
    this.isFirst = false,
    this.isLast = false,
    this.onTap,
    this.onEdit,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row with icon and name
                  _buildHeader(context, isDark),
                  const SizedBox(height: 12),
                  // Time info
                  _buildTimeInfo(context, isDark),
                  // Stay duration (if not last)
                  if (!isLast && entry.stayDurationMinutes > 0) ...[
                    const SizedBox(height: 12),
                    _buildStayDuration(context, isDark),
                  ],
                ],
              ),
            ),
            // Action buttons (if not first)
            if (!isFirst) _buildActionButtons(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      children: [
        // Marker icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: isFirst
                ? AppColors.startGreen
                : (isLast ? AppColors.endRed : AppColors.stopBlue),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isFirst
                ? const Icon(Icons.play_arrow, color: Colors.white, size: 20)
                : (isLast
                    ? const Icon(Icons.flag, color: Colors.white, size: 18)
                    : Text(
                        '${entry.index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      )),
          ),
        ),
        const SizedBox(width: 12),
        // Stop name
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.stopName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isFirst)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.startGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'START',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.startGreen,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeInfo(BuildContext context, bool isDark) {
    return Row(
      children: [
        if (!isFirst) ...[
          _buildTimeChip(
            context,
            'Arrival',
            entry.arrivalTimeFormatted,
            Icons.arrow_downward,
            isDark,
          ),
          const SizedBox(width: 12),
        ],
        _buildTimeChip(
          context,
          isFirst ? 'Start' : 'Departure',
          entry.departureTimeFormatted,
          isFirst ? Icons.play_arrow : Icons.arrow_upward,
          isDark,
        ),
      ],
    );
  }

  Widget _buildTimeChip(
    BuildContext context,
    String label,
    String time,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                time,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStayDuration(BuildContext context, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.accentYellow.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.accentYellow.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty, size: 14, color: AppColors.accentAmber),
          const SizedBox(width: 6),
          Text(
            'Stay: ${entry.stayDurationFormatted}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.accentAmber,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkElevated : Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (onEdit != null)
            TextButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit, size: 18),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBlue,
              ),
            ),
          if (onDelete != null)
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete, size: 18),
              label: const Text('Delete'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.error,
              ),
            ),
        ],
      ),
    );
  }
}

/// Route segment card showing transport info
class RouteSegmentCardWidget extends StatelessWidget {
  final TimelineEntry entry;
  final bool showTransport;

  const RouteSegmentCardWidget({
    Key? key,
    required this.entry,
    this.showTransport = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (!showTransport || entry.arrivalSegment == null) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segment = entry.arrivalSegment!;

    // Get transport type from segment
    final transportTypeId = segment.transportType.id;
    final transportColor = AppColors.getTransportColor(transportTypeId);
    final transportIcon = AppColors.getTransportIcon(transportTypeId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
      child: Row(
        children: [
          // Vertical line
          Container(
            width: 2,
            height: 40,
            color: transportColor.withValues(alpha: 0.3),
          ),
          const SizedBox(width: 16),
          // Transport card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: transportColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: transportColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  // Transport icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: transportColor.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      transportIcon,
                      color: transportColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Transport info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          segment.transportName,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: transportColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          segment.durationTextFromMinutes,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondary
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Distance
                  if (segment.distanceKm > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: transportColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${segment.distanceKm.toStringAsFixed(1)} km',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: transportColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empty state widget for timeline
class TimelineEmptyCard extends StatelessWidget {
  final VoidCallback? onAddStop;

  const TimelineEmptyCard({
    Key? key,
    this.onAddStop,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_location_alt,
              size: 64,
              color: isDark ? AppColors.textSecondary : Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'No stops added yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap on the map or use the + button to add your first stop',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondary : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            if (onAddStop != null) ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onAddStop,
                icon: const Icon(Icons.add),
                label: const Text('Add First Stop'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Loading state widget for timeline
class TimelineLoadingCard extends StatelessWidget {
  const TimelineLoadingCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(
              color: AppColors.primaryBlue,
            ),
            const SizedBox(height: 16),
            Text(
              'Calculating route...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Timeline summary header widget
class TimelineSummaryHeader extends StatelessWidget {
  final TripTimeline timeline;
  final VoidCallback? onRecalculate;

  const TimelineSummaryHeader({
    Key? key,
    required this.timeline,
    this.onRecalculate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue,
            AppColors.primaryDark,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Title row
          Row(
            children: [
              const Icon(Icons.timeline, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Trip Timeline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${timeline.entries.length} stops',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                Icons.play_arrow,
                DateFormat('h:mm a').format(timeline.startTime),
                'Start',
              ),
              _buildStatItem(
                Icons.directions_car,
                timeline.totalTravelTimeFormatted,
                'Travel',
              ),
              _buildStatItem(
                Icons.hourglass_empty,
                timeline.totalStayTimeFormatted,
                'Stay',
              ),
              _buildStatItem(
                Icons.flag,
                timeline.endTimeFormatted,
                'End',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
