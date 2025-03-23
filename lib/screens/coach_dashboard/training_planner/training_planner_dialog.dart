import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../constants.dart';

class TrainingPlannerDialog extends StatefulWidget {
  final String athleteId;

  const TrainingPlannerDialog({Key? key, required this.athleteId}) : super(key: key);

  @override
  _TrainingPlannerDialogState createState() => _TrainingPlannerDialogState();
}

class _TrainingPlannerDialogState extends State<TrainingPlannerDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _templates = [];
  bool _isLoading = true;
  bool _isCustom = false;

  String? _selectedTemplate;
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(Duration(days: 7));
  TextEditingController _titleController = TextEditingController();
  TextEditingController _descriptionController = TextEditingController();
  List<ExerciseItem> _exercises = [ExerciseItem()];

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTemplates() async {
    try {
      final templates = await _firestore.collection('training_templates').get();
      setState(() {
        _templates = templates.docs
            .map((doc) => {
                  'id': doc.id,
                  ...doc.data(),
                })
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading templates: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _assignTraining() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final trainingData = {
        'athleteId': widget.athleteId,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'startDate': _startDate,
        'endDate': _endDate,
        'exercises': _exercises
            .map((exercise) => {
                  'name': exercise.nameController.text,
                  'sets': int.parse(exercise.setsController.text),
                  'reps': int.parse(exercise.repsController.text),
                  'notes': exercise.notesController.text,
                })
            .toList(),
        'templateId': _isCustom ? null : _selectedTemplate,
        'status': 'assigned',
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('training_plans').add(trainingData);

      // Create notification for athlete
      await _firestore.collection('notifications').add({
        'recipientId': widget.athleteId,
        'type': 'training_assigned',
        'title': 'New Training Plan Assigned',
        'message': 'You have been assigned a new training plan: ${_titleController.text}',
        'read': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      Navigator.of(context).pop();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error assigning training plan: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Assign Training Plan'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isLoading)
                Center(child: CircularProgressIndicator())
              else ...[
                Row(
                  children: [
                    Text('Custom Plan'),
                    Switch(
                      value: _isCustom,
                      onChanged: (value) {
                        setState(() {
                          _isCustom = value;
                          if (!value && _templates.isNotEmpty) {
                            _selectedTemplate = _templates.first['id'];
                          }
                        });
                      },
                    ),
                  ],
                ),
                if (!_isCustom && _templates.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedTemplate ?? _templates.first['id'],
                    items: _templates.map<DropdownMenuItem<String>>((template) {
                      return DropdownMenuItem<String>(
                        value: template['id'],
                        child: Text(template['title']),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedTemplate = value;
                      });
                    },
                    decoration: InputDecoration(labelText: 'Select Template'),
                  )
                else ...[
                  TextFormField(
                    controller: _titleController,
                    decoration: InputDecoration(labelText: 'Title'),
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please enter a title' : null,
                  ),
                  SizedBox(height: defaultPadding),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  SizedBox(height: defaultPadding),
                  Text('Exercises', style: Theme.of(context).textTheme.titleMedium),
                  ..._exercises.map((exercise) => _buildExerciseItem(exercise)).toList(),
                  TextButton.icon(
                    icon: Icon(Icons.add),
                    label: Text('Add Exercise'),
                    onPressed: () {
                      setState(() {
                        _exercises.add(ExerciseItem());
                      });
                    },
                  ),
                ],
                SizedBox(height: defaultPadding),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: Icon(Icons.calendar_today),
                        label: Text('Start Date'),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              _startDate = date;
                            });
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: Icon(Icons.calendar_today),
                        label: Text('End Date'),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate,
                            firstDate: _startDate,
                            lastDate: DateTime.now().add(Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              _endDate = date;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _assignTraining,
          child: Text('Assign'),
        ),
      ],
    );
  }

  Widget _buildExerciseItem(ExerciseItem exercise) {
    return Card(
      margin: EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: EdgeInsets.all(8),
        child: Column(
          children: [
            TextFormField(
              controller: exercise.nameController,
              decoration: InputDecoration(labelText: 'Exercise Name'),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter exercise name' : null,
            ),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: exercise.setsController,
                    decoration: InputDecoration(labelText: 'Sets'),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Enter sets' : null,
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: exercise.repsController,
                    decoration: InputDecoration(labelText: 'Reps'),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Enter reps' : null,
                  ),
                ),
              ],
            ),
            TextFormField(
              controller: exercise.notesController,
              decoration: InputDecoration(labelText: 'Notes'),
              maxLines: 2,
            ),
            if (_exercises.length > 1)
              TextButton.icon(
                icon: Icon(Icons.delete),
                label: Text('Remove'),
                onPressed: () {
                  setState(() {
                    _exercises.remove(exercise);
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}

class ExerciseItem {
  final nameController = TextEditingController();
  final setsController = TextEditingController();
  final repsController = TextEditingController();
  final notesController = TextEditingController();
}
