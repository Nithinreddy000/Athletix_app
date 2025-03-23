import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../constants.dart';

class MatchScorecard extends StatefulWidget {
  final String matchId;
  final String sportType;

  const MatchScorecard({
    Key? key,
    required this.matchId,
    required this.sportType,
  }) : super(key: key);

  @override
  _MatchScorecardState createState() => _MatchScorecardState();
}

class _MatchScorecardState extends State<MatchScorecard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool isLoading = true;
  Map<String, dynamic>? matchDetails;
  List<Map<String, dynamic>> athletes = [];
  Map<String, dynamic>? results;
  
  @override
  void initState() {
    super.initState();
    _loadMatchData();
  }
  
  Future<void> _loadMatchData() async {
    setState(() {
      isLoading = true;
    });
    
    try {
      // Load match details
      final matchDoc = await _firestore.collection('matches').doc(widget.matchId).get();
      if (matchDoc.exists) {
        matchDetails = matchDoc.data();
        
        // Load athlete details
        final athleteIds = List<String>.from(matchDetails?['athletes'] ?? []);
        
        for (final athleteId in athleteIds) {
          final athleteDoc = await _firestore.collection('users').doc(athleteId).get();
          if (athleteDoc.exists) {
            final athleteData = athleteDoc.data() ?? {};
            
            athletes.add({
              'id': athleteId,
              'name': athleteData['name'] ?? 'Unknown Athlete',
              'jersey_number': athleteData['jersey_number'] ?? '',
              'country': athleteData['country'] ?? 'Unknown',
            });
          }
        }
        
        // Generate results based on sport type
        results = _generateResults();
      }
    } catch (e) {
      print('Error loading match data: $e');
    }
    
    setState(() {
      isLoading = false;
    });
  }
  
  Map<String, dynamic> _generateResults() {
    if (widget.sportType == 'running') {
      return _generateRunningResults();
    } else if (widget.sportType == 'swimming') {
      return _generateSwimmingResults();
    } else if (widget.sportType == 'weightlifting') {
      return _generateWeightliftingResults();
    }
    
    return {};
  }
  
  Map<String, dynamic> _generateRunningResults() {
    final athleteResults = <Map<String, dynamic>>[];
    final distance = '100m';
    final type = 'sprint';
    
    // World record time for 100m sprint (approximate)
    final worldRecord = {'seconds': 9, 'milliseconds': 580};
    
    // Generate times for each athlete
    for (int i = 0; i < athletes.length; i++) {
      // Add a random time difference (0.1 to 1.5 seconds)
      final timeDiffSeconds = 0.1 + (i * 0.2) + (_randomDouble() * 0.3);
      
      // Calculate total time in milliseconds
      int totalMs = 0;
      totalMs += worldRecord['seconds']! * 1000;
      totalMs += worldRecord['milliseconds']!;
      
      // Add the time difference
      totalMs += (timeDiffSeconds * 1000).round();
      
      // Convert back to seconds, milliseconds
      int seconds = (totalMs / 1000).floor();
      totalMs -= seconds * 1000;
      int milliseconds = totalMs;
      
      // Create result entry
      athleteResults.add({
        'athleteId': athletes[i]['id'],
        'athleteName': athletes[i]['name'],
        'hours': 0,
        'minutes': 0,
        'seconds': seconds,
        'milliseconds': milliseconds,
        'lane': i + 1,
        'rank': i + 1,
        'personalBest': i == 0,
        'seasonBest': true,
      });
    }
    
    // Sort results by time
    athleteResults.sort((a, b) {
      final aTime = a['seconds'] * 1000 + a['milliseconds'];
      final bTime = b['seconds'] * 1000 + b['milliseconds'];
      return aTime.compareTo(bTime);
    });
    
    // Update ranks
    for (int i = 0; i < athleteResults.length; i++) {
      athleteResults[i]['rank'] = i + 1;
    }
    
    return {
      'type': type,
      'distance': distance,
      'results': athleteResults,
      'location': 'Olympic Stadium',
      'weather': 'Sunny',
      'temperature': 25.0,
      'trackCondition': 'Excellent',
      'isWorldRecord': false,
      'isOlympicRecord': false,
      'isNationalRecord': false,
    };
  }
  
  Map<String, dynamic> _generateSwimmingResults() {
    // Similar to running results but with swimming-specific fields
    return {};
  }
  
  Map<String, dynamic> _generateWeightliftingResults() {
    // Similar to running results but with weightlifting-specific fields
    return {};
  }
  
  double _randomDouble() {
    return DateTime.now().millisecondsSinceEpoch % 1000 / 1000;
  }
  
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    if (matchDetails == null) {
      return Center(child: Text('Match details not found'));
    }
    
    if (widget.sportType == 'running') {
      return _buildRunningScorecard();
    } else if (widget.sportType == 'swimming') {
      return _buildSwimmingScorecard();
    } else if (widget.sportType == 'weightlifting') {
      return _buildWeightliftingScorecard();
    }
    
    return Center(child: Text('Scorecard not available for this sport type'));
  }
  
  Widget _buildRunningScorecard() {
    if (results == null || results!['results'] == null) {
      return Center(child: Text('No results available'));
    }
    
    final athleteResults = results!['results'] as List<Map<String, dynamic>>;
    
    // Get winner names
    String? winnerName;
    String? secondPlaceName;
    String? thirdPlaceName;
    
    if (athleteResults.isNotEmpty) {
      winnerName = athleteResults[0]['athleteName'];
      if (athleteResults.length > 1) secondPlaceName = athleteResults[1]['athleteName'];
      if (athleteResults.length > 2) thirdPlaceName = athleteResults[2]['athleteName'];
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(defaultPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Scorecard
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'OFFICIAL RESULTS',
                        style: Theme.of(context).textTheme.headline6?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatDate(matchDetails!['date']),
                        style: Theme.of(context).textTheme.subtitle1,
                      ),
                    ],
                  ),
                  Divider(thickness: 2),
                  Text(
                    '${results!['type']?.toString().toUpperCase() ?? 'SPRINT'} - ${results!['distance'] ?? '100m'}',
                    style: Theme.of(context).textTheme.subtitle1?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Location: ${results!['location'] ?? 'Olympic Stadium'}'),
                  Text('Weather: ${results!['weather'] ?? 'Sunny'}, ${results!['temperature']?.toStringAsFixed(1) ?? '25.0'}°C'),
                  Text('Track Condition: ${results!['trackCondition'] ?? 'Excellent'}'),
                  
                  SizedBox(height: defaultPadding),
                  
                  // Results table
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        // Table header
                        Container(
                          color: Colors.grey.shade200,
                          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                          child: Row(
                            children: [
                              Expanded(flex: 1, child: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text('Lane', style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(flex: 4, child: Text('Athlete', style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(flex: 2, child: Text('Time', style: TextStyle(fontWeight: FontWeight.bold))),
                              Expanded(flex: 2, child: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        
                        // Table rows
                        ...athleteResults.map((result) {
                          // Format time
                          String timeStr = '';
                          if (result['hours'] > 0) {
                            timeStr += '${result['hours']}:';
                          }
                          
                          if (result['minutes'] > 0 || result['hours'] > 0) {
                            timeStr += '${result['minutes'].toString().padLeft(2, '0')}:';
                          }
                          
                          timeStr += '${result['seconds'].toString().padLeft(2, '0')}';
                          
                          if (results!['type'] == 'sprint') {
                            timeStr += '.${result['milliseconds'].toString().padLeft(3, '0')}';
                          }
                          
                          // Determine medal color
                          Color? rowColor;
                          if (result['rank'] == 1) rowColor = Colors.amber.withOpacity(0.2);
                          else if (result['rank'] == 2) rowColor = Colors.grey.shade300;
                          else if (result['rank'] == 3) rowColor = Colors.brown.shade200;
                          
                          return Container(
                            color: rowColor,
                            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                            child: Row(
                              children: [
                                Expanded(flex: 1, child: Text(result['rank'].toString())),
                                Expanded(flex: 1, child: Text(result['lane'].toString())),
                                Expanded(flex: 4, child: Text(result['athleteName'])),
                                Expanded(flex: 2, child: Text(timeStr, style: TextStyle(fontWeight: FontWeight.bold))),
                                Expanded(
                                  flex: 2, 
                                  child: Row(
                                    children: [
                                      if (result['personalBest'] == true)
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text('PB', style: TextStyle(color: Colors.white, fontSize: 10)),
                                        ),
                                      SizedBox(width: 4),
                                      if (result['seasonBest'] == true)
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text('SB', style: TextStyle(color: Colors.white, fontSize: 10)),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                  
                  SizedBox(height: defaultPadding),
                  
                  // Records section
                  if (results!['isWorldRecord'] == true || 
                      results!['isOlympicRecord'] == true || 
                      results!['isNationalRecord'] == true)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RECORDS:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        if (results!['isWorldRecord'] == true)
                          Text('WR - World Record', style: TextStyle(color: Colors.red)),
                        if (results!['isOlympicRecord'] == true)
                          Text('OR - Olympic Record', style: TextStyle(color: Colors.blue)),
                        if (results!['isNationalRecord'] == true)
                          Text('NR - National Record', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                  
                  SizedBox(height: defaultPadding),
                  
                  // Podium visualization
                  if (athleteResults.length >= 3)
                    Container(
                      height: 120,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Second place
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(secondPlaceName ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                              Container(
                                width: 80,
                                height: 60,
                                color: Colors.grey.shade300,
                                child: Center(child: Text('2', style: TextStyle(fontSize: 24))),
                              ),
                            ],
                          ),
                          SizedBox(width: 8),
                          // First place
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(winnerName ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                              Container(
                                width: 80,
                                height: 80,
                                color: Colors.amber.shade200,
                                child: Center(child: Text('1', style: TextStyle(fontSize: 24))),
                              ),
                            ],
                          ),
                          SizedBox(width: 8),
                          // Third place
                          Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(thirdPlaceName ?? '', style: TextStyle(fontWeight: FontWeight.bold)),
                              Container(
                                width: 80,
                                height: 40,
                                color: Colors.brown.shade200,
                                child: Center(child: Text('3', style: TextStyle(fontSize: 24))),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: defaultPadding),
          
          // Export button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.share),
                label: Text('Share Results'),
                onPressed: () {
                  // Implement share functionality
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildSwimmingScorecard() {
    return Center(child: Text('Swimming scorecard not implemented yet'));
  }
  
  Widget _buildWeightliftingScorecard() {
    return Center(child: Text('Weightlifting scorecard not implemented yet'));
  }
  
  String _formatDate(dynamic date) {
    if (date == null) return 'Unknown Date';
    if (date is Timestamp) {
      return DateFormat('dd MMM yyyy').format(date.toDate());
    }
    return 'Unknown Date';
  }
} 