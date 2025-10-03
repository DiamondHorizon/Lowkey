import 'package:flutter/material.dart';

import '../widgets/tempo_slider.dart';
import '../widgets/hand_toggle.dart';
import '../widgets/wait_mode_toggle.dart';

void showPauseMenu({
  required BuildContext context,
  required double tempoFactor,
  required ValueChanged<double> onTempoChanged,
  required String selectedHand,
  required ValueChanged<String> onHandChanged,
  required bool waitMode,
  required ValueChanged<bool> onWaitModeChanged,
}) {
  showDialog(
    context: context,
    builder: (context) {
      double localTempo = tempoFactor;
      String localHand = selectedHand;
      bool localWaitMode = waitMode;

      return AlertDialog(
        title: Text(
          'Settings',
          style: TextStyle(
            color: Theme.of(context).colorScheme.surface,
          ),
        ),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TempoSlider(
                tempoFactor: localTempo,
                onChanged: (value) {
                  setState(() => localTempo = value);
                  onTempoChanged(value);
                },
              ),
              WaitModeToggle(
                waitMode: localWaitMode,
                onChanged: (value) {
                  setState(() => localWaitMode = value);
                  onWaitModeChanged(value);
                },
              ),
              HandToggle(
                selectedHand: localHand,
                onChanged: (value) {
                  setState(() => localHand = value);
                  onHandChanged(value);
                },
              ),
            ],
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, bottom: 4.0),
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Close"),
            ),
          ),
        ],
      );
    },
  );
}