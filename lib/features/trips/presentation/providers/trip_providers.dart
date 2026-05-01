import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:latlong2/latlong.dart';
import '../../../../data/datasources/remote/firestore_service.dart';
import '../../../../data/models/trip_model.dart';
import '../../../../data/models/stop_model.dart';
import '../../../../data/models/expense_model.dart';
import '../../../../data/datasources/local/database_helper.dart';
import '../../../../data/datasources/local/sync_service.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../../core/services/timeline_service.dart';
import '../../../../core/services/transport_service.dart';

/// Database helper provider
final databaseHelperProvider = Provider<DatabaseHelper>((ref) {
  return DatabaseHelper.instance;
});

/// Sync service provider
final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService();
});

/// Current user ID provider
final currentUserIdProvider = Provider<String?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.when(
    data: (user) => user?.uid,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Trips list provider
final tripsProvider =
    StateNotifierProvider<TripsNotifier, AsyncValue<List<Trip>>>((ref) {
  final notifier = TripsNotifier(
    ref.watch(databaseHelperProvider),
    ref.watch(syncServiceProvider),
  );

  // Watch auth state and set user ID when available
  final userId = ref.watch(currentUserIdProvider);
  if (userId != null) {
    notifier.setUserId(userId);
  }

  return notifier;
});

/// Trips notifier
class TripsNotifier extends StateNotifier<AsyncValue<List<Trip>>> {
  final DatabaseHelper _db;
  final SyncService _sync;
  String? _userId;

  TripsNotifier(this._db, this._sync) : super(const AsyncValue.data([]));

  /// Set user ID and load trips
  void setUserId(String userId) {
    _userId = userId;
    loadTrips();
  }

  /// Load all trips
  Future<void> loadTrips() async {
    if (_userId == null) return;

    state = const AsyncValue.loading();
    try {
      final tripsData = await _db.getTrips(_userId!);
      final trips = tripsData.map((t) => Trip.fromJson(t)).toList();
      state = AsyncValue.data(trips);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Create a new trip
  Future<Trip?> createTrip({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    String? description,
    String? imageUrl,
  }) async {
    if (_userId == null) return null;

    final now = DateTime.now();
    final tripId = const Uuid().v4();
    
    // Generate a unique 6-character share code
    final shareCode = tripId.substring(0, 6).toUpperCase();

    final trip = Trip(
      id: tripId,
      name: name,
      startDate: startDate,
      endDate: endDate,
      description: description,
      imageUrl: imageUrl,
      userId: _userId!,
      isShared: true, // Share by default so we get the code
      shareCode: shareCode,
      createdAt: now,
      updatedAt: now,
    );

    // Save locally
    await _db.insertTrip(trip.toJson());
    
    // Share on Firestore to generate the lookup entry
    try {
      final firestore = FirestoreService();
      // Also upload the trip document first
      await firestore.uploadTrip(trip);
      await firestore.shareTrip(trip);
    } catch (e) {
      print('Error sharing trip on creation: $e');
    }

    await loadTrips();
    return trip;
  }

  /// Update a trip
  Future<void> updateTrip(Trip trip) async {
    final updatedTrip = trip.copyWith(updatedAt: DateTime.now());
    await _db.updateTrip(updatedTrip.toJson());
    await loadTrips();
  }

  /// Delete a trip
  Future<void> deleteTrip(String tripId) async {
    await _db.deleteTrip(tripId);
    await loadTrips();
  }

  /// Sync trips with server
  Future<void> syncTrips() async {
    if (_userId == null) return;
    await _sync.syncAll(_userId!);
    await loadTrips();
  }

  /// Join a trip using a share code
  Future<bool> joinTrip(String shareCode) async {
    if (_userId == null) return false;

    try {
      print('TripsNotifier: Attempting to join trip with code: $shareCode');
      final firestore = FirestoreService();
      final trip = await firestore.joinTripByCode(shareCode, _userId!);
      
      if (trip != null) {
        print('TripsNotifier: Found trip ${trip.name}. Saving to local DB.');
        // Save to local DB
        await _db.insertTrip(trip.toJson());
        
        print('TripsNotifier: Fetching stops and expenses for ${trip.id}');
        // Load stops and expenses
        try {
          final stops = await firestore.downloadStops(trip.id);
          for (var stop in stops) {
            await _db.insertStop(stop.toJson());
          }
          
          final expenses = await firestore.downloadExpenses(trip.id);
          for (var expense in expenses) {
            await _db.insertExpense(expense.toJson());
          }
        } catch (syncError) {
          print('TripsNotifier: Warning - Could not sync all stops/expenses: $syncError');
          // We still continue because the trip itself is joined
        }
        
        await loadTrips();
        print('TripsNotifier: Successfully joined and loaded trip.');
        return true;
      } else {
        print('TripsNotifier: No trip found for code $shareCode');
      }
      return false;
    } catch (e) {
      print('TripsNotifier: Error joining trip: $e');
      return false;
    }
  }

  /// Leave a shared trip
  Future<void> leaveTrip(String tripId) async {
    if (_userId == null) return;

    try {
      print('TripsNotifier: Leaving trip $tripId');
      final firestore = FirestoreService();
      
      // 1. Remove from Firestore if possible
      try {
        await firestore.removeParticipant(tripId, _userId!);
      } catch (e) {
        print('TripsNotifier: Warning - Could not remove participant from Firestore: $e');
      }
      
      // 2. Delete locally
      await _db.deleteTrip(tripId);
      
      // 3. Refresh list
      await loadTrips();
    } catch (e) {
      print('TripsNotifier: Error leaving trip: $e');
    }
  }
}

/// Single trip provider
final tripProvider = FutureProvider.family<Trip?, String>((ref, tripId) async {
  final db = ref.watch(databaseHelperProvider);
  final tripData = await db.getTripById(tripId);
  return tripData != null ? Trip.fromJson(tripData) : null;
});

/// Stops provider for a trip
final stopsProvider =
    StateNotifierProvider.family<StopsNotifier, AsyncValue<List<Stop>>, String>(
  (ref, tripId) {
    return StopsNotifier(ref.watch(databaseHelperProvider), tripId);
  },
);

/// Stops notifier
class StopsNotifier extends StateNotifier<AsyncValue<List<Stop>>> {
  final DatabaseHelper _db;
  final String tripId;

  StopsNotifier(this._db, this.tripId) : super(const AsyncValue.loading()) {
    loadStops();
  }

  Future<void> loadStops() async {
    state = const AsyncValue.loading();
    try {
      final stopsData = await _db.getStops(tripId);
      final stops = stopsData.map((s) => Stop.fromJson(s)).toList();
      state = AsyncValue.data(stops);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Stop?> addStop({
    required String name,
    required double latitude,
    required double longitude,
    String? note,
    int durationMinutes = 60,
    String transportType = 'car',
  }) async {
    final currentStops = state.value ?? [];
    final now = DateTime.now();

    final stop = Stop(
      id: const Uuid().v4(),
      tripId: tripId,
      name: name,
      latitude: latitude,
      longitude: longitude,
      note: note,
      durationMinutes: durationMinutes,
      orderIndex: currentStops.length,
      transportType: transportType,
      createdAt: now,
      updatedAt: now,
    );

    await _db.insertStop(stop.toJson());
    await loadStops();
    return stop;
  }

  Future<void> updateStop(Stop stop) async {
    final updatedStop = stop.copyWith(updatedAt: DateTime.now());
    await _db.updateStop(updatedStop.toJson());
    await loadStops();
  }

  Future<void> deleteStop(String stopId) async {
    await _db.deleteStop(stopId);
    await loadStops();
  }

  Future<void> reorderStops(List<Stop> stops) async {
    for (int i = 0; i < stops.length; i++) {
      final updated = stops[i].copyWith(
        orderIndex: i,
        updatedAt: DateTime.now(),
      );
      await _db.updateStop(updated.toJson());
    }
    await loadStops();
  }
}

/// Expenses provider for a trip
final expensesProvider = StateNotifierProvider.family<ExpensesNotifier,
    AsyncValue<List<Expense>>, String>((ref, tripId) {
  return ExpensesNotifier(ref.watch(databaseHelperProvider), tripId);
});

/// Expenses notifier
class ExpensesNotifier extends StateNotifier<AsyncValue<List<Expense>>> {
  final DatabaseHelper _db;
  final String tripId;

  ExpensesNotifier(this._db, this.tripId) : super(const AsyncValue.loading()) {
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    state = const AsyncValue.loading();
    try {
      final expensesData = await _db.getExpenses(tripId);
      final expenses = expensesData.map((e) => Expense.fromJson(e)).toList();
      state = AsyncValue.data(expenses);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<Expense?> addExpense({
    required String category,
    required double amount,
    String? description,
    String currency = 'USD',
    required DateTime date,
    required String userId,
  }) async {
    final now = DateTime.now();

    final expense = Expense(
      id: const Uuid().v4(),
      tripId: tripId,
      category: category,
      amount: amount,
      description: description,
      currency: currency,
      date: date,
      userId: userId,
      createdAt: now,
      updatedAt: now,
    );

    await _db.insertExpense(expense.toJson());
    await loadExpenses();
    return expense;
  }

  Future<void> updateExpense(Expense expense) async {
    final updated = expense.copyWith(updatedAt: DateTime.now());
    await _db.updateExpense(updated.toJson());
    await loadExpenses();
  }

  Future<void> deleteExpense(String expenseId) async {
    await _db.deleteExpense(expenseId);
    await loadExpenses();
  }
}

/// Total expenses provider
final totalExpensesProvider = Provider.family<double, String>((ref, tripId) {
  final expenses = ref.watch(expensesProvider(tripId));
  return expenses.when(
    data: (list) => list.fold(0.0, (sum, e) => sum + e.amount),
    loading: () => 0.0,
    error: (_, __) => 0.0,
  );
});

/// Expenses by category provider
final expensesByCategoryProvider = Provider.family<Map<String, double>, String>(
  (ref, tripId) {
    final expenses = ref.watch(expensesProvider(tripId));
    return expenses.when(
      data: (list) {
        final map = <String, double>{};
        for (final expense in list) {
          map[expense.category] = (map[expense.category] ?? 0) + expense.amount;
        }
        return map;
      },
      loading: () => {},
      error: (_, __) => {},
    );
  },
);

// =====================
// TIMELINE PROVIDERS
// =====================

/// Timeline service provider
final timelineServiceProvider = Provider<TimelineService>((ref) {
  return TimelineService.instance;
});

/// Start time provider for timeline calculation
final startTimeProvider = StateProvider.family<DateTime, String>((ref, tripId) {
  // Default to current time rounded to next hour
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day, now.hour + 1, 0);
});

/// Trip timeline provider - calculates full timeline for a trip
final tripTimelineProvider =
    FutureProvider.family<TripTimeline, String>((ref, tripId) async {
  final stopsAsync = ref.watch(stopsProvider(tripId));
  final timelineService = ref.watch(timelineServiceProvider);
  final startTime = ref.watch(startTimeProvider(tripId));

  return stopsAsync.when(
    data: (stops) async {
      if (stops.isEmpty) {
        return TripTimeline.empty(tripId, startTime);
      }

      // Convert stops to timeline stops
      final timelineStops = stops
          .map((stop) => TimelineStop(
                id: stop.id,
                name: stop.name,
                location: LatLng(stop.latitude, stop.longitude),
                stayDurationMinutes: stop.durationMinutes,
                transportType: TransportType.fromId(stop.transportType),
              ))
          .toList();

      return timelineService.calculateTimeline(
        tripId: tripId,
        startTime: startTime,
        stops: timelineStops,
      );
    },
    loading: () => TripTimeline.empty(tripId, startTime),
    error: (_, __) => TripTimeline.empty(tripId, startTime),
  );
});

/// Quick timeline provider - calculates without API calls
final quickTimelineProvider =
    Provider.family<TripTimeline, String>((ref, tripId) {
  final stopsAsync = ref.watch(stopsProvider(tripId));
  final timelineService = ref.watch(timelineServiceProvider);
  final startTime = ref.watch(startTimeProvider(tripId));

  return stopsAsync.when(
    data: (stops) {
      if (stops.isEmpty) {
        return TripTimeline.empty(tripId, startTime);
      }

      final timelineStops = stops
          .map((stop) => TimelineStop(
                id: stop.id,
                name: stop.name,
                location: LatLng(stop.latitude, stop.longitude),
                stayDurationMinutes: stop.durationMinutes,
                transportType: TransportType.fromId(stop.transportType),
              ))
          .toList();

      return timelineService.calculateTimelineQuick(
        tripId: tripId,
        startTime: startTime,
        stops: timelineStops,
      );
    },
    loading: () => TripTimeline.empty(tripId, startTime),
    error: (_, __) => TripTimeline.empty(tripId, startTime),
  );
});

/// Total travel time provider
final totalTravelTimeProvider = Provider.family<String, String>((ref, tripId) {
  final timelineAsync = ref.watch(tripTimelineProvider(tripId));
  return timelineAsync.when(
    data: (timeline) => timeline.totalTravelTimeFormatted,
    loading: () => '...',
    error: (_, __) => 'N/A',
  );
});

/// Total trip time provider
final totalTripTimeProvider = Provider.family<String, String>((ref, tripId) {
  final timelineAsync = ref.watch(tripTimelineProvider(tripId));
  return timelineAsync.when(
    data: (timeline) => timeline.totalTripTimeFormatted,
    loading: () => '...',
    error: (_, __) => 'N/A',
  );
});

/// End time provider
final endTimeProvider = Provider.family<String, String>((ref, tripId) {
  final timelineAsync = ref.watch(tripTimelineProvider(tripId));
  return timelineAsync.when(
    data: (timeline) => timeline.endTimeFormatted,
    loading: () => '...',
    error: (_, __) => 'N/A',
  );
});
