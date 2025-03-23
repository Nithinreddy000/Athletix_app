import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Watch budget overview as a stream
  Stream<Map<String, dynamic>> watchBudgetOverview({String? athleteId}) {
    if (athleteId == null || athleteId.isEmpty) {
      print('No athlete ID provided for watchBudgetOverview');
      return Stream.value({
        'totalBudget': 0.0,
        'totalExpenses': 0.0,
        'totalIncome': 0.0,
        'lastUpdated': DateTime.now(),
      });
    }
    
    return _firestore
        .collection('athlete_budget_overview')
        .doc(athleteId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists) {
            return snapshot.data() as Map<String, dynamic>? ?? {
              'totalBudget': 0.0,
              'totalExpenses': 0.0,
              'totalIncome': 0.0,
              'lastUpdated': DateTime.now(),
            };
          } else {
            print('No budget overview found for athlete: $athleteId');
            return {
              'totalBudget': 0.0,
              'totalExpenses': 0.0,
              'totalIncome': 0.0,
              'lastUpdated': DateTime.now(),
            };
          }
        });
  }

  // Get budget categories as a List
  Future<List<Map<String, dynamic>>> getBudgetCategories({String? athleteId}) async {
    if (athleteId == null || athleteId.isEmpty) {
      print('No athlete ID provided for getBudgetCategories');
      return [];
    }
    
    try {
      final snapshot = await _firestore
          .collection('athlete_budget_categories')
          .where('athleteId', isEqualTo: athleteId)
          .get();
          
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) {
          final data = doc.data();
          // Ensure all fields are properly initialized
          return {
            'id': doc.id,
            'name': data['name'] as String? ?? 'Unnamed Category',
            'budget': (data['budget'] as num?)?.toDouble() ?? 0.0,
            'spent': (data['spent'] as num?)?.toDouble() ?? 0.0,
            'athleteId': data['athleteId'] as String,
          };
        }).toList();
      } else {
        print('No budget categories found for athlete: $athleteId');
        return [];
      }
    } catch (e) {
      print('Error getting budget categories for athlete: $e');
      return [];
    }
  }

  // Get recent transactions
  Future<List<Map<String, dynamic>>> getRecentTransactions({String? athleteId}) async {
    if (athleteId == null || athleteId.isEmpty) {
      print('No athlete ID provided for getRecentTransactions');
      return [];
    }
    
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .where('athleteId', isEqualTo: athleteId)
          .orderBy('date', descending: true)
          .limit(10)
          .get();
      
      if (snapshot.docs.isEmpty) {
        print('No transactions found for athlete: $athleteId');
        return [];
      }

      final transactions = <Map<String, dynamic>>[];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Check if all required fields are present
        if (data['type'] == null || data['amount'] == null || 
            data['category'] == null || data['date'] == null) {
          print('Skipping transaction ${doc.id} due to missing required fields');
          continue;
        }
        
        // Get category name if not already in the transaction
        String categoryName = data['categoryName'] as String? ?? '';
        if (categoryName.isEmpty) {
          try {
            final categoryDoc = await _firestore
                .collection('athlete_budget_categories')
                .doc(data['category'] as String)
                .get();
                
            if (categoryDoc.exists) {
              categoryName = categoryDoc.data()?['name'] as String? ?? 'Unnamed Category';
              
              // Update the transaction with the category name for future use
              await _firestore.collection('transactions').doc(doc.id).update({
                'categoryName': categoryName
              });
            }
          } catch (e) {
            print('Error fetching category name for transaction ${doc.id}: $e');
          }
        }
        
        transactions.add({
          'id': doc.id,
          'date': data['date']?.toDate() ?? DateTime.now(),
          'amount': (data['amount'] as num?)?.toDouble() ?? 0.0,
          'type': data['type'] as String? ?? '',
          'category': data['category'] as String? ?? '',
          'categoryName': categoryName,
          'description': data['description'] as String? ?? '',
          'athleteId': data['athleteId'] as String?,
        });
      }
      
      return transactions;
    } catch (e) {
      print('Error getting transactions: $e');
      return [];
    }
  }

  // Add a new budget category
  Future<void> addBudgetCategory({
    required String name,
    required double budget,
    String? athleteId,
  }) async {
    if (athleteId == null || athleteId.isEmpty) {
      print('No athlete ID provided for addBudgetCategory');
      return;
    }
    
    final batch = _firestore.batch();

    // Generate a more readable ID for the category
    final categoryRef = _firestore.collection('athlete_budget_categories').doc();
    batch.set(categoryRef, {
      'name': name,
      'budget': budget,
      'spent': 0.0,
      'remaining': budget,
      'athleteId': athleteId,
      'lastUpdated': FieldValue.serverTimestamp(),
    });
    
    // Update the budget overview for this athlete
    final overviewRef = _firestore.collection('athlete_budget_overview').doc(athleteId);
    batch.set(overviewRef, {
      'totalBudget': FieldValue.increment(budget),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
    
    // Sync the budget data to ensure consistency
    await _syncAthleteData(athleteId);
  }

  // Private method to sync athlete budget data
  Future<void> _syncAthleteData(String athleteId) async {
    if (athleteId.isEmpty) {
      print('No athlete ID provided for _syncAthleteData');
      return;
    }
    
    try {
      // Get all categories for the athlete
      final categoriesSnapshot = await _firestore
          .collection('athlete_budget_categories')
          .where('athleteId', isEqualTo: athleteId)
          .get();
      
      // Calculate total budget from categories
      double totalBudget = 0.0;
      double totalSpent = 0.0;
      
      for (var doc in categoriesSnapshot.docs) {
        final data = doc.data();
        totalBudget += (data['budget'] as num?)?.toDouble() ?? 0.0;
        totalSpent += (data['spent'] as num?)?.toDouble() ?? 0.0;
      }
      
      // Update the athlete's budget overview
      await _firestore.collection('athlete_budget_overview').doc(athleteId).set({
        'totalBudget': totalBudget,
        'totalExpenses': totalSpent,
        'lastUpdated': DateTime.now(),
      }, SetOptions(merge: true));
      
      print('Synced budget data for athlete $athleteId: Budget=$totalBudget, Spent=$totalSpent');
    } catch (e) {
      print('Error syncing athlete data: $e');
    }
  }

  // Update an existing budget category
  Future<void> updateBudgetCategory({
    required String categoryId,
    required String name,
    required double budget,
    String? athleteId,
  }) async {
    if (athleteId == null || athleteId.isEmpty) {
      print('No athlete ID provided for updateBudgetCategory');
      return;
    }
    
    try {
      // Find the category in athlete-specific collection
      final athleteCategorySnapshot = await _firestore
          .collection('athlete_budget_categories')
          .where(FieldPath.documentId, isEqualTo: categoryId)
          .where('athleteId', isEqualTo: athleteId)
          .get();
          
      if (athleteCategorySnapshot.docs.isNotEmpty) {
        final doc = athleteCategorySnapshot.docs.first;
        final data = doc.data();
        final oldBudget = (data['budget'] as num?)?.toDouble() ?? 0.0;
        final spent = (data['spent'] as num?)?.toDouble() ?? 0.0;
        
        // Update the category
        await _firestore.collection('athlete_budget_categories').doc(categoryId).update({
          'name': name,
          'budget': budget,
          'remaining': budget - spent,
          'lastUpdated': FieldValue.serverTimestamp(),
        });
        
        // Sync all athlete data to ensure consistency
        await _syncAthleteData(athleteId);
      } else {
        print('Category not found for athlete: $athleteId, categoryId: $categoryId');
      }
    } catch (e) {
      print('Error updating budget category: $e');
    }
  }

  // Delete a budget category
  Future<void> deleteBudgetCategory(String categoryId, {String? athleteId}) async {
    if (athleteId == null || athleteId.isEmpty) {
      print('No athlete ID provided for deleteBudgetCategory');
      return;
    }
    
    try {
      // Find the category in athlete-specific collection
      final athleteCategorySnapshot = await _firestore
          .collection('athlete_budget_categories')
          .where(FieldPath.documentId, isEqualTo: categoryId)
          .where('athleteId', isEqualTo: athleteId)
          .get();
          
      if (athleteCategorySnapshot.docs.isNotEmpty) {
        // Delete the category
        await _firestore.collection('athlete_budget_categories').doc(categoryId).delete();
        
        // Sync all athlete data to ensure consistency
        await _syncAthleteData(athleteId);
      } else {
        print('Category not found for athlete: $athleteId, categoryId: $categoryId');
      }
    } catch (e) {
      print('Error deleting budget category: $e');
    }
  }

  // Get budget overview for a specific athlete
  Future<Map<String, dynamic>> getBudgetOverview({String? athleteId}) async {
    if (athleteId == null || athleteId.isEmpty) {
      print('No athlete ID provided for getBudgetOverview');
      return {
        'totalBudget': 0.0,
        'totalExpenses': 0.0,
        'totalIncome': 0.0,
        'lastUpdated': DateTime.now(),
      };
    }
    
    try {
      final doc = await _firestore
          .collection('athlete_budget_overview')
          .doc(athleteId)
          .get();

      if (!doc.exists) {
        final defaultData = {
          'totalBudget': 0.0,
          'totalExpenses': 0.0,
          'totalIncome': 0.0,
          'lastUpdated': DateTime.now(),
        };
        await _firestore
            .collection('athlete_budget_overview')
            .doc(athleteId)
            .set(defaultData);
        return defaultData;
      }

      final data = doc.data()!;
      return {
        'totalBudget': (data['totalBudget'] as num?)?.toDouble() ?? 0.0,
        'totalExpenses': (data['totalExpenses'] as num?)?.toDouble() ?? 0.0,
        'totalIncome': (data['totalIncome'] as num?)?.toDouble() ?? 0.0,
        'lastUpdated': data['lastUpdated'] ?? DateTime.now(),
      };
    } catch (e) {
      print('Error getting budget overview for athlete $athleteId: $e');
      return {
        'totalBudget': 0.0,
        'totalExpenses': 0.0,
        'totalIncome': 0.0,
        'lastUpdated': DateTime.now(),
      };
    }
  }
}
