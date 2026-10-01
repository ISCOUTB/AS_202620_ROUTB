import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import '../theme/routb_theme.dart';
import 'routb_anim.dart';

/// Estilo visual de [RoutbButton].
///
/// * [primary] — `.bn`, píldora con degradado violeta.
/// * [secondary] — `.bn.t`, píldora discreta.
/// * [danger] — borde rosa, para acciones destructivas.
enum RoutbButtonVariant { primary, secondary, danger }

/// Botón de ROUTB, con etiqueta, icono opcional e indicador de carga.
class RoutbButton extends StatelessWidget {
  const RoutbButton({
    required this.label,
    this.onPressed,
    this.variant = RoutbButtonVariant.primary,
    this.icon,
    this.busy = false,
    this.height,
    this.expand = true,
    this.focusNode,
    super.key,
  });

  /// Texto del botón.
  final String label;

  /// Acción al pulsar. `null` desactiva el botón.
  final VoidCallback? onPressed;

  /// Estilo visual.
  final RoutbButtonVariant variant;

  /// Icono a la izquierda de la etiqueta.
  final IconData? icon;

  /// `true` muestra un indicador y bloquea el botón.
  final bool busy;

  /// Alto del botón.
  final double? height;

  /// `false` para que el botón ocupe solo su ancho natural.
  final bool expand;

  /// Nodo de foco externo, para mover el foco desde el código.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null && !busy;
    final radius = BorderRadius.circular(RoutbTheme.radiusPill);
    final boxHeight = height ??
        (variant == RoutbButtonVariant.secondary ? 46.0 : RoutbTheme.buttonHeight);

    final BoxDecoration decoration;
    final Color foreground;

    if (!enabled) {
      decoration = BoxDecoration(color: palette.line, borderRadius: radius);
      foreground = palette.muted;
    } else {
      switch (variant) {
        case RoutbButtonVariant.primary:
          decoration = BoxDecoration(
            gradient: palette.primaryGradient,
            borderRadius: radius,
            boxShadow: palette.raisedShadow,
          );
          foreground = palette.onBrand;
        case RoutbButtonVariant.secondary:
          decoration = BoxDecoration(
            color: palette.surface,
            borderRadius: radius,
          );
          foreground = palette.brand;
        case RoutbButtonVariant.danger:
          decoration = BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: palette.rose, width: 1.5),
          );
          foreground = palette.rose;
      }
    }

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (busy)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(foreground),
            ),
          )
        else if (icon != null)
          Icon(icon, size: 18, color: foreground),
        if (busy || icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: RoutbText.copy(
              variant == RoutbButtonVariant.secondary ? 13 : 15,
              color: foreground,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Pressable(
        onTap: enabled ? onPressed : null,
        borderRadius: radius,
        focusNode: focusNode,
        child: SizedBox(
          height: boxHeight,
          width: expand ? double.infinity : null,
          child: DecoratedBox(
            decoration: decoration,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Center(child: content),
            ),
          ),
        ),
      ),
    );
  }
}

/// Botón cuadrado redondeado del diseño: `.bk`, `.cl` y `.swp`.
class RoutbIconButton extends StatelessWidget {
  const RoutbIconButton({
    required this.icon,
    required this.onPressed,
    this.size = 40,
    this.background,
    this.foreground,
    this.semanticLabel,
    this.tooltip,
    this.showShadow = true,
    super.key,
  });

  /// Icono del botón.
  final IconData icon;

  /// Acción al pulsar.
  final VoidCallback? onPressed;

  /// Lado del botón.
  final double size;

  /// Relleno; por defecto la superficie.
  final Color? background;

  /// Color del icono; por defecto el violeta de marca.
  final Color? foreground;

  /// Etiqueta para el lector de pantalla.
  final String? semanticLabel;

  /// Texto del tooltip.
  final String? tooltip;

  /// `false` para mostrarlo sin sombra, como el botón de invertir trayecto.
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final button = Pressable(
      onTap: onPressed,
      semanticLabel: semanticLabel,
      borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background ?? palette.surface,
            borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
            boxShadow: showShadow ? palette.cardShadow : null,
          ),
          child: Icon(
            icon,
            size: size * 0.45,
            color: foreground ?? palette.brand,
          ),
        ),
      ),
    );

    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Acción de texto ligera, como el `.wk` de «Lun a vie» o «Cancelar ruta».
class RoutbTextAction extends StatelessWidget {
  const RoutbTextAction({
    required this.label,
    required this.onPressed,
    this.color,
    this.icon,
    super.key,
  });

  /// Texto de la acción.
  final String label;

  /// Acción al pulsar.
  final VoidCallback? onPressed;

  /// Color del texto; por defecto el violeta de marca.
  final Color? color;

  /// Icono opcional a la izquierda.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final enabled = onPressed != null;
    final tint = enabled ? (color ?? palette.brand) : palette.muted;

    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 16, color: tint),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: RoutbText.copy(12.5, color: tint, weight: FontWeight.w700),
        ),
      ],
    );

    if (!enabled) return child;

    return Pressable(
      onTap: onPressed,
      semanticLabel: label,
      borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
      child: child,
    );
  }
}