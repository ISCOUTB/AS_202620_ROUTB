import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import '../theme/routb_theme.dart';

/// `.fd`: campo con icono a la izquierda y borde que se pinta al escribir.
///
/// A diferencia de un `TextFormField` con `InputDecoration`, el contenedor es
/// el que lleva el fondo y el borde, y el campo va transparente encima. Así el
/// resultado es idéntico al del diseño en cualquier plataforma.
///
/// ```dart
/// RoutbField(
///   icon: Icons.phone,
///   hint: 'Número de teléfono',
///   controller: _phone,
///   keyboardType: TextInputType.phone,
/// )
/// ```
class RoutbField extends StatefulWidget {
  const RoutbField({
    required this.hint,
    this.controller,
    this.icon,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.prefixText,
    this.obscureToggle = false,
    this.errorText,
    this.suffix,
    this.onSubmitted,
    this.onChanged,
    this.autofocus = false,
    this.textInputAction,
    this.focusNode,
    super.key,
  });

  /// Texto que se ve cuando el campo está vacío.
  final String hint;

  /// Controlador del texto.
  final TextEditingController? controller;

  /// Icono a la izquierda.
  final IconData? icon;

  /// Tipo de teclado.
  final TextInputType? keyboardType;

  /// Mayúsculas y minúsculas automáticas.
  final TextCapitalization textCapitalization;

  /// Texto fijo antes del campo, como el `+57` del teléfono.
  final String? prefixText;

  /// Filtros de entrada.
  final List<TextInputFormatter>? inputFormatters;

  /// `true` añade el botón de mostrar u ocultar contraseña.
  final bool obscureToggle;

  /// Mensaje de error bajo el campo.
  final String? errorText;

  /// Widget a la derecha, en el hueco del botón de contraseña.
  final Widget? suffix;

  /// Se dispara al enviar desde el teclado.
  final ValueChanged<String>? onSubmitted;

  /// Se dispara en cada cambio.
  final ValueChanged<String>? onChanged;

  /// `true` para pedir el foco al abrir la pantalla.
  final bool autofocus;

  /// Acción del botón del teclado.
  final TextInputAction? textInputAction;

  /// Nodo de foco externo, cuando hay que moverlo desde otro widget.
  final FocusNode? focusNode;

  @override
  State<RoutbField> createState() => _RoutbFieldState();
}

class _RoutbFieldState extends State<RoutbField> {
  late FocusNode _focusNode;
  bool _obscured = true;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChanged);
    widget.controller?.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(RoutbField oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onTextChanged);
      widget.controller?.addListener(_onTextChanged);
    }

    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_onFocusChanged);
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    // Solo se destruye el nodo propio: uno recibido por parámetro es de quien
    // lo creó.
    if (widget.focusNode == null) _focusNode.dispose();
    widget.controller?.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onFocusChanged() {
    if (!mounted) return;
    setState(() => _focused = _focusNode.hasFocus);
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  bool get _hasError => widget.errorText != null && widget.errorText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: RoutbTheme.fieldHeight,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: _focused ? palette.card : palette.surface,
            borderRadius: BorderRadius.circular(RoutbTheme.radiusField),
            border: Border.all(
              color: _hasError
                  ? palette.rose
                  : _focused
                      ? palette.brand
                      : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              if (widget.prefixText != null) ...[
                Text(
                  widget.prefixText!,
                  style: RoutbText.copy(14, color: palette.ink),
                ),
                const SizedBox(width: 6),
                Container(
                  width: 1,
                  height: 18,
                  color: palette.line,
                ),
                const SizedBox(width: 12),
              ],
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 18,
                  color: _focused ? palette.brand : palette.muted,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  autofocus: widget.autofocus,
                  obscureText: widget.obscureToggle && _obscured,
                  keyboardType: widget.keyboardType,
                  textCapitalization: widget.textCapitalization,
                  inputFormatters: widget.inputFormatters,
                  textInputAction: widget.textInputAction,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  cursorColor: palette.brand,
                  cursorWidth: 2,
                  cursorRadius: const Radius.circular(1),
                  style: RoutbText.copy(14, color: palette.ink),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: widget.hint,
                    hintStyle: RoutbText.copy(14, color: palette.muted),
                  ),
                ),
              ),
              if (widget.obscureToggle)
                _EyeButton(
                  hidden: _obscured,
                  onToggle: () => setState(() => _obscured = !_obscured),
                )
              else if (widget.suffix != null)
                widget.suffix!,
            ],
          ),
        ),
        if (_hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 14),
            child: Text(
              widget.errorText!,
              style: RoutbText.copy(12, color: palette.rose),
            ),
          ),
      ],
    );
  }
}

/// `.ey`: botón de mostrar u ocultar contraseña.
class _EyeButton extends StatelessWidget {
  const _EyeButton({required this.hidden, required this.onToggle});

  final bool hidden;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      label: hidden ? 'Mostrar contraseña' : 'Ocultar contraseña',
      child: InkResponse(
        onTap: onToggle,
        radius: 24,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            hidden
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            size: 18,
            color: palette.muted,
          ),
        ),
      ),
    );
  }
}

/// `.ck`: casilla de aceptación con la marca blanca del diseño.
class RoutbCheckbox extends StatelessWidget {
  const RoutbCheckbox({
    required this.value,
    required this.onChanged,
    required this.label,
    super.key,
  });

  /// `true` si está marcada.
  final bool value;

  /// Se dispara al cambiar.
  final ValueChanged<bool>? onChanged;

  /// Texto junto a la casilla.
  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: value ? palette.brand : Colors.transparent,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: value ? palette.brand : palette.line,
          width: 2,
        ),
      ),
      child: value
          ? const Icon(Icons.check_rounded, size: 15, color: Colors.white)
          : null,
    );

    final enabled = onChanged != null;

    return Semantics(
      checked: value,
      enabled: enabled,
      label: label,
      child: InkWell(
        onTap: enabled ? () => onChanged!(!value) : null,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusControl),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              box,
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: RoutbText.copy(13, color: palette.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.bch`: chip de selección del trayecto.
class RoutbChip extends StatelessWidget {
  const RoutbChip({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  /// Texto del chip.
  final String label;

  /// `true` si está seleccionado.
  final bool selected;

  /// Acción al pulsar.
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusPill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? palette.ink : palette.card,
            borderRadius: BorderRadius.circular(RoutbTheme.radiusPill),
            border: Border.all(
              color: selected ? palette.ink : palette.line,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: RoutbText.copy(
              12.5,
              color: selected ? palette.background : palette.ink,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// `.pl`: píldora de estado del viaje.
class RoutbStatusPill extends StatelessWidget {
  const RoutbStatusPill({
    required this.label,
    required this.background,
    required this.foreground,
    this.icon,
    super.key,
  });

  /// Texto del estado.
  final String label;

  /// Relleno.
  final Color background;

  /// Color del texto.
  final Color foreground;

  /// Icono opcional a la izquierda.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(RoutbTheme.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: RoutbText.copy(11, color: foreground, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}