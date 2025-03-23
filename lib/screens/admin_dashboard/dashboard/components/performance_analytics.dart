import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:admin/services/analytics_service.dart';
import 'package:intl/intl.dart';

class PerformanceAnalytics extends StatefulWidget {
  final String athleteId;

  const PerformanceAnalytics({
    Key? key,
    required this.athleteId,
  }) : super(key: key);

  @override
  _PerformanceAnalyticsState createState() => _PerformanceAnalyticsState();
}

class _PerformanceAnalyticsState extends State<PerformanceAnalytics> {
  final AnalyticsService _analyticsService = AnalyticsService();
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Performance Analytics',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Row(
                  children: [
                    TextButton.icon(
                      icon: Icon(Icons.calendar_today),
                      label: Text(DateFormat('MMM dd').format(_startDate)),
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _startDate,
                          firstDate: DateTime.now().subtract(Duration(days: 365)),
                          lastDate: _endDate,
                        );
                        if (picked != null) {
                          setState(() {
                            _startDate = picked;
                          });
                        }
                      },
                    ),
                    Text(' - '),
                    TextButton.icon(
                      icon: Icon(Icons.calendar_today),
                      label: Text(DateFormat('MMM dd').format(_endDate)),
                      onPressed: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: _endDate,
                          firstDate: _startDate,
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _endDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            SizedBox(height: 32),
            FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
              future: _analyticsService.getPerformanceTrends(widget.athleteId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                return Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 2,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(show: true),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                              ),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  if (value.toInt() >= 0 &&
                                      value.toInt() < snapshot.data!.values.first.length) {
                                    return Text(
                                      DateFormat('MM/dd').format(
                                        snapshot.data!.values.first[value.toInt()]
                                            ['date'],
                                      ),
                                      style: TextStyle(fontSize: 10),
                                    );
                                  }
                                  return Text('');
                                },
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: true),
                          lineBarsData: snapshot.data!.entries.map((entry) {
                            Color color = Colors.primaries[
                                snapshot.data!.keys.toList().indexOf(entry.key) %
                                    Colors.primaries.length];
                            return LineChartBarData(
                              spots: entry.value
                                  .asMap()
                                  .entries
                                  .map((e) => FlSpot(
                                        e.key.toDouble(),
                                        e.value['value'].toDouble(),
                                      ))
                                  .toList(),
                              isCurved: true,
                              color: color,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(show: false),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    SizedBox(height: 16),
                    Wrap(
                      spacing: 16,
                      children: snapshot.data!.keys.map((metric) {
                        Color color = Colors.primaries[
                            snapshot.data!.keys.toList().indexOf(metric) %
                                Colors.primaries.length];
                        return Chip(
                          label: Text(metric.toUpperCase()),
                          backgroundColor: color.withOpacity(0.2),
                          avatar: CircleAvatar(
                            backgroundColor: color,
                            radius: 8,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 32),
            FutureBuilder<Map<String, dynamic>>(
              future: _analyticsService.getPerformanceSummary(
                  widget.athleteId, _startDate, _endDate),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Performance Summary',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 16),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        childAspectRatio: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: snapshot.data!['metrics'].length,
                      itemBuilder: (context, index) {
                        String metric =
                            snapshot.data!['metrics'].keys.elementAt(index);
                        Map<String, dynamic> data =
                            snapshot.data!['metrics'][metric];
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  metric.toUpperCase(),
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                Spacer(),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Avg: ${data['average'].toStringAsFixed(1)}'),
                                        Text('Max: ${data['max'].toStringAsFixed(1)}'),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Min: ${data['min'].toStringAsFixed(1)}'),
                                        Text('Count: ${data['count']}'),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 32),
            FutureBuilder<Map<String, int>>(
              future: _analyticsService.getSessionCompletionStats(widget.athleteId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                }

                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Training Session Statistics',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 16),
                    AspectRatio(
                      aspectRatio: 2,
                      child: PieChart(
                        PieChartData(
                          sections: [
                            PieChartSectionData(
                              color: Colors.green,
                              value: snapshot.data!['completed']!.toDouble(),
                              title: 'Completed',
                              radius: 100,
                            ),
                            PieChartSectionData(
                              color: Colors.red,
                              value: snapshot.data!['missed']!.toDouble(),
                              title: 'Missed',
                              radius: 100,
                            ),
                            PieChartSectionData(
                              color: Colors.orange,
                              value: snapshot.data!['cancelled']!.toDouble(),
                              title: 'Cancelled',
                              radius: 100,
                            ),
                          ],
                          sectionsSpace: 2,
                          centerSpaceRadius: 0,
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 