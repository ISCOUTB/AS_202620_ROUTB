import 'package:flutter/material.dart';

/// Tokens de color, sombra y degradado de ROUTB.
///
/// Cada constructor ([light] y [dark]) reproduce el juego de variables CSS del
/// diseño: `--bg`, `--ink`, `--mut`, `--card`, `--sf`, `--line`, `--brand`,
/// `--mint`, `--amber` y `--rose`, junto con `--sh` y los degradados que se
/// usan en el hero, los botones y los cupos.
///
/// Se registra como [ThemeExtension] para que ningún widget tenga que leer
/// [ThemeData] a mano ni fijar colores literales.
///
/// ```dart
/// final palette = RoutbPalette.of(context);
/// ```
@immutable
class RoutbPalette extends ThemeExtension<RoutbPalette> {
  const RoutbPalette({
    required this.background,
    required this.ink,
    required this.muted,
    required this.card,
    required this.surface,
    required this.line,
    required this.brand,
    required this.mint,
    required this.amber,
    required this.rose,
    required this.onBrand,
    required this.onMint,
    required this.onAmber,
    required this.brandSurface,
    required this.onBrandSurface,
    required this.mintSurface,
    required this.onMintSurface,
    required this.amberSurface,
    required this.onAmberSurface,
    required this.roseSurface,
    required this.onRoseSurface,
    required this.heroMuted,
    required this.cardShadow,
    required this.raisedShadow,
    required this.searchShadow,
    required this.primaryGradient,
    required this.mintGradient,
    required this.avatarGradient,
    required this.warmGradient,
    required this.heroGradient,
    required this.heroGlow,
  });

  // --- Superficies y texto -------------------------------------------------

  /// Fondo de la aplicación y de las hojas modales.
  final Color background;

  /// Color de texto principal.
  final Color ink;

  /// Color de texto secundario y de etiquetas.
  final Color muted;

  /// Fondo de tarjetas y campos.
  final Color card;

  /// Fondo de contenedores internos: campos, filas, mapa.
  final Color surface;

  /// Color de bordes y separadores.
  final Color line;

  // --- Acentos -------------------------------------------------------------

  /// Violeta de marca. Botones, campos activos y elementos seleccionados.
  final Color brand;

  /// Verde menta. Cupos libres, disponibilidad y confirmaciones.
  final Color mint;

  /// Ámbar. Récords nuevos, cupos por ocupar y estados en espera.
  final Color amber;

  /// Rosa. Rechazos, cancelaciones y acciones destructivas.
  final Color rose;

  /// Texto legible sobre [brand].
  final Color onBrand;

  /// Texto legible sobre [mint].
  final Color onMint;

  /// Texto legible sobre [amber].
  final Color onAmber;

  // --- Superficies de estado ------------------------------------------------

  /// Relleno translúcido de marca para insignias.
  final Color brandSurface;

  /// Texto sobre [brandSurface].
  final Color onBrandSurface;

  /// Relleno de las etiquetas de éxito.
  final Color mintSurface;

  /// Texto sobre [mintSurface].
  final Color onMintSurface;

  /// Relleno de las etiquetas en espera.
  final Color amberSurface;

  /// Texto sobre [amberSurface].
  final Color onAmberSurface;

  /// Relleno de las etiquetas de error o cancelación.
  final Color roseSurface;

  /// Texto sobre [roseSurface].
  final Color onRoseSurface;

  /// Texto atenuado dentro del hero, que siempre es blanco sobre violeta.
  final Color heroMuted;

  // --- Sombras --------------------------------------------------------------

  /// `--sh`: sombra de tarjeta.
  final List<BoxShadow> cardShadow;

  /// Sombra de los elementos que flotan por encima del contenido.
  final List<BoxShadow> raisedShadow;

  /// Sombra de las superficies claras que se despegan del fondo, como el
  /// buscador del pasajero.
  final List<BoxShadow> searchShadow;

  // --- Degradados ------------------------------------------------------------

  /// Botón principal y fondo de los iconos de rol.
  final Gradient primaryGradient;

  /// Cupo ocupado.
  final Gradient mintGradient;

  /// Avatar con iniciales.
  final Gradient avatarGradient;

  /// Acento cálido del segundo rol y de los Conductores.
  final Gradient warmGradient;

  /// Base del hero.
  final Gradient heroGradient;

  /// Resplandor del extremo superior derecho del hero.
  final RadialGradient heroGlow;

  // --- Instancias ------------------------------------------------------------

  /// Juego de color claro (Azul Rey UTB).
  static const RoutbPalette light = RoutbPalette(
    background: Color(0xFFF1F5F9),
    ink: Color(0xFF0F172A),
    muted: Color(0xFF5A6E85),
    card: Color(0xFFFFFFFF),
    surface: Color(0xFFF8FAFC),
    line: Color(0xFFD3DFEE),
    brand: Color(0xFF0D59D6),
    mint: Color(0xFF10B981),
    amber: Color(0xFFF59E0B),
    rose: Color(0xFFEF4444),
    onBrand: Color(0xFFFFFFFF),
    onMint: Color(0xFF06402C),
    onAmber: Color(0xFF4A2D00),
    brandSurface: Color(0x1F0D59D6),
    onBrandSurface: Color(0xFF0D59D6),
    mintSurface: Color(0xFFDCFCE7),
    onMintSurface: Color(0xFF065F46),
    amberSurface: Color(0xFFFEF3C7),
    onAmberSurface: Color(0xFF92400E),
    roseSurface: Color(0xFFFEE2E2),
    onRoseSurface: Color(0xFF991B1B),
    heroMuted: Color(0xB8FFFFFF),
    cardShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x1F0A2540),
        blurRadius: 30,
        offset: Offset(0, 12),
        spreadRadius: -14,
      ),
    ],
    raisedShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x590D59D6),
        blurRadius: 24,
        offset: Offset(0, 12),
        spreadRadius: -8,
      ),
    ],
    searchShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x260A2540),
        blurRadius: 28,
        offset: Offset(0, 14),
        spreadRadius: -14,
      ),
    ],
    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF1E6BFF), Color(0xFF0B4CC0)],
    ),
    mintGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF34D399), Color(0xFF059669)],
    ),
    avatarGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF0D59D6), Color(0xFF0284C7)],
    ),
    warmGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFFFB347), Color(0xFFFF8A00)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF091B3A), Color(0xFF0F3E8A)],
    ),
    heroGlow: RadialGradient(
      center: Alignment(0.9, -1),
      radius: 1.25,
      colors: <Color>[Color(0xFF2563EB), Color(0x002563EB)],
      stops: <double>[0, 0.55],
    ),
  );

  /// Juego de color oscuro (Azul Rey Noche).
  static const RoutbPalette dark = RoutbPalette(
    background: Color(0xFF09101D),
    ink: Color(0xFFF1F5F9),
    muted: Color(0xFF8B9FB8),
    card: Color(0xFF111E36),
    surface: Color(0xFF0D172A),
    line: Color(0xFF1E3252),
    brand: Color(0xFF0D59D6),
    mint: Color(0xFF10B981),
    amber: Color(0xFFF59E0B),
    rose: Color(0xFFEF4444),
    onBrand: Color(0xFFFFFFFF),
    onMint: Color(0xFF06402C),
    onAmber: Color(0xFF4A2D00),
    brandSurface: Color(0x330D59D6),
    onBrandSurface: Color(0xFF93C5FD),
    mintSurface: Color(0x3310B981),
    onMintSurface: Color(0xFF6EE7B7),
    amberSurface: Color(0x33F59E0B),
    onAmberSurface: Color(0xFFFCD34D),
    roseSurface: Color(0x33EF4444),
    onRoseSurface: Color(0xFFFCA5A5),
    heroMuted: Color(0xB8FFFFFF),
    cardShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x99000000),
        blurRadius: 30,
        offset: Offset(0, 12),
        spreadRadius: -14,
      ),
    ],
    raisedShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 24,
        offset: Offset(0, 12),
        spreadRadius: -8,
      ),
    ],
    searchShadow: <BoxShadow>[
      BoxShadow(
        color: Color(0x8C000000),
        blurRadius: 28,
        offset: Offset(0, 14),
        spreadRadius: -14,
      ),
    ],
    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF3B82F6), Color(0xFF1D4ED8)],
    ),
    mintGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF34D399), Color(0xFF059669)],
    ),
    avatarGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF2563EB), Color(0xFF0284C7)],
    ),
    warmGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFFFFB347), Color(0xFFFF8A00)],
    ),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: <Color>[Color(0xFF060F1E), Color(0xFF0C2B5E)],
    ),
    heroGlow: RadialGradient(
      center: Alignment(0.9, -1),
      radius: 1.25,
      colors: <Color>[Color(0xFF3B82F6), Color(0x003B82F6)],
      stops: <double>[0, 0.55],
    ),
  );

  /// Paleta activa del tema más cercano.
  ///
  /// Lanza si se usa fuera de un `MaterialApp` con el tema de ROUTB instalado.
  static RoutbPalette of(BuildContext context) {
    final palette = Theme.of(context).extension<RoutbPalette>();
    assert(palette != null, 'No hay RoutbPalette en el tema activo.');
    return palette!;
  }

  @override
  RoutbPalette copyWith({
    Color? background,
    Color? ink,
    Color? muted,
    Color? card,
    Color? surface,
    Color? line,
    Color? brand,
    Color? mint,
    Color? amber,
    Color? rose,
    Color? onBrand,
    Color? onMint,
    Color? onAmber,
    Color? brandSurface,
    Color? onBrandSurface,
    Color? mintSurface,
    Color? onMintSurface,
    Color? amberSurface,
    Color? onAmberSurface,
    Color? roseSurface,
    Color? onRoseSurface,
    Color? heroMuted,
    List<BoxShadow>? cardShadow,
    List<BoxShadow>? raisedShadow,
    List<BoxShadow>? searchShadow,
    Gradient? primaryGradient,
    Gradient? mintGradient,
    Gradient? avatarGradient,
    Gradient? warmGradient,
    Gradient? heroGradient,
    RadialGradient? heroGlow,
  }) {
    return RoutbPalette(
      background: background ?? this.background,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      card: card ?? this.card,
      surface: surface ?? this.surface,
      line: line ?? this.line,
      brand: brand ?? this.brand,
      mint: mint ?? this.mint,
      amber: amber ?? this.amber,
      rose: rose ?? this.rose,
      onBrand: onBrand ?? this.onBrand,
      onMint: onMint ?? this.onMint,
      onAmber: onAmber ?? this.onAmber,
      brandSurface: brandSurface ?? this.brandSurface,
      onBrandSurface: onBrandSurface ?? this.onBrandSurface,
      mintSurface: mintSurface ?? this.mintSurface,
      onMintSurface: onMintSurface ?? this.onMintSurface,
      amberSurface: amberSurface ?? this.amberSurface,
      onAmberSurface: onAmberSurface ?? this.onAmberSurface,
      roseSurface: roseSurface ?? this.roseSurface,
      onRoseSurface: onRoseSurface ?? this.onRoseSurface,
      heroMuted: heroMuted ?? this.heroMuted,
      cardShadow: cardShadow ?? this.cardShadow,
      raisedShadow: raisedShadow ?? this.raisedShadow,
      searchShadow: searchShadow ?? this.searchShadow,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      mintGradient: mintGradient ?? this.mintGradient,
      avatarGradient: avatarGradient ?? this.avatarGradient,
      warmGradient: warmGradient ?? this.warmGradient,
      heroGradient: heroGradient ?? this.heroGradient,
      heroGlow: heroGlow ?? this.heroGlow,
    );
  }

  @override
  RoutbPalette lerp(covariant RoutbPalette? other, double t) {
    if (other == null) return this;
    return RoutbPalette(
      background: Color.lerp(background, other.background, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      card: Color.lerp(card, other.card, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      line: Color.lerp(line, other.line, t)!,
      brand: Color.lerp(brand, other.brand, t)!,
      mint: Color.lerp(mint, other.mint, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      rose: Color.lerp(rose, other.rose, t)!,
      onBrand: Color.lerp(onBrand, other.onBrand, t)!,
      onMint: Color.lerp(onMint, other.onMint, t)!,
      onAmber: Color.lerp(onAmber, other.onAmber, t)!,
      brandSurface: Color.lerp(brandSurface, other.brandSurface, t)!,
      onBrandSurface: Color.lerp(onBrandSurface, other.onBrandSurface, t)!,
      mintSurface: Color.lerp(mintSurface, other.mintSurface, t)!,
      onMintSurface: Color.lerp(onMintSurface, other.onMintSurface, t)!,
      amberSurface: Color.lerp(amberSurface, other.amberSurface, t)!,
      onAmberSurface: Color.lerp(onAmberSurface, other.onAmberSurface, t)!,
      roseSurface: Color.lerp(roseSurface, other.roseSurface, t)!,
      onRoseSurface: Color.lerp(onRoseSurface, other.onRoseSurface, t)!,
      heroMuted: Color.lerp(heroMuted, other.heroMuted, t)!,
      cardShadow: _lerpShadow(cardShadow, other.cardShadow, t),
      raisedShadow: _lerpShadow(raisedShadow, other.raisedShadow, t),
      searchShadow: _lerpShadow(searchShadow, other.searchShadow, t),
      primaryGradient: _lerpGradient(primaryGradient, other.primaryGradient, t),
      mintGradient: _lerpGradient(mintGradient, other.mintGradient, t),
      avatarGradient: _lerpGradient(avatarGradient, other.avatarGradient, t),
      warmGradient: _lerpGradient(warmGradient, other.warmGradient, t),
      heroGradient: _lerpGradient(heroGradient, other.heroGradient, t),
      heroGlow: RadialGradient.lerp(heroGlow, other.heroGlow, t)!,
    );
  }

  static List<BoxShadow> _lerpShadow(
    List<BoxShadow> a,
    List<BoxShadow> b,
    double t,
  ) {
    if (a.length != b.length) return t < 0.5 ? a : b;
    return <BoxShadow>[
      for (var i = 0; i < a.length; i++) BoxShadow.lerp(a[i], b[i], t)!,
    ];
  }

  static Gradient _lerpGradient(Gradient a, Gradient b, double t) {
    if (a is LinearGradient && b is LinearGradient) {
      return LinearGradient.lerp(a, b, t)!;
    }
    if (a is RadialGradient && b is RadialGradient) {
      return RadialGradient.lerp(a, b, t)!;
    }
    return t < 0.5 ? a : b;
  }
}

/// Atajo para leer la paleta desde un `BuildContext`.
extension RoutbPaletteAccess on BuildContext {
  /// Tokens de color del tema activo.
  RoutbPalette get palette => RoutbPalette.of(this);

  /// `true` cuando el tema activo es el oscuro.
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
}
