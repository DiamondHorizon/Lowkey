import 'package:dart_midi/dart_midi.dart';
import 'dart:typed_data';

MidiFile parse(Uint8List midiData) {
  final parser = MidiParser();
  return parser.parseMidiFromBuffer(midiData);
}

class MidiNoteInstruction {
  final int noteNumber;
  final int channel;
  final bool isNoteOn;
  final int velocity;
  final int timeMs;
  final String hand;

  MidiNoteInstruction({
    required this.noteNumber,
    required this.channel,
    required this.isNoteOn,
    required this.velocity,
    required this.timeMs,
    required this.hand,
  });
}

List<MidiNoteInstruction> extractNoteInstructions(MidiFile midiFile, double tempoFactor) {
  final ticksPerBeat = midiFile.header.ticksPerBeat ?? 480;
  final microsecondsPerBeat = 500000;

  int cumulativeTicks = 0;
  final instructions = <MidiNoteInstruction>[];

  final events = midiFile.tracks.expand((track) => track).toList();

  for (final event in events) {
    if (event is NoteOnEvent) {
      cumulativeTicks += event.deltaTime;

      final timeMs = ((cumulativeTicks / ticksPerBeat) * (microsecondsPerBeat / 1000)) / tempoFactor;
      final hand = (event.channel == 1) ? 'left' : (event.channel == 2) ? 'right' : 'unknown';

      instructions.add(MidiNoteInstruction(
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

      instructions.add(MidiNoteInstruction(
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

List<MidiNoteInstruction> filterMidiByHand(List<MidiNoteInstruction> notes, String hand) {
  if (hand == 'both') return notes;
  return notes.where((note) => note.hand == hand).toList();
}


Map<int, List<MidiNoteInstruction>> groupByTime(List<MidiNoteInstruction> notes) {
  final map = <int, List<MidiNoteInstruction>>{};
  for (final note in notes) {
    map.putIfAbsent(note.timeMs, () => []).add(note);
  }
  return map;
}