import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../../../core/services/transport_service.dart';
import '../../../../core/theme/app_theme.dart';

/// Advanced Add Stop Bottom Sheet with time and transport selection
class AddStopBottomSheet extends ConsumerStatefulWidget {
  final LatLng location;
  final String tripId;
  final int stopIndex; // 0 = first stop
  final List<LatLng>? previousStops;
  final Function(
          String name, String? note, int stayMinutes, String transportType)?
      onAddStop;
  final DateTime? startTime;

  const AddStopBottomSheet({
    Key? key,
    required this.location,
    required this.tripId,
    required this.stopIndex,
    this.previousStops,
    this.onAddStop,
    this.startTime,
  }) : super(key: key);

  @override
  ConsumerState<AddStopBottomSheet> createState() => _AddStopBottomSheetState();
}

class _AddStopBottomSheetState extends ConsumerState<AddStopBottomSheet> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();

  TransportType _transportType = TransportType.car;
  int _stayMinutes = 60; // Default 1 hour
  DateTime _startTime = DateTime.now();
  DateTime? _calculatedArrival;

  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    // Set initial transport based on previous stops if available
    if (widget.stopIndex > 0 && widget.previousStops != null) {
      _transportType = TransportType.car;
    }
    // Initialize start time
    if (widget.startTime != null) {
      _startTime = widget.startTime!;
    } else {
      // Round to next hour
      final now = DateTime.now();
      _startTime = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    }
    // Calculate initial arrival for first stop
    _calculateArrival();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _calculateArrival() async {
    if (widget.stopIndex == 0) {
      setState(() {
        _calculatedArrival = _startTime.add(Duration(minutes: _stayMinutes));
      });
      return;
    }

    if (widget.previousStops == null || widget.previousStops!.isEmpty) {
      setState(() {
        _calculatedArrival = _startTime.add(Duration(minutes: _stayMinutes));
      });
      return;
    }

    setState(() => _isCalculating = true);

    try {
      final transportService = TransportService.instance;
      final lastStop = widget.previousStops!.last;
      final newStop = widget.location;

      // Get distance (straight line for quick calc)
      final distance =
          transportService.calculateDirectDistance(lastStop, newStop);
      final estimatedDistance = distance * 1.2; // Road vs straight line

      // Calculate travel time
      final travelMinutes = transportService.calculateDurationMinutes(
        distanceMeters: estimatedDistance,
        transportType: _transportType,
      );

      // Calculate arrival
      final arrival =
          _startTime.add(Duration(minutes: travelMinutes + _stayMinutes));

      setState(() {
        _calculatedArrival = arrival;
        _isCalculating = false;
      });
    } catch (e) {
      setState(() {
        _calculatedArrival = _startTime.add(Duration(minutes: _stayMinutes));
        _isCalculating = false;
      });
    }
  }

  String _formatTime(DateTime time) {
    return DateFormat('h:mm a').format(time);
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (mins == 0) return '$hours hr';
    return '$hours hr $mins min';
  }

  @override
  Widget build(BuildContext context) {
    final isFirstStop = widget.stopIndex == 0;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                children: [
                  Icon(Icons.add_location, color: AppTheme.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    isFirstStop
                        ? 'Add First Stop'
                        : 'Add Stop ${widget.stopIndex + 1}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Location info
              Text(
                'Location: ${widget.location.latitude.toStringAsFixed(4)}, ${widget.location.longitude.toStringAsFixed(4)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 20),

              // Stop name
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Stop Name *',
                  hintText: 'e.g., Hotel, Restaurant, Tourist Spot',
                  prefixIcon: const Icon(Icons.place),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),

              // Note
              TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'Any details about this stop',
                  prefixIcon: const Icon(Icons.note),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Start time (only for first stop)
              if (isFirstStop) ...[
                _buildStartTimePicker(),
                const SizedBox(height: 20),
              ],

              // Transport type (only for non-first stops)
              if (!isFirstStop) ...[
                _buildTransportSelector(),
                const SizedBox(height: 20),
              ],

              // Stay duration
              _buildStayDurationPicker(),
              const SizedBox(height: 20),

              // Arrival preview
              _buildArrivalPreview(),

              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _onAdd,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Add Stop'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStartTimePicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, color: AppTheme.primaryColor),
              const SizedBox(width: 8),
              const Text(
                'Start Time (First Stop)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickStartTime,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatTime(_startTime),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(Icons.edit, color: Colors.grey.shade400, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startTime),
    );
    if (picked != null) {
      setState(() {
        _startTime = DateTime(
          _startTime.year,
          _startTime.month,
          _startTime.day,
          picked.hour,
          picked.minute,
        );
      });
      _calculateArrival();
    }
  }

  Widget _buildTransportSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_getTransportIcon(_transportType),
                  color: _getTransportColor(_transportType)),
              const SizedBox(width: 8),
              const Text(
                'Transport to This Stop',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TransportType.values
                .where((t) => t != TransportType.flight)
                .map((type) => _buildTransportChip(type))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportChip(TransportType type) {
    final isSelected = type == _transportType;
    final color = _getTransportColor(type);

    return ChoiceChip(
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
          const SizedBox(width: 4),
          Text(
            '(${type.speedKmh.toInt()} km/h)',
            style: TextStyle(
              fontSize: 10,
              color: isSelected ? Colors.white70 : Colors.grey,
            ),
          ),
        ],
      ),
      selectedColor: color,
      onSelected: (_) {
        setState(() => _transportType = type);
        _calculateArrival();
      },
    );
  }

  Widget _buildStayDurationPicker() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.hourglass_empty, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              const Text(
                'Stay Duration',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _stayMinutes.toDouble(),
                  min: 5,
                  max: 480,
                  divisions: 95,
                  label: _formatDuration(_stayMinutes),
                  activeColor: Colors.amber.shade700,
                  onChanged: (value) {
                    setState(() => _stayMinutes = value.toInt());
                    _calculateArrival();
                  },
                ),
              ),
              SizedBox(
                width: 70,
                child: Text(
                  _formatDuration(_stayMinutes),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
                  ),
                  textAlign: TextAlign.end,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildArrivalPreview() {
    if (_calculatedArrival == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, color: Colors.green.shade700),
              const SizedBox(width: 8),
              Text(
                widget.stopIndex == 0 ? 'First Stop' : 'Arrival Time',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isCalculating)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Calculating...'),
              ],
            )
          else
            Row(
              children: [
                Icon(Icons.arrow_forward,
                    size: 16, color: Colors.green.shade700),
                const SizedBox(width: 8),
                Text(
                  _formatTime(_calculatedArrival!),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Text(
                  'Next departure: ${_formatTime(_calculatedArrival!.add(Duration(minutes: _stayMinutes)))}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
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
      case TransportType.bike:
        return Colors.orange;
      case TransportType.walking:
        return Colors.teal;
      case TransportType.flight:
        return Colors.red;
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
      case TransportType.bike:
        return Icons.pedal_bike;
      case TransportType.walking:
        return Icons.directions_walk;
      case TransportType.flight:
        return Icons.flight;
    }
  }

  void _onAdd() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a stop name')),
      );
      return;
    }

    widget.onAddStop?.call(
      _nameController.text.trim(),
      _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      _stayMinutes,
      _transportType.id,
    );

    Navigator.pop(context);
  }
}
