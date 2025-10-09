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
  Set<NoteInstruction> remainingNotes = {};
  bool isLoading = true;
  final double noteHeight = 20.0;
  double keyboardY = 0.0;
  final ValueNotifier<int> currentTimeNotifier = ValueNotifier(0);
  bool isTicking = false;
  final GlobalKey stackKey = GlobalKey();
  double stackHeight = 0.0;
  final activeFallingNotesNotifier = ValueNotifier<List<NoteInstruction>>([]);
  final activeNotesNotifier = ValueNotifier<Set<int>>({});
  final isPausedNotifier = ValueNotifier<bool>(true);
  bool hasStartedPlayback = false;
  int startTimeOffset = 0;
  Set<int> matchedExpectedPitches = {};

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
    midiService.onNoteReceived = onInputReceived;
    midiService.onNoteReleased = onNoteReleased;
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
    final startTime = DateTime.now().millisecondsSinceEpoch - currentTimeNotifier.value;

    void tick() {
      if (!mounted) return;

      final currentTime = DateTime.now().millisecondsSinceEpoch - startTime;

      // When the user pauses the playback
      if (isPausedNotifier.value) {
        isTicking = false;
        startTimeOffset = currentTime;
        return;
      }

      // Loop through all currently falling notes
      final anyremainingNoteAtKeyboard = activeFallingNotesNotifier.value.any((note) {
        final y = getYPosition(note.timeMs, currentTime); // Get the y-position of each note
        return remainingNotes.contains(note) && // Check if the note is still in remaining notes
              y >= keyboardY - noteHeight && // Check if the note is near the keyboard
              y <= keyboardY + noteHeight;
      }); // Assigns true to anyremainingNoteAtKeyboard if a note exists within that criteria

      // If not using wait mode or there are no pending notes near the keyboard
      if (!waitMode || !anyremainingNoteAtKeyboard) {
        currentTimeNotifier.value = currentTime; // Actually tick
        Future.delayed(Duration(milliseconds: 16), tick); // Recursive call in 16ms
      } else {
        isTicking = false; // Stops ticking
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

  List<NoteInstruction> getExpectedNotes(List<NoteInstruction> notes, int currentTime) {
    return notes.where((note) {
      final y = getYPosition(note.timeMs, currentTime);
      return remainingNotes.contains(note) &&
            y >= keyboardY - noteHeight * 1.5 &&
            y <= keyboardY + noteHeight;
    }).toList();
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
    if (instructions == null || instructions!.isEmpty) return;

    final filtered = filterByHand(
      instructions!.where((e) => e.isNoteOn).toList(),
      selectedHand,
    );

    if (filtered.isEmpty) return;

    remainingNotes.clear();
    matchedExpectedPitches.clear();
    activeNotesNotifier.value = {};
    activeFallingNotesNotifier.value = filtered;

    for (final note in filtered) {
      remainingNotes.add(note);
    }

    // Start playback immediately
    isPausedNotifier.value = false;
    startPlayback();
    midiService.startListening();
  }

  void onNoteReleased(int note) {
    activeNotesNotifier.value = {
      ...activeNotesNotifier.value..remove(note)
    };
  }

  void onInputReceived(int note) {
    midiService.registerNotePressed(note);
    activeNotesNotifier.value = {...activeNotesNotifier.value, note}; // Adds active notes to the set, triggers keyboard rebuild for highlighting

    // Get which notes are currently expected
    final expectedNotes = getExpectedNotes(activeFallingNotesNotifier.value, currentTimeNotifier.value);

    // Find the all notes that are expected and matches the played note
    final matchingNotes = expectedNotes.where((n) => n.noteNumber == note);

    // Get the note numbers of every expected note
    final expectedNoteNumbers = expectedNotes.map((n) => n.noteNumber).toSet();

    if (expectedNoteNumbers.contains(note)) {
      matchedExpectedPitches.add(note);
    }

    // Determine if every expected note is being
    final allExpectedNotesPlayed = expectedNoteNumbers.every(
      (pitch) => activeNotesNotifier.value.contains(pitch)
    );

    // Remove notes if all are found
    if (matchingNotes.isNotEmpty && allExpectedNotesPlayed) {
      for (final matchingNote in expectedNotes) { // Iterate through all notes
        final updated = [...activeFallingNotesNotifier.value]; // Gets the list of active notes
        updated.remove(matchingNote); // Removes the matched note from the list
        activeFallingNotesNotifier.value = updated; // Updates the screen
        remainingNotes.remove(matchingNote); // Removes the note from remainingNotes
      }
      matchedExpectedPitches.clear(); // Reset after all notes matched
    }

    // Resume playback after wait mode (when keys pressed)
    if (waitMode && !isTicking) {
      Future.delayed(Duration(milliseconds: 16), () {
        if (!isTicking && mounted) resumePlayback();
      });
    }

    // Clear visual key press after 300ms
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) {
        activeNotesNotifier.value = activeNotesNotifier.value..remove(note);
      }
    });
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
                                  activeFallingNotesNotifier: activeFallingNotesNotifier,
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
                                      valueListenable: activeNotesNotifier,
                                      builder: (_, activeNotes, __) {
                                        return PianoKeyboard(
                                          activeNotes: activeNotes.toList(),
                                          expectedNotes: waitMode ? expectedNotes.map((note) => note.noteNumber).toList() : [],
                                          handMap: handMap,
                                          onKeyPressed: (note) => onInputReceived(note),
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
// Make it acutally sound like the song
// Indicate scrolling in pause menu
// Make falling notes line up with keys
// Only take away notes when all pressed

// Eventually:
// Add song progression
// Sheet music