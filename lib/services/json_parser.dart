import 'dart:convert';
import 'package:flutter/services.dart';

class NoteInstruction {
  final int noteNumber;
  final int timeMs;
  final String hand;
  final bool isNoteOn;

  NoteInstruction({
    required this.noteNumber,
    required this.timeMs,
    required this.hand,
    required this.isNoteOn,
  });
}

Future<List<NoteInstruction>> loadNoteInstructionsFromJson(String filename) async {
  final jsonString = await rootBundle.loadString('assets/songs/$filename');
  final List<dynamic> rawNotes = json.decode(jsonString);

  return rawNotes.map((note) {
    return NoteInstruction(
      noteNumber: note['note'],
      timeMs: note['time'],
      hand: note['hand'],
      isNoteOn: true, // You can infer note-off later if needed
    );
  }).toList();
}

List<NoteInstruction> filterByHand(List<NoteInstruction> notes, String hand) {
  if (hand == 'both') return notes;

  return notes.where((note) {
    // Include notes explicitly assigned to the selected hand
    if (note.hand == hand) return true;

    // Optionally include ambiguous notes (e.g. 'both') if needed
    return note.hand == 'both';
  }).toList();
}