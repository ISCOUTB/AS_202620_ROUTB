import 'package:flutter/material.dart';

import '../theme/routb_palette.dart';
import '../theme/routb_text.dart';
import 'routb_campus_cover.dart';
import 'routb_logo.dart';
import 'routb_seats.dart';

/// En móvil se desplaza todo el tablero. Con espacio, los controles y el
/// listado se pueden consultar lado a lado, incluso en ventanas bajas.
class RoutbJourneyBoard extends StatelessWidget {
  const RoutbJourneyBoard({
    required this.header,
    required this.slivers,
    required this.storageKey,
    required this.onRefresh,
    super.key,
  });

  static const maxWidth = 1040.0;
  final Widget header;
  final List<Widget> slivers;
  final String storageKey;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 800;
        final list = RefreshIndicator(
          onRefresh: onRefresh,
          child: CustomScrollView(
            key: PageStorageKey<String>(storageKey),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              if (!wide) SliverToBoxAdapter(child: header),
              ...slivers,
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        );
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: wide ? 28 : 16),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 4,
                      child: SingleChildScrollView(
                        primary: false,
                        child: header,
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(flex: 5, child: list),
                  ],
                )
              : list,
        );
      },
    );
  }
}

/// La ilustración identifica Cartagena; los mapas interactivos se construyen
/// por separado a partir del viaje seleccionado.
class RoutbJourneyHeader extends StatelessWidget {
  const RoutbJourneyHeader({
    required this.title,
    required this.userName,
    required this.controls,
    super.key,
  });

  final String title;
  final String userName;
  final Widget controls;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final ink = context.isDarkMode ? palette.background : palette.ink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Row(
            children: [
              ExcludeSemantics(
                child: RoutbLogo(
                  variant: RoutbLogoVariant.onSurface.forBackground(
                    context.isDarkMode,
                  ),
                  width: 28,
                ),
              ),
              const SizedBox(width: 6),
              Text('ROUTB', style: RoutbText.headline(19, color: palette.ink)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hola, $userName',
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: RoutbText.copy(13, color: palette.muted),
                ),
              ),
            ],
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(22),
            boxShadow: palette.cardShadow,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                RoutbCampusCover(
                  child: Container(
                    alignment: Alignment.centerLeft,
                    constraints: const BoxConstraints(minHeight: 116),
                    padding: const EdgeInsets.fromLTRB(18, 24, 16, 24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          ink.withValues(alpha: 0.64),
                          ink.withValues(alpha: 0.38),
                          ink.withValues(alpha: 0),
                        ],
                        stops: const [0, 0.47, 0.78],
                      ),
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: RoutbText.headline(
                          36,
                          color: palette.onBrand,
                          height: 1.03,
                        ),
                      ),
                    ),
                  ),
                ),
                controls,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Encabezado de un listado, con su total real y una acción opcional.
class JourneySectionTitle extends StatelessWidget {
  const JourneySectionTitle(
    this.title, {
    required this.count,
    this.action,
    super.key,
  });
  final String title;
  final int count;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 20, 0, 12),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      style: RoutbText.headline(21, color: palette.ink),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$count', style: RoutbText.copy(15, color: palette.muted)),
              ],
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Acción principal bajo la ilustración. El texto puede ocupar varias líneas.
class JourneyAction extends StatelessWidget {
  const JourneyAction({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Material(
      color: p.card,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: p.brandSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(9),
                  child: Icon(icon, size: 21, color: p.onBrandSurface),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label, style: RoutbText.headline(16, color: p.ink)),
              ),
              Icon(
                Icons.arrow_forward_rounded,
                size: 20,
                color: p.onBrandSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Conserva la cabecera durante la carga y el reintento.
class JourneyFeedbackSliver extends StatelessWidget {
  const JourneyFeedbackSliver.loading({super.key})
    : message = null,
      onRetry = null;
  const JourneyFeedbackSliver.error({
    required String this.message,
    required VoidCallback this.onRetry,
    super.key,
  });
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.only(top: 20),
      sliver: SliverToBoxAdapter(
        child: message == null
            ? Semantics(
                label: 'Cargando viajes',
                liveRegion: true,
                child: const RoutbSkeleton(height: 190),
              )
            : RoutbEmptyState(
                icon: Icons.cloud_off_rounded,
                message: message!,
                action: TextButton.icon(
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                  onPressed: onRetry,
                ),
              ),
      ),
    );
  }
}
