import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final categories = await FirebaseFirestore.instance
          .collection('budget_categories')
          .get();
      for (var doc in categories.docs) {
        _categoryMap[doc.id] = doc.get('name');
      }
      if (categories.docs.isNotEmpty) {
        setState(() {
          _selectedCategory = categories.docs.first.id;
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

  String _getCategoryName(String categoryId) {
    return _categoryMap[categoryId] ?? categoryId;
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
              StreamBuilder<Map<String, dynamic>>(
                stream: _financialService.watchFinancialSummary(),
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
                stream: _financialService.watchRecentTransactions(),
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
                                DataCell(Text(transaction['description'] ?? '')),
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
              StreamBuilder<Map<String, dynamic>>(
                stream: _financialService.watchFinancialSummary(),
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
                stream: _financialService.watchRecentTransactions(),
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
                              DataCell(Text(transaction['description'] ?? '')),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StreamBuilder<Map<String, dynamic>>(
                    stream: _financialService.watchFinancialSummary(),
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
                stream: _financialService.watchRecentTransactions(),
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
                              DataCell(Text(transaction['description'] ?? '')),
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
                    stream: FirebaseFirestore.instance
                        .collection('budget_categories')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }

                      final categories = snapshot.data!.docs;
                      return DropdownButtonFormField<String>(
                        value: _selectedCategory.isEmpty
                            ? categories.first.id
                            : _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: categories.map((doc) {
                          final category = doc.get('name') as String;
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
}
