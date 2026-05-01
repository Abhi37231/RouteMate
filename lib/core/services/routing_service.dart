import 'dart:convert';
import 'dart:io';
import 'package:latlong2/latlong.dart';

/// Route result containing path and metadata
class RouteResult {
  final List<LatLng> points;
  final double distanceMeters;
  final int durationSeconds;
  final String? error;

  const RouteResult({
    required this.points,
    required this.distanceMeters,
    required this.durationSeconds,
    this.error,
  });

  bool get isValid => error == null && points.isNotEmpty;

  double get distanceKm => distanceMeters / 1000;

  String get distanceText {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${distanceKm.toStringAsFixed(1)} km';
  }

  String get durationText {
    if (durationSeconds < 60) {
      return '${durationSeconds} sec';
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

  factory RouteResult.error(String message) {
    return RouteResult(
      points: [],
      distanceMeters: 0,
      durationSeconds: 0,
      error: message,
    );
  }
}

/// Service for routing using OSRM (Open Source Routing Machine)
/// FREE API - No API key required
class RoutingService {
  static RoutingService? _instance;

  // OSRM public demo server (free, rate-limited)
  static const String _baseUrl = 'https://router.project-osrm.org';

  RoutingService._();

  static RoutingService get instance {
    _instance ??= RoutingService._();
    return _instance!;
  }

  /// Get route between two points using OSRM
  Future<RouteResult> getRoute(
    LatLng start,
    LatLng end, {
    String profile = 'driving-car',
  }) async {
    return getRouteViaPoints([start, end], profile: profile);
  }

  /// Get route through multiple waypoints
  Future<RouteResult> getRouteViaPoints(
    List<LatLng> waypoints, {
    String profile = 'driving-car',
  }) async {
    if (waypoints.length < 2) {
      return RouteResult.error('Need at least 2 waypoints');
    }

    try {
      // Build coordinate string: lon,lat;lon,lat
      final coords =
          waypoints.map((p) => '${p.longitude},${p.latitude}').join(';');

      final url = Uri.parse(
        '$_baseUrl/route/v1/$profile/$coords?overview=full&geometries=geojson',
      );

      final client = HttpClient();
      final request = await client.getUrl(url);
      request.headers.set('User-Agent', 'TripPlanner/1.0');
      final response = await request.close();

      if (response.statusCode != 200) {
        return RouteResult.error('HTTP ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      client.close();

      final code = data['code'] as String?;
      if (code != 'Ok') {
        return RouteResult.error(
            data['message']?.toString() ?? 'Unknown error');
      }

      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return RouteResult.error('No route found');
      }

      final route = routes.first as Map<String, dynamic>;
      final geometry = route['geometry'] as Map<String, dynamic>?;
      final coordinates = geometry?['coordinates'] as List<dynamic>?;

      if (coordinates == null) {
        return RouteResult.error('No geometry data');
      }

      // Convert from [lon, lat] to LatLng
      final points = coordinates.map((c) {
        final coord = c as List<dynamic>;
        return LatLng(coord[1] as double, coord[0] as double);
      }).toList();

      final distance = (route['distance'] as num?)?.toDouble() ?? 0;
      final duration = (route['duration'] as num?)?.toInt() ?? 0;

      return RouteResult(
        points: points,
        distanceMeters: distance,
        durationSeconds: duration,
      );
    } on SocketException {
      return RouteResult.error('No internet connection');
    } catch (e) {
      return RouteResult.error(e.toString());
    }
  }

  /// Get optimized route using nearest neighbor algorithm
  /// This is a client-side optimization when OSRM trip endpoint is unavailable
  Future<RouteResult> getOptimizedRoute(
    LatLng start,
    List<LatLng> stops, {
    String profile = 'driving-car',
  }) async {
    if (stops.isEmpty) {
      return getRoute(start, start, profile: profile);
    }

    if (stops.length == 1) {
      return getRoute(start, stops.first, profile: profile);
    }

    // Use nearest neighbor algorithm for basic optimization
    final optimized = _nearestNeighbor(start, stops);

    // Build full route
    final allPoints = [start, ...optimized];
    final List<LatLng> fullRoute = [];
    double totalDistance = 0;
    int totalDuration = 0;

    for (int i = 0; i < allPoints.length - 1; i++) {
      final segment = await getRouteViaPoints(
        [allPoints[i], allPoints[i + 1]],
        profile: profile,
      );

      if (!segment.isValid) {
        return segment;
      }

      // Add points (skip first to avoid duplicates)
      fullRoute.addAll(segment.points.skip(i > 0 ? 1 : 0));
      totalDistance += segment.distanceMeters;
      totalDuration += segment.durationSeconds;
    }

    return RouteResult(
      points: fullRoute,
      distanceMeters: totalDistance,
      durationSeconds: totalDuration,
    );
  }

  /// Nearest neighbor algorithm for route optimization
  List<LatLng> _nearestNeighbor(LatLng start, List<LatLng> stops) {
    if (stops.isEmpty) return [];

    final remaining = List<LatLng>.from(stops);
    final result = <LatLng>[];
    var current = start;
    final distance = const Distance();

    while (remaining.isNotEmpty) {
      LatLng? nearest;
      double minDist = double.infinity;
      int nearestIndex = 0;

      for (int i = 0; i < remaining.length; i++) {
        final d = distance.as(LengthUnit.Meter, current, remaining[i]);
        if (d < minDist) {
          minDist = d;
          nearest = remaining[i];
          nearestIndex = i;
        }
      }

      if (nearest != null) {
        result.add(nearest);
        remaining.removeAt(nearestIndex);
        current = nearest;
      }
    }

    return result;
  }

  /// Calculate straight-line distance for simple cases
  double calculateDirectDistance(LatLng start, LatLng end) {
    return const Distance().as(LengthUnit.Meter, start, end);
  }

  /// Format distance for display
  String formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}
