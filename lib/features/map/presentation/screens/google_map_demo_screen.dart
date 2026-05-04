import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 1. CONTROLLER / SERVICE FOR MAP LOGIC (CLEAN CODE)
/// This separates the map logic from the UI.
class MapStateController extends ChangeNotifier {
  GoogleMapController? mapController;
  
  // Default to Rameswaram
  LatLng _selectedLocation = const LatLng(9.2876, 79.3129); 
  String _locationName = "Rameswaram";

  LatLng get selectedLocation => _selectedLocation;
  String get locationName => _locationName;

  void onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  // 2. AUTO CAMERA MOVE & MARKER UPDATE
  void updateLocation(LatLng newLocation, String newName) {
    _selectedLocation = newLocation;
    _locationName = newName;
    notifyListeners();
    _animateToLocation(newLocation);
  }

  void _animateToLocation(LatLng location) {
    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: 15.0, // Proper zoom level (14-16)
        ),
      ),
    );
  }
}

/// 2. MAIN MAP SCREEN UI
class GoogleMapScreenDemo extends StatefulWidget {
  const GoogleMapScreenDemo({Key? key}) : super(key: key);

  @override
  State<GoogleMapScreenDemo> createState() => _GoogleMapScreenDemoState();
}

class _GoogleMapScreenDemoState extends State<GoogleMapScreenDemo> {
  final MapStateController _mapStateController = MapStateController();

  // Bottom sheet initial size
  final double _initialSheetSize = 0.3;

  @override
  void initState() {
    super.initState();
    _mapStateController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _mapStateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine bottom padding for Google Map to prevent hiding the Google logo 
    // and to keep the center of the map visible above the bottom sheet.
    final screenHeight = MediaQuery.of(context).size.height;
    final bottomPadding = screenHeight * _initialSheetSize;

    return Scaffold(
      appBar: AppBar(
        // 6. SEARCH TITLE: Dynamic location name instead of static text
        title: Text('Exploring: ${_mapStateController.locationName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              // Example: Dynamically updating location to Chennai
              _mapStateController.updateLocation(
                const LatLng(13.0827, 80.2707), 
                "Chennai",
              );
            },
            tooltip: 'Search (Demo: Go to Chennai)',
          )
        ],
      ),
      // 5. BOTTOM PANEL FIX: Added SafeArea to ensure UI doesn't cut into notches
      body: SafeArea(
        child: Stack(
          children: [
            // --- 1. GOOGLE MAP LAYER ---
            GoogleMap(
              // 1. MAP CAMERA ISSUE: Center properly on selected location with correct zoom
              initialCameraPosition: CameraPosition(
                target: _mapStateController.selectedLocation,
                zoom: 15.0, 
              ),
              onMapCreated: _mapStateController.onMapCreated,
              
              // 3. MARKER ISSUE: Add marker at selected place
              markers: {
                Marker(
                  markerId: const MarkerId('selected_location'),
                  position: _mapStateController.selectedLocation,
                  infoWindow: InfoWindow(title: _mapStateController.locationName),
                ),
              },
              
              // Tap on map to move marker
              onTap: (LatLng newLocation) {
                _mapStateController.updateLocation(newLocation, "Selected Pin");
              },
              
              // Add padding to ensure Google Map controls/logo stay above the bottom sheet
              padding: EdgeInsets.only(bottom: bottomPadding),
            ),

            // --- 2. ADD STOP BUTTON LAYER ---
            // 4. UI OVERLAP FIX: Use Positioned properly to keep button above bottom panel
            Positioned(
              bottom: bottomPadding + 20, // 20px padding above the bottom panel
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: () {
                  // Add stop logic here
                },
                label: const Text('Add Stop'),
                icon: const Icon(Icons.add_location),
                backgroundColor: Colors.blueAccent,
              ),
            ),

            // --- 3. DRAGGABLE BOTTOM PANEL LAYER ---
            // 5. BOTTOM PANEL FIX: Make it draggable and properly scaled
            DraggableScrollableSheet(
              initialChildSize: _initialSheetSize,
              minChildSize: 0.15,
              maxChildSize: 0.8,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 10,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: Column(
                    children: [
                      // Small drag handle at the top
                      Container(
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        width: 40,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          'Timeline / Details',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: 10,
                          itemBuilder: (context, index) {
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.location_on, size: 16),
                              ),
                              title: Text(
                                'Stop ${index + 1}',
                                style: const TextStyle(color: Colors.black87),
                              ),
                              subtitle: const Text('10:00 AM - 12:00 PM'),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
