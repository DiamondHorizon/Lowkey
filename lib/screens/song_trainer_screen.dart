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
  bool waitMode = false;
  Map<int, String> handMap = {};
  double baseSpeed = 0.1;
  Set<NoteInstruction> pendingNotes = {};
  bool isLoading = true;
  final double noteHeight = 20.0;
  double keyboardY = 0.0;
  final ValueNotifier<int> currentTimeNotifier = ValueNotifier(0);
  bool isTicking = false;
  final GlobalKey stackKey = GlobalKey();
  double stackHeight = 0.0;
  final activeFallingNotesNotifier = ValueNotifier<List<NoteInstruction>>([]);
  final playedNotesNotifier = ValueNotifier<Set<int>>({});
  final isPausedNotifier = ValueNotifier<bool>(true);
  bool hasStartedPlayback = false;
  int startTimeOffset = 0;

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
    if (isTicking || isPausedNotifier.value) return;
    isTicking = true;

    final startTime = DateTime.now().millisecondsSinceEpoch - startTimeOffset;

    void tick() {
      if (!mounted) return;

      final currentTime = DateTime.now().millisecondsSinceEpoch - startTime;

      if (isPausedNotifier.value) {
        isTicking = false;
        startTimeOffset = currentTimeNotifier.value; // Save current time
        return;
      }

      final anyPendingNoteAtKeyboard = activeFallingNotesNotifier.value.any((note) {
        final y = getYPosition(note.timeMs, currentTime);
        return pendingNotes.contains(note) &&
              y >= keyboardY - noteHeight &&
              y <= keyboardY + noteHeight;
      });

      if (!waitMode || !anyPendingNoteAtKeyboard) {
        currentTimeNotifier.value = currentTime;
        Future.delayed(Duration(milliseconds: 16), tick);
      } else {
        isTicking = false;
      }
    }

    tick();
  }

  void resumePlayback() {
    if (!isTicking) {
      isPausedNotifier.value = false;
      startPlayback();
    }
  }

  void handlePauseMenu() async {
    isPausedNotifier.value = true;

    final shouldResume = await showPauseMenu(
      context: context,
      tempoFactor: tempoFactor,
      onTempoChanged: updateTempo,
      selectedHand: selectedHand,
      onHandChanged: updateHand,
      waitMode: waitMode,
      onWaitModeChanged: updateWaitMode,
    );

    if (shouldResume != false) {
      resumePlayback();
    }
  }
  
  double getYPosition(int noteTime, int currentTime) {
    final y = (currentTime - noteTime) * tempoFactor * baseSpeed;
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

  List<NoteInstruction> getVisibleNotes(List<NoteInstruction> notes, int currentTime, double stackHeight) {
    return notes.where((note) {
      final y = getYPosition(note.timeMs, currentTime);
      return y >= -noteHeight && y <= stackHeight + noteHeight;
    }).toList();
  }

  List<int> getExpectedNotes(List<NoteInstruction> notes, int currentTime) {
    return notes.where((note) {
      final y = getYPosition(note.timeMs, currentTime);
      return pendingNotes.contains(note) &&
            y >= keyboardY - noteHeight * 1.5 &&
            y <= keyboardY + noteHeight;
    }).map((note) => note.noteNumber).toList();
  }

  List<NoteInstruction> getMissedNotes(List<NoteInstruction> notes, int currentTime, double screenHeight) {
    return notes.where((note) {
      final y = getYPosition(note.timeMs, currentTime);
      return y > screenHeight + noteHeight;
    }).toList();
  }

  void playSong() {
    startTimeOffset = 0;
    isTicking = false;
    currentTimeNotifier.value = 0;
    if (instructions == null || instructions!.isEmpty) return;

    final filtered = filterByHand(
      instructions!.where((e) => e.isNoteOn).toList(),
      selectedHand,
    );

    if (filtered.isEmpty) return;

    pendingNotes.clear();
    playedNotesNotifier.value = {};
    activeFallingNotesNotifier.value = filtered;

    for (final note in filtered) {
      pendingNotes.add(note);
      midiService.waitForUserInput(note.noteNumber).then((_) {
        if (mounted) {
          final updated = [...activeFallingNotesNotifier.value];
          updated.remove(note);
          activeFallingNotesNotifier.value = updated;
          playedNotesNotifier.value = {...playedNotesNotifier.value, note.noteNumber};

          Future.delayed(Duration(milliseconds: 300), () {
            if (mounted) {
              setState(() {
                playedNotesNotifier.value = playedNotesNotifier.value..remove(note.noteNumber);
                pendingNotes.remove(note);
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
    isPausedNotifier.value = false;
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
      // Menu Bar
      // TODO: Add song progression here
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0, top: 8.0),
            child: Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: Icon(Icons.pause),
                onPressed: handlePauseMenu,
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                stackHeight = constraints.maxHeight;
                keyboardY = stackHeight - keyboardHeight;

                return Stack(
                  key: stackKey,
                  children: [
                    if (isLoading)
                      Center(child: CircularProgressIndicator())
                    else
                      ValueListenableBuilder<int>(
                        valueListenable: currentTimeNotifier,
                        builder: (_, currentTime, __) {
                          final expectedNotes = getExpectedNotes(activeFallingNotesNotifier.value, currentTime);

                          final visibleNotes = getVisibleNotes(activeFallingNotesNotifier.value, currentTime, stackHeight);

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              if (!isPausedNotifier.value) {
                                isPausedNotifier.value = true;
                              }
                            },
                            child: Stack(
                              children: [
                                // Play/Pause
                                ValueListenableBuilder<bool>(
                                  valueListenable: isPausedNotifier,
                                  builder: (_, isPaused, __) {
                                    return isPaused
                                        ? GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: () {
                                              if (!hasStartedPlayback) {
                                                hasStartedPlayback = true;
                                                playSong();
                                              } else {
                                                resumePlayback();
                                              }
                                            },
                                            child: Container(
                                              color: Colors.black.withAlpha(102),
                                              child: Center(
                                                child: Icon(
                                                  Icons.play_arrow,
                                                  color: Colors.white,
                                                  size: 64,
                                                ),
                                              ),
                                            ),
                                          )
                                        : SizedBox.shrink();
                                  },
                                ),
                                // Falling Note Layer
                                FallingNoteLayer(
                                  notes: visibleNotes,
                                  noteHeight: noteHeight,
                                  getYPosition: (noteTime) => getYPosition(noteTime, currentTime),
                                  mapPitchToX: mapPitchToX,
                                  keyWidth: keyWidth,
                                ),
                                // Keyboard
                                Align(
                                  alignment: Alignment.bottomCenter,
                                  child: SizedBox(
                                    width: double.infinity,
                                    height: MediaQuery.of(context).size.height * 0.25,
                                    child: ValueListenableBuilder<Set<int>>(
                                      valueListenable: playedNotesNotifier,
                                      builder: (_, playedNotes, __) {
                                        return PianoKeyboard(
                                          activeNotes: playedNotes.toList(),
                                          expectedNotes: waitMode ? expectedNotes : [],
                                          handMap: handMap,
                                          onKeyPressed: (note) {
                                            midiService.registerNotePressed(note);
                                            playedNotesNotifier.value = {...playedNotesNotifier.value, note};

                                            final currentTime = currentTimeNotifier.value;
                                            final visibleNotes = getVisibleNotes(activeFallingNotesNotifier.value, currentTime, stackHeight);
                                            final expectedNotes = getExpectedNotes(activeFallingNotesNotifier.value, currentTime);

                                            // Find the first matching note that is visible, expected, and matches the played note
                                            final matchingNotes = visibleNotes.where(
                                              (n) => n.noteNumber == note && expectedNotes.contains(note),
                                            );

                                            if (matchingNotes.isNotEmpty) {
                                              final matchingNote = matchingNotes.first;
                                              final updated = [...activeFallingNotesNotifier.value];
                                              updated.remove(matchingNote);
                                              activeFallingNotesNotifier.value = updated;
                                              pendingNotes.remove(matchingNote);
                                            }

                                            Future.delayed(Duration(milliseconds: 300), () {
                                              if (mounted) {
                                                playedNotesNotifier.value = playedNotesNotifier.value..remove(note);
                                              }
                                            });
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                );
              }
            ),
          ),
        ],
      ),
    );
  }
}

// TODO: 
// Make it acutally sound like the song with falling notes
// Indicate scrolling in pause menu
// Prevent notes from dissapearing while falling
// Make falling notes line up with keys
// Prevent all notes from clearing

// Eventually:
// Add song progression
// Sheet music