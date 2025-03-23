import 'package:cloud_firestore/cloud_firestore.dart';

class ContentModerationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get content moderation overview
  Stream<Map<String, dynamic>> watchModerationOverview() {
    return _firestore
        .collection('moderation_overview')
        .doc('current')
        .snapshots()
        .map((snapshot) => snapshot.data() as Map<String, dynamic>? ?? {
              'totalReports': 0,
              'pendingReview': 0,
              'resolved': 0,
              'averageResponseTime': 0.0,
              'lastUpdated': DateTime.now(),
            });
  }

  // Get recent reports
  Future<List<Map<String, dynamic>>> getRecentReports() async {
    final snapshot = await _firestore
        .collection('reports')
        .orderBy('timestamp', descending: true)
        .limit(10)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'type': data['type'] as String? ?? 'Unknown',
        'status': data['status'] as String? ?? 'Pending',
        'description': data['description'] as String? ?? '',
        'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
        'reporter': data['reporter'] as String? ?? 'Anonymous',
        'severity': data['severity'] as String? ?? 'Low',
      };
    }).toList();
  }

  // Get flagged content
  Future<List<Map<String, dynamic>>> getFlaggedContent() async {
    final snapshot = await _firestore
        .collection('flagged_content')
        .orderBy('timestamp', descending: true)
        .get();

    return snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'contentType': data['contentType'] as String? ?? 'Unknown',
        'reason': data['reason'] as String? ?? '',
        'status': data['status'] as String? ?? 'Pending',
        'timestamp': data['timestamp']?.toDate() ?? DateTime.now(),
        'reporter': data['reporter'] as String? ?? 'Anonymous',
        'contentId': data['contentId'] as String? ?? '',
      };
    }).toList();
  }

  // Update report status
  Future<void> updateReportStatus({
    required String reportId,
    required String status,
    String? resolution,
  }) async {
    await _firestore.collection('reports').doc(reportId).update({
      'status': status,
      'resolution': resolution,
      'resolvedAt': FieldValue.serverTimestamp(),
    });

    // Update overview statistics
    final batch = _firestore.batch();
    final overviewRef = _firestore.collection('moderation_overview').doc('current');
    
    if (status == 'Resolved') {
      batch.set(overviewRef, {
        'resolved': FieldValue.increment(1),
        'pendingReview': FieldValue.increment(-1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  // Add new report
  Future<void> addReport({
    required String type,
    required String description,
    required String severity,
    String? reporter,
  }) async {
    final batch = _firestore.batch();
    
    // Add the report
    final reportRef = _firestore.collection('reports').doc();
    batch.set(reportRef, {
      'type': type,
      'description': description,
      'severity': severity,
      'reporter': reporter ?? 'Anonymous',
      'status': 'Pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Update overview statistics
    final overviewRef = _firestore.collection('moderation_overview').doc('current');
    batch.set(overviewRef, {
      'totalReports': FieldValue.increment(1),
      'pendingReview': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await batch.commit();
  }
} 