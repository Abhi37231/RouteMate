import 'package:equatable/equatable.dart';

/// Expense model representing an expense for a trip
class Expense extends Equatable {
  final String id;
  final String tripId;
  final String category;
  final double amount;
  final String? description;
  final String? currency;
  final DateTime date;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Expense({
    required this.id,
    required this.tripId,
    required this.category,
    required this.amount,
    this.description,
    this.currency = 'USD',
    required this.date,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create from JSON map
  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] as String,
      tripId: json['tripId'] as String,
      category: json['category'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      currency: json['currency'] as String? ?? 'USD',
      date: DateTime.parse(json['date'] as String),
      userId: json['userId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tripId': tripId,
      'category': category,
      'amount': amount,
      'description': description,
      'currency': currency,
      'date': date.toIso8601String(),
      'userId': userId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Create a copy with modifications
  Expense copyWith({
    String? id,
    String? tripId,
    String? category,
    double? amount,
    String? description,
    String? currency,
    DateTime? date,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Expense(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      category: category ?? this.category,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      currency: currency ?? this.currency,
      date: date ?? this.date,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    tripId,
    category,
    amount,
    description,
    currency,
    date,
    userId,
    createdAt,
    updatedAt,
  ];
}
