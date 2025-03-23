import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../../constants.dart';
import '../../../../services/medical_report_service.dart';

class AddMedicalReportForm extends StatefulWidget {
  final String athleteId;
  final Function onReportAdded;

  const AddMedicalReportForm({
    Key? key,
    required this.athleteId,
    required this.onReportAdded,
  }) : super(key: key);

  @override
  _AddMedicalReportFormState createState() => _AddMedicalReportFormState();
}

class _AddMedicalReportFormState extends State<AddMedicalReportForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _diagnosisController = TextEditingController();
  
  PlatformFile? _pdfFile;
  PlatformFile? _modelFile;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _pickPDFFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        setState(() {
          _pdfFile = result.files.first;
        });
      }
    } catch (e) {
      print('Error picking PDF file: $e');
      setState(() {
        _errorMessage = 'Error picking PDF file';
      });
    }
  }

  Future<void> _pick3DModelFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['glb', 'gltf'],
      );

      if (result != null) {
        setState(() {
          _modelFile = result.files.first;
        });
      }
    } catch (e) {
      print('Error picking 3D model file: $e');
      setState(() {
        _errorMessage = 'Error picking 3D model file';
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate() || _pdfFile == null) {
      setState(() {
        _errorMessage = 'Please fill all required fields and upload a PDF file';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final medicalReportService = MedicalReportService();
      final result = await medicalReportService.uploadMedicalReport(
        athleteId: widget.athleteId,
        reportTitle: _titleController.text,
        diagnosis: _diagnosisController.text,
        pdfBytes: _pdfFile!.bytes!,
        modelBytes: _modelFile?.bytes,
        modelFileName: _modelFile?.name,
      );

      if (result['success']) {
        widget.onReportAdded();
        Navigator.of(context).pop();
      } else {
        setState(() {
          _errorMessage = 'Failed to upload report: ${result['error']}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error uploading report: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(defaultPadding),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Add Medical Report',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: defaultPadding),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Report Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: defaultPadding),
            TextFormField(
              controller: _diagnosisController,
              decoration: InputDecoration(
                labelText: 'Diagnosis',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a diagnosis';
                }
                return null;
              },
            ),
            const SizedBox(height: defaultPadding),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickPDFFile,
                    icon: Icon(Icons.upload_file),
                    label: Text(_pdfFile != null ? 'PDF Selected' : 'Upload PDF'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: defaultPadding),
                    ),
                  ),
                ),
                SizedBox(width: defaultPadding),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pick3DModelFile,
                    icon: Icon(Icons.view_in_ar),
                    label: Text(_modelFile != null ? '3D Model Selected' : 'Upload 3D Model'),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: defaultPadding),
                    ),
                  ),
                ),
              ],
            ),
            if (_pdfFile != null) ...[
              const SizedBox(height: defaultPadding / 2),
              Text(
                'Selected PDF: ${_pdfFile!.name}',
                style: TextStyle(color: Colors.green),
              ),
            ],
            if (_modelFile != null) ...[
              const SizedBox(height: defaultPadding / 2),
              Text(
                'Selected 3D Model: ${_modelFile!.name}',
                style: TextStyle(color: Colors.green),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: defaultPadding),
              Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: defaultPadding),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Submit Report'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: defaultPadding),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _diagnosisController.dispose();
    super.dispose();
  }
} 