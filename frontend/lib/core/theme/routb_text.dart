import 'package:flutter/material.dart';

/// Familias tipográficas de ROUTB.
///
/// Los titulares usan **Bricolage Grotesque** (600 y 800) y todo el texto de
/// interfaz **DM Sans** (500 y 700). Ambas van empaquetadas como TTF en
/// `assets/fonts`, así que la app no depende de la red para pintar texto.
abstract final class RoutbText {
  /// Familia de titulares, cifras grandes y nombres de sección.
  static const String display = 'BricolageGrotesque';

  /// Familia de párrafo, etiquetas y botones.
  static const String body = 'DMSans';

  /// Estilo de titular de tamaño libre, para las cifras que no encajan en
  /// ningún rol de [TextTheme].
  ///
  /// Desde Flutter 3.47 el alineamiento no vive en [TextStyle] sino en `Text`,
  /// con su parámetro `textAlign`.
  static TextStyle headline(
    double size, {
    required Color color,
    double height = 1.15,
  }) =>
      TextStyle(
        fontFamily: display,
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: color,
        height: height,
        letterSpacing: -0.4,
      );

  /// Estilo de párrafo de tamaño libre.
  ///
  /// El alineamiento se pasa a `Text` con `textAlign`: desde Flutter 3.47
  /// [TextStyle] ya no lo lleva.
  static TextStyle copy(
    double size, {
    required Color color,
    FontWeight weight = FontWeight.w500,
    double height = 1.35,
  }) =>
      TextStyle(
        fontFamily: body,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  /// Roles del [TextTheme] derivados de los tamaños que usa el diseño.
  ///
  /// Los tres roles `display` cubren los titulares; `headline*` quedan como
  /// alias para que los widgets de Material que los usan a solas también
  /// hereden la tipografía de ROUTB.
  static TextTheme textTheme(Color ink, Color muted) => TextTheme(
        displayLarge: headline(32, color: ink, height: 1),
        displayMedium: headline(28, color: ink, height: 1.1),
        displaySmall: headline(22, color: ink, height: 1.2),
        headlineLarge: headline(28, color: ink, height: 1.1),
        headlineMedium: headline(22, color: ink, height: 1.2),
        headlineSmall: headline(18, color: ink),
        titleLarge: headline(18, color: ink),
        titleMedium: headline(16, color: ink),
        titleSmall: headline(15, color: ink),
        labelLarge: headline(14, color: ink),
        bodyLarge: copy(14, color: ink),
        bodyMedium: copy(13, color: ink),
        bodySmall: copy(12, color: muted),
        labelMedium: copy(13, color: ink, weight: FontWeight.w700),
        labelSmall: copy(11, color: ink, weight: FontWeight.w700),
      );
}