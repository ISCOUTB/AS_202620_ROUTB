import 'package:flutter/material.dart';

import '../models/trip.dart';
import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';

/// Hora de salida y recorrido en el mismo orden en los dos modos.
class RoutbJourneySchedule extends StatelessWidget {
  const RoutbJourneySchedule({
    required this.trip,
    this.stops = const [],
    this.compact = false,
    super.key,
  });

  final Trip trip;
  final bool compact;
  final List<String> stops;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    late final time = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          trip.departureDateLabel,
          style: RoutbText.copy(12, color: p.muted),
        ),
        Wrap(
          spacing: 4,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(
              trip.departureClockLabel,
              style: RoutbText.headline(29, color: p.ink, height: 1.1),
            ),
            if (trip.departureMeridiem.isNotEmpty)
              Text(
                trip.departureMeridiem,
                style: RoutbText.copy(
                  12,
                  color: p.muted,
                  weight: FontWeight.w700,
                ),
              ),
          ],
        ),
      ],
    );
    final places = [trip.origin, ...stops, trip.destination];
    final route = Stack(
      children: [
        Positioned(
          left: 4,
          top: 12,
          bottom: 12,
          width: 2,
          child: ColoredBox(color: p.line),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, place) in places.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: index == places.length - 1 ? p.mint : p.card,
                        borderRadius: BorderRadius.circular(
                          index == places.length - 1 ? 2 : 8,
                        ),
                        border: Border.all(
                          width: 2,
                          color: index == places.length - 1
                              ? p.onMintSurface
                              : p.onBrandSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        place,
                        semanticsLabel:
                            '${index == 0
                                ? 'Origen'
                                : index == places.length - 1
                                ? 'Destino'
                                : 'Parada confirmada'}: $place',
                        style: RoutbText.headline(16, color: p.ink),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                trip.departureDateLabel,
                style: RoutbText.copy(12, color: p.muted),
              ),
              Text(
                trip.departureLabel,
                style: RoutbText.copy(
                  14,
                  color: p.onBrandSurface,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          route,
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <
            MediaQuery.textScalerOf(context).scale(245)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [time, const SizedBox(height: 12), route],
          );
        }
        return Row(
          children: [
            Expanded(flex: 2, child: time),
            const SizedBox(width: 12),
            Expanded(flex: 3, child: route),
          ],
        );
      },
    );
  }
}
