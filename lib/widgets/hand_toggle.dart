import 'package:flutter/material.dart';

class HandToggle extends StatelessWidget {
  final String selectedHand;
  final ValueChanged<String> onChanged;

  const HandToggle({
    required this.selectedHand,
    required this.onChanged,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: Text('Left'),
          selected: selectedHand == 'left',
          onSelected: (_) => onChanged('left'),
        ),
        SizedBox(width: 8),
        ChoiceChip(
          label: Text('Right'),
          selected: selectedHand == 'right',
          onSelected: (_) => onChanged('right'),
        ),
        SizedBox(width: 8),
        ChoiceChip(
          label: Text('Both'),
          selected: selectedHand == 'both',
          onSelected: (_) => onChanged('both'),
        ),
      ],
    );
  }
}