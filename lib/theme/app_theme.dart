import 'package:flutter/material.dart';

ThemeData buildLightTheme({String? fontFamily}) {
  const colorScheme = ColorScheme.light(
    primary: Color(0xFF0E7C86),
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFCFF3F0),
    onPrimaryContainer: Color(0xFF063E43),
    secondary: Color(0xFFF07F2E),
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFFFE2CB),
    onSecondaryContainer: Color(0xFF6B3208),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1B2527),
    surfaceContainerHighest: Color(0xFFEAF0EF),
    onSurfaceVariant: Color(0xFF647476),
    error: Color(0xFFD64545),
    onError: Colors.white,
    outline: Color(0xFFDDE5E4),
    surfaceTint: Colors.transparent,
  );

  return _buildBase(
    colorScheme: colorScheme,
    scaffoldColor: const Color(0xFFF5F8F7),
    fontFamily: fontFamily,
  );
}

ThemeData buildDarkTheme({String? fontFamily}) {
  const colorScheme = ColorScheme.dark(
    primary: Color(0xFF5FD3C4),
    onPrimary: Color(0xFF04363A),
    primaryContainer: Color(0xFF0F4C52),
    onPrimaryContainer: Color(0xFFD3F7F2),
    secondary: Color(0xFFFFB067),
    onSecondary: Color(0xFF4A2406),
    secondaryContainer: Color(0xFF63340D),
    onSecondaryContainer: Color(0xFFFFE2CB),
    surface: Color(0xFF1B2224),
    onSurface: Color(0xFFE7EDEC),
    surfaceContainerHighest: Color(0xFF283234),
    onSurfaceVariant: Color(0xFFA3B0B1),
    error: Color(0xFFEF6B6B),
    onError: Color(0xFF300606),
    outline: Color(0xFF334042),
    surfaceTint: Colors.transparent,
  );

  return _buildBase(
    colorScheme: colorScheme,
    scaffoldColor: const Color(0xFF12181A),
    fontFamily: fontFamily,
  );
}

ThemeData _buildBase({
  required ColorScheme colorScheme,
  required Color scaffoldColor,
  String? fontFamily,
}) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldColor,
    fontFamily: fontFamily,
    appBarTheme: AppBarTheme(
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 48,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      shape: Border(bottom: BorderSide(color: colorScheme.outline, width: 0.5)),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 18),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: colorScheme.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outline,
      thickness: 0.5,
      space: 0.5,
    ),
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    textTheme: TextTheme(
      titleLarge: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      bodyLarge: TextStyle(
        fontSize: 15,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        color: colorScheme.onSurface,
        fontFamily: fontFamily,
      ),
      bodySmall: TextStyle(
        fontSize: 12,
        color: colorScheme.onSurfaceVariant,
        fontFamily: fontFamily,
      ),
    ),
  );
}
