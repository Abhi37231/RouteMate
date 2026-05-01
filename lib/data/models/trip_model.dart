import 'package:equatable/equatable.dart';

/// Trip model representing a travel trip
class Trip extends Equatable {
  final String id;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final String? description;
  final String? imageUrl;
  final String userId;
  final List<String> participantIds;
  final bool isShared;
  final String? shareCode;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Trip({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    this.description,
    this.imageUrl,
    required this.userId,
    this.participantIds = const [],
    this.isShared = false,
    this.shareCode,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from JSON map - handles both bool and int (0/1) from SQLite
  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      name: json['name'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: DateTime.parse(json['endDate'] as String),
      description: json['description'] as String?,
      imageUrl: json['imageUrl'] as String?,
      userId: json['userId'] as String,
      participantIds: _convertToParticipantList(json['participantIds']),
      // FIX: Safe conversion from int (0/1) or bool to bool
      // Avoids "type 'int' is not a subtype of type 'bool'" error
      isShared: _convertToBool(json['isShared']),
      shareCode: json['shareCode'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Safe participant list conversion
  static List<String> _convertToParticipantList(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String) {
      // Handle comma separated string from SQLite
      if (value.isEmpty) return [];
      return value.split(',');
    }
    return [];
  }

  /// Safe bool conversion - handles int (0/1), bool, or null
  static bool _convertToBool(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return false;
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'description': description,
      'imageUrl': imageUrl,
      'userId': userId,
      'participantIds': participantIds, // SQLite will need conversion to string
      'isShared': isShared,
      'shareCode': shareCode,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with modifications
  Trip copyWith({
    String? id,
    String? name,
    DateTime? startDate,
    DateTime? endDate,
    String? description,
    String? imageUrl,
    String? userId,
    List<String>? participantIds,
    bool? isShared,
    String? shareCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      userId: userId ?? this.userId,
      participantIds: participantIds ?? this.participantIds,
      isShared: isShared ?? this.isShared,
      shareCode: shareCode ?? this.shareCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        startDate,
        endDate,
        description,
        imageUrl,
        userId,
        participantIds,
        isShared,
        shareCode,
        createdAt,
        updatedAt,
      ];
}
