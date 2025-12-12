// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color grey = Color(0xFF808080);
  static const Color lightGrey = Color(0xFFD3D3D3);
  static const Color darkGrey = Color(0xFF696969);
  static const Color medium = Color(0x50FFFFFF);
  static const Color accent = Color(0xFFFFA500);
  static const Color primaryColor = Color(0xFF2196F3); // Blue as primary
  static const Color secondaryColor = Color(0xFFFF9800); // Orange as secondary

  // Text Colors
  static const Color darkText = Color(0xFF333333);
  static const Color lightText = Color(0xFF666666);
  static const Color whiteText = Colors.white;

  // Text Styles
  static TextStyle headingStyle = const TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: darkText,
  );

  static TextStyle subheadingStyle = const TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: darkText,
  );

  static TextStyle bodyStyle = const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: darkText,
  );

  static TextStyle captionStyle = const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: lightText,
  );

  static TextStyle buttonStyle = const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: whiteText,
  );

  // Additional useful styles
  static TextStyle errorStyle = const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Colors.red,
  );

  static TextStyle successStyle = const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Colors.green,
  );

  static TextStyle warningStyle = const TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: Colors.orange,
  );

  // Card and container styles
  static BoxDecoration cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.1),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );

  static BoxDecoration containerDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: lightGrey, width: 1),
  );

  // Button styles
  static ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: whiteText,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: buttonStyle,
  );

  static ButtonStyle secondaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.transparent,
    foregroundColor: primaryColor,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: const BorderSide(color: primaryColor),
    ),
    textStyle: buttonStyle.copyWith(color: primaryColor),
  );

  static ButtonStyle accentButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: accent,
    foregroundColor: darkText,
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    textStyle: buttonStyle.copyWith(color: darkText),
  );

  // Input decoration
  static InputDecoration inputDecoration = InputDecoration(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: lightGrey),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: lightGrey),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: primaryColor),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.red),
    ),
  );

  // Spacing constants
  static const double defaultPadding = 16.0;
  static const double mediumPadding = 12.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  // Border radius
  static const double borderRadiusSmall = 4.0;
  static const double borderRadiusMedium = 8.0;
  static const double borderRadiusLarge = 12.0;

  // Animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
}
