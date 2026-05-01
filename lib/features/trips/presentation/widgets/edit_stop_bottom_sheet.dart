import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/transport_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/stop_model.dart';

/// Bottom sheet for editing a stop
class EditStopBottomSheet extends ConsumerStatefulWidget {
  final Stop stop;
  final Function(Stop updatedStop) onSave;

  const EditStopBottomSheet({
    Key? key,
    required this.stop,
    required this.onSave,
  }) : super(key: key);

  @override
  ConsumerState<EditStopBottomSheet> createState() =>
      _EditStopBottomSheetState();
}

class _EditStopBottomSheetState extends ConsumerState<EditStopBottomSheet> {
  late TextEditingController _nameController;
  late TextEditingController _noteController;
  late int _stayMinutes;
  late TransportType _transportType;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.stop.name);
    _noteController = TextEditingController(text: widget.stop.note ?? '');
    _stayMinutes = widget.stop.durationMinutes;
    _transportType = TransportType.fromId(widget.stop.transportType);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
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
                    color: AppColors.textSecondary,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Edit Stop',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

              // Name field
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Stop Name',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon: const Icon(Icons.location_on,
                      color: AppColors.primaryBlue),
                  filled: true,
                  fillColor: AppColors.darkElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Note field
              TextField(
                controller: _noteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Note (optional)',
                  labelStyle: TextStyle(color: AppColors.textSecondary),
                  prefixIcon:
                      const Icon(Icons.note, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.darkElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Stay duration
              Row(
                children: [
                  const Icon(Icons.timer, color: AppColors.accentAmber),
                  const SizedBox(width: 12),
                  Text(
                    'Stay Duration:',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  _buildDurationChip(30, '30 min'),
                  const SizedBox(width: 8),
                  _buildDurationChip(60, '1 hr'),
                  const SizedBox(width: 8),
                  _buildDurationChip(120, '2 hr'),
                ],
              ),
              const SizedBox(height: 16),

              // Transport type
              Text(
                'Transport Type:',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: TransportType.values.map((type) {
                  final isSelected = _transportType == type;
                  return ChoiceChip(
                    label: Text(type.displayName),
                    selected: isSelected,
                    onSelected: (_) {
                      setState(() => _transportType = type);
                    },
                    selectedColor: AppColors.getTransportColor(type.id)
                        .withValues(alpha: 0.3),
                    backgroundColor: AppColors.darkElevated,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? AppColors.getTransportColor(type.id)
                          : AppColors.textSecondary,
                    ),
                    avatar: Icon(
                      AppColors.getTransportIcon(type.id),
                      color: isSelected
                          ? AppColors.getTransportColor(type.id)
                          : AppColors.textSecondary,
                      size: 18,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _onSave,
                  icon: const Icon(Icons.save),
                  label: const Text(
                    'Save Changes',
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDurationChip(int minutes, String label) {
    final isSelected = _stayMinutes == minutes;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => setState(() => _stayMinutes = minutes),
      selectedColor: AppColors.accentAmber.withValues(alpha: 0.3),
      backgroundColor: AppColors.darkElevated,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.accentAmber : AppColors.textSecondary,
      ),
    );
  }

  void _onSave() {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a stop name')),
      );
      return;
    }

    final updatedStop = widget.stop.copyWith(
      name: _nameController.text.trim(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      durationMinutes: _stayMinutes,
      transportType: _transportType.id,
      updatedAt: DateTime.now(),
    );

    widget.onSave(updatedStop);
    Navigator.pop(context);
  }
}
