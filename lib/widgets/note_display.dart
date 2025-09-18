import 'package:flutter/material.dart';

class NoteDisplay extends StatelessWidget {
  final List<int> activeNotes;

  const NoteDisplay({required this.activeNotes, Key? key}) : super(key: key);

  String midiNoteToKey(int noteNumber) {
    const noteNames = ['C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B'];
    final octave = (noteNumber ~/ 12) - 1;
    final note = noteNames[noteNumber % 12];
    return '$note$octave';
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: activeNotes.map((note) {
        return Chip(label: Text("Play: ${midiNoteToKey(note)}"));
      }).toList(),
    );
  }
}