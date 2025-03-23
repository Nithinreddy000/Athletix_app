import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create new announcement
  Future<void> createAnnouncement({
    required String title,
    required String content,
    required String priority,
    required List<String> targetRoles,
  }) {
    return _firestore.collection('announcements').add({
      'title': title,
      'content': content,
      'priority': priority.toLowerCase(),
      'status': 'active',
      'targetRoles': targetRoles,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // Get active announcements
  Stream<QuerySnapshot> getAnnouncements() {
    return _firestore.collection('announcements').snapshots();
  }

  // Get announcement statistics
  Stream<Map<String, int>> getAnnouncementStatisticsStream() {
    return _firestore.collection('announcements').snapshots().map((snapshot) {
      Map<String, int> stats = {
        'total': 0,
        'active': 0,
        'archived': 0,
        'highPriority': 0,
        'mediumPriority': 0,
      };

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        stats['total'] = stats['total']! + 1;

        if (data['status'] == 'active') {
          stats['active'] = stats['active']! + 1;
        } else if (data['status'] == 'archived') {
          stats['archived'] = stats['archived']! + 1;
        }

        if (data['priority'] == 'high' && data['status'] == 'active') {
          stats['highPriority'] = stats['highPriority']! + 1;
        }

        if (data['priority'] == 'medium' && data['status'] == 'active') {
          stats['mediumPriority'] = stats['mediumPriority']! + 1;
        }
      }

      return stats;
    });
  }

  // Get active announcements
  Stream<QuerySnapshot> getActiveAnnouncements() {
    return _firestore.collection('announcements').where('status', isEqualTo: 'active').snapshots();
  }

  // Get high priority announcements
  Stream<QuerySnapshot> getHighPriorityAnnouncements() {
    return _firestore.collection('announcements').where('priority', isEqualTo: 'high').snapshots();
  }

  // Get medium priority announcements
  Stream<QuerySnapshot> getMediumPriorityAnnouncements() {
    return _firestore.collection('announcements').where('priority', isEqualTo: 'medium').snapshots();
  }
}
