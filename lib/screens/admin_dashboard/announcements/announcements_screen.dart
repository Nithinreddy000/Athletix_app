import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';
import '../../../responsive.dart';
import '../../../services/announcement_service.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({Key? key}) : super(key: key);

  @override
  _AnnouncementsScreenState createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AnnouncementService _announcementService = AnnouncementService();
  String targetRole = 'Athlete';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Responsive(
      mobile: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: defaultPadding),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: defaultPadding,
                      ),
                    ),
                    onPressed: _showAddAnnouncementDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                  ),
                ),
              ],
            ),
          ),
          _buildAnnouncementStats(),
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF212332),
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: false,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.deepPurple,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'High Priority'),
                Tab(text: 'Medium'),
                Tab(text: 'All'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _tabController,
              children: [
                _buildHighPriorityTab(),
                _buildMediumPriorityTab(),
                _buildAllAnnouncementsTab(),
              ],
            ),
          ),
        ],
      ),
      tablet: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: Row(
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: defaultPadding * 1.5,
                      vertical: defaultPadding,
                    ),
                  ),
                  onPressed: _showAddAnnouncementDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('New Announcement'),
                ),
              ],
            ),
          ),
          _buildAnnouncementStats(),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'High Priority'),
              Tab(text: 'Medium Priority'),
              Tab(text: 'All Announcements'),
            ],
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _tabController,
              children: [
                _buildHighPriorityTab(),
                _buildMediumPriorityTab(),
                _buildAllAnnouncementsTab(),
              ],
            ),
          ),
        ],
      ),
      desktop: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: Row(
              children: [
                const Text(
                  'Overview',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: defaultPadding * 1.5,
                      vertical: defaultPadding,
                    ),
                  ),
                  onPressed: _showAddAnnouncementDialog,
                  icon: const Icon(Icons.add),
                  label: const Text('New Announcement'),
                ),
              ],
            ),
          ),
          _buildAnnouncementStats(),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'High Priority'),
              Tab(text: 'Medium Priority'),
              Tab(text: 'All Announcements'),
            ],
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              controller: _tabController,
              children: [
                _buildHighPriorityTab(),
                _buildMediumPriorityTab(),
                _buildAllAnnouncementsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnouncementStats() {
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total',
                  8,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: defaultPadding),
              Expanded(
                child: _buildStatCard(
                  'Medium',
                  1,
                  Colors.orange,
                ),
              ),
              const SizedBox(width: defaultPadding),
              Expanded(
                child: _buildStatCard(
                  'High',
                  2,
                  Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF242731),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighPriorityTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _announcementService.getHighPriorityAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No high priority announcements'));
        }

        final announcements = snapshot.data!.docs.take(6).toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent High Priority Announcements',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: defaultPadding),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  final announcement = announcements[index].data() as Map<String, dynamic>;
                  return _buildAnnouncementCard(announcements[index].id, announcement);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediumPriorityTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _announcementService.getMediumPriorityAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No medium priority announcements'));
        }

        final announcements = snapshot.data!.docs.take(6).toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Recent Medium Priority Announcements',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: defaultPadding),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: announcements.length,
                itemBuilder: (context, index) {
                  final announcement = announcements[index].data() as Map<String, dynamic>;
                  return _buildAnnouncementCard(announcements[index].id, announcement);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAllAnnouncementsTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _announcementService.getAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No announcements'));
        }

        final announcements = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(defaultPadding),
          itemCount: announcements.length,
          itemBuilder: (context, index) {
            final announcement = announcements[index].data() as Map<String, dynamic>;
            return _buildAnnouncementCard(announcements[index].id, announcement);
          },
        );
      },
    );
  }

  Widget _buildAnnouncementCard(String id, Map<String, dynamic> announcement) {
    final createdAt = (announcement['createdAt'] as Timestamp?)?.toDate();
    final formattedDate = createdAt != null ? DateFormat('MMM d, y').format(createdAt) : 'Date not available';
    final priority = announcement['priority'] as String;

    Color priorityColor = Colors.grey;
    if (priority == 'high') {
      priorityColor = Colors.red;
    } else if (priority == 'medium') {
      priorityColor = Colors.orange;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: defaultPadding),
      child: ExpansionTile(
        title: Text(
          announcement['title'],
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Row(
          children: [
            Expanded(
              child: Text(
                'Created on $formattedDate',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        leading: Container(
          margin: const EdgeInsets.only(left: 4),
          child: Icon(Icons.circle, color: priorityColor, size: 12),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  announcement['content'],
                  style: const TextStyle(height: 1.5),
                ),
                if (announcement['targetRoles'] != null && announcement['targetRoles'].isNotEmpty) ...[
                  const SizedBox(height: defaultPadding / 2),
                  Wrap(
                    spacing: 4,
                    children: [
                      const Text(
                        'Target Roles:',
                        style: TextStyle(fontStyle: FontStyle.italic),
                      ),
                      Text(
                        announcement['targetRoles'].join(', '),
                        style: const TextStyle(fontStyle: FontStyle.italic),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddAnnouncementDialog() {
    showDialog(
      context: context,
      builder: (context) => AddAnnouncementDialog(
        announcementService: _announcementService,
        targetRole: targetRole,
      ),
    );
  }
}

class AddAnnouncementDialog extends StatefulWidget {
  final AnnouncementService announcementService;
  final String targetRole;

  const AddAnnouncementDialog({
    Key? key,
    required this.announcementService,
    required this.targetRole,
  }) : super(key: key);

  @override
  _AddAnnouncementDialogState createState() => _AddAnnouncementDialogState();
}

class _AddAnnouncementDialogState extends State<AddAnnouncementDialog> {
  final titleController = TextEditingController();
  final contentController = TextEditingController();
  String priority = 'low';
  List<String> targetRoles = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    targetRoles = [widget.targetRole];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Announcement'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: defaultPadding),
            TextField(
              controller: contentController,
              decoration: const InputDecoration(
                labelText: 'Content',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: defaultPadding),
            DropdownButtonFormField<String>(
              value: priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: ['low', 'medium', 'high'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value.toUpperCase()),
                );
              }).toList(),
              onChanged: (String? value) {
                setState(() {
                  priority = value ?? 'low';
                });
              },
            ),
            const SizedBox(height: defaultPadding),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Target Roles'),
                CheckboxListTile(
                  title: const Text('Athlete'),
                  value: targetRoles.contains('Athlete'),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value!) {
                        targetRoles.add('Athlete');
                      } else {
                        targetRoles.remove('Athlete');
                      }
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Medical'),
                  value: targetRoles.contains('Medical'),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value!) {
                        targetRoles.add('Medical');
                      } else {
                        targetRoles.remove('Medical');
                      }
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Organisations'),
                  value: targetRoles.contains('Organisations'),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value!) {
                        targetRoles.add('Organisations');
                      } else {
                        targetRoles.remove('Organisations');
                      }
                    });
                  },
                ),
                CheckboxListTile(
                  title: const Text('Coaches'),
                  value: targetRoles.contains('Coaches'),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value!) {
                        targetRoles.add('Coaches');
                      } else {
                        targetRoles.remove('Coaches');
                      }
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        if (isLoading)
          const CircularProgressIndicator()
        else
          ElevatedButton(
            onPressed: _createAnnouncement,
            child: const Text('Create'),
          ),
      ],
    );
  }

  void _createAnnouncement() async {
    if (titleController.text.isEmpty || contentController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all required fields')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await widget.announcementService.createAnnouncement(
        title: titleController.text,
        content: contentController.text,
        priority: priority,
        targetRoles: targetRoles,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement created successfully')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating announcement: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }
}
