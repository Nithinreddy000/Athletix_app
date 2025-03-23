import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../constants.dart';

class MatchScorecardDetails extends StatefulWidget {
  final String matchId;
  final String sportType;
  final bool isEditable;

  const MatchScorecardDetails({
    Key? key,
    required this.matchId,
    required this.sportType,
    this.isEditable = false,
  }) : super(key: key);

  @override
  _MatchScorecardDetailsState createState() => _MatchScorecardDetailsState();
}

class _MatchScorecardDetailsState extends State<MatchScorecardDetails> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  Map<String, dynamic>? matchDetails;
  List<Map<String, dynamic>> athletes = [];
  Map<String, TextEditingController> rankControllers = {};
  
  @override
  void initState() {
    super.initState();
    _loadMatchData();
  }

  @override
  void dispose() {
    rankControllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }
  
  Future<void> _loadMatchData() async {
    setState(() => isLoading = true);
    
    try {
      // Load match details
      final matchDoc = await _firestore.collection('matches').doc(widget.matchId).get();
      if (matchDoc.exists) {
        matchDetails = matchDoc.data();
        
        // Load athlete details
        final athleteIds = List<String>.from(matchDetails?['athletes'] ?? []);
        
        // Load detected athletes from video processing if available
        final detectedAthletes = matchDetails?['detected_athletes'] ?? {};
        
        for (final athleteId in athleteIds) {
          final athleteDoc = await _firestore.collection('users').doc(athleteId).get();
          if (athleteDoc.exists) {
            final athleteData = athleteDoc.data() ?? {};
            final rankController = TextEditingController(
              text: (matchDetails?['ranks']?[athleteId]?.toString() ?? '0')
            );
            
            rankControllers[athleteId] = rankController;
            
            // Check if this athlete was detected in the video
            final isDetected = detectedAthletes[athleteId] != null;
            final detectionConfidence = detectedAthletes[athleteId]?['confidence'] ?? 0.0;
            final detectedJersey = detectedAthletes[athleteId]?['detected_jersey'] ?? '';
            
            athletes.add({
              'id': athleteId,
              'name': athleteData['name'] ?? 'Unknown Athlete',
              'jersey_number': athleteData['jersey_number'] ?? athleteData['jerseyNumber'] ?? '',
              'country': athleteData['country'] ?? 'Unknown',
              'score': matchDetails?['scores']?[athleteId] ?? 0,
              'rank': matchDetails?['ranks']?[athleteId] ?? 0,
              'is_detected': isDetected,
              'detection_confidence': detectionConfidence,
              'detected_jersey': detectedJersey,
            });
          }
        }
        
        // Sort athletes by rank
        athletes.sort((a, b) => (a['rank'] as int).compareTo(b['rank'] as int));
      }
    } catch (e) {
      print('Error loading match data: $e');
    }
    
    setState(() => isLoading = false);
  }

  Future<void> _updateRanks() async {
    try {
      final ranks = <String, int>{};
      
      // Collect all ranks
      for (final athlete in athletes) {
        final rank = int.tryParse(rankControllers[athlete['id']]?.text ?? '0') ?? 0;
        ranks[athlete['id']] = rank;
      }
      
      // Update Firestore
      await _firestore.collection('matches').doc(widget.matchId).update({
        'ranks': ranks,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ranks updated successfully')),
      );
      
      // Reload data to reflect changes
      await _loadMatchData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating ranks: $e')),
      );
    }
  }

  // Add a method to verify athlete detection
  Future<void> _verifyAthleteDetection() async {
    try {
      // Get the match document
      final matchDoc = await _firestore.collection('matches').doc(widget.matchId).get();
      if (!matchDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Match not found')),
        );
        return;
      }
      
      final matchData = matchDoc.data() ?? {};
      
      // Check if video processing has been done
      if (matchData['status'] != 'completed' && matchData['status'] != 'processing_completed') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Video processing not completed yet')),
        );
        return;
      }
      
      // Get unidentified athletes from the processing results
      final unidentifiedAthletes = matchData['unidentified_athletes'] ?? [];
      
      if (unidentifiedAthletes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No unidentified athletes to verify')),
        );
        return;
      }
      
      // Show dialog to manually match unidentified athletes
      await _showAthleteMatchingDialog(unidentifiedAthletes);
    } catch (e) {
      print('Error verifying athlete detection: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error verifying athletes: $e')),
      );
    }
  }
  
  // Show dialog to manually match unidentified athletes
  Future<void> _showAthleteMatchingDialog(List<dynamic> unidentifiedAthletes) async {
    // Create a map to store the selected athlete for each unidentified athlete
    final Map<String, String> athleteMatches = {};
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Match Unidentified Athletes'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: unidentifiedAthletes.length,
            itemBuilder: (context, index) {
              final unidentifiedAthlete = unidentifiedAthletes[index];
              final detectedJersey = unidentifiedAthlete['detected_jersey'] ?? 'Unknown';
              final confidence = unidentifiedAthlete['confidence'] ?? 0.0;
              
              return Card(
                margin: EdgeInsets.symmetric(vertical: 8),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unidentified Athlete #${index + 1}',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text('Detected Jersey: $detectedJersey'),
                      Text('Confidence: ${(confidence * 100).toStringAsFixed(1)}%'),
                      SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Match with Athlete',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem<String>(
                            value: '',
                            child: Text('-- Select Athlete --'),
                          ),
                          ...athletes.map((athlete) => DropdownMenuItem<String>(
                            value: athlete['id'],
                            child: Text('${athlete['name']} (${athlete['jersey_number']})'),
                          )).toList(),
                        ],
                        onChanged: (value) {
                          athleteMatches[unidentifiedAthlete['id']] = value ?? '';
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Update the match with the matched athletes
              await _updateAthleteMatches(athleteMatches);
              Navigator.of(context).pop();
            },
            child: Text('Save Matches'),
          ),
        ],
      ),
    );
  }
  
  // Update the match with the matched athletes
  Future<void> _updateAthleteMatches(Map<String, String> athleteMatches) async {
    try {
      // Get the current detected athletes
      final matchDoc = await _firestore.collection('matches').doc(widget.matchId).get();
      final matchData = matchDoc.data() ?? {};
      final detectedAthletes = Map<String, dynamic>.from(matchData['detected_athletes'] ?? {});
      
      // Update the detected athletes with the matches
      athleteMatches.forEach((unidentifiedId, athleteId) {
        if (athleteId.isNotEmpty) {
          // Find the athlete in our list
          final athlete = athletes.firstWhere(
            (a) => a['id'] == athleteId,
            orElse: () => {'id': '', 'name': '', 'jersey_number': ''},
          );
          
          // Add the athlete to the detected athletes
          detectedAthletes[athleteId] = {
            'name': athlete['name'],
            'jersey_number': athlete['jersey_number'],
            'confidence': 1.0, // Manual match has 100% confidence
            'manually_matched': true,
            'original_unidentified_id': unidentifiedId,
          };
        }
      });
      
      // Update the match document
      await _firestore.collection('matches').doc(widget.matchId).update({
        'detected_athletes': detectedAthletes,
        'last_manual_verification': FieldValue.serverTimestamp(),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Athlete matches updated successfully')),
      );
      
      // Reload the data
      await _loadMatchData();
    } catch (e) {
      print('Error updating athlete matches: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating athlete matches: $e')),
      );
    }
  }

  // Helper method to safely find an athlete by rank
  Map<String, dynamic> findAthleteByRank(int rank) {
    try {
      return athletes.firstWhere((a) => a['rank'] == rank);
    } catch (e) {
      // Return a default athlete if none found with this rank
      return {
        'name': 'No Athlete',
        'score': 0,
        'rank': rank
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (matchDetails == null) {
      return Center(child: Text('Match details not found'));
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(defaultPadding),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Theme.of(context).colorScheme.secondary,
                          Theme.of(context).colorScheme.secondary.withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _getSportIcon(widget.sportType),
                              color: Colors.white,
                              size: 28,
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Match Scorecard',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            if (widget.isEditable)
                              ElevatedButton.icon(
                                onPressed: _verifyAthleteDetection,
                                icon: Icon(Icons.person_search),
                                label: Text('Verify Athletes'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            SizedBox(width: 8),
                            if (widget.isEditable)
                              ElevatedButton.icon(
                                onPressed: _updateRanks,
                                icon: Icon(Icons.save),
                                label: Text('Save Ranks'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.secondary,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: defaultPadding),
                  
                  // Match details
                  ListTile(
                    title: Text('Match Type'),
                    subtitle: Text(_formatSportType(widget.sportType)),
                    leading: Icon(_getSportIcon(widget.sportType), color: Theme.of(context).colorScheme.secondary),
                  ),
                  ListTile(
                    title: Text('Date'),
                    subtitle: Text(matchDetails?['date']?.toDate()?.toString().substring(0, 10) ?? 'N/A'),
                    leading: Icon(Icons.calendar_today, color: Theme.of(context).colorScheme.secondary),
                  ),
                  
                  SizedBox(height: defaultPadding),
                  
                  // Athletes table
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: [
                        DataColumn(label: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Athlete', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Jersey', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('Detection', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: athletes.map((athlete) {
                        final rank = athlete['rank'] as int;
                        Color? rowColor;
                        
                        // Highlight medalists
                        if (rank == 1) rowColor = Theme.of(context).colorScheme.secondary.withOpacity(0.2);
                        else if (rank == 2) rowColor = Colors.grey.shade300;
                        else if (rank == 3) rowColor = Colors.brown.shade200;
                        
                        // Get race time
                        final raceTime = matchDetails?['race_time']?[athlete['id']] ?? 0.0;
                        final formattedTime = _formatRaceTime(raceTime);
                        
                        // Detection status icon and color
                        Widget detectionWidget;
                        if (athlete['is_detected'] == true) {
                          detectionWidget = Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 16),
                              SizedBox(width: 4),
                              Text('Detected', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500)),
                            ],
                          );
                        } else {
                          detectionWidget = Row(
                            children: [
                              Icon(Icons.error, color: Theme.of(context).colorScheme.error, size: 16),
                              SizedBox(width: 4),
                              Text('Not detected', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                            ],
                          );
                        }
                        
                        return DataRow(
                          color: MaterialStateProperty.all(rowColor),
                          cells: [
                            DataCell(
                              widget.isEditable
                                ? TextField(
                                    controller: rankControllers[athlete['id']],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    ),
                                  )
                                : Row(
                                    children: [
                                      if (rank <= 3)
                                        Icon(
                                          Icons.emoji_events,
                                          color: rank == 1 
                                            ? Colors.amber 
                                            : rank == 2 
                                              ? Colors.grey.shade400 
                                              : Colors.brown.shade300,
                                          size: 16,
                                        ),
                                      SizedBox(width: 4),
                                      Text('#$rank'),
                                    ],
                                  ),
                            ),
                            DataCell(Text(athlete['name'])),
                            DataCell(Text(athlete['jersey_number'].toString())),
                            DataCell(Text(formattedTime)),
                            DataCell(detectionWidget),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                  
                  if (athletes.length >= 3) ...[
                    SizedBox(height: defaultPadding * 2),
                    
                    // Podium visualization
                    Container(
                      height: 160,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Second place
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                findAthleteByRank(2)['name'],
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatRaceTime(matchDetails?['race_time']?[findAthleteByRank(2)['id']] ?? 0.0),
                                style: TextStyle(fontSize: 12),
                              ),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('2nd', style: TextStyle(fontSize: 20)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 8),
                          
                          // First place
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                findAthleteByRank(1)['name'],
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatRaceTime(matchDetails?['race_time']?[findAthleteByRank(1)['id']] ?? 0.0),
                                style: TextStyle(fontSize: 12),
                              ),
                              Container(
                                width: 80,
                                height: 120,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.secondary.withOpacity(0.7),
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('1st', style: TextStyle(fontSize: 20)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(width: 8),
                          
                          // Third place
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                findAthleteByRank(3)['name'],
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 4),
                              Text(
                                _formatRaceTime(matchDetails?['race_time']?[findAthleteByRank(3)['id']] ?? 0.0),
                                style: TextStyle(fontSize: 12),
                              ),
                              Container(
                                width: 80,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.brown.shade200,
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.1),
                                      blurRadius: 4,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text('3rd', style: TextStyle(fontSize: 20)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Helper method to format race time
  String _formatRaceTime(dynamic time) {
    if (time == null) return 'N/A';
    
    // Format time as mm:ss.ms
    final seconds = (time as num).toDouble();
    final mins = (seconds / 60).floor();
    final secs = seconds % 60;
    return '${mins.toString().padLeft(2, '0')}:${secs.toStringAsFixed(2).padLeft(5, '0')}';
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
      case '100m':
      case 'sprint':
        return Icons.directions_run;
      default:
        return Icons.sports;
    }
  }
  
  // Helper method to format sport type
  String _formatSportType(String sportType) {
    // Handle special cases
    if (sportType.toLowerCase() == '100m') {
      return '100m Sprint';
    }
    
    // Capitalize first letter of each word
    return sportType.split('_').map((word) => 
      word.isNotEmpty ? word[0].toUpperCase() + word.substring(1) : ''
    ).join(' ');
  }
} 