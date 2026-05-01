import 'package:equatable/equatable.dart';

/// Stop model representing a stop in a trip
class Stop extends Equatable {
  final String id;
  final String tripId;
  final String name;
  final double latitude;
  final double longitude;
  final String? note;
  final int durationMinutes;
  final int orderIndex;
  final int dayNumber; // NEW: Which day this stop belongs to (1, 2, 3, etc.)
  final DateTime? arrivalTime;
  final DateTime? departureTime;
  final String transportType;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Stop({
    required this.id,
    required this.tripId,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.note,
    this.durationMinutes = 60,
    required this.orderIndex,
    this.dayNumber = 1, // Default to day 1
    this.arrivalTime,
    this.departureTime,
    this.transportType = 'car',
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from JSON map
  factory Stop.fromJson(Map<String, dynamic> json) {
    return Stop(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      note: json['note'] as String?,
      durationMinutes: json['durationMinutes'] as int? ?? 60,
      orderIndex: json['orderIndex'] as int,
      dayNumber: json['dayNumber'] as int? ?? 1,
      arrivalTime: json['arrivalTime'] != null
          ? DateTime.parse(json['arrivalTime'] as String)
          : null,
      departureTime: json['departureTime'] != null
          ? DateTime.parse(json['departureTime'] as String)
          : null,
      transportType: json['transportType'] as String? ?? 'car',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'note': note,
      'durationMinutes': durationMinutes,
      'orderIndex': orderIndex,
      'dayNumber': dayNumber,
      'arrivalTime': arrivalTime?.toIso8601String(),
      'departureTime': departureTime?.toIso8601String(),
      'transportType': transportType,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with modifications
  Stop copyWith({
    String? id,
    String? tripId,
    String? name,
    double? latitude,
    double? longitude,
    String? note,
    int? durationMinutes,
    int? orderIndex,
    DateTime? arrivalTime,
    DateTime? departureTime,
    String? transportType,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Stop(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      note: note ?? this.note,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      orderIndex: orderIndex ?? this.orderIndex,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      departureTime: departureTime ?? this.departureTime,
      transportType: transportType ?? this.transportType,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        tripId,
        name,
        latitude,
        longitude,
        note,
        durationMinutes,
        orderIndex,
        arrivalTime,
        departureTime,
        transportType,
        createdAt,
        updatedAt,
      ];
}
