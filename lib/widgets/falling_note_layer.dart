import 'package:flutter/material.dart';

import '../services/json_parser.dart';
import '../widgets/falling_note.dart';

class FallingNoteLayer extends StatelessWidget {
  final ValueNotifier<List<NoteInstruction>> activeFallingNotesNotifier;
  final List<NoteInstruction> notes;
  final double Function(int) getYPosition;
  final double Function(int) mapPitchToX;
  final double keyWidth;
  final double baseSpeed;

  const FallingNoteLayer({
    required this.activeFallingNotesNotifier,
    required this.notes,
    required this.getYPosition,
    required this.mapPitchToX,
    required this.keyWidth,
    required this.baseSpeed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<NoteInstruction>>(
      valueListenable: activeFallingNotesNotifier,
      builder: (context, notes, _) {
        return Stack(
          children: notes
              .map((note) {
                final y = getYPosition(note.timeMs);
                final noteHeight = note.durationMs * baseSpeed ;

                return Positioned(
                  top: y - noteHeight,
                  left: mapPitchToX(note.noteNumber),
                  child: FallingNote(
                    key: ValueKey('${note.noteNumber}_${note.timeMs}'),
                    color: note.hand == 'left' ? Colors.purple : Colors.blue,
                    keyWidth: keyWidth,
                    durationMs: note.durationMs,
                    baseSpeed: baseSpeed,
                  ),
                );
              })
              .whereType<Widget>()
              .toList(),
        );
      },
    );
  }
}
