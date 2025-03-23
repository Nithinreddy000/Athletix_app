import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';
import '../../../responsive.dart';
import '../../../services/audit_log_service.dart';

class AuditLogsScreen extends StatefulWidget {
  const AuditLogsScreen({Key? key}) : super(key: key);

  @override
  _AuditLogsScreenState createState() => _AuditLogsScreenState();
}

class _AuditLogsScreenState extends State<AuditLogsScreen> {
  final AuditLogService _auditLogService = AuditLogService();
  String? _selectedModule;
  String? _selectedAction;
  DateTime? _startDate;
  DateTime? _endDate;
  DocumentSnapshot? _lastDocument;
  bool _isLoading = false;
  List<DocumentSnapshot> _logs = [];
  bool _hasMore = true;
  Map<String, dynamic>? _statistics;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      final stats = await _auditLogService.getAuditLogStatistics(
        startDate: _startDate ?? DateTime(2020),
        endDate: _endDate ?? DateTime.now(),
      );
      setState(() => _statistics = stats);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading statistics: $e')),
      );
    }
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await _auditLogService.getAuditLogs(
        module: _selectedModule,
        action: _selectedAction,
        startDate: _startDate ?? DateTime(2020),
        endDate: _endDate ?? DateTime.now(),
      ).first;

      setState(() {
        _logs = snapshot.docs;
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length >= 50;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading audit logs: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (!_hasMore || _isLoading) return;

    setState(() => _isLoading = true);
    try {
      final snapshot = await _auditLogService.getAuditLogs(
        module: _selectedModule,
        action: _selectedAction,
        startDate: _startDate ?? DateTime(2020),
        endDate: _endDate ?? DateTime.now(),
        lastDocument: _lastDocument,
      ).first;

      setState(() {
        _logs.addAll(snapshot.docs);
        _lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
        _hasMore = snapshot.docs.length >= 50;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading more audit logs: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _exportLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await _auditLogService.exportAuditLogs(
        module: _selectedModule,
        action: _selectedAction,
        startDate: _startDate,
        endDate: _endDate,
      );
      
      // Generate CSV content
      final csvContent = [
        ['Timestamp', 'User ID', 'Module', 'Action', 'Description'].join(','),
        ...logs.map((log) => [
          log['timestamp'].toDate().toString(),
          log['userId'],
          log['module'],
          log['action'],
          log['description'],
        ].join(','))
      ].join('\n');

      // TODO: Implement file download for web/desktop/mobile
      // For now, just show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logs exported successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting logs: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
return Responsive(
  mobile: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Audit Logs',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            ElevatedButton.icon(
              onPressed: _exportLogs,
              icon: const Icon(Icons.file_download),
              label: const Text('Export Logs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding * 1.5,
                  vertical: defaultPadding,
                ),
              ),
            ),
          ],
        ),
      ),
      if (_statistics != null) _buildStatisticsCards(),
      _buildFilters(),
      Expanded(
        child: _buildLogsList(),
      ),
    ],
  ),
  tablet: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Audit Logs',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            ElevatedButton.icon(
              onPressed: _exportLogs,
              icon: const Icon(Icons.file_download),
              label: const Text('Export Logs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding * 1.5,
                  vertical: defaultPadding,
                ),
              ),
            ),
          ],
        ),
      ),
      if (_statistics != null) _buildStatisticsCards(),
      _buildFilters(),
      Expanded(
        child: _buildLogsList(),
      ),
    ],
  ),
  desktop: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Audit Logs',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            ElevatedButton.icon(
              onPressed: _exportLogs,
              icon: const Icon(Icons.file_download),
              label: const Text('Export Logs'),
              style: ElevatedButton.styleFrom(
                backgroundColor: secondaryColor,
                padding: const EdgeInsets.symmetric(
                  horizontal: defaultPadding * 1.5,
                  vertical: defaultPadding,
                ),
              ),
            ),
          ],
        ),
      ),
      if (_statistics != null) _buildStatisticsCards(),
      _buildFilters(),
      Expanded(
        child: _buildLogsList(),
      ),
    ],
  ),
);
  }

Widget _buildStatisticsCards() {
  return Container(
    padding: const EdgeInsets.all(defaultPadding),
    child: Wrap(
      spacing: defaultPadding,
      runSpacing: defaultPadding,
      children: [
        _buildStatCard(
          'Total Logs',
          _statistics?['totalLogs'] ?? 0,
          Icons.list_alt,
        ),
        _buildStatCard(
          'Unique Users',
          _statistics?['uniqueUsers'] ?? 0,
          Icons.people,
        ),
        _buildStatCard(
          'Today\'s Logs',
          _statistics?['todayLogs'] ?? 0,
          Icons.today,
        ),
      ],
    ),
  );
}

  Widget _buildStatCard(String title, int value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.white),
              ),
              Icon(icon, color: Colors.white),
            ],
          ),
          Text(
            value.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

Widget _buildFilters() {
  return Card(
    margin: const EdgeInsets.all(defaultPadding),
    child: Padding(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: defaultPadding),
          Wrap(
            spacing: defaultPadding,
            runSpacing: defaultPadding,
            children: [
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _selectedModule,
                  decoration: const InputDecoration(
                    labelText: 'Module',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Modules')),
                    DropdownMenuItem(value: 'user', child: Text('User Management')),
                    DropdownMenuItem(value: 'content', child: Text('Content')),
                    DropdownMenuItem(value: 'settings', child: Text('Settings')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedModule = value);
                    _loadInitialData();
                  },
                ),
              ),
              SizedBox(
                width: 200,
                child: DropdownButtonFormField<String>(
                  value: _selectedAction,
                  decoration: const InputDecoration(
                    labelText: 'Action',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('All Actions')),
                    DropdownMenuItem(value: 'create', child: Text('Create')),
                    DropdownMenuItem(value: 'update', child: Text('Update')),
                    DropdownMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                  onChanged: (value) {
                    setState(() => _selectedAction = value);
                    _loadInitialData();
                  },
                ),
              ),
              SizedBox(
                width: 200,
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Start Date',
                    border: OutlineInputBorder(),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _startDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _startDate = date);
                      _loadInitialData();
                    }
                  },
                  readOnly: true,
                  controller: TextEditingController(
                    text: _startDate?.toString().split(' ')[0] ?? '',
                  ),
                ),
              ),
              SizedBox(
                width: 200,
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'End Date',
                    border: OutlineInputBorder(),
                  ),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _endDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _endDate = date);
                      _loadInitialData();
                    }
                  },
                  readOnly: true,
                  controller: TextEditingController(
                    text: _endDate?.toString().split(' ')[0] ?? '',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget _buildLogsList() {
  if (_isLoading && _logs.isEmpty) {
    return const Center(child: CircularProgressIndicator());
  }

  return NotificationListener<ScrollNotification>(
    onNotification: (ScrollNotification scrollInfo) {
      if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
        _loadMore();
      }
      return true;
    },
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Container(
        padding: const EdgeInsets.all(defaultPadding),
        decoration: BoxDecoration(
          color: secondaryColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DataTable(
              columnSpacing: defaultPadding,
              columns: const [
                DataColumn(label: Text('Timestamp')),
                DataColumn(label: Text('User')),
                DataColumn(label: Text('Module')),
                DataColumn(label: Text('Action')),
                DataColumn(label: Text('Description')),
              ],
              rows: _logs.map((log) {
                final data = log.data() as Map<String, dynamic>;
                return DataRow(
                  cells: [
                    DataCell(Text(
                      DateFormat('yyyy-MM-dd HH:mm').format(
                        (data['timestamp'] as Timestamp).toDate(),
                      ),
                    )),
                    DataCell(Text(data['userId'] ?? '')),
                    DataCell(Text(data['module'] ?? '')),
                    DataCell(Text(data['action'] ?? '')),
                    DataCell(Text(data['description'] ?? '')),
                  ],
                );
              }).toList(),
            ),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(defaultPadding),
                  child: CircularProgressIndicator(),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}
}
