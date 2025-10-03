import 'package:flutter/material.dart';

import 'controllers/color_theme_controller.dart';
import 'themes/lowkey_theme.dart';
import 'screens/midi_input_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeModeNotifier,
      builder: (_, mode, __) => MaterialApp(
        title: 'Lowkey',
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: mode,
        home: MidiInputScreen(), // Main widget
      ),
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

// To update app icon: flutter pub run flutter_launcher_icons:main