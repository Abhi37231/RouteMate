import 'dart:convert';
import 'dart:io';
import 'package:latlong2/latlong.dart';

/// Nearby place from Overpass API
class NearbyPlace {
  final String name;
  final LatLng location;
  final String type;
  final String? category;
  final double? distance;

  const NearbyPlace({
    required this.name,
    required this.location,
    required this.type,
    this.category,
    this.distance,
  });

  factory NearbyPlace.fromJson(Map<String, dynamic> json, LatLng center) {
    final tags = json['tags'] as Map<String, dynamic>? ?? {};
    final lat = json['lat'] as double?;
    final lon = json['lon'] as double?;

    if (lat == null || lon == null) {
      throw const FormatException('Missing coordinates');
    }

    final location = LatLng(lat, lon);
    final dist = const Distance().as(LengthUnit.Meter, center, location);

    return NearbyPlace(
      name: tags['name'] as String? ?? tags['brand'] as String? ?? 'Unknown',
      location: location,
      type: tags['tourism'] as String? ?? tags['amenity'] as String? ?? 'place',
      category: tags['tourism'] as String? ?? tags['amenity'] as String?,
      distance: dist,
    );
  }
}

/// Service for finding nearby places using Overpass API
/// FREE API - No API key required
class NearbyPlacesService {
  static NearbyPlacesService? _instance;

  static const String _baseUrl = 'https://overpass-api.de/api/interpreter';

  NearbyPlacesService._();

  static NearbyPlacesService get instance {
    _instance ??= NearbyPlacesService._();
    return _instance!;
  }

  /// Search for nearby places
  Future<List<NearbyPlace>> searchNearby(
    LatLng center, {
    double radiusMeters = 1000,
    List<String>? types,
    int limit = 10,
  }) async {
    try {
      // Build Overpass query
      String nodeQuery = '';
      String wayQuery = '';

      if (types == null || types.isEmpty) {
        // Default: common tourist places
        nodeQuery = '''
          node["tourism"](around:$radiusMeters,${center.latitude},${center.longitude});
          node["amenity"](around:$radiusMeters,${center.latitude},${center.longitude});
        ''';
        wayQuery = '''
          way["tourism"](around:$radiusMeters,${center.latitude},${center.longitude});
          way["amenity"](around:$radiusMeters,${center.latitude},${center.longitude});
        ''';
      } else {
        for (final type in types) {
          nodeQuery +=
              'node["$type"](around:$radiusMeters,${center.latitude},${center.longitude});';
          wayQuery +=
              'way["$type"](around:$radiusMeters,${center.latitude},${center.longitude});';
        }
      }

      final query = '''
        [out:json][timeout:10];
        (
          $nodeQuery
          $wayQuery
        );
        out center $limit;
      ''';

      final uri = Uri.parse(_baseUrl);
      final client = HttpClient();
      final request = await client.postUrl(uri);
      request.headers.set('Content-Type', 'application/x-www-form-urlencoded');
      request.headers.set('User-Agent', 'TripPlanner/1.0');
      request.write('data=${Uri.encodeComponent(query)}');

      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      client.close();

      final elements = data['elements'] as List<dynamic>? ?? [];

      final places = <NearbyPlace>[];
      for (final element in elements) {
        try {
          final place = NearbyPlace.fromJson(
            element as Map<String, dynamic>,
            center,
          );
          if (place.name != 'Unknown') {
            places.add(place);
          }
        } catch (_) {
          // Skip invalid entries
        }
      }

      // Sort by distance
      places.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));

      return places.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  /// Search for specific place types
  Future<List<NearbyPlace>> searchByCategory(
    LatLng center,
    String category, {
    double radiusMeters = 1000,
    int limit = 10,
  }) async {
    return searchNearby(
      center,
      radiusMeters: radiusMeters,
      types: [category],
      limit: limit,
    );
  }

  /// Search for restaurants
  Future<List<NearbyPlace>> searchRestaurants(
    LatLng center, {
    double radiusMeters = 1000,
    int limit = 10,
  }) async {
    return searchByCategory(center, 'restaurant',
        radiusMeters: radiusMeters, limit: limit);
  }

  /// Search for hotels
  Future<List<NearbyPlace>> searchHotels(
    LatLng center, {
    double radiusMeters = 1000,
    int limit = 10,
  }) async {
    return searchByCategory(center, 'hotel',
        radiusMeters: radiusMeters, limit: limit);
  }

  /// Search for attractions
  Future<List<NearbyPlace>> searchAttractions(
    LatLng center, {
    double radiusMeters = 1000,
    int limit = 10,
  }) async {
    return searchByCategory(center, 'attraction',
        radiusMeters: radiusMeters, limit: limit);
  }

  /// Search for gas stations
  Future<List<NearbyPlace>> searchGasStations(
    LatLng center, {
    double radiusMeters = 5000,
    int limit = 5,
  }) async {
    return searchByCategory(center, 'fuel',
        radiusMeters: radiusMeters, limit: limit);
  }

  /// Search for parking
  Future<List<NearbyPlace>> searchParking(
    LatLng center, {
    double radiusMeters = 1000,
    int limit = 5,
  }) async {
    return searchByCategory(center, 'parking',
        radiusMeters: radiusMeters, limit: limit);
  }

  /// Search for ATMs/banks
  Future<List<NearbyPlace>> searchATMs(
    LatLng center, {
    double radiusMeters = 1000,
    int limit = 5,
  }) async {
    return searchByCategory(center, 'atm',
        radiusMeters: radiusMeters, limit: limit);
  }
}
