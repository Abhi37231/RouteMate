import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import '../../data/models/route_segment_model.dart';
import 'transport_service.dart';
import 'routing_service.dart';

/// Timeline entry representing a stop in the travel timeline
class TimelineEntry {
  final int index;
  final String stopId;
  final String stopName;
  final LatLng location;
  final DateTime arrivalTime;
  final DateTime departureTime;
  final int stayDurationMinutes;
  final RouteSegment? arrivalSegment;
  final RouteSegment? departureSegment;

  const TimelineEntry({
    required this.index,
    required this.stopId,
    required this.stopName,
    required this.location,
    required this.arrivalTime,
    required this.departureTime,
    required this.stayDurationMinutes,
    this.arrivalSegment,
    this.departureSegment,
  });

  /// Get formatted arrival time
  String get arrivalTimeFormatted => DateFormat('h:mm a').format(arrivalTime);

  /// Get formatted departure time
  String get departureTimeFormatted =>
      DateFormat('h:mm a').format(departureTime);

  /// Get stay duration formatted
  String get stayDurationFormatted {
    if (stayDurationMinutes < 60) {
      return '$stayDurationMinutes min';
    }
    final hours = stayDurationMinutes ~/ 60;
    final mins = stayDurationMinutes % 60;
    if (mins == 0) {
      return '$hours hr';
    }
    return '$hours hr $mins min';
  }

  /// Get travel time from previous stop
  int get travelDurationMinutes {
    if (arrivalSegment == null) return 0;
    return arrivalSegment!.durationMinutes;
  }

  /// Get travel time formatted
  String get travelDurationFormatted {
    return _formatDuration(travelDurationMinutes);
  }

  /// Get estimated cost in USD
  double get estimatedCost {
    if (arrivalSegment == null) return 0.0;
    return _calculateCost(
      arrivalSegment!.distanceMeters,
      arrivalSegment!.transportType,
    );
  }

  double _calculateCost(double distanceMeters, TransportType type) {
    final distanceKm = distanceMeters / 1000;
    switch (type) {
      case TransportType.car:
        return distanceKm * 0.15; // $0.15 per km
      case TransportType.bus:
        return 5.0 + (distanceKm * 0.05); // $5 base + $0.05 per km
      case TransportType.train:
        return 10.0 + (distanceKm * 0.08); // $10 base + $0.08 per km
      case TransportType.flight:
        return 100.0 + (distanceKm * 0.12); // $100 base + $0.12 per km
      case TransportType.bike:
        return distanceKm * 0.02; // $0.02 per km (maintenance)
      case TransportType.walking:
        return 0.0;
    }
  }

  String get estimatedCostFormatted => '\$${estimatedCost.toStringAsFixed(2)}';

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

  /// Copy with modifications
  TimelineEntry copyWith({
    int? index,
    String? stopId,
    String? stopName,
    LatLng? location,
    DateTime? arrivalTime,
    DateTime? departureTime,
    int? stayDurationMinutes,
    RouteSegment? arrivalSegment,
    RouteSegment? departureSegment,
  }) {
    return TimelineEntry(
      index: index ?? this.index,
      stopId: stopId ?? this.stopId,
      stopName: stopName ?? this.stopName,
      location: location ?? this.location,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      departureTime: departureTime ?? this.departureTime,
      stayDurationMinutes: stayDurationMinutes ?? this.stayDurationMinutes,
      arrivalSegment: arrivalSegment ?? this.arrivalSegment,
      departureSegment: departureSegment ?? this.departureSegment,
    );
  }
}

/// Trip timeline containing all stops and segments
class TripTimeline {
  final String tripId;
  final DateTime startTime;
  final List<TimelineEntry> entries;
  final List<RouteSegment> segments;
  final DateTime? totalDuration;
  final DateTime? endTime;

  const TripTimeline({
    required this.tripId,
    required this.startTime,
    required this.entries,
    required this.segments,
    this.totalDuration,
    this.endTime,
  });

  /// Get total travel time in minutes
  int get totalTravelMinutes {
    return segments.fold(0, (sum, s) => sum + s.durationMinutes);
  }

  /// Get total stay time in minutes
  int get totalStayMinutes {
    return entries.fold(0, (sum, e) => sum + e.stayDurationMinutes);
  }

  /// Get total trip time
  int get totalTripMinutes => totalTravelMinutes + totalStayMinutes;

  /// Get total estimated cost
  double get totalEstimatedCost {
    return entries.fold(0.0, (sum, e) => sum + e.estimatedCost);
  }

  String get totalEstimatedCostFormatted =>
      '\$${totalEstimatedCost.toStringAsFixed(2)}';

  /// Get formatted total travel time
  String get totalTravelTimeFormatted {
    return _formatDuration(totalTravelMinutes);
  }

  /// Get formatted total stay time
  String get totalStayTimeFormatted {
    return _formatDuration(totalStayMinutes);
  }

  /// Get formatted total trip time
  String get totalTripTimeFormatted {
    return _formatDuration(totalTripMinutes);
  }

  /// Get end time formatted
  String get endTimeFormatted {
    if (endTime == null) return 'N/A';
    return DateFormat('h:mm a').format(endTime!);
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

  /// Create empty timeline
  factory TripTimeline.empty(String tripId, DateTime startTime) {
    return TripTimeline(
      tripId: tripId,
      startTime: startTime,
      entries: const [],
      segments: const [],
      endTime: startTime,
    );
  }
}

/// Data for a stop used in timeline calculation
class TimelineStop {
  final String id;
  final String name;
  final LatLng location;
  final int stayDurationMinutes;
  final TransportType transportType;

  const TimelineStop({
    required this.id,
    required this.name,
    required this.location,
    this.stayDurationMinutes = 60,
    this.transportType = TransportType.car,
  });
}

/// Service for calculating travel timelines
class TimelineService {
  static TimelineService? _instance;

  final RoutingService _routingService;
  final TransportService _transportService;

  TimelineService._()
      : _routingService = RoutingService.instance,
        _transportService = TransportService.instance;

  static TimelineService get instance {
    _instance ??= TimelineService._();
    return _instance!;
  }

  /// Calculate full trip timeline
  /// Takes a list of stops with their transport types and calculates
  /// arrival/departure times for each stop
  Future<TripTimeline> calculateTimeline({
    required String tripId,
    required DateTime startTime,
    required List<TimelineStop> stops,
  }) async {
    if (stops.length < 2) {
      return TripTimeline.empty(tripId, startTime);
    }

    final entries = <TimelineEntry>[];
    final segments = <RouteSegment>[];

    // First stop - starts at the given start time
    final firstStop = stops.first;
    final firstEntry = TimelineEntry(
      index: 0,
      stopId: firstStop.id,
      stopName: firstStop.name,
      location: firstStop.location,
      arrivalTime: startTime,
      departureTime:
          startTime.add(Duration(minutes: firstStop.stayDurationMinutes)),
      stayDurationMinutes: firstStop.stayDurationMinutes,
    );
    entries.add(firstEntry);

    DateTime currentTime =
        startTime.add(Duration(minutes: firstStop.stayDurationMinutes));

    // Process subsequent stops
    for (int i = 1; i < stops.length; i++) {
      final fromStop = stops[i - 1];
      final toStop = stops[i];
      final transportType = fromStop.transportType;

      // Get route from OSRM
      final routeResult = await _routingService.getRoute(
        fromStop.location,
        toStop.location,
        profile: _transportService.getOsrmProfile(transportType),
      );

      // Calculate duration (use API if available, otherwise calculate)
      final durationSeconds = _transportService.calculateDuration(
        distanceMeters: routeResult.distanceMeters,
        transportType: transportType,
        apiDurationSeconds:
            routeResult.isValid ? routeResult.durationSeconds : null,
      );

      final durationMinutes = (durationSeconds / 60).ceil();

      // Calculate arrival time
      final arrivalTime = currentTime.add(Duration(minutes: durationMinutes));
      final departureTime =
          arrivalTime.add(Duration(minutes: toStop.stayDurationMinutes));

      // Create segment
      final segment = RouteSegment(
        id: '${fromStop.id}_${toStop.id}',
        fromStopId: fromStop.id,
        toStopId: toStop.id,
        fromStopName: fromStop.name,
        toStopName: toStop.name,
        transportType: transportType,
        distanceMeters: routeResult.isValid
            ? routeResult.distanceMeters
            : _transportService.estimateDistance(
                fromStop.location,
                toStop.location,
              ),
        durationSeconds: durationSeconds,
        polylinePoints: routeResult.points,
      );
      segments.add(segment);

      // Create timeline entry
      final entry = TimelineEntry(
        index: i,
        stopId: toStop.id,
        stopName: toStop.name,
        location: toStop.location,
        arrivalTime: arrivalTime,
        departureTime: departureTime,
        stayDurationMinutes: toStop.stayDurationMinutes,
        arrivalSegment: segment,
      );
      entries.add(entry);

      currentTime = departureTime;
    }

    return TripTimeline(
      tripId: tripId,
      startTime: startTime,
      entries: entries,
      segments: segments,
      endTime: currentTime,
    );
  }

  /// Calculate timeline using existing Stop objects from the model
  Future<TripTimeline> calculateTimelineFromStops({
    required String tripId,
    required DateTime startTime,
    required List<StopTimelineData> stops,
  }) async {
    final timelineStops = stops
        .map((s) => TimelineStop(
              id: s.id,
              name: s.name,
              location: LatLng(s.latitude, s.longitude),
              stayDurationMinutes: s.stayDurationMinutes,
              transportType: TransportType.fromId(s.transportType),
            ))
        .toList();

    return calculateTimeline(
      tripId: tripId,
      startTime: startTime,
      stops: timelineStops,
    );
  }

  /// Quick calculation without API calls (uses straight-line distances)
  TripTimeline calculateTimelineQuick({
    required String tripId,
    required DateTime startTime,
    required List<TimelineStop> stops,
  }) {
    if (stops.length < 2) {
      return TripTimeline.empty(tripId, startTime);
    }

    final entries = <TimelineEntry>[];
    final segments = <RouteSegment>[];

    // First stop
    final firstStop = stops.first;
    final firstEntry = TimelineEntry(
      index: 0,
      stopId: firstStop.id,
      stopName: firstStop.name,
      location: firstStop.location,
      arrivalTime: startTime,
      departureTime:
          startTime.add(Duration(minutes: firstStop.stayDurationMinutes)),
      stayDurationMinutes: firstStop.stayDurationMinutes,
    );
    entries.add(firstEntry);

    DateTime currentTime =
        startTime.add(Duration(minutes: firstStop.stayDurationMinutes));

    // Process subsequent stops
    for (int i = 1; i < stops.length; i++) {
      final fromStop = stops[i - 1];
      final toStop = stops[i];
      final transportType = fromStop.transportType;

      // Calculate distance using straight line
      final distance = _transportService.calculateDirectDistance(
        fromStop.location,
        toStop.location,
      );

      // Calculate duration from speed
      final durationMinutes = _transportService.calculateDurationMinutes(
        distanceMeters: distance,
        transportType: transportType,
      );

      // Calculate times
      final arrivalTime = currentTime.add(Duration(minutes: durationMinutes));
      final departureTime =
          arrivalTime.add(Duration(minutes: toStop.stayDurationMinutes));

      // Create segment
      final segment = RouteSegment(
        id: '${fromStop.id}_${toStop.id}',
        fromStopId: fromStop.id,
        toStopId: toStop.id,
        fromStopName: fromStop.name,
        toStopName: toStop.name,
        transportType: transportType,
        distanceMeters: distance,
        durationSeconds: durationMinutes * 60,
        polylinePoints: [fromStop.location, toStop.location],
      );
      segments.add(segment);

      // Create entry
      final entry = TimelineEntry(
        index: i,
        stopId: toStop.id,
        stopName: toStop.name,
        location: toStop.location,
        arrivalTime: arrivalTime,
        departureTime: departureTime,
        stayDurationMinutes: toStop.stayDurationMinutes,
        arrivalSegment: segment,
      );
      entries.add(entry);

      currentTime = departureTime;
    }

    return TripTimeline(
      tripId: tripId,
      startTime: startTime,
      entries: entries,
      segments: segments,
      endTime: currentTime,
    );
  }
}

/// Simple stop data for timeline calculation (decoupled from DB model)
class StopTimelineData {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int stayDurationMinutes;
  final String transportType;

  const StopTimelineData({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.stayDurationMinutes = 60,
    this.transportType = 'car',
  });
}
