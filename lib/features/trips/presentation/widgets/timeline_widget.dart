import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/transport_service.dart';
import '../../../../core/services/timeline_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Timeline entry widget - displays a single stop with its timeline
class TimelineEntryWidget extends StatelessWidget {
  final TimelineEntry entry;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;
  final Function(TransportType)? onTransportChanged;

  const TimelineEntryWidget({
    Key? key,
    required this.entry,
    this.isFirst = false,
    this.isLast = false,
    this.onTap,
    this.onTransportChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Timeline indicator
              _buildTimelineIndicator(),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: _buildContent(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineIndicator() {
    return SizedBox(
      width: 40,
      child: Column(
        children: [
          // Top line
          if (!isFirst)
            Container(
              width: 2,
              height: 16,
              color: AppTheme.primaryColor,
            ),
          // Dot
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isFirst ? AppTheme.primaryColor : Colors.white,
              border: Border.all(
                color: AppTheme.primaryColor,
                width: 2,
              ),
              shape: BoxShape.circle,
            ),
            child: isFirst
                ? const Icon(Icons.play_arrow, color: Colors.white, size: 14)
                : null,
          ),
          // Bottom line
          if (!isLast)
            Expanded(
              child: Container(
                width: 2,
                color: AppTheme.primaryColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Stop name and time
          _buildStopHeader(),
          const SizedBox(height: 8),
          // Arrival segment info (if not first)
          if (!isFirst && entry.arrivalSegment != null) ...[
            _buildArrivalSegment(context),
            const SizedBox(height: 12),
          ],
          // Stay duration (if not last)
          if (!isLast) ...[
            _buildStayDuration(context),
          ],
        ],
      ),
    );
  }

  Widget _buildStopHeader() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.location_on,
                color: isFirst ? AppTheme.primaryColor : Colors.grey.shade700,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.stopName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (isFirst)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'START',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Times row
          Row(
            children: [
              if (!isFirst) ...[
                _buildTimeChip(
                  'Arr: ${entry.arrivalTimeFormatted}',
                  Icons.arrow_downward,
                ),
                const SizedBox(width: 8),
              ],
              _buildTimeChip(
                'Dep: ${entry.departureTimeFormatted}',
                Icons.arrow_upward,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeChip(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildArrivalSegment(BuildContext context) {
    final segment = entry.arrivalSegment!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _getTransportColor(segment.transportType).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getTransportColor(segment.transportType).withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Transport type dropdown (if changeable)
          if (onTransportChanged != null) ...[
            _buildTransportDropdown(context, segment.transportType),
            const SizedBox(height: 8),
          ],
          // Transport info
          Row(
            children: [
              Icon(
                _getTransportIcon(segment.transportType),
                color: _getTransportColor(segment.transportType),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                segment.transportName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _getTransportColor(segment.transportType),
                ),
              ),
              const Spacer(),
              Text(
                segment.durationTextFromMinutes,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Distance
          Row(
            children: [
              Icon(Icons.straighten, size: 14, color: Colors.grey.shade500),
              const SizedBox(width: 4),
              Text(
                segment.distanceText,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransportDropdown(BuildContext context, TransportType current) {
    return DropdownButtonFormField<TransportType>(
      value: current,
      decoration: InputDecoration(
        labelText: 'Transport',
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      items: TransportType.values
          .where((t) => t != TransportType.flight) // No flight for short routes
          .map((type) => DropdownMenuItem(
                value: type,
                child: Row(
                  children: [
                    Icon(
                      _getTransportIcon(type),
                      size: 18,
                      color: _getTransportColor(type),
                    ),
                    const SizedBox(width: 8),
                    Text(type.displayName),
                  ],
                ),
              ))
          .toList(),
      onChanged: (type) {
        if (type != null && onTransportChanged != null) {
          onTransportChanged!(type);
        }
      },
    );
  }

  Widget _buildStayDuration(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.hourglass_empty, color: Colors.amber.shade700, size: 18),
          const SizedBox(width: 8),
          Text(
            'Stay: ${entry.stayDurationFormatted}',
            style: TextStyle(
              color: Colors.amber.shade800,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Color _getTransportColor(TransportType type) {
    switch (type) {
      case TransportType.car:
        return Colors.blue;
      case TransportType.bus:
        return Colors.green;
      case TransportType.train:
        return Colors.purple;
      case TransportType.flight:
        return Colors.red;
      case TransportType.bike:
        return Colors.orange;
      case TransportType.walking:
        return Colors.teal;
    }
  }

  IconData _getTransportIcon(TransportType type) {
    switch (type) {
      case TransportType.car:
        return Icons.directions_car;
      case TransportType.bus:
        return Icons.directions_bus;
      case TransportType.train:
        return Icons.train;
      case TransportType.flight:
        return Icons.flight;
      case TransportType.bike:
        return Icons.pedal_bike;
      case TransportType.walking:
        return Icons.directions_walk;
    }
  }
}

/// Full timeline widget - displays the entire trip timeline
class TimelineViewWidget extends StatelessWidget {
  final TripTimeline timeline;
  final Function(int, TransportType)? onTransportChanged;
  final Function(int)? onStayDurationChanged;
  final VoidCallback? onRecalculate;

  const TimelineViewWidget({
    Key? key,
    required this.timeline,
    this.onTransportChanged,
    this.onStayDurationChanged,
    this.onRecalculate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        _buildHeader(context),
        const SizedBox(height: 16),
        // Timeline entries
        ...timeline.entries.asMap().entries.map((entry) {
          final index = entry.key;
          final timelineEntry = entry.value;
          return TimelineEntryWidget(
            key: ValueKey(timelineEntry.stopId),
            entry: timelineEntry,
            isFirst: index == 0,
            isLast: index == timeline.entries.length - 1,
            onTransportChanged: (type) {
              if (onTransportChanged != null) {
                onTransportChanged!(index, type);
              }
            },
          );
        }),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Trip Timeline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const Spacer(),
              if (onRecalculate != null)
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: onRecalculate,
                  tooltip: 'Recalculate timeline',
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Start',
                DateFormat('h:mm a').format(timeline.startTime),
                Icons.play_arrow,
              ),
              _buildSummaryItem(
                'Travel',
                timeline.totalTravelTimeFormatted,
                Icons.directions_car,
              ),
              _buildSummaryItem(
                'Stay',
                timeline.totalStayTimeFormatted,
                Icons.hourglass_empty,
              ),
              _buildSummaryItem(
                'End',
                timeline.endTimeFormatted,
                Icons.flag,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

/// Compact timeline widget - minimal timeline for cards
class CompactTimelineWidget extends StatelessWidget {
  final TripTimeline timeline;

  const CompactTimelineWidget({
    Key? key,
    required this.timeline,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildInfoItem(
            'Stops',
            '${timeline.entries.length}',
            Icons.location_on,
          ),
          _buildInfoItem(
            'Travel',
            timeline.totalTravelTimeFormatted,
            Icons.directions_car,
          ),
          _buildInfoItem(
            'End',
            timeline.endTimeFormatted,
            Icons.access_time,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
          ),
        ),
      ],
    );
  }
}

/// Loading timeline widget
class TimelineLoadingWidget extends StatelessWidget {
  const TimelineLoadingWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Calculating timeline...',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

/// Empty timeline widget
class TimelineEmptyWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onAddStops;

  const TimelineEmptyWidget({
    Key? key,
    this.message = 'No stops added yet',
    this.onAddStops,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.timeline,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
          if (onAddStops != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onAddStops,
              icon: const Icon(Icons.add),
              label: const Text('Add Stops'),
            ),
          ],
        ],
      ),
    );
  }
}
