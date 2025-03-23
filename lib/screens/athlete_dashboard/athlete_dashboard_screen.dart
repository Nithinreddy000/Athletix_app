import 'package:flutter/material.dart';
import '../../constants.dart';
import 'performance_insights/performance_insights.dart';
import 'injury_records/injury_records_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../shared/announcements_screen.dart';

class AthleteDashboardScreen extends StatefulWidget {
  const AthleteDashboardScreen({Key? key}) : super(key: key);

  @override
  _AthleteDashboardScreenState createState() => _AthleteDashboardScreenState();
}

class _AthleteDashboardScreenState extends State<AthleteDashboardScreen> {
  Map<String, dynamic>? _athleteData;
  bool _isLoading = true;
  
  // Add the darkColor variable
  final Color darkColor = Color(0xFF1E1E2D);

  @override
  void initState() {
    super.initState();
    _loadAthleteData();
  }

  Future<void> _loadAthleteData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        
        if (userDoc.exists) {
          setState(() {
            _athleteData = userDoc.data();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading athlete data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Athlete Dashboard'),
        backgroundColor: darkColor,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAthleteProfile(),
                  SizedBox(height: defaultPadding * 2),
                  Text(
                    'Dashboard',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: defaultPadding),
                  GridView.count(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: defaultPadding,
                    mainAxisSpacing: defaultPadding,
                    children: [
                      _buildDashboardCard(
                        title: 'Performance Insights',
                        icon: Icons.insights,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PerformanceInsights(),
                            ),
                          );
                        },
                      ),
                      _buildDashboardCard(
                        title: 'Injury Records',
                        icon: Icons.healing,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => InjuryRecordsScreen(),
                            ),
                          );
                        },
                      ),
                      _buildDashboardCard(
                        title: 'Announcements',
                        icon: Icons.announcement,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SharedAnnouncementsScreen(userRole: 'Athlete'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: defaultPadding * 2),
                  Text(
                    'Recent Announcements',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: defaultPadding),
                  Container(
                    height: 300,
                    child: SharedAnnouncementsScreen(userRole: 'Athlete'),
                  ),
                ],
              ),
            ),
    );
  }
  
  Widget _buildDashboardCard({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: secondaryColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: EdgeInsets.all(defaultPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Colors.blue,
              ),
              SizedBox(height: defaultPadding),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildAthleteProfile() {
    if (_athleteData == null) {
      return SizedBox(height: 100);
    }
    
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Colors.blueGrey,
            backgroundImage: _athleteData!['photoUrl'] != null
                ? NetworkImage(_athleteData!['photoUrl'])
                : null,
            child: _athleteData!['photoUrl'] == null
                ? Icon(Icons.person, size: 40, color: Colors.white)
                : null,
          ),
          SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _athleteData!['name'] ?? 'Athlete',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                _athleteData!['email'] ?? '',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              if (_athleteData!['sportsType'] != null) ...[
                SizedBox(height: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _athleteData!['sportsType'],
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
} 