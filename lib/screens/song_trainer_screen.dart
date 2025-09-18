import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import '../widgets/tempo_slider.dart';
import '../widgets/hand_toggle.dart';
import '../services/midi_parser.dart';
import '../widgets/note_display.dart';
import '../widgets/wait_mode_toggle.dart';
import '../services/midi_service.dart';
import '../widgets/piano_keyboard.dart';

class SongTrainerScreen extends StatefulWidget {
  final String filename;
  final String songName;

  const SongTrainerScreen({required this.filename, required this.songName});

  @override
  _SongTrainerScreenState createState() => _SongTrainerScreenState();
}

class _SongTrainerScreenState extends State<SongTrainerScreen> {
  final midiService = MidiService();
  double tempoFactor = 1.0; // Default to 100% speed
  String selectedHand = 'both';
  List<int> currentNotes = [];
  bool waitMode = false;
  Map<int, String> handMap = {};

  Future<void> playSong() async {
    final bytes = await rootBundle.load('assets/songs/${widget.filename}');
    final midiData = bytes.buffer.asUint8List();

    final midiFile = parse(midiData);
    final allNotes = extractNoteInstructions(midiFile, tempoFactor);
    final filteredNotes = filterByHand(allNotes, selectedHand);

    handMap = {
      for (var note in filteredNotes) note.noteNumber: note.hand,
    };

    final startTime = DateTime.now().millisecondsSinceEpoch;

    for (final note in filteredNotes) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - startTime;
      final waitTime = note.timeMs - elapsed;

      if (waitTime > 0 && !waitMode) {
        await Future.delayed(Duration(milliseconds: waitTime));
      }

      if (waitMode && note.isNoteOn) {
        setState(() {
          currentNotes = [note.noteNumber];
        });

        await midiService.waitForUserInput(note.noteNumber); // ⏳ Wait for correct input

        setState(() {
          currentNotes = [];
        });
      } else {
        setState(() {
          if (note.isNoteOn) {
            currentNotes.add(note.noteNumber);
          } else {
            currentNotes.remove(note.noteNumber);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Playing: ${widget.songName}")),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TempoSlider(
              tempoFactor: tempoFactor,
              onChanged: (value) => setState(() => tempoFactor = value),
            ),
            WaitModeToggle(
              waitMode: waitMode,
              onChanged: (value) => setState(() => waitMode = value),
            ),
            HandToggle(
              selectedHand: selectedHand,
              onChanged: (value) => setState(() => selectedHand = value),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: playSong,
              child: Text("Play"),
            ),
            NoteDisplay(activeNotes: currentNotes),
            PianoKeyboard(
              activeNotes: currentNotes,
              expectedNote: waitMode ? currentNotes.firstOrNull : null,
              handMap: handMap,
              onKeyPressed: (note) {
                // Optional: simulate input
              },
            ),
          ],
        ),
      ),
    );
  }
}
