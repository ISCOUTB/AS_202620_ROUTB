import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import '../theme/routb_theme.dart';

/// Tarjeta del diseño: fondo de tarjeta, esquinas de 24 y sombra suave.
///
/// ```dart
/// const RoutbCard(
///   child: RoutbCardHeader(title: 'Solicitudes'),
/// )
/// ```
class RoutbCard extends StatelessWidget {
  const RoutbCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.borderColor,
    this.borderWidth = 0,
    this.semanticLabel,
    super.key,
  });

  /// Contenido de la tarjeta.
  final Widget child;

  /// Espacio interior.
  final EdgeInsetsGeometry padding;

  /// Espacio exterior.
  final EdgeInsetsGeometry? margin;

  /// Si se indica, la tarjeta responde al toque con la marca de [Pressable].
  final VoidCallback? onTap;

  /// Color del borde, para estados seleccionados o de error.
  final Color? borderColor;

  /// Grosor del borde.
  final double borderWidth;

  /// Etiqueta para el lector de pantalla.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final decoration = BoxDecoration(
      color: palette.card,
      borderRadius: BorderRadius.circular(RoutbTheme.radiusCard),
      boxShadow: palette.cardShadow,
      border: borderWidth > 0 && borderColor != null
          ? Border.all(color: borderColor!, width: borderWidth)
          : null,
    );

    final content = Padding(padding: padding, child: child);

    if (onTap == null) {
      return Semantics(
        label: semanticLabel,
        container: true,
        child: Container(
          margin: margin,
          decoration: decoration,
          child: content,
        ),
      );
    }

    return Container(
      margin: margin,
      decoration: decoration,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(RoutbTheme.radiusCard),
          child: content,
        ),
      ),
    );
  }
}

/// Encabezado de tarjeta: icono opcional, título en titular y contador.
class RoutbCardHeader extends StatelessWidget {
  const RoutbCardHeader({
    required this.title,
    this.icon,
    this.count,
    this.trailing,
    super.key,
  });

  /// Texto del encabezado.
  final String title;

  /// Icono a la izquierda del título.
  final IconData? icon;

  /// Número que se muestra en la insignia del título.
  final int? count;

  /// Elemento a la derecha del encabezado.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: palette.ink),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (count != null && count! > 0) ...[
            RoutbBadge(
              text: '$count',
              background: palette.amber,
              foreground: palette.onAmber,
            ),
            const SizedBox(width: 8),
          ],
          if (trailing != null) ?trailing,
        ],
      ),
    );
  }
}

/// `.bd`: contador ámbar de una tarjeta.
class RoutbBadge extends StatelessWidget {
  const RoutbBadge({
    required this.text,
    required this.background,
    required this.foreground,
    this.dense = false,
    super.key,
  });

  /// Texto del contador.
  final String text;

  /// Color de relleno.
  final Color background;

  /// Color del texto.
  final Color foreground;

  /// Versión más pequeña para insignias dentro de una tarjeta.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 7 : 9,
        vertical: dense ? 2 : 2,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusPill),
      ),
      child: Text(
        text,
        style: RoutbText.copy(
          dense ? 10 : 11,
          color: foreground,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// `.rc`: insignia de rol bajo el encabezado de registro.
class RoutbChipLabel extends StatelessWidget {
  const RoutbChipLabel({required this.label, super.key});

  /// Texto de la insignia.
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: palette.brandSurface,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusPill),
      ),
      child: Text(
        label,
        style: RoutbText.copy(12, color: palette.onBrandSurface,
            weight: FontWeight.w700),
      ),
    );
  }
}

/// Etiqueta atenuada para subtítulos secundarios.
class RoutbHint extends StatelessWidget {
  const RoutbHint(this.text, {this.margin, super.key});

  /// Texto atenuado.
  final String text;

  /// Espacio exterior.
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Text(
        text,
        style: RoutbText.copy(12, color: palette.muted),
      ),
    );
  }
}