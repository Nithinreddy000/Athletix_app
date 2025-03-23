import 'package:cloud_firestore/cloud_firestore.dart';

class AthleteService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<Map<String, dynamic>>> getAthletes() async {
    try {
      // Query athletes with the index
      final QuerySnapshot athleteSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'athlete')
          .orderBy('name')
          .get();

      final List<Map<String, dynamic>> loadedAthletes = await Future.wait(
        athleteSnapshot.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;
          final athleteId = doc.id;

          // Get coach name
          String coachName = 'No Coach Assigned';
          if (data['coachId'] != null) {
            final coachDoc = await _firestore.collection('users').doc(data['coachId']).get();
            if (coachDoc.exists) {
              coachName = coachDoc.data()?['name'] ?? 'No Coach Assigned';
            }
          }

          // Get medical reports count
          final reportsCount = await _firestore
              .collection('medical_reports')
              .where('athlete_id', isEqualTo: athleteId)
              .count()
              .get();

          // Get most recent injury
          final recentReport = await _firestore
              .collection('medical_reports')
              .where('athlete_id', isEqualTo: athleteId)
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          Map<String, dynamic>? recentInjury;
          if (recentReport.docs.isNotEmpty) {
            final reportData = recentReport.docs.first.data();
            final injuries = reportData['injury_data'] as List?;
            if (injuries != null && injuries.isNotEmpty) {
              recentInjury = Map<String, dynamic>.from(injuries.first);
            }
          }

          return {
            'id': athleteId,
            'name': data['name'] ?? 'No Name',
            'email': data['email'] ?? 'No Email',
            'sport': data['sportsType'] ?? 'Not Specified',
            'team': data['team'] ?? 'Not Assigned',
            'jerseyNumber': data['jerseyNumber'] ?? 'N/A',
            'photoUrl': data['photoUrl'],
            'coachName': coachName,
            'recordCount': reportsCount.count,
            'recentInjury': recentInjury,
          };
        }),
      );

      return loadedAthletes;
    } catch (e) {
      print('Error getting athletes: $e');
      return [];
    }
  }
  
  // Add a method to get athletes under a specific coach
  Future<List<Map<String, dynamic>>> getAthletesByCoach(String coachId) async {
    try {
      print('Getting athletes for coach ID: $coachId');
      
      // Query athletes with the coachId field
      final QuerySnapshot athleteSnapshot1 = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'athlete')
          .where('coachId', isEqualTo: coachId)
          .get();
          
      // Also check for athletes that have this coach as their coach_id
      final QuerySnapshot athleteSnapshot2 = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'athlete')
          .where('coach_id', isEqualTo: coachId)
          .get();
      
      // Combine results from both queries, avoiding duplicates
      final Set<String> athleteIds = {};
      final List<DocumentSnapshot> allDocs = [];
      
      for (final doc in athleteSnapshot1.docs) {
        if (!athleteIds.contains(doc.id)) {
          athleteIds.add(doc.id);
          allDocs.add(doc);
        }
      }
      
      for (final doc in athleteSnapshot2.docs) {
        if (!athleteIds.contains(doc.id)) {
          athleteIds.add(doc.id);
          allDocs.add(doc);
        }
      }

      print('Found ${allDocs.length} athletes for coach ID: $coachId');
      
      final List<Map<String, dynamic>> loadedAthletes = await Future.wait(
        allDocs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;
          final athleteId = doc.id;

          // Get medical reports count
          final reportsCount = await _firestore
              .collection('medical_reports')
              .where('athlete_id', isEqualTo: athleteId)
              .count()
              .get();

          // Get most recent injury
          final recentReport = await _firestore
              .collection('medical_reports')
              .where('athlete_id', isEqualTo: athleteId)
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          Map<String, dynamic>? recentInjury;
          if (recentReport.docs.isNotEmpty) {
            final reportData = recentReport.docs.first.data();
            final injuries = reportData['injury_data'] as List?;
            if (injuries != null && injuries.isNotEmpty) {
              recentInjury = Map<String, dynamic>.from(injuries.first);
            }
          }

          return {
            'id': athleteId,
            'name': data['name'] ?? 'No Name',
            'email': data['email'] ?? 'No Email',
            'sport': data['sportsType'] ?? 'Not Specified',
            'team': data['team'] ?? 'Not Assigned',
            'jerseyNumber': data['jerseyNumber'] ?? 'N/A',
            'photoUrl': data['photoUrl'],
            'recordCount': reportsCount.count,
            'recentInjury': recentInjury,
          };
        }),
      );

      return loadedAthletes;
    } catch (e) {
      print('Error getting athletes by coach: $e');
      return [];
    }
  }
} 