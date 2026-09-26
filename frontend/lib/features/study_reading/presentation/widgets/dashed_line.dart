import "package:flutter/material.dart";

class DashedVerticalLine extends StatelessWidget {
  const DashedVerticalLine({super.key, required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _DashedLinePainter(color: color));
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 2;
    const dashHeight = 6.0, dashSpace = 6.0;
    double y = 0;
    while (y < size.height) {
      canvas.drawLine(Offset(1, y), Offset(1, y + dashHeight), paint);
      y += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
