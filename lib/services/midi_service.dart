import 'dart:async';
import 'package:flutter_midi_command/flutter_midi_command.dart';

class MidiService {
  static final MidiService _instance = MidiService._internal();
  factory MidiService() => _instance;
  MidiService._internal();
  bool isListening = false;
  void Function(int)? onNoteReceived;
  
  Set<int> _pressedNotes = {};
  Set<int> _requiredNotes = {};
  Completer<void>? _chordCompleter;
  
  static final MidiCommand command = MidiCommand();

  // Future<void> waitForUserInput(int expectedNote) async {
  //   final completer = Completer<void>();

  //   late StreamSubscription<MidiPacket> subscription;

  //   subscription = command.onMidiDataReceived!.listen((MidiPacket packet) {
  //     final data = packet.data;
  //     if (data.isNotEmpty && (data[0] & 0xF0) == 0x90) { // NoteOn
  //       final playedNote = data[1];
  //       if (playedNote == expectedNote) {
  //         subscription.cancel(); // Stop listening
  //         completer.complete();
  //       }
  //     }
  //   });

  //   return completer.future;
  // }

  void startListening() {
    if (isListening) return;
    isListening = true;

    command.onMidiDataReceived?.listen((MidiPacket packet) {
      final data = packet.data;
      if (data.isNotEmpty && (data[0] & 0xF0) == 0x90 && data[2] > 0) {
        final playedNote = data[1];
        onNoteReceived?.call(playedNote);
      }
    });
  }

  void registerNotePressed(int note) {
    _pressedNotes.add(note);
    if (_chordCompleter != null &&
        _pressedNotes.containsAll(_requiredNotes)) {
      _chordCompleter!.complete();
      _chordCompleter = null;
      _pressedNotes.clear();
      _requiredNotes.clear();
    }
  }

  // Future<void> waitForChord(Set<int> requiredNotes) {
  //   _requiredNotes = requiredNotes;
  //   _pressedNotes.clear();
  //   _chordCompleter = Completer<void>();

  //   late StreamSubscription<MidiPacket> subscription;

  //   subscription = command.onMidiDataReceived!.listen((MidiPacket packet) {
  //     final data = packet.data;
  //     if (data.isNotEmpty && (data[0] & 0xF0) == 0x90 && data[2] > 0) { // NoteOn with velocity
  //       final playedNote = data[1];
  //       _pressedNotes.add(playedNote);

  //       if (_pressedNotes.containsAll(_requiredNotes)) {
  //         subscription.cancel();
  //         _chordCompleter!.complete();
  //         _chordCompleter = null;
  //         _pressedNotes.clear();
  //         _requiredNotes.clear();
  //       }
  //     }
  //   });

  //   return _chordCompleter!.future;
  // }
}