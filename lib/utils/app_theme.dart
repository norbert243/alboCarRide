import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static final Color primaryColor = Color(0xFF0057FF); // A more vibrant blue
  static final Color secondaryColor = Color(0xFFFFC107); // A complementary amber
  static final Color backgroundColor = Color(0xFFF5F5F5); // A lighter grey
  static final Color cardColor = Colors.white;
  static final Color textColor = Color(0xFF333333); // Darker grey for better contrast
  static final Color subtleTextColor = Color(0xFF666666);

  static final ThemeData theme = ThemeData(
    primaryColor: primaryColor,
    colorScheme: ColorScheme.fromSwatch(
      primarySwatch: Colors.blue,
      accentColor: secondaryColor,
      backgroundColor: backgroundColor,
      cardColor: cardColor,
      errorColor: Colors.red.shade700,
    ).copyWith(secondary: secondaryColor),
    scaffoldBackgroundColor: backgroundColor,
    fontFamily: GoogleFonts.poppins().fontFamily,
    textTheme: TextTheme(
      displayLarge: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
      displayMedium: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
      bodyLarge: GoogleFonts.poppins(fontSize: 16, color: textColor),
      bodyMedium: GoogleFonts.poppins(fontSize: 14, color: subtleTextColor),
      labelLarge: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      elevation: 4,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.symmetric(vertical: 10),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: textColor),
      titleTextStyle: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
        elevation: 2,
        shadowColor: Colors.black26,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        textStyle: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return primaryColor;
        }
        return Colors.grey;
      }),
      trackColor: MaterialStateProperty.resolveWith((states) {
        if (states.contains(MaterialState.selected)) {
          return primaryColor.withOpacity(0.5);
        }
        return Colors.grey.withOpacity(0.5);
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      hintStyle: GoogleFonts.poppins(color: subtleTextColor),
      labelStyle: GoogleFonts.poppins(color: textColor),
    ),
  );
}
