import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';
import '../../core/services/transport_service.dart';

/// Model representing a route segment between two stops
class RouteSegment extends Equatable {
  final String id;
  final String fromStopId;
  final String toStopId;
  final String fromStopName;
  final String toStopName;
  final TransportType transportType;
  final double distanceMeters;
  final int durationSeconds;
  final List<LatLng> polylinePoints;
  final DateTime? calculatedAt;

  const RouteSegment({
    required this.id,
    required this.fromStopId,
    required this.toStopId,
    required this.fromStopName,
    required this.toStopName,
    required this.transportType,
    required this.distanceMeters,
    required this.durationSeconds,
    this.polylinePoints = const [],
    this.calculatedAt,
  });

  /// Get distance in kilometers
  double get distanceKm => distanceMeters / 1000;

  /// Get distance formatted
  String get distanceText {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  /// Get duration in minutes
  int get durationMinutes => (durationSeconds / 60).ceil();

  /// Get duration formatted
  String get durationText {
    if (durationSeconds < 60) {
      return '$durationSeconds sec';
    }
    final minutes = durationSeconds ~/ 60;
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

  /// Get formatted duration from minutes
  String get durationTextFromMinutes {
    if (durationMinutes < 60) {
      return '$durationMinutes min';
    }
    final hours = durationMinutes ~/ 60;
    final mins = durationMinutes % 60;
    if (mins == 0) {
      return '$hours hr';
    }
    return '$hours hr $mins min';
  }

  /// Get transport type display name
  String get transportName => transportType.displayName;

  /// Get start location
  LatLng? get startLocation =>
      polylinePoints.isNotEmpty ? polylinePoints.first : null;

  /// Get end location
  LatLng? get endLocation =>
      polylinePoints.isNotEmpty ? polylinePoints.last : null;

  /// Create from JSON map
  factory RouteSegment.fromJson(Map<String, dynamic> json) {
    return RouteSegment(
      id: json['id'] as String,
      fromStopId: json['fromStopId'] as String,
      toStopId: json['toStopId'] as String,
      fromStopName: json['fromStopName'] as String,
      toStopName: json['toStopName'] as String,
      transportType:
          TransportType.fromId(json['transportType'] as String? ?? 'car'),
      distanceMeters: (json['distanceMeters'] as num).toDouble(),
      durationSeconds: json['durationSeconds'] as int,
      polylinePoints: _parsePolyline(json['polylinePoints'] as List<dynamic>?),
      calculatedAt: json['calculatedAt'] != null
          ? DateTime.parse(json['calculatedAt'] as String)
          : null,
    );
  }

  /// Parse polyline points from JSON
  static List<LatLng> _parsePolyline(List<dynamic>? points) {
    if (points == null) return [];
    return points.map((p) {
      final coord = p as List<dynamic>;
      return LatLng(coord[1] as double, coord[0] as double);
    }).toList();
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'fromStopId': fromStopId,
      'toStopId': toStopId,
      'fromStopName': fromStopName,
      'toStopName': toStopName,
      'transportType': transportType.id,
      'distanceMeters': distanceMeters,
      'durationSeconds': durationSeconds,
      'polylinePoints':
          polylinePoints.map((p) => [p.longitude, p.latitude]).toList(),
      'calculatedAt': calculatedAt?.toIso8601String(),
    };
  }

  /// Create a copy with modifications
  RouteSegment copyWith({
    String? id,
    String? fromStopId,
    String? toStopId,
    String? fromStopName,
    String? toStopName,
    TransportType? transportType,
    double? distanceMeters,
    int? durationSeconds,
    List<LatLng>? polylinePoints,
    DateTime? calculatedAt,
  }) {
    return RouteSegment(
      id: id ?? this.id,
      fromStopId: fromStopId ?? this.fromStopId,
      toStopId: toStopId ?? this.toStopId,
      fromStopName: fromStopName ?? this.fromStopName,
      toStopName: toStopName ?? this.toStopName,
      transportType: transportType ?? this.transportType,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      polylinePoints: polylinePoints ?? this.polylinePoints,
      calculatedAt: calculatedAt ?? this.calculatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        fromStopId,
        toStopId,
        fromStopName,
        toStopName,
        transportType,
        distanceMeters,
        durationSeconds,
        calculatedAt,
      ];
}
