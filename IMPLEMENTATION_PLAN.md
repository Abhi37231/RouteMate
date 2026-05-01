# Trip Planner App - Implementation Plan (FREE & Open Source)

## Status: Analysis Complete

### Phase 1: Core Map Features (Priority High)
- [ ] 1. Add user location marker on map with live GPS tracking
- [ ] 2. Integrate OSRM route drawing between stops
- [ ] 3. Show route info (distance + estimated time)
- [ ] 4. Add "Optimize Route" button using nearest-neighbor

### Phase 2: Search UI Enhancements (Priority High)
- [ ] 5. Debounced autocomplete search bar in map screen
- [ ] 6. Search results dropdown with place selection

### Phase 3: UI/UX Improvements (Priority Medium)
- [ ] 7. Draggable bottom sheet for stops list
- [ ] 8. Nearby places button and results sheet
- [ ] 9. Smooth animations for marker add/remove

### Phase 4: Extra Features (Priority Medium)
- [ ] 10. Expense tracker screen (per stop + total)
- [ ] 11. Full offline mode indicator

### Phase 5: Cleanup (Priority High)
- [ ] 12. Remove Firebase dependencies from pubspec.yaml
- [ ] 13. Update main.dart to work without Firebase
- [ ] 14. Update Android permissions for location

## Dependencies to Keep (All FREE):
- flutter_map: ^6.1.0 (OpenStreetMap)
- latlong2: ^0.9.0
- geolocator: ^11.0.0
- sqflite: ^2.3.2
- flutter_riverpod: ^2.4.9

## Dependencies to Remove:
- firebase_core
- firebase_auth
- cloud_firestore
- google_sign_in

## APIs Used (All FREE):
- OpenStreetMap tiles: https://tile.openstreetmap.org
- Nominatim search: https://nominatim.openstreetmap.org
- OSRM routing: https://router.project-osrm.org
- Overpass API: https://overpass-api.de/api/interpreter
