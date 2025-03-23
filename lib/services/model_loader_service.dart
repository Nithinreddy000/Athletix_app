import 'dart:async';

/// Service for handling 3D model loading operations and notifications
class ModelLoaderService {
  // Stream controller to broadcast model loading status
  final StreamController<ModelLoadEvent> _modelLoadController = 
      StreamController<ModelLoadEvent>.broadcast();
  
  // Public stream that can be listened to
  Stream<ModelLoadEvent> get modelLoadStream => _modelLoadController.stream;
  
  // Map to track loading status of models
  final Map<String, bool> _modelLoadStatus = {};
  
  /// Notify that a model has been loaded or failed to load
  void notifyModelLoaded(String modelUrl, bool success) {
    _modelLoadStatus[modelUrl] = success;
    _modelLoadController.add(
      ModelLoadEvent(
        modelUrl: modelUrl,
        success: success,
      ),
    );
  }
  
  /// Check if a model is already loaded
  bool isModelLoaded(String modelUrl) {
    return _modelLoadStatus[modelUrl] == true;
  }
  
  /// Get a future that completes when the specified model is loaded
  Future<bool> waitForModelLoad(String modelUrl, {Duration timeout = const Duration(seconds: 30)}) {
    // If model is already loaded, return immediately
    if (_modelLoadStatus[modelUrl] == true) {
      return Future.value(true);
    }
    
    // Otherwise, listen to the stream for this model
    final completer = Completer<bool>();
    late StreamSubscription subscription;
    
    // Set up a timeout
    Timer? timeoutTimer;
    if (timeout != Duration.zero) {
      timeoutTimer = Timer(timeout, () {
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete(false);
        }
      });
    }
    
    subscription = modelLoadStream.listen((event) {
      if (event.modelUrl == modelUrl) {
        if (!completer.isCompleted) {
          timeoutTimer?.cancel();
          subscription.cancel();
          completer.complete(event.success);
        }
      }
    });
    
    return completer.future;
  }
  
  /// Dispose of the service resources
  void dispose() {
    _modelLoadController.close();
  }
}

/// Event class for model loading notifications
class ModelLoadEvent {
  final String modelUrl;
  final bool success;
  
  ModelLoadEvent({
    required this.modelUrl,
    required this.success,
  });
} 