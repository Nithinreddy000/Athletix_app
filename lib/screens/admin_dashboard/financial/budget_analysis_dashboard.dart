import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupSubscriptions();
    _loadData();
  }

  void _setupSubscriptions() {
    _overviewSubscription = _budgetService.watchBudgetOverview().listen(
      (overview) {
        if (mounted) {
          _overview = overview;
        }
      },
      onError: (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading overview: $error')),
          );
        }
      },
    );
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final categories = await _budgetService.getBudgetCategories();
      final transactions = await _budgetService.getRecentTransactions();

      print('Categories loaded: $categories');
      print('Transactions loaded: $transactions');

      if (mounted) {
        setState(() {
          _categories = categories;
          _transactions = transactions;
          for (var category in categories) {
            _categoryMap[category['id']] = category['name'];
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  String _getCategoryName(String categoryId) {
    return _categoryMap[categoryId] ?? categoryId;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Responsive(
        mobile: Column(
          children: [
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
                                category['name'] as String? ?? '',
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
                              style: Theme.of(context).textTheme.bodyMedium,
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
                            DataCell(Text(_getCategoryName(transaction['category'] ?? ''))),
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
                    DataCell(Text(_getCategoryName(transaction['category'] ?? ''))),
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
                await _budgetService.deleteBudgetCategory(category['id'] as String);
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

  @override
  void dispose() {
    _overviewSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }
}
