import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/performance_analytics_service.dart';
import '../constants.dart';

class PerformanceVisualization extends StatefulWidget {
  final List<Map<String, dynamic>> sessionData;
  final Map<String, dynamic>? comparisonData;

  const PerformanceVisualization({
    Key? key,
    required this.sessionData,
    this.comparisonData,
  }) : super(key: key);

  @override
  _PerformanceVisualizationState createState() => _PerformanceVisualizationState();
}

class _PerformanceVisualizationState extends State<PerformanceVisualization> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Map<String, double> metrics;
  late List<Map<String, dynamic>> recommendations;
  late Map<String, double> trainingFocus;
  late Map<String, List<double>> movementPatterns;
  late Map<String, dynamic> specializedMetrics;
  String _selectedMovementType = 'jump';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _calculateMetrics();
  }

  void _calculateMetrics() {
    metrics = PerformanceAnalytics.calculatePerformanceMetrics(widget.sessionData);
    recommendations = PerformanceAnalytics.generateDetailedRecommendations(metrics);
    trainingFocus = PerformanceAnalytics.generateTrainingFocus(metrics);
    movementPatterns = PerformanceAnalytics.analyzeMovementPatterns(widget.sessionData);
    specializedMetrics = PerformanceAnalytics.analyzeSpecificMovement(
      widget.sessionData,
      _selectedMovementType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (widget.comparisonData != null)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Comparing with previous session',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: 'Overview'),
            Tab(text: 'Detailed Analysis'),
            Tab(text: 'Movement Patterns'),
            Tab(text: 'Specialized Analysis'),
            Tab(text: 'Recommendations'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildOverviewTab(),
              _buildDetailedAnalysisTab(),
              _buildMovementPatternsTab(),
              _buildSpecializedAnalysisTab(),
              _buildRecommendationsTab(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Performance Overview Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Performance Overview',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: Row(
                      children: [
                        Expanded(
                          child: PieChart(
                            PieChartData(
                              sections: PerformanceAnalytics.generatePerformanceBreakdown(metrics),
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                            ),
                          ),
                        ),
                        if (widget.comparisonData != null) ...[
                          SizedBox(width: 16),
                          Expanded(
                            child: _buildProgressComparison(),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Key Performance Indicators
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Key Performance Indicators',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 16),
                  _buildKPIGrid(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailedAnalysisTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Fatigue Analysis
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fatigue Analysis',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 16),
                  _buildFatigueChart(),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Power Output
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Power Output',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 16),
                  _buildPowerOutputChart(),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Technique Analysis
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Technique Analysis',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 16),
                  _buildTechniqueAnalysis(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementPatternsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Phase Analysis
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Movement Phases',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 16),
                  _buildPhaseAnalysisChart(),
                ],
              ),
            ),
          ),

          SizedBox(height: 16),

          // Movement Efficiency
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Movement Efficiency',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  SizedBox(height: 16),
                  _buildEfficiencyRadar(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecializedAnalysisTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButton<String>(
              value: _selectedMovementType,
              items: ['jump', 'sprint', 'squat'].map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(type.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedMovementType = value;
                    specializedMetrics = PerformanceAnalytics.analyzeSpecificMovement(
                      widget.sessionData,
                      value,
                    );
                  });
                }
              },
            ),
          ),
          _buildSpecializedMetricsCard(),
          if (widget.comparisonData != null)
            _buildComparisonAnalysis(),
        ],
      ),
    );
  }

  Widget _buildSpecializedMetricsCard() {
    if (specializedMetrics.isEmpty) return SizedBox.shrink();

    final metrics = _getSpecializedMetricsForType();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_selectedMovementType.toUpperCase()} Analysis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            ...metrics.entries.map((entry) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatMetricName(entry.key),
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    LinearProgressIndicator(
                      value: entry.value is double ? entry.value.clamp(0.0, 1.0) : 0.0,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(_getMetricColor(entry.value)),
                    ),
                    Text(
                      _formatMetricValue(entry.value),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonAnalysis() {
    if (widget.comparisonData == null) return SizedBox.shrink();

    final previousMetrics = PerformanceAnalytics.analyzeSpecificMovement(
      widget.comparisonData!['sessionData'] as List<Map<String, dynamic>>,
      _selectedMovementType,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progress Comparison',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: 16),
            _buildComparisonChart(previousMetrics),
          ],
        ),
      ),
    );
  }

  Widget _buildComparisonChart(Map<String, dynamic> previousMetrics) {
    final currentMetrics = _getSpecializedMetricsForType();
    final metrics = currentMetrics.keys.where((key) => 
      currentMetrics[key] is double && previousMetrics[key] is double
    ).toList();

    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 1.0,
          barGroups: List.generate(metrics.length, (index) {
            final metric = metrics[index];
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: (previousMetrics[metric] as double).clamp(0.0, 1.0),
                  color: Colors.grey,
                  width: 15,
                ),
                BarChartRodData(
                  toY: (currentMetrics[metric] as double).clamp(0.0, 1.0),
                  color: Colors.blue,
                  width: 15,
                ),
              ],
            );
          }),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      _formatMetricName(metrics[value.toInt()]),
                      style: TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(show: true),
          borderData: FlBorderData(show: true),
        ),
      ),
    );
  }

  Map<String, dynamic> _getSpecializedMetricsForType() {
    switch (_selectedMovementType) {
      case 'jump':
        return {
          'takeoffVelocity': specializedMetrics['takeoffVelocity'] ?? 0.0,
          'jumpHeight': specializedMetrics['jumpHeight'] ?? 0.0,
          'explosiveness': specializedMetrics['explosiveness'] ?? 0.0,
          'landingControl': specializedMetrics['landingControl'] ?? 0.0,
          'symmetry': specializedMetrics['symmetry'] ?? 0.0,
        };
      case 'sprint':
        return {
          'maxSpeed': specializedMetrics['maxSpeed'] ?? 0.0,
          'accelerationRate': specializedMetrics['accelerationRate'] ?? 0.0,
          'speedEndurance': specializedMetrics['speedEndurance'] ?? 0.0,
          'strideEfficiency': specializedMetrics['strideEfficiency'] ?? 0.0,
          'stepFrequency': specializedMetrics['stepFrequency'] ?? 0.0,
        };
      case 'squat':
        return {
          'depthAngle': specializedMetrics['depthAngle'] ?? 0.0,
          'descendingControl': specializedMetrics['descendingControl'] ?? 0.0,
          'ascendingPower': specializedMetrics['ascendingPower'] ?? 0.0,
          'symmetry': specializedMetrics['symmetry'] ?? 0.0,
          'stabilityScore': specializedMetrics['stabilityScore'] ?? 0.0,
        };
      default:
        return {};
    }
  }

  String _formatMetricName(String metric) {
    return metric
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
        )
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatMetricValue(dynamic value) {
    if (value is double) {
      if (value < 1.0) {
        return '${(value * 100).toStringAsFixed(1)}%';
      }
      return value.toStringAsFixed(2);
    }
    return value.toString();
  }

  Color _getMetricColor(dynamic value) {
    if (value is! double) return Colors.grey;
    if (value >= 0.8) return Colors.green;
    if (value >= 0.6) return Colors.blue;
    if (value >= 0.4) return Colors.orange;
    return Colors.red;
  }

  Widget _buildKPIGrid() {
    final kpiMetrics = {
      'Performance Index': metrics['performanceIndex']!,
      'Technique Score': metrics['techniqueScore']!,
      'Power Output': metrics['powerOutput']!,
      'Movement Efficiency': metrics['movementEfficiency']!,
      'Recovery Rate': metrics['recoveryRate']!,
      'Balance Score': metrics['balanceScore']!,
    };

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: kpiMetrics.length,
      itemBuilder: (context, index) {
        final entry = kpiMetrics.entries.elementAt(index);
        return _buildKPICard(entry.key, entry.value);
      },
    );
  }

  Widget _buildKPICard(String label, double value) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _getKPIColor(value).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            '${(value * 100).toStringAsFixed(1)}%',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: _getKPIColor(value),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFatigueChart() {
    // Split session into segments
    final segments = widget.sessionData.length ~/ 10;
    final speedSegments = List.generate(10, (i) {
      final start = i * segments;
      final end = (i + 1) * segments;
      final segmentData = widget.sessionData.sublist(start, end);
      return segmentData.map((d) => d['speed'] as double).reduce((a, b) => a + b) / segmentData.length;
    });

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text('${(value * 10).toInt()}%');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(value.toStringAsFixed(1));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: speedSegments.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), e.value);
              }).toList(),
              isCurved: true,
              color: Colors.blue,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.blue.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPowerOutputChart() {
    final powers = widget.sessionData.map((d) {
      final speed = d['speed'] as double;
      final accel = d['acceleration'] as double;
      final height = d['height'] as double;
      return speed * accel + height * 9.81;
    }).toList();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text('${value.toInt()}s');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  return Text(value.toStringAsFixed(1));
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: true),
          lineBarsData: [
            LineChartBarData(
              spots: powers.asMap().entries.map((e) {
                return FlSpot(e.key.toDouble(), e.value);
              }).toList(),
              isCurved: true,
              color: Colors.red,
              barWidth: 2,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: Colors.red.withOpacity(0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTechniqueAnalysis() {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 2,
          child: RadarChart(
            RadarChartData(
              dataSets: [
                RadarDataSet(
                  dataEntries: [
                    RadarEntry(value: metrics['techniqueScore']! * 100),
                    RadarEntry(value: metrics['stabilityScore']! * 100),
                    RadarEntry(value: metrics['balanceScore']! * 100),
                    RadarEntry(value: metrics['consistency']! * 100),
                    RadarEntry(value: metrics['movementEfficiency']! * 100),
                  ],
                  fillColor: Colors.blue.withOpacity(0.2),
                  borderColor: Colors.blue,
                ),
              ],
              radarShape: RadarShape.polygon,
              radarBorderData: BorderSide(color: Colors.grey),
              ticksTextStyle: TextStyle(color: Colors.grey, fontSize: 10),
              getTitle: (index) {
                switch (index) {
                  case 0:
                    return 'Technique';
                  case 1:
                    return 'Stability';
                  case 2:
                    return 'Balance';
                  case 3:
                    return 'Consistency';
                  case 4:
                    return 'Efficiency';
                  default:
                    return '';
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseAnalysisChart() {
    return SizedBox(
      height: 300,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  switch (value.toInt()) {
                    case 0:
                      return Text('Preparation');
                    case 1:
                      return Text('Execution');
                    case 2:
                      return Text('Recovery');
                    default:
                      return Text('');
                  }
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [
                BarChartRodData(
                  toY: movementPatterns['preparationPhase']!.length.toDouble(),
                  color: Colors.blue,
                ),
              ],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [
                BarChartRodData(
                  toY: movementPatterns['executionPhase']!.length.toDouble(),
                  color: Colors.green,
                ),
              ],
            ),
            BarChartGroupData(
              x: 2,
              barRods: [
                BarChartRodData(
                  toY: movementPatterns['recoveryPhase']!.length.toDouble(),
                  color: Colors.orange,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEfficiencyRadar() {
    final efficiencyMetrics = {
      'Speed Smoothness': metrics['movementEfficiency']!,
      'Energy Conservation': 1.0 - metrics['fatigueIndex']!,
      'Form Consistency': metrics['consistency']!,
      'Balance Control': metrics['balanceScore']!,
      'Recovery Efficiency': metrics['recoveryRate']!,
    };

    return AspectRatio(
      aspectRatio: 2,
      child: RadarChart(
        RadarChartData(
          dataSets: [
            RadarDataSet(
              dataEntries: efficiencyMetrics.values
                  .map((v) => RadarEntry(value: v * 100))
                  .toList(),
              fillColor: Colors.green.withOpacity(0.2),
              borderColor: Colors.green,
            ),
          ],
          radarShape: RadarShape.polygon,
          radarBorderData: BorderSide(color: Colors.grey),
          ticksTextStyle: TextStyle(color: Colors.grey, fontSize: 10),
          getTitle: (index) {
            return efficiencyMetrics.keys.elementAt(index);
          },
        ),
      ),
    );
  }

  Color _getKPIColor(double value) {
    if (value >= 0.8) return Colors.green;
    if (value >= 0.6) return Colors.blue;
    if (value >= 0.4) return Colors.orange;
    return Colors.red;
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Technique':
        return Icons.sports_gymnastics;
      case 'Power':
        return Icons.flash_on;
      case 'Efficiency':
        return Icons.speed;
      case 'Recovery':
        return Icons.refresh;
      case 'Balance':
        return Icons.balance;
      default:
        return Icons.fitness_center;
    }
  }

  Color _getCategoryColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
} 