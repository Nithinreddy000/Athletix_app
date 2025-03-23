import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Record an audit log entry
  Future<void> recordAuditLog({
    required String userId,
    required String action,
    required String module,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    await _firestore.collection('audit_logs').add({
      'userId': userId,
      'action': action,
      'module': module,
      'description': description,
      'metadata': metadata,
      'timestamp': FieldValue.serverTimestamp(),
      'ipAddress': '', // To be filled by server-side function
      'userAgent': '', // To be filled by server-side function
    });
  }

  // Get audit logs with pagination and filters
  Stream<QuerySnapshot> getAuditLogs({
    String? userId,
    String? module,
    String? action,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    DocumentSnapshot? lastDocument,
  }) {
    Query query = _firestore.collection('audit_logs')
        .orderBy('timestamp', descending: true);

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }
    if (module != null) {
      query = query.where('module', isEqualTo: module);
    }
    if (action != null) {
      query = query.where('action', isEqualTo: action);
    }
    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: endDate);
    }

    if (lastDocument != null) {
      query = query.startAfterDocument(lastDocument);
    }

    return query.limit(limit).snapshots();
  }

  // Get audit log statistics
  Future<Map<String, dynamic>> getAuditLogStatistics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final snapshot = await _firestore
        .collection('audit_logs')
        .where('timestamp', isGreaterThanOrEqualTo: startDate)
        .where('timestamp', isLessThanOrEqualTo: endDate)
        .get();

    Map<String, int> actionCounts = {};
    Map<String, int> moduleCounts = {};
    Map<String, int> userCounts = {};

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      
      final action = data['action'] as String;
      actionCounts[action] = (actionCounts[action] ?? 0) + 1;

      final module = data['module'] as String;
      moduleCounts[module] = (moduleCounts[module] ?? 0) + 1;

      final userId = data['userId'] as String;
      userCounts[userId] = (userCounts[userId] ?? 0) + 1;
    }

    return {
      'totalLogs': snapshot.docs.length,
      'actionBreakdown': actionCounts,
      'moduleBreakdown': moduleCounts,
      'userBreakdown': userCounts,
    };
  }

  // Export audit logs
  Future<List<Map<String, dynamic>>> exportAuditLogs({
    DateTime? startDate,
    DateTime? endDate,
    String? userId,
    String? module,
    String? action,
  }) async {
    Query query = _firestore.collection('audit_logs')
        .orderBy('timestamp', descending: true);

    if (userId != null) {
      query = query.where('userId', isEqualTo: userId);
    }
    if (module != null) {
      query = query.where('module', isEqualTo: module);
    }
    if (action != null) {
      query = query.where('action', isEqualTo: action);
    }
    if (startDate != null) {
      query = query.where('timestamp', isGreaterThanOrEqualTo: startDate);
    }
    if (endDate != null) {
      query = query.where('timestamp', isLessThanOrEqualTo: endDate);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
  }
} 