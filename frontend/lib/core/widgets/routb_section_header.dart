import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import 'routb_campus_cover.dart';

/// Portada de las pestañas secundarias. En ventanas anchas, el contenido
/// principal acompaña la portada y los controles se desplazan a su derecha.
class RoutbSectionPage extends StatelessWidget {
  const RoutbSectionPage({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.body,
    this.primary,
    super.key,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? primary;
  final Widget Function(bool split) body;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final split = constraints.maxWidth >= 800;
        final compact =
            (!split && constraints.maxHeight < 620) ||
            MediaQuery.textScalerOf(context).scale(16) > 24;
        final cover = Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          decoration: BoxDecoration(
            color: p.brand,
            borderRadius: BorderRadius.circular(22),
          ),
          child: RoutbCampusCover(
            child: Container(
              padding: EdgeInsets.all(compact ? 12 : 18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    p.brand,
                    p.brand.withValues(alpha: 0.88),
                    p.brand.withValues(alpha: 0),
                  ],
                  stops: const [0, .42, 1],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!compact && split) ...[
                    Icon(icon, color: p.onBrand, size: 22),
                    const SizedBox(height: 8),
                  ],
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: RoutbText.headline(
                        compact ? 23 : 32,
                        color: p.onBrand,
                      ),
                    ),
                  ),
                  if (!compact)
                    Text(subtitle, style: RoutbText.copy(13, color: p.onBrand)),
                ],
              ),
            ),
          ),
        );
        if (!split) {
          return Column(
            children: [
              cover,
              Expanded(child: body(split)),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                primary: false,
                child: Column(
                  children: [
                    cover,
                    if (primary != null)
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: primary,
                      ),
                  ],
                ),
              ),
            ),
            Expanded(flex: 6, child: body(split)),
          ],
        );
      },
    );
  }
}
