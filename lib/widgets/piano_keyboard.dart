import 'package:flutter/material.dart';

class PianoKeyboard extends StatelessWidget {
  final List<int> activeNotes;
  final int? expectedNote;
  final Map<int, String>? handMap;
  final void Function(int note)? onKeyPressed;

  const PianoKeyboard({
    required this.activeNotes,
    this.expectedNote,
    this.handMap,
    this.onKeyPressed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const int startNote = 48; // C3
    const int endNote = 84;   // C6
    const double whiteKeyWidth = 40;
    const double blackKeyWidth = 24;
    const double blackKeyHeight = 120;

    final whiteNotes = <int>[];
    final blackNotes = <int>[];

    for (int note = startNote; note <= endNote; note++) {
      final mod = note % 12;
      if ([1, 3, 6, 8, 10].contains(mod)) {
        blackNotes.add(note);
      } else {
        whiteNotes.add(note);
      }
    }

    return SizedBox(
      height: 200,
      width: whiteNotes.length * whiteKeyWidth,
      child: Stack(
        children: [
          // White keys
          Row(
            children: whiteNotes.map((note) {
              final hand = handMap?[note];
              final isActive = activeNotes.contains(note);
              final isExpected = note == expectedNote;

              Color baseColor = hand == 'left'
                  ? Colors.blue.shade200
                  : hand == 'right'
                      ? Colors.red.shade200
                      : Colors.white;

              final color = isExpected
                  ? Colors.orange
                  : isActive
                      ? Colors.green
                      : baseColor;

              return GestureDetector(
                onTap: () => onKeyPressed?.call(note),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 100),
                  width: whiteKeyWidth,
                  height: 200,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
              );
            }).toList(),
          ),

          // Black keys positioned precisely
          ...blackNotes.map((note) {
            // final mod = note % 12;
            final index = whiteNotes.indexWhere((n) => n > note);
            final leftOffset = (index - 1) * whiteKeyWidth + (whiteKeyWidth - blackKeyWidth / 2);

            final hand = handMap?[note];
            final isActive = activeNotes.contains(note);
            final isExpected = note == expectedNote;

            Color baseColor = hand == 'left'
                ? Colors.blue.shade700
                : hand == 'right'
                    ? Colors.red.shade700
                    : Colors.black;

            final color = isExpected
                ? Colors.orange
                : isActive
                    ? Colors.green
                    : baseColor;

            return Positioned(
              left: leftOffset,
              top: 0,
              child: GestureDetector(
                onTap: () => onKeyPressed?.call(note),
                child: AnimatedContainer(
                  duration: Duration(milliseconds: 100),
                  width: blackKeyWidth,
                  height: blackKeyHeight,
                  decoration: BoxDecoration(
                    color: color,
                    border: Border.all(color: Colors.grey),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}