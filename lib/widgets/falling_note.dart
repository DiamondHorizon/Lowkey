import 'package:flutter/material.dart';

class FallingNote extends StatelessWidget {
  final int pitch;
  final double yPosition;
  final Color color;
  final double keyWidth;
  final int durationMs;
  final double tempoFactor;
  final double baseSpeed;
  final double Function(int pitch) mapPitchToX;

  const FallingNote({
    required this.pitch,
    required this.yPosition,
    required this.color,
    required this.keyWidth,
    required this.durationMs,
    required this.tempoFactor,
    required this.baseSpeed,
    required this.mapPitchToX,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final double noteHeight = durationMs * baseSpeed;

    return AnimatedOpacity(
      duration: Duration(milliseconds: 200),
      opacity: 1.0,
      child: Container(
        width: keyWidth,
        height: noteHeight,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}