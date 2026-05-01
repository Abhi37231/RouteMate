import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../services/nominatim_service.dart';
import '../services/nearby_places_service.dart';
import '../services/tile_cache_service.dart';

/// Location service provider
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService.instance;
});

/// Routing service provider
final routingServiceProvider = Provider<RoutingService>((ref) {
  return RoutingService.instance;
});

/// Nominatim service provider
final nominatimServiceProvider = Provider<NominatimService>((ref) {
  return NominatimService.instance;
});

/// Nearby places service provider
final nearbyPlacesServiceProvider = Provider<NearbyPlacesService>((ref) {
  return NearbyPlacesService.instance;
});

/// Tile cache service provider
final tileCacheServiceProvider = Provider<TileCacheService>((ref) {
  return TileCacheService.instance;
});

/// User location state
class UserLocationState {
  final double? latitude;
  final double? longitude;
  final bool isLoading;
  final String? error;

  const UserLocationState({
    this.latitude,
    this.longitude,
    this.isLoading = false,
    this.error,
  });

  bool get hasLocation => latitude != null && longitude != null;

  UserLocationState copyWith({
    double? latitude,
    double? longitude,
    bool? isLoading,
    String? error,
  }) {
    return UserLocationState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

/// User location notifier
class UserLocationNotifier extends StateNotifier<UserLocationState> {
  final LocationService _locationService;

  UserLocationNotifier(this._locationService)
      : super(const UserLocationState(isLoading: true));

  Future<void> getCurrentLocation() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final position = await _locationService.getCurrentPosition();
      if (position != null) {
        state = UserLocationState(
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: 'Location not available',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// User location provider
final userLocationProvider =
    StateNotifierProvider<UserLocationNotifier, UserLocationState>((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return UserLocationNotifier(locationService);
});

/// Route state for displaying route info
class RouteInfoState {
  final List<dynamic> points;
  final double distanceMeters;
  final int durationSeconds;
  final bool isLoading;
  final String? error;

  const RouteInfoState({
    this.points = const [],
    this.distanceMeters = 0,
    this.durationSeconds = 0,
    this.isLoading = false,
    this.error,
  });

  String get distanceText {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
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
}
