import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../constants.dart';
import '../../../responsive.dart';
import '../../../services/content_moderation_service.dart';

class ContentModerationDashboard extends StatefulWidget {
  const ContentModerationDashboard({Key? key}) : super(key: key);

  @override
  _ContentModerationDashboardState createState() => _ContentModerationDashboardState();
}

class _ContentModerationDashboardState extends State<ContentModerationDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ContentModerationService _moderationService = ContentModerationService();
  Map<String, dynamic> _overview = {};
  List<Map<String, dynamic>> _reports = [];
  List<Map<String, dynamic>> _flaggedContent = [];
  StreamSubscription<Map<String, dynamic>>? _overviewSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupSubscriptions();
    _loadData();
  }

  void _setupSubscriptions() {
    _overviewSubscription = _moderationService.watchModerationOverview().listen(
      (overview) {
        if (mounted) {
          setState(() {
            _overview = overview;
          });
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
    try {
      final reports = await _moderationService.getRecentReports();
      final flaggedContent = await _moderationService.getFlaggedContent();

      if (mounted) {
        setState(() {
          _reports = reports;
          _flaggedContent = flaggedContent;
        });
      }
    } catch (e) {
      print('Error loading data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Responsive(
      mobile: Scaffold(
        body: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: defaultPadding),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF212332),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                isScrollable: false,
                indicatorColor: Colors.deepPurple,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Reports'),
                  Tab(text: 'Flagged'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildReportsTab(),
                  _buildFlaggedContentTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      tablet: Column(
        children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: defaultPadding),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF212332),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.deepPurple,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
                tabs: const [
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: defaultPadding),
                      child: Text('Overview'),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: defaultPadding),
                      child: Text('Reports'),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: defaultPadding),
                      child: Text('Flagged'),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildReportsTab(),
                _buildFlaggedContentTab(),
              ],
            ),
          ),
        ],
      ),
      desktop: Column(
        children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: defaultPadding),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF212332),
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: Colors.deepPurple,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
                padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
                tabs: const [
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: defaultPadding),
                      child: Text('Overview'),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: defaultPadding),
                      child: Text('Reports'),
                    ),
                  ),
                  Tab(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: defaultPadding),
                      child: Text('Flagged'),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildReportsTab(),
                _buildFlaggedContentTab(),
              ],
            ),
          ),
        ],
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
            'Content Moderation Overview',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: defaultPadding),
          Responsive(
            mobile: Column(
              children: _buildOverviewCards(),
            ),
            tablet: Row(
              children: _buildOverviewCards()
                  .map((card) => Expanded(child: card))
                  .toList(),
            ),
            desktop: Row(
              children: _buildOverviewCards()
                  .map((card) => Expanded(child: card))
                  .toList(),
            ),
          ),
          const SizedBox(height: defaultPadding * 2),
          Text(
            'Recent Reports',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: defaultPadding),
          _buildRecentReportsList(),
        ],
      ),
    );
  }

  List<Widget> _buildOverviewCards() {
    return [
      _buildOverviewCard(
        title: 'Total Reports',
        value: _overview['totalReports']?.toDouble() ?? 0.0,
        icon: Icons.report_problem,
        color: Colors.orange,
      ),
      _buildOverviewCard(
        title: 'Pending Review',
        value: _overview['pendingReview']?.toDouble() ?? 0.0,
        icon: Icons.pending_actions,
        color: Colors.red,
      ),
      _buildOverviewCard(
        title: 'Resolved',
        value: _overview['resolved']?.toDouble() ?? 0.0,
        icon: Icons.check_circle,
        color: Colors.green,
      ),
      _buildOverviewCard(
        title: 'Avg. Response Time',
        value: _overview['averageResponseTime']?.toDouble() ?? 0.0,
        icon: Icons.timer,
        color: Colors.blue,
        isTime: true,
      ),
    ];
  }

  Widget _buildReportsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reports',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _showAddReportDialog(),
                tooltip: 'New Report',
              ),
            ],
          ),
          const SizedBox(height: defaultPadding),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: Responsive.isMobile(context) 
                      ? MediaQuery.of(context).size.width - 40
                      : MediaQuery.of(context).size.width - 300,
                ),
                child: DataTable(
                  columnSpacing: defaultPadding,
                  horizontalMargin: defaultPadding,
                  columns: const [
                    DataColumn(label: Text('Type')),
                    DataColumn(label: Text('Description')),
                    DataColumn(label: Text('Severity')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: _reports.map((report) {
                    return DataRow(
                      cells: [
                        DataCell(Text(report['type'] as String? ?? '')),
                        DataCell(
                          Container(
                            constraints: const BoxConstraints(maxWidth: 200),
                            child: Text(
                              report['description'] as String? ?? '',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(_buildSeverityChip(report['severity'] as String? ?? 'Low')),
                        DataCell(_buildStatusChip(report['status'] as String? ?? 'Pending')),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle),
                                onPressed: () => _updateReportStatus(report['id'] as String, 'Resolved'),
                                tooltip: 'Mark as Resolved',
                                color: Colors.green,
                              ),
                              IconButton(
                                icon: const Icon(Icons.info),
                                onPressed: () => _showReportDetails(report),
                                tooltip: 'View Details',
                                color: Colors.blue,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlaggedContentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Flagged Content',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: defaultPadding),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Content Type')),
                  DataColumn(label: Text('Reason')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Reporter')),
                  DataColumn(label: Text('Actions')),
                ],
                rows: _flaggedContent.map((content) {
                  return DataRow(
                    cells: [
                      DataCell(Text(content['contentType'] as String? ?? '')),
                      DataCell(Text(content['reason'] as String? ?? '')),
                      DataCell(_buildStatusChip(content['status'] as String? ?? 'Pending')),
                      DataCell(Text(content['reporter'] as String? ?? '')),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.visibility),
                              onPressed: () => _viewFlaggedContent(content),
                              tooltip: 'View Content',
                              color: Colors.blue,
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete),
                              onPressed: () => _showDeleteConfirmation(content),
                              tooltip: 'Delete Content',
                              color: Colors.red,
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewCard({
    required String title,
    required double value,
    required IconData icon,
    required Color color,
    bool isTime = false,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: defaultPadding / 2),
                Text(title),
              ],
            ),
            const SizedBox(height: defaultPadding),
            Text(
              isTime ? '${value.toStringAsFixed(1)}h' : value.toStringAsFixed(0),
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

  Widget _buildRecentReportsList() {
    if (_reports.isEmpty) {
      return const Center(
        child: Text('No recent reports'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _reports.length.clamp(0, 5),
      itemBuilder: (context, index) {
        final report = _reports[index];
        return Card(
          child: ListTile(
            leading: Icon(
              Icons.report_problem,
              color: _getSeverityColor(report['severity'] as String? ?? 'Low'),
            ),
            title: Text(report['type'] as String? ?? ''),
            subtitle: Text(report['description'] as String? ?? ''),
            trailing: _buildStatusChip(report['status'] as String? ?? 'Pending'),
          ),
        );
      },
    );
  }

  Widget _buildSeverityChip(String severity) {
    return Chip(
      label: Text(
        severity,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: _getSeverityColor(severity),
    );
  }

  Widget _buildStatusChip(String status) {
    return Chip(
      label: Text(
        status,
        style: const TextStyle(color: Colors.white),
      ),
      backgroundColor: _getStatusColor(status),
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
      default:
        return Colors.green;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'resolved':
        return Colors.green;
      case 'in progress':
        return Colors.orange;
      case 'pending':
      default:
        return Colors.grey;
    }
  }

  Future<void> _showAddReportDialog() async {
    final typeController = TextEditingController();
    final descriptionController = TextEditingController();
    String severity = 'Low';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Report'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: typeController,
                decoration: const InputDecoration(
                  labelText: 'Report Type',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a report type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: defaultPadding),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a description';
                  }
                  return null;
                },
              ),
              const SizedBox(height: defaultPadding),
              DropdownButtonFormField<String>(
                value: severity,
                decoration: const InputDecoration(
                  labelText: 'Severity',
                  border: OutlineInputBorder(),
                ),
                items: ['Low', 'Medium', 'High'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    severity = newValue;
                  }
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
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await _moderationService.addReport(
                    type: typeController.text,
                    description: descriptionController.text,
                    severity: severity,
                  );
                  if (mounted) {
                    Navigator.of(context).pop();
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Report added successfully')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error adding report: $e')),
                    );
                  }
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    typeController.dispose();
    descriptionController.dispose();
  }

  Future<void> _updateReportStatus(String reportId, String status) async {
    try {
      await _moderationService.updateReportStatus(
        reportId: reportId,
        status: status,
      );
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report marked as $status')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating report: $e')),
        );
      }
    }
  }

  void _showReportDetails(Map<String, dynamic> report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Type', report['type'] as String? ?? ''),
            _buildDetailRow('Description', report['description'] as String? ?? ''),
            _buildDetailRow('Severity', report['severity'] as String? ?? ''),
            _buildDetailRow('Status', report['status'] as String? ?? ''),
            _buildDetailRow('Reporter', report['reporter'] as String? ?? ''),
            _buildDetailRow('Timestamp', report['timestamp'].toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _viewFlaggedContent(Map<String, dynamic> content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Flagged Content Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Content Type', content['contentType'] as String? ?? ''),
            _buildDetailRow('Reason', content['reason'] as String? ?? ''),
            _buildDetailRow('Status', content['status'] as String? ?? ''),
            _buildDetailRow('Reporter', content['reporter'] as String? ?? ''),
            _buildDetailRow('Content ID', content['contentId'] as String? ?? ''),
            _buildDetailRow('Timestamp', content['timestamp'].toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Flagged Content'),
        content: const Text('Are you sure you want to delete this content? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // Implement delete functionality
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
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
