import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/services/nearby_places_service.dart';
import '../../../../core/services/routing_service.dart';
import '../../../../core/services/timeline_service.dart';
import '../../../../core/services/transport_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../data/models/stop_model.dart';
import '../../../../data/models/trip_model.dart';
import '../../../../features/trips/presentation/providers/trip_providers.dart';
import '../../../../features/trips/presentation/widgets/timeline_card_widget.dart';
import '../widgets/add_stop_bottom_sheet.dart';

/// Map screen using OpenStreetMap with modern dark UI and draggable bottom sheet
class MapScreen extends ConsumerStatefulWidget {
  final Trip? trip;
  final Function(Stop)? onStopAdded;
  final List<Stop> existingStops;

  const MapScreen({
    Key? key,
    this.trip,
    this.onStopAdded,
    this.existingStops = const [],
  }) : super(key: key);

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen>
    with TickerProviderStateMixin {
  final MapController _mapController = MapController();
  List<Stop> _stops = [];
  List<LatLng> _routePoints = [];

  // Draggable scrollable sheet controller
  final DraggableScrollableController _sheetController =
      DraggableScrollableController();

  // User location
  LatLng? _userLocation;
  bool _isLoadingLocation = false;

  // Route info from OSRM
  bool _isLoadingRoute = false;
  List<LatLng> _osrmRoutePoints = [];

  // Nearby places
  List<NearbyPlace> _nearbyPlaces = [];
  bool _isLoadingNearby = false;

  // Location stream for live tracking
  StreamSubscription<Position>? _locationSubscription;

  // Default center (India)
  static const LatLng _defaultCenter = LatLng(20.5937, 78.9629);
  static const double _defaultZoom = 5.0;

  // OpenStreetMap tile server (free)
  static const String _tileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String _attribution =
      '© OpenStreetMap contributors | Free & Open Source';

  @override
  void initState() {
    super.initState();
    if (widget.trip != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _syncStopsFromProvider();
      });
    } else {
      _stops = List.from(widget.existingStops);
      _updateRoutePoints();
    }
    _initUserLocation();
  }

  // --------------------- LOCATION ---------------------

  Future<void> _initUserLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      final locationService = ref.read(locationServiceProvider);
      final hasPermission = await locationService.checkPermissions();
      if (hasPermission) {
        final position = await locationService.getCurrentPosition();
        if (position != null && mounted) {
          setState(() {
            _userLocation = LatLng(position.latitude, position.longitude);
            _isLoadingLocation = false;
          });
          _startLocationTracking();
        }
      } else {
        if (mounted) setState(() => _isLoadingLocation = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _startLocationTracking() {
    final locationService = ref.read(locationServiceProvider);
    _locationSubscription =
        locationService.getPositionStream().listen((position) {
      if (mounted) {
        setState(() {
          _userLocation = LatLng(position.latitude, position.longitude);
        });
      }
    });
  }

  void _centerOnUser() {
    if (_userLocation != null) {
      _mapController.move(_userLocation!, 15);
    }
  }

  // --------------------- STOPS MANAGEMENT ---------------------

  void _syncStopsFromProvider() {
    final stopsAsync = ref.read(stopsProvider(widget.trip!.id));
    stopsAsync.when(
      data: (stops) {
        if (mounted) {
          setState(() {
            _stops = stops;
            _updateRoutePoints();
            // Automatically calculate route when stops change
            if (_stops.length >= 2) {
              _getRoute();
            }
          });
        }
      },
      loading: () {},
      error: (err, _) {
        if (mounted) {
          _showSnackBar('Error loading stops: $err');
        }
      },
    );
  }

  void _updateRoutePoints() {
    _routePoints = _stops
        .where((stop) => stop.latitude != null && stop.longitude != null)
        .map((stop) => LatLng(stop.latitude!, stop.longitude!))
        .toList();
  }

  void _addStopAtCenter() {
    final center = _mapController.camera.center;
    _showAddStopBottomSheet(center);
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    _showAddStopBottomSheet(point);
  }

  void _showAddStopBottomSheet(LatLng point) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddStopBottomSheet(
        location: point,
        tripId: widget.trip?.id ?? '',
        stopIndex: _stops.length,
        previousStops: _stops.isNotEmpty
            ? _stops.map((s) => LatLng(s.latitude, s.longitude)).toList()
            : null,
        startTime: _stops.isEmpty ? DateTime.now() : null,
        onAddStop: (name, note, stayMinutes, transportType) async {
          await _handleAddStop(
            name: name,
            point: point,
            note: note,
            stayMinutes: stayMinutes,
            transportType: TransportType.fromId(transportType),
          );
        },
      ),
    );
  }

  Future<void> _handleAddStop({
    required String name,
    required LatLng point,
    String? note,
    int stayMinutes = 60,
    TransportType transportType = TransportType.car,
  }) async {
    if (widget.trip != null) {
      try {
        await ref.read(stopsProvider(widget.trip!.id).notifier).addStop(
              name: name,
              latitude: point.latitude,
              longitude: point.longitude,
              note: note,
              durationMinutes: stayMinutes,
              transportType: transportType.id,
            );
        if (mounted) {
          _showSnackBar('Stop "$name" added');
          // Expand timeline to show new stop
          _expandTimeline();
        }
      } catch (e) {
        if (mounted) _showSnackBar('Error adding stop: $e');
      }
    } else {
      final now = DateTime.now();
      final newStop = Stop(
        id: now.millisecondsSinceEpoch.toString(),
        tripId: '',
        name: name,
        latitude: point.latitude,
        longitude: point.longitude,
        note: note,
        durationMinutes: stayMinutes,
        orderIndex: _stops.length,
        transportType: transportType.id,
        createdAt: now,
        updatedAt: now,
      );

      setState(() {
        _stops.add(newStop);
        _updateRoutePoints();
      });

      widget.onStopAdded?.call(newStop);
      _showSnackBar('Stop "$name" added');
      _expandTimeline();
    }
  }

  void _expandTimeline() {
    _sheetController.animateTo(
      0.5,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _removeStop(Stop stop) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text(
          'Remove Stop',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove "${stop.name}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);
              if (widget.trip != null) {
                try {
                  await ref
                      .read(stopsProvider(widget.trip!.id).notifier)
                      .deleteStop(stop.id);
                } catch (e) {
                  if (mounted) _showSnackBar('Error removing stop: $e');
                }
              } else {
                setState(() {
                  _stops.removeWhere((s) => s.id == stop.id);
                  _updateRoutePoints();
                });
              }
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _centerOnStops() {
    if (_stops.isEmpty) return;

    if (_stops.length == 1) {
      _mapController.move(
        LatLng(_stops.first.latitude!, _stops.first.longitude!),
        15.0,
      );
    } else {
      double minLat = 90, maxLat = -90, minLng = 180, maxLng = -180;
      for (final stop in _stops) {
        if (stop.latitude! < minLat) minLat = stop.latitude!;
        if (stop.latitude! > maxLat) maxLat = stop.latitude!;
        if (stop.longitude! < minLng) minLng = stop.longitude!;
        if (stop.longitude! > maxLng) maxLng = stop.longitude!;
      }

      final center = LatLng(
        (minLat + maxLat) / 2,
        (minLng + maxLng) / 2,
      );

      _mapController.move(center, 12.0);
    }
  }

  // --------------------- ROUTE ---------------------

  Future<void> _getRoute() async {
    if (_stops.length < 2) return;

    setState(() => _isLoadingRoute = true);
    try {
      final routingService = ref.read(routingServiceProvider);
      final stops =
          _stops.map((s) => LatLng(s.latitude!, s.longitude!)).toList();

      final result = await routingService.getOptimizedRoute(
          stops.first, stops.skip(1).toList());

      if (mounted && result.isValid) {
        _osrmRoutePoints = result.points;
        _routePoints = result.points;

        setState(() {
          _isLoadingRoute = false;
        });

        _showSnackBar('Route: ${result.distanceText} • ${result.durationText}');
      } else {
        setState(() => _isLoadingRoute = false);
        if (mounted) {
          _showSnackBar('Route error: ${result.error}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingRoute = false);
        _showSnackBar('Error: $e');
      }
    }
  }

  // --------------------- SEARCH & NEARBY ---------------------

  Future<List<Map<String, dynamic>>> _searchCity(String query) async {
    if (query.trim().isEmpty) return [];

    final client = HttpClient();
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query.trim())}&format=json&limit=5',
      );
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'RouteMate/1.0 (Flutter App)');
      final response = await request.close();

      if (response.statusCode != 200) {
        throw Exception('Search failed with status ${response.statusCode}');
      }

      final body = await response.transform(utf8.decoder).join();
      final data = jsonDecode(body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    } finally {
      client.close();
    }
  }

  void _showSearchDialog() {
    final searchController = TextEditingController();
    List<Map<String, dynamic>> results = [];
    bool isSearching = false;
    String? error;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.darkElevated,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Search City',
              style: TextStyle(color: Colors.white),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: searchController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter city name...',
                      hintStyle: TextStyle(color: AppColors.textSecondary),
                      prefixIcon:
                          Icon(Icons.search, color: AppColors.textSecondary),
                      suffixIcon: isSearching
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : IconButton(
                              icon: Icon(Icons.arrow_forward,
                                  color: AppColors.primaryBlue),
                              onPressed: () async {
                                setDialogState(() {
                                  isSearching = true;
                                  error = null;
                                });
                                try {
                                  final searchResults =
                                      await _searchCity(searchController.text);
                                  setDialogState(() {
                                    results = searchResults;
                                    isSearching = false;
                                  });
                                } catch (e) {
                                  setDialogState(() {
                                    error = e.toString();
                                    isSearching = false;
                                  });
                                }
                              },
                            ),
                      filled: true,
                      fillColor: AppColors.darkCard,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (value) async {
                      setDialogState(() {
                        isSearching = true;
                        error = null;
                      });
                      try {
                        final searchResults = await _searchCity(value);
                        setDialogState(() {
                          results = searchResults;
                          isSearching = false;
                        });
                      } catch (e) {
                        setDialogState(() {
                          error = e.toString();
                          isSearching = false;
                        });
                      }
                    },
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      error!,
                      style: TextStyle(color: AppColors.error),
                    ),
                  ],
                  if (results.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white24),
                    Flexible(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (context, index) {
                            final result = results[index];
                            final lat = double.tryParse(
                                  result['lat']?.toString() ?? '',
                                ) ??
                                0.0;
                            final lon = double.tryParse(
                                  result['lon']?.toString() ?? '',
                                ) ??
                                0.0;
                            return ListTile(
                              leading: Icon(Icons.location_on,
                                  color: AppColors.primaryBlue),
                              title: Text(
                                result['display_name'] ?? 'Unknown',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white),
                              ),
                              subtitle: Text(
                                'Lat: ${lat.toStringAsFixed(4)}, '
                                'Lng: ${lon.toStringAsFixed(4)}',
                                style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                                _mapController.move(LatLng(lat, lon), 12.0);
                              },
                            );
                          },
                        ),
                      ),
                    ),
                  ] else if (!isSearching &&
                      searchController.text.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'No results found',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Close',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showNearbyPlaces() async {
    if (_userLocation == null) {
      _showSnackBar('Location not available');
      return;
    }

    setState(() => _isLoadingNearby = true);
    try {
      final nearbyService = ref.read(nearbyPlacesServiceProvider);
      final places =
          await nearbyService.searchNearby(_userLocation!, limit: 10);

      if (mounted) {
        setState(() {
          _nearbyPlaces = places;
          _isLoadingNearby = false;
        });
        _showNearbyPlacesSheet();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingNearby = false);
    }
  }

  void _showNearbyPlacesSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.darkBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nearby Places',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            if (_nearbyPlaces.isEmpty)
              Text(
                'No places found nearby',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _nearbyPlaces.length,
                  itemBuilder: (context, index) {
                    final place = _nearbyPlaces[index];
                    return ListTile(
                      leading: Icon(Icons.place, color: AppColors.primaryBlue),
                      title: Text(
                        place.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        place.type,
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: place.distance != null
                          ? Text(
                              '${(place.distance! / 1000).toStringAsFixed(1)} km',
                              style: TextStyle(color: AppColors.textSecondary),
                            )
                          : null,
                      onTap: () {
                        _mapController.move(place.location, 15);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --------------------- SNACKBAR ---------------------

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: AppColors.darkElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // --------------------- UI BUILD ---------------------

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Listen to stops provider updates
    if (widget.trip != null) {
      ref.listen(stopsProvider(widget.trip!.id), (previous, next) {
        next.when(
          data: (stops) {
            if (mounted) {
              setState(() {
                _stops = stops;
                _updateRoutePoints();
                if (_stops.length >= 2) {
                  _getRoute();
                }
              });
            }
          },
          loading: () {},
          error: (err, _) {
            if (mounted) _showSnackBar('Error loading stops: $err');
          },
        );
      });
    }

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Full screen map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _stops.isNotEmpty
                  ? LatLng(_stops.first.latitude!, _stops.first.longitude!)
                  : _defaultCenter,
              initialZoom: _defaultZoom,
              onTap: _onMapTap,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              // OSM Tile Layer
              TileLayer(
                urlTemplate: _tileUrlTemplate,
                userAgentPackageName: 'com.routemate.app',
                maxZoom: 19,
              ),

              // Route polyline
              if (_routePoints.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _routePoints,
                      color: AppColors.primaryBlue,
                      strokeWidth: 4.0,
                    ),
                  ],
                ),

              // Stop markers
              MarkerLayer(
                markers: _stops.asMap().entries.map((entry) {
                  final index = entry.key;
                  final stop = entry.value;
                  final isStart = index == 0;
                  final isEnd = index == _stops.length - 1;

                  return Marker(
                    point: LatLng(stop.latitude!, stop.longitude!),
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () => _showStopDetails(stop),
                      child: _buildStopMarker(index, isStart, isEnd),
                    ),
                  );
                }).toList(),
              ),

              // User location marker
              if (_userLocation != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _userLocation!,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryBlue.withOpacity(0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.my_location,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),

          // Draggable bottom sheet with timeline
          _buildDraggableTimeline(),

          // Floating action button
          _buildFloatingActionButton(),

          // Loading overlay
          if (_isLoadingRoute)
            const Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryBlue,
                  strokeWidth: 3,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --------------------- CUSTOM WIDGETS ---------------------

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.darkBackground.withOpacity(0.8),
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
        tooltip: 'Back',
      ),
      title: Text(
        widget.trip?.name ?? 'Plan Trip',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 18,
        ),
      ),
      actions: [
        // Search city
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white70),
          onPressed: _showSearchDialog,
          tooltip: 'Search city',
        ),
        // Route overview / center on stops
        if (_stops.isNotEmpty)
          IconButton(
            icon: const Icon(Icons.center_focus_strong, color: Colors.white70),
            onPressed: _centerOnStops,
            tooltip: 'Center on stops',
          ),
        // My location
        IconButton(
          icon: _isLoadingLocation
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.my_location, color: Colors.white70),
          onPressed: _centerOnUser,
          tooltip: 'My location',
        ),
        // Nearby places
        IconButton(
          icon: _isLoadingNearby
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.location_searching, color: Colors.white70),
          onPressed: _showNearbyPlaces,
          tooltip: 'Nearby places',
        ),
      ],
    );
  }

  Widget _buildStopMarker(int index, bool isStart, bool isEnd) {
    Color color;
    IconData icon;

    if (isStart) {
      color = AppColors.startGreen;
      icon = Icons.play_arrow;
    } else if (isEnd) {
      color = AppColors.endRed;
      icon = Icons.flag;
    } else {
      color = AppColors.stopBlue;
      icon = Icons.location_on;
    }

    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: isStart || isEnd
              ? Icon(icon, color: Colors.white, size: 20)
              : Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDraggableTimeline() {
    if (_stops.isEmpty) {
      return Positioned(
        bottom: 0,
        left: 0,
        right: 0,
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: AppColors.darkElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: TimelineEmptyCard(
            onAddStop: _addStopAtCenter,
          ),
        ),
      );
    }

    return Positioned.fill(
      child: DraggableScrollableSheet(
        controller: _sheetController,
        initialChildSize: 0.15,
        minChildSize: 0.1,
        maxChildSize: 0.85,
        snap: true,
        snapSizes: const [0.15, 0.5, 0.85],
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: AppColors.darkElevated,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag handle
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Timeline content
                Expanded(
                  child: _buildTimelineContent(scrollController),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimelineContent(ScrollController scrollController) {
    if (widget.trip == null) {
      // Local mode: build simple timeline
      return _buildLocalTimeline(scrollController);
    }

    // Trip mode: use Riverpod timeline provider
    final timelineAsync = ref.watch(tripTimelineProvider(widget.trip!.id));

    return timelineAsync.when(
      data: (timeline) {
        if (timeline.entries.isEmpty) {
          return TimelineEmptyCard(onAddStop: _addStopAtCenter);
        }

        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.only(bottom: 100),
          children: [
            TimelineSummaryHeader(
              timeline: timeline,
              onRecalculate: () {
                if (widget.trip != null) {
                  ref.invalidate(tripTimelineProvider(widget.trip!.id));
                }
              },
            ),
            const SizedBox(height: 8),
            ...timeline.entries.asMap().entries.expand((entry) {
              final index = entry.key;
              final timelineEntry = entry.value;
              final isFirst = index == 0;
              final isLast = index == timeline.entries.length - 1;

              return [
                // Transport segment (if not first)
                if (!isFirst)
                  RouteSegmentCardWidget(
                    entry: timelineEntry,
                    showTransport: true,
                  ),
                // Stop card
                StopCardWidget(
                  entry: timelineEntry,
                  isFirst: isFirst,
                  isLast: isLast,
                  onTap: () {
                    // Center map on stop
                    _mapController.move(
                      LatLng(
                        _stops[index].latitude!,
                        _stops[index].longitude!,
                      ),
                      15,
                    );
                    // Collapse sheet
                    _sheetController.animateTo(
                      0.15,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                  onEdit: () {
                    _showSnackBar('Edit: ${_stops[index].name}');
                  },
                  onDelete: () => _removeStop(_stops[index]),
                ),
              ];
            }).toList(),
          ],
        );
      },
      loading: () => const TimelineLoadingCard(),
      error: (err, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error: $err',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ),
    );
  }

  Widget _buildLocalTimeline(ScrollController scrollController) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.only(bottom: 100),
      children: [
        // Simple header
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primaryBlue,
                AppColors.primaryDark,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.timeline, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                '${_stops.length} stops',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        // Simple stop list
        ..._stops.asMap().entries.map((entry) {
          final index = entry.key;
          final stop = entry.value;
          final isFirst = index == 0;
          final isLast = index == _stops.length - 1;
          final now = DateTime.now();

          return StopCardWidget(
            entry: TimelineEntry(
              index: index,
              stopId: stop.id,
              stopName: stop.name,
              location: LatLng(stop.latitude!, stop.longitude!),
              arrivalTime: now,
              departureTime: now.add(Duration(minutes: stop.durationMinutes)),
              stayDurationMinutes: stop.durationMinutes,
            ),
            isFirst: isFirst,
            isLast: isLast,
            onTap: () {
              _mapController.move(
                LatLng(stop.latitude!, stop.longitude!),
                15,
              );
            },
            onDelete: () => _removeStop(stop),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return Positioned(
      right: 16,
      bottom: _stops.isEmpty
          ? 140 // Above empty timeline
          : MediaQuery.of(context).size.height * 0.15 + 16,
      // Above draggable sheet
      child: FloatingActionButton.extended(
        onPressed: _addStopAtCenter,
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location),
        label: const Text('Add Stop'),
        elevation: 4,
      ),
    );
  }

  void _showStopDetails(Stop stop) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.darkElevated,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.stopBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${_stops.indexOf(stop) + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    stop.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: AppColors.error),
                  onPressed: () {
                    Navigator.pop(context);
                    _removeStop(stop);
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Location: ${stop.latitude?.toStringAsFixed(4)}, ${stop.longitude?.toStringAsFixed(4)}',
              style: TextStyle(color: AppColors.textSecondary),
            ),
            if (stop.note != null && stop.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Note: ${stop.note}',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  _mapController.move(
                    LatLng(stop.latitude!, stop.longitude!),
                    15.0,
                  );
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.navigation),
                label: const Text('Go to location'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _mapController.dispose();
    _sheetController.dispose();
    _locationSubscription?.cancel();
    super.dispose();
  }
}
