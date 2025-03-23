import 'package:flutter/material.dart';
import '../../../constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationsPanel extends StatefulWidget {
  @override
  _NotificationsPanelState createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> notifications = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        final QuerySnapshot notificationsSnapshot = await _firestore
            .collection('notifications')
            .where('recipientId', isEqualTo: currentUser.uid)
            .orderBy('timestamp', descending: true)
            .limit(20)
            .get();

        setState(() {
          notifications = notificationsSnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  })
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Notifications",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: Icon(Icons.refresh),
                onPressed: _loadNotifications,
              ),
            ],
          ),
          SizedBox(height: defaultPadding),
          isLoading
              ? Center(child: CircularProgressIndicator())
              : notifications.isEmpty
                  ? Center(
                      child: Text(
                        "No notifications",
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : Expanded(
                      child: ListView.builder(
                        itemCount: notifications.length,
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return Card(
                            color: notification['read'] == true
                                ? secondaryColor
                                : primaryColor.withOpacity(0.1),
                            child: ListTile(
                              leading: _buildNotificationIcon(
                                  notification['type'] ?? 'general'),
                              title: Text(notification['title'] ?? ''),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(notification['message'] ?? ''),
                                  SizedBox(height: 4),
                                  Text(
                                    _formatTimestamp(
                                        notification['timestamp'] as Timestamp),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              onTap: () =>
                                  _markAsRead(notification['id'] as String),
                            ),
                          );
                        },
                      ),
                    ),
        ],
      ),
    );
  }

  Widget _buildNotificationIcon(String type) {
    IconData icon;
    Color color;

    switch (type) {
      case 'injury':
        icon = Icons.healing;
        color = Colors.red;
        break;
      case 'training':
        icon = Icons.fitness_center;
        color = Colors.green;
        break;
      case 'performance':
        icon = Icons.trending_up;
        color = Colors.blue;
        break;
      default:
        icon = Icons.notifications;
        color = Colors.grey;
    }

    return Icon(icon, color: color);
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('notifications')
          .doc(notificationId)
          .update({'read': true});

      setState(() {
        notifications = notifications.map((notification) {
          if (notification['id'] == notificationId) {
            return {...notification, 'read': true};
          }
          return notification;
        }).toList();
      });
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }
}
