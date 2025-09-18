import 'package:flutter/material.dart';

class TempoSlider extends StatelessWidget {
  final double tempoFactor;
  final ValueChanged<double> onChanged;

  const TempoSlider({
    required this.tempoFactor,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: tempoFactor,
      min: 0.25,
      max: 2.0,
      divisions: 7,
      label: "${(tempoFactor * 100).round()}%",
      onChanged: onChanged,
    );
  }
}