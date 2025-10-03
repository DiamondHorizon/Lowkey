import 'package:flutter/material.dart';

class AppColors {
  static const Color primaryBlue = Color.fromARGB(255, 0, 187, 255);
  static const MaterialColor primarySwatch = MaterialColor(
    0xFF00BBFF,
    <int, Color>{
      50: Color(0xFFE0F7FF),
      100: Color(0xFFB3ECFF),
      200: Color(0xFF80E1FF),
      300: Color(0xFF4DD6FF),
      400: Color(0xFF26CCFF),
      500: Color(0xFF00BBFF),
      600: Color(0xFF00A7E6),
      700: Color(0xFF0092CC),
      800: Color(0xFF007EB3),
      900: Color(0xFF005580),
    },
  );

  static const Color accentBlue = Color.fromARGB(255, 0, 149, 255);
  static const Color deepBlue = Color.fromARGB(255, 0, 70, 120);
  static const Color softGray = Color.fromARGB(255, 184, 184, 184);
  static const Color darkBackground = Color.fromARGB(255, 24, 24, 24);
  static const Color highlightGreen = Color.fromARGB(255, 78, 210, 85);
}

class AppTheme {
  static ThemeData baseTheme(ColorScheme colorScheme, Color scaffoldColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.background,
      dividerTheme: DividerThemeData(
        color: colorScheme.secondary,
        thickness: 1.5,
        space: 32,
      ),
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: colorScheme.surface),
        titleLarge: TextStyle(color: colorScheme.secondary),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.secondary,
          foregroundColor: colorScheme.onSecondary,
        ),
      ),
      listTileTheme: ListTileThemeData(
        selectedColor: colorScheme.secondary,
        iconColor: colorScheme.onSurface,
        textColor: colorScheme.secondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.secondary,
          side: BorderSide(color: colorScheme.secondary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colorScheme.secondary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white; // Always white when ON
          }
          return Colors.grey.shade300; // Default when OFF
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.secondary; // Track when ON
          }
          return Colors.grey.shade400; // Track when OFF
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          return colorScheme.secondary; // Removes black border
        }),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surface, // unselected background
        selectedColor: colorScheme.secondary, // selected background
        disabledColor: Colors.grey.shade300,
        labelStyle: TextStyle(color: colorScheme.onSurface), // unselected text
        secondaryLabelStyle: TextStyle(color: Colors.white), // selected text
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      sliderTheme: SliderThemeData(
        inactiveTrackColor: Colors.black, // Unlit portion beyond the thumb
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onSecondary,
        titleTextStyle: TextStyle(
          color: colorScheme.onSecondary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        iconTheme: IconThemeData(color: colorScheme.onSecondary),
      ),
    );
  }

  static ThemeData lightTheme = baseTheme(
    ColorScheme.fromSwatch(
      primarySwatch: AppColors.primarySwatch,
      accentColor: AppColors.accentBlue,
      backgroundColor: AppColors.softGray,
      errorColor: Colors.red,
      brightness: Brightness.light,
    ).copyWith(
      secondary: AppColors.accentBlue,
      onPrimary: AppColors.deepBlue,
      onSecondary: Colors.white,
      surface: Colors.black,
      onSurface: Colors.white,
    ),
    AppColors.softGray,
  );

  static ThemeData darkTheme = baseTheme(
    ColorScheme.fromSwatch(
      primarySwatch: AppColors.primarySwatch,
      accentColor: AppColors.accentBlue,
      backgroundColor: AppColors.darkBackground,
      errorColor: Colors.red,
      brightness: Brightness.dark,
    ).copyWith(
      secondary: AppColors.accentBlue,
      onPrimary: AppColors.deepBlue,
      onSecondary: Colors.white,
      surface: Colors.white,
      onSurface: Colors.black,
    ),
    AppColors.darkBackground,
  );

}