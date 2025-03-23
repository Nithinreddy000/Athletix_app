// This is a stub file that provides the same interface as dart:html for non-web platforms
import 'dart:async';

class CssStyleDeclaration {
  String position = '';
  String top = '';
  String left = '';
  String width = '';
  String height = '';
  String backgroundColor = '';
  String zIndex = '';
  String display = '';
  String justifyContent = '';
  String alignItems = '';
  String flexDirection = '';
  String padding = '';
  String borderRadius = '';
  String marginTop = '';
  String gap = '';
  String color = '';
  String border = '';
  String cursor = '';
}

class Element {
  CssStyleDeclaration style = CssStyleDeclaration();
  List<Element> children = [];
  
  void append(Element child) {
    children.add(child);
  }
  
  void remove() {
    // Implementation for non-web platforms
  }
}

class DivElement extends Element {
  DivElement();
}

class VideoElement extends Element {
  VideoElement();
  bool autoplay = false;
  dynamic srcObject;
  int videoWidth = 0;
  int videoHeight = 0;
}

class ButtonElement extends Element {
  ButtonElement();
  String text = '';
  StreamController<void> _onClick = StreamController<void>.broadcast();
  Stream<void> get onClick => _onClick.stream;
}

class CanvasElement extends Element {
  CanvasElement({this.width, this.height});
  final int? width;
  final int? height;
  
  CanvasRenderingContext2D? get context2D => CanvasRenderingContext2D();
  
  Future<Blob> toBlob(String type, double quality) async {
    return Blob([], {'type': type});
  }
}

class CanvasRenderingContext2D {
  void drawImage(VideoElement source, int x, int y) {
    // Implementation for non-web platforms
  }
}

class FileReader {
  dynamic result;
  StreamController<void> _onLoad = StreamController<void>.broadcast();
  Stream<void> get onLoad => _onLoad.stream;
  
  void readAsDataUrl(Blob blob) {
    // Implementation for non-web platforms
  }
}

class Blob {
  Blob(List<dynamic> array, Map<String, String> options);
}

class MediaStream {
  List<MediaStreamTrack> getTracks() => [];
}

class MediaStreamTrack {
  void stop() {
    // Implementation for non-web platforms
  }
}

class MediaDevices {
  Future<MediaStream?> getUserMedia(Map<String, dynamic> constraints) async {
    throw UnsupportedError('getUserMedia() is only supported on web platforms.');
  }
}

class Navigator {
  MediaDevices? get mediaDevices => MediaDevices();
}

class Window {
  Navigator get navigator => Navigator();
}

class Document extends Element {
  Element? get body => null;
  
  Element createElement(String tagName) {
    switch (tagName) {
      case 'div':
        return DivElement();
      case 'video':
        return VideoElement();
      case 'button':
        return ButtonElement();
      case 'canvas':
        return CanvasElement();
      default:
        throw UnsupportedError('Unsupported element: $tagName');
    }
  }
}

Window window = Window();
Document document = Document(); 