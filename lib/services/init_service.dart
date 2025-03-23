import 'package:cloud_firestore/cloud_firestore.dart';

class InitService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initializeBudgetData() async {
    try {
      // Initialize budget overview
      final overviewDoc = await _firestore.collection('budget_overview').doc('current').get();
      if (!overviewDoc.exists) {
        await _firestore.collection('budget_overview').doc('current').set({
          'totalIncome': 0.0,
          'totalExpenses': 0.0,
          'lastUpdated': DateTime.now(),
        });
      }

      // Initialize default budget categories if none exist
      final categories = await _firestore.collection('budget_categories').get();
      if (categories.docs.isEmpty) {
        final defaultCategories = [
          {'name': 'Food', 'budget': 500.0},
          {'name': 'Transport', 'budget': 300.0},
          {'name': 'Utilities', 'budget': 200.0},
          {'name': 'Entertainment', 'budget': 150.0},
        ];

        final batch = _firestore.batch();
        for (var category in defaultCategories) {
          final docRef = _firestore.collection('budget_categories').doc();
          batch.set(docRef, {
            'name': category['name'],
            'budget': category['budget'],
            'spent': 0.0,
            'remaining': category['budget'],
            'lastUpdated': DateTime.now(),
          });
        }
        await batch.commit();
      }
    } catch (e) {
      print('Error initializing budget data: $e');
    }
  }
} 