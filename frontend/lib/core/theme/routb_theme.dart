import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_routes.dart';
import 'routb_palette.dart';
import 'routb_text.dart';

/// `ThemeData` de ROUTB en claro y oscuro.
///
/// Los dos temas comparten estructura y se diferencian solo en la
/// [RoutbPalette] que inyectan, de modo que ningún widget necesita saber en
/// qué modo está la app.
abstract final class RoutbTheme {
  // --- Radios ---------------------------------------------------------------

  /// `.c`: tarjeta.
  static const double radiusCard = 24;

  /// `.sheet`: hoja inferior.
  static const double radiusSheet = 30;

  /// `.ro`: tarjeta de ruta.
  static const double radiusRoute = 18;

  /// `.fd`: campo de formulario.
  static const double radiusField = 16;

  /// `.rl`, `.srch`, `.av`, `.map`: contenedor con imagen de fondo.
  static const double radiusTile = 22;

  /// `.bk`, `.cl`: botón cuadrado redondeado.
  static const double radiusControl = 14;

  /// `.rb`, `.nx`, `.bn`: píldora.
  static const double radiusPill = 99;

  // --- Tamaños ---------------------------------------------------------------

  /// `.bn`: alto del botón principal.
  static const double buttonHeight = 52;

  /// `.fd`: alto del campo.
  static const double fieldHeight = 54;

  /// Áreas táctiles mínimas, por accesibilidad.
  static const double minTouchTarget = 48;

  /// `maxWidth` del contenido en tablet y web.
  static const double contentMaxWidth = 520;

  /// Tema claro.
  static ThemeData light() => _build(Brightness.light, RoutbPalette.light);

  /// Tema oscuro.
  static ThemeData dark() => _build(Brightness.dark, RoutbPalette.dark);

  static ThemeData _build(Brightness brightness, RoutbPalette palette) {
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.brand,
      brightness: brightness,
    ).copyWith(
      primary: palette.brand,
      onPrimary: palette.onBrand,
      surface: palette.card,
      onSurface: palette.ink,
      surfaceContainerHighest: palette.surface,
      outlineVariant: palette.line,
      error: palette.rose,
      onError: palette.onBrand,
    );

    final textTheme = RoutbText.textTheme(palette.ink, palette.muted);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: RoutbText.body,
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      textTheme: textTheme,
      dividerColor: palette.line,
      splashFactory: InkSparkle.splashFactory,
      extensions: <ThemeExtension<dynamic>>[palette],

      // Flutter 3.47 quitó `pageTransitionsTheme` de `MaterialApp`: el
      // desplazamiento lateral de ROUTB se declara aquí para que lo hereden
      // todas las rutas.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: RoutbSlideTransitionsBuilder(),
          TargetPlatform.iOS: RoutbSlideTransitionsBuilder(),
          TargetPlatform.linux: RoutbSlideTransitionsBuilder(),
          TargetPlatform.macOS: RoutbSlideTransitionsBuilder(),
          TargetPlatform.windows: RoutbSlideTransitionsBuilder(),
        },
      ),

      iconTheme: IconThemeData(color: palette.muted, size: 18),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: palette.ink,
        iconTheme: IconThemeData(color: palette.ink, size: 22),
        titleTextStyle: textTheme.titleMedium,
      ),

      dividerTheme: DividerThemeData(
        color: palette.line,
        thickness: 1,
        space: 1,
      ),

      // Los botones propios de ROUTB son píldoras; estos valores solo evitan
      // que los controles de Material se vean ajenos al resto.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: palette.brand,
          foregroundColor: palette.onBrand,
          minimumSize: const Size.fromHeight(buttonHeight),
          textStyle: textTheme.labelLarge?.copyWith(fontFamily: RoutbText.body),
          shape: const StadiumBorder(),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.brand,
          textStyle: textTheme.labelMedium,
          shape: const StadiumBorder(),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: palette.brand),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: palette.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
      ),

      // Avisos propios: la app usa `RoutbToast`, no `SnackBar`.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: palette.background),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusField),
        ),
      ),

      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: palette.ink,
          borderRadius: BorderRadius.circular(radiusControl),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: palette.background),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: palette.brand,
        linearTrackColor: palette.line,
        circularTrackColor: palette.line,
      ),

      // Accesibilidad: el foco visible en el diseño es un anillo menta.
      focusColor: palette.mint.withValues(alpha: 0.25),
      visualDensity: VisualDensity.standard,
    );
  }

  /// Estilo de sistema para las barras de estado y navegación.
  static SystemUiOverlayStyle overlayStyleFor(Brightness brightness) {
    return brightness == Brightness.dark
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;
  }
}