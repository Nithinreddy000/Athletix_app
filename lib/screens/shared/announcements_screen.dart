import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../constants.dart';
import '../../responsive.dart';
import '../../services/announcement_service.dart';

class SharedAnnouncementsScreen extends StatefulWidget {
  final String userRole;
  
  const SharedAnnouncementsScreen({
    Key? key,
    required this.userRole,
  }) : super(key: key);

  @override
  _SharedAnnouncementsScreenState createState() => _SharedAnnouncementsScreenState();
}

class _SharedAnnouncementsScreenState extends State<SharedAnnouncementsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AnnouncementService _announcementService = AnnouncementService();

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
                  'Announcements',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
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
                  'Announcements',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
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
                  'Announcements',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
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

  Widget _buildHighPriorityTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _announcementService.getHighPriorityAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No high priority announcements'));
        }

        final allAnnouncements = snapshot.data!.docs;
        final filteredAnnouncements = allAnnouncements.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final targetRoles = List<String>.from(data['targetRoles'] ?? []);
          return targetRoles.contains(widget.userRole);
        }).toList();

        if (filteredAnnouncements.isEmpty) {
          return const Center(child: Text('No high priority announcements for you'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'High Priority Announcements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: defaultPadding),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredAnnouncements.length,
                itemBuilder: (context, index) {
                  final announcement = filteredAnnouncements[index].data() as Map<String, dynamic>;
                  return _buildAnnouncementCard(filteredAnnouncements[index].id, announcement);
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
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No medium priority announcements'));
        }

        final allAnnouncements = snapshot.data!.docs;
        final filteredAnnouncements = allAnnouncements.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final targetRoles = List<String>.from(data['targetRoles'] ?? []);
          return targetRoles.contains(widget.userRole);
        }).toList();

        if (filteredAnnouncements.isEmpty) {
          return const Center(child: Text('No medium priority announcements for you'));
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Medium Priority Announcements',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: defaultPadding),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredAnnouncements.length,
                itemBuilder: (context, index) {
                  final announcement = filteredAnnouncements[index].data() as Map<String, dynamic>;
                  return _buildAnnouncementCard(filteredAnnouncements[index].id, announcement);
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
      stream: _announcementService.getActiveAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No announcements'));
        }

        final allAnnouncements = snapshot.data!.docs;
        final filteredAnnouncements = allAnnouncements.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final targetRoles = List<String>.from(data['targetRoles'] ?? []);
          return targetRoles.contains(widget.userRole);
        }).toList();

        if (filteredAnnouncements.isEmpty) {
          return const Center(child: Text('No announcements for you'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(defaultPadding),
          itemCount: filteredAnnouncements.length,
          itemBuilder: (context, index) {
            final announcement = filteredAnnouncements[index].data() as Map<String, dynamic>;
            return _buildAnnouncementCard(filteredAnnouncements[index].id, announcement);
          },
        );
      },
    );
  }

  Widget _buildAnnouncementCard(String id, Map<String, dynamic> announcement) {
    final title = announcement['title'] ?? 'No Title';
    final content = announcement['content'] ?? 'No Content';
    final priority = announcement['priority'] ?? 'low';
    final createdAt = announcement['createdAt'] as Timestamp?;
    final formattedDate = createdAt != null
        ? DateFormat('MMM dd, yyyy').format(createdAt.toDate())
        : 'Unknown date';

    Color priorityColor;
    switch (priority) {
      case 'high':
        priorityColor = Colors.red;
        break;
      case 'medium':
        priorityColor = Colors.orange;
        break;
      default:
        priorityColor = Colors.green;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: defaultPadding),
      child: Padding(
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(content),
            const SizedBox(height: 8),
            Text(
              'Posted on $formattedDate',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
} 