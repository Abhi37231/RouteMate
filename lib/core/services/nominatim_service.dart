import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:latlong2/latlong.dart';

/// Place result from Nominatim search
class PlaceResult {
  final String displayName;
  final String? name;
  final LatLng location;
  final String? type;
  final String? placeId;
  final String? category;

  const PlaceResult({
    required this.displayName,
    this.name,
    required this.location,
    this.type,
    this.placeId,
    this.category,
  });

  factory PlaceResult.fromJson(Map<String, dynamic> json) {
    return PlaceResult(
      displayName: json['display_name'] as String? ?? '',
      name: json['name'] as String?,
      location: LatLng(
        double.parse(json['lat'] as String),
        double.parse(json['lon'] as String),
      ),
      type: json['type'] as String?,
      placeId: json['place_id']?.toString(),
      category: json['category'] as String?,
    );
  }

  /// Get short name (first part of display name)
  String get shortName {
    final parts = displayName.split(',');
    return parts.isNotEmpty ? parts[0].trim() : displayName;
  }
}

/// Service for place search using Nominatim (OpenStreetMap)
/// FREE API - No API key required
/// Implements debounced autocomplete
class NominatimService {
  static NominatimService? _instance;

  static const String _baseUrl = 'https://nominatim.openstreetmap.org';

  // Debounce timer
  Timer? _debounceTimer;
  final _debounceDuration = const Duration(milliseconds: 300);

  // Cache for recent searches
  final Map<String, List<PlaceResult>> _cache = {};
  static const int _maxCacheSize = 50;

  NominatimService._();

  static NominatimService get instance {
    _instance ??= NominatimService._();
    return _instance!;
  }

  /// Search places with debounce
  /// Returns a function that can be called to cancel previous searches
  Stream<List<PlaceResult>> searchWithDebounce(String query) {
    final controller = StreamController<List<PlaceResult>>();

    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      controller.add([]);
      controller.close();
      return controller.stream;
    }

    // Check cache first
    final cacheKey = query.toLowerCase().trim();
    if (_cache.containsKey(cacheKey)) {
      controller.add(_cache[cacheKey]!);
      controller.close();
      return controller.stream;
    }

    _debounceTimer = Timer(_debounceDuration, () async {
      try {
        final results = await search(query);
        _addToCache(cacheKey, results);
        controller.add(results);
      } catch (e) {
        controller.addError(e);
      } finally {
        controller.close();
      }
    });

    return controller.stream;
  }

  /// Cancel any pending search
  void cancelSearch() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }

  /// Search places by query
  Future<List<PlaceResult>> search(String query, {int limit = 5}) async {
    if (query.trim().isEmpty) return [];

    try {
      final uri = Uri.parse(
        '$_baseUrl/search?q=${Uri.encodeComponent(query.trim())}&format=json&limit=$limit&addressdetails=1',
      );

      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'TripPlanner/1.0 (Flutter App)');
      request.headers.set('Accept', 'application/json');

      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Search failed: HTTP ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as List<dynamic>;

      client.close();

      return data
          .map((item) => PlaceResult.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Search with additional filters
  Future<List<PlaceResult>> searchWithFilters(
    String query, {
    int limit = 5,
    String? countryCodes,
    String? featureType,
  }) async {
    if (query.trim().isEmpty) return [];

    try {
      var uriString =
          '$_baseUrl/search?q=${Uri.encodeComponent(query.trim())}&format=json&limit=$limit&addressdetails=1';

      if (countryCodes != null) {
        uriString += '&countrycodes=$countryCodes';
      }

      if (featureType != null) {
        uriString += '&featuretype=$featureType';
      }

      final uri = Uri.parse(uriString);

      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'TripPlanner/1.0 (Flutter App)');
      request.headers.set('Accept', 'application/json');

      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Search failed: HTTP ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as List<dynamic>;

      client.close();

      return data
          .map((item) => PlaceResult.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Reverse geocode (coordinates to address)
  Future<String?> reverseGeocode(LatLng location) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/reverse?lat=${location.latitude}&lon=${location.longitude}&format=json',
      );

      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'TripPlanner/1.0');

      final response = await request.close();

      if (response.statusCode != 200) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      client.close();

      return data['display_name'] as String?;
    } catch (e) {
      return null;
    }
  }

  /// Get details for a specific place
  Future<PlaceResult?> getPlaceDetails(String placeId) async {
    try {
      final uri = Uri.parse(
        '$_baseUrl/details?place_id=$placeId&format=json&addressdetails=1',
      );

      final client = HttpClient();
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'TripPlanner/1.0');

      final response = await request.close();

      if (response.statusCode != 200) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      client.close();

      return PlaceResult.fromJson(data);
    } catch (e) {
      return null;
    }
  }

  void _addToCache(String query, List<PlaceResult> results) {
    _cache[query] = results;

    // Limit cache size
    if (_cache.length > _maxCacheSize) {
      final keys = _cache.keys.take(_cache.length - _maxCacheSize);
      for (final key in keys) {
        _cache.remove(key);
      }
    }
  }

  /// Clear search cache
  void clearCache() {
    _cache.clear();
  }

  /// Dispose
  void dispose() {
    _debounceTimer?.cancel();
    _cache.clear();
  }
}
