import 'package:cloud_firestore/cloud_firestore.dart';

class Transaction {
  final String id;
  final double amount;
  final String description;
  final String category;
  final String type;
  final Timestamp date;
  final String createdBy;

  Transaction({
    required this.id,
    required this.amount,
    required this.description,
    required this.category,
    required this.type,
    required this.date,
    required this.createdBy,
  });

  factory Transaction.fromMap(Map<String, dynamic> map, String docId) {
    return Transaction(
      id: docId,
      amount: (map['amount'] as num).toDouble(),
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? '',
      type: map['type'] as String? ?? '',
      date: map['date'] as Timestamp? ?? Timestamp.now(),
      createdBy: map['createdBy'] as String? ?? 'Unknown',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'amount': amount,
      'description': description,
      'category': category,
      'type': type,
      'date': date,
      'createdBy': createdBy,
    };
  }
} 