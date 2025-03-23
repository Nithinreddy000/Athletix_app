import 'package:flutter/material.dart';
import '../../../services/medical_report_service.dart';
import 'package:file_picker/file_picker.dart';

class AthleteRecordsScreen extends StatefulWidget {
  final String athleteId;
  final String athleteName;

  const AthleteRecordsScreen({
    Key? key,
    required this.athleteId,
    required this.athleteName,
  }) : super(key: key);

  @override
  _AthleteRecordsScreenState createState() => _AthleteRecordsScreenState();
}

class _AthleteRecordsScreenState extends State<AthleteRecordsScreen> {
  final MedicalReportService _reportService = MedicalReportService();
  bool _isUploading = false;
  String? _uploadError;
  bool _showSuccess = false;

  Future<void> _uploadReport() async {
    try {
      setState(() {
        _isUploading = true;
        _uploadError = null;
        _showSuccess = false;
      });

      // Pick PDF file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isUploading = false);
        return;
      }

      final file = result.files.first;
      if (file.bytes == null) {
        throw Exception('Could not read file');
      }

      // Upload report
      await _reportService.uploadMedicalReport(
        athleteId: widget.athleteId,
        title: 'Medical Report ${DateTime.now()}',
        diagnosis: 'Pending review',
        pdfBytes: file.bytes!,
      );

      setState(() {
        _isUploading = false;
        _showSuccess = true;
      });

      // Show success snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medical report uploaded successfully'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.athleteName} - Medical Records'),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600),
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isUploading) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Uploading medical report...'),
                  ] else if (_showSuccess) ...[
                    const Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Report uploaded successfully!',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'You can view the 3D visualization in the Injury Records section.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        setState(() => _showSuccess = false);
                      },
                      child: const Text('Upload Another Report'),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.upload_file,
                      size: 48,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Upload Medical Report',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a PDF file containing the medical report',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _uploadReport,
                      icon: const Icon(Icons.file_upload),
                      label: const Text('Choose File'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 16,
                        ),
                      ),
                    ),
                    if (_uploadError != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _uploadError!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 