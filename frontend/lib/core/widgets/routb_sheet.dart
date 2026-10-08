import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import '../theme/routb_theme.dart';

/// Hoja inferior de ROUTB, equivalente a `.sheet`.
///
/// Ocupa el 91 % de la altura, lleva asa, encabezado con botón de cierre, cuerpo
/// desplazable y pie fijo. Al abrirse sube lo justo para que el teclado no
/// tape el campo que se está rellenando.
///
/// ```dart
/// final ruta = await RoutbSheet.show<Trip>(
///   context: context,
///   title: 'Nueva ruta',
///   body: _Formulario(),
///   footer: _Publicar(),
/// );
/// ```
class RoutbSheet {
  const RoutbSheet._();

  /// Abre la hoja y devuelve el resultado con el que se cerró, o `null` si se
  /// descartó.
  static Future<T?> show<T>({
    required BuildContext context,
    required String title,
    required Widget body,
    Widget? footer,
    String? subtitle,
    double heightFactor = 0.91,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      showDragHandle: false,
      backgroundColor: context.palette.surface,
      barrierColor: const Color(0x8C0A0820),
      constraints: const BoxConstraints(maxWidth: 640),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(RoutbTheme.radiusSheet),
        ),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: heightFactor.clamp(0.5, 1.0).toDouble(),
        minChildSize: 0.5,
        maxChildSize: 1.0,
        builder: (context, scrollController) => RoutbSheetScaffold(
          title: title,
          subtitle: subtitle,
          body: body,
          footer: footer,
          scrollController: scrollController,
        ),
      ),
    );
  }
}

/// Estructura visual de una hoja de ROUTB.
class RoutbSheetScaffold extends StatelessWidget {
  const RoutbSheetScaffold({
    required this.title,
    required this.body,
    this.subtitle,
    this.footer,
    this.scrollController,
    super.key,
  });

  /// Título de la hoja.
  final String title;

  /// Texto atenuado bajo el título.
  final String? subtitle;

  /// Contenido desplazable.
  final Widget body;

  /// Pie fijo, normalmente un botón.
  final Widget? footer;

  /// Controlador de desplazamiento de la hoja redimensionable.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final media = MediaQuery.of(context);

    return Padding(
      padding: EdgeInsets.only(top: media.padding.top),
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
            // `.sg`: asa.
            Container(
              width: 44,
              height: 5,
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: palette.line,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
            // `.sh1`: encabezado con cierre.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: RoutbText.headline(22, color: palette.ink),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: RoutbText.copy(12, color: palette.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _SheetCloseButton(
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollController,
              padding: EdgeInsets.fromLTRB(
                16,
                6,
                16,
                12 + media.viewInsets.bottom,
              ),
              child: body,
            ),
          ),
          if (footer != null)
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                6,
                16,
                20 + media.viewInsets.bottom,
              ),
              child: footer,
            ),
        ],
      ),
    );
  }
}

class _SheetCloseButton extends StatelessWidget {
  const _SheetCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: 'Cerrar',
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
          child: SizedBox(
            width: 36,
            height: 36,
            child: Icon(Icons.close_rounded, size: 18, color: palette.ink),
          ),
        ),
      ),
    );
  }
}

/// `.seg`: control de dos opciones, como «Voy a la UTB / Salgo de la UTB».
class RoutbSegmented<T> extends StatelessWidget {
  const RoutbSegmented({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// Opciones del control, en orden.
  final List<({T value, String label})> options;

  /// Opción activa.
  final T value;

  /// Se dispara al cambiar de opción.
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: option.value == value,
                label: option.label,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onChanged(option.value),
                    borderRadius: BorderRadius.circular(12),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        color: option.value == value ? palette.brand : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        option.label,
                        textAlign: TextAlign.center,
                        style: RoutbText.copy(
                          13,
                          color: option.value == value
                              ? palette.onBrand
                              : palette.muted,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
