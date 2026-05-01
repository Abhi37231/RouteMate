import 'package:equatable/equatable.dart';

/// Tag model representing a tag for a stop
class Tag extends Equatable {
  final String id;
  final String stopId;
  final String name;
  final String? color;
  final DateTime createdAt;

  const Tag({
    required this.id,
    required this.stopId,
    required this.name,
    this.color,
    required this.createdAt,
  });

  /// Create from JSON map
  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      id: json['id'] as String,
      stopId: json['stopId'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'stopId': stopId,
      'name': name,
      'color': color,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Create a copy with modifications
  Tag copyWith({
    String? id,
    String? stopId,
    String? name,
    String? color,
    DateTime? createdAt,
  }) {
    return Tag(
      id: id ?? this.id,
      stopId: stopId ?? this.stopId,
      name: name ?? this.name,
      color: color ?? this.color,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [id, stopId, name, color, createdAt];
}
