import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../functions/pause_menu.dart';
import '../services/json_parser.dart';
import '../services/midi_service.dart';
import '../widgets/falling_note_layer.dart';
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
  List<NoteInstruction>? instructions;
  List<NoteInstruction> activeFallingNotes = [];
  bool waitMode = false;
  Map<int, String> handMap = {};
  double baseSpeed = 0.1;
  Timer? playbackTimer;
  Set<int> pendingNotes = {};
  List<int> playedNotes = [];
  bool isLoading = true;
  final double noteHeight = 20.0;
  double keyboardY = 0.0;
  final ValueNotifier<int> currentTimeNotifier = ValueNotifier(0);
  bool isTicking = false;
  int currentTime = 0;
  final GlobalKey stackKey = GlobalKey();

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

  Future<void> loadNoteEvents() async {
    final loaded = await loadNoteInstructionsFromJson(widget.filename);
    setState(() {
      instructions = loaded;
      isLoading = false;
    });
  }

  void startPlayback() {
    if (isTicking) return;
    isTicking = true;

    final startTime = DateTime.now().millisecondsSinceEpoch;

    void tick() {
      if (!mounted) return;

      final currentTime = DateTime.now().millisecondsSinceEpoch - startTime;
      final anyPendingNoteAtKeyboard = activeFallingNotes.any((note) {
        final y = getYPosition(note.timeMs, currentTime);
        return pendingNotes.contains(note.noteNumber) &&
              y >= keyboardY - noteHeight &&
              y <= keyboardY + noteHeight;
      });

      if (!waitMode || !anyPendingNoteAtKeyboard) {
        currentTimeNotifier.value = currentTime;
        Future.delayed(Duration(milliseconds: 16), tick);
      } else {
        isTicking = false; // Stop ticking until user plays correct notes
        print('[Paused] Waiting for user input...');
      }
    }

    tick();
  }

  double getYPosition(int noteTime, int currentTime) {
    final y = (currentTime - noteTime) * tempoFactor * baseSpeed;

    // 🔧 Force clamping for test
    final stopY = keyboardY - noteHeight;
    return (waitMode && !isTicking) ? (y > stopY ? stopY : y) : y;
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
    isTicking = false;
    currentTimeNotifier.value = 0;
    if (instructions == null || instructions!.isEmpty) return;

    playbackTimer?.cancel();

    final filtered = filterByHand(
      instructions!.where((e) => e.isNoteOn).toList(),
      selectedHand,
    );

    if (filtered.isEmpty) return;

    pendingNotes.clear();
    playedNotes.clear();
    activeFallingNotes = filtered;

    for (final note in activeFallingNotes) {
      pendingNotes.add(note.noteNumber);
      midiService.waitForUserInput(note.noteNumber).then((_) {
        if (mounted) {
          setState(() {
            activeFallingNotes.remove(note);
            playedNotes.add(note.noteNumber);
          });

          Future.delayed(Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                playedNotes.remove(note.noteNumber);
                pendingNotes.remove(note.noteNumber);
              });
            }
          });

          if (waitMode && !isTicking) {
            Future.delayed(Duration(milliseconds: 16), () {
              if (!isTicking && mounted) startPlayback();
            });
          }
        }
      });
    }

    // Start playback immediately
    startPlayback();
  }

  @override
  Widget build(BuildContext context) {
    final double keyWidth = MediaQuery.of(context).size.width / 88; // for 88 keys
    final double keyboardHeight = MediaQuery.of(context).size.height * 0.25; 

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
              key: stackKey,
              children: [
                if (isLoading)
                  Center(child: CircularProgressIndicator())
                else
                  ValueListenableBuilder<int>(
                    valueListenable: currentTimeNotifier,
                    builder: (_, currentTime, __) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final renderBox = stackKey.currentContext?.findRenderObject() as RenderBox?;
                        if (renderBox != null) {
                          final stackHeight = renderBox.size.height;
                          keyboardY = stackHeight - keyboardHeight;
                        }
                      });
                      final expectedNotes = activeFallingNotes.where((note) {
                        final y = getYPosition(note.timeMs, currentTime);
                        return pendingNotes.contains(note.noteNumber) &&
                              y >= keyboardY - noteHeight * 1.5 &&
                              y <= keyboardY + noteHeight;
                      }).map((note) => note.noteNumber).toList();

                      final missedNotes = activeFallingNotes.where((note) {
                        final y = getYPosition(note.timeMs, currentTime);
                        return y > MediaQuery.of(context).size.height + noteHeight;
                      }).toList();

                      if (missedNotes.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setState(() {
                            activeFallingNotes.removeWhere((note) => missedNotes.contains(note));
                            pendingNotes.removeAll(missedNotes.map((n) => n.noteNumber));
                          });
                        });
                      }

                      return Stack(
                        children: [
                          FallingNoteLayer(
                            notes: activeFallingNotes,
                            noteHeight: noteHeight,
                            getYPosition: (noteTime) => getYPosition(noteTime, currentTime),
                            mapPitchToX: mapPitchToX,
                            keyWidth: keyWidth,
                          ),
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: SizedBox(
                              width: double.infinity,
                              height: MediaQuery.of(context).size.height * 0.25,
                              child: PianoKeyboard(
                                activeNotes: playedNotes,
                                expectedNotes: waitMode ? expectedNotes : [],
                                handMap: handMap,
                                onKeyPressed: (note) {
                                  midiService.registerNotePressed(note);
                                  setState(() {
                                    playedNotes.add(note);
                                  });
                                  Future.delayed(Duration(milliseconds: 300), () {
                                    if (mounted) {
                                      setState(() {
                                        playedNotes.remove(note);
                                      });
                                    }
                                  });
                                },
                              ),
                            ),
                          ),
                          Positioned(
                            top: keyboardY,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 2,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      );
                    },
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