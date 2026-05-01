import 'package:flutter/material.dart';
import '../../../../core/services/transport_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Dropdown widget for selecting transport type
class TransportSelectorWidget extends StatelessWidget {
  final TransportType selectedType;
  final ValueChanged<TransportType> onChanged;
  final bool enabled;

  const TransportSelectorWidget({
    Key? key,
    required this.selectedType,
    required this.onChanged,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<TransportType>(
      value: selectedType,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: 'Transport Mode',
        prefixIcon: Icon(
          _getTransportIcon(selectedType),
          color: _getTransportColor(selectedType),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        enabled: enabled,
      ),
      items: TransportType.values
          .map((type) => DropdownMenuItem(
                value: type,
                child: Row(
                  children: [
                    Icon(
                      _getTransportIcon(type),
                      color: _getTransportColor(type),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            type.displayName,
                            style: const TextStyle(
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${type.speedKmh.toInt()} km/h',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ))
          .toList(),
      onChanged: enabled
          ? (type) {
              if (type != null) {
                onChanged(type);
              }
            }
          : null,
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

/// Chip-based transport type selector
class TransportChipSelector extends StatelessWidget {
  final TransportType selectedType;
  final ValueChanged<TransportType> onChanged;
  final bool enabled;

  const TransportChipSelector({
    Key? key,
    required this.selectedType,
    required this.onChanged,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: TransportType.values.map((type) => _buildChip(type)).toList(),
    );
  }

  Widget _buildChip(TransportType type) {
    final isSelected = type == selectedType;
    final color = _getTransportColor(type);

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getTransportIcon(type),
            size: 16,
            color: isSelected ? Colors.white : color,
          ),
          const SizedBox(width: 4),
          Text(type.displayName),
        ],
      ),
      onSelected: enabled ? (_) => onChanged(type) : null,
      selectedColor: color,
      checkmarkColor: Colors.white,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade800,
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

/// Transport type legend for display
class TransportLegendWidget extends StatelessWidget {
  final bool showSpeeds;
  final bool compact;

  const TransportLegendWidget({
    Key? key,
    this.showSpeeds = true,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: TransportType.values
            .where((t) => t != TransportType.flight)
            .map((type) => _buildCompactItem(type))
            .toList(),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transport Modes',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: TransportType.values
              .where((t) => t != TransportType.flight)
              .map((type) => _buildItem(type))
              .toList(),
        ),
      ],
    );
  }

  Widget _buildCompactItem(TransportType type) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _getTransportIcon(type),
          size: 14,
          color: _getTransportColor(type),
        ),
        const SizedBox(width: 4),
        Text(
          showSpeeds ? '${type.speedKmh.toInt()} km/h' : type.displayName,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildItem(TransportType type) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: _getTransportColor(type).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(
            _getTransportIcon(type),
            size: 14,
            color: _getTransportColor(type),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${type.displayName} (${type.speedKmh.toInt()} km/h)',
          style: const TextStyle(fontSize: 13),
        ),
      ],
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

/// Stay duration widget for setting time spent at a stop
class StayDurationWidget extends StatelessWidget {
  final int durationMinutes;
  final ValueChanged<int> onChanged;
  final bool enabled;

  const StayDurationWidget({
    Key? key,
    required this.durationMinutes,
    required this.onChanged,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.hourglass_empty,
          color: Colors.amber.shade700,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Slider(
            value: durationMinutes.toDouble(),
            min: 5,
            max: 480, // 8 hours
            divisions: enabled ? 95 : 0,
            label: _formatDuration(durationMinutes),
            onChanged: enabled ? (value) => onChanged(value.toInt()) : null,
          ),
        ),
        SizedBox(
          width: 70,
          child: Text(
            _formatDuration(durationMinutes),
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) {
      return '$hours hr';
    }
    return '$hours hr $mins min';
  }
}

/// Time picker widget for start time selection
class StartTimePickerWidget extends StatelessWidget {
  final DateTime startTime;
  final ValueChanged<DateTime> onChanged;
  final bool enabled;

  const StartTimePickerWidget({
    Key? key,
    required this.startTime,
    required this.onChanged,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? () => _selectTime(context) : null,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              Icons.access_time,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Start Time',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  _formatTime(startTime),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (enabled)
              Icon(
                Icons.edit,
                size: 18,
                color: Colors.grey.shade400,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(startTime),
    );
    if (picked != null) {
      final newTime = DateTime(
        startTime.year,
        startTime.month,
        startTime.day,
        picked.hour,
        picked.minute,
      );
      onChanged(newTime);
    }
  }

  String _formatTime(DateTime time) {
    final hour =
        time.hour > 12 ? time.hour - 12 : (time.hour == 0 ? 12 : time.hour);
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
