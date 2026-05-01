import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Custom map marker widget for flutter_map
class MapMarkerWidget extends StatefulWidget {
  final int index;
  final bool isStart;
  final bool isEnd;
  final String? label;
  final VoidCallback? onTap;
  final bool animate;

  const MapMarkerWidget({
    Key? key,
    required this.index,
    this.isStart = false,
    this.isEnd = false,
    this.label,
    this.onTap,
    this.animate = true,
  }) : super(key: key);

  @override
  State<MapMarkerWidget> createState() => _MapMarkerWidgetState();
}

class _MapMarkerWidgetState extends State<MapMarkerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    if (widget.animate) {
      _controller.forward();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _markerColor {
    if (widget.isStart) return AppColors.startGreen;
    if (widget.isEnd) return AppColors.endRed;
    return AppColors.stopBlue;
  }

  IconData get _markerIcon {
    if (widget.isStart) return Icons.play_arrow;
    if (widget.isEnd) return Icons.flag;
    return Icons.location_on;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _opacityAnimation.value,
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _markerColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: _markerColor.withValues(alpha: 0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: widget.isStart || widget.isEnd
                ? Icon(
                    _markerIcon,
                    color: Colors.white,
                    size: 20,
                  )
                : Text(
                    '${widget.index + 1}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Factory to create markers for stops
class MapMarkerFactory {
  /// Create marker based on stop position
  static Widget createMarker({
    required int index,
    required int totalStops,
    String? label,
    VoidCallback? onTap,
  }) {
    final isStart = index == 0;
    final isEnd = index == totalStops - 1 && totalStops > 1;

    return MapMarkerWidget(
      index: index,
      isStart: isStart,
      isEnd: isEnd,
      label: label,
      onTap: onTap,
    );
  }

  /// Create a list of markers from stops
  static List<Widget> createMarkers({
    required List<dynamic> stops,
    Function(int)? onMarkerTap,
  }) {
    return stops.asMap().entries.map((entry) {
      final index = entry.key;
      final stop = entry.value;

      return createMarker(
        index: index,
        totalStops: stops.length,
        label: stop.name,
        onTap: onMarkerTap != null ? () => onMarkerTap(index) : null,
      );
    }).toList();
  }
}

/// Marker info for building marker layer
class MarkerInfo {
  final int index;
  final int totalStops;
  final double latitude;
  final double longitude;
  final String? label;

  MarkerInfo({
    required this.index,
    required this.totalStops,
    required this.latitude,
    required this.longitude,
    this.label,
  });
}
