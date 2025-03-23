import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../constants.dart';
import '../performance_analysis/video_player_with_controls.dart';

class PreviousSessionsScreen extends StatefulWidget {
  @override
  _PreviousSessionsScreenState createState() => _PreviousSessionsScreenState();
}

class _PreviousSessionsScreenState extends State<PreviousSessionsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Map<String, dynamic>> _sessions = [];
  bool _isLoading = true;
  String? _selectedAthleteId;
  Map<String, String> _athleteNames = {};

  @override
  void initState() {
    super.initState();
    _loadAthletes();
  }

  Future<void> _loadAthletes() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final athletesSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'athlete')
          .where('coachId', isEqualTo: currentUser.uid)
          .get();

      for (var doc in athletesSnapshot.docs) {
        _athleteNames[doc.id] = doc.data()['name'] ?? 'Unknown Athlete';
      }

      if (athletesSnapshot.docs.isNotEmpty) {
        _selectedAthleteId = athletesSnapshot.docs.first.id;
        await _loadSessions(_selectedAthleteId!);
      }

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading athletes: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSessions(String athleteId) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final sessionsSnapshot = await _firestore
          .collection('athletePerformanceAnalysis')
          .where('athleteId', isEqualTo: athleteId)
          .where('status', isEqualTo: 'completed')
          .orderBy('timestamp', descending: true)
          .get();

      _sessions = sessionsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'timestamp': data['timestamp'],
          'videoUrl': data['videoUrl'],
          'metrics': data['metrics'] ?? {},
          'poseData': data['poseData'] ?? [],
          'sessionType': data['sessionType'] ?? 'Training',
        };
      }).toList();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading sessions: $e');
      setState(() {
        _isLoading = false;
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
                "Previous Sessions",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_athleteNames.isNotEmpty)
                DropdownButton<String>(
                  value: _selectedAthleteId,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedAthleteId = newValue;
                      });
                      _loadSessions(newValue);
                    }
                  },
                  items: _athleteNames.entries
                      .map((e) => DropdownMenuItem(
                            value: e.key,
                            child: Text(
                              e.value,
                              style: TextStyle(color: Colors.white70),
                            ),
                          ))
                      .toList(),
                  dropdownColor: secondaryColor,
                ),
            ],
          ),
          SizedBox(height: defaultPadding),
          if (_isLoading)
            Center(child: CircularProgressIndicator())
          else if (_sessions.isEmpty)
            Center(
              child: Text(
                'No previous sessions found',
                style: TextStyle(color: Colors.white70),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _sessions.length,
                itemBuilder: (context, index) {
                  final session = _sessions[index];
                  final timestamp = session['timestamp'] as Timestamp;
                  final metrics = session['metrics'] as Map<String, dynamic>;
                  
                  return Card(
                    color: bgColor,
                    margin: EdgeInsets.only(bottom: defaultPadding),
                    child: ExpansionTile(
                      title: Text(
                        '${session['sessionType']} - ${_formatDate(timestamp)}',
                        style: TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        'Form Score: ${((metrics['form_score'] ?? 0.0) * 100).toStringAsFixed(1)}%',
                        style: TextStyle(color: Colors.white70),
                      ),
                      children: [
                        if (session['videoUrl'] != null)
                          Container(
                            height: 400,
                            padding: EdgeInsets.all(defaultPadding),
                            child: Column(
                              children: [
                                Expanded(
                                  child: VideoPlayerWithControls(
                                    videoUrl: session['videoUrl'],
                                    poseData: List<Map<String, dynamic>>.from(session['poseData'] ?? []),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: Text(
                                    'Video URL: ${session['videoUrl']}',
                                    style: TextStyle(color: Colors.white70, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Padding(
                            padding: EdgeInsets.all(defaultPadding),
                            child: Center(
                              child: Text(
                                'No video available for this session',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.all(defaultPadding),
                          child: Column(
                            children: [
                              _buildMetricsGrid(metrics),
                              SizedBox(height: defaultPadding),
                              _buildSessionDetails(session),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(Map<String, dynamic> metrics) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 4,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard('Form Score', metrics['form_score'] ?? 0.0, Colors.blue),
        _buildMetricCard('Balance', metrics['balance'] ?? 0.0, Colors.green),
        _buildMetricCard('Symmetry', metrics['symmetry'] ?? 0.0, Colors.orange),
        _buildMetricCard('Smoothness', metrics['smoothness'] ?? 0.0, Colors.purple),
      ],
    );
  }

  Widget _buildMetricCard(String label, double value, Color color) {
    return Card(
      color: color.withOpacity(0.1),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(color: color, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              '${(value * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionDetails(Map<String, dynamic> session) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Session Details',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.calendar_today, size: 16, color: Colors.white70),
            SizedBox(width: 8),
            Text(
              'Date: ${_formatDate(session['timestamp'])}',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.sports, size: 16, color: Colors.white70),
            SizedBox(width: 8),
            Text(
              'Type: ${session['sessionType']}',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
} 