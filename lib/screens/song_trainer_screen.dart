import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../functions/pause_menu.dart';
import '../services/json_parser.dart';
// import '../services/midi_parser.dart';
import '../services/midi_service.dart';
import '../widgets/note_display.dart';
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

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();
    loadSettings();
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      tempoFactor = prefs.getDouble('tempoFactor') ?? 1.0;
      selectedHand = prefs.getString('selectedHand') ?? 'both';
      waitMode = prefs.getBool('waitMode') ?? false;
    });
  }

  void updateTempo(double value) async {
    setState(() => tempoFactor = value);
    final prefs = await SharedPreferences.getInstance();
    prefs.setDouble('tempoFactor', value);
  }

  void updateHand(String value) async {
    setState(() => selectedHand = value);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('selectedHand', value);
  }

  void updateWaitMode(bool value) async {
    setState(() => waitMode = value);
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool('waitMode', value);
  }

  // Future<void> playMidiSong() async {
  //   final bytes = await rootBundle.load('assets/songs/${widget.filename}');
  //   final midiData = bytes.buffer.asUint8List();

  //   final midiFile = parse(midiData);
  //   final allNotes = extractNoteInstructions(midiFile, tempoFactor);
  //   final filteredNotes = filterByHand(allNotes, selectedHand);

  //   handMap = {
  //     for (var note in filteredNotes) note.noteNumber: note.hand,
  //   };

  //   final startTime = DateTime.now().millisecondsSinceEpoch;

  //   for (final note in filteredNotes) {
  //     final now = DateTime.now().millisecondsSinceEpoch;
  //     final elapsed = now - startTime;
  //     final waitTime = note.timeMs - elapsed;

  //     if (waitTime > 0 && !waitMode) {
  //       await Future.delayed(Duration(milliseconds: waitTime));
  //     }

  //     if (waitMode && note.isNoteOn) {
  //       setState(() {
  //         currentNotes = [note.noteNumber];
  //       });

  //       await midiService.waitForUserInput(note.noteNumber); // ⏳ Wait for correct input

  //       setState(() {
  //         currentNotes = [];
  //       });
  //     } else {
  //       setState(() {
  //         if (note.isNoteOn) {
  //           currentNotes.add(note.noteNumber);
  //         } else {
  //           currentNotes.remove(note.noteNumber);
  //         }
  //       });
  //     }
  //   }
  // }

  Future<void> playSong() async {
    final allNotes = await loadNoteInstructionsFromJson(widget.filename);
    final filteredNotes = filterByHand(allNotes, selectedHand);

    handMap = {
      for (var note in filteredNotes) note.noteNumber: note.hand,
    };

    final startTime = DateTime.now().millisecondsSinceEpoch;

    final notesByTime = <int, List<NoteInstruction>>{}; 
    for (final note in filteredNotes) {
      notesByTime.putIfAbsent(note.timeMs, () => []).add(note);
    }

    for (final timeMs in notesByTime.keys.toList()..sort()) {
      final chord = notesByTime[timeMs]!;
      final now = DateTime.now().millisecondsSinceEpoch;
      final elapsed = now - startTime;
      final waitTime = timeMs - elapsed;

      if (waitTime > 0 && !waitMode) {
        await Future.delayed(Duration(milliseconds: waitTime));
      }

      final chordNotes = chord.where((n) => n.isNoteOn).map((n) => n.noteNumber).toSet();

      if (waitMode && chordNotes.isNotEmpty) {
        setState(() {
          currentNotes.clear();
          currentNotes.addAll(chordNotes);
        });

        await midiService.waitForChord(chordNotes); // ⏳ Wait for all notes

        setState(() {
          currentNotes = [];
        });
      } else {
        setState(() {
          for (final note in chord) {
            if (note.isNoteOn) {
              currentNotes.add(note.noteNumber);
            } else {
              currentNotes.remove(note.noteNumber);
            }
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Playing: ${widget.songName}")),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: Icon(Icons.pause),
              onPressed: () => showPauseMenu(
                context: context,
                tempoFactor: tempoFactor,
                onTempoChanged: updateTempo,
                selectedHand: selectedHand,
                onHandChanged: updateHand,
                waitMode: waitMode,
                onWaitModeChanged: updateWaitMode,
              ),
            ),
          ),
          SizedBox(height: 16),
          Center (
            child: ElevatedButton(
              onPressed: playSong,
              child: Text("Play"),
            ),
          ),
          NoteDisplay(activeNotes: currentNotes),
          SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.25,
            child: PianoKeyboard(
              activeNotes: currentNotes,
              expectedNotes: waitMode ? currentNotes : [],
              handMap: handMap,
              onKeyPressed: (note) {
                midiService.registerNotePressed(note);
              },
            ),
          ),
        ],
      ),
    );
  }
}

// TODO: 
// make it acutally sound like the song??, 
// save settings for next time, 
// add back arrow to song list when hitting go to songs, 
// fix color theme

// Eventually: 
// Falling notes, 
// sheet music, 