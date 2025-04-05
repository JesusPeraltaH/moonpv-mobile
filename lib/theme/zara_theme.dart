import 'package:flutter/material.dart';

class ZaraTheme {
  static final ThemeData darkTheme = ThemeData.dark().copyWith(
    scaffoldBackgroundColor: const Color(0xFF757575), // Fondo gris oscuro para tema oscuro
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF121212),  // Fondo negro para elementos principales
      secondary: Color(0xFF121212), // Gris suave para elementos secundarios
      surface: Color(0xFF121212),  // Superficies (cards, modales)
      background: Color(0xFF757575), // Fondo gris oscuro
      error: Colors.redAccent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF000000), // Botón negro
        foregroundColor: Colors.white, // Texto blanco
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    iconTheme: const IconThemeData(
      color: Colors.black, // Íconos negros
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFF2C2C2C), // Fondo de los textfields (gris oscuro)
      labelStyle: TextStyle(color: Colors.white), // Gris claro para etiquetas
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF9E9E9E)), // Gris claro
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF9E9E9E), width: 2),
      ),
      border: OutlineInputBorder(),
    ),
  );

  static final ThemeData lightTheme = ThemeData.light().copyWith(
    scaffoldBackgroundColor: const Color(0xFFF5F5F5), // Fondo blanco suave
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF121212),  // Gris oscuro para el tema claro
      secondary: Color(0xFF121212), // Gris más suave para elementos secundarios
      surface: Color(0xFFFFFFFF),
      background: Color(0xFFF5F5F5),
      error: Colors.redAccent,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF000000), // Botón negro
        foregroundColor: Colors.white, // Texto blanco
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        textStyle: const TextStyle(fontWeight: FontWeight.bold),
      ),
    ),
    iconTheme: const IconThemeData(
      color: Colors.black, // Íconos negros
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFEFEFEF), // Fondo gris claro para los textfields
      labelStyle: TextStyle(color: Color(0xFF121212)), // Gris suave para etiquetas
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF121212)), // Gris suave
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFF121212), width: 2),
      ),
      border: OutlineInputBorder(),
    ),
  );
}
