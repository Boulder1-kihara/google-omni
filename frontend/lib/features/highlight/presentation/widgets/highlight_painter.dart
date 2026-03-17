import 'package:flutter/material.dart';
import 'dart:math' as math;

class SelectionHighlightPainter extends CustomPainter {
  final Rect? selectionRect;
  final bool isFinished;
  
  // Animation value driving the wavy glowing border
  // Usually tied to an AnimationController in the parent widget
  final double animationValue;

  SelectionHighlightPainter({
    required this.selectionRect,
    required this.isFinished,
    this.animationValue = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (selectionRect == null) return;

    // Optional visual polish: Dim the background around the selection when finished
    if (isFinished) {
      final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
      final rectPath = Path()..addRect(selectionRect!);
      final outsidePath = Path.combine(PathOperation.difference, bgPath, rectPath);
      
      canvas.drawPath(
        outsidePath, 
        Paint()..color = Colors.black.withOpacity(0.4),
      );
    }

    final fillPaint = Paint()
      ..color = Colors.cyan.withOpacity(isFinished ? 0.0 : 0.2)
      ..style = PaintingStyle.fill;

    // Cache animation values to avoid redundant calculations
    final double sinValue = math.sin(animationValue * math.pi);
    final double strokeWidth = isFinished ? 2.0 + (sinValue * 1.5) : 1.5;
    final double blurRadius = isFinished ? 5.0 + (sinValue * 8.0) : 0.0;

    // The animated glowing border logic
    final borderPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    if (isFinished) {
      borderPaint.maskFilter = MaskFilter.blur(
        BlurStyle.outer, 
        blurRadius,
      );
    }

    // Draw the main bounding box
    canvas.drawRect(selectionRect!, fillPaint);
    canvas.drawRect(selectionRect!, borderPaint);

    // Draw resize handles on corners when finished
    if (isFinished) {
      _drawHandles(canvas, selectionRect!);
    }
  }

  void _drawHandles(Canvas canvas, Rect rect) {
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final handleBorderPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double handleRadius = 5.0;
    
    // Standard corner drag handles
    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomLeft,
      rect.bottomRight,
    ];

    for (var corner in corners) {
      canvas.drawCircle(corner, handleRadius, handlePaint);
      canvas.drawCircle(corner, handleRadius, handleBorderPaint);
    }
  }

  @override
  bool shouldRepaint(covariant SelectionHighlightPainter oldDelegate) {
    return oldDelegate.selectionRect != selectionRect ||
           oldDelegate.isFinished != isFinished ||
           oldDelegate.animationValue != animationValue;
  }
}
