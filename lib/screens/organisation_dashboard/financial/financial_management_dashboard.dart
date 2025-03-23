import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import '../../../constants.dart';
import '../../../responsive.dart';
import '../../../services/financial_service.dart';

class FinancialManagementDashboard extends StatefulWidget {
  const FinancialManagementDashboard({Key? key}) : super(key: key);

  @override
  _FinancialManagementDashboardState createState() => _FinancialManagementDashboardState();
}

class _FinancialManagementDashboardState extends State<FinancialManagementDashboard> {
  final Map<String, String> _categoryMap = {};
  final FinancialService _financialService = FinancialService();
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedType = 'expense';
  String _selectedCategory = '';
  bool _isLoading = false;
  
  // Athlete selection variables
  List<Map<String, dynamic>> _athletes = [];
  String? _selectedAthleteId;
  bool _isLoadingAthletes = true;
  String _organizationId = '';

  @override
  void initState() {
    super.initState();
    _loadOrganizationId().then((_) {
      _loadAthletes();
      _loadInitialData();
    });
  }

  Future<void> _loadOrganizationId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        setState(() {
          _organizationId = user.uid;
        });
      }
    }
  }

  Future<void> _loadAthletes() async {
    setState(() {
      _isLoadingAthletes = true;
    });
    
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'athlete')
          .where('organizationId', isEqualTo: _organizationId)
          .get();
      
      final athletes = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unknown Athlete',
          'email': data['email'] ?? '',
          'profileImage': data['profileImage'],
        };
      }).toList();
      
      setState(() {
        _athletes = athletes;
        _isLoadingAthletes = false;
        
        // Select the first athlete by default if available
        if (athletes.isNotEmpty) {
          _selectedAthleteId = athletes.first['id'];
        }
      });
    } catch (e) {
      print('Error loading athletes: $e');
      setState(() {
        _isLoadingAthletes = false;
      });
    }
  }

  Future<void> _loadInitialData() async {
    try {
      // Load categories for the selected athlete
      if (_selectedAthleteId != null) {
        final categories = await FirebaseFirestore.instance
            .collection('athlete_budget_categories')
            .where('athleteId', isEqualTo: _selectedAthleteId)
            .get();
            
        _categoryMap.clear(); // Clear previous mappings
        
        for (var doc in categories.docs) {
          final data = doc.data();
          final name = data['name'] as String? ?? 'Unnamed Category';
          _categoryMap[doc.id] = name;
        }
        
        if (categories.docs.isNotEmpty) {
          setState(() {
            _selectedCategory = categories.docs.first.id;
          });
        }
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  String _getCategoryName(String categoryId) {
    if (categoryId.isEmpty) return 'Unknown Category';
    
    // First check if we have the category name in our map
    if (_categoryMap.containsKey(categoryId)) {
      return _categoryMap[categoryId]!;
    }
    
    // If not in our map, try to fetch it from Firestore (async operation)
    _fetchCategoryName(categoryId);
    
    // Return a placeholder while we're fetching
    return 'Loading...';
  }
  
  // Helper method to fetch category name asynchronously
  Future<void> _fetchCategoryName(String categoryId) async {
    if (categoryId.isEmpty) return;
    
    try {
      final doc = await FirebaseFirestore.instance
          .collection('athlete_budget_categories')
          .doc(categoryId)
          .get();
          
      if (doc.exists && mounted) {
        final name = doc.data()?['name'] as String? ?? 'Unnamed Category';
        setState(() {
          _categoryMap[categoryId] = name;
        });
      } else {
        // Category not found, set a default name
        setState(() {
          _categoryMap[categoryId] = 'Unknown Category';
        });
      }
    } catch (e) {
      print('Error fetching category name for $categoryId: $e');
      if (mounted) {
        setState(() {
          _categoryMap[categoryId] = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Responsive(
        mobile: SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Athlete Dropdown
              _buildAthleteDropdown(),
              const SizedBox(height: defaultPadding),
              
              StreamBuilder<Map<String, dynamic>>(
                stream: _financialService.watchFinancialSummary(athleteId: _selectedAthleteId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final data = snapshot.data!;
                  return Column(
                    children: [
                      if (Responsive.isDesktop(context))
                        Row(
                          children: [
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'Total Income',
                                value: '\$${(data['totalIncome'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                icon: Icons.trending_up,
                                color: Colors.green,
                              ),
                            ),
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'Total Expenses',
                                value: '\$${(data['totalExpenses'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                icon: Icons.trending_down,
                                color: Colors.red,
                              ),
                            ),
                            Expanded(
                              child: _buildSummaryCard(
                                title: 'Net Balance',
                                value: '\$${((data['totalIncome'] ?? 0.0) - (data['totalExpenses'] ?? 0.0)).toStringAsFixed(2)}',
                                icon: Icons.account_balance_wallet,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        )
                      else
                        Column(
                          children: [
                            _buildSummaryCard(
                              title: 'Total Income',
                              value: '\$${(data['totalIncome'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                              icon: Icons.trending_up,
                              color: Colors.green,
                              width: double.infinity,
                            ),
                            _buildSummaryCard(
                              title: 'Total Expenses',
                              value: '\$${(data['totalExpenses'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                              icon: Icons.trending_down,
                              color: Colors.red,
                              width: double.infinity,
                            ),
                            _buildSummaryCard(
                              title: 'Net Balance',
                              value: '\$${((data['totalIncome'] ?? 0.0) - (data['totalExpenses'] ?? 0.0)).toStringAsFixed(2)}',
                              icon: Icons.account_balance_wallet,
                              color: Colors.blue,
                              width: double.infinity,
                            ),
                          ],
                        ),
                      const SizedBox(height: defaultPadding),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: defaultPadding,
                            vertical: defaultPadding / 2,
                          ),
                        ),
                        onPressed: () => _showAddTransactionDialog(context),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Transaction'),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: defaultPadding),
              const SizedBox(height: defaultPadding),
              Text(
                'Recent Transactions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: defaultPadding),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _financialService.watchRecentTransactions(athleteId: _selectedAthleteId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final transactions = snapshot.data!;
                  if (transactions.isEmpty) {
                    return const Center(
                      child: Text('No transactions found'),
                    );
                  }

                  return Card(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(defaultPadding),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columnSpacing: defaultPadding,
                          columns: const [
                            DataColumn(label: Text('Date')),
                            DataColumn(label: Text('Description')),
                            DataColumn(label: Text('Category')),
                            DataColumn(label: Text('Type')),
                            DataColumn(label: Text('Amount')),
                          ],
                          rows: transactions.map((transaction) {
                            final date = transaction['date'] as DateTime;
                            final amount = transaction['amount'] as double;
                            final type = transaction['type'] as String;

                            return DataRow(
                              cells: [
                                DataCell(Text(DateFormat('MMM d, y').format(date))),
                                DataCell(
                                  Container(
                                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.2),
                                    child: Text(
                                      transaction['description'] ?? '',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                DataCell(Text(transaction['categoryName'] as String? ?? _getCategoryName(transaction['category'] ?? ''))),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        type == 'income' ? Icons.arrow_upward : Icons.arrow_downward,
                                        color: type == 'income' ? Colors.green : Colors.red,
                                        size: 16,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(type.toUpperCase()),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    '\$${amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      color: type == 'income' ? Colors.green : Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        tablet: SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add athlete dropdown
              _buildAthleteDropdown(),
              const SizedBox(height: defaultPadding),
              
              StreamBuilder<Map<String, dynamic>>(
                stream: _financialService.watchFinancialSummary(athleteId: _selectedAthleteId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final data = snapshot.data!;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 1,
                        child: _buildSummaryCard(
                          title: 'Total Income',
                          value: '\$${(data['totalIncome'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                          icon: Icons.trending_up,
                          color: Colors.green,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: _buildSummaryCard(
                          title: 'Total Expenses',
                          value: '\$${(data['totalExpenses'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                          icon: Icons.trending_down,
                          color: Colors.red,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: _buildSummaryCard(
                          title: 'Net Balance',
                          value: '\$${((data['totalIncome'] ?? 0.0) - (data['totalExpenses'] ?? 0.0)).toStringAsFixed(2)}',
                          icon: Icons.account_balance_wallet,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: defaultPadding),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: defaultPadding,
                        vertical: defaultPadding / 2,
                      ),
                    ),
                    onPressed: () => _showAddTransactionDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Transaction'),
                  ),
                ],
              ),
              const SizedBox(height: defaultPadding),
              Text(
                'Recent Transactions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: defaultPadding),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _financialService.watchRecentTransactions(athleteId: _selectedAthleteId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final transactions = snapshot.data!;
                  if (transactions.isEmpty) {
                    return const Center(
                      child: Text('No transactions found'),
                    );
                  }

                  return Card(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(defaultPadding),
                      child: DataTable(
                        columnSpacing: defaultPadding,
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Description')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Amount')),
                        ],
                        rows: transactions.map((transaction) {
                          final date = transaction['date'] as DateTime;
                          final amount = transaction['amount'] as double;
                          final type = transaction['type'] as String;

                          return DataRow(
                            cells: [
                              DataCell(Text(DateFormat('MMM d, y').format(date))),
                              DataCell(
                                Container(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.2),
                                  child: Text(
                                    transaction['description'] ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(transaction['categoryName'] as String? ?? _getCategoryName(transaction['category'] ?? ''))),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      type == 'income' ? Icons.arrow_upward : Icons.arrow_downward,
                                      color: type == 'income' ? Colors.green : Colors.red,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(type.toUpperCase()),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  '\$${amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: type == 'income' ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        desktop: SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add athlete dropdown
              _buildAthleteDropdown(),
              const SizedBox(height: defaultPadding),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StreamBuilder<Map<String, dynamic>>(
                    stream: _financialService.watchFinancialSummary(athleteId: _selectedAthleteId),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }

                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }

                      final data = snapshot.data!;
                      return Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 1,
                              child: _buildSummaryCard(
                                title: 'Total Income',
                                value: '\$${(data['totalIncome'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                icon: Icons.trending_up,
                                color: Colors.green,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: _buildSummaryCard(
                                title: 'Total Expenses',
                                value: '\$${(data['totalExpenses'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                                icon: Icons.trending_down,
                                color: Colors.red,
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: _buildSummaryCard(
                                title: 'Net Balance',
                                value: '\$${((data['totalIncome'] ?? 0.0) - (data['totalExpenses'] ?? 0.0)).toStringAsFixed(2)}',
                                icon: Icons.account_balance_wallet,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: defaultPadding),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: defaultPadding,
                        vertical: defaultPadding / 2,
                      ),
                    ),
                    onPressed: () => _showAddTransactionDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Transaction'),
                  ),
                ],
              ),
              const SizedBox(height: defaultPadding),
              Text(
                'Recent Transactions',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: defaultPadding),
              StreamBuilder<List<Map<String, dynamic>>>(
                stream: _financialService.watchRecentTransactions(athleteId: _selectedAthleteId),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Text('Error: ${snapshot.error}');
                  }

                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final transactions = snapshot.data!;
                  if (transactions.isEmpty) {
                    return const Center(
                      child: Text('No transactions found'),
                    );
                  }

                  return Card(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(defaultPadding),
                      child: DataTable(
                        columnSpacing: defaultPadding,
                        columns: const [
                          DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Description')),
                          DataColumn(label: Text('Category')),
                          DataColumn(label: Text('Type')),
                          DataColumn(label: Text('Amount')),
                        ],
                        rows: transactions.map((transaction) {
                          final date = transaction['date'] as DateTime;
                          final amount = transaction['amount'] as double;
                          final type = transaction['type'] as String;

                          return DataRow(
                            cells: [
                              DataCell(Text(DateFormat('MMM d, y').format(date))),
                              DataCell(
                                Container(
                                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.2),
                                  child: Text(
                                    transaction['description'] ?? '',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                              DataCell(Text(transaction['categoryName'] as String? ?? _getCategoryName(transaction['category'] ?? ''))),
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      type == 'income' ? Icons.arrow_upward : Icons.arrow_downward,
                                      color: type == 'income' ? Colors.green : Colors.red,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(type.toUpperCase()),
                                  ],
                                ),
                              ),
                              DataCell(
                                Text(
                                  '\$${amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: type == 'income' ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    double? width,
  }) {
    return Card(
      child: Container(
        width: width,
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: defaultPadding / 2),
                Text(title),
              ],
            ),
            const SizedBox(height: defaultPadding / 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTransactionDialog(BuildContext context) async {
    _amountController.clear();
    _descriptionController.clear();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Transaction'),
            content: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'income', child: Text('Income')),
                      DropdownMenuItem(value: 'expense', child: Text('Expense')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: defaultPadding),
                  StreamBuilder<QuerySnapshot>(
                    stream: _selectedAthleteId != null 
                      ? FirebaseFirestore.instance
                          .collection('athlete_budget_categories')
                          .where('athleteId', isEqualTo: _selectedAthleteId)
                          .snapshots()
                      : Stream.empty(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data == null || snapshot.data!.docs.isEmpty) {
                        if (!snapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'No categories found for this athlete. Please add categories first.',
                              style: TextStyle(color: Colors.red),
                            ),
                            SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('Close'),
                            ),
                          ],
                        );
                      }

                      final categories = snapshot.data!.docs;
                      
                      // Reset selected category if it doesn't exist in the current athlete's categories
                      if (_selectedCategory.isEmpty || !categories.any((doc) => doc.id == _selectedCategory)) {
                        if (categories.isNotEmpty) {
                          _selectedCategory = categories.first.id;
                        }
                      }
                      
                      return DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: categories.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final category = data['name'] as String? ?? 'Unnamed Category';
                          return DropdownMenuItem(
                            value: doc.id,
                            child: Text(category),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a category';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: defaultPadding),
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                      prefixText: '\$',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an amount';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      if (double.parse(value) <= 0) {
                        return 'Amount must be greater than zero';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: defaultPadding),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (_formKey.currentState!.validate()) {
                          setState(() => _isLoading = true);
                          try {
                            await _financialService.addTransaction(
                              type: _selectedType,
                              category: _selectedCategory,
                              amount: double.parse(_amountController.text),
                              description: _descriptionController.text,
                              athleteId: _selectedAthleteId,
                            );
                            if (mounted) {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Transaction added successfully'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error adding transaction: $e'),
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setState(() => _isLoading = false);
                            }
                          }
                        }
                      },
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Add this method to build the athlete dropdown
  Widget _buildAthleteDropdown() {
    if (_isLoadingAthletes) {
      return Container(
        padding: const EdgeInsets.all(defaultPadding),
        decoration: BoxDecoration(
          color: secondaryColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
            SizedBox(width: 10),
            Text('Loading athletes...', style: TextStyle(color: Colors.white70)),
          ],
        ),
      );
    }

    if (_athletes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(defaultPadding),
        decoration: BoxDecoration(
          color: secondaryColor,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'No athletes found for this organization. Add athletes with this organization assigned to view their financial data.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: defaultPadding, vertical: defaultPadding / 2),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'ATHLETE FINANCIAL DATA',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedAthleteId,
            dropdownColor: secondaryColor,
            isExpanded: true,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.person, color: Colors.white70),
              border: OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white24),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blue),
                borderRadius: BorderRadius.all(Radius.circular(10)),
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              fillColor: Colors.black12,
              filled: true,
            ),
            style: const TextStyle(color: Colors.white, fontSize: 16),
            items: _athletes.map((athlete) {
              return DropdownMenuItem<String>(
                value: athlete['id'],
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAthleteAvatar(athlete),
                    const SizedBox(width: 10),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return Container(
                            height: 24, // Fixed height to prevent overflow
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    "${athlete['name']} (${athlete['email']})",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedAthleteId = value;
                // Reload financial data for the selected athlete
                // No need to explicitly reload as StreamBuilder will automatically update
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAthleteAvatar(Map<String, dynamic> athlete) {
    if (athlete['profileImage'] != null) {
      try {
        final imageData = athlete['profileImage'];
        if (imageData is List<dynamic>) {
          return CircleAvatar(
            radius: 16,
            backgroundImage: MemoryImage(Uint8List.fromList(imageData.cast<int>())),
            backgroundColor: Colors.grey[800],
          );
        }
      } catch (e) {
        print('Error loading profile image: $e');
      }
    }
    
    return CircleAvatar(
      radius: 16,
      backgroundColor: Colors.blue.withOpacity(0.2),
      child: const Icon(Icons.person, size: 20, color: Colors.white70),
    );
  }
}
