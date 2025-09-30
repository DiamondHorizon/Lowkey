import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primarySwatch: Colors.orange,
    scaffoldBackgroundColor: Colors.white,
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: Colors.black),
      titleLarge: TextStyle(color: Colors.orange),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: Colors.orange,
      thumbColor: Colors.deepOrange,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.orange),
    ),
    toggleButtonsTheme: ToggleButtonsThemeData(
      selectedColor: Colors.white,
      fillColor: Colors.orange,
      borderColor: Colors.grey,
      selectedBorderColor: Colors.orangeAccent,
      borderRadius: BorderRadius.circular(8),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primarySwatch: Colors.orange,
    scaffoldBackgroundColor: Colors.black,
    textTheme: TextTheme(
      bodyMedium: TextStyle(color: Colors.white),
      titleLarge: TextStyle(color: Colors.orangeAccent),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: Colors.orange,
      thumbColor: Colors.deepOrange,
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: Colors.orange),
    ),
    toggleButtonsTheme: ToggleButtonsThemeData(
      selectedColor: Colors.white,
      fillColor: Colors.orange,
      borderColor: Colors.grey,
      selectedBorderColor: Colors.orangeAccent,
      borderRadius: BorderRadius.circular(8),
    ),
  );
}