import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:admin/services/announcement_service.dart';

class AnnouncementManagement extends StatefulWidget {
  const AnnouncementManagement({Key? key}) : super(key: key);

  @override
  _AnnouncementManagementState createState() => _AnnouncementManagementState();
}

class _AnnouncementManagementState extends State<AnnouncementManagement> {
  final AnnouncementService _announcementService = AnnouncementService();
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedPriority = 'medium';
  List<String> _selectedRoles = ['athlete'];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  void _showAddAnnouncementDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Create Announcement'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(labelText: 'Title'),
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter a title' : null,
                ),
                SizedBox(height: 16),
                TextFormField(
                  controller: _contentController,
                  decoration: InputDecoration(labelText: 'Content'),
                  maxLines: 3,
                  validator: (value) =>
                      value?.isEmpty ?? true ? 'Please enter content' : null,
                ),
                SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedPriority,
                  items: ['high', 'medium', 'low']
                      .map((priority) => DropdownMenuItem(
                            value: priority,
                            child: Text(priority.toUpperCase()),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPriority = value!;
                    });
                  },
                  decoration: InputDecoration(labelText: 'Priority'),
                ),
                SizedBox(height: 16),
                Text('Target Roles:', style: Theme.of(context).textTheme.titleSmall),
                Wrap(
                  spacing: 8,
                  children: ['admin', 'coach', 'athlete', 'organization']
                      .map((role) => FilterChip(
                            label: Text(role.toUpperCase()),
                            selected: _selectedRoles.contains(role),
                            onSelected: (selected) {
                              setState(() {
                                if (selected) {
                                  _selectedRoles.add(role);
                                } else {
                                  _selectedRoles.remove(role);
                                }
                              });
                            },
                          ))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                await _announcementService.createAnnouncement(
                  title: _titleController.text,
                  content: _contentController.text,
                  priority: _selectedPriority,
                  targetRoles: _selectedRoles,
                );
                Navigator.pop(context);
                _titleController.clear();
                _contentController.clear();
                setState(() {
                  _selectedPriority = 'medium';
                  _selectedRoles = ['athlete'];
                });
              }
            },
            child: Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Announcements',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                ElevatedButton.icon(
                  onPressed: _showAddAnnouncementDialog,
                  icon: Icon(Icons.add),
                  label: Text('Create Announcement'),
                ),
              ],
            ),
            SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: _announcementService.getAllAnnouncements(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var doc = snapshot.data!.docs[index];
                    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(data['title'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(data['content'] ?? ''),
                            SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: [
                                Chip(
                                  label: Text(data['priority'].toString().toUpperCase()),
                                  backgroundColor: data['priority'] == 'high'
                                      ? Colors.red[100]
                                      : data['priority'] == 'medium'
                                          ? Colors.orange[100]
                                          : Colors.green[100],
                                ),
                                ...(data['targetRoles'] as List<dynamic>)
                                    .map((role) => Chip(label: Text(role.toString())))
                                    .toList(),
                              ],
                            ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                data['status'] == 'active'
                                    ? Icons.archive
                                    : Icons.unarchive,
                                color: Colors.grey,
                              ),
                              onPressed: () async {
                                await _announcementService.updateAnnouncement(
                                  doc.id,
                                  status: data['status'] == 'active'
                                      ? 'archived'
                                      : 'active',
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                bool confirm = await showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: Text('Confirm Delete'),
                                    content: Text(
                                        'Are you sure you want to delete this announcement?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm) {
                                  await _announcementService
                                      .deleteAnnouncement(doc.id);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 