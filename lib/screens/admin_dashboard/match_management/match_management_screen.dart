import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../../../constants.dart';
import '../../../config.dart';
import '../../../responsive.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/match_service.dart';
import '../../coach_dashboard/performance_analysis/match_scorecard_details.dart';
import 'dart:math';

class MatchManagementScreen extends StatefulWidget {
  const MatchManagementScreen({Key? key}) : super(key: key);

  @override
  _MatchManagementScreenState createState() => _MatchManagementScreenState();
}

class _MatchManagementScreenState extends State<MatchManagementScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  
  String selectedSport = 'running';
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  List<String> selectedAthletes = [];
  List<Map<String, dynamic>> matches = [];
  List<Map<String, dynamic>> athletes = [];
  File? videoFile;
  Uint8List? videoBytes;
  String? videoFileName;
  String? selectedMatchId;
  bool isLoading = false;
  double uploadProgress = 0.0;
  String uploadStatus = '';
  bool useMockMode = Config.enableMockMode;
  bool isCancelling = false;
  bool isProcessing = false;
  String processingStatus = '';
  Timer? processingStatusTimer;

  // Match summary fields
  Map<String, dynamic> matchSummary = {};

  // New fields for processing status tracking
  Set<String> _processedMatchIds = {};
  Set<String> _savedSummaryMatchIds = {};

  List<TextEditingController>? _timeControllers;
  String? errorMessage;

  // Add a new field to track the selected athlete for filtering
  String? selectedAthleteId;
  List<Map<String, dynamic>> filteredMatches = [];

  @override
  void initState() {
    super.initState();
    print('Initializing MatchManagementScreen');
    _tabController = TabController(length: 3, vsync: this);
    _initializeData();
  }
  
  Future<void> _initializeData() async {
    // Load athletes first
    await _loadAthletes();
    // Then load matches (which may create a sample match if needed)
    await _loadMatches();
  }

  Future<void> _loadAthletes() async {
    print('Loading athletes...');
    try {
      final snapshot = await _firestore
        .collection('users')
        .where('role', isEqualTo: 'athlete')
        .get();

      print('Athlete query returned ${snapshot.docs.length} documents');
      
      // Debug: Print the first document if available
      if (snapshot.docs.isNotEmpty) {
        print('First athlete document data: ${snapshot.docs.first.data()}');
      }

    setState(() {
        athletes = snapshot.docs
            .map((doc) {
              // Safely access fields with null checks
              final data = doc.data();
              return {
                'id': doc.id,
                'name': data['name'] ?? 'Unknown Athlete',
                // Try different possible field names for sport
                'sport': data['sport'] ?? data['sportsType'] ?? data['sportType'] ?? 'unknown',
              };
              })
          .toList();
    });
      
      print('Loaded ${athletes.length} athletes successfully');
      
      // If no athletes were found, create sample athletes
      if (athletes.isEmpty) {
        print('No athletes found. Creating sample athletes...');
        await _createSampleAthletes();
      }
    } catch (e) {
      print('Error loading athletes: $e');
    }
  }

  Future<void> _createSampleAthletes() async {
    try {
      // Sample athletes for each sport
      final sampleAthletes = [
        {'name': 'John Runner', 'role': 'athlete', 'sport': 'running', 'jerseyNumber': '1'},
        {'name': 'Sarah Runner', 'role': 'athlete', 'sport': 'running', 'jerseyNumber': '2'},
        {'name': 'Mike Swimmer', 'role': 'athlete', 'sport': 'swimming', 'jerseyNumber': '3'},
        {'name': 'Lisa Swimmer', 'role': 'athlete', 'sport': 'swimming', 'jerseyNumber': '4'},
        {'name': 'Tom Lifter', 'role': 'athlete', 'sport': 'weightlifting', 'jerseyNumber': '5'},
        {'name': 'Emma Lifter', 'role': 'athlete', 'sport': 'weightlifting', 'jerseyNumber': '6'},
      ];
      
      // Add each athlete to Firestore
      for (final athlete in sampleAthletes) {
        await _firestore.collection('users').add(athlete);
      }
      
      print('Created ${sampleAthletes.length} sample athletes');
      
      // Reload athletes
      await _loadAthletes();
    } catch (e) {
      print('Error creating sample athletes: $e');
    }
  }

  Future<void> _loadMatches() async {
    try {
      final snapshot = await _firestore
          .collection('matches')
          .orderBy('date', descending: true)
          .get();

      setState(() {
        // Store the previously selected match ID
        final previousSelectedId = selectedMatchId;
        
        matches = snapshot.docs
            .map((doc) {
              final data = doc.data();
              // Ensure all required fields exist
              return {
                'id': doc.id,
                'sport': data['sport'] ?? 'unknown',
                'date': data['date'] ?? Timestamp.now(),
                'status': data['status'] ?? 'scheduled',
                'athletes': data['athletes'] ?? [],
                'videoUrl': data['videoUrl'],
                ...data, // Include all other fields
              };
            })
            .toList();
            
        // Apply athlete filter if one is selected
        _filterMatchesByAthlete();
            
        // Check if the previously selected match still exists
        final previousMatchExists = matches.any((match) => match['id'] == previousSelectedId);
        
        // Set the selected match ID
        if (filteredMatches.isNotEmpty) {
          if (previousSelectedId != null && previousMatchExists) {
            // Keep the previously selected match if it still exists
            selectedMatchId = previousSelectedId;
          } else {
            // Otherwise, select the first match
            selectedMatchId = filteredMatches.first['id'];
          }
        } else {
          // No matches available
          selectedMatchId = null;
        }
        
        print('Loaded ${matches.length} matches successfully');
        
        // If no matches were found, create a sample match
        if (matches.isEmpty && athletes.isNotEmpty) {
          print('No matches found. Creating a sample match...');
          _createSampleMatch();
        }
      });
    } catch (e) {
      print('Error loading matches: $e');
    }
  }
  
  // New method to filter matches by selected athlete
  void _filterMatchesByAthlete() {
    if (selectedAthleteId != null) {
      filteredMatches = matches
          .where((match) => (match['athletes'] as List<dynamic>).contains(selectedAthleteId))
          .toList();
    } else {
      filteredMatches = List.from(matches);
    }
  }
  
  Future<void> _createSampleMatch() async {
    try {
      // Get athletes for the selected sport
      final sportAthletes = athletes
          .where((athlete) => athlete['sport'].toString().toLowerCase() == selectedSport.toLowerCase())
          .toList();
          
      if (sportAthletes.isEmpty) {
        print('No athletes found for sport: $selectedSport');
        return;
      }
      
      // Create a sample match
      final matchData = {
        'sport': selectedSport,
        'date': Timestamp.fromDate(DateTime.now().add(Duration(days: 1))),
        'athletes': sportAthletes.map((a) => a['id']).toList(),
        'status': 'scheduled',
        'createdAt': FieldValue.serverTimestamp(),
      };
      
      final docRef = await _firestore.collection('matches').add(matchData);
      print('Created sample match with ID: ${docRef.id}');
      
      // Reload matches
      _loadMatches();
    } catch (e) {
      print('Error creating sample match: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(defaultPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match Management',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: defaultPadding),
                TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Create Match'),
                    Tab(text: 'Upload Video'),
                    Tab(text: 'Match Summary'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildCreateMatchTab(),
                _buildVideoUploadTab(),
                _buildMatchSummaryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateMatchTab() {
    // Filter athletes by selected sport
    final filteredAthletes = athletes
        .where((athlete) => 
            athlete['sport'].toString().toLowerCase() == selectedSport.toLowerCase())
        .toList();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(defaultPadding),
      child: Container(
        decoration: BoxDecoration(
          color: secondaryColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Header with gradient
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(defaultPadding),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2C3E50),
                      Color(0xFF1A2530),
                    ],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.sports,
                          color: Colors.white,
                          size: 28,
                        ),
                        SizedBox(width: 12),
                        Text(
                          "Create New Match",
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      "Set up a new match for athletes to participate in",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sport Selection
                    Text(
                      'Select Sport',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: defaultPadding / 2),
                    
                    // Sport Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildSportCard(
                            'Running',
                            Icons.directions_run,
                            selectedSport == 'running',
                            () => setState(() {
                              selectedSport = 'running';
                  selectedAthletes = [];
                            }),
                            Colors.blue,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildSportCard(
                            'Swimming',
                            Icons.pool,
                            selectedSport == 'swimming',
                            () => setState(() {
                              selectedSport = 'swimming';
                              selectedAthletes = [];
                            }),
                            Colors.cyan,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildSportCard(
                            'Weightlifting',
                            Icons.fitness_center,
                            selectedSport == 'weightlifting',
                            () => setState(() {
                              selectedSport = 'weightlifting';
                              selectedAthletes = [];
                            }),
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: defaultPadding * 1.5),
                    
                    // Date & Time Selection
                    Text(
                'Match Date & Time',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: defaultPadding / 2),
                    
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: ListTile(
                        leading: Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.calendar_today,
                            color: Colors.indigo,
                          ),
                        ),
                        title: Text(
                selectedDate != null
                              ? DateFormat('EEEE, MMM dd, yyyy').format(selectedDate!)
                              : 'Select Date',
                          style: TextStyle(
                            fontWeight: selectedDate != null ? FontWeight.w500 : FontWeight.normal,
                          ),
                        ),
                        subtitle: selectedTime != null
                            ? Text(selectedTime!.format(context))
                            : null,
                        trailing: ElevatedButton.icon(
                          icon: Icon(Icons.edit_calendar),
                          label: Text(selectedDate != null ? 'Change' : 'Select'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                onPressed: () async {
                  final date = await showDatePicker(
                    context: context,
                              initialDate: selectedDate ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                                initialTime: selectedTime ?? TimeOfDay.now(),
                    );
                    setState(() {
                      selectedDate = date;
                      selectedTime = time;
                    });
                  }
                },
                        ),
                      ),
                    ),
                    
                    SizedBox(height: defaultPadding * 1.5),
                    
                    // Athlete Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            Text(
              'Select Athletes',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Remove the "Create Sample Athletes" button
              ],
            ),
                    SizedBox(height: defaultPadding / 2),
            
            // Show message if no athletes are available for the selected sport
            if (filteredAthletes.isEmpty)
                      Container(
                        padding: EdgeInsets.all(defaultPadding * 1.5),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_off,
                              size: 48,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                    'No athletes available for ${selectedSport.toUpperCase()}',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.w500,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Click "Create Sample Athletes" to add some test athletes',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                ),
              )
            else
                      Container(
                        padding: EdgeInsets.all(defaultPadding),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Available Athletes: ${filteredAthletes.length}',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 12),
            Wrap(
              spacing: 8.0,
                              runSpacing: 12.0,
                children: filteredAthletes
                                  .map((athlete) => _buildAthleteChip(athlete))
                  .toList(),
            ),
                          ],
                        ),
                      ),
                    
                    SizedBox(height: defaultPadding * 2),
                    
                    // Create Match Button
                    Container(
                      height: 50,
              width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: Icon(Icons.add_circle),
                        label: Text('CREATE MATCH'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                onPressed: selectedAthletes.isNotEmpty && selectedDate != null && selectedTime != null
                    ? _createMatch
                    : null,
                      ),
                    ),
                    
                    SizedBox(height: defaultPadding),
                    
                    // Requirements text
                    if (selectedAthletes.isEmpty || selectedDate == null || selectedTime == null)
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.amber),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Please select athletes, date, and time to create a match',
                                style: TextStyle(color: Colors.amber.shade300),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildSportCard(String name, IconData icon, bool isSelected, VoidCallback onTap, Color color) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.black12,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.white10,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.3) : Colors.black12,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? color : Colors.grey,
                size: 24,
              ),
            ),
            SizedBox(height: 12),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? color : Colors.grey,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildAthleteChip(Map<String, dynamic> athlete) {
    final isSelected = selectedAthletes.contains(athlete['id']);
    final name = athlete['name'] as String;
    final jerseyNumber = athlete['jerseyNumber'] as String? ?? '';
    
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            selectedAthletes.remove(athlete['id']);
          } else {
            selectedAthletes.add(athlete['id']);
          }
        });
      },
      borderRadius: BorderRadius.circular(30),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.withOpacity(0.2) : Colors.black26,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.transparent,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue.withOpacity(0.3) : Colors.black12,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  jerseyNumber.isNotEmpty ? jerseyNumber : name[0],
                  style: TextStyle(
                    color: isSelected ? Colors.blue : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              name,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected ? Colors.blue : Colors.grey,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoUploadTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: defaultPadding),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height - 200, // Subtract header height
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(defaultBorderRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(defaultPadding),
      child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                // Header section with title and description
                Container(
                  width: double.infinity,
                padding: const EdgeInsets.all(defaultPadding),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withOpacity(0.7),
                        primaryColor.withOpacity(0.4),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(defaultBorderRadius),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.2),
                        blurRadius: 8,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                  children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                        Icons.video_library_rounded,
                          size: 36,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                    Text(
                      'Upload Match Video',
                        style: TextStyle(
                                fontSize: 22,
                          fontWeight: FontWeight.bold,
                                color: Colors.white,
                        ),
                    ),
                            SizedBox(height: 4),
                    Text(
                              'Upload a video of the match for AI processing and analysis. The system will automatically extract key metrics and insights.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 2,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(height: 24),
                
                // Match selection section
                Container(
                  padding: EdgeInsets.all(defaultPadding),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(defaultBorderRadius),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sports,
                            color: primaryColor,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                      Text(
                        'Match Selection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.titleLarge?.color,
                            ),
                          ),
                        ],
                                ),
                                SizedBox(height: 16),
                                Text(
                        'Select the match you want to upload a video for:',
                                  style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 12),
                          Container(
                        decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                                ),
                              ),
                        child: DropdownButtonFormField<String>(
                              value: selectedMatchId,
                          decoration: InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            border: InputBorder.none,
                            hintText: 'Select a match',
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                          icon: Icon(Icons.arrow_drop_down, color: primaryColor),
                          isExpanded: true,
                          items: matches.map((match) {
                                final date = match['date'] != null 
                                ? DateFormat('yyyy-MM-dd').format((match['date'] as Timestamp).toDate())
                                : 'Unknown Date';
                            final sportType = match['sport'] as String? ?? 'unknown';
                                
                                return DropdownMenuItem<String>(
                                  value: match['id'] as String,
                              child: Container(
                                constraints: BoxConstraints(maxHeight: 50),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                    children: [
                                        Text(
                                      '$date - ${sportType.toUpperCase()} Match',
                                          style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: Theme.of(context).textTheme.titleMedium?.color,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                ),
                                  ),
                                );
                              }).toList(),
                          onChanged: (value) {
                            setState(() {
                                  selectedMatchId = value;
                            });
                          },
                        ),
                          ),
                      ],
                  ),
                ),
                      
                      SizedBox(height: 24),
                      
                      // Video upload section
                Container(
                  padding: EdgeInsets.all(defaultPadding),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(defaultBorderRadius),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withOpacity(0.1),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.videocam_rounded,
                            color: primaryColor,
                            size: 22,
                          ),
                          SizedBox(width: 8),
                        Text(
                        'Video Selection',
                          style: TextStyle(
                          fontSize: 18,
                            fontWeight: FontWeight.bold,
                              color: Theme.of(context).textTheme.titleLarge?.color,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      
                      // Video preview or upload area
                      videoFile == null && videoBytes == null
                        ? Container(
                            height: 220,
                          width: double.infinity,
                          decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                          ),
                            child: DashedBorder(
                              color: primaryColor.withOpacity(0.3),
                              strokeWidth: 1.5,
                              gap: 5.0,
                              radius: Radius.circular(12),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                    Container(
                                      padding: EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: primaryColor.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.cloud_upload_rounded,
                                  size: 48,
                                        color: primaryColor,
                                      ),
                                    ),
                                    SizedBox(height: 20),
                                    ElevatedButton.icon(
                                      onPressed: !isProcessing ? _pickVideo : null,
                                      icon: const Icon(Icons.upload_file),
                                      label: const Text('Select Video'),
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: primaryColor,
                                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        elevation: 2,
                                      ),
                                ),
                                SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.info_outline,
                                          size: 14,
                                          color: Colors.grey.shade600,
                                        ),
                                        SizedBox(width: 4),
                                Text(
                                          'Supported formats: MP4, MOV, AVI, WEBM',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                                  ],
                                ),
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              // Video preview container
                      Container(
                                height: 180,
                            width: double.infinity,
                        decoration: BoxDecoration(
                                  color: Colors.black87,
                                  borderRadius: BorderRadius.circular(12),
                            ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                      Icons.video_file_rounded,
                                    size: 48,
                                      color: Colors.white70,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      videoFileName ?? 'Selected Video',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    SizedBox(height: 4),
                                  Text(
                                      kIsWeb
                                          ? '${(videoBytes!.length / (1024 * 1024)).toStringAsFixed(2)} MB'
                                          : '${(videoFile!.lengthSync() / (1024 * 1024)).toStringAsFixed(2)} MB',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                  ),
                                ],
                              ),
                            ),
                              SizedBox(height: 16),
                              // Action buttons
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: !isProcessing ? _pickVideo : null,
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Change Video'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryColor,
                                      side: BorderSide(color: primaryColor),
                                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  ElevatedButton.icon(
                                    onPressed: selectedMatchId != null && !isProcessing ? _uploadDirectlyToBackend : null,
                                    icon: const Icon(Icons.send),
                                    label: const Text('Process Video'),
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: primaryColor,
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      elevation: 2,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                      ),
                  ],
                ),
              ),
              
                SizedBox(height: 24),
                
                // Processing status section
                if (isLoading || isProcessing)
                Container(
                  padding: EdgeInsets.all(defaultPadding),
                  decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(defaultBorderRadius),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 5,
                          offset: Offset(0, 2),
                        ),
                      ],
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                            children: [
                            Icon(
                              isProcessing ? Icons.settings : Icons.upload_file,
                              color: primaryColor,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              isProcessing ? 'Processing Status' : 'Upload Status',
                                  style: TextStyle(
                                fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                color: Theme.of(context).textTheme.titleLarge?.color,
                                ),
                              ),
                            ],
                          ),
                        SizedBox(height: 16),
                        
                        // Progress indicator
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: isProcessing ? null : uploadProgress,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
                          ),
                        ),
                        SizedBox(height: 12),
                        
                        // Status text
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                isProcessing ? Icons.autorenew_rounded : Icons.cloud_upload_rounded,
                                color: primaryColor,
                                size: 16,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                isProcessing ? processingStatus : uploadStatus,
                          style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyMedium?.color,
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                              ),
                            ),
                          ],
                        ),
                        
                        // Cancel button
                        if (isLoading && !isProcessing)
                          Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: TextButton.icon(
                        onPressed: () {
                                setState(() {
                                  isCancelling = true;
                                  uploadStatus = 'Cancelling upload...';
                                });
                                // Actual cancellation logic would be here
                                Future.delayed(Duration(seconds: 1), () {
                                  setState(() {
                                    isLoading = false;
                                    isCancelling = false;
                                    uploadProgress = 0;
                                    uploadStatus = '';
                                  });
                                });
                              },
                              icon: Icon(Icons.cancel, size: 16),
                              label: Text('Cancel Upload'),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                              ),
                          ),
                      ),
                    ],
                  ),
                ),
              
                // Tips section
                if (!isLoading && !isProcessing)
                Container(
                    margin: EdgeInsets.only(top: 24),
                  padding: EdgeInsets.all(defaultPadding),
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(defaultBorderRadius),
                      border: Border.all(
                        color: primaryColor.withOpacity(0.2),
                      ),
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: Colors.amber.shade700,
                              size: 20,
                            ),
                            SizedBox(width: 8),
                      Text(
                              'Tips for Best Results',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                      ),
                    ],
                  ),
                        SizedBox(height: 12),
                        _buildTipItem(
                          icon: Icons.high_quality,
                          text: 'Use high-quality video for better analysis results',
                        ),
                        SizedBox(height: 8),
                        _buildTipItem(
                          icon: Icons.videocam,
                          text: 'Ensure the camera captures the entire playing area',
                        ),
                        SizedBox(height: 8),
                        _buildTipItem(
                          icon: Icons.timelapse,
                          text: 'Processing time depends on video length and quality',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem({required IconData icon, required String text}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
        Icon(
          icon,
          size: 16,
          color: primaryColor.withOpacity(0.7),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: Colors.blue.shade900.withOpacity(0.7),
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 2,
                      ),
                    ),
                  ],
      );
    }

  Widget _buildMatchSummaryTab() {
    final selectedMatch = matches.firstWhere(
      (m) => m['id'] == selectedMatchId,
      orElse: () => {
        'id': selectedMatchId,
        'sport': 'unknown',
        'sport_type': 'unknown',
        'date': Timestamp.now(),
      },
    );

    final sportType = selectedMatch['sport'] ?? selectedMatch['sport_type'] ?? 'unknown';
    
    // Get the athletes for this match
    final matchAthletes = List<String>.from(selectedMatch['athletes'] ?? []);
    
    // Create controllers for time inputs
    if (_timeControllers == null || _timeControllers?.length != matchAthletes.length) {
      _timeControllers = List.generate(
        matchAthletes.length,
        (index) => TextEditingController(text: ''),
      );
    }
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main content area - Expanded to fill available space
          Expanded(
            child: matchAthletes.isEmpty
                ? _buildNoAthletesView()
                : _buildMatchSummaryContent(sportType, matchAthletes),
          ),
        ],
      ),
    );
  }
  
  // Widget for when no athletes are in the match
  Widget _buildNoAthletesView() {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
                    decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_off,
                size: 80,
                color: Colors.blue.shade300,
              ),
            ),
            SizedBox(height: 24),
            Text(
              'No athletes in this match',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            SizedBox(height: 16),
            Container(
              width: 400,
              child: Text(
                'Add athletes to the match to enter race results',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _tabController.animateTo(0),
              icon: Icon(Icons.edit),
              label: Text('Edit Match'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: primaryColor,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                ),
                elevation: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Widget for match summary content
  Widget _buildMatchSummaryContent(String sportType, List<String> matchAthletes) {
    return Container(
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with sport type
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
                    ),
                    child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                    _getSportIcon(sportType),
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        SizedBox(width: 16),
                        Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${sportType.toUpperCase()} Match Summary',
                            style: TextStyle(
                              fontSize: 22, 
                              fontWeight: FontWeight.bold,
                                color: Colors.white,
                            ),
                          ),
                            SizedBox(height: 4),
                        Text(
                              'Enter race results for each athlete',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.9),
                              ),
                        ),
                      ],
                    ),
                      ],
                  ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Race Details',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                    ),
                  ),
                ],
                ),
              ],
            ),
          ),
          
          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Race type selector
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Race Configuration',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                SizedBox(height: 16),
                        Container(
                          padding: EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context).dividerColor,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                  Text(
                                      'Race Type',
                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                      fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor,
                                          width: 1,
                                        ),
                                      ),
                                      child: DropdownButtonFormField<String>(
                                        decoration: InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          border: InputBorder.none,
                                          hintText: 'Select race type',
                                          hintStyle: TextStyle(color: Colors.grey),
                                        ),
                                        value: '100m',
                                        items: [
                                          '100m', '200m', '400m', '800m', '1500m', '5000m', '10000m', 'Marathon'
                                        ].map<DropdownMenuItem<String>>((distance) {
                                          return DropdownMenuItem<String>(
                                            value: distance,
                                            child: Text(distance),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          // Handle race type change
                                        },
                                        icon: Icon(Icons.keyboard_arrow_down, color: primaryColor),
                                        dropdownColor: Theme.of(context).cardColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Track Condition',
                                      style: TextStyle(
                      fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: Theme.of(context).dividerColor,
                                          width: 1,
                                        ),
                                      ),
                                      child: DropdownButtonFormField<String>(
                                        decoration: InputDecoration(
                                          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                          border: InputBorder.none,
                                          hintText: 'Select condition',
                                          hintStyle: TextStyle(color: Colors.grey),
                                        ),
                                        value: 'Excellent',
                                        items: [
                                          'Excellent', 'Good', 'Fair', 'Poor'
                                        ].map<DropdownMenuItem<String>>((condition) {
                                          return DropdownMenuItem<String>(
                                            value: condition,
                                            child: Text(condition),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          // Handle condition change
                                        },
                                        icon: Icon(Icons.keyboard_arrow_down, color: primaryColor),
                                        dropdownColor: Theme.of(context).cardColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Results section
                  Container(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Athlete Results',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.timer,
                                    size: 16,
                                    color: primaryColor,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Enter Times',
                                    style: TextStyle(
                                      color: primaryColor,
                              fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        
                        // Column headers
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                              topRight: Radius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(width: 60, child: Text('RANK', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700))),
                              SizedBox(width: 8),
                              Expanded(child: Text('ATHLETE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700))),
                              Container(width: 120, child: Text('TIME', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade700))),
            ],
          ),
        ),
          
                        // Athlete rows
                        Container(
                          height: 200, // Fixed height with internal scrolling
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            border: Border.all(color: Theme.of(context).dividerColor),
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                          ),
                          child: ListView.separated(
                            itemCount: matchAthletes.length,
                            separatorBuilder: (context, index) => Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor.withOpacity(0.5)),
                            itemBuilder: (context, index) {
                              final athleteId = matchAthletes[index];
                              final athlete = athletes.firstWhere(
                                (a) => a['id'] == athleteId,
                                orElse: () => {'id': athleteId, 'name': 'Unknown Athlete'},
                              );
                              final athleteName = athlete['name'] ?? 'Unknown Athlete';
                              
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                color: index % 2 == 0 ? Colors.transparent : Theme.of(context).scaffoldBackgroundColor.withOpacity(0.5),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 60,
            child: Container(
                                        width: 36,
                                        height: 36,
                  decoration: BoxDecoration(
                                          color: _getRankColor(index),
                                          shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                                              color: _getRankColor(index).withOpacity(0.3),
                                              blurRadius: 8,
                                              offset: Offset(0, 3),
                  ),
                ],
              ),
                                        child: Center(
                                          child: Text(
                                            '${index + 1}',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundColor: Colors.grey.shade200,
                                            child: Text(
                                              athleteName.substring(0, 1).toUpperCase(),
                                              style: TextStyle(
                                                color: primaryColor,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            athleteName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 120,
                                      child: TextField(
                                        controller: _timeControllers?[index],
                                        decoration: InputDecoration(
                                          hintText: '00:00.00',
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            borderSide: BorderSide(
                                              color: Theme.of(context).dividerColor,
                                            ),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                          isDense: true,
                                          filled: true,
                                          fillColor: Theme.of(context).cardColor,
                                          prefixIcon: Icon(Icons.timer, size: 16, color: Colors.grey),
                                        ),
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
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
                  ),
                ],
              ),
            ),
          ),
          
          // Save button
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () {
                    // Reset form
                  },
                  child: Text('Reset Form'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    side: BorderSide(color: primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    // Collect the results
                    final results = List.generate(matchAthletes.length, (index) {
                      final athleteId = matchAthletes[index];
                      final athlete = athletes.firstWhere(
                        (a) => a['id'] == athleteId,
                        orElse: () => {'id': athleteId, 'name': 'Unknown Athlete'},
                      );
                      
                      return {
                        'athlete': athlete['name'],
                        'time': _timeControllers?[index].text ?? '',
                        'place': index + 1,
                      };
                    });
                    
                    // Save the summary
                    _saveSummary({
                      'sport': 'running',
                      'race_type': '100m',
                      'results': results,
                    });
                  },
                  icon: Icon(Icons.save),
                  label: Text('Save Results'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getSportIcon(String sportType) {
    switch (sportType.toLowerCase()) {
      case 'running':
        return Icons.directions_run;
      case 'swimming':
        return Icons.pool;
      case 'weightlifting':
        return Icons.fitness_center;
      case 'football':
      case 'soccer':
        return Icons.sports_soccer;
      case 'basketball':
        return Icons.sports_basketball;
      case 'tennis':
        return Icons.sports_tennis;
      case 'baseball':
        return Icons.sports_baseball;
      case 'volleyball':
        return Icons.sports_volleyball;
      default:
        return Icons.sports;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'processing':
        return Icons.autorenew;
      case 'scheduled':
        return Icons.event;
      case 'cancelled':
        return Icons.cancel;
      case 'uploading':
        return Icons.cloud_upload;
      default:
        return Icons.help_outline;
    }
  }
  
  // Helper function to get status color
  Color _getStatusColor(String status) {
    switch(status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'processing':
      case 'uploading':
      case 'video_uploaded':
        return Colors.blue;
      case 'scheduled':
        return Colors.orange;
      case 'processing_failed':
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  // Helper function to format status
  String _formatStatus(String status) {
    // Replace underscores with spaces and capitalize each word
    return status.split('_').map((word) => 
      word.substring(0, 1).toUpperCase() + word.substring(1).toLowerCase()
    ).join(' ');
  }
  
  // Build sport-specific summary based on sport type
  Widget _buildSportSpecificSummary(String sportType, Map<String, dynamic> selectedMatch) {
    // Check if we have a specific editor for this sport
    switch (sportType.toLowerCase()) {
      case 'running':
      return _buildRunningSummary();
      case 'swimming':
        return _buildSwimmingSummary();
      case 'weightlifting':
        return _buildWeightliftingSummary();
      default:
        // Generic summary for other sports
        return Container(
          width: double.infinity,
          height: double.infinity,
          padding: EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getSportIcon(sportType),
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                ),
                SizedBox(height: 24),
                Text(
            'No specific editor available for ${sportType.toUpperCase()} matches',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 16),
                Text(
                  'You can create a different match type or edit this match',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => _tabController.animateTo(0),
                  icon: Icon(Icons.add),
                  label: Text('Create Different Match Type'),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: primaryColor,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
    }
  }

  // Add _saveSummary method
  Future<void> _saveSummary(Map<String, dynamic> summary) async {
    try {
      setState(() => isLoading = true);
      
      // Add match ID to the summary if not already included
      if (!summary.containsKey('matchId') && selectedMatchId != null) {
        summary['matchId'] = selectedMatchId;
      }
      
      // Save the summary to Firestore
      await _firestore.collection('matches').doc(selectedMatchId).update({
        'summary': summary,
        'last_updated': FieldValue.serverTimestamp(),
      });
      
      // Show success message only if we haven't shown it before for this match
      if (!_savedSummaryMatchIds.contains(selectedMatchId)) {
        _savedSummaryMatchIds.add(selectedMatchId!); // Mark this match as having a saved summary
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Match summary saved successfully')),
        );
      }
      
      // Refresh the match data
      await _loadMatches();
    } catch (e) {
      print('Error saving match summary: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving match summary: $e')),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // Running summary widget
  Widget _buildRunningSummary() {
    // Get the selected match
    final selectedMatch = matches.firstWhere(
      (m) => m['id'] == selectedMatchId,
      orElse: () => {'id': selectedMatchId, 'athletes': []},
    );
    
    // Get the athletes for this match
    final matchAthletes = List<String>.from(selectedMatch['athletes'] ?? []);
    
    // Create controllers for time inputs
    if (_timeControllers == null || _timeControllers?.length != matchAthletes.length) {
      _timeControllers = List.generate(
        matchAthletes.length,
        (index) => TextEditingController(text: ''),
      );
    }
    
    if (matchAthletes.isEmpty) {
      return Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.person_off,
                  size: 64,
                  color: Colors.blue.shade300,
                ),
              ),
              SizedBox(height: 24),
              Text(
                'No athletes in this match',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'Add athletes to the match to enter race results',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: Icon(Icons.edit),
                label: Text('Edit Match'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: primaryColor,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Determine if we're on a narrow screen (mobile) or wide screen (desktop/web)
          final isWideScreen = constraints.maxWidth > 800;
    
    return SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Padding(
              padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  // Header with race info
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [primaryColor, primaryColor.withOpacity(0.7)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.directions_run,
                              color: Colors.white,
                              size: 32,
                            ),
                            SizedBox(width: 16),
          Text(
            'Running Match Summary',
            style: TextStyle(
                                fontSize: 24,
              fontWeight: FontWeight.bold,
                                color: Colors.white,
            ),
                            ),
                          ],
          ),
          SizedBox(height: 16),
                        Text(
                          'Enter race results for each athlete',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Race type selector
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Race Type',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                          SizedBox(height: 16),
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Theme.of(context).dividerColor,
                                width: 1,
                              ),
                            ),
                            child: DropdownButtonFormField<String>(
            decoration: InputDecoration(
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                border: InputBorder.none,
                                hintText: 'Select race type',
                                hintStyle: TextStyle(color: Colors.grey),
            ),
            value: '100m',
                              items: [
                                '100m', '200m', '400m', '800m', '1500m', '5000m', '10000m', 'Marathon'
                              ].map<DropdownMenuItem<String>>((distance) {
                                return DropdownMenuItem<String>(
                                  value: distance,
                                  child: Text(distance),
                                );
                              }).toList(),
                              onChanged: (value) {
                                // Handle race type change
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Results section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
          Text(
            'Results',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                          SizedBox(height: 24),
                          
                          // Column headers
                          Container(
                            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(width: 60, child: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold))),
                                SizedBox(width: 8),
                                Expanded(child: Text('Athlete', style: TextStyle(fontWeight: FontWeight.bold))),
                                Container(width: 120, child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          
                          // Athlete rows - Expanded to fill available space
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Theme.of(context).dividerColor),
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: ListView.separated(
              itemCount: matchAthletes.length,
                                separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final athleteId = matchAthletes[index];
                final athlete = athletes.firstWhere(
                  (a) => a['id'] == athleteId,
                  orElse: () => {'id': athleteId, 'name': 'Unknown Athlete'},
                );
                final athleteName = athlete['name'] ?? 'Unknown Athlete';
                
                                  return Container(
                                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    color: index % 2 == 0 ? Colors.transparent : Colors.grey.shade50,
                    child: Row(
                      children: [
                  Container(
                                          width: 60,
                                          child: CircleAvatar(
                                            radius: 16,
                                            backgroundColor: _getRankColor(index),
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            athleteName,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
            Container(
                                          width: 120,
                                          child: TextField(
                                            controller: _timeControllers?[index],
                                            decoration: InputDecoration(
                                              hintText: '00:00.00',
                                              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide(
                                                  color: Theme.of(context).dividerColor,
                                                ),
                                              ),
                                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              isDense: true,
                                            ),
                                            keyboardType: TextInputType.number,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                        ),
                      ),
                    ],
                  ),
                                  );
                                },
                              ),
                    ),
                        ),
                      ],
                      ),
                    ),
                  ),
          
                  SizedBox(height: 32),
          
          // Save button
                  Container(
            width: double.infinity,
                    padding: EdgeInsets.all(16),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Collect the results
                        final results = List.generate(matchAthletes.length, (index) {
                          final athleteId = matchAthletes[index];
                          final athlete = athletes.firstWhere(
                            (a) => a['id'] == athleteId,
                            orElse: () => {'id': athleteId, 'name': 'Unknown Athlete'},
                          );
                          
                          return {
                            'athlete': athlete['name'],
                            'time': _timeControllers?[index].text ?? '',
                            'place': index + 1,
                          };
                        });
                        
                        // Save the summary
                        _saveSummary({
                          'sport': 'running',
                          'race_type': '100m',
                          'results': results,
                        });
                      },
                      icon: Icon(Icons.save),
                      label: Text('Save Results'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                        backgroundColor: primaryColor,
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 3,
              ),
            ),
          ),
        ],
              ),
      ),
    );
  }
      ),
    );
  }
  
  Color _getRankColor(int rank) {
    switch (rank) {
      case 0:
        return Colors.amber.shade700; // Gold
      case 1:
        return Colors.blueGrey.shade400; // Silver
      case 2:
        return Colors.brown.shade400; // Bronze
      default:
        return Colors.grey.shade600;
    }
  }

  // Swimming summary widget
  Widget _buildSwimmingSummary() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine if we're on a narrow screen (mobile) or wide screen (desktop/web)
        final isWideScreen = constraints.maxWidth > 800;
        
    return SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: isWideScreen ? 1000 : 600),
              padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  // Header with swimming info
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade600, Colors.blue.shade400],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.pool,
                              color: Colors.white,
                              size: 32,
                            ),
                            SizedBox(width: 16),
          Text(
            'Swimming Match Summary',
            style: TextStyle(
                                fontSize: 24,
              fontWeight: FontWeight.bold,
                                color: Colors.white,
            ),
                            ),
                          ],
          ),
          SizedBox(height: 16),
                        Text(
                          'Enter swimming results for each athlete',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 32),
          
          // Event details
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Event Details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                          SizedBox(height: 24),
          Row(
                    children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Stroke',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  items: ['Freestyle', 'Backstroke', 'Breaststroke', 'Butterfly']
                    .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    )).toList(),
                  onChanged: (value) {},
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Distance',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                  items: ['50m', '100m', '200m', '400m', '800m', '1500m']
                    .map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    )).toList(),
                  onChanged: (value) {},
                        ),
                      ),
                    ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Results section
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
          Text(
            'Results',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
            ),
                  ),
                          SizedBox(height: 24),
          
                          // Athletes results
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Card(
                                margin: EdgeInsets.only(bottom: 16),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                child: Padding(
                                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                                        radius: 24,
                        backgroundColor: index == 0 ? Colors.amber : (index == 1 ? Colors.grey.shade300 : Colors.brown.shade200),
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Athlete ${index + 1}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              'Lane ${index + 1}',
                                              style: TextStyle(
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 16),
                  Container(
                                        width: 120,
                        child: TextFormField(
                          decoration: InputDecoration(
                            labelText: 'Time',
                                            border: OutlineInputBorder(
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                            isDense: true,
                                            filled: true,
                                            fillColor: Colors.white,
                                            hintText: '00:00.00',
                          ),
                          keyboardType: TextInputType.number,
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                        ),
                        ),
                      ],
                    ),
                  ),
              );
            },
                          ),
                        ],
                      ),
                    ),
          ),
          
                  SizedBox(height: 32),
          
          // Save button
                  Center(
                    child: Container(
                      width: isWideScreen ? 300 : double.infinity,
                      child: ElevatedButton.icon(
              onPressed: () {
                _saveSummary({
                  'stroke': 'Freestyle',
                  'distance': '100m',
                  'results': [
                    {'athlete': 'Athlete 1', 'time': '47.58', 'place': 1},
                    {'athlete': 'Athlete 2', 'time': '48.12', 'place': 2},
                    {'athlete': 'Athlete 3', 'time': '49.37', 'place': 3},
                  ],
                });
              },
                        icon: Icon(Icons.save),
                        label: Text('Save Swimming Results'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                          backgroundColor: Colors.blue.shade600,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
              ),
                          elevation: 3,
            ),
          ),
                    ),
                  ),
                  
                  SizedBox(height: 32),
        ],
              ),
            ),
      ),
        );
      }
    );
  }

  // Weightlifting summary widget
  Widget _buildWeightliftingSummary() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine if we're on a narrow screen (mobile) or wide screen (desktop/web)
        final isWideScreen = constraints.maxWidth > 800;
        
    return SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: Center(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: isWideScreen ? 1000 : 600,
                minHeight: 1000, // Added minimum height to make the container taller
              ),
              padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                  // Header with weightlifting info
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade700, Colors.amber.shade500],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.fitness_center,
                              color: Colors.white,
                              size: 32,
                            ),
                            SizedBox(width: 16),
          Text(
            'Weightlifting Match Summary',
            style: TextStyle(
                                fontSize: 24,
              fontWeight: FontWeight.bold,
                                color: Colors.white,
            ),
                            ),
                          ],
          ),
          SizedBox(height: 16),
                        Text(
                          'Enter lift results for each athlete',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Lift type selector
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lift Type',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                          SizedBox(height: 16),
          DropdownButtonFormField<String>(
            decoration: InputDecoration(
                              labelText: 'Select Lift Type',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            items: ['Snatch', 'Clean and Jerk', 'Combined']
              .map((type) => DropdownMenuItem(
                value: type,
                child: Text(type),
              )).toList(),
            onChanged: (value) {},
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 32),
                  
                  // Athletes attempts
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
          Text(
                            'Athlete Attempts',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
                          SizedBox(height: 24),
          
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Card(
                                margin: EdgeInsets.only(bottom: 24),
                                elevation: 1,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                child: Padding(
                                  padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                                      // Athlete header
                      Row(
                        children: [
                          CircleAvatar(
                                            radius: 24,
                            backgroundColor: index == 0 ? Colors.amber : (index == 1 ? Colors.grey.shade300 : Colors.brown.shade200),
                                            child: Text(
                                              '${index + 1}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 16),
                          Expanded(
                                            child: Text(
                                              'Athlete ${index + 1}',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                    ),
                                  ],
                                ),
                                      
                                      SizedBox(height: 24),
                                      
                                      // Attempts
                                      Text(
                                        'Attempts',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                      
                                      // Horizontal scrollable attempts
                                      Container(
                                        height: isWideScreen ? null : 220,
                                        child: isWideScreen
                                            ? Row(
                                                children: _buildAttemptWidgets(),
                                              )
                                            : SingleChildScrollView(
                                                scrollDirection: Axis.horizontal,
                                                child: Row(
                                                  children: _buildAttemptWidgets(),
                                                ),
                                              ),
                                    ),
                                  ],
                                ),
                                ),
                              );
                            },
                                    ),
                                  ],
                                ),
                    ),
                  ),
                  
                  SizedBox(height: 32),
          
          // Save button
                  Center(
                    child: Container(
                      width: isWideScreen ? 300 : double.infinity,
                      child: ElevatedButton.icon(
              onPressed: () {
                _saveSummary({
                  'lift_type': 'Clean and Jerk',
                  'attempts': [
                    {
                      'athlete': 'Athlete 1',
                      'attempts': [
                        {'weight': 180, 'success': true},
                        {'weight': 190, 'success': false},
                        {'weight': 195, 'success': true},
                      ],
                      'place': 1,
                    },
                    {
                      'athlete': 'Athlete 2',
                      'attempts': [
                        {'weight': 175, 'success': true},
                        {'weight': 185, 'success': true},
                        {'weight': 190, 'success': false},
                      ],
                      'place': 2,
                    },
                    {
                      'athlete': 'Athlete 3',
                      'attempts': [
                        {'weight': 170, 'success': true},
                        {'weight': 180, 'success': false},
                        {'weight': 180, 'success': true},
                      ],
                      'place': 3,
                    },
                  ],
                });
              },
                        icon: Icon(Icons.save),
                        label: Text('Save Weightlifting Results'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                          backgroundColor: Colors.amber.shade700,
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 3,
                        ),
                      ),
                    ),
                  ),
                  
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      }
    );
  }
  
  // Helper method to build attempt widgets for weightlifting
  List<Widget> _buildAttemptWidgets() {
    return List.generate(3, (attemptIndex) {
      final isSuccess = attemptIndex != 1; // Just for demo, 2nd attempt fails
      
      return Container(
        width: 180,
        margin: EdgeInsets.only(right: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSuccess ? Colors.green.shade200 : Colors.red.shade200,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attempt ${attemptIndex + 1}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: 'Weight (kg)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isDense: true,
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              initialValue: isSuccess ? '${170 + (attemptIndex * 10)}' : '${180 + (attemptIndex * 5)}',
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Success',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Switch(
                  value: isSuccess,
                  activeColor: Colors.green,
                  onChanged: (value) {},
                ),
              ],
            ),
          ],
        ),
      );
    });
  }

  Future<void> _createMatch() async {
    if (_formKey.currentState!.validate() &&
        selectedDate != null &&
        selectedTime != null &&
        selectedAthletes.isNotEmpty) {
      setState(() => isLoading = true);
      try {
        final matchData = {
          'sport': selectedSport,
          'date': Timestamp.fromDate(DateTime(
            selectedDate!.year,
            selectedDate!.month,
            selectedDate!.day,
            selectedTime!.hour,
            selectedTime!.minute,
          )),
          'athletes': selectedAthletes,
          'status': 'scheduled',
          'createdAt': FieldValue.serverTimestamp(),
        };

        await _firestore.collection('matches').add(matchData);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Match created successfully')),
        );

        // Move to video upload tab
        _tabController.animateTo(1);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating match: $e')),
        );
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> _pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.video,
      allowMultiple: false,
      withData: true,
    );

    if (result != null) {
      setState(() {
        if (kIsWeb) {
          // For web, store the bytes and filename
          videoBytes = result.files.single.bytes;
          videoFileName = result.files.single.name;
          videoFile = null;
          
          // Check file size and show warning if too large
          final fileSizeMB = videoBytes!.length / (1024 * 1024);
          if (fileSizeMB > 50) {
            _showFileSizeWarning(fileSizeMB);
          }
        } else {
          // For mobile/desktop, create a File object
        videoFile = File(result.files.single.path!);
          videoBytes = null;
          videoFileName = result.files.single.name;
          
          // Check file size and show warning if too large
          final fileSizeMB = videoFile!.lengthSync() / (1024 * 1024);
          if (fileSizeMB > 50) {
            _showFileSizeWarning(fileSizeMB);
          }
        }
      });
    }
  }

  void _showFileSizeWarning(double fileSizeMB) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Warning: The selected video is ${fileSizeMB.toStringAsFixed(1)} MB. Large videos may take a long time to upload and process. Consider using a smaller video for better results.',
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 10),
      ),
    );
  }

  Future<void> _uploadDirectlyToBackend() async {
    if (videoFile == null && videoBytes == null) return;
    if (selectedMatchId == null) return;

    setState(() {
      isLoading = true;
      uploadProgress = 0;
      uploadStatus = 'Preparing to upload...';
    });
    
    try {
      print('Starting direct upload to backend...');
      
      // Verify that the match document still exists
      if (!await _verifySelectedMatch()) {
        await _showMatchNotFoundDialog();
        throw Exception('Match document no longer exists or is invalid. Please select another match.');
      }
      
      // Get the selected match
      final selectedMatch = matches.firstWhere(
        (match) => match['id'] == selectedMatchId,
        orElse: () => {'id': '', 'sport': ''} as Map<String, dynamic>,
      );

      if (selectedMatch['id'].isEmpty) {
        throw Exception('No match selected');
      }
      
      // Check if the match is already being processed or completed
      final currentStatus = selectedMatch['status'] as String? ?? 'unknown';
      if (currentStatus == 'processing' || currentStatus == 'completed') {
        final action = await _showMatchAlreadyProcessingDialog(currentStatus);
        if (action == MatchProcessingAction.cancel) {
      setState(() => isLoading = false);
          return;
        }
      }
      
      // Update the match status in Firestore to indicate processing has started
      setState(() {
        uploadStatus = 'Updating match status...';
      });
      
      try {
        await _firestore.collection('matches').doc(selectedMatch['id']).update({
          'status': 'uploading',
          'upload_started_at': FieldValue.serverTimestamp(),
          'coach_id': FirebaseAuth.instance.currentUser?.uid ?? 'unknown', // Ensure coach_id is set
        });
        print('Successfully updated match status to uploading');
      } catch (e) {
        print('Error updating match status: $e');
        // Continue with the upload even if the status update fails
      }
      
      // If mock mode is enabled, use mock upload
      if (useMockMode) {
        print('Mock mode enabled, using mock upload');
        return await _performMockUpload(selectedMatch);
      }
      
      // Check if backend is reachable
      final backendStatus = await _checkBackendStatus();
      
      if (backendStatus.isReachable) {
        // Backend is reachable, proceed with upload
        return await _performRealUpload(selectedMatch, backendStatus.url);
      } else {
        // Backend is not reachable, show error or use mock upload
        print('Backend not reachable: ${backendStatus.error}');
        
        // Show dialog to let user choose what to do
        final action = await _showBackendUnreachableDialog(backendStatus.error);
        
        if (action == BackendUnreachableAction.useMock) {
          // Use mock upload
          return await _performMockUpload(selectedMatch);
        } else if (action == BackendUnreachableAction.retry) {
          // Retry the upload
          setState(() {
            isLoading = false;
          });
          return await _uploadDirectlyToBackend();
        } else {
          // Cancel the upload
          return await _cancelUpload();
        }
      }
    } catch (e) {
      print('Error in direct upload process: $e');
      
      // Update the match status to indicate failure
      if (selectedMatchId != null) {
        try {
          await _firestore.collection('matches').doc(selectedMatchId!).update({
            'status': 'upload_failed',
            'error_message': e.toString(),
          });
        } catch (updateError) {
          print('Error updating match status: $updateError');
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading video: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 10),
          action: SnackBarAction(
            label: 'RETRY',
            onPressed: () {
              _uploadDirectlyToBackend();
            },
          ),
        ),
      );
      
      setState(() {
        isLoading = false;
      });
    } finally {
      if (mounted && !isCancelling && isLoading) {
      setState(() => isLoading = false);
      }
    }
  }
  
  // Show dialog when match is already being processed
  Future<MatchProcessingAction> _showMatchAlreadyProcessingDialog(String status) async {
    final result = await showDialog<MatchProcessingAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(status == 'processing' ? 'Match Already Processing' : 'Match Already Processed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status == 'processing' 
                ? 'This match is already being processed. Uploading a new video may cause issues.'
                : 'This match has already been processed. Uploading a new video will overwrite the existing results.'
            ),
            SizedBox(height: 16),
            Text('What would you like to do?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(MatchProcessingAction.cancel),
            child: Text('Cancel Upload'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(MatchProcessingAction.continue_),
            child: Text('Continue Anyway'),
          ),
        ],
      ),
    );
    
    return result ?? MatchProcessingAction.cancel;
  }
  
  // Check if backend is reachable
  Future<BackendStatus> _checkBackendStatus() async {
    setState(() {
      uploadStatus = 'Checking connection to backend...';
    });
    
    // Try primary backend first
    try {
      print('Checking if primary backend is reachable: ${Config.apiBaseUrl}');
      final pingResponse = await http.get(
        Uri.parse('${Config.apiBaseUrl}/health'),
      ).timeout(Duration(seconds: 5));
      
      if (pingResponse.statusCode == 200) {
        print('Primary backend is reachable');
        return BackendStatus(
          isReachable: true,
          url: '${Config.apiBaseUrl}/process_match_video',
        );
      }
    } catch (e) {
      print('Error connecting to primary backend: $e');
    }
    
    // Try fallback backend
    setState(() {
      uploadStatus = 'Trying fallback server...';
    });
    
    try {
      print('Checking if fallback backend is reachable: ${Config.fallbackApiBaseUrl}');
      final fallbackPingResponse = await http.get(
        Uri.parse('${Config.fallbackApiBaseUrl}/health'),
      ).timeout(Duration(seconds: 5));
      
      if (fallbackPingResponse.statusCode == 200) {
        print('Fallback backend is reachable');
        return BackendStatus(
          isReachable: true,
          url: '${Config.fallbackApiBaseUrl}/process_match_video',
        );
      }
    } catch (e) {
      print('Error connecting to fallback backend: $e');
    }
    
    // Neither backend is reachable
    return BackendStatus(
      isReachable: false,
      error: 'Cannot connect to any backend server. Please check your internet connection or try again later.',
    );
  }
  
  // Perform the actual upload to the backend
  Future<void> _performRealUpload(Map<String, dynamic> selectedMatch, String backendUrl) async {
    setState(() {
      uploadStatus = 'Preparing video for upload...';
    });
    
    print('Sending video directly to backend: $backendUrl');
    var request = http.MultipartRequest('POST', Uri.parse(backendUrl));
    
    // Add match data
    request.fields['match_id'] = selectedMatch['id'];
    request.fields['sport_type'] = selectedMatch['sport'] as String;
    
    // Get coach ID (current user ID)
    final currentUser = FirebaseAuth.instance.currentUser;
    final coachId = currentUser?.uid ?? 'unknown_coach';
    request.fields['coach_id'] = coachId;
    
    // Add the video file
    if (kIsWeb) {
      // For web, use bytes
      print('Sending video bytes to backend...');
      request.files.add(
        http.MultipartFile.fromBytes(
          'video',
          videoBytes!,
          filename: videoFileName ?? 'video.mp4',
          contentType: MediaType('video', 'mp4'),
        ),
      );
    } else {
      // For mobile/desktop, use file
      print('Sending video file to backend...');
      request.files.add(
        await http.MultipartFile.fromPath(
          'video',
          videoFile!.path,
          contentType: MediaType('video', 'mp4'),
        ),
      );
    }
    
    setState(() {
      uploadStatus = 'Uploading video to server...';
    });
    
    print('Sending multipart request to backend...');
    
    // Set a longer timeout for the upload
    final streamedResponse = await request.send().timeout(
      Duration(minutes: 5),
      onTimeout: () {
        throw TimeoutException('Upload timed out after 5 minutes. The video might be too large or the connection too slow.');
      },
    );
    
    // Track upload progress
    final totalBytes = streamedResponse.contentLength ?? 0;
    
    // Simple progress tracking
    if (totalBytes > 0) {
      // Update status to show we're starting the upload
      setState(() {
        uploadProgress = 0.01; // Start with 1% to show it's beginning
        uploadStatus = 'Starting upload (${totalBytes ~/ 1024} KB total)...';
      });
    }
    
    // Get the response
    final response = await http.Response.fromStream(streamedResponse);
    
    // Upload completed
    setState(() {
      uploadProgress = 1.0; // 100%
      uploadStatus = 'Upload complete, processing response...';
    });
    
    print('Backend API response status code: ${response.statusCode}');
    print('Backend API response body: ${response.body}');
    
    if (response.statusCode != 202 && response.statusCode != 200) {
      throw Exception('Failed to upload and process video: ${response.body}');
    }
    
    // We don't need to update the match status here, as the backend will handle it
    // This prevents race conditions that could lead to duplicate documents
    setState(() {
      uploadStatus = 'Video sent to server for processing...';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Video sent directly to backend for processing')),
    );

    // Clear the selected video
    setState(() {
      videoFile = null;
      videoBytes = null;
      videoFileName = null;
      uploadProgress = 0;
      uploadStatus = '';
    });

    // Start checking processing status
    _startProcessingStatusCheck(selectedMatch['id']);

    // Refresh the matches list
    _loadMatches();
  }
  
  // Show dialog when backend is unreachable
  Future<BackendUnreachableAction> _showBackendUnreachableDialog(String error) async {
    final result = await showDialog<BackendUnreachableAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Backend Unreachable'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Could not connect to the backend server:'),
            SizedBox(height: 8),
            Text(
              error,
              style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
            ),
            SizedBox(height: 16),
            Text('What would you like to do?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(BackendUnreachableAction.cancel),
            child: Text('Cancel Upload'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(BackendUnreachableAction.retry),
            child: Text('Retry'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(BackendUnreachableAction.useMock),
            child: Text('Use Testing Mode'),
          ),
        ],
      ),
    );
    
    return result ?? BackendUnreachableAction.cancel;
  }

  // Mock upload for testing when backend is not available
  Future<void> _performMockUpload(Map<String, dynamic> selectedMatch) async {
    setState(() {
      uploadStatus = 'Simulating upload (TESTING MODE)...';
    });
    
    // Calculate a realistic upload time based on file size
    final fileSize = kIsWeb 
        ? (videoBytes?.length ?? 0) 
        : (videoFile?.lengthSync() ?? 0);
    
    final fileSizeKB = fileSize / 1024;
    
    // Show file size in status
    setState(() {
      uploadStatus = 'Preparing to upload ${fileSizeKB.toStringAsFixed(0)} KB (TESTING MODE)...';
    });
    
    await Future.delayed(Duration(milliseconds: 500));
    
    // Simulate upload progress - slower for larger files
    final steps = 20;
    final baseDelay = 100; // ms
    final sizeDelay = (fileSizeKB / 1024).clamp(0.5, 5); // 0.5-5 seconds extra based on size
    
    for (int i = 1; i <= steps; i++) {
      // Simulate network fluctuations
      final randomFactor = 0.5 + (0.5 * i / steps) + (0.2 * (DateTime.now().millisecondsSinceEpoch % 10) / 10);
      final delayMs = (baseDelay * randomFactor * sizeDelay).toInt();
      
      await Future.delayed(Duration(milliseconds: delayMs));
      
      setState(() {
        uploadProgress = i / steps;
        uploadStatus = 'Uploading: ${(uploadProgress * 100).toStringAsFixed(0)}% (TESTING MODE)';
      });
    }
    
    setState(() {
      uploadStatus = 'Processing video (TESTING MODE)...';
    });
    
    // Simulate backend processing time
    final processingTime = 1 + (fileSizeKB / 1024).clamp(1, 3);
    await Future.delayed(Duration(seconds: processingTime.toInt()));
    
    // For mock uploads, we'll directly update the match status to 'completed'
    // This simulates the entire backend processing flow
    try {
      // Verify that the match document still exists
      final matchDoc = await _firestore.collection('matches').doc(selectedMatch['id']).get();
      if (!matchDoc.exists) {
        print('Warning: Match document no longer exists. Cannot update status.');
      } else {
        await _firestore.collection('matches').doc(selectedMatch['id']).update({
          'status': 'completed',
          'processing_started_at': FieldValue.serverTimestamp(),
          'processing_completed_at': FieldValue.serverTimestamp(),
          'is_mock_upload': true,
          'mock_file_size_kb': fileSizeKB,
          'processed_video_url': 'https://example.com/mock_processed_video.mp4',
          'performance_data': _generateMockPerformanceData(selectedMatch),
        });
        print('Successfully updated match status for mock upload');
      }
    } catch (e) {
      print('Error updating match status for mock upload: $e');
      // Continue even if the status update fails
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('TESTING MODE: Mock upload of ${fileSizeKB.toStringAsFixed(0)} KB completed successfully'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 4),
      ),
    );
    
    // Clear the selected video
    setState(() {
      videoFile = null;
      videoBytes = null;
      videoFileName = null;
      uploadProgress = 0;
      uploadStatus = '';
      isLoading = false;
    });
    
    // No need to check processing status for mock uploads since we directly set it to completed
    
    // Refresh the matches list
    _loadMatches();
  }
  
  // Generate mock performance data for testing
  Map<String, dynamic> _generateMockPerformanceData(Map<String, dynamic> match) {
    final performanceData = <String, dynamic>{};
    
    // Get athlete IDs from the match
    final athleteIds = List<String>.from(match['athletes'] ?? []);
    
    // Generate mock data for each athlete
    for (final athleteId in athleteIds) {
      performanceData[athleteId] = {
        'metrics': {
          'form_score': 0.7 + (Random().nextDouble() * 0.3),
          'balance': 0.6 + (Random().nextDouble() * 0.4),
          'symmetry': 0.7 + (Random().nextDouble() * 0.3),
          'smoothness': 0.6 + (Random().nextDouble() * 0.4),
        },
        'fitbit_data': {
          'heart_rate': [70 + Random().nextInt(30)],
          'steps': 1000 + Random().nextInt(5000),
          'calories': 200 + Random().nextInt(300),
        }
      };
    }
    
    return performanceData;
  }

  // Cancel the current upload
  Future<void> _cancelUpload() async {
    setState(() {
      isCancelling = true;
      uploadStatus = 'Cancelling upload...';
    });
    
    // Wait a moment to simulate cancellation
    await Future.delayed(Duration(milliseconds: 500));
    
    // Update the match status if needed
    if (selectedMatchId != null) {
      try {
        // Verify that the match document still exists
        final matchDoc = await _firestore.collection('matches').doc(selectedMatchId!).get();
        if (!matchDoc.exists) {
          print('Warning: Match document no longer exists. Cannot update status for cancellation.');
        } else {
          await _firestore.collection('matches').doc(selectedMatchId!).update({
            'status': 'upload_cancelled',
            'cancelled_at': FieldValue.serverTimestamp(),
          });
          print('Successfully updated match status to cancelled');
        }
      } catch (e) {
        print('Error updating match status during cancellation: $e');
      }
    }
    
    // Reset the upload state
    setState(() {
      isLoading = false;
      isCancelling = false;
      uploadProgress = 0;
      uploadStatus = '';
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Upload cancelled'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // Refresh the match list and verify the selected match
  Future<bool> _verifySelectedMatch() async {
    try {
      // Reload the matches
      await _loadMatches();
      
      // Check if the selected match exists
      if (selectedMatchId == null) {
        print('No match selected after refresh');
        return false;
      }
      
      final matchExists = matches.any((match) => match['id'] == selectedMatchId);
      if (!matchExists) {
        print('Selected match no longer exists after refresh');
        return false;
      }
      
      // Verify that the document exists in Firestore
      final matchDoc = await _firestore.collection('matches').doc(selectedMatchId).get();
      if (!matchDoc.exists) {
        print('Match document does not exist in Firestore');
        return false;
      }
      
      return true;
    } catch (e) {
      print('Error verifying selected match: $e');
      return false;
    }
  }

  // Show error dialog when match document doesn't exist
  Future<void> _showMatchNotFoundDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Match Not Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('The selected match no longer exists in the database.'),
            SizedBox(height: 8),
            Text(
              'It may have been deleted or the ID is invalid.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 16),
            Text('Please select another match or create a new one.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _createSampleMatch();
            },
            child: Text('Create Sample Match'),
          ),
        ],
      ),
    );
    
    // Refresh the matches list
    await _loadMatches();
  }

  // Start checking processing status
  void _startProcessingStatusCheck(String matchId) {
    // Cancel any existing timer
    _stopProcessingStatusCheck();
    
    setState(() {
      isProcessing = true;
      processingStatus = 'Processing video...';
    });
    
    // Create a new timer to check status every 5 seconds
    processingStatusTimer = Timer.periodic(Duration(seconds: 5), (timer) {
      _checkProcessingStatus(matchId);
    });
    
    // Do an immediate check
    _checkProcessingStatus(matchId);
  }
  
  // Stop checking processing status
  void _stopProcessingStatusCheck() {
    processingStatusTimer?.cancel();
    processingStatusTimer = null;
    
    if (mounted) {  // Add this check to prevent setState after dispose
    setState(() {
      isProcessing = false;
      processingStatus = '';
    });
    }
  }
  
  // Check processing status
  Future<void> _checkProcessingStatus(String matchId) async {
    // First check if the widget is still mounted before proceeding
    if (!mounted) {
      // Cancel the timer if widget is no longer mounted
      _stopProcessingStatusCheck();
      return;
    }
    
    try {
      final matchService = MatchService();
      final statusData = await matchService.checkProcessingStatus(matchId);
      
      // Check again if still mounted after the async operation
      if (!mounted) {
        return;
      }
      
      print('Processing status: ${statusData['status']}');
      
      setState(() {
        processingStatus = 'Processing video: ${statusData['status']}';
      });
      
      // If processing is complete, stop checking and navigate to summary tab
      if (statusData['status'] == 'completed') {
        _stopProcessingStatusCheck();
        
        // Show success message only if we haven't shown it before for this match
        if (!_processedMatchIds.contains(matchId)) {
          _processedMatchIds.add(matchId); // Mark this match as processed
          
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video processing completed successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
        }
        
        // Navigate to summary tab
        _tabController.animateTo(2); // Index 2 is the summary tab
        
        // Refresh matches to get the latest data
        await _loadMatches();
      }
      // If processing failed, stop checking and show error
      else if (statusData['status'] == 'error' || statusData['status'] == 'processing_failed') {
        _stopProcessingStatusCheck();
        
        // Show error message only if we haven't shown it before for this match
        if (!_processedMatchIds.contains(matchId)) {
          _processedMatchIds.add(matchId); // Mark this match as processed (even though it failed)
          
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Video processing failed: ${statusData['error_message'] ?? 'Unknown error'}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 10),
            action: SnackBarAction(
              label: 'RETRY',
              onPressed: () {
                if (selectedMatchId != null) {
                  _uploadDirectlyToBackend();
                }
              },
            ),
          ),
        );
        }
      }
    } catch (e) {
      print('Error checking processing status: $e');
      // Don't stop the timer on error, just continue checking
      // But make sure we're not trying to update state if widget is disposed
      if (!mounted) {
        _stopProcessingStatusCheck();
      }
    }
  }

  @override
  void dispose() {
    print('Disposing MatchManagementScreen');
    // Make sure to cancel the timer before disposing the widget
    if (processingStatusTimer != null) {
      processingStatusTimer!.cancel();
      processingStatusTimer = null;
    }
    _tabController.dispose();
    super.dispose();
  }
}

class DashedBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double gap;
  final Radius radius;

  const DashedBorder({
    Key? key,
    required this.child,
    required this.color,
    this.strokeWidth = 1.0,
    this.gap = 5.0,
    this.radius = const Radius.circular(0),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(radius),
      ),
      child: CustomPaint(
        painter: DashedBorderPainter(
          color: color,
          strokeWidth: strokeWidth,
          gap: gap,
          radius: radius,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.all(radius),
          child: Container(
            child: child,
          ),
        ),
      ),
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final Radius radius;

  DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.gap,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    // Top line
    _drawDashedLine(
      canvas,
      paint,
      Offset(radius.x, 0),
      Offset(size.width - radius.x, 0),
    );

    // Right line
    _drawDashedLine(
      canvas,
      paint,
      Offset(size.width, radius.y),
      Offset(size.width, size.height - radius.y),
    );

    // Bottom line
    _drawDashedLine(
      canvas,
      paint,
      Offset(size.width - radius.x, size.height),
      Offset(radius.x, size.height),
    );

    // Left line
    _drawDashedLine(
      canvas,
      paint,
      Offset(0, size.height - radius.y),
      Offset(0, radius.y),
    );

    // Draw the rounded corners
    if (radius.x > 0 && radius.y > 0) {
      // Top-right corner
      _drawDashedArc(
        canvas,
        paint,
        Rect.fromLTWH(
          size.width - radius.x * 2,
          0,
          radius.x * 2,
          radius.y * 2,
        ),
        0,
        90,
      );

      // Bottom-right corner
      _drawDashedArc(
        canvas,
        paint,
        Rect.fromLTWH(
          size.width - radius.x * 2,
          size.height - radius.y * 2,
          radius.x * 2,
          radius.y * 2,
        ),
        90,
        90,
      );

      // Bottom-left corner
      _drawDashedArc(
        canvas,
        paint,
        Rect.fromLTWH(
          0,
          size.height - radius.y * 2,
          radius.x * 2,
          radius.y * 2,
        ),
        180,
        90,
      );

      // Top-left corner
      _drawDashedArc(
        canvas,
        paint,
        Rect.fromLTWH(
          0,
          0,
          radius.x * 2,
          radius.y * 2,
        ),
        270,
        90,
      );
    }
  }

  void _drawDashedLine(Canvas canvas, Paint paint, Offset start, Offset end) {
    final double distance = (end - start).distance;
    final double dashLength = gap * 2;
    final int dashCount = (distance / dashLength).floor();
    final double dx = (end.dx - start.dx) / distance;
    final double dy = (end.dy - start.dy) / distance;

    bool draw = true;
    double currentDistance = 0;
    Offset currentStart = start;

    while (currentDistance < distance) {
      final double segmentLength = draw ? gap * 2 : gap;
      currentDistance += segmentLength;

      if (currentDistance > distance) {
        currentDistance = distance;
      }

      final Offset currentEnd = Offset(
        start.dx + dx * currentDistance,
        start.dy + dy * currentDistance,
      );

      if (draw) {
        canvas.drawLine(currentStart, currentEnd, paint);
      }

      currentStart = currentEnd;
      draw = !draw;
    }
  }

  void _drawDashedArc(
    Canvas canvas,
    Paint paint,
    Rect rect,
    double startAngle,
    double sweepAngle,
  ) {
    final double arcLength = rect.width * sweepAngle * 3.14159 / 180;
    final double dashLength = gap * 2;
    final int dashCount = (arcLength / dashLength).floor();
    final double anglePerDash = sweepAngle / dashCount;

    bool draw = true;
    double currentAngle = startAngle;

    for (int i = 0; i < dashCount; i++) {
      final double segmentAngle = draw ? anglePerDash : anglePerDash / 2;
      
      if (draw) {
        canvas.drawArc(
          rect,
          currentAngle * 3.14159 / 180,
          segmentAngle * 3.14159 / 180,
          false,
          paint,
        );
      }

      currentAngle += segmentAngle;
      draw = !draw;
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.radius != radius;
  }
}

// Backend status class
class BackendStatus {
  final bool isReachable;
  final String url;
  final String error;
  
  BackendStatus({
    required this.isReachable,
    this.url = '',
    this.error = '',
  });
}

// Backend unreachable action enum
enum BackendUnreachableAction {
  cancel,
  retry,
  useMock,
}

// Match processing action enum
enum MatchProcessingAction {
  cancel,
  continue_,
} 