import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../constants.dart';
import '../../responsive.dart';
import '../../services/medical_report_service.dart';
import '../../services/athlete_service.dart';
import '../../services/ai_service.dart'; // We'll create this service for Gemini integration
import 'injury_records/injury_records_screen.dart'; // Corrected import path
import '../shared/announcements_screen.dart';

class MedicalDashboardScreen extends StatefulWidget {
  const MedicalDashboardScreen({Key? key}) : super(key: key);

  @override
  State<MedicalDashboardScreen> createState() => _MedicalDashboardScreenState();
}

class _MedicalDashboardScreenState extends State<MedicalDashboardScreen> {
  final MedicalReportService _medicalReportService = MedicalReportService();
  final AthleteService _athleteService = AthleteService();
  
  @override
  void initState() {
    super.initState();
    _debugFirestoreConnection();
  }

  Future<void> _debugFirestoreConnection() async {
    try {
      print('Debugging Firestore connection...');
      
      // Check if medical_reports collection exists and has documents
      final medicalReportsSnapshot = await FirebaseFirestore.instance
          .collection('medical_reports')
          .get();
      
      print('Medical reports collection exists: ${medicalReportsSnapshot.docs.isNotEmpty}');
      print('Number of medical reports: ${medicalReportsSnapshot.docs.length}');
      
      if (medicalReportsSnapshot.docs.isNotEmpty) {
        print('Sample medical report data: ${medicalReportsSnapshot.docs.first.data()}');
      } else {
        // Try to create a test document to verify write permissions
        await _createTestMedicalReport();
      }
      
      // Check if users collection exists and has athletes
      final athletesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'athlete')
          .get();
      
      print('Athletes found: ${athletesSnapshot.docs.length}');
    } catch (e) {
      print('Error debugging Firestore: $e');
    }
  }
  
  Future<void> _createTestMedicalReport() async {
    try {
      print('Attempting to create a test medical report...');
      
      // Create a test document
      final docRef = await FirebaseFirestore.instance.collection('medical_reports').add({
        'title': 'Test Medical Report',
        'athlete_id': 'test_athlete',
        'athlete_name': 'Test Athlete',
        'diagnosis': 'Test Diagnosis',
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'injury_data': [
          {
            'bodyPart': 'knee',
            'severity': 'moderate',
            'description': 'Test injury description',
            'status': 'active',
            'recoveryProgress': 25
          }
        ]
      });
      
      print('Test document created with ID: ${docRef.id}');
      
      // Create a test athlete if none exists
      final athletesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'athlete')
          .get();
          
      if (athletesSnapshot.docs.isEmpty) {
        final athleteRef = await FirebaseFirestore.instance.collection('users').add({
          'name': 'Test Athlete',
          'email': 'test@example.com',
          'role': 'athlete',
          'sportsType': 'Football',
          'team': 'Test Team',
          'jerseyNumber': '99'
        });
        
        print('Test athlete created with ID: ${athleteRef.id}');
      }
    } catch (e) {
      print('Error creating test documents: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        primary: false,
        padding: const EdgeInsets.all(defaultPadding),
        child: Column(
          children: [
            const SizedBox(height: defaultPadding),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    children: [
                      // Medical Overview Section
                      _buildMedicalOverview(),
                      const SizedBox(height: defaultPadding),
                      // Recent Medical Records (limited to 2)
                      _buildRecentMedicalRecords(),
                      const SizedBox(height: defaultPadding),
                      // Injury Reports Section
                      _buildInjuryReports(),
                      const SizedBox(height: defaultPadding),
                      // Announcements Section
                      _buildAnnouncementsSection(),
                    ],
                  ),
                ),
                if (!Responsive.isMobile(context))
                  const SizedBox(width: defaultPadding),
                // Right Side Panel
                if (!Responsive.isMobile(context))
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        // Injury Statistics
                        _buildInjuryStatistics(),
                        const SizedBox(height: defaultPadding),
                        // Active Athletes
                        _buildActiveAthletes(),
                      ],
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalOverview() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('medical_reports')
          .snapshots(),
      builder: (context, reportsSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'athlete')
              .snapshots(),
          builder: (context, athletesSnapshot) {
            // Initialize counts
            int activeInjuryCount = 0;
            int totalInjuryCount = 0;
            int injuredAthleteCount = 0;
            
            // Use sets to track unique injuries
            Set<String> uniqueInjuries = {};
            Set<String> uniqueActiveInjuries = {};
            Set<String> athletesWithInjuries = {};
            
            if (reportsSnapshot.hasData && athletesSnapshot.hasData) {
              // Process each medical report
              for (var doc in reportsSnapshot.data!.docs) {
                final data = doc.data() as Map<String, dynamic>;
                
                // Extract athlete ID
                String? athleteId;
                if (data['athlete_id'] != null) {
                  athleteId = data['athlete_id'] as String;
                } else if (data['analysis_result'] != null && 
                        (data['analysis_result'] as Map<String, dynamic>).containsKey('athlete_id')) {
                  athleteId = (data['analysis_result'] as Map<String, dynamic>)['athlete_id'] as String;
                }
                
                // Get injury data from the document
                List? injuryData;
                if (data['injury_data'] != null) {
                  injuryData = data['injury_data'] as List?;
                } else if (data['analysis_result'] != null && 
                        (data['analysis_result'] as Map<String, dynamic>).containsKey('injury_data')) {
                  injuryData = (data['analysis_result'] as Map<String, dynamic>)['injury_data'] as List?;
                }
                
                // Process injuries if available
                if (injuryData != null && injuryData.isNotEmpty && athleteId != null) {
                  bool hasAnyInjury = false;
                  
                  // Count total and active injuries
                  for (var injury in injuryData) {
                    if (injury is Map<String, dynamic>) {
                      final bodyPart = injury['bodyPart'] ?? 'Unknown';
                      final side = injury['side'] ?? '';
                      final severity = injury['severity'] ?? '';
                      
                      // Create a unique key for each injury
                      final injuryKey = '$athleteId-$bodyPart-$side-$severity';
                      
                      // Only count if not already counted
                      if (!uniqueInjuries.contains(injuryKey)) {
                        uniqueInjuries.add(injuryKey);
                        hasAnyInjury = true;
                        
                        if (injury['status'] == 'active') {
                          uniqueActiveInjuries.add(injuryKey);
                        }
                      }
                    }
                  }
                  
                  // Add athlete to the set if they have any injuries
                  if (hasAnyInjury) {
                    athletesWithInjuries.add(athleteId);
                  }
                }
              }
              
              // Set the counts based on unique sets
              totalInjuryCount = uniqueInjuries.length;
              activeInjuryCount = uniqueActiveInjuries.length;
              injuredAthleteCount = athletesWithInjuries.length;

              // Debug logs
              print('Medical Overview Counts:');
              print('Active Injuries: $activeInjuryCount');
              print('Total Injuries: $totalInjuryCount');
              print('Athletes with Injuries: $injuredAthleteCount');
            }
            
            return Container(
              padding: const EdgeInsets.all(defaultPadding),
              decoration: BoxDecoration(
                color: secondaryColor,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Medical Overview",
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: defaultPadding),
                  if (reportsSnapshot.connectionState == ConnectionState.waiting ||
                      athletesSnapshot.connectionState == ConnectionState.waiting)
                    _buildLoadingOverviewCards()
                  else if (totalInjuryCount == 0 && injuredAthleteCount == 0)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: Text(
                          "No injury data available yet",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    )
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildOverviewCard(
                          Icons.healing,
                          "Active Injuries",
                          activeInjuryCount.toString(),
                        ),
                        _buildOverviewCard(
                          Icons.medical_services,
                          "Total Injuries",
                          totalInjuryCount.toString(),
                        ),
                        _buildOverviewCard(
                          Icons.people,
                          "Athletes with Injuries",
                          injuredAthleteCount.toString(),
                        ),
                      ],
                    ),
                ],
              ),
            ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0);
          },
        );
      },
    );
  }

  Widget _buildLoadingOverviewCards() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(3, (index) {
        return Expanded(
          child: Shimmer.fromColors(
          baseColor: Colors.grey[800]!,
          highlightColor: Colors.grey[700]!,
          child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 5),
              height: 100,
            padding: const EdgeInsets.all(defaultPadding),
            decoration: BoxDecoration(
                color: secondaryColor.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primaryColor.withOpacity(0.3)),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildOverviewCard(IconData icon, String title, String count) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 5),
        padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
          color: secondaryColor.withOpacity(0.7),
        borderRadius: BorderRadius.circular(10),
          border: Border.all(color: primaryColor.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                Icon(icon, color: primaryColor, size: 24),
              Text(
                  count,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
              ),
            ],
          ),
            const SizedBox(height: 10),
          Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
          ),
        ],
      ),
      ),
    ).animate().fadeIn(duration: 300.ms).scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }

  Widget _buildRecentMedicalRecords() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('medical_reports')
          .limit(2) // Limit to 2 recent records as requested
          .snapshots(),
      builder: (context, snapshot) {
        // Debug log
        if (snapshot.hasData) {
          print('Recent medical records count: ${snapshot.data!.docs.length}');
          if (snapshot.data!.docs.isNotEmpty) {
            print('First record data: ${snapshot.data!.docs.first.data()}');
          }
        } else if (snapshot.hasError) {
          print('Error in recent medical records: ${snapshot.error}');
        }
        
        // Check if we have data to display
        bool hasDataToDisplay = snapshot.hasData && snapshot.data!.docs.isNotEmpty;
        
        return Container(
          padding: const EdgeInsets.all(defaultPadding),
          decoration: BoxDecoration(
            color: secondaryColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Recent Medical Records",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                  ),
                ],
              ),
              const SizedBox(height: defaultPadding),
              if (snapshot.connectionState == ConnectionState.waiting)
                _buildLoadingRecords()
              else if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                const Center(
                  child: Text(
                    "No medical records found",
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  separatorBuilder: (context, index) => const Divider(color: Colors.white24),
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    
                    print('Processing record ${index + 1}: ${doc.id}');

                    // Extract athlete name and ID
                    String athleteId = '';
                    String athleteName = 'Unknown';
                    
                    if (data['athlete_id'] != null) {
                      athleteId = data['athlete_id'] as String;
                    } else if (data['analysis_result'] != null && 
                              (data['analysis_result'] as Map<String, dynamic>).containsKey('athlete_id')) {
                      athleteId = (data['analysis_result'] as Map<String, dynamic>)['athlete_id'] as String;
                    }
                    
                    if (data['athlete_name'] != null) {
                      athleteName = data['athlete_name'] as String;
                    } else if (data['analysis_result'] != null && 
                              (data['analysis_result'] as Map<String, dynamic>).containsKey('athlete_name')) {
                      athleteName = (data['analysis_result'] as Map<String, dynamic>)['athlete_name'] as String;
                    }
                    
                    // Handle both timestamp formats
                    Timestamp? timestamp = data['timestamp'] as Timestamp?;
                    if (timestamp == null && data['audit_trail'] != null) {
                      timestamp = (data['audit_trail'] as Map<String, dynamic>)['created_at'] as Timestamp?;
                    }
                    
                    final date = timestamp != null 
                        ? DateFormat('MMM dd, yyyy').format(timestamp.toDate())
                        : 'Unknown date';
                    
                    // Find a title for the record
                    String title = 'Medical Report';
                    if (data['title'] != null) {
                      title = data['title'] as String;
                    } else if (data['file_name'] != null) {
                      title = data['file_name'] as String;
                    }
                    
                    print('Record details: $title, $athleteName, $date');
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: primaryColor.withOpacity(0.2),
                        child: const Icon(Icons.description, color: primaryColor),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        'Athlete: $athleteName • $date',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        color: Colors.white54,
                        size: 16,
                      ),
                      onTap: () {
                        // Navigate to injury record details
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => InjuryRecordsScreen(
                              initialAthleteId: athleteId,
                            ),
                          ),
                        );
                      },
                    ).animate().fadeIn(duration: 300.ms, delay: (100 * index).ms);
                  },
                ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 300.ms).slideY(begin: 0.2, end: 0);
      },
    );
  }

  Widget _buildLoadingRecords() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 2, // Only show 2 loading placeholders
        itemBuilder: (context, index) {
          return ListTile(
            leading: const CircleAvatar(),
            title: Container(
              width: double.infinity,
              height: 16,
              color: Colors.white,
            ),
            subtitle: Container(
              width: double.infinity,
              height: 12,
              margin: const EdgeInsets.only(top: 4),
              color: Colors.white,
            ),
          );
        },
      ),
    );
  }

  // Add this method to automatically analyze injuries
  Future<Map<String, dynamic>> _autoAnalyzeInjury(Map<String, dynamic> injury, String reportId) async {
    final AIService aiService = AIService();
    
    try {
      // Extract injury details
      final bodyPart = injury['bodyPart'] ?? 'Unknown';
      final side = injury['side'] ?? '';
      final severity = injury['severity'] ?? 'moderate';
      final description = injury['description'] ?? 'No description available';
      
      print('Auto-analyzing injury: $bodyPart ${side.isNotEmpty ? "($side)" : ""} - $severity');
      print('Initial recovery progress: ${injury['recoveryProgress']}');
      
      // Only analyze if recovery progress is missing or zero
      if (injury['recoveryProgress'] == null || injury['recoveryProgress'] == 0) {
        // Call the AI service to analyze the injury
        final result = await aiService.analyzeInjury(
          reportId: reportId,
          description: description,
          bodyPart: bodyPart,
          severity: severity,
          side: side,
        );
        
        print('Analysis result recovery progress: ${result['recovery_progress']}');
        
        // Create a new injury map with updated values
        final updatedInjury = {
          ...injury,
          'recoveryProgress': result['recovery_progress'],
          'estimatedRecoveryTime': result['estimated_recovery_time'],
          'recommendedTreatment': result['recommended_treatment'],
          'lastUpdated': DateTime.now().toIso8601String(),
        };
        
        // Immediately update Firestore
        try {
          // Get the current injury data array
          final docRef = FirebaseFirestore.instance.collection('medical_reports').doc(reportId);
          final docData = await docRef.get();
          
          if (docData.exists && docData.data()?['injury_data'] != null) {
            final List currentInjuryData = docData.data()?['injury_data'] as List;
            
            // Find and update the matching injury
            bool foundMatch = false;
            for (int i = 0; i < currentInjuryData.length; i++) {
              final currentInjury = currentInjuryData[i] as Map<String, dynamic>;
              if (currentInjury['bodyPart'] == bodyPart && 
                  (side == null || currentInjury['side'] == side)) {
                
                // Update the injury in the array
                currentInjuryData[i] = updatedInjury;
                foundMatch = true;
                print('Updated injury at index $i with recovery progress: ${updatedInjury['recoveryProgress']}%');
                break;
              }
            }
            
            if (foundMatch) {
              // Update the document with new injury data
              await docRef.update({'injury_data': currentInjuryData});
              print('Updated Firestore document with new injury data');
              
              // Force UI refresh
              if (mounted) {
                setState(() {
                  // Trigger UI refresh
                  print('Triggered UI refresh after Firestore update');
                });
              }
            } else {
              print('Could not find matching injury in the array to update');
            }
          }
        } catch (e) {
          print('Error updating injury data in Firestore: $e');
        }
        
        return updatedInjury;
      }
    } catch (e) {
      print('Error auto-analyzing injury: $e');
    }
    
    // Return the original injury if analysis failed or wasn't needed
    return injury;
  }

  Widget _buildInjuryReports() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('medical_reports')
          .snapshots(),
      builder: (context, snapshot) {
        return Container(
          padding: const EdgeInsets.all(defaultPadding),
          decoration: BoxDecoration(
            color: secondaryColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Injury Reports",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: defaultPadding),
              if (snapshot.connectionState == ConnectionState.waiting)
                _buildLoadingRecords()
              else if (!snapshot.hasData || snapshot.data!.docs.isEmpty)
                const Center(
                  child: Text(
                    "No active injury reports found",
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final String reportId = doc.id;
                    final data = doc.data() as Map<String, dynamic>;
                    
                    // Check both direct injury_data and nested injury_data in analysis_result
                    List? injuryData;
                    
                    if (data['injury_data'] != null) {
                      injuryData = data['injury_data'] as List?;
                    } else if (data['analysis_result'] != null && 
                              (data['analysis_result'] as Map<String, dynamic>).containsKey('injury_data')) {
                      injuryData = (data['analysis_result'] as Map<String, dynamic>)['injury_data'] as List?;
                    }
                    
                    if (injuryData == null || injuryData.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    
                    // Get active injuries and deduplicate them
                    final List<Map<String, dynamic>> activeInjuries = [];
                    final Set<String> injuryKeys = {};
                    
                    for (var injury in injuryData) {
                      if (injury is Map<String, dynamic> && injury['status'] == 'active') {
                        final bodyPart = injury['bodyPart'] ?? 'Unknown';
                        final side = injury['side'] ?? '';
                        final severity = injury['severity'] ?? '';
                        
                        // Create a unique key for each injury
                        final injuryKey = '$bodyPart-$side-$severity';
                        
                        // Only add if we haven't seen this injury before
                        if (!injuryKeys.contains(injuryKey)) {
                          injuryKeys.add(injuryKey);
                          activeInjuries.add(injury);
                          
                          // Auto-analyze the injury for recovery progress if needed
                          // This needs to happen after the UI is built, so we use Future.microtask
                          if (injury['recoveryProgress'] == null || injury['recoveryProgress'] == 0) {
                            Future.microtask(() async {
                              print('Starting analysis for $bodyPart ($side) injury with recovery progress: ${injury['recoveryProgress']}');
                              final analysisResult = await _autoAnalyzeInjury(injury, reportId);
                              
                              print('Analysis completed with recovery progress: ${analysisResult['recoveryProgress']}');
                              
                              // Update the injury data in Firestore with the analysis results
                              if (analysisResult['recoveryProgress'] != null && 
                                  analysisResult['recoveryProgress'] != injury['recoveryProgress']) {
                                try {
                                  // Get the current injury data array
                                  final docRef = FirebaseFirestore.instance.collection('medical_reports').doc(reportId);
                                  final docData = await docRef.get();
                                  
                                  if (docData.exists && docData.data()?['injury_data'] != null) {
                                    final List currentInjuryData = docData.data()?['injury_data'] as List;
                                    bool updated = false;
                                    
                                    // Find and update the matching injury
                                    for (int i = 0; i < currentInjuryData.length; i++) {
                                      final currentInjury = currentInjuryData[i] as Map<String, dynamic>;
                                      if (currentInjury['bodyPart'] == bodyPart && 
                                          currentInjury['side'] == side && 
                                          currentInjury['severity'] == severity) {
                                        
                                        currentInjuryData[i] = analysisResult;
                                        updated = true;
                                        print('Updated injury in Firestore at index $i with recovery progress: ${analysisResult['recoveryProgress']}%');
                                        break;
                                      }
                                    }
                                    
                                    if (updated) {
                                      // Update the document with new injury data
                                      await docRef.update({'injury_data': currentInjuryData});
                                      print('Firestore document updated successfully');
                                      
                                      // Force a UI refresh
                                      if (mounted) {
                                        setState(() {
                                          // This will trigger a complete UI refresh
                                          print('Forcing UI refresh after Firestore update');
                                        });
                                      }
                                    } else {
                                      print('Could not find matching injury to update in Firestore');
                                    }
                                  }
                                } catch (e) {
                                  print('Error updating injury data: $e');
                                }
                              }
                            });
                          }
                        }
                      }
                    }
                    
                    if (activeInjuries.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    
                    return Column(
                      children: activeInjuries.map<Widget>((injury) {
                        final Map<String, dynamic> injuryMap = injury as Map<String, dynamic>;
                        final bodyPart = injuryMap['bodyPart'] ?? 'Unknown';
                        final side = injuryMap['side'] ?? '';
                        final description = injuryMap['description'] ?? 'No description';
                        final recoveryProgress = injuryMap['recoveryProgress'] ?? 0;
                        final colorCode = injuryMap['colorCode'] ?? '#FF8888';
                        
                        final Color injuryColor = _getColorFromHex(colorCode);
                    
                    return Card(
                      color: secondaryColor.withOpacity(0.7),
                      margin: const EdgeInsets.only(bottom: defaultPadding),
                      child: Padding(
                        padding: const EdgeInsets.all(defaultPadding),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                      backgroundColor: injuryColor.withOpacity(0.2),
                                  child: Icon(
                                    Icons.healing,
                                        color: injuryColor,
                                  ),
                                ),
                                const SizedBox(width: defaultPadding),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['athlete_name'] ?? 'Unknown Athlete',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Text(
                                            '$bodyPart ${side.isNotEmpty ? "($side)" : ""} Injury',
                                        style: const TextStyle(color: Colors.white70),
                                      ),
                                    ],
                                  ),
                                ),
                                    // Status badge without "ANALYZED" tag
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                        color: injuryColor,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                      child: const Text(
                                        "ACTIVE",
                                        style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                                const SizedBox(height: defaultPadding),
                                Text(
                                  description,
                                  style: const TextStyle(color: Colors.white, fontSize: 13),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: defaultPadding),
                            Text(
                              'Recovery Progress',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            const SizedBox(height: defaultPadding / 2),
                                Container(
                                  width: double.infinity, // This constrains the width
                                  child: LinearProgressIndicator(
                              value: recoveryProgress / 100,
                              backgroundColor: Colors.grey.withOpacity(0.2),
                                    valueColor: AlwaysStoppedAnimation<Color>(injuryColor),
                                  ),
                            ),
                            const SizedBox(height: defaultPadding / 2),
                            Text(
                              '$recoveryProgress%',
                              style: TextStyle(
                                    color: injuryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            
                            // Show estimated recovery time if available
                            if (injuryMap['estimatedRecoveryTime'] != null) ...[
                              const SizedBox(height: defaultPadding / 2),
                              Row(
                                children: [
                                  Icon(Icons.timer_outlined, size: 14, color: Colors.white70),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      'Est. Recovery: ${injuryMap['estimatedRecoveryTime']}',
                                      style: TextStyle(color: Colors.white70, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ).animate().fadeIn(duration: 300.ms, delay: (100 * index).ms).slideX(begin: 0.1, end: 0);
                      }).toList(),
                    );
                  },
                ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 400.ms).slideY(begin: 0.2, end: 0);
      },
    );
  }

  // New widget to replace Upcoming Appointments
  Widget _buildInjuryStatistics() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('medical_reports')
          .snapshots(),
      builder: (context, snapshot) {
        Map<String, int> injuryTypes = {};
        // Track unique injuries to avoid duplicates
        Set<String> uniqueInjuryKeys = {};
        
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            
            // Extract athlete ID
            String? athleteId;
            if (data['athlete_id'] != null) {
              athleteId = data['athlete_id'] as String;
            } else if (data['analysis_result'] != null && 
                    (data['analysis_result'] as Map<String, dynamic>).containsKey('athlete_id')) {
              athleteId = (data['analysis_result'] as Map<String, dynamic>)['athlete_id'] as String;
            }
            
            // Check both direct injury_data and nested injury_data in analysis_result
            List? injuryData;
            
            if (data['injury_data'] != null) {
              injuryData = data['injury_data'] as List?;
            } else if (data['analysis_result'] != null && 
                      (data['analysis_result'] as Map<String, dynamic>).containsKey('injury_data')) {
              injuryData = (data['analysis_result'] as Map<String, dynamic>)['injury_data'] as List?;
            }
            
            if (injuryData != null && injuryData.isNotEmpty && athleteId != null) {
              for (var injury in injuryData) {
                if (injury is Map<String, dynamic>) {
                  final bodyPart = injury['bodyPart'] ?? 'Unknown';
                  final side = injury['side'] ?? '';
                  final severity = injury['severity'] ?? '';
                  
                  // Create a unique key for each injury
                  final injuryKey = '$athleteId-$bodyPart-$side-$severity';
                  
                  // Only count if we haven't seen this injury before
                  if (!uniqueInjuryKeys.contains(injuryKey)) {
                    uniqueInjuryKeys.add(injuryKey);
                    
                    // For injury statistics, group by body part
                    final displayType = side.isNotEmpty ? '$bodyPart $side' : bodyPart;
                    injuryTypes[displayType] = (injuryTypes[displayType] ?? 0) + 1;
                  }
                }
              }
            }
          }
        }
        
        return Container(
          padding: const EdgeInsets.all(defaultPadding),
          decoration: BoxDecoration(
            color: secondaryColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Injury Statistics",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: defaultPadding),
              if (snapshot.connectionState == ConnectionState.waiting)
                _buildLoadingStatistics()
              else if (injuryTypes.isEmpty)
                const Center(
                  child: Text(
                    "No injury data available",
                    style: TextStyle(color: Colors.white70),
                  ),
                )
              else
                Column(
                  children: injuryTypes.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: defaultPadding / 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              entry.key,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              entry.value.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ),
                          ],
                        ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms, delay: 500.ms).slideY(begin: 0.2, end: 0);
      },
    );
  }

  Widget _buildLoadingStatistics() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 4,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: defaultPadding / 2),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 16,
                    color: Colors.white,
                  ),
                ),
                Container(
                  width: 40,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // New widget to replace Quick Actions
  Widget _buildActiveAthletes() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('medical_reports')
          .snapshots(),
      builder: (context, reportsSnapshot) {
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .where('role', isEqualTo: 'athlete')
              .snapshots(),
          builder: (context, athletesSnapshot) {
            List<Map<String, dynamic>> activeAthletes = [];
            
            if (reportsSnapshot.hasData && athletesSnapshot.hasData) {
              for (var athleteDoc in athletesSnapshot.data!.docs) {
                final athleteData = athleteDoc.data() as Map<String, dynamic>;
                final athleteId = athleteDoc.id;
                
                bool hasActiveInjury = false;
                String? latestInjuryDate;
                
                for (var reportDoc in reportsSnapshot.data!.docs) {
                  final reportData = reportDoc.data() as Map<String, dynamic>;
                  
                  if (reportData['athlete_id'] == athleteId) {
                    // Check both direct injury_data and nested injury_data in analysis_result
                    List? injuryData;
                    
                    if (reportData['injury_data'] != null) {
                      injuryData = reportData['injury_data'] as List?;
                    } else if (reportData['analysis_result'] != null && 
                              (reportData['analysis_result'] as Map<String, dynamic>).containsKey('injury_data')) {
                      injuryData = (reportData['analysis_result'] as Map<String, dynamic>)['injury_data'] as List?;
                    }
                    
                    // Track unique injuries
                    Set<String> uniqueActiveInjuries = {};
                    
                    if (injuryData != null && injuryData.isNotEmpty) {
                      for (var injury in injuryData) {
                        if (injury is Map<String, dynamic> && 
                            injury['status'] == 'active') {
                          
                          final bodyPart = injury['bodyPart'] ?? 'Unknown';
                          final side = injury['side'] ?? '';
                          final severity = injury['severity'] ?? '';
                          
                          // Create a unique key for this injury
                          final injuryKey = '$bodyPart-$side-$severity';
                          
                          // Only process if we haven't seen this injury before
                          if (!uniqueActiveInjuries.contains(injuryKey)) {
                            uniqueActiveInjuries.add(injuryKey);
                            hasActiveInjury = true;
                            
                            // Update latest injury date if needed
                            if (injury['lastUpdated'] != null) {
                              final newDate = injury['lastUpdated'] as String;
                              if (latestInjuryDate == null || newDate.compareTo(latestInjuryDate) > 0) {
                                latestInjuryDate = newDate;
                              }
                            } else if (reportData['timestamp'] != null && 
                                      (latestInjuryDate == null || reportData['timestamp'] != null)) {
                              final timestamp = reportData['timestamp'] as Timestamp;
                              final newDate = DateFormat('yyyy-MM-dd').format(timestamp.toDate());
                              if (latestInjuryDate == null || newDate.compareTo(latestInjuryDate) > 0) {
                                latestInjuryDate = newDate;
                              }
                            }
                          }
                        }
                      }
                    }
                    
                    if (hasActiveInjury) {
                      activeAthletes.add({
                        'id': athleteId,
                        'name': athleteData['name'] ?? 'Unknown Athlete',
                        'latestInjuryDate': latestInjuryDate,
                      });
                    }
                  }
                }
              }
            }
            
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
                    "Athletes with Active Injuries",
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: defaultPadding),
                  if (reportsSnapshot.connectionState == ConnectionState.waiting ||
                      athletesSnapshot.connectionState == ConnectionState.waiting)
                    _buildLoadingAthletes()
                  else if (activeAthletes.isEmpty)
                    const Center(
                      child: Text(
                        "No athletes with active injuries",
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: activeAthletes.length,
                      itemBuilder: (context, index) {
                        final athlete = activeAthletes[index];
                        final dateStr = athlete['latestInjuryDate'] != null
                            ? 'Since: ${DateFormat('MMM dd, yyyy').format(DateTime.parse(athlete['latestInjuryDate']))}'
                            : '';
                        
                        return Card(
                          color: secondaryColor.withOpacity(0.7),
                          margin: const EdgeInsets.only(bottom: defaultPadding / 2),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.red.withOpacity(0.2),
                              child: const Icon(Icons.person, color: Colors.red),
                            ),
                            title: Text(
                              athlete['name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              dateStr,
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white54,
                              size: 16,
                            ),
                            onTap: () {
                              // Navigate to athlete injury details
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => InjuryRecordsScreen(
                                    initialAthleteId: athlete['id'],
                                  ),
                                ),
                              );
                            },
                          ),
                        ).animate().fadeIn(duration: 300.ms, delay: (100 * index).ms);
            },
          ),
        ],
      ),
    ).animate().fadeIn(duration: 500.ms, delay: 600.ms).slideY(begin: 0.2, end: 0);
          },
        );
      },
    );
  }

  Widget _buildLoadingAthletes() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[800]!,
      highlightColor: Colors.grey[700]!,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Card(
            margin: const EdgeInsets.only(bottom: defaultPadding / 2),
            child: const ListTile(
              leading: CircleAvatar(),
              title: SizedBox(height: 16, width: double.infinity),
              subtitle: SizedBox(height: 12, width: double.infinity),
            ),
          );
        },
      ),
    );
  }

  Color _getColorFromHex(String hexColor) {
    hexColor = hexColor.replaceAll("#", "");
    if (hexColor.length == 6) {
      hexColor = "FF" + hexColor;
    }
    try {
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      return Colors.red; // Default color if parsing fails
    }
  }

  Widget _buildAnnouncementsSection() {
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF212332),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Announcements",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: defaultPadding,
                    vertical: defaultPadding / 2,
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SharedAnnouncementsScreen(userRole: 'Medical'),
                    ),
                  );
                },
                icon: const Icon(Icons.announcement),
                label: const Text("View All"),
              ),
            ],
          ),
          const SizedBox(height: defaultPadding),
          SizedBox(
            height: 300,
            child: SharedAnnouncementsScreen(userRole: 'Medical'),
          ),
        ],
      ),
    );
  }
} 