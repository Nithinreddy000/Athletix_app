import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AnnotationService {
  final FirebaseFirestore _firestore;
  final String sessionId;

  AnnotationService({
    required this.sessionId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // Save annotation
  Future<void> saveAnnotation(DrawingAnnotation annotation) async {
    await _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('annotations')
        .add(annotation.toJson());
  }

  // Get annotations for a specific frame
  Stream<List<DrawingAnnotation>> getAnnotationsForFrame(int frameIndex) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('annotations')
        .where('frameIndex', isEqualTo: frameIndex)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DrawingAnnotation.fromJson(doc.data()))
            .toList());
  }

  // Delete annotation
  Future<void> deleteAnnotation(String annotationId) async {
    await _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('annotations')
        .doc(annotationId)
        .delete();
  }
}

class DrawingAnnotation {
  final String? id;
  final int frameIndex;
  final AnnotationType type;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final String? text;
  final Offset? textPosition;

  DrawingAnnotation({
    this.id,
    required this.frameIndex,
    required this.type,
    required this.points,
    required this.color,
    this.strokeWidth = 2.0,
    this.text,
    this.textPosition,
  });

  Map<String, dynamic> toJson() {
    return {
      'frameIndex': frameIndex,
      'type': type.toString(),
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': color.value,
      'strokeWidth': strokeWidth,
      'text': text,
      'textPosition': textPosition != null
          ? {'x': textPosition!.dx, 'y': textPosition!.dy}
          : null,
    };
  }

  factory DrawingAnnotation.fromJson(Map<String, dynamic> json) {
    return DrawingAnnotation(
      id: json['id'],
      frameIndex: json['frameIndex'] as int,
      type: AnnotationType.values.firstWhere(
        (e) => e.toString() == json['type'],
      ),
      points: (json['points'] as List).map((p) {
        return Offset(p['x'] as double, p['y'] as double);
      }).toList(),
      color: Color(json['color'] as int),
      strokeWidth: json['strokeWidth'] as double,
      text: json['text'] as String?,
      textPosition: json['textPosition'] != null
          ? Offset(
              json['textPosition']['x'] as double,
              json['textPosition']['y'] as double,
            )
          : null,
    );
  }
}

enum AnnotationType {
  freehand,
  line,
  arrow,
  circle,
  rectangle,
  text,
  angle,
}

class AnnotationPainter extends CustomPainter {
  final List<DrawingAnnotation> annotations;
  final DrawingAnnotation? currentAnnotation;

  AnnotationPainter({
    required this.annotations,
    this.currentAnnotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw saved annotations
    for (final annotation in annotations) {
      _drawAnnotation(canvas, size, annotation);
    }

    // Draw current annotation if exists
    if (currentAnnotation != null) {
      _drawAnnotation(canvas, size, currentAnnotation!);
    }
  }

  void _drawAnnotation(Canvas canvas, Size size, DrawingAnnotation annotation) {
    final paint = Paint()
      ..color = annotation.color
      ..strokeWidth = annotation.strokeWidth
      ..style = PaintingStyle.stroke;

    switch (annotation.type) {
      case AnnotationType.freehand:
        _drawFreehand(canvas, annotation.points, paint);
        break;
      case AnnotationType.line:
        _drawLine(canvas, annotation.points, paint);
        break;
      case AnnotationType.arrow:
        _drawArrow(canvas, annotation.points, paint);
        break;
      case AnnotationType.circle:
        _drawCircle(canvas, annotation.points, paint);
        break;
      case AnnotationType.rectangle:
        _drawRectangle(canvas, annotation.points, paint);
        break;
      case AnnotationType.text:
        _drawText(canvas, annotation.text!, annotation.textPosition!, paint);
        break;
      case AnnotationType.angle:
        _drawAngle(canvas, annotation.points, paint);
        break;
    }
  }

  void _drawFreehand(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    
    final path = Path()..moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    canvas.drawPath(path, paint);
  }

  void _drawLine(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    canvas.drawLine(points.first, points.last, paint);
  }

  void _drawArrow(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    
    final start = points.first;
    final end = points.last;
    
    // Draw main line
    canvas.drawLine(start, end, paint);
    
    // Calculate arrow head
    final angle = (end - start).direction;
    final arrowSize = 20.0;
    
    final arrowPath = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * cos(angle + pi / 6),
        end.dy - arrowSize * sin(angle + pi / 6),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - arrowSize * cos(angle - pi / 6),
        end.dy - arrowSize * sin(angle - pi / 6),
      );
    
    canvas.drawPath(arrowPath, paint);
  }

  void _drawCircle(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    
    final center = points.first;
    final radius = (points.last - center).distance;
    canvas.drawCircle(center, radius, paint);
  }

  void _drawRectangle(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 2) return;
    
    final rect = Rect.fromPoints(points.first, points.last);
    canvas.drawRect(rect, paint);
  }

  void _drawText(Canvas canvas, String text, Offset position, Paint paint) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: paint.color,
        fontSize: 16,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, position);
  }

  void _drawAngle(Canvas canvas, List<Offset> points, Paint paint) {
    if (points.length < 3) return;
    
    // Draw lines
    canvas.drawLine(points[0], points[1], paint);
    canvas.drawLine(points[1], points[2], paint);
    
    // Calculate and draw angle
    final angle = _calculateAngle(points[0], points[1], points[2]);
    final textSpan = TextSpan(
      text: '${angle.toStringAsFixed(1)}°',
      style: TextStyle(
        color: paint.color,
        fontSize: 14,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, points[1]);
  }

  double _calculateAngle(Offset p1, Offset p2, Offset p3) {
    final v1 = p1 - p2;
    final v2 = p3 - p2;
    final angle = atan2(v2.dy, v2.dx) - atan2(v1.dy, v1.dx);
    return (angle * 180 / pi).abs();
  }

  @override
  bool shouldRepaint(AnnotationPainter oldDelegate) {
    return annotations != oldDelegate.annotations ||
        currentAnnotation != oldDelegate.currentAnnotation;
  }
} 