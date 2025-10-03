import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../functions/pause_menu.dart';
import '../models/note_event.dart'; 
import '../services/json_parser.dart';
import '../services/midi_service.dart';
import '../widgets/falling_note.dart';
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
  List<NoteEvent> activeFallingNotes = [];
  bool waitMode = false;
  Map<int, String> handMap = {};
  List<NoteEvent>? events;
  double baseSpeed = 0.1;
  Timer? playbackTimer;
  Set<int> pendingNotes = {};
  List<int> playedNotes = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();
    loadSettings();
    loadNoteEvents();
  }

  @override
  void dispose() { // When leaving the screen
    playbackTimer?.cancel(); // Cancel the timer
    WakelockPlus.disable(); // Disable always on
    SystemChrome.setPreferredOrientations([ // Rotate back to portrait
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

  int currentTime = 0;

  Future<List<NoteEvent>> loadNoteEventsFromJson(String filename) async {
    final jsonString = await rootBundle.loadString('assets/$filename');
    final List<dynamic> jsonList = json.decode(jsonString);
    return jsonList.map((e) => NoteEvent.fromJson(e)).toList();
  }

  Future<void> loadNoteEvents() async {
    final loaded = await loadNoteEventsFromJson(widget.filename);
    print('[Trainer] Loaded ${loaded.length} notes');
    setState(() {
      events = loaded;
      isLoading = false;
    });
  }

  void startPlayback() {
    final startTime = DateTime.now().millisecondsSinceEpoch;
    playbackTimer = Timer.periodic(Duration(milliseconds: 16), (timer) {
      if (!mounted) return;
      setState(() {
        currentTime = DateTime.now().millisecondsSinceEpoch - startTime;
      });
    });
  }

  double getYPosition(int noteTime) {
    return (noteTime - currentTime) * tempoFactor * baseSpeed;
  }

  double mapPitchToX(int pitch) {
    const int startNote = 21; // A0
    const int endNote = 108;  // C8
    final totalKeys = endNote - startNote + 1;
    final screenWidth = MediaQuery.of(context).size.width;
    final keyWidth = screenWidth / totalKeys;
    return (pitch - startNote) * keyWidth;
  }

  void playSong() {
    if (events == null || events!.isEmpty) return;

    playbackTimer?.cancel(); // Cancel any previous timer

    setState(() {
      currentTime = 0;
      pendingNotes.clear();
      playedNotes.clear();
      activeFallingNotes = events!
        .where((e) => e.isNoteOn && (selectedHand == 'both' || e.hand == selectedHand))
        .toList();
    });

    startPlayback();
  }

  @override
  Widget build(BuildContext context) {
    final double keyWidth = MediaQuery.of(context).size.width / 88; // for 88 keys
    final double noteHeight = 20.0; // or whatever looks good visually
    final double keyboardHeight = MediaQuery.of(context).size.height * 0.25;
    final double keyboardY = MediaQuery.of(context).size.height - keyboardHeight;

    final notesToPlay = activeFallingNotes.where((note) {
      final y = getYPosition(note.time);
      return y >= keyboardY - noteHeight && y <= keyboardY + noteHeight;
    }).toList();

    for (final note in notesToPlay) {
      if (!pendingNotes.contains(note.note)) {
        pendingNotes.add(note.note);
        if (Platform.isAndroid || Platform.isIOS) {
          midiService.waitForUserInput(note.note).then((_) {
            if (mounted) {
              setState(() {
                activeFallingNotes.remove(note);
                pendingNotes.remove(note.note);
                playedNotes.add(note.note); // Show matched note
              });

              // Optional: clear highlight after short delay
              Future.delayed(Duration(milliseconds: 300), () {
                if (mounted) {
                  setState(() {
                    playedNotes.remove(note.note);
                  });
                }
              });
            }
          });
        }
      }
    }


    final missedNotes = activeFallingNotes.where((note) {
      final y = getYPosition(note.time);
      return y > MediaQuery.of(context).size.height + noteHeight;
    }).toList();

    if (missedNotes.isNotEmpty) {
      setState(() {
        activeFallingNotes.removeWhere((note) => missedNotes.contains(note));
        pendingNotes.removeAll(missedNotes.map((n) => n.note));
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Playing: ${widget.songName}"),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 8.0),
            child: Align(
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
          ),
          SizedBox(height: 16),
          Center(
            child: ElevatedButton(
              onPressed: playSong,
              child: Text("Play"),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                if (isLoading)
                  Center(child: CircularProgressIndicator())
                else
                  ...activeFallingNotes
                    .where((event) =>
                      getYPosition(event.time) >= -noteHeight &&
                      getYPosition(event.time) <= MediaQuery.of(context).size.height)
                    .map((event) => FallingNote(
                      pitch: event.note,
                      yPosition: getYPosition(event.time),
                      color: event.hand == 'left' ? Colors.blue : Colors.green,
                      keyWidth: keyWidth,
                      noteHeight: noteHeight,
                      mapPitchToX: mapPitchToX,
                    )),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.25,
                    child: PianoKeyboard(
                      activeNotes: playedNotes,
                      expectedNotes: waitMode ? playedNotes : [],
                      handMap: handMap,
                      onKeyPressed: (note) {
                        midiService.registerNotePressed(note);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// TODO: 
// Make it acutally sound like the song with falling notes 

// Eventually: 
// Sheet music 