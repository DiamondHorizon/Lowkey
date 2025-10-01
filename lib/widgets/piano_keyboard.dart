import 'package:flutter/material.dart';

class PianoKeyboard extends StatelessWidget {
  final List<int> activeNotes;
  final List<int> expectedNotes;
  final Map<int, String>? handMap;
  final void Function(int note)? onKeyPressed;

  const PianoKeyboard({
    required this.activeNotes,
    required this.expectedNotes,
    this.handMap,
    this.onKeyPressed,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const int startNote = 21; // A0
    const int endNote = 108; // C8

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
    
    return LayoutBuilder(
      builder: (context, constraints) {
        // Width
        final whiteKeyWidth = constraints.maxWidth / whiteNotes.length;
        final blackKeyWidth = whiteKeyWidth * 0.65;

        // Height
        final keyboardHeight = constraints.maxHeight;
        final blackKeyHeight = keyboardHeight * 0.8;

        return Container(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Stack(
            children: [
              // White keys
              Positioned.fill(
                child: Row(
                  children: whiteNotes.map((note) {
                    final hand = handMap?[note];
                    final isActive = activeNotes.contains(note);
                    final isExpected = expectedNotes.contains(note);

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
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => onKeyPressed?.call(note),
                        child: AnimatedContainer(
                          duration: Duration(milliseconds: 100),
                          height: keyboardHeight,
                          decoration: BoxDecoration(
                            color: color,
                            border: Border.all(color: Colors.grey),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              // Black keys
              ...blackNotes.map((note) {
                final index = whiteNotes.indexWhere((n) => n > note);
                final leftOffset = (index > 0 ? index - 1 : 0) * whiteKeyWidth + (whiteKeyWidth - blackKeyWidth / 2);

                final hand = handMap?[note];
                final isActive = activeNotes.contains(note);
                final isExpected = expectedNotes.contains(note);

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
      },
    );
  }
}