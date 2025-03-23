import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../services/performance_service.dart';
import '../../../models/performance_data.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:share_plus/share_plus';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'match_scorecard.dart';

class MatchSummaryScreen extends StatefulWidget {
  final String sessionId;
  final String teamId;
  final String sportType;

  const MatchSummaryScreen({
    Key? key,
    required this.sessionId,
    required this.teamId,
    required this.sportType,
  }) : super(key: key);

  @override
  _MatchSummaryScreenState createState() => _MatchSummaryScreenState();
}

class _MatchSummaryScreenState extends State<MatchSummaryScreen> with SingleTickerProviderStateMixin {
  final PerformanceService _performanceService = PerformanceService();
  late TabController _tabController;
  
  MatchSummary? _matchSummary;
  TeamAnalytics? _teamAnalytics;
  bool _isLoading = true;
  Map<String, dynamic>? _matchDetails;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final matchSummary = await _performanceService.generateMatchSummary(widget.sessionId);
      final teamAnalytics = await _performanceService.generateTeamAnalytics(
        widget.teamId,
        widget.sportType,
        DateTime.now().subtract(Duration(days: 30)),
        DateTime.now(),
      );
      
      // Load match details for scorecard
      final matchDetails = await _loadMatchDetails();
      
      setState(() {
        _matchSummary = matchSummary;
        _teamAnalytics = teamAnalytics;
        _matchDetails = matchDetails;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<Map<String, dynamic>> _loadMatchDetails() async {
    try {
      final matchDoc = await FirebaseFirestore.instance
          .collection('matches')
          .doc(widget.sessionId)
          .get();
          
      if (matchDoc.exists) {
        final matchData = matchDoc.data() ?? {};
        
        // Load athlete details
        final athleteIds = List<String>.from(matchData['athletes'] ?? []);
        final athletes = <Map<String, dynamic>>[];
        
        for (final athleteId in athleteIds) {
          final athleteDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(athleteId)
              .get();
              
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
        final results = _generateResults(widget.sportType, athletes);
        
        return {
          ...matchData,
          'athletes': athletes,
          'results': results,
        };
      }
      
      return {};
    } catch (e) {
      print('Error loading match details: $e');
      return {};
    }
  }
  
  Map<String, dynamic> _generateResults(String sportType, List<Map<String, dynamic>> athletes) {
    if (sportType == 'running') {
      return _generateRunningResults(athletes);
    } else if (sportType == 'swimming') {
      return _generateSwimmingResults(athletes);
    } else if (sportType == 'weightlifting') {
      return _generateWeightliftingResults(athletes);
    }
    
    return {};
  }
  
  Map<String, dynamic> _generateRunningResults(List<Map<String, dynamic>> athletes) {
    final results = <Map<String, dynamic>>[];
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
      results.add({
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
    results.sort((a, b) {
      final aTime = a['seconds'] * 1000 + a['milliseconds'];
      final bTime = b['seconds'] * 1000 + b['milliseconds'];
      return aTime.compareTo(bTime);
    });
    
    // Update ranks
    for (int i = 0; i < results.length; i++) {
      results[i]['rank'] = i + 1;
    }
    
    return {
      'type': type,
      'distance': distance,
      'results': results,
      'location': 'Olympic Stadium',
      'weather': 'Sunny',
      'temperature': 25.0,
      'trackCondition': 'Excellent',
      'isWorldRecord': false,
      'isOlympicRecord': false,
      'isNationalRecord': false,
    };
  }
  
  Map<String, dynamic> _generateSwimmingResults(List<Map<String, dynamic>> athletes) {
    // Similar to running results but with swimming-specific fields
    return {};
  }
  
  Map<String, dynamic> _generateWeightliftingResults(List<Map<String, dynamic>> athletes) {
    // Similar to running results but with weightlifting-specific fields
    return {};
  }
  
  double _randomDouble() {
    return DateTime.now().millisecondsSinceEpoch % 1000 / 1000;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Match Summary'),
        actions: [
          IconButton(
            icon: Icon(Icons.share),
            onPressed: _exportReport,
          ),
          IconButton(
            icon: Icon(Icons.compare),
            onPressed: _showComparisonDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Performance Metrics'),
            Tab(text: 'Team Analysis'),
            Tab(text: 'Highlights'),
            Tab(text: 'Scorecard'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPerformanceMetricsTab(),
          _buildTeamAnalysisTab(),
          _buildHighlightsTab(),
          _buildScorecardTab(),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetricsTab() {
    if (_matchSummary == null) return Container();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance Overview Card
          _buildPerformanceOverviewCard(),
          SizedBox(height: 16),
          
          // Metrics Chart
          _buildMetricsChart(),
          SizedBox(height: 24),
          
          // Time Series Data
          Text('Performance Over Time', 
            style: Theme.of(context).textTheme.headline6),
          SizedBox(height: 8),
          _buildTimeSeriesChart(),
        ],
      ),
    );
  }

  Widget _buildPerformanceOverviewCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance Overview',
              style: Theme.of(context).textTheme.headline6),
            SizedBox(height: 16),
            
            // Metrics Grid
            GridView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 2,
              ),
              itemCount: _matchSummary!.metrics.length,
              itemBuilder: (context, index) {
                final metric = _matchSummary!.metrics.entries.elementAt(index);
                return _buildMetricTile(metric.key, metric.value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile(String name, double value) {
    final sportMetrics = PerformanceService.sportMetrics[widget.sportType];
    final definition = sportMetrics?[name];
    
    return Card(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              definition?.name ?? name,
              style: TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 4),
            Text(
              '${value.toStringAsFixed(2)} ${definition?.unit ?? ''}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: _getMetricColor(value, definition),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMetricColor(double value, MetricDefinition? definition) {
    if (definition == null) return Colors.blue;
    
    final performance = definition.isLowerBetter
        ? definition.threshold / value
        : value / definition.threshold;
        
    if (performance >= 0.9) return Colors.green;
    if (performance >= 0.7) return Colors.orange;
    return Colors.red;
  }

  Widget _buildMetricsChart() {
    return SizedBox(
      height: 300,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              dataEntries: _matchSummary!.metrics.entries.map((entry) {
                final definition = PerformanceService.sportMetrics[widget.sportType]?[entry.key];
                final normalizedValue = definition?.isLowerBetter ?? false
                    ? definition!.threshold / entry.value
                    : entry.value / (definition?.threshold ?? 1.0);
                return RadarEntry(value: normalizedValue.clamp(0.0, 1.0));
              }).toList(),
              fillColor: Colors.blue.withOpacity(0.2),
              borderColor: Colors.blue,
            ),
          ],
          titleTextStyle: TextStyle(fontSize: 12),
          tickCount: 5,
          ticksTextStyle: TextStyle(fontSize: 10),
          getTitle: (index) {
            final metric = _matchSummary!.metrics.entries.elementAt(index);
            final definition = PerformanceService.sportMetrics[widget.sportType]?[metric.key];
            return definition?.name ?? metric.key;
          },
        ),
      ),
    );
  }

  Widget _buildTimeSeriesChart() {
    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(show: true),
          borderData: FlBorderData(show: true),
          lineBarsData: _matchSummary!.timeSeriesData.entries.map((entry) {
            final values = entry.value;
            return LineChartBarData(
              spots: List.generate(values.length, (index) {
                return FlSpot(index.toDouble(), values[index]);
              }),
              isCurved: true,
              dotData: FlDotData(show: false),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTeamAnalysisTab() {
    if (_teamAnalytics == null) return Container();

    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Team Overview
          _buildTeamOverviewCard(),
          SizedBox(height: 24),
          
          // Top Performers
          Text('Top Performers', 
            style: Theme.of(context).textTheme.headline6),
          SizedBox(height: 8),
          _buildTopPerformersSection(),
          SizedBox(height: 24),
          
          // Areas for Improvement
          Text('Areas for Improvement', 
            style: Theme.of(context).textTheme.headline6),
          SizedBox(height: 8),
          _buildAreasForImprovementSection(),
        ],
      ),
    );
  }

  Widget _buildTeamOverviewCard() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Team Overview',
              style: Theme.of(context).textTheme.headline6),
            SizedBox(height: 16),
            
            // Team Averages
            ...(_teamAnalytics!.teamAverages.entries.map((entry) {
              final definition = PerformanceService.sportMetrics[widget.sportType]?[entry.key];
              return ListTile(
                title: Text(definition?.name ?? entry.key),
                trailing: Text(
                  '${entry.value.toStringAsFixed(2)} ${definition?.unit ?? ''}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _getMetricColor(entry.value, definition),
                  ),
                ),
              );
            })),
          ],
        ),
      ),
    );
  }

  Widget _buildTopPerformersSection() {
    return Column(
      children: _teamAnalytics!.topPerformers.map((athleteId) {
        final performance = _teamAnalytics!.athletePerformances[athleteId];
        if (performance == null) return Container();
        
        return Card(
          child: ListTile(
            leading: CircleAvatar(child: Text('${performance.overallScore.round()}')),
            title: Text('Athlete $athleteId'),
            subtitle: Text(
              'Strengths: ${performance.strengths.join(", ")}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAreasForImprovementSection() {
    return Column(
      children: _teamAnalytics!.areasForImprovement.map((area) {
        return Card(
          child: ListTile(
            leading: Icon(Icons.warning, color: Colors.orange),
            title: Text(area),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHighlightsTab() {
    if (_matchSummary == null) return Container();

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // Performance Highlights
        ..._matchSummary!.highlights.map((highlight) {
          return Card(
            child: ListTile(
              leading: Icon(Icons.star, color: Colors.amber),
              title: Text(highlight),
            ),
          );
        }),
        
        SizedBox(height: 24),
        
        // Competition Results
        if (_matchSummary!.competitionResults.isNotEmpty) ...[
          Text('Competition Results', 
            style: Theme.of(context).textTheme.headline6),
          SizedBox(height: 8),
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _matchSummary!.competitionResults.entries.map((entry) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key),
                        Text(
                          entry.value.toString(),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildScorecardTab() {
    return MatchScorecard(
      matchId: widget.sessionId,
      sportType: widget.sportType,
    );
  }

  Future<void> _exportReport() async {
    try {
      final pdf = pw.Document();

      // Add title
      pdf.addPage(
        pw.Page(
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(
                level: 0,
                child: pw.Text('Performance Analysis Report',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Date: ${DateTime.now().toString().split(' ')[0]}'),
              pw.Text('Sport: ${widget.sportType}'),
              pw.SizedBox(height: 20),
              
              // Performance Metrics
              pw.Header(level: 1, child: pw.Text('Performance Metrics')),
              ..._matchSummary!.metrics.entries.map((entry) {
                final definition = PerformanceService.sportMetrics[widget.sportType]?[entry.key];
                return pw.Text(
                  '${definition?.name ?? entry.key}: ${entry.value.toStringAsFixed(2)} ${definition?.unit ?? ''}'
                );
              }),
              
              pw.SizedBox(height: 20),
              
              // Highlights
              pw.Header(level: 1, child: pw.Text('Performance Highlights')),
              ..._matchSummary!.highlights.map((highlight) => 
                pw.Bullet(text: highlight)
              ),
              
              // Team Analysis if available
              if (_teamAnalytics != null) ...[
                pw.SizedBox(height: 20),
                pw.Header(level: 1, child: pw.Text('Team Analysis')),
                pw.Text('Top Performers:'),
                ..._teamAnalytics!.topPerformers.map((athleteId) {
                  final performance = _teamAnalytics!.athletePerformances[athleteId];
                  return pw.Bullet(
                    text: 'Athlete $athleteId - Score: ${performance?.overallScore.round()}'
                  );
                }),
              ],
            ],
          ),
        ),
      );

      // Save PDF
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/performance_report.pdf');
      await file.writeAsBytes(await pdf.save());

      // Share the file
      await Share.shareFiles(
        [file.path],
        text: 'Performance Analysis Report',
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error exporting report: $e')),
      );
    }
  }

  void _showComparisonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Compare With'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Other Athletes'),
              onTap: () {
                Navigator.pop(context);
                _showAthleteComparison();
              },
            ),
            ListTile(
              title: Text('Other Teams'),
              onTap: () {
                Navigator.pop(context);
                _showTeamComparison();
              },
            ),
            ListTile(
              title: Text('Previous Sessions'),
              onTap: () {
                Navigator.pop(context);
                _showSessionComparison();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonChart(List<ComparisonData> data) {
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barGroups: data.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  y: entry.value.value,
                  colors: [entry.value.color],
                  width: 20,
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: SideTitles(
              showTitles: true,
              getTitles: (value) => data[value.toInt()].label,
            ),
          ),
        ),
      ),
    );
  }

  // Enhanced visualization for specific sports
  Widget _buildSportSpecificMetrics() {
    switch (widget.sportType.toLowerCase()) {
      case 'basketball':
        return _buildBasketballMetrics();
      case 'athletics':
        return _buildAthleticsMetrics();
      default:
        return Container();
    }
  }

  Widget _buildBasketballMetrics() {
    final metrics = _matchSummary?.metrics ?? {};
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Basketball Performance',
              style: Theme.of(context).textTheme.headline6),
            SizedBox(height: 16),
            
            // Shooting accuracy chart
            _buildShootingChart(metrics),
            
            // Player movement heatmap
            _buildMovementHeatmap(),
            
            // Success rate by zone
            _buildCourtZoneAnalysis(),
          ],
        ),
      ),
    );
  }

  Widget _buildAthleticsMetrics() {
    final metrics = _matchSummary?.metrics ?? {};
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Athletics Performance',
              style: Theme.of(context).textTheme.headline6),
            SizedBox(height: 16),
            
            // Sprint analysis
            _buildSprintAnalysis(metrics),
            
            // Power output graph
            _buildPowerGraph(),
            
            // Technique breakdown
            _buildTechniqueBreakdown(),
          ],
        ),
      ),
    );
  }

  Widget _buildShootingChart(Map<String, double> metrics) {
    final shootingData = [
      ChartData('3PT', metrics['three_point'] ?? 0),
      ChartData('2PT', metrics['field_goal'] ?? 0),
      ChartData('FT', metrics['free_throw'] ?? 0),
    ];

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barGroups: shootingData.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  y: entry.value.value,
                  colors: [Colors.blue],
                  width: 20,
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: SideTitles(
              showTitles: true,
              getTitles: (value) => shootingData[value.toInt()].category,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMovementHeatmap() {
    // Simplified heatmap using a Grid
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        childAspectRatio: 1,
      ),
      itemCount: 64,
      itemBuilder: (context, index) {
        final intensity = _getMovementIntensity(index);
        return Container(
          margin: EdgeInsets.all(1),
          color: Colors.blue.withOpacity(intensity),
        );
      },
    );
  }

  double _getMovementIntensity(int index) {
    // Mock data - replace with actual movement data
    final row = index ~/ 8;
    final col = index % 8;
    return (row + col) / 16;
  }

  Widget _buildCourtZoneAnalysis() {
    return CustomPaint(
      size: Size(300, 150),
      painter: CourtZonePainter(
        zoneSuccessRates: {
          'left_corner': 0.45,
          'right_corner': 0.38,
          'top_key': 0.42,
          'paint': 0.65,
          'mid_range': 0.35,
        },
      ),
    );
  }

  Widget _buildSprintAnalysis(Map<String, double> metrics) {
    final sprintData = [
      ChartData('Reaction', metrics['start_reaction'] ?? 0),
      ChartData('Acceleration', metrics['acceleration'] ?? 0),
      ChartData('Top Speed', metrics['top_speed'] ?? 0),
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: SideTitles(
            showTitles: true,
            getTitles: (value) => sprintData[value.toInt()].category,
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: sprintData.asMap().entries.map((entry) {
              return FlSpot(entry.key.toDouble(), entry.value.value);
            }).toList(),
            isCurved: true,
            colors: [Colors.green],
            dotData: FlDotData(show: true),
          ),
        ],
      ),
    );
  }

  Widget _buildPowerGraph() {
    // Mock power data over time
    final powerData = List.generate(10, (index) {
      return FlSpot(
        index.toDouble(),
        (index * 2 + Random().nextDouble() * 5).clamp(0, 100),
      );
    });

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: powerData,
            isCurved: true,
            colors: [Colors.red],
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget _buildTechniqueBreakdown() {
    final techniqueData = [
      ChartData('Form', 85),
      ChartData('Efficiency', 78),
      ChartData('Consistency', 92),
    ];

    return RadarChart(
      RadarChartData(
        dataSets: [
          RadarDataSet(
            dataEntries: techniqueData.map((data) {
              return RadarEntry(value: data.value / 100);
            }).toList(),
            fillColor: Colors.purple.withOpacity(0.2),
            borderColor: Colors.purple,
          ),
        ],
        radarShape: RadarShape.polygon,
        radarBorderData: BorderSide(color: Colors.grey),
        ticksTextStyle: TextStyle(fontSize: 10),
        getTitle: (index) => techniqueData[index].category,
      ),
    );
  }

  Future<void> _showAthleteComparison() async {
    // Mock comparison data
    final comparisonData = [
      ComparisonData(label: 'Current', value: 85, color: Colors.blue),
      ComparisonData(label: 'Team Avg', value: 75, color: Colors.grey),
      ComparisonData(label: 'Top Player', value: 95, color: Colors.green),
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Athlete Comparison',
                style: Theme.of(context).textTheme.headline6),
              SizedBox(height: 16),
              _buildComparisonChart(comparisonData),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showTeamComparison() async {
    // Mock team comparison data
    final comparisonData = [
      ComparisonData(label: 'Our Team', value: 82, color: Colors.blue),
      ComparisonData(label: 'Team A', value: 78, color: Colors.red),
      ComparisonData(label: 'Team B', value: 88, color: Colors.green),
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Team Comparison',
                style: Theme.of(context).textTheme.headline6),
              SizedBox(height: 16),
              _buildComparisonChart(comparisonData),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSessionComparison() async {
    // Mock session comparison data
    final comparisonData = [
      ComparisonData(label: 'Current', value: 85, color: Colors.blue),
      ComparisonData(label: 'Last Week', value: 80, color: Colors.grey),
      ComparisonData(label: 'Best', value: 90, color: Colors.green),
    ];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Session Comparison',
                style: Theme.of(context).textTheme.headline6),
              SizedBox(height: 16),
              _buildComparisonChart(comparisonData),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class ComparisonData {
  final String label;
  final double value;
  final Color color;

  ComparisonData({
    required this.label,
    required this.value,
    required this.color,
  });
}

class ChartData {
  final String category;
  final double value;

  ChartData(this.category, this.value);
}

class CourtZonePainter extends CustomPainter {
  final Map<String, double> zoneSuccessRates;

  CourtZonePainter({required this.zoneSuccessRates});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill;

    // Draw each zone with color based on success rate
    zoneSuccessRates.forEach((zone, rate) {
      final rect = _getZoneRect(zone, size);
      paint.color = Colors.red.withOpacity(rate);
      canvas.drawRect(rect, paint);
    });
  }

  Rect _getZoneRect(String zone, Size size) {
    switch (zone) {
      case 'left_corner':
        return Rect.fromLTWH(0, size.height * 0.8, size.width * 0.2, size.height * 0.2);
      case 'right_corner':
        return Rect.fromLTWH(size.width * 0.8, size.height * 0.8, size.width * 0.2, size.height * 0.2);
      case 'top_key':
        return Rect.fromLTWH(size.width * 0.4, 0, size.width * 0.2, size.height * 0.3);
      case 'paint':
        return Rect.fromLTWH(size.width * 0.3, size.height * 0.3, size.width * 0.4, size.height * 0.5);
      case 'mid_range':
      default:
        return Rect.fromLTWH(size.width * 0.2, size.height * 0.2, size.width * 0.6, size.height * 0.6);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
} 