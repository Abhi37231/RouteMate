import 'package:latlong2/latlong.dart';

/// Transport type enumeration with associated speeds and OSRM profiles
enum TransportType {
  car('car', 'Car', 60.0, 'car'),
  bus('bus', 'Bus', 50.0, 'car'),
  train('train', 'Train', 80.0, 'car'),
  flight('flight', 'Flight', 800.0, 'car'),
  bike('bike', 'Bike', 20.0, 'bike'),
  walking('walking', 'Walking', 5.0, 'foot');

  final String id;
  final String displayName;
  final double speedKmh; // km/h
  final String osrmProfile;

  const TransportType(
      this.id, this.displayName, this.speedKmh, this.osrmProfile);

  /// Get speed in meters per second
  double get speedMetersPerSecond => speedKmh * 1000 / 3600;

  /// Get TransportType from id string
  static TransportType fromId(String id) {
    return TransportType.values.firstWhere(
      (t) => t.id == id.toLowerCase(),
      orElse: () => TransportType.car,
    );
  }

  /// Get all transport types for UI
  static List<TransportType> get all => TransportType.values;
}

/// Service for handling transport-related calculations
class TransportService {
  static TransportService? _instance;

  TransportService._();

  static TransportService get instance {
    _instance ??= TransportService._();
    return _instance!;
  }

  /// Calculate duration in seconds based on distance and transport type
  /// Uses API duration if available, otherwise calculates from speed
  int calculateDuration({
    required double distanceMeters,
    required TransportType transportType,
    int? apiDurationSeconds,
  }) {
    // If we have valid API duration, use it
    if (apiDurationSeconds != null && apiDurationSeconds > 0) {
      return apiDurationSeconds;
    }

    // Otherwise calculate from speed
    if (distanceMeters <= 0) return 0;

    final speedMs = transportType.speedMetersPerSecond;
    if (speedMs <= 0) return 0;

    final duration = distanceMeters / speedMs;
    return duration.ceil();
  }

  /// Calculate travel time in minutes
  int calculateDurationMinutes({
    required double distanceMeters,
    required TransportType transportType,
    int? apiDurationSeconds,
  }) {
    final seconds = calculateDuration(
      distanceMeters: distanceMeters,
      transportType: transportType,
      apiDurationSeconds: apiDurationSeconds,
    );
    return (seconds / 60).ceil();
  }

  /// Get OSRM profile for transport type
  String getOsrmProfile(TransportType transportType) {
    return transportType.osrmProfile;
  }

  /// Get display name for transport type
  String getDisplayName(TransportType transportType) {
    return transportType.displayName;
  }

  /// Calculate straight-line distance between two points
  double calculateDirectDistance(LatLng start, LatLng end) {
    return const Distance().as(LengthUnit.Meter, start, end);
  }

  /// Estimate distance when API fails (straight-line with multiplier)
  double estimateDistance(LatLng start, LatLng end) {
    final direct = calculateDirectDistance(start, end);
    // Add 20% for road vs straight line
    return direct * 1.2;
  }

  /// Format duration for display
  String formatDuration(int seconds) {
    if (seconds < 60) {
      return '$seconds sec';
    }
    final minutes = seconds ~/ 60;
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

  /// Format duration from minutes
  String formatDurationFromMinutes(int minutes) {
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
