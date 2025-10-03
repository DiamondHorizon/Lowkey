import 'package:flutter/material.dart';

class FallingNote extends StatelessWidget {
  final int pitch;
  final double yPosition;
  final Color color;
  final double keyWidth;
  final double noteHeight;
  final double Function(int pitch) mapPitchToX;

  const FallingNote({
    required this.pitch,
    required this.yPosition,
    required this.color,
    required this.keyWidth,
    required this.noteHeight,
    required this.mapPitchToX,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: yPosition,
      left: mapPitchToX(pitch),
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