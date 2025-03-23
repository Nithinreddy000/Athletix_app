import 'package:flutter/material.dart';
import '../../../constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TrainingPlanner extends StatefulWidget {
  @override
  _TrainingPlannerState createState() => _TrainingPlannerState();
}

class _TrainingPlannerState extends State<TrainingPlanner> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> trainingPlans = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrainingPlans();
  }

  Future<void> _loadTrainingPlans() async {
    try {
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        final QuerySnapshot plansSnapshot = await _firestore
            .collection('training_plans')
            .where('coachId', isEqualTo: currentUser.uid)
            .orderBy('startDate', descending: true)
            .get();

        setState(() {
          trainingPlans = plansSnapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    ...doc.data() as Map<String, dynamic>,
                  })
              .toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading training plans: $e');
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
                "Training Planner",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              ElevatedButton.icon(
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    horizontal: defaultPadding * 1.5,
                    vertical: defaultPadding,
                  ),
                ),
                onPressed: () => _createTrainingPlan(),
                icon: Icon(Icons.add),
                label: Text("New Plan"),
              ),
            ],
          ),
          SizedBox(height: defaultPadding),
          isLoading
              ? Center(child: CircularProgressIndicator())
              : trainingPlans.isEmpty
                  ? Center(
                      child: Text(
                        "No training plans available",
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : Expanded(
                      child: ListView.builder(
                        itemCount: trainingPlans.length,
                        itemBuilder: (context, index) {
                          final plan = trainingPlans[index];
                          return Card(
                            color: secondaryColor,
                            child: ListTile(
                              leading: Icon(
                                Icons.fitness_center,
                                color: _getPlanStatusColor(plan['status']),
                              ),
                              title: Text(plan['title'] ?? 'Untitled Plan'),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Athletes: ${plan['assignedAthletes']?.length ?? 0}',
                                  ),
                                  Text(
                                    'Duration: ${plan['duration'] ?? 0} days',
                                  ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.more_vert),
                                onPressed: () => _showPlanOptions(plan),
                              ),
                              onTap: () => _viewPlanDetails(plan),
                            ),
                          );
                        },
                      ),
                    ),
        ],
      ),
    );
  }

  Color _getPlanStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'draft':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  void _createTrainingPlan() {
    // Implement training plan creation
  }

  void _showPlanOptions(Map<String, dynamic> plan) {
    // Implement plan options menu
  }

  void _viewPlanDetails(Map<String, dynamic> plan) {
    // Implement plan details view
  }
}
