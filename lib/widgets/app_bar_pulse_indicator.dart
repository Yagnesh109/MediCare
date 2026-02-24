import 'package:flutter/material.dart';

class AppBarPulseBackground extends StatefulWidget {
  const AppBarPulseBackground({super.key});

  @override
  State<AppBarPulseBackground> createState() => _AppBarPulseBackgroundState();
}

class _AppBarPulseBackgroundState extends State<AppBarPulseBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7600),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pulseColor = const Color(0xFFF5FBFF).withValues(alpha: 0.52);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _waveController,
        builder: (context, _) {
          return CustomPaint(
            painter: _PulseWavePainter(
              progress: _waveController.value,
              color: pulseColor,
            ),
            size: Size.infinite,
          );
        },
      ),
    );
  }
}

class _PulseWavePainter extends CustomPainter {
  const _PulseWavePainter({
    required this.progress,
    required this.color,
  });

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height * 0.62;
    final maxAmplitude = size.height * 0.24;

    final axisPaint = Paint()
      ..color = color.withValues(alpha: 0.12)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      axisPaint,
    );

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 3.4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8);

    final wavePaint = Paint()
      ..color = color
      ..strokeWidth = 1.7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Baseline-heavy waveform: lots of straight (0) segments with
    // occasional high/low events, similar to monitor traces.
    const amplitudes = <double>[
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
      0.12,
      -0.65,
      0.95,
      -0.28,
      0.0,
      0.0,
      0.0,
      -0.18,
      0.42,
      -0.22,
      0.0,
      0.0,
      0.0,
      0.0,
      0.08,
      -0.52,
      0.70,
      -0.20,
      0.0,
      0.0,
      0.0,
      0.0,
      -0.10,
      0.25,
      -0.12,
      0.0,
      0.0,
      0.0,
      0.0,
      0.0,
    ];

    const widths = <double>[
      1.3,
      1.3,
      1.2,
      1.4,
      1.3,
      1.2,
      0.8,
      0.65,
      0.55,
      0.85,
      1.2,
      1.3,
      1.3,
      0.9,
      0.8,
      0.95,
      1.2,
      1.3,
      1.4,
      1.3,
      0.85,
      0.65,
      0.55,
      0.9,
      1.2,
      1.3,
      1.3,
      1.4,
      0.9,
      0.95,
      1.0,
      1.2,
      1.3,
      1.4,
      1.3,
      1.2,
    ];

    final path = Path();
    final baseSegment = size.width / 54;
    var cycleWidth = 0.0;
    for (final width in widths) {
      cycleWidth += width * baseSegment;
    }
    final shift = progress * cycleWidth;
    var cycleStart = -cycleWidth + shift;
    var started = false;

    while (cycleStart < size.width + cycleWidth) {
      var x = cycleStart;
      for (var i = 0; i < amplitudes.length; i++) {
        final segmentWidth = widths[i] * baseSegment;
        final amp = amplitudes[i] * maxAmplitude;
        final start = Offset(x, centerY);
        final peak = Offset(x + segmentWidth * 0.42, centerY - amp);
        final end = Offset(x + segmentWidth, centerY);

        if (!started) {
          path.moveTo(start.dx, start.dy);
          started = true;
        } else {
          path.lineTo(start.dx, start.dy);
        }

        if (amplitudes[i].abs() < 0.001) {
          path.lineTo(end.dx, end.dy); // keep a flat straight line
        } else {
          path.lineTo(peak.dx, peak.dy);
          path.lineTo(end.dx, end.dy);
        }
        x = end.dx;
      }
      cycleStart += cycleWidth;
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, wavePaint);

    // Keep title area clean by covering a small centered region with app bar color.
    final titleMaskPaint = Paint()
      ..color = const Color(0xFF1565C0)
      ..style = PaintingStyle.fill;
    final maskRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(size.width / 2, centerY - 4),
        width: size.width * 0.44,
        height: size.height * 0.82,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(maskRect, titleMaskPaint);
  }

  @override
  bool shouldRepaint(covariant _PulseWavePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
