import 'package:flutter/material.dart';
import '../../../../constants.dart';

class SwimmingSummary extends StatefulWidget {
  final String matchId;
  final Function(Map<String, dynamic>) onSave;

  const SwimmingSummary({
    Key? key,
    required this.matchId,
    required this.onSave,
  }) : super(key: key);

  @override
  _SwimmingSummaryState createState() => _SwimmingSummaryState();
}

class _SwimmingSummaryState extends State<SwimmingSummary> {
  final _formKey = GlobalKey<FormState>();
  
  // Form fields for each athlete
  List<Map<String, dynamic>> results = [];
  String selectedStroke = 'freestyle';
  String selectedDistance = '50m';

  final List<String> strokes = ['freestyle', 'backstroke', 'breaststroke', 'butterfly'];
  final List<String> distances = ['50m', '100m', '200m', '400m', '800m', '1500m'];
  
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Swimming Match Summary',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: defaultPadding),
          
          // Event details
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: selectedStroke,
                  decoration: const InputDecoration(
                    labelText: 'Stroke',
                    border: OutlineInputBorder(),
                  ),
                  items: strokes.map((stroke) => DropdownMenuItem(
                    value: stroke,
                    child: Text(stroke.toUpperCase()),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedStroke = value!;
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
                    });
                  },
                ),
              ),
            ],
          ),
          
          const SizedBox(height: defaultPadding * 2),
          
          // Results section
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: results.length,
            itemBuilder: (context, index) {
              final result = results[index];
              return Card(
                margin: const EdgeInsets.only(bottom: defaultPadding),
                child: Padding(
                  padding: const EdgeInsets.all(defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Athlete: ${result['athleteName']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: defaultPadding),
                      
                      // Time
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Minutes',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  result['minutes'] = int.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: defaultPadding),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Seconds',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  result['seconds'] = int.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: defaultPadding),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Milliseconds',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  result['milliseconds'] = int.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: defaultPadding),
                      
                      // Additional details
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Lane',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  result['lane'] = int.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: defaultPadding),
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Rank',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  result['rank'] = int.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: defaultPadding),
                      
                      // Split times
                      Text('Split Times', style: Theme.of(context).textTheme.titleSmall),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _getSplitCount(),
                        itemBuilder: (context, splitIndex) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: '${(splitIndex + 1) * 50}m Split',
                                border: const OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  if (result['splits'] == null) {
                                    result['splits'] = List.filled(_getSplitCount(), 0.0);
                                  }
                                  result['splits'][splitIndex] = double.tryParse(value) ?? 0.0;
                                });
                              },
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: defaultPadding * 2),
          
          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saveSummary,
              child: const Text('Save Summary'),
            ),
          ),
        ],
      ),
    );
  }

  int _getSplitCount() {
    final distance = int.parse(selectedDistance.replaceAll('m', ''));
    return (distance ~/ 50) - 1; // -1 because we don't need split for the final length
  }

  void _saveSummary() {
    if (_formKey.currentState!.validate()) {
      final summary = {
        'matchId': widget.matchId,
        'stroke': selectedStroke,
        'distance': selectedDistance,
        'results': results,
      };
      widget.onSave(summary);
    }
  }
} 