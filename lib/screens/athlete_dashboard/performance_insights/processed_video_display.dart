import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:video_player/video_player.dart';
import '../../../constants.dart';
import '../performance_analysis/video_player_with_controls.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ProcessedVideoDisplay extends StatefulWidget {
  @override
  _ProcessedVideoDisplayState createState() => _ProcessedVideoDisplayState();
}

class _ProcessedVideoDisplayState extends State<ProcessedVideoDisplay> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  bool isLoading = true;
  List<Map<String, dynamic>> processedVideos = [];
  Map<String, dynamic>? selectedVideo;
  String? selectedMatchId;
  
  @override
  void initState() {
    super.initState();
    _loadProcessedVideos();
  }
  
  Future<void> _loadProcessedVideos() async {
    try {
      setState(() {
        isLoading = true;
      });
      
      final User? currentUser = _auth.currentUser;
      if (currentUser != null) {
        // Get coach dashboard data
        final coachDashboardDoc = await _firestore
            .collection('coach_dashboards')
            .doc(currentUser.uid)
            .get();
            
        if (coachDashboardDoc.exists) {
          final dashboardData = coachDashboardDoc.data();
          final latestVideos = dashboardData?['latest_processed_videos'] as List<dynamic>? ?? [];
          
          if (latestVideos.isNotEmpty) {
            // Convert to list of maps
            processedVideos = latestVideos
                .map((video) => Map<String, dynamic>.from(video))
                .toList();
                
            // Sort by timestamp (newest first)
            processedVideos.sort((a, b) {
              final aTimestamp = a['timestamp'] as Timestamp?;
              final bTimestamp = b['timestamp'] as Timestamp?;
              if (aTimestamp == null || bTimestamp == null) return 0;
              return bTimestamp.compareTo(aTimestamp);
            });
            
            // Get match details for each video
            for (var video in processedVideos) {
              if (video['match_id'] != null) {
                try {
                  final matchDoc = await _firestore
                      .collection('matches')
                      .doc(video['match_id'])
                      .get();
                  
                  if (matchDoc.exists) {
                    final matchData = matchDoc.data() ?? {};
                    video['match_name'] = matchData['name'] ?? 'Unnamed Match';
                    video['match_date'] = matchData['date'] ?? video['timestamp'];
                    video['sport_type'] = matchData['sport'] ?? video['sport_type'] ?? 'running';
                  }
                } catch (e) {
                  print('Error loading match details: $e');
                }
              }
            }
            
            // Select the first video by default
            if (processedVideos.isNotEmpty) {
              selectedVideo = processedVideos.first;
              selectedMatchId = selectedVideo?['match_id'];
            }
          }
        }
      }
      
      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('Error loading processed videos: $e');
      setState(() {
        isLoading = false;
      });
    }
  }
  
  // Get unique match IDs from processed videos
  List<String> get uniqueMatchIds {
    final Set<String> matchIds = {};
    for (var video in processedVideos) {
      if (video['match_id'] != null) {
        matchIds.add(video['match_id']);
      }
    }
    return matchIds.toList();
  }
  
  // Get unique athlete IDs from processed videos for the selected match
  List<String> getAthleteIdsForMatch(String matchId) {
    final Set<String> athleteIds = {};
    for (var video in processedVideos) {
      if (video['match_id'] == matchId && video['athlete_id'] != null) {
        athleteIds.add(video['athlete_id']);
      }
    }
    return athleteIds.toList();
  }
  
  // Get athlete name for display
  String getAthleteDisplayName(String athleteId) {
    final athleteVideos = processedVideos.where((v) => v['athlete_id'] == athleteId).toList();
    if (athleteVideos.isNotEmpty) {
      return athleteVideos.first['athlete_name'] ?? 'Unknown Athlete';
    }
    return "Athlete $athleteId";
  }
  
  // Get match name for display
  String getMatchDisplayName(String matchId) {
    final matchVideos = processedVideos.where((v) => v['match_id'] == matchId).toList();
    if (matchVideos.isNotEmpty) {
      final video = matchVideos.first;
      final matchName = video['match_name'] ?? 'Match';
      final date = _formatTimestamp(video['match_date'] ?? video['timestamp']);
      final sport = video['sport_type']?.toString().toUpperCase() ?? '';
      return "$matchName - $sport ($date)";
    }
    return "Match $matchId";
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: secondaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(defaultPadding),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Performance Insights",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (processedVideos.isNotEmpty)
                  Row(
                    children: [
                      // Match selection dropdown
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: DropdownButton<String>(
                          value: selectedMatchId,
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedMatchId = newValue;
                                // Reset selected video when match changes
                                selectedVideo = processedVideos.firstWhere(
                                  (video) => video['match_id'] == newValue,
                                  orElse: () => processedVideos.first,
                                );
                              });
                            }
                          },
                          items: uniqueMatchIds
                              .map<DropdownMenuItem<String>>((matchId) {
                            return DropdownMenuItem<String>(
                              value: matchId,
                              child: Text(
                                getMatchDisplayName(matchId),
                                style: TextStyle(color: Colors.white70),
                              ),
                            );
                          }).toList(),
                          underline: SizedBox(),
                          icon: Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                          dropdownColor: secondaryColor,
                        ),
                      ),
                      SizedBox(width: 16),
                      // Athlete selection dropdown (only show if match is selected)
                      if (selectedMatchId != null)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black12,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: DropdownButton<String>(
                            value: selectedVideo?['athlete_id'],
                            hint: Text('Select Athlete', style: TextStyle(color: Colors.white70)),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  // Find video for this athlete and match
                                  selectedVideo = processedVideos.firstWhere(
                                    (video) => 
                                      video['match_id'] == selectedMatchId && 
                                      video['athlete_id'] == newValue,
                                    orElse: () => processedVideos.first,
                                  );
                                });
                              }
                            },
                            items: getAthleteIdsForMatch(selectedMatchId!)
                                .map<DropdownMenuItem<String>>((athleteId) {
                              return DropdownMenuItem<String>(
                                value: athleteId,
                                child: Text(
                                  getAthleteDisplayName(athleteId),
                                  style: TextStyle(color: Colors.white70),
                                ),
                              );
                            }).toList(),
                            underline: SizedBox(),
                            icon: Icon(Icons.keyboard_arrow_down, color: Colors.white70),
                            dropdownColor: secondaryColor,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          
          // Content
          if (isLoading)
            Center(
              child: Padding(
                padding: EdgeInsets.all(defaultPadding * 2),
                child: CircularProgressIndicator(),
              ),
            )
          else if (processedVideos.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(defaultPadding * 2),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_off, size: 48, color: Colors.grey),
                    SizedBox(height: defaultPadding),
                    Text(
                      "No processed videos available",
                      style: TextStyle(color: Colors.grey),
                    ),
                    SizedBox(height: defaultPadding),
                    ElevatedButton.icon(
                      icon: Icon(Icons.refresh),
                      label: Text("Refresh"),
                      onPressed: _loadProcessedVideos,
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: EdgeInsets.all(defaultPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Match and athlete info
                  if (selectedVideo != null)
                    Container(
                      padding: EdgeInsets.all(defaultPadding),
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "${selectedVideo!['match_name'] ?? 'Match'} - ${selectedVideo!['sport_type']?.toString().toUpperCase() ?? 'RUNNING'}",
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Athlete: ${selectedVideo!['athlete_name'] ?? 'Unknown'} - Recorded: ${_formatTimestamp(selectedVideo!['timestamp'])}",
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  
                  SizedBox(height: defaultPadding),
                  
                  // Video player
                  if (selectedVideo != null)
                    Container(
                      height: 300,
                      child: VideoPlayerWithControls(
                        videoUrl: selectedVideo!['video_url'] ?? '',
                      ),
                    )
                  else
                    Container(
                      height: 300,
                      color: Colors.black54,
                      child: Center(
                        child: Text(
                          "Video not available",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                    ),
                    
                  SizedBox(height: defaultPadding),
                  
                  // Athlete info and metrics
                  if (selectedVideo != null)
                    _buildAthleteMetrics(selectedVideo!),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildAthleteMetrics(Map<String, dynamic> videoData) {
    final performanceMetrics = videoData['performance_metrics'] as Map<String, dynamic>? ?? {};
    final fitbitData = videoData['fitbit_data'] as Map<String, dynamic>? ?? {};
    final sportType = videoData['sport_type'] as String? ?? 'running';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Match and athlete info
        Text(
          "${videoData['match_name'] ?? 'Match'} - ${sportType.toUpperCase()}",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          "Athlete: ${videoData['athlete_name'] ?? 'Unknown'} - Recorded: ${_formatTimestamp(videoData['timestamp'])}",
          style: TextStyle(color: Colors.white70),
        ),
        SizedBox(height: defaultPadding),
        
        // Performance metrics
        Text(
          "Performance Metrics",
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: defaultPadding / 2),
        
        // Metrics grid
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: [
            _buildMetricCard(
              "Form Score", 
              performanceMetrics['form_score']?.toDouble() ?? 0.0,
              icon: Icons.sports,
              max: 1.0,
            ),
            _buildMetricCard(
              "Balance", 
              performanceMetrics['balance']?.toDouble() ?? 0.0,
              icon: Icons.balance,
              max: 1.0,
            ),
            _buildMetricCard(
              "Symmetry", 
              performanceMetrics['symmetry']?.toDouble() ?? 0.0,
              icon: Icons.compare_arrows,
              max: 1.0,
            ),
            _buildMetricCard(
              "Smoothness", 
              performanceMetrics['smoothness']?.toDouble() ?? 0.0,
              icon: Icons.waves,
              max: 1.0,
            ),
          ],
        ),
        
        SizedBox(height: defaultPadding),
        
        // Fitbit data
        Text(
          "Fitbit Sensor Data",
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: defaultPadding / 2),
        
        // Fitbit metrics grid
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: [
            _buildFitbitMetricCard(
              "Heart Rate", 
              "${fitbitData['heart_rate_avg']?.toInt() ?? fitbitData['heartrate_avg']?.toInt() ?? 0} bpm",
              icon: Icons.favorite,
              color: Colors.redAccent,
            ),
            _buildFitbitMetricCard(
              "Steps", 
              "${fitbitData['steps']?.toInt() ?? 0}",
              icon: Icons.directions_walk,
              color: Colors.greenAccent,
            ),
            _buildFitbitMetricCard(
              "Calories", 
              "${fitbitData['calories']?.toInt() ?? 0} cal",
              icon: Icons.local_fire_department,
              color: Colors.orangeAccent,
            ),
            _buildFitbitMetricCard(
              "Distance", 
              "${(fitbitData['distance']?.toDouble() ?? 0.0).toStringAsFixed(1)} m",
              icon: Icons.straighten,
              color: Colors.blueAccent,
            ),
          ],
        ),
        
        // Sport-specific metrics
        if (sportType == 'running')
          _buildRunningMetrics(performanceMetrics, fitbitData)
        else if (sportType == 'swimming')
          _buildSwimmingMetrics(performanceMetrics, fitbitData)
        else if (sportType == 'weightlifting')
          _buildWeightliftingMetrics(performanceMetrics, fitbitData),
      ],
    );
  }
  
  Widget _buildMetricCard(String title, double value, {IconData? icon, double max = 1.0}) {
    final percentage = (value / max).clamp(0.0, 1.0);
    
    return Card(
      color: Colors.black12,
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null)
                  Icon(icon, color: Colors.white70, size: 16),
                SizedBox(width: 4),
                Text(
                  value.toStringAsFixed(2),
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4),
            LinearProgressIndicator(
              value: percentage,
              backgroundColor: Colors.white24,
              valueColor: AlwaysStoppedAnimation<Color>(
                _getColorForPercentage(percentage),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFitbitMetricCard(String title, String value, {IconData? icon, Color color = Colors.blue}) {
    return Card(
      color: Colors.black12,
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null)
                  Icon(icon, color: color, size: 20),
                SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRunningMetrics(Map<String, dynamic> metrics, Map<String, dynamic> fitbitData) {
    // Combine metrics and fitbit data
    final combinedMetrics = {...metrics, ...fitbitData};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: defaultPadding),
        Text(
          "Running Metrics",
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: defaultPadding / 2),
        
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: [
            _buildFitbitMetricCard(
              "Avg Speed", 
              "${(combinedMetrics['avg_speed']?.toDouble() ?? 0.0).toStringAsFixed(1)} m/s",
              icon: Icons.speed,
              color: Colors.amberAccent,
            ),
            _buildFitbitMetricCard(
              "Stride Length", 
              "${(combinedMetrics['stride_length']?.toDouble() ?? 0.0).toStringAsFixed(1)} m",
              icon: Icons.straighten,
              color: Colors.purpleAccent,
            ),
            _buildFitbitMetricCard(
              "Cadence", 
              "${(combinedMetrics['cadence']?.toDouble() ?? 0.0).toStringAsFixed(1)} spm",
              icon: Icons.repeat,
              color: Colors.tealAccent,
            ),
            _buildFitbitMetricCard(
              "Vertical Osc", 
              "${(combinedMetrics['vertical_oscillation']?.toDouble() ?? 0.0).toStringAsFixed(1)} cm",
              icon: Icons.height,
              color: Colors.indigoAccent,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildSwimmingMetrics(Map<String, dynamic> metrics, Map<String, dynamic> fitbitData) {
    // Combine metrics and fitbit data
    final combinedMetrics = {...metrics, ...fitbitData};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: defaultPadding),
        Text(
          "Swimming Metrics",
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: defaultPadding / 2),
        
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: [
            _buildFitbitMetricCard(
              "Stroke Rate", 
              "${(combinedMetrics['stroke_rate']?.toDouble() ?? 0.0).toStringAsFixed(1)} spm",
              icon: Icons.pool,
              color: Colors.lightBlueAccent,
            ),
            _buildFitbitMetricCard(
              "Stroke Length", 
              "${(combinedMetrics['stroke_length']?.toDouble() ?? 0.0).toStringAsFixed(1)} m",
              icon: Icons.straighten,
              color: Colors.cyanAccent,
            ),
            _buildFitbitMetricCard(
              "Efficiency", 
              "${(combinedMetrics['efficiency']?.toDouble() ?? 0.0).toStringAsFixed(1)}",
              icon: Icons.trending_up,
              color: Colors.greenAccent,
            ),
            _buildFitbitMetricCard(
              "Avg Speed", 
              "${(combinedMetrics['avg_speed']?.toDouble() ?? 0.0).toStringAsFixed(1)} m/s",
              icon: Icons.speed,
              color: Colors.amberAccent,
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildWeightliftingMetrics(Map<String, dynamic> metrics, Map<String, dynamic> fitbitData) {
    // Combine metrics and fitbit data
    final combinedMetrics = {...metrics, ...fitbitData};
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: defaultPadding),
        Text(
          "Weightlifting Metrics",
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: defaultPadding / 2),
        
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          childAspectRatio: 1.5,
          children: [
            _buildFitbitMetricCard(
              "Form Quality", 
              "${(combinedMetrics['form_quality']?.toDouble() ?? 0.0).toStringAsFixed(1)}",
              icon: Icons.fitness_center,
              color: Colors.purpleAccent,
            ),
            _buildFitbitMetricCard(
              "Power", 
              "${(combinedMetrics['power']?.toDouble() ?? 0.0).toStringAsFixed(1)} W",
              icon: Icons.flash_on,
              color: Colors.redAccent,
            ),
            _buildFitbitMetricCard(
              "Velocity", 
              "${(combinedMetrics['velocity']?.toDouble() ?? 0.0).toStringAsFixed(1)} m/s",
              icon: Icons.speed,
              color: Colors.orangeAccent,
            ),
            _buildFitbitMetricCard(
              "Range of Motion", 
              "${(combinedMetrics['range_of_motion']?.toDouble() ?? 0.0).toStringAsFixed(1)}°",
              icon: Icons.rotate_90_degrees_ccw,
              color: Colors.blueAccent,
            ),
          ],
        ),
      ],
    );
  }
  
  Color _getColorForPercentage(double percentage) {
    if (percentage < 0.3) return Colors.redAccent;
    if (percentage < 0.7) return Colors.orangeAccent;
    return Colors.greenAccent;
  }
  
  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return DateFormat('MMM d, yyyy - h:mm a').format(date);
    }
    return 'Unknown';
  }
} 