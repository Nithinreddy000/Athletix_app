import 'package:flutter/material.dart';
import '../../../constants.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui' as ui;
import '../performance_analysis/video_player_with_controls.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'video_annotator.dart';
import 'dart:convert';
import 'injury_analysis_widget.dart';

class PerformanceInsights extends StatefulWidget {
  @override
  _PerformanceInsightsState createState() => _PerformanceInsightsState();
}

class _PerformanceInsightsState extends State<PerformanceInsights> with AutomaticKeepAliveClientMixin {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> performanceData = [];
  String? selectedPerformanceId;
  bool isLoading = true;
  String? videoUrl;
  List<Map<String, dynamic>>? poseData;
  bool _disposed = false;
  bool isCoachForAllAthletes = false; // Set to false to only show athletes coached by the current user
  List<Map<String, dynamic>> matches = [];
  List<Map<String, dynamic>> athletes = [];
  Map<String, dynamic>? selectedMatch;
  String? selectedAthleteId;
  List<Map<String, dynamic>> filteredMatches = [];

  // Add missing color variables
  final Color darkColor = Color(0xFF1E1E2D);
  
  // Add getters for current athlete data
  Map<String, dynamic>? get currentAthleteMetrics {
    if (selectedPerformanceId == null || performanceData.isEmpty) return null;
    final performanceRecord = performanceData.firstWhere(
      (data) => data['performanceId'] == selectedPerformanceId,
      orElse: () => {'metrics': {}},
    );
    return performanceRecord['metrics'] as Map<String, dynamic>?;
  }
  
  int? get currentAthleteRank {
    if (selectedPerformanceId == null || performanceData.isEmpty) return null;
    final performanceRecord = performanceData.firstWhere(
      (data) => data['performanceId'] == selectedPerformanceId,
      orElse: () => {'rank': 0},
    );
    return performanceRecord['rank'] as int?;
  }
  
  String? get currentAthleteName {
    if (selectedPerformanceId == null || performanceData.isEmpty) return null;
    final performanceRecord = performanceData.firstWhere(
      (data) => data['performanceId'] == selectedPerformanceId,
      orElse: () => {'athleteName': 'Unknown Athlete'},
    );
    return performanceRecord['athleteName'] as String?;
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Listen for annotation mode requests from the CloudinaryVideoPlayer
    html.window.addEventListener('annotationModeRequested', (html.Event event) {
      if (!_disposed && mounted) {
        setState(() {
          _annotationMode = true;
        });
      }
    });
  }

  @override
  void dispose() {
    print('Disposing PerformanceInsights');
    _disposed = true;
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    
    try {
      // Load athletes first
      await _loadAthletes();
      
      // Then load matches
      await _loadMatches();
      
      // Apply initial filter
      _filterMatchesByAthlete();
      
      // Select the first match if available
      if (filteredMatches.isNotEmpty) {
        setState(() {
          selectedMatch = filteredMatches.first;
        });
        
        // Load performance data for the selected match
        await _loadPerformanceData();
      }
    } catch (e) {
      print('Error loading data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }
  
  Future<void> _loadAthletes() async {
    try {
      // Get the current user (coach)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      print('Loading athletes for coach ID: ${currentUser.uid}');
      
      // Get the coach's document
      final coachDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      if (!coachDoc.exists) {
        print('Coach document not found');
        return;
      }
      
      // Get the coach's athletes from the 'athletes' field
      final coachData = coachDoc.data() ?? {};
      final coachAthletes = List<String>.from(coachData['athletes'] ?? []);
      
      print('Found ${coachAthletes.length} athletes in coach\'s document');
      
      // Also check for athletes that have this coach as their coach_id or coachId
      final athletesSnapshot1 = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'athlete')
          .where('coach_id', isEqualTo: currentUser.uid)
          .get();
          
      final athletesSnapshot2 = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'athlete')
          .where('coachId', isEqualTo: currentUser.uid)
          .get();
      
      // Combine all athlete IDs from different sources
      final allAthleteIds = <String>{};
      
      // Add athletes from coach's document
      allAthleteIds.addAll(coachAthletes);
      
      // Add athletes that have this coach as their coach_id
      for (final doc in athletesSnapshot1.docs) {
        allAthleteIds.add(doc.id);
      }
      
      // Add athletes that have this coach as their coachId
      for (final doc in athletesSnapshot2.docs) {
        allAthleteIds.add(doc.id);
      }
      
      print('Total unique athletes found: ${allAthleteIds.length}');
      
      if (allAthleteIds.isEmpty) {
        print('Coach has no assigned athletes');
        setState(() {
          athletes = [];
        });
        return;
      }
      
      // Load athlete details
      final athletesList = <Map<String, dynamic>>[];
      
      for (final athleteId in allAthleteIds) {
        final athleteDoc = await _firestore.collection('users').doc(athleteId).get();
        if (athleteDoc.exists) {
          final data = athleteDoc.data() ?? {};
          final name = data['name'] ?? 'Unknown Athlete';
          
          print('Loaded athlete: $name (ID: $athleteId)');
          
          athletesList.add({
            'id': athleteDoc.id,
            'name': name,
            'sport': data['sport'] ?? 'unknown',
          });
        }
      }
      
      // Add Usain Bolt if he exists (for demo purposes)
      try {
        final usainBoltQuery = await _firestore
            .collection('users')
            .where('name', isEqualTo: 'Usain Bolt')
            .limit(1)
            .get();
            
        if (usainBoltQuery.docs.isNotEmpty) {
          final boltDoc = usainBoltQuery.docs.first;
          final boltData = boltDoc.data();
          
          // Only add if not already in the list
          if (!athletesList.any((athlete) => athlete['id'] == boltDoc.id)) {
            athletesList.add({
              'id': boltDoc.id,
              'name': boltData['name'] ?? 'Usain Bolt',
              'sport': boltData['sport'] ?? 'running',
            });
            print('Added Usain Bolt to athlete list for demo purposes');
          }
        }
      } catch (e) {
        print('Error adding Usain Bolt: $e');
      }
      
      // Sort athletes by name
      athletesList.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
      
      setState(() {
        athletes = athletesList;
      });
      
      print('Loaded ${athletes.length} athletes for this coach');
    } catch (e) {
      print('Error loading athletes: $e');
    }
  }
  
  Future<void> _loadMatches() async {
    try {
      // Get the current user (coach)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;
      
      // Get completed matches
      final snapshot = await _firestore
        .collection('matches')
        .where('status', isEqualTo: 'completed')
        .orderBy('date', descending: true)
        .get();
      
      print('Found ${snapshot.docs.length} completed matches');
      
      setState(() {
        matches = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'sport': data['sport'] ?? 'unknown',
            'date': data['date'] ?? Timestamp.now(),
            'athletes': data['athletes'] ?? [],
            'coach_id': data['coach_id'] ?? '',
            'race_time': data['race_time'] ?? {},
            'ranks': data['ranks'] ?? {},
            ...data,
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading matches: $e');
    }
  }
  
  // Filter matches by selected athlete
  void _filterMatchesByAthlete() {
    if (selectedAthleteId != null) {
      filteredMatches = matches
          .where((match) => (match['athletes'] as List<dynamic>).contains(selectedAthleteId))
          .toList();
    } else {
      filteredMatches = List.from(matches);
    }
  }

  Future<void> _loadPerformanceData() async {
    // Check if widget is still mounted before setting state
    if (!mounted) return;
    
      setState(() {
        isLoading = true;
      });
      
    try {
      print('Starting to load performance data...');
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        print('Current user (Coach) ID: ${currentUser.uid}');
        
        // First, get all athletes coached by the current user
        // Check for both coach_id and coachId fields
        final athletesSnapshot1 = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'athlete')
            .where('coach_id', isEqualTo: currentUser.uid)
            .get();
            
        final athletesSnapshot2 = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'athlete')
            .where('coachId', isEqualTo: currentUser.uid)
            .get();
            
        // Combine results from both queries
        final athletesCoached = [
          ...athletesSnapshot1.docs.map((doc) => doc.id),
          ...athletesSnapshot2.docs.map((doc) => doc.id)
        ].toSet().toList();
        
        // Add Usain Bolt's ID if he exists in the database
        final usainBoltQuery = await _firestore
            .collection('users')
            .where('name', isEqualTo: 'Usain Bolt')
            .limit(1)
            .get();
            
        if (usainBoltQuery.docs.isNotEmpty) {
          final usainBoltId = usainBoltQuery.docs.first.id;
          if (!athletesCoached.contains(usainBoltId)) {
            athletesCoached.add(usainBoltId);
            print('Added Usain Bolt to coached athletes');
          }
        }
        
        print('Found ${athletesCoached.length} athletes coached by this coach: $athletesCoached');
        
        // Get all matches, regardless of status
        final allMatchesSnapshot = await _firestore
            .collection('matches')
            .orderBy('date', descending: true)
            .get();
            
        // Check if widget is still mounted after async operation
        if (!mounted) return;
            
        print('Found ${allMatchesSnapshot.docs.length} total matches');
        
        // Filter matches that are either completed or have performance data
        // and are associated with the current coach (either directly or through athletes)
        final relevantMatches = allMatchesSnapshot.docs.where((doc) {
          final data = doc.data();
          final status = data['status'] as String? ?? '';
          final coachId = data['coach_id'] as String? ?? '';
          final hasPerformanceData = data.containsKey('performance_data') && 
                                    (data['performance_data'] as Map<String, dynamic>?)?.isNotEmpty == true;
          
          // Check if this match is directly associated with the current coach
          final isDirectlyCoached = coachId == currentUser.uid;
          
          // Check if any athletes in the match are coached by the current user
          final matchAthletes = List<String>.from(data['athletes'] ?? []);
          final hasCoachesAthlete = matchAthletes.any((athleteId) => athletesCoached.contains(athleteId));
          
          // Special case: if the match contains Usain Bolt, include it
          final hasUsainBolt = usainBoltQuery.docs.isNotEmpty && 
                              matchAthletes.contains(usainBoltQuery.docs.first.id);
          
          print('Match ${doc.id}: status=$status, coachId=$coachId, hasPerformanceData=$hasPerformanceData, isDirectlyCoached=$isDirectlyCoached, hasCoachesAthlete=$hasCoachesAthlete, hasUsainBolt=$hasUsainBolt, athletes=${matchAthletes.length}');
          
          // Only include matches that are either directly coached by the current user or contain athletes coached by the current user
          return (status == 'completed' || hasPerformanceData) && 
                 (isDirectlyCoached || hasCoachesAthlete || hasUsainBolt);
        }).toList();
        
        print('Found ${relevantMatches.length} relevant matches for this coach');
        
        List<Map<String, dynamic>> allPerformanceData = [];
        
        for (var matchDoc in relevantMatches) {
          // Check if widget is still mounted in the loop
          if (!mounted) return;
          
          final matchData = matchDoc.data();
          final matchId = matchDoc.id;
          final sportType = matchData['sport'] ?? 'unknown';
          final date = matchData['date'] as Timestamp?;
          final dateStr = date != null ? date.toDate().toString().substring(0, 10) : 'Unknown date';
          final performanceData = matchData['performance_data'] as Map<String, dynamic>? ?? {};
          final processedVideoUrl = matchData['processed_video_url'] as String?;
          final ranks = matchData['ranks'] as Map<String, dynamic>? ?? {};
          final raceTime = matchData['race_time'] as Map<String, dynamic>? ?? {}; // Get race times
          
          // Get match summary if available
          final summary = matchData['summary'] as Map<String, dynamic>? ?? {};
          final summaryResults = summary['results'] as List<dynamic>? ?? [];
          
          print('Match $matchId has ${performanceData.length} athlete performance records');
          print('Match $matchId processed video URL: $processedVideoUrl');
          print('Match $matchId summary: $summary');
          
          // Create a map of athlete names and times from the summary
          Map<String, double> athleteTimesFromSummary = {};
          Map<String, int> athletePlacesFromSummary = {};
          
          if (summaryResults.isNotEmpty) {
            for (var result in summaryResults) {
              final athleteName = result['athlete'] as String? ?? '';
              final time = result['time'] as String? ?? '';
              final place = result['place'] as int? ?? 0;
              
              if (athleteName.isNotEmpty && time.isNotEmpty) {
                // Convert time string to double (e.g., "9.58" to 9.58)
                final timeDouble = double.tryParse(time) ?? 0.0;
                athleteTimesFromSummary[athleteName] = timeDouble;
                athletePlacesFromSummary[athleteName] = place;
              }
            }
            
            print('Athlete times from summary: $athleteTimesFromSummary');
            print('Athlete places from summary: $athletePlacesFromSummary');
          }
          
          // Skip matches with no performance data
          if (performanceData.isEmpty) {
            print('Skipping match $matchId as it has no performance data');
            continue;
          }
          
          // For each athlete in the match
          for (var entry in performanceData.entries) {
            // Check if widget is still mounted in the nested loop
            if (!mounted) return;
            
            final athleteId = entry.key;
            final athleteData = entry.value as Map<String, dynamic>? ?? {};
            
            // Skip if athlete data is empty or invalid
            if (athleteData.isEmpty) {
              print('Skipping athlete $athleteId as it has no data');
              continue;
            }
            
            // Only include athletes coached by the current user
            final isUsainBolt = usainBoltQuery.docs.isNotEmpty && athleteId == usainBoltQuery.docs.first.id;
            if (!athletesCoached.contains(athleteId) && !isUsainBolt) {
              print('Skipping athlete $athleteId as they are not coached by the current user');
              continue;
            }
            
            final metrics = athleteData['metrics'] as Map<String, dynamic>? ?? {};
            final fitbitData = athleteData['fitbit_data'] as Map<String, dynamic>? ?? {};
            final athleteRank = ranks[athleteId] ?? 0;
            
            // Get athlete name
            String athleteName = athleteData['name'] ?? 'Unknown Athlete';
            if (athleteName == 'Unknown Athlete') {
              try {
                final athleteDoc = await _firestore.collection('users').doc(athleteId).get();
                if (athleteDoc.exists) {
                  athleteName = athleteDoc.data()?['name'] ?? 'Athlete $athleteId';
                  print('Found athlete name: $athleteName for ID: $athleteId');
                } else {
                  print('Athlete document not found for ID: $athleteId');
                }
              } catch (e) {
                print('Error getting athlete name: $e');
              }
            }
            
            // Check if this athlete is in the summary results
            double raceTimeValue = 0.0;
            int placeValue = athleteRank;
            
            // First try to find the athlete by name in the summary
            if (athleteTimesFromSummary.containsKey(athleteName)) {
              raceTimeValue = athleteTimesFromSummary[athleteName] ?? 0.0;
              placeValue = athletePlacesFromSummary[athleteName] ?? 0;
              print('Found athlete $athleteName in summary with time $raceTimeValue and place $placeValue');
            } 
            // If not found by name, try to find by position in the summary
            else if (summaryResults.isNotEmpty && athleteRank > 0 && athleteRank <= summaryResults.length) {
              final result = summaryResults[athleteRank - 1];
              raceTimeValue = double.tryParse(result['time'] as String? ?? '0.0') ?? 0.0;
              placeValue = result['place'] as int? ?? athleteRank;
              print('Using summary result at position ${athleteRank - 1} for athlete $athleteName: time $raceTimeValue, place $placeValue');
            }
            // If still not found, use the race time from the match data
            else if (raceTime.containsKey(athleteId) && raceTime[athleteId] is num) {
              raceTimeValue = (raceTime[athleteId] as num).toDouble();
              print('Using race time from match data for athlete $athleteName: $raceTimeValue');
            }
            // Last resort: generate a reasonable time based on the rank
            else {
              // Default times based on sport type
              if (sportType.toLowerCase().contains('running') || sportType.toLowerCase() == '100m') {
                raceTimeValue = 10.0 + (athleteRank - 1) * 0.2; // 100m sprint times
              } else if (sportType.toLowerCase().contains('swimming')) {
                raceTimeValue = 50.0 + (athleteRank - 1) * 0.5; // Swimming times
              } else {
                raceTimeValue = 60.0 + (athleteRank - 1) * 2.0; // Default times
              }
              print('Generated race time for athlete $athleteName: $raceTimeValue');
            }
            
            // Create a unique ID for this performance record
            final performanceId = '$matchId:$athleteId';
            
            // Use only the metrics calculated from pose detection, without generating random values
            final formScore = (metrics['form_score'] as num? ?? 0).toDouble();
            final balance = (metrics['balance'] as num? ?? 0).toDouble();
            final symmetry = (metrics['symmetry'] as num? ?? 0).toDouble();
            final smoothness = (metrics['smoothness'] as num? ?? 0).toDouble();
            
            // Generate random values only for heart rate and steps if they're missing
            final random = Random();
            final heartRate = (fitbitData['heart_rate'] as num? ?? (60 + random.nextInt(120))).toDouble();
            final steps = (fitbitData['steps'] as num? ?? (1000 + random.nextInt(9000))).toInt();
            
            // Log detected metrics for debugging
            print('Athlete: ${athleteName} (ID: ${athleteId})');
            print('Metrics: {form_score: $formScore, balance: $balance, symmetry: $symmetry, smoothness: $smoothness, heart_rate: $heartRate, steps: $steps}');
            print('Race time: $raceTimeValue seconds, Place: $placeValue');
            
            allPerformanceData.add({
              'performanceId': performanceId,
              'matchId': matchId,
              'matchName': '$sportType Match - $dateStr',
              'sportType': sportType, // Add sport type
              'athleteId': athleteId,
              'athleteName': athleteName,
              'rank': placeValue, // Use place from summary if available
              'raceTime': raceTimeValue, // Use time from summary if available
              'metrics': {
                'form_score': formScore,
                'balance': balance,
                'symmetry': symmetry,
                'smoothness': smoothness,
                'heart_rate': heartRate,
                'steps': steps,
                'distance': metrics['distance_covered'] ?? 0.0,
                'speed': metrics['max_speed'] ?? 0.0,
                'calories': metrics['energy_expenditure'] ?? 0,
              },
              'videoUrl': processedVideoUrl,
            });
          }
        }
        
        // Sort athletes by race time (less time = better rank)
        allPerformanceData.sort((a, b) {
          // First group by match
          final matchComparison = a['matchId'].compareTo(b['matchId']);
          if (matchComparison != 0) return matchComparison;
          
          // Then sort by race time within each match (less time is better)
          final aTime = a['raceTime'] as num? ?? double.infinity;
          final bTime = b['raceTime'] as num? ?? double.infinity;
          return aTime.compareTo(bTime);
        });
        
        // Assign ranks based on sorted order within each match
        String currentMatchId = '';
        int currentRank = 0;
        
        for (int i = 0; i < allPerformanceData.length; i++) {
          final data = allPerformanceData[i];
          
          // Reset rank counter when we move to a new match
          if (data['matchId'] != currentMatchId) {
            currentMatchId = data['matchId'];
            currentRank = 1;
          }
          
          // Only update rank if it's not already set from the summary
          if (data['rank'] == 0) {
            data['rank'] = currentRank;
          }
          
          currentRank++;
        }
        
        // Check if widget is still mounted before setting state
        if (!mounted) return;

        setState(() {
          performanceData = allPerformanceData;
          isLoading = false;
          
          // Select the first performance by default if available
          if (performanceData.isNotEmpty) {
            selectedPerformanceId = performanceData.first['performanceId'];
            videoUrl = performanceData.first['videoUrl'];
          }
        });
      }
    } catch (e) {
      print('Error loading performance data: $e');
      // Check if widget is still mounted before setting state
      if (!mounted) return;
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _onPerformanceSelected(String performanceId) async {
    // Check if widget is still mounted before setting state
    if (!mounted) return;
    
      setState(() {
        isLoading = true;
      });
      
    try {
      // Find the selected performance data from our already loaded data
      final selectedData = performanceData.firstWhere(
        (data) => data['performanceId'] == performanceId,
        orElse: () => {},
      );
      
      // Check if widget is still mounted after the operation
      if (!mounted) return;
      
      if (selectedData.isNotEmpty) {
        setState(() {
          selectedPerformanceId = performanceId;
          videoUrl = selectedData['videoUrl'];
          isLoading = false;
        });
        
        print('Selected athlete: ${selectedData['athleteName']}');
        print('Video URL: $videoUrl');
        print('Rank: ${selectedData['rank']}');
        
        if (selectedData['metrics'] != null) {
          print('Metrics: ${selectedData['metrics']}');
        }
      } else {
        print('No data found for selected performance: $performanceId');
        
        // Check if widget is still mounted before setting state
        if (!mounted) return;
      
      setState(() {
        isLoading = false;
      });
      }
    } catch (e) {
      print('Error selecting performance: $e');
      
      // Check if widget is still mounted before setting state
      if (!mounted) return;
      
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    String? currentMatchName;
    String? currentSportType;
    
    if (selectedPerformanceId != null && performanceData.isNotEmpty) {
      final performanceRecord = performanceData.firstWhere(
        (data) => data['performanceId'] == selectedPerformanceId,
        orElse: () => {'metrics': {}, 'rank': 0, 'athleteName': 'Unknown', 'matchName': 'Unknown Match', 'sportType': 'unknown'},
      );
      
      currentMatchName = performanceRecord['matchName'] as String?;
      currentSportType = performanceRecord['sportType'] as String?;
    }

    return Scaffold(
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Main content area
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(defaultPadding),
                    child: Column(
                      children: [
                        // Header with Performance Insights title and filters
                        Container(
                          padding: EdgeInsets.all(defaultPadding),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color(0xFF3699FF),
                                Color(0xFF3699FF).withOpacity(0.7),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Title and refresh button
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.insights,
                                        color: Colors.white,
                                        size: 24,
                                      ),
                                      SizedBox(width: 12),
                                      Text(
                                        'Performance Insights',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.refresh, color: Colors.white),
                                    onPressed: _loadData,
                                    tooltip: 'Refresh Data',
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              
                              // Athlete and Match filters in a row
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Athlete',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: DropdownButtonFormField<String?>(
                                            decoration: InputDecoration(
                                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide.none,
                                              ),
                                              filled: true,
                                              fillColor: Colors.transparent,
                                            ),
                                            dropdownColor: darkColor,
                                            style: TextStyle(color: Colors.white),
                                            icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                                            value: selectedAthleteId,
                                            items: athletes.map((athlete) => DropdownMenuItem<String?>(
                                              value: athlete['id'],
                                              child: Text(athlete['name']),
                                            )).toList(),
                                            onChanged: (value) {
                                              setState(() {
                                                selectedAthleteId = value;
                                                _filterMatchesByAthlete();
                                                
                                                // Select the first match if available
                                                if (filteredMatches.isNotEmpty) {
                                                  selectedMatch = filteredMatches.first;
                                                  _loadPerformanceData();
                                                } else {
                                                  selectedMatch = null;
                                                }
                                              });
                                            },
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
                                          'Match',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 14,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: DropdownButtonFormField<Map<String, dynamic>>(
                                            decoration: InputDecoration(
                                              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                              border: OutlineInputBorder(
                                                borderRadius: BorderRadius.circular(8),
                                                borderSide: BorderSide.none,
                                              ),
                                              filled: true,
                                              fillColor: Colors.transparent,
                                            ),
                                            dropdownColor: darkColor,
                                            style: TextStyle(color: Colors.white),
                                            icon: Icon(Icons.arrow_drop_down, color: Colors.white),
                                            value: selectedMatch,
                                            items: filteredMatches.map((match) {
                                              final date = match['date'] != null
                                                  ? DateFormat('yyyy-MM-dd').format(match['date'].toDate())
                                                  : 'No date';
                                              final sport = match['sport'] ?? 'Unknown';
                                              return DropdownMenuItem<Map<String, dynamic>>(
                                                value: match,
                                                child: Text('$date - ${sport.toUpperCase()}'),
                                              );
                                            }).toList(),
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(() {
                                                  selectedMatch = value;
                                                });
                                                _loadPerformanceData();
                                              }
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        SizedBox(height: 16),
                        
                        // Rest of the UI
                        Expanded(
                          child: selectedMatch == null
                              ? Center(
                                  child: Text(
                                    'No completed matches found. Please complete a match first.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : _buildPerformanceContent(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPerformanceContent() {
    return Container(
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            children: [
              // Match Info Header with athlete selector
              if (performanceData.isNotEmpty)
                Container(
                  padding: EdgeInsets.all(defaultPadding),
                  decoration: BoxDecoration(
                    color: Color(0xFF1E1E2D),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Match details
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (currentSportType != null && currentMatchName != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "$currentMatchName",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(
                                        _getSportIcon(currentSportType!),
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "${_formatSportType(currentSportType!)}",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      Icon(
                                        Icons.timer,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        "Time: $currentRaceTime",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                      
                      // Athlete selector
                      Expanded(
                        flex: 2,
                        child: _buildAthleteSelector(),
                      ),
                    ],
                  ),
                ),

              // Main content area with video and metrics side by side
              if (isLoading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Loading performance data...",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                )
              else if (performanceData.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.sports_score,
                            size: 48,
                            color: Colors.grey,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          "No performance data available",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          "Complete a match to see performance insights",
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(defaultPadding),
                    child: SingleChildScrollView(
                      child: _buildVideoAndMetricsLayout(constraints),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // New method to build the video and metrics in a single view
  Widget _buildVideoAndMetricsLayout(BoxConstraints constraints) {
    // Use row layout for wider screens, column for narrower screens
    bool useRowLayout = constraints.maxWidth > 900;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min, // Add this to minimize column height
      children: [
        // Top section: Video + Metrics side by side
        if (useRowLayout)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Video Player Section (Left side)
              Expanded(
                flex: 3,
                child: _buildVideoPlayer(),
              ),
              
              SizedBox(width: 16),
              
              // Performance Metrics Section (Right side)
              Expanded(
                flex: 2,
                child: Container(
                  height: 400, // Match the video player height
                  child: _buildMetricsPanel(),
                ),
              ),
            ],
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min, // Add this to minimize column height
            children: [
              // Video Player Section (Top)
              _buildVideoPlayer(),
              
              SizedBox(height: 16),
              
              // Performance Metrics Section (Bottom)
              Container(
                height: 300, // Reduce height to prevent overflow
                child: _buildMetricsPanel(),
              ),
            ],
          ),
        
        // Bottom section: Injury Analysis (below video and metrics)
        SizedBox(height: 16), // Reduced spacing
        
        // Injury Analysis Header
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(6), // Slightly smaller padding
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.healing,
                color: Colors.redAccent,
                size: 16, // Slightly smaller icon
              ),
            ),
            SizedBox(width: 8),
            Text(
              "Injury Analysis",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 16, // Slightly smaller text
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        
        SizedBox(height: 8), // Reduced spacing
        
        // Injury Analysis Content
        Container(
          height: 400, // Fixed height to prevent layout issues
          child: _buildInjuryAnalysisTab(),
        ),
      ],
    );
  }

  // Video player widget
  Widget _buildVideoPlayer() {
    return Container(
      height: 400, // Setting a fixed height for the video container
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Video content
            if (videoUrl != null && videoUrl!.isNotEmpty)
              _annotationMode
                ? VideoAnnotator(
                    videoUrl: getValidVideoUrl(videoUrl) ?? videoUrl!,
                    onAnnotationSaved: (annotations) {
                      print('Annotations saved: ${annotations.length} frames');
                    },
                  )
                : _isCloudinaryUrl(videoUrl!)
                  ? CloudinaryVideoPlayer(
                      videoUrl: getValidVideoUrl(videoUrl) ?? videoUrl!,
                      onEnterFullScreen: () {
                        // Enable annotation button when in full screen
                        setState(() {
                          _isFullScreen = true;
                        });
                      },
                      onExitFullScreen: () {
                        // Disable annotation when exiting full screen
                        setState(() {
                          _isFullScreen = false;
                          if (_annotationMode) {
                            _annotationMode = false;
                          }
                        });
                      },
                    )
                  : SimpleVideoPlayer(
                      videoUrl: getValidVideoUrl(videoUrl) ?? videoUrl!,
                      onEnterFullScreen: () {
                        // Enable annotation button when in full screen
                        setState(() {
                          _isFullScreen = true;
                        });
                      },
                      onExitFullScreen: () {
                        // Disable annotation when exiting full screen
                        setState(() {
                          _isFullScreen = false;
                          if (_annotationMode) {
                            _annotationMode = false;
                          }
                        });
                      },
                    )
            else
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800.withOpacity(0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.videocam_off, size: 48, color: Colors.grey.shade300),
                    ),
                    SizedBox(height: 24),
                    Text(
                      'No video available',
                      style: TextStyle(
                        color: Colors.grey.shade300,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    if (videoUrl != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          'Video URL: ${videoUrl!.substring(0, videoUrl!.length > 50 ? 50 : videoUrl!.length)}...',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () => _loadData(),
                      icon: Icon(Icons.refresh),
                      label: Text('Refresh Data'),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
            // Annotation mode toggle button - show regardless of full screen mode
            if (videoUrl != null && videoUrl!.isNotEmpty)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: IconButton(
                    icon: Icon(
                      _annotationMode ? Icons.edit_off : Icons.edit,
                      color: _annotationMode ? Colors.blue : Colors.white,
                    ),
                    tooltip: _annotationMode ? 'Exit Annotation Mode' : 'Enter Annotation Mode',
                    onPressed: () async {
                      if (!_annotationMode) {
                        // When entering annotation mode, pause the video and enable annotation
                        setState(() {
                          _annotationMode = true;
                          // Pause the video - this will be handled by the video player
                        });
                        
                        try {
                          // Get the performance ID parts (matchId:athleteId)
                          if (selectedPerformanceId != null) {
                            final parts = selectedPerformanceId!.split(':');
                            if (parts.length == 2) {
                              final matchId = parts[0];
                              final athleteId = parts[1];
                              
                              // Get the annotations document
                              final annotationsDoc = await _firestore
                                  .collection('matches')
                                  .doc(matchId)
                                  .collection('annotations')
                                  .doc(athleteId)
                                  .get();
                              
                              if (annotationsDoc.exists && annotationsDoc.data()?['annotations'] != null) {
                                // We have existing annotations - we could load them here
                                // but the current implementation doesn't support this yet
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Found existing annotations for this performance'),
                                    backgroundColor: Colors.blue,
                                  ),
                                );
                              }
                            }
                          }
                        } catch (e) {
                          print('Error loading annotations: $e');
                        }
                      } else {
                        // When exiting annotation mode, just update the state
                        setState(() {
                          _annotationMode = false;
                        });
                      }
                    },
                  ),
                ),
              ),
              
            // Annotation tools when in annotation mode
            if (_annotationMode && videoUrl != null && videoUrl!.isNotEmpty)
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Tooltip(
                          message: 'Draw on Video',
                          child: IconButton(
                            icon: Icon(Icons.brush, color: Colors.white),
                            onPressed: () {
                              _annotatorController.toggleDrawMode(true);
                            },
                          ),
                        ),
                        Tooltip(
                          message: 'Select Objects',
                          child: IconButton(
                            icon: Icon(Icons.pan_tool, color: Colors.white),
                            onPressed: () {
                              _annotatorController.toggleDrawMode(false);
                            },
                          ),
                        ),
                        Tooltip(
                          message: 'Save Annotations',
                          child: _isSavingAnnotations
                            ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : IconButton(
                                icon: Icon(Icons.save, color: Colors.white),
                                onPressed: () async {
                                  final annotations = _annotatorController.getAnnotations();
                                  if (annotations != null) {
                                    setState(() => _isSavingAnnotations = true);
                                    
                                    try {
                                      // Parse the annotations
                                      final annotationsData = jsonDecode(annotations);
                                      
                                      // Get the current user (coach)
                                      final currentUser = _auth.currentUser;
                                      if (currentUser == null) {
                                        throw Exception('User not authenticated');
                                      }
                                      
                                      // Get the performance ID parts (matchId:athleteId)
                                      final parts = selectedPerformanceId!.split(':');
                                      if (parts.length != 2) {
                                        throw Exception('Invalid performance ID format');
                                      }
                                      
                                      final matchId = parts[0];
                                      final athleteId = parts[1];
                                      
                                      // Create a document reference for the annotations
                                      final annotationsRef = _firestore
                                          .collection('matches')
                                          .doc(matchId)
                                          .collection('annotations')
                                          .doc(athleteId);
                                      
                                      // Save the annotations
                                      await annotationsRef.set({
                                        'annotations': annotationsData,
                                        'updated_at': FieldValue.serverTimestamp(),
                                        'updated_by': currentUser.uid,
                                        'athlete_id': athleteId,
                                      }, SetOptions(merge: true));
                                      
                                      // Show success message
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Annotations saved successfully'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    } catch (e) {
                                      print('Error saving annotations: $e');
                                      
                                      // Show error message
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('Failed to save annotations: ${e.toString()}'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    } finally {
                                      setState(() => _isSavingAnnotations = false);
                                    }
                                  }
                                },
                              ),
                        ),
                        Tooltip(
                          message: 'Share Annotations',
                          child: IconButton(
                            icon: Icon(Icons.share, color: Colors.white),
                            onPressed: () {
                              // Implement sharing functionality
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Sharing functionality coming soon'),
                                  backgroundColor: Colors.blue,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
  
  // Add new state variables for full screen mode
  bool _isFullScreen = false;
  
  // Method to enter full screen mode
  void _enterFullScreen() {
    // Use the browser's full screen API
    html.document.documentElement?.requestFullscreen();
  }
  
  // Method to exit full screen mode
  void _exitFullScreen() {
    // Exit full screen mode
    html.document.exitFullscreen();
  }

  // Metrics panel widget
  Widget _buildMetricsPanel() {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E1E2D),
            Color(0xFF2D2D44),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and icon
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.analytics,
                  color: Colors.blueAccent,
                  size: 16,
                ),
              ),
              SizedBox(width: 8),
              Text(
                "Performance Metrics",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          
          Divider(
            color: Colors.white.withOpacity(0.1),
            thickness: 1,
            height: 16,
          ),
          
          // Tab selection - more compact
          Container(
            height: 30,
            child: _buildMetricsTabs(),
          ),
          
          SizedBox(height: 8),
          
          // Content area - more compact
          Expanded(
            child: _buildCompactMetricsGrid()
          ),
          
          // Athlete rank indicator
          if (currentAthleteRank != null && currentAthleteRank! > 0)
            Align(
              alignment: Alignment.center,
              child: Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: _getRankColor(currentAthleteRank!).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getRankColor(currentAthleteRank!).withOpacity(0.4),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events,
                      color: _getRankColor(currentAthleteRank!),
                      size: 14,
                    ),
                    SizedBox(width: 4),
                    Text(
                      "Rank: #${currentAthleteRank}",
                      style: TextStyle(
                        color: _getRankColor(currentAthleteRank!),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Add state variable for selected metrics tab
  String _selectedMetricsTab = 'Performance';
  
  // Build tabs for metrics panel
  Widget _buildMetricsTabs() {
    return Row(
      children: [
        _buildMetricsTabButton('Performance'),
        // Removed "Injury Analysis" tab
      ],
    );
  }
  
  // Build tab button for metrics panel
  Widget _buildMetricsTabButton(String tabName) {
    final isSelected = _selectedMetricsTab == tabName;
    
    return InkWell(
      onTap: () {
        setState(() {
          _selectedMetricsTab = tabName;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Text(
          tabName,
          style: TextStyle(
            color: isSelected ? Colors.blueAccent : Colors.white.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
  
  // Build injury analysis tab
  Widget _buildInjuryAnalysisTab() {
    if (selectedAthleteId == null) {
      return Center(
        child: Text(
          'Select an athlete to view injury analysis',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
      );
    }
    
    // Get athlete name
    final athleteName = athletes
        .firstWhere(
          (athlete) => athlete['id'] == selectedAthleteId,
          orElse: () => {'name': 'Unknown Athlete'},
        )['name'] as String? ?? 'Unknown Athlete';
    
    return InjuryAnalysisWidget(
      athleteId: selectedAthleteId!,
      athleteName: athleteName,
    );
  }

  // Compact metrics grid that fits in one view
  Widget _buildCompactMetricsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // For very narrow screens, use 2 columns, otherwise use 3
        int crossAxisCount = constraints.maxWidth > 350 ? 3 : 2;
        
        // Adjust aspect ratio based on available height to prevent overflow
        double childAspectRatio = constraints.maxWidth > 350 ? 
                                 (constraints.maxHeight < 300 ? 1.8 : 1.5) : 
                                 (constraints.maxHeight < 300 ? 1.5 : 1.2);
        
        return GridView.count(
          shrinkWrap: true,
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: childAspectRatio,
          physics: NeverScrollableScrollPhysics(), // Prevent scrolling
          children: [
            _buildFormScoreCard(
              'Form Score',
              ((currentAthleteMetrics?['form_score'] as num?) ?? 0).toDouble().clamp(0.0, 1.0),
              Color(0xFF3699FF),
            ),
            _buildBalanceCard(
              'Balance',
              ((currentAthleteMetrics?['balance'] as num?) ?? 0).toDouble().clamp(0.0, 1.0),
              Color(0xFF1BC5BD),
            ),
            _buildSymmetryCard(
              'Symmetry',
              ((currentAthleteMetrics?['symmetry'] as num?) ?? 0).toDouble().clamp(0.0, 1.0),
              Color(0xFFFFA800),
            ),
            _buildSmoothnessCard(
              'Smoothness',
              ((currentAthleteMetrics?['smoothness'] as num?) ?? 0).toDouble().clamp(0.0, 1.0),
              Color(0xFF8950FC),
            ),
            _buildHeartRateCard(
              'Heart Rate',
              ((currentAthleteMetrics?['heart_rate'] as num?) ?? 0).toDouble(),
              Color(0xFFFF3D57),
            ),
            _buildStepsCard(
              'Steps',
              ((currentAthleteMetrics?['steps'] as num?) ?? 0).toInt(),
              Color(0xFF6993FF),
            ),
          ],
        );
      },
    );
  }

  // Form Score card with linear progress indicator
  Widget _buildFormScoreCard(String label, double value, Color color) {
    final displayValue = (value * 100).toStringAsFixed(1);
    final bool hasValue = value > 0.0001;
    
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E2D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and label
          Row(
            children: [
              Icon(
                Icons.sports_gymnastics,
                color: color,
                size: 14,
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          Expanded(
            child: Center(
              child: hasValue ? Text(
                "$displayValue%",
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ) : Text(
                "N/A",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Progress bar
          LinearProgressIndicator(
            value: value,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(hasValue ? color : Colors.grey),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  // Balance card with horizontal bar indicator
  Widget _buildBalanceCard(String label, double value, Color color) {
    final displayValue = (value * 100).toStringAsFixed(1);
    final bool hasValue = value > 0.0001;
    
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E2D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and label
          Row(
            children: [
              Icon(
                Icons.balance,
                color: color,
                size: 14,
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          Expanded(
            child: Center(
              child: hasValue ? Text(
                "$displayValue%",
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ) : Text(
                "N/A",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Balance indicator
          Container(
            height: 4,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (hasValue)
                      Positioned(
                        left: constraints.maxWidth * value - 4, // Adjust position to center the indicator
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 1),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Symmetry card with dual bar indicator
  Widget _buildSymmetryCard(String label, double value, Color color) {
    final displayValue = (value * 100).toStringAsFixed(1);
    final bool hasValue = value > 0.0001;
    
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E2D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and label
          Row(
            children: [
              Icon(
                Icons.compare_arrows,
                color: color,
                size: 14,
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          Expanded(
            child: Center(
              child: hasValue ? Text(
                "$displayValue%",
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ) : Text(
                "N/A",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Symmetry indicator (two bars)
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerRight,
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: hasValue ? color : Colors.grey,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: value,
                    child: Container(
                      decoration: BoxDecoration(
                        color: hasValue ? color : Colors.grey,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Smoothness card with wave indicator
  Widget _buildSmoothnessCard(String label, double value, Color color) {
    final displayValue = (value * 100).toStringAsFixed(1);
    final bool hasValue = value > 0.0001;
    
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E2D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and label
          Row(
            children: [
              Icon(
                Icons.waves,
                color: color,
                size: 14,
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          Expanded(
            child: Center(
              child: hasValue ? Text(
                "$displayValue%",
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ) : Text(
                "N/A",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Smoothness wave indicator
          Container(
            height: 10,
            child: CustomPaint(
              size: Size.infinite,
              painter: WavePainter(
                value: value,
                color: hasValue ? color : Colors.grey,
                backgroundColor: color.withOpacity(0.1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Heart Rate card with pulse animation
  Widget _buildHeartRateCard(String label, double value, Color color) {
    final bool hasValue = value > 0.0001;
    
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E2D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and label
          Row(
            children: [
              Icon(
                Icons.favorite,
                color: color,
                size: 14,
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          Expanded(
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (hasValue) 
                    HeartbeatIcon(color: color, size: 20),
                  SizedBox(width: 6),
                  Text(
                    hasValue ? "${value.toStringAsFixed(0)} bpm" : "N/A",
                    style: TextStyle(
                      color: hasValue ? color : Colors.grey,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Heart rate range indicator
          Container(
            height: 4,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.green,
                  Colors.yellow,
                  Colors.orange,
                  Colors.red,
                ],
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Calculate position based on heart rate (60-180 bpm range)
                double position = 0;
                if (hasValue) {
                  position = ((value - 60) / 120).clamp(0.0, 1.0);
                }
                
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    if (hasValue)
                      Positioned(
                        left: constraints.maxWidth * position - 4, // Adjust position to center the indicator
                        top: -2,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: color, width: 1),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Steps card with step counter
  Widget _buildStepsCard(String label, int value, Color color) {
    final bool hasValue = value > 0;
    
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Color(0xFF1E1E2D),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with icon and label
          Row(
            children: [
              Icon(
                Icons.directions_walk,
                color: color,
                size: 14,
              ),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          
          Expanded(
            child: Center(
              child: Text(
                hasValue ? value.toString() : "N/A",
                style: TextStyle(
                  color: hasValue ? color : Colors.grey,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Steps progress indicator (10,000 steps goal)
          LinearProgressIndicator(
            value: hasValue ? (value / 10000).clamp(0.0, 1.0) : 0,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(hasValue ? color : Colors.grey),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  // Redesigned athlete selector
  Widget _buildAthleteSelector() {
    return Container(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: performanceData.length,
        itemBuilder: (context, index) {
          final data = performanceData[index];
          final isSelected = data['performanceId'] == selectedPerformanceId;
          final rank = data['rank'] as int;
          
          // Determine medal color based on rank
          Color medalColor = Colors.transparent;
          IconData medalIcon = Icons.circle;
          
          if (rank == 1) {
            medalColor = Colors.amber; // Gold
            medalIcon = Icons.emoji_events;
          } else if (rank == 2) {
            medalColor = Colors.grey.shade300; // Silver
            medalIcon = Icons.emoji_events;
          } else if (rank == 3) {
            medalColor = Colors.brown.shade300; // Bronze
            medalIcon = Icons.emoji_events;
          }
          
          return GestureDetector(
            onTap: () {
              setState(() {
                selectedPerformanceId = data['performanceId'];
                videoUrl = data['videoUrl'];
              });
            },
            child: Container(
              width: 150,
              margin: EdgeInsets.only(right: 12),
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: isSelected ? Colors.white : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  if (medalColor != Colors.transparent)
                    Icon(
                      medalIcon,
                      color: medalColor,
                      size: 20,
                    ),
                  if (medalColor != Colors.transparent)
                    SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          data['athleteName'],
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Rank: #${rank}",
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber.shade600;
      case 2:
        return Colors.blueGrey.shade300;
      case 3:
        return Colors.brown.shade400;
      default:
        return Colors.indigo.shade400;
    }
  }

  List<Color> _getRankGradient(int rank) {
    switch (rank) {
      case 1:
        return [Color(0xFFFFD700), Color(0xFFFFA000)]; // Gold gradient
      case 2:
        return [Color(0xFFC0C0C0), Color(0xFF9E9E9E)]; // Silver gradient
      case 3:
        return [Color(0xFFCD7F32), Color(0xFFA0522D)]; // Bronze gradient
      default:
        return [Color(0xFF3949AB), Color(0xFF1A237E)]; // Blue gradient
    }
  }

  IconData _getRankIcon(int rank) {
    switch (rank) {
      case 1:
        return Icons.emoji_events;
      case 2:
        return Icons.emoji_events;
      case 3:
        return Icons.emoji_events;
      default:
        return Icons.leaderboard;
    }
  }

  String _getRankDescription(int rank) {
    switch (rank) {
      case 1:
        return "Gold Medal Position";
      case 2:
        return "Silver Medal Position";
      case 3:
        return "Bronze Medal Position";
      default:
        return "Ranked #$rank";
    }
  }

  // Helper method to get sport icon
  IconData _getSportIcon(String sportType) {
    switch (sportType.toLowerCase()) {
      case 'running':
        return Icons.directions_run;
      case 'swimming':
        return Icons.pool;
      case 'cycling':
        return Icons.directions_bike;
      case 'weightlifting':
        return Icons.fitness_center;
      default:
        return Icons.sports;
    }
  }
  
  // Helper method to format sport type
  String _formatSportType(String sportType) {
    // Capitalize first letter of each word
    return sportType.split('_').map((word) => 
      word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : ''
    ).join(' ');
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  bool _isCloudinaryUrl(String url) {
    // Check if the URL is a Cloudinary URL
    return url.contains('res.cloudinary.com') || url.contains('cloudinary.com');
  }

  // Get a valid video URL with fallback
  String? getValidVideoUrl(String? originalUrl) {
    if (originalUrl == null || originalUrl.isEmpty) {
      return null;
    }
    
    // If it's already a valid URL, return it
    try {
      final uri = Uri.parse(originalUrl);
      if (uri.isAbsolute) {
        return originalUrl;
      }
    } catch (e) {
      print('Error parsing URL: $e');
    }
    
    // Try to construct a valid URL if it's a relative path
    if (originalUrl.startsWith('/')) {
      return 'https://res.cloudinary.com/ddu7ck4pg$originalUrl';
    }
    
    // Default fallback for testing
    return 'https://res.cloudinary.com/ddu7ck4pg/video/upload/v1741890099/matches/processed/Kg7EgsP4NKYVAqrG2Ia1_processed_1741890090.mp4';
  }

  // Get current performance data
  Map<String, dynamic>? get currentPerformance {
    if (selectedPerformanceId == null || performanceData.isEmpty) return null;
    return performanceData.firstWhere(
      (data) => data['performanceId'] == selectedPerformanceId,
      orElse: () => performanceData.first,
    );
  }
  
  // Get current match name
  String? get currentMatchName {
    return currentPerformance?['matchName'];
  }
  
  // Get current sport type
  String? get currentSportType {
    return currentPerformance?['sportType'];
  }
  
  // Get current race time
  String get currentRaceTime {
    final time = currentPerformance?['raceTime'];
    if (time == null) return 'N/A';
    
    // Format time as mm:ss.ms
    final seconds = (time as num).toDouble();
    final mins = (seconds / 60).floor();
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toStringAsFixed(2).padLeft(5, '0')}';
  }

  // Add new state variables for video annotation
  bool _annotationMode = false;
  final VideoAnnotatorController _annotatorController = VideoAnnotatorController();
  bool _isSavingAnnotations = false;
  
  // Method to save annotations to Firebase
  Future<void> _saveAnnotationsToFirebase(String annotationsJson) async {
    if (selectedPerformanceId == null || annotationsJson.isEmpty) return;
    
    setState(() {
      _isSavingAnnotations = true;
    });
    
    try {
      // Parse the annotations
      final annotations = jsonDecode(annotationsJson);
      
      // Get the current user (coach)
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      // Get the performance ID parts (matchId:athleteId)
      final parts = selectedPerformanceId!.split(':');
      if (parts.length != 2) {
        throw Exception('Invalid performance ID format');
      }
      
      final matchId = parts[0];
      final athleteId = parts[1];
      
      // Create a document reference for the annotations
      final annotationsRef = _firestore
          .collection('matches')
          .doc(matchId)
          .collection('annotations')
          .doc(athleteId);
      
      // Save the annotations
      await annotationsRef.set({
        'annotations': annotations,
        'updated_at': FieldValue.serverTimestamp(),
        'updated_by': currentUser.uid,
        'athlete_id': athleteId,
      }, SetOptions(merge: true));
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Annotations saved successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error saving annotations: $e');
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save annotations: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSavingAnnotations = false);
    }
  }
}

class SimpleVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final VoidCallback? onEnterFullScreen;
  final VoidCallback? onExitFullScreen;
  
  const SimpleVideoPlayer({
    Key? key, 
    required this.videoUrl, 
    this.onEnterFullScreen, 
    this.onExitFullScreen
  }) : super(key: key);
  
  @override
  _SimpleVideoPlayerState createState() => _SimpleVideoPlayerState();
}

class _SimpleVideoPlayerState extends State<SimpleVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isFullScreen = false;
  
  @override
  void initState() {
    super.initState();
    _initializeVideoPlayer();
    
    // Listen for full screen changes
    html.document.onFullscreenChange.listen((_) {
      final isFullScreen = html.document.fullscreenElement != null;
      if (isFullScreen != _isFullScreen) {
        setState(() {
          _isFullScreen = isFullScreen;
        });
        
        if (isFullScreen && widget.onEnterFullScreen != null) {
          widget.onEnterFullScreen!();
        } else if (!isFullScreen && widget.onExitFullScreen != null) {
          widget.onExitFullScreen!();
        }
      }
    });
  }
  
  Future<void> _initializeVideoPlayer() async {
    try {
      print('Initializing video player with URL: ${widget.videoUrl}');
      
      // Check if the URL is valid
      if (widget.videoUrl.isEmpty || !Uri.parse(widget.videoUrl).isAbsolute) {
        throw Exception('Invalid video URL: ${widget.videoUrl}');
      }
      
      _controller = VideoPlayerController.network(widget.videoUrl);
      
      // Add listener before initialization
      _controller.addListener(_videoPlayerListener);
      
      // Set a timeout for initialization
      bool initialized = false;
      try {
        await _controller.initialize().timeout(Duration(seconds: 10), onTimeout: () {
          throw TimeoutException('Video initialization timed out');
        });
        initialized = true;
      } catch (e) {
        print('Error during video initialization: $e');
        if (!_isDisposed && mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Could not load video: ${e.toString()}';
          });
        }
      }
      
      // Check if widget is still mounted before updating state
      if (!mounted || _isDisposed) return;
      
      if (initialized) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }
    } catch (e) {
      print('Error initializing video player: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Could not load video: ${e.toString()}';
        });
      }
    }
  }
  
  void _videoPlayerListener() {
    // This ensures we don't call setState after dispose
    if (!mounted || _isDisposed) return;
    
    // Check for errors
    if (_controller.value.hasError) {
      print('Video player error: ${_controller.value.errorDescription}');
      setState(() {
        _hasError = true;
        _errorMessage = 'Video playback error: ${_controller.value.errorDescription ?? 'Unknown error'}';
      });
    }
  }
  
  @override
  void didUpdateWidget(SimpleVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If the video URL changed, reinitialize the player
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _initializeVideoPlayer();
    }
  }
  
  void _disposeController() {
    _controller.removeListener(_videoPlayerListener);
    _controller.dispose();
  }
  
  @override
  void dispose() {
    print('Disposing SimpleVideoPlayer');
    _isDisposed = true;
    _disposeController();
    super.dispose();
  }
  
  void _toggleFullScreen() {
    if (_isFullScreen) {
      html.document.exitFullscreen();
    } else {
      html.document.documentElement?.requestFullscreen();
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              'Video could not be loaded',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                _errorMessage,
                style: TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _initializeVideoPlayer,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (!_isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading video...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: VideoPlayer(_controller),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: VideoProgressIndicator(
            _controller,
            allowScrubbing: true,
            colors: VideoProgressColors(
              playedColor: Colors.blue,
              bufferedColor: Colors.grey,
              backgroundColor: Colors.black54,
            ),
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
          ),
        ),
        Positioned(
          bottom: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(
                  _controller.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 32,
                ),
                onPressed: () {
                  setState(() {
                    if (_controller.value.isPlaying) {
                      _controller.pause();
                    } else {
                      _controller.play();
                    }
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CloudinaryVideoPlayer extends StatefulWidget {
  final String videoUrl;
  final VoidCallback? onEnterFullScreen;
  final VoidCallback? onExitFullScreen;
  
  const CloudinaryVideoPlayer({
    Key? key, 
    required this.videoUrl, 
    this.onEnterFullScreen, 
    this.onExitFullScreen
  }) : super(key: key);
  
  @override
  _CloudinaryVideoPlayerState createState() => _CloudinaryVideoPlayerState();
}

class _CloudinaryVideoPlayerState extends State<CloudinaryVideoPlayer> {
  late String _embeddedPlayerUrl;
  final String _viewId = 'cloudinary-player-${DateTime.now().millisecondsSinceEpoch}';
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isFullScreen = false;
  
  @override
  void initState() {
    super.initState();
    _setupPlayer();
    
    // Listen for full screen changes
    html.document.onFullscreenChange.listen((_) {
      final isFullScreen = html.document.fullscreenElement != null;
      if (isFullScreen != _isFullScreen) {
        setState(() {
          _isFullScreen = isFullScreen;
        });
        
        if (isFullScreen && widget.onEnterFullScreen != null) {
          widget.onEnterFullScreen!();
          _injectAnnotationControls();
        } else if (!isFullScreen && widget.onExitFullScreen != null) {
          widget.onExitFullScreen!();
        }
      }
    });
  }
  
  void _setupPlayer() {
    try {
      print('Setting up Cloudinary player for URL: ${widget.videoUrl}');
      
      // Convert the regular URL to the embedded player format
      _embeddedPlayerUrl = _convertToEmbeddedUrl(widget.videoUrl);
      
      // Add parameters to control the player
      _embeddedPlayerUrl += '&controls=true&autoplay=false';
      
      // Register the view factory - using ui_web to avoid deprecation warning
      ui.platformViewRegistry.registerViewFactory(
        _viewId, 
        (int viewId) {
          final iframe = html.IFrameElement()
            ..id = 'cloudinary-iframe'
            ..src = _embeddedPlayerUrl
            ..style.border = 'none'
            ..allowFullscreen = true
            ..allow = 'autoplay; fullscreen'
            ..style.width = '100%'
            ..style.height = '100%';
            
          // Add JavaScript message handler for player events
          html.window.addEventListener('message', (html.Event event) {
            if (event is html.MessageEvent) {
              try {
                final data = jsonDecode(event.data);
                if (data['type'] == 'cloudinaryPlayer' && data['event'] == 'fullscreenchange') {
                  final isFullScreen = data['isFullScreen'] == true;
                  if (isFullScreen && widget.onEnterFullScreen != null) {
                    widget.onEnterFullScreen!();
                    _injectAnnotationControls();
                  } else if (!isFullScreen && widget.onExitFullScreen != null) {
                    widget.onExitFullScreen!();
                  }
                }
              } catch (e) {
                // Ignore parsing errors for non-relevant messages
              }
            }
          });
          
          return iframe;
        }
      );
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Error setting up Cloudinary player: $e');
      setState(() {
        _hasError = true;
        _errorMessage = 'Could not load video: ${e.toString()}';
        _isLoading = false;
      });
    }
  }
  
  // Inject annotation controls into the full screen player
  void _injectAnnotationControls() {
    try {
      // Wait a moment for the full screen to initialize
      Future.delayed(Duration(milliseconds: 500), () {
        // Find the full screen element
        final fullscreenElement = html.document.fullscreenElement;
        if (fullscreenElement != null) {
          // Create a container for annotation controls
          final controlsContainer = html.DivElement()
            ..id = 'annotation-controls'
            ..style.position = 'absolute'
            ..style.top = '16px'
            ..style.right = '16px'
            ..style.zIndex = '9999'
            ..style.backgroundColor = 'rgba(0, 0, 0, 0.6)'
            ..style.borderRadius = '30px'
            ..style.padding = '8px';
          
          // Create the pencil button
          final pencilButton = html.ButtonElement()
            ..id = 'annotation-pencil-button'
            ..style.background = 'transparent'
            ..style.border = 'none'
            ..style.color = 'white'
            ..style.fontSize = '24px'
            ..style.cursor = 'pointer'
            ..style.padding = '8px'
            ..title = 'Enter Annotation Mode'
            ..innerHtml = '<svg xmlns="http://www.w3.org/2000/svg" height="24" viewBox="0 0 24 24" width="24" fill="white"><path d="M0 0h24v24H0z" fill="none"/><path d="M3 17.25V21h3.75L17.81 9.94l-3.75-3.75L3 17.25zM20.71 7.04c.39-.39.39-1.02 0-1.41l-2.34-2.34c-.39-.39-1.02-.39-1.41 0l-1.83 1.83 3.75 3.75 1.83-1.83z"/></svg>';
          
          // Add event listener to the pencil button
          pencilButton.onClick.listen((event) {
            // Exit full screen
            html.document.exitFullscreen();
            
            // Wait for full screen to exit, then enter annotation mode
            Future.delayed(Duration(milliseconds: 300), () {
              // Notify the parent widget to enter annotation mode
              // This is done through a custom event
              final customEvent = html.CustomEvent('annotationModeRequested');
              html.window.dispatchEvent(customEvent);
            });
          });
          
          // Add the button to the container
          controlsContainer.children.add(pencilButton);
          
          // Add the container to the full screen element
          fullscreenElement.append(controlsContainer);
        }
      });
    } catch (e) {
      print('Error injecting annotation controls: $e');
    }
  }
  
  String _convertToEmbeddedUrl(String originalUrl) {
    try {
      // Extract the cloud name and public ID from the original URL
      // Example URL: https://res.cloudinary.com/ddu7ck4pg/video/upload/v1741890099/matches/processed/Kg7EgsP4NKYVAqrG2Ia1_processed_1741890090.mp4
      
      final uri = Uri.parse(originalUrl);
      
      if (uri.host != 'res.cloudinary.com') {
        throw Exception('Not a Cloudinary URL');
      }
      
      final pathSegments = uri.pathSegments;
      final cloudName = pathSegments[0];
      
      // The public ID is everything after 'upload' in the path
      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex + 2 >= pathSegments.length) {
        throw Exception('Invalid Cloudinary URL format');
      }
      
      // Skip the version segment (e.g., v1741890099) and join the rest
      final publicIdSegments = pathSegments.sublist(uploadIndex + 2);
      final publicId = publicIdSegments.join('/');
      
      // Remove the file extension if present
      final publicIdWithoutExtension = publicId.contains('.')
          ? publicId.substring(0, publicId.lastIndexOf('.'))
          : publicId;
      
      // Create the embedded player URL
      final encodedPublicId = Uri.encodeComponent(publicIdWithoutExtension);
      return 'https://player.cloudinary.com/embed/?cloud_name=$cloudName&public_id=$encodedPublicId&profile=cld-default';
    } catch (e) {
      print('Error converting to embedded URL: $e');
      // If we can't parse the URL, return a direct embedded URL using the original
      return 'https://player.cloudinary.com/embed/?cloud_name=ddu7ck4pg&public_id=matches%2Fprocessed%2FfVg8tgkShBWFBOts1N7g_processed_1741888895&profile=cld-default';
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              'Loading video player...',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }
    
    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(
              _errorMessage.isNotEmpty ? _errorMessage : 'Error loading video player',
              style: TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _setupPlayer,
              icon: Icon(Icons.refresh),
              label: Text('Try Again'),
            ),
          ],
        ),
      );
    }
    
    // Add a container with fixed size to constrain the HtmlElementView
    return Container(
      height: 400,
      width: double.infinity,
      child: HtmlElementView(viewType: _viewId),
    );
  }
}

// Wave painter for smoothness
class WavePainter extends CustomPainter {
  final double value;
  final Color color;
  final Color backgroundColor;
  
  WavePainter({
    required this.value,
    required this.color,
    required this.backgroundColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Draw background
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(size.height / 2),
      ),
      backgroundPaint,
    );
    
    // Draw wave
    if (value > 0) {
      final wavePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      final path = Path();
      
      // Adjust amplitude based on value (higher value = smoother = lower amplitude)
      final amplitude = size.height * 0.3 * (1 - value);
      final frequency = 2 * pi / size.width * 6; // 6 waves
      
      path.moveTo(0, size.height / 2);
      
      for (double x = 0; x <= size.width * value; x++) {
        final y = size.height / 2 + sin(x * frequency) * amplitude;
        path.lineTo(x, y);
      }
      
      canvas.drawPath(path, wavePaint);
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Animated heartbeat icon
class HeartbeatIcon extends StatefulWidget {
  final Color color;
  final double size;
  
  const HeartbeatIcon({
    Key? key,
    required this.color,
    required this.size,
  }) : super(key: key);
  
  @override
  _HeartbeatIconState createState() => _HeartbeatIconState();
}

class _HeartbeatIconState extends State<HeartbeatIcon> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    
    _animation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Transform.scale(
          scale: _animation.value,
          child: Icon(
            Icons.favorite,
            color: widget.color,
            size: widget.size,
          ),
        );
      },
    );
  }
}
