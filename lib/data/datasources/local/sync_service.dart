import 'package:connectivity_plus/connectivity_plus.dart';
import 'database_helper.dart';
import '../remote/firestore_service.dart';
import '../../models/trip_model.dart';
import '../../models/stop_model.dart';
import '../../models/expense_model.dart';

/// Service for syncing local SQLite data with Firestore
class SyncService {
  final DatabaseHelper _localDb;
  final FirestoreService _remoteDb;
  final Connectivity _connectivity;

  SyncService({
    DatabaseHelper? localDb,
    FirestoreService? remoteDb,
    Connectivity? connectivity,
  }) : _localDb = localDb ?? DatabaseHelper.instance,
       _remoteDb = remoteDb ?? FirestoreService(),
       _connectivity = connectivity ?? Connectivity();

  /// Check if device is online
  Future<bool> isOnline() async {
    final result = await _connectivity.checkConnectivity();
    return result != ConnectivityResult.none;
  }

  /// Upload all local trips to Firestore
  Future<void> uploadTrips(String userId) async {
    if (!await isOnline()) return;

    final trips = await _localDb.getTrips(userId);
    for (final tripMap in trips) {
      try {
        final trip = Trip.fromJson(tripMap);
        await _remoteDb.uploadTrip(trip);

        // Also sync stops for this trip
        await uploadStops(trip.id);

        // Sync expenses for this trip
        await uploadExpenses(trip.id);

        // Update sync metadata
        await _localDb.updateSyncMetadata('trips', trip.id, DateTime.now());
      } catch (e) {
        // Log error but continue with other trips
        print('Error uploading trip ${tripMap['id']}: $e');
      }
    }
  }

  /// Upload stops for a trip
  Future<void> uploadStops(String tripId) async {
    if (!await isOnline()) return;

    final stops = await _localDb.getStops(tripId);
    for (final stopMap in stops) {
      try {
        final stop = Stop.fromJson(stopMap);
        await _remoteDb.uploadStop(stop);
        await _localDb.updateSyncMetadata('stops', stop.id, DateTime.now());
      } catch (e) {
        print('Error uploading stop ${stopMap['id']}: $e');
      }
    }
  }

  /// Upload expenses for a trip
  Future<void> uploadExpenses(String tripId) async {
    if (!await isOnline()) return;

    final expenses = await _localDb.getExpenses(tripId);
    for (final expenseMap in expenses) {
      try {
        final expense = Expense.fromJson(expenseMap);
        await _remoteDb.uploadExpense(expense);
        await _localDb.updateSyncMetadata(
          'expenses',
          expense.id,
          DateTime.now(),
        );
      } catch (e) {
        print('Error uploading expense ${expenseMap['id']}: $e');
      }
    }
  }

  /// Download trips from Firestore
  Future<List<Trip>> downloadTrips(String userId) async {
    if (!await isOnline()) return [];

    try {
      final remoteTrips = await _remoteDb.downloadTrips(userId);

      // Merge with local data - latest update wins
      for (final trip in remoteTrips) {
        final localTrip = await _localDb.getTripById(trip.id);

        if (localTrip == null) {
          // New trip from server, save locally
          await _localDb.insertTrip(trip.toJson());
        } else {
          final localTripModel = Trip.fromJson(localTrip);
          if (trip.updatedAt.isAfter(localTripModel.updatedAt)) {
            // Remote is newer, update local
            await _localDb.updateTrip(trip.toJson());
          }
        }

        // Sync stops for this trip
        final remoteStops = await downloadStops(trip.id);
        for (final stop in remoteStops) {
          final localStop = await _localDb.getStopById(stop.id);
          if (localStop == null) {
            await _localDb.insertStop(stop.toJson());
          } else {
            final localStopModel = Stop.fromJson(localStop);
            if (stop.updatedAt.isAfter(localStopModel.updatedAt)) {
              await _localDb.updateStop(stop.toJson());
            }
          }
        }

        // Sync expenses for this trip
        final remoteExpenses = await downloadExpenses(trip.id);
        for (final expense in remoteExpenses) {
          final localExpense = await _localDb.getExpenseById(expense.id);
          if (localExpense == null) {
            await _localDb.insertExpense(expense.toJson());
          } else {
            final localExpenseModel = Expense.fromJson(localExpense);
            if (expense.updatedAt.isAfter(localExpenseModel.updatedAt)) {
              await _localDb.updateExpense(expense.toJson());
            }
          }
        }
      }

      return remoteTrips;
    } catch (e) {
      print('Error downloading trips: $e');
      return [];
    }
  }

  /// Download stops from Firestore
  Future<List<Stop>> downloadStops(String tripId) async {
    if (!await isOnline()) return [];

    try {
      return await _remoteDb.downloadStops(tripId);
    } catch (e) {
      print('Error downloading stops: $e');
      return [];
    }
  }

  /// Download expenses from Firestore
  Future<List<Expense>> downloadExpenses(String tripId) async {
    if (!await isOnline()) return [];

    try {
      return await _remoteDb.downloadExpenses(tripId);
    } catch (e) {
      print('Error downloading expenses: $e');
      return [];
    }
  }

  /// Sync all data automatically
  Future<void> syncAll(String userId) async {
    if (!await isOnline()) return;

    // Upload local changes first
    await uploadTrips(userId);

    // Then download remote changes
    await downloadTrips(userId);

    // Download shared trips
    await downloadSharedTrips(userId);
  }

  Future<void> downloadSharedTrips(String userId) async {
    if (!await isOnline()) return;

    try {
      final sharedTrips = await _remoteDb.getSharedTrips(userId);
      for (final trip in sharedTrips) {
        final localTrip = await _localDb.getTripById(trip.id);
        if (localTrip == null) {
          await _localDb.insertTrip(trip.toJson());
          // Also download stops and expenses for this shared trip
          await downloadStops(trip.id);
          await downloadExpenses(trip.id);
        } else {
          final localTripModel = Trip.fromJson(localTrip);
          if (trip.updatedAt.isAfter(localTripModel.updatedAt)) {
            await _localDb.updateTrip(trip.toJson());
            await downloadStops(trip.id);
            await downloadExpenses(trip.id);
          }
        }
      }
    } catch (e) {
      print('Error downloading shared trips: $e');
    }
  }

  /// Start periodic sync
  void startPeriodicSync(String userId, Duration interval) {
    // This would typically use a timer or background service
    // For now, sync can be triggered manually or on app resume
  }
}
