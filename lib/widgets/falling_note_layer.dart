import 'package:flutter/material.dart';

import '../services/json_parser.dart';
import '../widgets/falling_note.dart';

class FallingNoteLayer extends StatelessWidget {
  final List<NoteInstruction> notes;
  final double noteHeight;
  final double Function(int) getYPosition;
  final double Function(int) mapPitchToX;
  final double keyWidth;

  const FallingNoteLayer({
    required this.notes,
    required this.noteHeight,
    required this.getYPosition,
    required this.mapPitchToX,
    required this.keyWidth,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Stack(
      children: notes
          .where((note) {
            final y = getYPosition(note.timeMs);
            return y >= 0 && y <= screenHeight + noteHeight;
          })
          .map((note) => FallingNote(
                pitch: note.noteNumber,
                yPosition: getYPosition(note.timeMs),
                color: note.hand == 'left' ? Colors.blue : Colors.green,
                keyWidth: keyWidth,
                noteHeight: noteHeight,
                mapPitchToX: mapPitchToX,
              ))
          .toList(),
    );
  }
}
