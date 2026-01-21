import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ECGHeartLine extends StatefulWidget {
  final Color color;
  final double height;
  final double width;

  const ECGHeartLine({
    super.key,
    this.color = AppColors.primary,
    this.height = 60,
    this.width = 200,
  });

  @override
  State<ECGHeartLine> createState() => _ECGHeartLineState();
}

class _ECGHeartLineState extends State<ECGHeartLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.width, widget.height),
          painter: ECGPainter(
            animationValue: _controller.value,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class ECGPainter extends CustomPainter {
  final double animationValue;
  final Color color;

  ECGPainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    final w = size.width;
    final h = size.height;
    final midY = h / 2;

    // We want the line to "travel" from left to right
    // We'll define a standard ECG pulse pattern, now let's make it smooth
    path.moveTo(0, midY);

    // Segment 1: Isoelectric 1
    path.lineTo(w * 0.2, midY);

    // Segment 2: P wave (Cubic)
    path.cubicTo(
      w * 0.22,
      midY,
      w * 0.24,
      midY - h * 0.1,
      w * 0.25,
      midY - h * 0.1,
    );
    path.cubicTo(
      w * 0.26,
      midY - h * 0.1,
      w * 0.28,
      midY,
      w * 0.3,
      midY,
    );

    // Segment 3: PQ segment
    path.lineTo(w * 0.35, midY);

    // Segment 4: QRS Complex (Faster, sharper but still smooth joins)
    path.lineTo(w * 0.38, midY + h * 0.1); // Q
    path.lineTo(w * 0.42, midY - h * 0.45); // R
    path.lineTo(w * 0.46, midY + h * 0.3); // S
    path.lineTo(w * 0.5, midY); // J point

    // Segment 5: ST segment
    path.lineTo(w * 0.55, midY);

    // Segment 6: T wave (Cubic)
    path.cubicTo(
      w * 0.6,
      midY,
      w * 0.62,
      midY - h * 0.15,
      w * 0.65,
      midY - h * 0.15,
    );
    path.cubicTo(
      w * 0.68,
      midY - h * 0.15,
      w * 0.7,
      midY,
      w * 0.75,
      midY,
    );

    // Segment 7: Isoelectric 2
    path.lineTo(w, midY);

    // Draw background faint line
    final faintPaint = Paint()
      ..color = color.withOpacity(0.1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, faintPaint);

    // Draw scanning effect
    final scanOffset = animationValue * w;

    canvas.save();
    // Clip a "window" that moves with a glow
    final clipRect = Rect.fromLTWH(scanOffset - 60, 0, 100, h);
    final shader = LinearGradient(
      colors: [color.withOpacity(0), color, color.withOpacity(0.2)],
      stops: const [0.0, 0.8, 1.0],
    ).createShader(clipRect);

    paint.shader = shader;
    paint.strokeWidth = 2.5;
    canvas.drawPath(path, paint);

    // Draw a bright dot at the lead with glow
    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    // Find approximate Y on path for the scanOffset
    final pathMetrics = path.computeMetrics();
    Offset dotOffset = Offset(scanOffset, midY);
    if (pathMetrics.isNotEmpty) {
      final metric = pathMetrics.first;
      // Linear search for point with matching X on the metric
      for (double len = 0; len < metric.length; len += 2) {
        final pos = metric.getTangentForOffset(len)!.position;
        if (pos.dx >= scanOffset) {
          dotOffset = pos;
          break;
        }
      }
    }

    // Glow effect
    canvas.drawCircle(dotOffset, 3, dotPaint);
    canvas.drawCircle(
        dotOffset,
        6,
        Paint()
          ..color = color.withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    canvas.drawCircle(
        dotOffset,
        12,
        Paint()
          ..color = color.withOpacity(0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant ECGPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
