import 'package:dart_midi/dart_midi.dart';
import 'dart:typed_data';

MidiFile parse(Uint8List midiData) {
  final parser = MidiParser();
  return parser.parseMidiFromBuffer(midiData);
}

class NoteInstruction {
  final int noteNumber;
  final int channel;
  final bool isNoteOn;
  final int velocity;
  final int timeMs;
  final String hand;

  NoteInstruction({
    required this.noteNumber,
    required this.channel,
    required this.isNoteOn,
    required this.velocity,
    required this.timeMs,
    required this.hand,
  });
}

List<NoteInstruction> extractNoteInstructions(MidiFile midiFile, double tempoFactor) {
  final ticksPerBeat = midiFile.header.ticksPerBeat ?? 480;
  final microsecondsPerBeat = 500000;

  int cumulativeTicks = 0;
  final instructions = <NoteInstruction>[];

  final events = midiFile.tracks.expand((track) => track).toList();

  for (final event in events) {
    if (event is NoteOnEvent) {
      cumulativeTicks += event.deltaTime;

      final timeMs = ((cumulativeTicks / ticksPerBeat) * (microsecondsPerBeat / 1000)) / tempoFactor;
      final hand = (event.channel == 1) ? 'left' : (event.channel == 2) ? 'right' : 'unknown';

      instructions.add(NoteInstruction(
        noteNumber: event.noteNumber,
        channel: event.channel,
        isNoteOn: true,
        velocity: event.velocity,
        timeMs: timeMs.round(),
        hand: hand,
      ));
    } else if (event is NoteOffEvent) {
      cumulativeTicks += event.deltaTime;

      final timeMs = ((cumulativeTicks / ticksPerBeat) * (microsecondsPerBeat / 1000)) / tempoFactor;
      final hand = (event.channel == 1) ? 'left' : (event.channel == 2) ? 'right' : 'unknown';

      instructions.add(NoteInstruction(
        noteNumber: event.noteNumber,
        channel: event.channel,
        isNoteOn: false,
        velocity: event.velocity,
        timeMs: timeMs.round(),
        hand: hand,
      ));
    }
  }

  return instructions;
}

List<NoteInstruction> filterByHand(List<NoteInstruction> notes, String hand) {
  if (hand == 'both') return notes;
  return notes.where((note) => note.hand == hand).toList();
}

Map<int, List<NoteInstruction>> groupByTime(List<NoteInstruction> notes) {
  final map = <int, List<NoteInstruction>>{};
  for (final note in notes) {
    map.putIfAbsent(note.timeMs, () => []).add(note);
  }
  return map;
}