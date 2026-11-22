import 'package:flutter/material.dart';

import '../../../core/theme/routb_palette.dart';
import '../../../core/theme/routb_theme.dart';
import '../../../core/widgets/routb_card.dart';

class SafetyDetailPage extends StatelessWidget {
  const SafetyDetailPage({
    required this.title,
    required this.children,
    super.key,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(title: Text(title, maxLines: 2)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: RoutbTheme.contentMaxWidth,
            ),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class SafetyLink extends StatelessWidget {
  const SafetyLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return RoutbCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(RoutbTheme.radiusCard),
          ),
          leading: Icon(icon, color: palette.brand),
          title: Text(
            title,
            style: TextStyle(color: palette.ink, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitle, style: TextStyle(color: palette.muted)),
          trailing: Icon(Icons.chevron_right_rounded, color: palette.muted),
          onTap: onTap,
        ),
      ),
    );
  }
}
