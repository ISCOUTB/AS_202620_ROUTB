import 'package:flutter/material.dart';

import '../../../core/theme/routb_theme.dart';

class ProfileFormPage extends StatelessWidget {
  const ProfileFormPage({
    required this.title,
    required this.body,
    required this.footer,
    required this.busy,
    super.key,
  });

  final String title;
  final Widget body;
  final Widget footer;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: RoutbTheme.contentMaxWidth,
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final inlineAction =
                      MediaQuery.viewInsetsOf(context).bottom > 0 ||
                      constraints.maxHeight < 320;
                  return AbsorbPointer(
                    absorbing: busy,
                    child: Column(
                      children: [
                        Expanded(
                          child: ListView(
                            padding: const EdgeInsets.all(16),
                            children: [
                              body,
                              if (inlineAction) ...[
                                const SizedBox(height: 16),
                                footer,
                              ],
                            ],
                          ),
                        ),
                        if (!inlineAction)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                            child: footer,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
