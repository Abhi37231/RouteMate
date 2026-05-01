import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../models/trip_model.dart';
import '../../models/stop_model.dart';
import '../../models/expense_model.dart';
import '../../models/tag_model.dart';

/// Firestore service for online sync
class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  // Trip operations
  Future<void> uploadTrip(Trip trip) async {
    await _firestore
        .collection(AppConstants.tripsCollection)
        .doc(trip.id)
        .set(trip.toJson());
  }

  Future<void> updateTrip(Trip trip) async {
    await _firestore
        .collection(AppConstants.tripsCollection)
        .doc(trip.id)
        .update(trip.toJson());
  }

  Future<void> deleteTrip(String tripId) async {
    await _firestore
        .collection(AppConstants.tripsCollection)
        .doc(tripId)
        .delete();
  }

  Future<List<Trip>> downloadTrips(String userId) async {
    final snapshot = await _firestore
        .collection(AppConstants.tripsCollection)
        .where('userId', isEqualTo: userId)
        .get();

    return snapshot.docs.map((doc) => Trip.fromJson(doc.data())).toList();
  }

  Future<Trip?> getTripById(String tripId) async {
    final doc = await _firestore
        .collection(AppConstants.tripsCollection)
        .doc(tripId)
        .get();

    return doc.exists ? Trip.fromJson(doc.data()!) : null;
  }

  // Stop operations
  Future<void> uploadStop(Stop stop) async {
    await _firestore
        .collection(AppConstants.stopsCollection)
        .doc(stop.id)
        .set(stop.toJson());
  }

  Future<void> updateStop(Stop stop) async {
    await _firestore
        .collection(AppConstants.stopsCollection)
        .doc(stop.id)
        .update(stop.toJson());
  }

  Future<void> deleteStop(String stopId) async {
    await _firestore
        .collection(AppConstants.stopsCollection)
        .doc(stopId)
        .delete();
  }

  Future<List<Stop>> downloadStops(String tripId) async {
    final snapshot = await _firestore
        .collection(AppConstants.stopsCollection)
        .where('tripId', isEqualTo: tripId)
        .get();

    return snapshot.docs.map((doc) => Stop.fromJson(doc.data())).toList();
  }

  // Expense operations
  Future<void> uploadExpense(Expense expense) async {
    await _firestore
        .collection(AppConstants.expensesCollection)
        .doc(expense.id)
        .set(expense.toJson());
  }

  Future<void> updateExpense(Expense expense) async {
    await _firestore
        .collection(AppConstants.expensesCollection)
        .doc(expense.id)
        .update(expense.toJson());
  }

  Future<void> deleteExpense(String expenseId) async {
    await _firestore
        .collection(AppConstants.expensesCollection)
        .doc(expenseId)
        .delete();
  }

  Future<List<Expense>> downloadExpenses(String tripId) async {
    final snapshot = await _firestore
        .collection(AppConstants.expensesCollection)
        .where('tripId', isEqualTo: tripId)
        .get();

    return snapshot.docs.map((doc) => Expense.fromJson(doc.data())).toList();
  }

  // Tag operations
  Future<void> uploadTag(Tag tag) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(tag.stopId)
        .collection('tags')
        .doc(tag.id)
        .set(tag.toJson());
  }

  Future<void> deleteTag(String stopId, String tagId) async {
    await _firestore
        .collection(AppConstants.usersCollection)
        .doc(stopId)
        .collection('tags')
        .doc(tagId)
        .delete();
  }

  Future<List<Tag>> downloadTags(String stopId) async {
    final snapshot = await _firestore
        .collection(AppConstants.usersCollection)
        .doc(stopId)
        .collection('tags')
        .get();

    return snapshot.docs.map((doc) => Tag.fromJson(doc.data())).toList();
  }

  // Sharing operations
  Future<void> shareTrip(Trip trip) async {
    await _firestore
        .collection(AppConstants.sharedTripsCollection)
        .doc(trip.shareCode)
        .set({
          'tripId': trip.id,
          'shareCode': trip.shareCode,
          'tripData': trip.toJson(),
          'ownerId': trip.userId,
          'createdAt': DateTime.now().toIso8601String(),
        });
  }

  Future<String?> getSharedTripId(String shareCode) async {
    final doc = await _firestore
        .collection(AppConstants.sharedTripsCollection)
        .doc(shareCode)
        .get();

    return doc.exists ? doc.data()!['tripId'] as String? : null;
  }

  Future<List<Trip>> getSharedTrips(String userId) async {
    final snapshot = await _firestore
        .collection(AppConstants.tripsCollection)
        .where('participantIds', arrayContains: userId)
        .get();

    return snapshot.docs.map((doc) => Trip.fromJson(doc.data())).toList();
  }

  Future<void> addParticipant(String tripId, String userId) async {
    // 1. Add to subcollection for record keeping
    await _firestore
        .collection(AppConstants.tripsCollection)
        .doc(tripId)
        .collection('participants')
        .doc(userId)
        .set({'userId': userId, 'joinedAt': DateTime.now().toIso8601String()});

    // 2. Update trip document array for easier querying
    await _firestore.collection(AppConstants.tripsCollection).doc(tripId).update({
      'participantIds': FieldValue.arrayUnion([userId]),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<void> removeParticipant(String tripId, String userId) async {
    // 1. Remove from subcollection
    await _firestore
        .collection(AppConstants.tripsCollection)
        .doc(tripId)
        .collection('participants')
        .doc(userId)
        .delete();

    // 2. Remove from trip document array
    await _firestore.collection(AppConstants.tripsCollection).doc(tripId).update({
      'participantIds': FieldValue.arrayRemove([userId]),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  Future<Trip?> joinTripByCode(String shareCode, String userId) async {
    final cleanCode = shareCode.trim().toUpperCase();
    
    // Find trip by share code
    final sharedTripDoc = await _firestore
        .collection(AppConstants.sharedTripsCollection)
        .doc(cleanCode)
        .get();

    if (!sharedTripDoc.exists) return null;

    final data = sharedTripDoc.data()!;
    final tripId = data['tripId'] as String;
    
    // Create trip model from embedded data if available
    Trip? trip;
    if (data.containsKey('tripData')) {
      trip = Trip.fromJson(data['tripData'] as Map<String, dynamic>);
    } else {
      // Fallback to fetching if not embedded
      trip = await getTripById(tripId);
    }
    
    if (trip == null) {
      print('FirestoreService: Trip not found in snapshot or main collection.');
      return null;
    }

    // Add user as participant to the main trip document
    // AND update the local model so the UI sees the user as a participant
    List<String> updatedParticipants = List.from(trip.participantIds);
    if (!updatedParticipants.contains(userId)) {
      updatedParticipants.add(userId);
    }
    
    final joinedTrip = trip.copyWith(participantIds: updatedParticipants);

    try {
      print('FirestoreService: Adding participant $userId to trip $tripId');
      await addParticipant(tripId, userId);
    } catch (e) {
      print('Warning: Could not add participant to remote document: $e');
    }
    
    return joinedTrip;
  }
}
