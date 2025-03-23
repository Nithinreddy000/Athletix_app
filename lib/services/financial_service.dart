import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/transaction.dart' as model;

class FinancialService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Add transaction with proper overview update
  Future<void> addTransaction({
    required String type,
    required double amount,
    required String category,
    required String description,
    String? athleteId,
  }) async {
    if (athleteId == null || athleteId.isEmpty) {
      print('No athlete ID provided for addTransaction');
      throw Exception('Athlete ID is required to add a transaction');
    }
    
    try {
      final batch = _firestore.batch();

      // Get category name first
      String categoryName = '';
      try {
        final categoryDoc = await _firestore
            .collection('athlete_budget_categories')
            .doc(category)
            .get();
            
        if (categoryDoc.exists) {
          categoryName = categoryDoc.data()?['name'] ?? 'Unknown Category';
        } else {
          print('Warning: Category $category not found for athlete $athleteId');
          categoryName = 'Unknown Category';
        }
      } catch (e) {
        print('Error getting category name: $e');
        categoryName = 'Unknown Category';
      }

      // Add transaction with category name
      final transactionRef = _firestore.collection('transactions').doc();
      final now = DateTime.now();
      batch.set(transactionRef, {
        'type': type,
        'amount': amount,
        'category': category,
        'categoryName': categoryName, // Store category name for easier retrieval
        'description': description,
        'date': now,
        'createdAt': now,
        'athleteId': athleteId,
      });

      // Get current athlete overview
      final overviewDoc = await _firestore.collection('athlete_budget_overview').doc(athleteId).get();
      final currentData = overviewDoc.data() ?? {
        'totalIncome': 0.0,
        'totalExpenses': 0.0,
        'lastUpdated': now,
      };

      // Update budget overview with proper type casting
      final totalIncome = (currentData['totalIncome'] as num?)?.toDouble() ?? 0.0;
      final totalExpenses = (currentData['totalExpenses'] as num?)?.toDouble() ?? 0.0;

      batch.set(_firestore.collection('athlete_budget_overview').doc(athleteId), {
        'totalIncome': type == 'income' ? totalIncome + amount : totalIncome,
        'totalExpenses': type == 'expense' ? totalExpenses + amount : totalExpenses,
        'lastUpdated': now,
      }, SetOptions(merge: true));

      // Update budget category
      if (type == 'expense') {
        // Check if the category exists
        final categoryDoc = await _firestore
            .collection('athlete_budget_categories')
            .doc(category)
            .get();
            
        if (categoryDoc.exists) {
          final categoryData = categoryDoc.data() ?? {};
          final currentSpent = (categoryData['spent'] as num?)?.toDouble() ?? 0.0;
          final currentBudget = (categoryData['budget'] as num?)?.toDouble() ?? 0.0;

          batch.update(_firestore.collection('athlete_budget_categories').doc(category), {
            'spent': currentSpent + amount,
            'remaining': currentBudget - (currentSpent + amount),
            'lastUpdated': now,
          });
        } else {
          print('Warning: Attempted to add expense to non-existent category: $category');
          // Don't create a new category here, as it should already exist
        }
      }

      await batch.commit();
      await syncBudgetWithTransactions(athleteId: athleteId);
    } catch (e) {
      print('Error adding transaction: $e');
      throw Exception('Failed to add transaction: $e');
    }
  }

  Future<void> _updateLocalCache({required String athleteId}) async {
    if (athleteId.isEmpty) {
      print('No athlete ID provided for _updateLocalCache');
      return;
    }
    
    try {
      // Get all transactions for the current month for the specific athlete
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0);

      final transactions = await _firestore
        .collection('transactions')
        .where('athleteId', isEqualTo: athleteId)
        .where('date', isGreaterThanOrEqualTo: startOfMonth)
        .where('date', isLessThanOrEqualTo: endOfMonth)
        .get();

      double totalIncome = 0.0;
      double totalExpenses = 0.0;
      Map<String, double> categorySpending = {};

      for (var doc in transactions.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num).toDouble();
        final type = data['type'] as String;
        final category = data['category'] as String;

        if (type == 'income') {
          totalIncome += amount;
        } else {
          totalExpenses += amount;
          categorySpending[category] = (categorySpending[category] ?? 0.0) + amount;
        }
      }

      // Update athlete budget overview
      await _firestore.collection('athlete_budget_overview').doc(athleteId).set({
        'totalIncome': totalIncome,
        'totalExpenses': totalExpenses,
        'lastUpdated': DateTime.now(),
      }, SetOptions(merge: true));

      // Update category spending for athlete
      for (var entry in categorySpending.entries) {
        // Get the category document
        final categorySnapshot = await _firestore
            .collection('athlete_budget_categories')
            .where(FieldPath.documentId, isEqualTo: entry.key)
            .where('athleteId', isEqualTo: athleteId)
            .get();
            
        if (categorySnapshot.docs.isNotEmpty) {
          final categoryDoc = categorySnapshot.docs.first;
          await _firestore.collection('athlete_budget_categories').doc(categoryDoc.id).set({
            'spent': entry.value,
            'lastUpdated': DateTime.now(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      print('Error updating local cache for athlete $athleteId: $e');
    }
  }

  // Watch financial summary with proper type handling
  Stream<Map<String, dynamic>> watchFinancialSummary({String? athleteId}) {
    if (athleteId == null || athleteId.isEmpty) {
      print('No athlete ID provided for watchFinancialSummary');
      return Stream.value({
        'totalIncome': 0.0,
        'totalExpenses': 0.0,
        'lastUpdated': DateTime.now(),
      });
    }
    
    return _firestore
        .collection('athlete_budget_overview')
        .doc(athleteId)
        .snapshots()
        .map((snapshot) {
          final data = snapshot.data() ?? {};
          return {
            'totalIncome': (data['totalIncome'] as num?)?.toDouble() ?? 0.0,
            'totalExpenses': (data['totalExpenses'] as num?)?.toDouble() ?? 0.0,
            'lastUpdated': data['lastUpdated'] ?? DateTime.now(),
          };
        });
  }

  // Watch recent transactions with proper type handling
  Stream<List<Map<String, dynamic>>> watchRecentTransactions({String? athleteId}) {
    if (athleteId == null || athleteId.isEmpty) {
      print('No athlete ID provided for watchRecentTransactions');
      return Stream.value([]);
    }
    
    return _firestore
        .collection('transactions')
        .where('athleteId', isEqualTo: athleteId)
        .orderBy('date', descending: true)
        .limit(5)
        .snapshots()
        .asyncMap((snapshot) async {
          if (snapshot.docs.isEmpty) {
            print('No transactions found for athlete: $athleteId');
            return [];
          }
          
          final List<Map<String, dynamic>> transactions = [];
          
          for (var doc in snapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            // Ensure all required fields exist
            if (data['type'] == null || data['amount'] == null || 
                data['category'] == null || data['date'] == null) {
              print('Skipping transaction with missing data: ${doc.id}');
              continue;
            }
            
            try {
              // Get category name if it's not already in the transaction
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
                  } else {
                    categoryName = 'Unknown Category';
                  }
                } catch (e) {
                  print('Error fetching category name for transaction ${doc.id}: $e');
                  categoryName = 'Unknown Category';
                }
              }
              
              transactions.add({
                'id': doc.id,
                'type': data['type'] as String,
                'amount': (data['amount'] as num).toDouble(),
                'category': data['category'] as String,
                'categoryName': categoryName,
                'description': data['description'] as String? ?? '',
                'date': (data['date'] as Timestamp).toDate(),
                'athleteId': data['athleteId'] as String?,
              });
            } catch (e) {
              print('Error parsing transaction data: $e');
            }
          }
          
          return transactions;
        });
  }

  // Get budget overview for a specific athlete
  Future<Map<String, dynamic>> getBudgetOverview({String? athleteId}) async {
    if (athleteId == null || athleteId.isEmpty) {
      print('No athlete ID provided for getBudgetOverview');
      return {
        'totalIncome': 0.0,
        'totalExpenses': 0.0,
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
          'totalIncome': 0.0,
          'totalExpenses': 0.0,
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
        'totalIncome': (data['totalIncome'] as num?)?.toDouble() ?? 0.0,
        'totalExpenses': (data['totalExpenses'] as num?)?.toDouble() ?? 0.0,
        'lastUpdated': data['lastUpdated'] ?? DateTime.now(),
      };
    } catch (e) {
      print('Error getting budget overview for athlete $athleteId: $e');
      return {
        'totalIncome': 0.0,
        'totalExpenses': 0.0,
        'lastUpdated': DateTime.now(),
      };
    }
  }

  // Initialize budget category for a specific athlete
  Future<void> initializeBudgetCategory(String categoryId, {required String athleteId}) async {
    if (athleteId.isEmpty) {
      print('No athlete ID provided for initializeBudgetCategory');
      return;
    }
    
    try {
      final categorySnapshot = await _firestore
          .collection('athlete_budget_categories')
          .where(FieldPath.documentId, isEqualTo: categoryId)
          .where('athleteId', isEqualTo: athleteId)
          .get();
          
      if (categorySnapshot.docs.isEmpty) {
        await _firestore.collection('athlete_budget_categories').doc(categoryId).set({
          'name': 'New Category',
          'budget': 0.0,
          'spent': 0.0,
          'remaining': 0.0,
          'lastUpdated': DateTime.now(),
          'athleteId': athleteId,
        });
      }
    } catch (e) {
      print('Error initializing budget category: $e');
    }
  }

  // Sync budget with transactions
  Future<void> syncBudgetWithTransactions({String? athleteId}) async {
    if (athleteId == null || athleteId.isEmpty) {
      print('No athlete ID provided for syncBudgetWithTransactions');
      return;
    }
    
    try {
      // Get all transactions for the athlete
      final transactions = await _firestore
        .collection('transactions')
        .where('athleteId', isEqualTo: athleteId)
        .get();

      double totalIncome = 0.0;
      double totalExpenses = 0.0;
      Map<String, double> categorySpending = {};

      for (var doc in transactions.docs) {
        final data = doc.data();
        final amount = (data['amount'] as num).toDouble();
        final type = data['type'] as String;
        final category = data['category'] as String;

        if (type == 'income') {
          totalIncome += amount;
        } else {
          totalExpenses += amount;
          categorySpending[category] = (categorySpending[category] ?? 0.0) + amount;
        }
      }

      // Update athlete budget overview
      await _firestore.collection('athlete_budget_overview').doc(athleteId).set({
        'totalIncome': totalIncome,
        'totalExpenses': totalExpenses,
        'lastUpdated': DateTime.now(),
      }, SetOptions(merge: true));

      // Update category spending for athlete
      for (var entry in categorySpending.entries) {
        // Get the category document
        final categorySnapshot = await _firestore
            .collection('athlete_budget_categories')
            .where(FieldPath.documentId, isEqualTo: entry.key)
            .where('athleteId', isEqualTo: athleteId)
            .get();
            
        if (categorySnapshot.docs.isNotEmpty) {
          final categoryDoc = categorySnapshot.docs.first;
          await _firestore.collection('athlete_budget_categories').doc(categoryDoc.id).set({
            'spent': entry.value,
            'lastUpdated': DateTime.now(),
          }, SetOptions(merge: true));
        }
      }
    } catch (e) {
      print('Error syncing budget with transactions: $e');
    }
  }

  // Get all transactions with filters for a specific athlete
  Future<List<Map<String, dynamic>>> getAllTransactions({
    required String athleteId,
    DateTime? startDate,
    DateTime? endDate,
    String? category,
  }) async {
    if (athleteId.isEmpty) {
      print('No athlete ID provided for getAllTransactions');
      return [];
    }
    
    try {
      Query query = _firestore.collection('transactions')
          .where('athleteId', isEqualTo: athleteId)
          .orderBy('date', descending: true);

      if (startDate != null) {
        query = query.where('date', isGreaterThanOrEqualTo: startDate);
      }
      if (endDate != null) {
        query = query.where('date', isLessThanOrEqualTo: endDate);
      }
      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      final snapshot = await query.get();
      
      if (snapshot.docs.isEmpty) {
        print('No transactions found for athlete: $athleteId with the specified filters');
        return [];
      }

      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'type': data['type'] as String,
          'amount': (data['amount'] as num).toDouble(),
          'category': data['category'] as String,
          'description': data['description'] as String? ?? '',
          'date': (data['date'] as Timestamp).toDate(),
          'athleteId': data['athleteId'] as String,
        };
      }).toList();
    } catch (e) {
      print('Error getting transactions for athlete $athleteId: $e');
      return [];
    }
  }

  // Get all transaction categories for a specific athlete
  Future<List<String>> getTransactionCategories({required String athleteId}) async {
    if (athleteId.isEmpty) {
      print('No athlete ID provided for getTransactionCategories');
      return [];
    }
    
    try {
      final snapshot = await _firestore
          .collection('athlete_budget_categories')
          .where('athleteId', isEqualTo: athleteId)
          .get();
          
      return snapshot.docs.map((doc) => doc.data()['name'] as String).toList();
    } catch (e) {
      print('Error getting transaction categories for athlete $athleteId: $e');
      return [];
    }
  }

  // Get all transactions for a specific athlete
  Future<List<model.Transaction>> getTransactions({required String athleteId}) async {
    if (athleteId.isEmpty) {
      print('No athlete ID provided for getTransactions');
      return [];
    }
    
    try {
      final snapshot = await _firestore
          .collection('transactions')
          .where('athleteId', isEqualTo: athleteId)
          .orderBy('date', descending: true)
          .get();
      
      if (snapshot.docs.isEmpty) {
        print('No transactions found for athlete: $athleteId');
        return [];
      }
      
      return snapshot.docs.map((doc) => 
        model.Transaction.fromMap(doc.data(), doc.id)
      ).toList();
    } catch (e) {
      print('Error getting transactions for athlete $athleteId: $e');
      return [];
    }
  }

  // Delete a transaction
  Future<void> deleteTransaction(String id, {String? athleteId}) async {
    if (athleteId == null || athleteId.isEmpty) {
      print('No athlete ID provided for deleteTransaction');
      throw Exception('Athlete ID is required to delete a transaction');
    }
    
    try {
      // Get the transaction data before deleting
      final doc = await _firestore.collection('transactions').doc(id).get();
      if (!doc.exists) {
        throw Exception('Transaction not found');
      }
      
      final data = doc.data()!;
      final type = data['type'] as String;
      final amount = (data['amount'] as num).toDouble();
      final category = data['category'] as String;
      final transactionAthleteId = data['athleteId'] as String?;
      
      // Verify that the transaction belongs to the specified athlete
      if (transactionAthleteId != athleteId) {
        throw Exception('Transaction does not belong to the specified athlete');
      }
      
      final batch = _firestore.batch();
      
      // Delete the transaction
      batch.delete(_firestore.collection('transactions').doc(id));
      
      // Update athlete budget overview
      final overviewDoc = await _firestore.collection('athlete_budget_overview').doc(athleteId).get();
      if (overviewDoc.exists) {
        final overviewData = overviewDoc.data()!;
        final totalIncome = (overviewData['totalIncome'] as num?)?.toDouble() ?? 0.0;
        final totalExpenses = (overviewData['totalExpenses'] as num?)?.toDouble() ?? 0.0;
        
        batch.update(_firestore.collection('athlete_budget_overview').doc(athleteId), {
          'totalIncome': type == 'income' ? totalIncome - amount : totalIncome,
          'totalExpenses': type == 'expense' ? totalExpenses - amount : totalExpenses,
          'lastUpdated': DateTime.now(),
        });
      }
      
      // Update category if it's an expense
      if (type == 'expense') {
        // Find the category in athlete-specific collection
        final categorySnapshot = await _firestore
            .collection('athlete_budget_categories')
            .where(FieldPath.documentId, isEqualTo: category)
            .where('athleteId', isEqualTo: athleteId)
            .get();
            
        if (categorySnapshot.docs.isNotEmpty) {
          final categoryDoc = categorySnapshot.docs.first;
          final categoryData = categoryDoc.data();
          final currentSpent = (categoryData['spent'] as num?)?.toDouble() ?? 0.0;
          final currentBudget = (categoryData['budget'] as num?)?.toDouble() ?? 0.0;
          
          batch.update(_firestore.collection('athlete_budget_categories').doc(category), {
            'spent': currentSpent - amount,
            'remaining': currentBudget - (currentSpent - amount),
            'lastUpdated': DateTime.now(),
          });
        }
      }
      
      await batch.commit();
      await syncBudgetWithTransactions(athleteId: athleteId);
    } catch (e) {
      print('Error deleting transaction: $e');
      throw Exception('Failed to delete transaction: $e');
    }
  }
}
