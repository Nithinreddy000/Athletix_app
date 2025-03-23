import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../widgets/model_viewer_plus_widget.dart';

class ModelViewerScreen extends StatefulWidget {
  final String modelUrl;
  final String title;

  const ModelViewerScreen({
    Key? key,
    required this.modelUrl,
    this.title = "3D Model Viewer",
  }) : super(key: key);

  @override
  _ModelViewerScreenState createState() => _ModelViewerScreenState();
}

class _ModelViewerScreenState extends State<ModelViewerScreen> {
  bool autoRotate = true;
  Color backgroundColor = Colors.black;
  bool isLoading = false;
  String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: Icon(autoRotate ? Icons.pause : Icons.play_arrow),
            onPressed: () {
              setState(() {
                autoRotate = !autoRotate;
              });
            },
            tooltip: autoRotate ? 'Pause rotation' : 'Start rotation',
          ),
          IconButton(
            icon: const Icon(Icons.color_lens),
            onPressed: () {
              _showBackgroundColorPicker();
            },
            tooltip: 'Change background color',
          ),
        ],
      ),
      body: Column(
        children: [
          if (errorMessage != null)
            Container(
              padding: const EdgeInsets.all(8.0),
              color: Colors.red.shade100,
              width: double.infinity,
              child: Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          Expanded(
            child: ModelViewerPlusWidget(
              modelUrl: widget.modelUrl,
              backgroundColor: backgroundColor,
              autoRotate: autoRotate,
              height: MediaQuery.of(context).size.height - 100,
              width: MediaQuery.of(context).size.width,
              onModelLoaded: (success) {
                setState(() {
                  isLoading = false;
                  errorMessage = success ? null : 'Failed to load model';
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  'Powered by Model Viewer Plus',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
                if (kIsWeb)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Web Mode: Using model-viewer web component',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showBackgroundColorPicker() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Background Color'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _colorOption(Colors.black, 'Black'),
                _colorOption(Colors.white, 'White'),
                _colorOption(Colors.grey.shade800, 'Dark Grey'),
                _colorOption(Colors.blue.shade900, 'Dark Blue'),
                _colorOption(Colors.transparent, 'Transparent'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _colorOption(Color color, String name) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      title: Text(name),
      onTap: () {
        setState(() {
          backgroundColor = color;
        });
        Navigator.of(context).pop();
      },
    );
  }
} 