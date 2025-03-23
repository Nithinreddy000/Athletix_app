import 'package:flutter/material.dart';

class AthleteStatisticsScreen extends StatefulWidget {
  final String userId;
  
  const AthleteStatisticsScreen({Key? key, required this.userId}) : super(key: key);

  @override
  State<AthleteStatisticsScreen> createState() => _AthleteStatisticsScreenState();
}

class _AthleteStatisticsScreenState extends State<AthleteStatisticsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Athlete Statistics'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Statistics for athlete ID: ${widget.userId}'),
            // We'll add more statistics widgets here later
          ],
        ),
      ),
    );
  }
} 