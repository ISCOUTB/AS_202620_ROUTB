import 'package:flutter/material.dart';

import '../models/user_role.dart';
import '../theme/routb_palette.dart';

/// Estado de la modalidad disponible en la navegación de la sesión.
class TravelModeScope extends InheritedWidget {
  const TravelModeScope({
    required this.mode,
    required this.driverEnabled,
    required this.busy,
    required this.onSelect,
    required super.child,
    super.key,
  });
  final UserRole mode;
  final bool driverEnabled;
  final bool busy;
  final ValueChanged<UserRole> onSelect;

  static TravelModeScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TravelModeScope>();

  @override
  bool updateShouldNotify(TravelModeScope oldWidget) =>
      mode != oldWidget.mode ||
      driverEnabled != oldWidget.driverEnabled ||
      busy != oldWidget.busy;
}

class TravelModeSelector extends StatelessWidget {
  const TravelModeSelector({this.inProfile = false, super.key});
  final bool inProfile;

  @override
  Widget build(BuildContext context) {
    final scope = TravelModeScope.maybeOf(context);
    if (scope == null) return const SizedBox.shrink();
    final driver = scope.mode == UserRole.driver;
    if (inProfile && !scope.driverEnabled) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: scope.busy ? null : () => scope.onSelect(UserRole.driver),
          icon: const Icon(Icons.directions_car_outlined),
          label: const Text('Quiero ser conductor'),
        ),
      );
    }
    final color = context.palette.onBrandSurface;
    return Align(
      alignment: Alignment.centerRight,
      child: PopupMenuButton<UserRole>(
        enabled: !scope.busy,
        tooltip: 'Cambiar modo de viaje',
        initialValue: scope.mode,
        onSelected: scope.onSelect,
        itemBuilder: (_) => [
          CheckedPopupMenuItem(
            value: UserRole.passenger,
            checked: !driver,
            child: const Text('Pasajero'),
          ),
          CheckedPopupMenuItem(
            value: UserRole.driver,
            checked: driver,
            child: Text(
              scope.driverEnabled ? 'Conductor' : 'Quiero ser conductor',
            ),
          ),
        ],
        child: Container(
          decoration: BoxDecoration(
            color: context.palette.brandSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                driver ? Icons.directions_car_outlined : Icons.person_outline,
                size: 18,
                color: color,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(scope.mode.label, style: TextStyle(color: color)),
              ),
              if (scope.busy)
                const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Icon(Icons.expand_more, size: 18, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
