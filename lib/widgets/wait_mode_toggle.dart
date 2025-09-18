import 'package:flutter/material.dart';

class WaitModeToggle extends StatelessWidget {
  final bool waitMode;
  final ValueChanged<bool> onChanged;

  const WaitModeToggle({
    required this.waitMode,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      title: Text("Wait Mode"),
      subtitle: Text("Pause until correct note is played"),
      value: waitMode,
      onChanged: onChanged,
    );
  }
}
