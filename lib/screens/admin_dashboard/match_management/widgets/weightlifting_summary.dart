import 'package:flutter/material.dart';
import '../../../../constants.dart';

class WeightliftingSummary extends StatefulWidget {
  final String matchId;
  final Function(Map<String, dynamic>) onSave;

  const WeightliftingSummary({
    Key? key,
    required this.matchId,
    required this.onSave,
  }) : super(key: key);

  @override
  _WeightliftingSummaryState createState() => _WeightliftingSummaryState();
}

class _WeightliftingSummaryState extends State<WeightliftingSummary> {
  final _formKey = GlobalKey<FormState>();
  
  // Form fields for each athlete
  List<Map<String, dynamic>> attempts = [];
  
  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Weightlifting Match Summary',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: defaultPadding),
          
          // Athlete attempts section
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: attempts.length,
            itemBuilder: (context, index) {
              final attempt = attempts[index];
              return Card(
                margin: const EdgeInsets.only(bottom: defaultPadding),
                child: Padding(
                  padding: const EdgeInsets.all(defaultPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Athlete: ${attempt['athleteName']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: defaultPadding),
                      
                      // Snatch attempts
                      Text('Snatch Attempts', style: Theme.of(context).textTheme.titleSmall),
                      Row(
                        children: List.generate(3, (i) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Attempt ${i + 1}',
                                suffixText: 'kg',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  attempt['snatch'][i] = double.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                        )),
                      ),
                      
                      const SizedBox(height: defaultPadding),
                      
                      // Clean & Jerk attempts
                      Text('Clean & Jerk Attempts', style: Theme.of(context).textTheme.titleSmall),
                      Row(
                        children: List.generate(3, (i) => Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: TextFormField(
                              decoration: InputDecoration(
                                labelText: 'Attempt ${i + 1}',
                                suffixText: 'kg',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  attempt['cleanAndJerk'][i] = double.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                        )),
                      ),
                      
                      const SizedBox(height: defaultPadding),
                      
                      // Total and ranking
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Total',
                                suffixText: 'kg',
                              ),
                              readOnly: true,
                              initialValue: _calculateTotal(attempt).toString(),
                            ),
                          ),
                          const SizedBox(width: defaultPadding),
                          Expanded(
                            child: TextFormField(
                              decoration: const InputDecoration(
                                labelText: 'Rank',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                setState(() {
                                  attempt['rank'] = int.tryParse(value) ?? 0;
                                });
                              },
                            ),
                          ),
                        ],
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

  double _calculateTotal(Map<String, dynamic> attempt) {
    final bestSnatch = (attempt['snatch'] as List).reduce((a, b) => a > b ? a : b);
    final bestCleanAndJerk = (attempt['cleanAndJerk'] as List).reduce((a, b) => a > b ? a : b);
    return bestSnatch + bestCleanAndJerk;
  }

  void _saveSummary() {
    if (_formKey.currentState!.validate()) {
      final summary = {
        'matchId': widget.matchId,
        'attempts': attempts,
      };
      widget.onSave(summary);
    }
  }
} 