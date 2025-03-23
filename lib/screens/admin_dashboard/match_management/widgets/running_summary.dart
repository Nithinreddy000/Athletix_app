import 'package:flutter/material.dart';
import '../../../../constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RunningSummary extends StatefulWidget {
  final String matchId;
  final Function(Map<String, dynamic>) onSave;

  const RunningSummary({
    Key? key,
    required this.matchId,
    required this.onSave,
  }) : super(key: key);

  @override
  _RunningState createState() => _RunningState();
}

class _RunningState extends State<RunningSummary> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Form fields for each athlete
  List<Map<String, dynamic>> results = [];
  String selectedDistance = '100m';
  String selectedType = 'sprint'; // sprint, middle, long
  bool isLoading = true;
  List<Map<String, dynamic>> athletes = [];
  String? winnerName;
  String? secondPlaceName;
  String? thirdPlaceName;
  DateTime matchDate = DateTime.now();
  String matchLocation = 'Olympic Stadium';
  String weatherCondition = 'Sunny';
  double temperature = 25.0;
  String trackCondition = 'Excellent';
  bool isWorldRecord = false;
  bool isOlympicRecord = false;
  bool isNationalRecord = false;

  final List<String> distances = [
    '100m', '200m', '400m', '800m', '1500m', '5000m', '10000m', 'marathon'
  ];
  final List<String> types = ['sprint', 'middle', 'long'];
  
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
        final matchData = matchDoc.data() ?? {};
        final athleteIds = List<String>.from(matchData['athletes'] ?? []);
        final Timestamp? dateTimestamp = matchData['date'];
        
        if (dateTimestamp != null) {
          matchDate = dateTimestamp.toDate();
        }
        
        // Load athlete details
        for (final athleteId in athleteIds) {
          final athleteDoc = await _firestore.collection('users').doc(athleteId).get();
          if (athleteDoc.exists) {
            final athleteData = athleteDoc.data() ?? {};
            
            // Create a result entry for this athlete
            final result = {
              'athleteId': athleteId,
              'athleteName': athleteData['name'] ?? 'Unknown Athlete',
              'hours': 0,
              'minutes': 0,
              'seconds': 0,
              'milliseconds': 0,
              'lane': results.length + 1,
              'rank': 0,
              'splits': List.filled(_getSplitCount(), 0.0),
              'personalBest': false,
              'seasonBest': true,
            };
            
            results.add(result);
            athletes.add({
              'id': athleteId,
              'name': athleteData['name'] ?? 'Unknown Athlete',
              'country': athleteData['country'] ?? 'Unknown',
              'jerseyNumber': athleteData['jersey_number'] ?? '0',
            });
          }
        }
        
        // Generate some realistic times based on the distance
        _generateRealisticTimes();
        
        // Sort results by time (rank)
        _sortResultsByTime();
        
        // Set winner names
        if (results.isNotEmpty) {
          winnerName = results[0]['athleteName'];
        }
        if (results.length > 1) {
          secondPlaceName = results[1]['athleteName'];
        }
        if (results.length > 2) {
          thirdPlaceName = results[2]['athleteName'];
        }
      }
    } catch (e) {
      print('Error loading match data: $e');
    }
    
    setState(() {
      isLoading = false;
    });
  }
  
  void _generateRealisticTimes() {
    // World record times (approximate) for different distances
    final worldRecords = {
      '100m': {'seconds': 9, 'milliseconds': 580},
      '200m': {'seconds': 19, 'milliseconds': 190},
      '400m': {'seconds': 43, 'milliseconds': 30},
      '800m': {'minutes': 1, 'seconds': 40, 'milliseconds': 910},
      '1500m': {'minutes': 3, 'seconds': 26, 'milliseconds': 0},
      '5000m': {'minutes': 12, 'seconds': 35, 'milliseconds': 360},
      '10000m': {'minutes': 26, 'seconds': 11, 'milliseconds': 0},
      'marathon': {'hours': 2, 'minutes': 1, 'seconds': 9, 'milliseconds': 0},
    };
    
    // Get the world record for the selected distance
    final worldRecord = worldRecords[selectedDistance] ?? {'seconds': 10, 'milliseconds': 0};
    
    // Generate times for each athlete
    for (int i = 0; i < results.length; i++) {
      // Add a random time difference (0.1 to 1.5 seconds for sprints, more for longer distances)
      double timeDiffSeconds = 0;
      
      if (selectedDistance == '100m' || selectedDistance == '200m') {
        timeDiffSeconds = 0.1 + (i * 0.2) + (Random().nextDouble() * 0.3);
      } else if (selectedDistance == '400m' || selectedDistance == '800m') {
        timeDiffSeconds = 0.5 + (i * 0.7) + (Random().nextDouble() * 1.0);
      } else if (selectedDistance == '1500m' || selectedDistance == '5000m') {
        timeDiffSeconds = 2.0 + (i * 3.0) + (Random().nextDouble() * 5.0);
      } else {
        timeDiffSeconds = 10.0 + (i * 15.0) + (Random().nextDouble() * 30.0);
      }
      
      // Calculate total time in milliseconds
      int totalMs = 0;
      if (worldRecord['hours'] != null) totalMs += worldRecord['hours'] * 3600000;
      if (worldRecord['minutes'] != null) totalMs += worldRecord['minutes'] * 60000;
      if (worldRecord['seconds'] != null) totalMs += worldRecord['seconds'] * 1000;
      if (worldRecord['milliseconds'] != null) totalMs += worldRecord['milliseconds'];
      
      // Add the time difference
      totalMs += (timeDiffSeconds * 1000).round();
      
      // Convert back to hours, minutes, seconds, milliseconds
      int hours = (totalMs / 3600000).floor();
      totalMs -= hours * 3600000;
      int minutes = (totalMs / 60000).floor();
      totalMs -= minutes * 60000;
      int seconds = (totalMs / 1000).floor();
      totalMs -= seconds * 1000;
      int milliseconds = totalMs;
      
      // Update the result
      results[i]['hours'] = hours;
      results[i]['minutes'] = minutes;
      results[i]['seconds'] = seconds;
      results[i]['milliseconds'] = milliseconds;
      results[i]['rank'] = i + 1;
      
      // Generate split times for longer distances
      if (_getSplitCount() > 0) {
        List<double> splits = [];
        double totalTime = hours * 3600 + minutes * 60 + seconds + milliseconds / 1000;
        double splitTime = totalTime / _getSplitCount();
        
        // Add some variation to splits
        for (int j = 0; j < _getSplitCount(); j++) {
          double variation = 0.95 + (Random().nextDouble() * 0.1); // 0.95 to 1.05
          splits.add(splitTime * variation);
        }
        
        results[i]['splits'] = splits;
      }
    }
  }
  
  void _sortResultsByTime() {
    results.sort((a, b) {
      // Convert both times to milliseconds for comparison
      int aTime = (a['hours'] ?? 0) * 3600000 + 
                 (a['minutes'] ?? 0) * 60000 + 
                 (a['seconds'] ?? 0) * 1000 + 
                 (a['milliseconds'] ?? 0);
                 
      int bTime = (b['hours'] ?? 0) * 3600000 + 
                 (b['minutes'] ?? 0) * 60000 + 
                 (b['seconds'] ?? 0) * 1000 + 
                 (b['milliseconds'] ?? 0);
                 
      return aTime.compareTo(bTime);
    });
    
    // Update ranks
    for (int i = 0; i < results.length; i++) {
      results[i]['rank'] = i + 1;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }
    
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Running Match Summary',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: defaultPadding),
          
          // Event details
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Race Type',
                    border: OutlineInputBorder(),
                  ),
                  items: types.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.toUpperCase()),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedType = value!;
                      _generateRealisticTimes();
                      _sortResultsByTime();
                    });
                  },
                ),
              ),
              const SizedBox(width: defaultPadding),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedDistance,
                  decoration: const InputDecoration(
                    labelText: 'Distance',
                    border: OutlineInputBorder(),
                  ),
                  items: distances.map((distance) => DropdownMenuItem(
                    value: distance,
                    child: Text(distance),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedDistance = value!;
                      _generateRealisticTimes();
                      _sortResultsByTime();
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: defaultPadding * 2),
          
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
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('dd MMM yyyy').format(matchDate),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  Divider(thickness: 2),
                  Text(
                    '${selectedType.toUpperCase()} - ${selectedDistance}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('Location: $matchLocation'),
                  Text('Weather: $weatherCondition, ${temperature.toStringAsFixed(1)}°C'),
                  Text('Track Condition: $trackCondition'),
                  
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
                        ...results.map((result) {
                          // Format time
                          String timeStr = '';
                          if (result['hours'] > 0) {
                            timeStr += '${result['hours']}:';
                          }
                          
                          if (result['minutes'] > 0 || result['hours'] > 0) {
                            timeStr += '${result['minutes'].toString().padLeft(2, '0')}:';
                          }
                          
                          timeStr += '${result['seconds'].toString().padLeft(2, '0')}';
                          
                          if (selectedType == 'sprint') {
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
                                      if (result['personalBest'])
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text('PB', style: TextStyle(color: Colors.white, fontSize: 10)),
                                        ),
                                      SizedBox(width: 4),
                                      if (result['seasonBest'])
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
                  if (isWorldRecord || isOlympicRecord || isNationalRecord)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RECORDS:', style: TextStyle(fontWeight: FontWeight.bold)),
                        SizedBox(height: 4),
                        if (isWorldRecord)
                          Text('WR - World Record', style: TextStyle(color: Colors.red)),
                        if (isOlympicRecord)
                          Text('OR - Olympic Record', style: TextStyle(color: Colors.blue)),
                        if (isNationalRecord)
                          Text('NR - National Record', style: TextStyle(color: Colors.green)),
                      ],
                    ),
                  
                  SizedBox(height: defaultPadding),
                  
                  // Podium visualization
                  if (results.length >= 3)
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
          
          const SizedBox(height: defaultPadding * 2),
          
          // Save button
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                icon: Icon(Icons.save),
                label: Text('Save Results'),
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Prepare data for saving
                    final summaryData = {
                      'type': selectedType,
                      'distance': selectedDistance,
                      'results': results,
                      'location': matchLocation,
                      'weather': weatherCondition,
                      'temperature': temperature,
                      'trackCondition': trackCondition,
                      'isWorldRecord': isWorldRecord,
                      'isOlympicRecord': isOlympicRecord,
                      'isNationalRecord': isNationalRecord,
                      'date': matchDate,
                    };
                    
                    // Call the onSave callback
                    widget.onSave(summaryData);
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  int _getSplitCount() {
    // Determine number of splits based on distance
    switch (selectedDistance) {
      case '400m': return 1;  // 200m split
      case '800m': return 1;  // 400m split
      case '1500m': return 3; // 400m, 800m, 1200m splits
      case '5000m': return 4; // 1000m splits
      case '10000m': return 9; // 1000m splits
      case 'marathon': return 8; // 5km splits
      default: return 0;
    }
  }

  String _getSplitDistance(int index) {
    // Return the distance for each split
    switch (selectedDistance) {
      case '400m': return '200m';
      case '800m': return '400m';
      case '1500m': 
        final distances = ['400m', '800m', '1200m'];
        return distances[index];
      case '5000m': 
        return '${(index + 1) * 1000}m';
      case '10000m': 
        return '${(index + 1) * 1000}m';
      case 'marathon': 
      return '${(index + 1) * 5}km';
      default: return '';
    }
  }
}

class Random {
  static final _random = new Random._internal();
  
  factory Random() {
    return _random;
  }
  
  Random._internal();
  
  double nextDouble() {
    return DateTime.now().millisecondsSinceEpoch % 1000 / 1000;
  }
} 