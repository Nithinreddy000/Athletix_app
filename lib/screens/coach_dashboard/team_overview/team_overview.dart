import 'package:flutter/material.dart';
import '../../../constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../training_planner/training_planner_dialog.dart';
import '../performance_analysis/performance_analysis_screen.dart';

class TeamOverview extends StatefulWidget {
  @override
  _TeamOverviewState createState() => _TeamOverviewState();
}

class _TeamOverviewState extends State<TeamOverview> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> athletes = [];
  bool isLoading = true;
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAthletes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAthletes() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('Loading athletes for coach: ${currentUser.uid}');
        
        // Query users collection for athletes assigned to this coach
        final QuerySnapshot athletesSnapshot = await _firestore
            .collection('users')  // Changed from 'athletes' to 'users'
            .where('role', isEqualTo: 'athlete')
            .where('coachId', isEqualTo: currentUser.uid)
            .get();

        print('Found ${athletesSnapshot.docs.length} athletes');

        List<Map<String, dynamic>> athletesList = [];
        for (var doc in athletesSnapshot.docs) {
          final athleteData = doc.data() as Map<String, dynamic>;
          print('Processing athlete: ${athleteData['name']}');
          
          athletesList.add({
            'id': doc.id,
            'name': athleteData['name'] ?? 'Unknown',
            'email': athleteData['email'] ?? 'No email',
            'sportsType': athleteData['sportsType'] ?? 'Not specified',
            'latestMetrics': null,  // We'll add these features later
            'complianceRate': 0.0,
            'hasActiveInjury': false,
          });
        }

        setState(() {
          athletes = athletesList;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading athletes: $e');
      setState(() {
        isLoading = false;
        athletes = [];
      });
    }
  }

  void _showAthleteDetails(Map<String, dynamic> athlete) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(athlete['name']),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.person),
                title: Text('Personal Information'),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Email: ${athlete['email']}'),
                    Text('Sport: ${athlete['sportsType']}'),
                  ],
                ),
              ),
              Divider(),
              if (athlete['latestMetrics'] != null) ...[
                ListTile(
                  leading: Icon(Icons.trending_up),
                  title: Text('Latest Performance'),
                  subtitle: Text(
                    'Score: ${athlete['latestMetrics']['score']}\nDate: ${athlete['latestMetrics']['date']}',
                  ),
                ),
                Divider(),
              ],
              ListTile(
                leading: Icon(Icons.assignment_turned_in),
                title: Text('Training Compliance'),
                subtitle: Text(
                  '${(athlete['complianceRate'] * 100).toStringAsFixed(1)}%',
                ),
                trailing: _getComplianceIcon(athlete['complianceRate']),
              ),
              Divider(),
              ListTile(
                leading: Icon(Icons.healing),
                title: Text('Injury Status'),
                subtitle: Text(
                  athlete['hasActiveInjury'] ? 'Active Injury' : 'No Active Injuries',
                ),
                trailing: Icon(
                  athlete['hasActiveInjury'] ? Icons.warning : Icons.check_circle,
                  color: athlete['hasActiveInjury'] ? Colors.red : Colors.green,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _assignTraining(athlete);
            },
            child: Text('Assign Training'),
          ),
        ],
      ),
    );
  }

  void _assignTraining(Map<String, dynamic> athlete) {
    showDialog(
      context: context,
      builder: (context) => TrainingPlannerDialog(athleteId: athlete['id']),
    );
  }

  Widget _getComplianceIcon(double rate) {
    if (rate >= 0.9) {
      return Icon(Icons.star, color: Colors.amber);
    } else if (rate >= 0.7) {
      return Icon(Icons.thumb_up, color: Colors.green);
    } else if (rate >= 0.5) {
      return Icon(Icons.warning, color: Colors.orange);
    } else {
      return Icon(Icons.warning, color: Colors.red);
    }
  }

  List<Map<String, dynamic>> _getFilteredAthletes() {
    if (_searchQuery.isEmpty) return athletes;
    return athletes.where((athlete) =>
        athlete['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
        athlete['sportsType'].toString().toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredAthletes = _getFilteredAthletes();
    
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
                "",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Container(
                width: 300,
                height: 40,
                decoration: BoxDecoration(
                  color: secondaryColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white10),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Search athletes...",
                    hintStyle: TextStyle(color: Colors.white54),
                    prefixIcon: Icon(Icons.search, color: Colors.white54),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.transparent),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.blue.withOpacity(0.5)),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
            ],
          ),
          SizedBox(height: defaultPadding),
          if (isLoading)
            Center(child: CircularProgressIndicator())
          else if (filteredAthletes.isEmpty)
            Center(child: Text("No athletes found"))
          else
            Expanded(
              child: ListView.builder(
                itemCount: filteredAthletes.length,
                itemBuilder: (context, index) {
                  final athlete = filteredAthletes[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: defaultPadding),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(athlete['name'][0]),
                      ),
                      title: Text(athlete['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(athlete['sportsType']),
                          Text(athlete['email']),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (athlete['hasActiveInjury'])
                            Padding(
                              padding: EdgeInsets.only(right: 8),
                              child: Icon(Icons.healing, color: Colors.red),
                            ),
                          _getComplianceIcon(athlete['complianceRate']),
                          IconButton(
                            icon: Icon(Icons.visibility),
                            onPressed: () => _showAthleteDetails(athlete),
                          ),
                        ],
                      ),
                      onTap: () => _showAthleteDetails(athlete),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAthleteCard(BuildContext context, DocumentSnapshot athlete) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        athlete['name'] ?? 'N/A',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: defaultPadding / 2),
                      Text(
                        athlete['email'] ?? 'N/A',
                        style: TextStyle(color: Colors.white70),
                      ),
                      SizedBox(height: defaultPadding / 2),
                      Text(
                        'Sports Type: ${athlete['sportsType'] ?? 'N/A'}',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(
                      horizontal: defaultPadding,
                      vertical: defaultPadding / 2,
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PerformanceAnalysisScreen(
                          athleteId: athlete.id,
                          athleteName: athlete['name'] ?? 'Athlete',
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.analytics),
                  label: Text('Performance Analysis'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
