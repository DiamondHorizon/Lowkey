import 'package:flutter/material.dart';

import 'screens/midi_input_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lowkey',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MidiInputScreen(), // Main widget
    );
  } 
}

// TODO: Add navigation:
// return MaterialApp(
//   title: 'Lowkey',
//   theme: ThemeData(primarySwatch: Colors.blue),
//   initialRoute: '/',
//   routes: {
//     '/': (context) => MidiInputScreen(),
//     '/trainer': (context) => SongTrainerScreen(filename: 'example.mid'),
//   },
// );