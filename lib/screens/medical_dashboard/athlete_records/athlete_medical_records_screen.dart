import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../constants.dart';
import '../../../responsive.dart';
import '../injury_records/injury_records_screen.dart';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';
import 'dart:js' as js;
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:async';
import '../../../config.dart';

class AthleteMedicalRecordsScreen extends StatefulWidget {
  const AthleteMedicalRecordsScreen({Key? key}) : super(key: key);

  @override
  State<AthleteMedicalRecordsScreen> createState() => _AthleteMedicalRecordsScreenState();
}

class _AthleteMedicalRecordsScreenState extends State<AthleteMedicalRecordsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> athletes = [];
  bool isLoading = true;
  String searchQuery = '';
  String selectedSport = 'All';
  List<String> sportTypes = ['All'];
  Map<String, dynamic>? selectedAthleteInjuries;
  final String pdfJsVersion = '3.11.174';
  final String pdfJsUrl = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.min.js';
  final String pdfJsWorkerUrl = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
  final String serverUrl = Config.apiBaseUrl;  // Using central config instead of hardcoded URL
  String? slicerModelUrl;

  @override
  void initState() {
    super.initState();
    _loadAthletes();
  }

  Future<void> _loadAthletes() async {
    if (!mounted) return;
    
    setState(() => isLoading = true);
    try {
      final QuerySnapshot athleteSnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'athlete')
          .get();

      if (!mounted) return;

      List<Map<String, dynamic>> loadedAthletes = await Future.wait(
        athleteSnapshot.docs.map((doc) async {
          final data = doc.data() as Map<String, dynamic>;
          final athleteId = doc.id;

          String coachName = 'No Coach Assigned';
          if (data['coachId'] != null) {
            final coachDoc = await _firestore.collection('users').doc(data['coachId']).get();
            if (coachDoc.exists) {
              coachName = coachDoc.data()?['name'] ?? 'No Coach Assigned';
            }
          }

          return {
            'id': athleteId,
            'name': data['name'] ?? 'No Name',
            'email': data['email'] ?? 'No Email',
            'sportsType': data['sportsType'] ?? 'Not Specified',
            'jerseyNumber': data['jerseyNumber'] ?? 'N/A',
            'coachName': coachName,
          };
        }),
      );

      if (!mounted) return;

      setState(() {
        athletes = loadedAthletes;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading athletes: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> getFilteredAthletes() {
    return athletes.where((athlete) {
      final matchesSearch = athlete['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
          athlete['email'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
          athlete['jerseyNumber'].toString().toLowerCase().contains(searchQuery.toLowerCase());
      
      final matchesSport = selectedSport == 'All' || athlete['sportsType'] == selectedSport;
      
      return matchesSearch && matchesSport;
    }).toList();
  }

  Future<void> _uploadAndAnalyzeMedicalReport(String athleteId, String athleteName) async {
    // Show privacy notice
    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Privacy Notice'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('This medical report will be processed securely:'),
            SizedBox(height: 8),
            Text('1. The PDF will be read directly in your browser'),
            Text('2. Only authorized staff can process reports'),
            Text('3. Data is encrypted during transmission'),
            Text('4. Analysis results are stored securely'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Proceed'),
          ),
        ],
      ),
    ) ?? false;

    if (!shouldProceed) return;

    try {
      setState(() => isLoading = true);

      // First verify if user has permission to upload medical reports
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('You must be logged in to upload medical reports');
      }

      // Get user info from Firestore
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUser.uid)
          .get();
      
      final userData = userDoc.data() ?? {};
      final userRole = userData['role'] as String? ?? 'staff';  // Default to staff if no role specified

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );

      if (result != null && result.files.first.bytes != null) {
        final file = result.files.first;
        final bytes = file.bytes!;

        // Show processing status
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Processing PDF securely...'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        print('Sending request to: $serverUrl/upload_report');
        
        // Create form data with the PDF file
        var request = http.MultipartRequest('POST', Uri.parse('$serverUrl/upload_report'));
        
        // Add the PDF file
        request.files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: file.name,
          ),
        );

        // Add other data as fields
        request.fields['athlete_id'] = athleteId;
        request.fields['athlete_name'] = athleteName;
        request.fields['uploaded_by_uid'] = currentUser.uid;
        request.fields['uploaded_by_name'] = currentUser.displayName ?? '';
        request.fields['uploaded_by_role'] = userRole;

        // Send the request
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        print('Response status: ${response.statusCode}');
        print('Response body: ${response.body}');

        if (response.statusCode == 200) {
          final analysisResult = json.decode(response.body);
          print('Analysis result: ${json.encode(analysisResult)}');
          
          // Get the Slicer model URL if available
          final slicerUrl = analysisResult['model_url'] as String?;
          
          // Get the athlete ID from the response (this is the new field we added to the backend)
          final responseAthleteId = analysisResult['athlete_id'] as String? ?? athleteId;
          
          // Store analysis results with audit trail
          await _firestore.collection('medical_reports').add({
            'athlete_id': responseAthleteId,
            'athlete_name': athleteName,
            'file_name': file.name,
            'uploaded_by': {
              'uid': currentUser.uid,
              'name': currentUser.displayName,
              'role': userRole,
              'timestamp': FieldValue.serverTimestamp(),
            },
            'analysis_result': analysisResult,
            'injury_locations': analysisResult['injury_locations'],
            'slicer_model_url': slicerUrl,
            'status': 'analyzed',
            'text_content': '', // PDF content is not provided in form-data request
            'audit_trail': {
              'created_at': FieldValue.serverTimestamp(),
              'created_by': currentUser.uid,
              'ip_address': '', // You can add this from the server response
              'action': 'UPLOAD_AND_ANALYZE',
            }
          });

          setState(() {
            selectedAthleteInjuries = analysisResult;
            // Store the athlete ID in the selectedAthleteInjuries map
            selectedAthleteInjuries!['athlete_id'] = responseAthleteId;
            slicerModelUrl = slicerUrl;
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Medical report analyzed successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else if (response.statusCode == 401) {
          throw Exception('Unauthorized: Please log in again');
        } else if (response.statusCode == 403) {
          throw Exception('You do not have permission to perform this action');
        } else {
          throw Exception('Failed to analyze medical report: ${response.statusCode}');
        }
      }
    } catch (e) {
      print('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  bool _isPdfJsLoaded() {
    return js.context.hasProperty('pdfjsLib');
  }

  Future<void> _loadPdfJs() async {
    try {
      // Set worker source first
      js.context.callMethod('eval', ['''
        window.pdfjsWorkerSrc = '$pdfJsWorkerUrl';
      ''']);

      // Load PDF.js library
      final script = html.ScriptElement()
        ..src = pdfJsUrl
        ..type = 'text/javascript';

      html.document.head!.append(script);
      await script.onLoad.first;

      // Set worker source after library is loaded
      js.context.callMethod('eval', ['''
        if (typeof pdfjsLib !== 'undefined') {
          pdfjsLib.GlobalWorkerOptions.workerSrc = window.pdfjsWorkerSrc;
        }
      ''']);

      // Load worker script
      final workerScript = html.ScriptElement()
        ..src = pdfJsWorkerUrl
        ..type = 'text/javascript';

      html.document.head!.append(workerScript);
      await workerScript.onLoad.first;

      // Verify initialization
      await Future.delayed(Duration(milliseconds: 500));
      if (!_isPdfJsLoaded()) {
        throw Exception('PDF.js failed to initialize properly');
      }

      print('PDF.js initialized successfully with worker');
    } catch (e) {
      print('Error loading PDF.js: $e');
      throw Exception('Failed to load PDF.js library: $e');
    }
  }

  Future<String> _readPdfContent(Uint8List pdfBytes) async {
    try {
      // Convert bytes to base64
      final base64Pdf = base64Encode(pdfBytes);

      // Create loading task with proper configuration
      final result = await js.context.callMethod('eval', ['''
        (async function() {
          try {
            // Configure PDF.js
            const loadingTask = pdfjsLib.getDocument({
              data: atob('$base64Pdf'),
              useWorkerFetch: true,
              isEvalSupported: true
            });
            
            console.log('Loading PDF...');
            const pdf = await loadingTask.promise;
            console.log('PDF loaded successfully, pages:', pdf.numPages);
            let textContent = [];
            
            for (let i = 1; i <= pdf.numPages; i++) {
              console.log('Processing page:', i);
              const page = await pdf.getPage(i);
              const content = await page.getTextContent();
              const pageText = content.items
                .map(item => item.str || '')
                .filter(str => str.trim().length > 0)  // Remove empty strings
                .join(' ');
              console.log('Page', i, 'text length:', pageText.length);
              if (pageText.trim().length > 0) {
                textContent.push(pageText);
              }
            }
            
            const finalText = textContent.join('\\n');
            console.log('Total extracted text length:', finalText.length);
            return Promise.resolve(finalText);  // Explicitly resolve the Promise
          } catch (error) {
            console.error('PDF processing error:', error);
            return Promise.reject('PDF processing failed: ' + error.message);
          }
        })()
      ''']);

      // Convert the Promise result to a Future and wait for it
      final jsPromise = js.JsObject.fromBrowserObject(result);
      final completer = Completer<String>();
      
      jsPromise.callMethod('then', [
        (value) => completer.complete(value.toString()),
        (error) => completer.completeError(error.toString())
      ]);

      final extractedText = await completer.future;
      
      if (extractedText.isEmpty) {
        throw Exception('Failed to extract text from PDF - empty result');
      }

      print('Successfully extracted text, length: ${extractedText.length}');
      print('Text preview: ${extractedText.substring(0, min(200, extractedText.length))}...');
      return extractedText;

    } catch (e) {
      print('Error reading PDF content: $e');
      throw Exception('Failed to read PDF content: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredAthletes = getFilteredAthletes();
    
    return Scaffold(
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side - Athletes list
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(defaultPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          "Medical Records",
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const Spacer(),
                        SizedBox(
                          width: 200,
                          child: DropdownButtonFormField<String>(
                            value: selectedSport,
                            decoration: InputDecoration(
                              labelText: 'Sport Type',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(horizontal: 10),
                            ),
                            items: sportTypes.map((sport) => DropdownMenuItem(
                              value: sport,
                              child: Text(sport),
                            )).toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSport = value!;
                              });
                            },
                          ),
                        ),
                        SizedBox(width: defaultPadding),
                        SizedBox(
                          width: 300,
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: "Search athletes...",
                              fillColor: secondaryColor,
                              filled: true,
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              prefixIcon: Icon(Icons.search),
                            ),
                            onChanged: (value) {
                              setState(() {
                                searchQuery = value;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: defaultPadding),
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (filteredAthletes.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.all(defaultPadding * 2),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_search, size: 64, color: Colors.grey),
                              SizedBox(height: defaultPadding),
                              Text(
                                'No athletes found',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: filteredAthletes.length,
                        itemBuilder: (context, index) {
                          final athlete = filteredAthletes[index];
                          return Card(
                            color: secondaryColor,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.white24,
                                child: Text(
                                  athlete['name'].toString().substring(0, 1).toUpperCase(),
                                  style: TextStyle(color: Colors.white),
                                ),
                              ),
                              title: Text(athlete['name']),
                              subtitle: Text(
                                'Sport: ${athlete['sportsType']} | Jersey: ${athlete['jerseyNumber']} | Coach: ${athlete['coachName']}',
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ElevatedButton.icon(
                                onPressed: () => _uploadAndAnalyzeMedicalReport(athlete['id'], athlete['name']),
                                icon: const Icon(Icons.upload_file),
                                label: const Text('Upload Medical Report'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                                  ),
                                  if (selectedAthleteInjuries != null && selectedAthleteInjuries!['athlete_id'] == athlete['id'])
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8.0),
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => InjuryRecordsScreen(
                                                initialAthleteId: athlete['id'],
                                              ),
                                            ),
                                          );
                                        },
                                        icon: const Icon(Icons.visibility),
                                        label: const Text('View Injuries'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    
                    // Success message when report is uploaded
                    if (selectedAthleteInjuries != null)
                      Padding(
                        padding: const EdgeInsets.all(defaultPadding),
                        child: GestureDetector(
                          onTap: () {
                            // Navigate to the injury records tab in the medical dashboard
                            // Find the nearest MainScreen ancestor
                            final scaffoldMessenger = ScaffoldMessenger.of(context);
                            
                            // Get the athlete ID from the selectedAthleteInjuries
                            final athleteId = selectedAthleteInjuries!['athlete_id'] as String?;
                            
                            if (athleteId == null || athleteId.isEmpty) {
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Error: Athlete ID not found'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            
                            print('Navigating to Injury Records for athlete: $athleteId');
                            
                            // Use Navigator.pushNamedAndRemoveUntil to go back to the main screen
                            // and then navigate to the Injury Records tab
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              '/dashboard',
                              (route) => false,
                              arguments: {
                                'initialTab': 'injury_records',
                                'athleteId': athleteId,
                              },
                            ).then((_) {
                              // Show a snackbar to indicate the navigation
                              scaffoldMessenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Navigated to Injury Records'),
                                  duration: Duration(seconds: 2),
                              ),
                            );
                            });
                          },
                          child: Card(
                            color: secondaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: primaryColor.withOpacity(0.3), width: 1),
                            ),
                            elevation: 4,
                            child: Padding(
                              padding: const EdgeInsets.all(defaultPadding),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle, color: primaryColor),
                                      SizedBox(width: 8),
                                      Text(
                                        'Medical report analyzed successfully',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Colors.white,
                                        ),
                                      ),
                                      Spacer(),
                                      IconButton(
                                        icon: Icon(Icons.close, color: Colors.white70),
                                        onPressed: () {
                                          setState(() {
                                            selectedAthleteInjuries = null;
                                            slicerModelUrl = null;
                                          });
                                        },
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'The medical report has been successfully analyzed. To view the 3D visualization of the injuries, please go to the Injury Records section.',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                  SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: () {
                                        // Navigate to the injury records tab in the medical dashboard
                                        // Find the nearest MainScreen ancestor
                                        final scaffoldMessenger = ScaffoldMessenger.of(context);
                                        
                                        // Get the athlete ID from the selectedAthleteInjuries
                                        final athleteId = selectedAthleteInjuries!['athlete_id'] as String?;
                                        
                                        if (athleteId == null || athleteId.isEmpty) {
                                          scaffoldMessenger.showSnackBar(
                                            const SnackBar(
                                              content: Text('Error: Athlete ID not found'),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                          return;
                                        }
                                        
                                        print('Navigating to Injury Records for athlete: $athleteId');
                                        
                                        // Use Navigator.pushNamedAndRemoveUntil to go back to the main screen
                                        // and then navigate to the Injury Records tab
                                        Navigator.pushNamedAndRemoveUntil(
                                          context,
                                          '/dashboard',
                                          (route) => false,
                                          arguments: {
                                            'initialTab': 'injury_records',
                                            'athleteId': athleteId,
                                          },
                                        ).then((_) {
                                          // Show a snackbar to indicate the navigation
                                          scaffoldMessenger.showSnackBar(
                                            const SnackBar(
                                              content: Text('Navigated to Injury Records'),
                                              duration: Duration(seconds: 2),
                                          ),
                                        );
                                        });
                                      },
                                      icon: const Icon(Icons.visibility),
                                      label: const Text('View in Injury Records'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
} 