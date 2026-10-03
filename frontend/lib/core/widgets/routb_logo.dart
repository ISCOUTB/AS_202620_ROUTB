import 'package:flutter/material.dart';

/// Variante del símbolo de ROUTB.
///
/// La marca es la letra «R» trazada como un recorrido con nodos naranjas. El
/// nombre no forma parte del símbolo: el título de la pantalla y el saludo del
/// hero ya dicen ROUTB, y repetirlo en cada logo competía con ese texto.
///
/// | Variante | Fondo | Asset |
/// |---|---|---|
/// | [onHero] | oscuro | `routb_marca_blanca.png` |
/// | [onSurface] | claro | `routb_marca_oscura.png` |
enum RoutbLogoVariant {
  /// Marca en blanco, para el hero violeta y el splash en tema oscuro.
  onHero,

  /// Marca en tinta, para el acceso y el splash en tema claro.
  onSurface;

  /// Ruta del asset.
  String get asset => switch (this) {
        RoutbLogoVariant.onHero => 'assets/images/routb_marca_blanca.png',
        RoutbLogoVariant.onSurface => 'assets/images/routb_marca_oscura.png',
      };

  /// `true` si el fondo donde se pinta es oscuro.
  bool get isForDarkBackground => this == RoutbLogoVariant.onHero;
}

/// Elige la variante del símbolo según el fondo donde se va a pintar.
///
/// El resultado no depende de la variante de partida: sobre fondo oscuro siempre
/// va la marca blanca, y sobre fondo claro la de tinta.
extension RoutbLogoVariantTheme on RoutbLogoVariant {
  /// Variante para el fondo [isDarkBackground].
  RoutbLogoVariant forBackground(bool isDarkBackground) => isDarkBackground
      ? RoutbLogoVariant.onHero
      : RoutbLogoVariant.onSurface;
}

/// Proporción del símbolo, tal como viene en el asset.
const double kRoutbLogoAspectRatio = 130 / 141;

/// Símbolo de ROUTB.
///
/// ```dart
/// const RoutbLogo(width: 84)
/// ```
class RoutbLogo extends StatelessWidget {
  const RoutbLogo({
    required this.variant,
    this.width,
    this.height,
    this.semanticLabel = 'ROUTB',
    super.key,
  });

  /// Variante del arte a mostrar.
  final RoutbLogoVariant variant;

  /// Ancho deseado.
  final double? width;

  /// Alto deseado. Si se omite se deduce del ancho con la proporción del asset.
  final double? height;

  /// Texto que anuncia el lector de pantalla.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      variant.asset,
      width: width,
      height: height ?? (width == null ? null : width! / kRoutbLogoAspectRatio),
      fit: BoxFit.contain,
      semanticLabel: semanticLabel,
      filterQuality: FilterQuality.medium,
    );
  }
}