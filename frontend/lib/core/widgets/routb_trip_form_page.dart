import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import 'routb_campus_cover.dart';

/// Página de formulario con portada desplazable y acción siempre accesible.
class RoutbTripFormPage extends StatelessWidget {
  const RoutbTripFormPage({
    required this.title,
    required this.subtitle,
    required this.body,
    this.footer,
    this.busy = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget body;
  final Widget? footer;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PopScope(
      canPop: !busy,
      child: AbsorbPointer(
        absorbing: busy,
        child: Scaffold(
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: RoutbCampusCover(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      p.brand,
                                      p.brand.withValues(alpha: .92),
                                      p.brand.withValues(alpha: .22),
                                    ],
                                    stops: const [0, .45, 1],
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    8,
                                    20,
                                    20,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      BackButton(color: p.onBrand),
                                      const SizedBox(height: 6),
                                      Semantics(
                                        header: true,
                                        child: Text(
                                          title,
                                          style: RoutbText.headline(
                                            30,
                                            color: p.onBrand,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        subtitle,
                                        style: RoutbText.copy(
                                          14,
                                          color: p.onBrand,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          body,
                        ],
                      ),
                    ),
                    if (footer != null) ...[
                      Divider(height: 1, color: p.line),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        child: footer,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
