import 'dart:async';
import 'package:flutter_midi_command/flutter_midi_command.dart';

class MidiService {
  static final MidiService _instance = MidiService._internal();
  factory MidiService() => _instance;
  MidiService._internal();
  
  static final MidiCommand command = MidiCommand();

  Future<void> waitForUserInput(int expectedNote) async {
    final completer = Completer<void>();

    late StreamSubscription<MidiPacket> subscription;

    subscription = command.onMidiDataReceived!.listen((MidiPacket packet) {
      final data = packet.data;
      if (data.isNotEmpty && (data[0] & 0xF0) == 0x90) { // NoteOn
        final playedNote = data[1];
        if (playedNote == expectedNote) {
          subscription.cancel(); // Stop listening
          completer.complete();
        }
      }
    });

    return completer.future;
  }
}