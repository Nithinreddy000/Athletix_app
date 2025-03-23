import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:typed_data';
import '../../../constants.dart';
import '../../../responsive.dart';
import '../../../services/budget_service.dart';

class BudgetAnalysisDashboard extends StatefulWidget {
  const BudgetAnalysisDashboard({Key? key}) : super(key: key);

  @override
  _BudgetAnalysisDashboardState createState() => _BudgetAnalysisDashboardState();
}

class _BudgetAnalysisDashboardState extends State<BudgetAnalysisDashboard> with SingleTickerProviderStateMixin {
  final Map<String, String> _categoryMap = {};
  late TabController _tabController;
  final BudgetService _budgetService = BudgetService();
  Map<String, dynamic> _overview = {};
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _transactions = [];
  StreamSubscription<Map<String, dynamic>>? _overviewSubscription;
  bool _isLoading = false;
  
  // Athlete selection variables
  List<Map<String, dynamic>> _athletes = [];
  String? _selectedAthleteId;
  bool _isLoadingAthletes = true;
  String _organizationId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadOrganizationId().then((_) {
      _loadAthletes().then((_) {
        // Only load data after athletes are loaded and selected
        if (_selectedAthleteId != null) {
          _loadData();
          _setupSubscriptions();
        }
      });
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

  void _setupSubscriptions() {
    // Cancel existing subscription if any
    _overviewSubscription?.cancel();
    
    // Only set up subscription if we have an athlete ID
    if (_selectedAthleteId != null) {
      print('Setting up budget overview subscription for athlete: $_selectedAthleteId');
      _overviewSubscription = _budgetService.watchBudgetOverview(athleteId: _selectedAthleteId).listen(
        (overview) {
          if (mounted) {
            print('Received overview update from Firestore: $overview');
            setState(() {
              // Always update the overview with the latest data
              _overview = overview;
            });
          }
        },
        onError: (error) {
          print('Error in budget overview subscription: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error loading overview: $error')),
            );
          }
        },
      );
    }
  }

  Future<void> _loadData() async {
    if (!mounted || _selectedAthleteId == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      print('Loading data for athlete ID: $_selectedAthleteId');
      
      // First, clean up any problematic categories
      await _cleanupProblematicCategories();
      
      // Load categories and transactions in parallel
      final categoriesFuture = _budgetService.getBudgetCategories(athleteId: _selectedAthleteId);
      final transactionsFuture = _budgetService.getRecentTransactions(athleteId: _selectedAthleteId);
      final overviewFuture = _budgetService.getBudgetOverview(athleteId: _selectedAthleteId);
      
      // Use await for each future separately to avoid type issues
      final categories = await categoriesFuture;
      final transactions = await transactionsFuture;
      final overview = await overviewFuture;

      print('Categories loaded: $categories');
      print('Transactions loaded: $transactions');
      print('Overview loaded: $overview');

      if (mounted) {
        setState(() {
          _categories = categories;
          _transactions = transactions;
          _categoryMap.clear(); // Clear previous category mappings
          
          // Always update the overview with the data from Firestore
          _overview = overview;
          
          // Map categories for reference
          for (var category in _categories) {
            if (category['id'] != null && category['name'] != null) {
              _categoryMap[category['id']] = category['name'] as String? ?? 'Unnamed Category';
            }
          }
          
          // Also map category names from transactions if they have categoryName field
          for (var transaction in _transactions) {
            if (transaction['category'] != null && transaction['categoryName'] != null) {
              _categoryMap[transaction['category']] = transaction['categoryName'] as String;
            }
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Reset data on error
          _overview = {
            'totalBudget': 0.0,
            'totalExpenses': 0.0,
            'totalIncome': 0.0,
            'lastUpdated': DateTime.now(),
          };
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }
  
  // Method to clean up any problematic categories
  Future<void> _cleanupProblematicCategories() async {
    if (_selectedAthleteId == null) return;
    
    try {
      // Get all categories for the athlete
      final snapshot = await FirebaseFirestore.instance
          .collection('athlete_budget_categories')
          .where('athleteId', isEqualTo: _selectedAthleteId)
          .get();
      
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String?;
        final budget = (data['budget'] as num?)?.toDouble();
        final spent = (data['spent'] as num?)?.toDouble();
        
        // Check for problematic categories (missing required fields or strange values)
        bool isProblematic = false;
        
        if (name == null || name.isEmpty) isProblematic = true;
        if (budget == null) isProblematic = true;
        if (spent == null) isProblematic = true;
        
        // If spent is unreasonably high (e.g., over $10,000) and budget is 0 or very low
        if (spent != null && budget != null && spent > 10000 && budget < 100) {
          isProblematic = true;
        }
        
        if (isProblematic) {
          print('Found problematic category: ${doc.id}. Deleting it.');
          await FirebaseFirestore.instance
              .collection('athlete_budget_categories')
              .doc(doc.id)
              .delete();
        }
      }
    } catch (e) {
      print('Error cleaning up problematic categories: $e');
    }
  }

  String _getCategoryName(String categoryId) {
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
      }
    } catch (e) {
      print('Error fetching category name for $categoryId: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Responsive(
        mobile: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: _buildAthleteDropdown(),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Categories'),
                Tab(text: 'Transactions'),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildCategoriesTab(),
                  _buildTransactionsTab(),
                ],
              ),
            ),
          ],
        ),
        tablet: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: _buildAthleteDropdown(),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Categories'),
                Tab(text: 'Transactions'),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildCategoriesTab(),
                  _buildTransactionsTab(),
                ],
              ),
            ),
          ],
        ),
        desktop: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: _buildAthleteDropdown(),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Categories'),
                Tab(text: 'Transactions'),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildCategoriesTab(),
                  _buildTransactionsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Budget Overview',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: defaultPadding),
          if (Responsive.isDesktop(context))
            // Desktop layout - cards in a row
            Row(
              children: [
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Total Budget',
                    value: '\$${(_overview['totalBudget'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    icon: Icons.account_balance,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: defaultPadding),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Total Expenses',
                    value: '\$${(_overview['totalExpenses'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    icon: Icons.trending_down,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: defaultPadding),
                Expanded(
                  child: _buildSummaryCard(
                    title: 'Total Income',
                    value: '\$${(_overview['totalIncome'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                    icon: Icons.trending_up,
                    color: Colors.green,
                  ),
                ),
              ],
            )
          else
            // Mobile/Tablet layout - cards in a column
            Column(
              children: [
                _buildSummaryCard(
                  title: 'Total Budget',
                  value: '\$${(_overview['totalBudget'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                  icon: Icons.account_balance,
                  color: Colors.blue,
                  width: double.infinity,
                ),
                _buildSummaryCard(
                  title: 'Total Expenses',
                  value: '\$${(_overview['totalExpenses'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                  icon: Icons.trending_down,
                  color: Colors.red,
                  width: double.infinity,
                ),
                _buildSummaryCard(
                  title: 'Total Income',
                  value: '\$${(_overview['totalIncome'] as num?)?.toStringAsFixed(2) ?? '0.00'}',
                  icon: Icons.trending_up,
                  color: Colors.green,
                  width: double.infinity,
                ),
              ],
            ),
          const SizedBox(height: defaultPadding * 2),
          Text(
            'Overall Budget Progress',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: defaultPadding),
          LinearProgressIndicator(
            value: _calculateBudgetProgress(),
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(
              _calculateBudgetHealth() >= 0.7 ? Colors.green :
              _calculateBudgetHealth() >= 0.4 ? Colors.orange : Colors.red,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: defaultPadding / 2),
            child: Text(
              '${(_calculateBudgetProgress() * 100).toStringAsFixed(1)}% of budget utilized',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: defaultPadding * 2),
          Text(
            'Recent Transactions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: defaultPadding),
          _buildRecentTransactionsList(),
        ],
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Budget Categories',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showAddCategoryDialog(),
                tooltip: 'Add Category',
              ),
            ],
          ),
          const SizedBox(height: defaultPadding),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_categories.isEmpty)
            const Center(
              child: Text('No categories found. Add a category to get started.'),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final name = category['name'] as String? ?? 'Unnamed Category';
                final spent = category['spent'] as double? ?? 0.0;
                final budget = category['budget'] as double? ?? 0.0;
                final progress = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;

                return Card(
                  key: Key(category['id']), // Ensure unique keys
                  child: Padding(
                    padding: const EdgeInsets.all(defaultPadding),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                style: Theme.of(context).textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _showEditCategoryDialog(category),
                              iconSize: 20,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _showDeleteCategoryDialog(category),
                              iconSize: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: defaultPadding),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Budget: \$${budget.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            Text(
                              'Spent: \$${spent.toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: spent > 0 ? Colors.red : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: defaultPadding / 2),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[300],
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 0.9 ? Colors.red :
                            progress >= 0.7 ? Colors.orange :
                            Colors.green,
                          ),
                        ),
                        if (budget > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Remaining: \$${(budget - spent).toStringAsFixed(2)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: budget - spent > 0 ? Colors.green : Colors.red,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildTransactionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Transaction History',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: defaultPadding),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_transactions.isEmpty)
            const Center(
              child: Text('No transactions found'),
            )
          else
            Card(
              child: SizedBox(
                width: double.infinity,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.of(context).size.width - (2 * defaultPadding),
                    ),
                    child: DataTable(
                      columnSpacing: defaultPadding,
                      horizontalMargin: defaultPadding,
                      columns: const [
                        DataColumn(
                          label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                          tooltip: 'Transaction Date',
                        ),
                        DataColumn(
                          label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                          tooltip: 'Transaction Description',
                        ),
                        DataColumn(
                          label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
                          tooltip: 'Transaction Category',
                        ),
                        DataColumn(
                          label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold)),
                          tooltip: 'Transaction Type',
                        ),
                        DataColumn(
                          label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                          tooltip: 'Transaction Amount',
                        ),
                      ],
                      rows: _transactions.map((transaction) {
                        final date = transaction['date'] as DateTime;
                        final amount = transaction['amount'] as double;
                        final type = transaction['type'] as String;
                        
                        // Use categoryName if available, otherwise try to get it from the map
                        final categoryName = transaction['categoryName'] as String? ?? 
                                           _getCategoryName(transaction['category'] ?? '');

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
                            DataCell(Text(categoryName)),
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
              ),
            ),
        ],
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

  Widget _buildRecentTransactionsList() {
    if (_transactions.isEmpty) {
      return const Center(
        child: Text('No recent transactions'),
      );
    }

    return Card(
      child: SizedBox(
        width: double.infinity,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width - (2 * defaultPadding),
            ),
            child: DataTable(
              columnSpacing: defaultPadding,
              horizontalMargin: defaultPadding,
              columns: const [
                DataColumn(
                  label: Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                  tooltip: 'Transaction Date',
                ),
                DataColumn(
                  label: Text('Description', style: TextStyle(fontWeight: FontWeight.bold)),
                  tooltip: 'Transaction Description',
                ),
                DataColumn(
                  label: Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
                  tooltip: 'Transaction Category',
                ),
                DataColumn(
                  label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold)),
                  tooltip: 'Transaction Type',
                ),
                DataColumn(
                  label: Text('Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                  tooltip: 'Transaction Amount',
                ),
              ],
              rows: _transactions.map((transaction) {
                final date = transaction['date'] as DateTime;
                final amount = transaction['amount'] as double;
                final type = transaction['type'] as String;
                
                // Use categoryName if available, otherwise try to get it from the map
                final categoryName = transaction['categoryName'] as String? ?? 
                                   _getCategoryName(transaction['category'] ?? '');

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
                    DataCell(Text(categoryName)),
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
      ),
    );
  }

  double _calculateBudgetProgress() {
    final totalBudget = _overview['totalBudget']?.toDouble() ?? 0.0;
    final totalExpenses = _overview['totalExpenses']?.toDouble() ?? 0.0;
    return totalBudget > 0 ? (totalExpenses / totalBudget).clamp(0.0, 1.0) : 0.0;
  }

  double _calculateBudgetHealth() {
    final totalBudget = _overview['totalBudget']?.toDouble() ?? 0.0;
    final totalExpenses = _overview['totalExpenses']?.toDouble() ?? 0.0;
    return totalBudget > 0 ? ((totalBudget - totalExpenses) / totalBudget).clamp(0.0, 1.0) : 0.0;
  }

  Future<void> _showAddCategoryDialog() async {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Category'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a category name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: defaultPadding),
                    TextFormField(
                      controller: budgetController,
                      decoration: const InputDecoration(
                        labelText: 'Budget Amount',
                        border: OutlineInputBorder(),
                        prefixText: '\$',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a budget amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Budget must be greater than zero';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  nameController.dispose();
                  budgetController.dispose();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setState(() => _isLoading = true);
                          try {
                            await _budgetService.addBudgetCategory(
                              name: nameController.text,
                              budget: double.parse(budgetController.text),
                              athleteId: _selectedAthleteId,
                            );
                            if (mounted) {
                              Navigator.of(context).pop();
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Category added successfully')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error adding category: $e')),
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
                    : const Text('Add'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditCategoryDialog(Map<String, dynamic> category) async {
    final nameController = TextEditingController(text: category['name'] as String?);
    final budgetController = TextEditingController(
      text: (category['budget'] as double?)?.toString() ?? '0.0',
    );
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Edit Category'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Category Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a category name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: defaultPadding),
                    TextFormField(
                      controller: budgetController,
                      decoration: const InputDecoration(
                        labelText: 'Budget Amount',
                        border: OutlineInputBorder(),
                        prefixText: '\$',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a budget amount';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Please enter a valid number';
                        }
                        if (double.parse(value) <= 0) {
                          return 'Budget must be greater than zero';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  nameController.dispose();
                  budgetController.dispose();
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        if (formKey.currentState!.validate()) {
                          setState(() => _isLoading = true);
                          try {
                            await _budgetService.updateBudgetCategory(
                              categoryId: category['id'] as String,
                              name: nameController.text,
                              budget: double.parse(budgetController.text),
                              athleteId: _selectedAthleteId,
                            );
                            if (mounted) {
                              Navigator.of(context).pop();
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Category updated successfully')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error updating category: $e')),
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

  Future<void> _showDeleteCategoryDialog(Map<String, dynamic> category) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text('Are you sure you want to delete the category "${category['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _budgetService.deleteBudgetCategory(
                  category['id'] as String,
                  athleteId: _selectedAthleteId,
                );
                if (mounted) {
                  Navigator.of(context).pop();
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Category deleted successfully')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting category: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

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
                'No athletes found for this organization. Add athletes with this organization assigned to view their budget data.',
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
                'ATHLETE BUDGET DATA',
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
              if (value == _selectedAthleteId) return; // Skip if same athlete selected
              
              print('Athlete selection changed from $_selectedAthleteId to $value');
              
              // Cancel existing subscription
              _overviewSubscription?.cancel();
              
              setState(() {
                _selectedAthleteId = value;
                _isLoading = true;
                
                // Reset data before loading new data
                _overview = {
                  'totalBudget': 0.0,
                  'totalExpenses': 0.0,
                  'totalIncome': 0.0,
                  'lastUpdated': DateTime.now(),
                };
                _categories = [];
                _transactions = [];
                _categoryMap.clear();
              });
              
              // Reload budget data for the selected athlete
              Future.microtask(() {
                _setupSubscriptions();
                _loadData();
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

  @override
  void dispose() {
    _overviewSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }
}
