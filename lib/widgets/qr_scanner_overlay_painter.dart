import 'dart:math' as math;
import 'package:flutter/material.dart';

class QrScannerOverlayPainter extends CustomPainter {
  final double animationValue;

  const QrScannerOverlayPainter({this.animationValue = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final boxSize = size.width * 0.68;
    final left = cx - boxSize / 2;
    final top = cy - boxSize / 2;
    final rect = RRect.fromLTRBR(
      left, top, left + boxSize, top + boxSize,
      const Radius.circular(16),
    );

    // ── Dark overlay (punch-out the scan window) ─────────────────────
    final overlayPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rect)
      ..fillType = PathFillType.evenOdd;

    canvas.drawPath(
      overlayPath,
      Paint()..color = Colors.black.withOpacity(0.72),
    );

    // ── Thin window border ───────────────────────────────────────────
    canvas.drawRRect(
      rect,
      Paint()
        ..color = Colors.white.withOpacity(0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    // ── Animated corner brackets ─────────────────────────────────────
    final bracketColor = Color.lerp(
      const Color(0xFF6C63FF),
      const Color(0xFF48CAE4),
      animationValue,
    )!;

    final bp = Paint()
      ..color = bracketColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    const arm = 24.0;
    final r = 16.0; // corner radius

    // Helper: draw one L-shaped bracket corner
    void bracket(double x, double y, double sx, double sy) {
      final path = Path()
        ..moveTo(x + sx * arm, y)
        ..lineTo(x + sx * r, y)
        ..arcToPoint(
          Offset(x, y + sy * r),
          radius: const Radius.circular(16),
          clockwise: sy > 0 ? sx < 0 : sx > 0,
        )
        ..lineTo(x, y + sy * arm);
      canvas.drawPath(path, bp);
    }

    bracket(left, top, 1, 1);                            // top-left
    bracket(left + boxSize, top, -1, 1);                 // top-right
    bracket(left, top + boxSize, 1, -1);                 // bottom-left
    bracket(left + boxSize, top + boxSize, -1, -1);      // bottom-right

    // ── Scan-line sweep ──────────────────────────────────────────────
    final sweepY = top + boxSize * animationValue;
    if (sweepY >= top && sweepY <= top + boxSize) {
      final sweepPaint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            bracketColor.withOpacity(0.6),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromLTWH(left, sweepY - 1, boxSize, 2));
      canvas.drawRect(
        Rect.fromLTWH(left + 4, sweepY - 1, boxSize - 8, 2),
        sweepPaint,
      );
    }
  }

  @override
  bool shouldRepaint(QrScannerOverlayPainter old) =>
      old.animationValue != animationValue;
}
