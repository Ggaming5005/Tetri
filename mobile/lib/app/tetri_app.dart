import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/strings.dart';
import '../design/component_gallery.dart';
import '../design/components/components.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../design/typography.dart';

class TetriApp extends StatefulWidget {
  const TetriApp({super.key});

  @override
  State<TetriApp> createState() => _TetriAppState();
}

class _TetriAppState extends State<TetriApp> {
  final themeMode = ValueNotifier(ThemeMode.system);
  late final router = GoRouter(
    initialLocation: kDebugMode && const bool.fromEnvironment('TETRI_GALLERY')
        ? '/__gallery'
        : '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const _BrandPreview()),
      if (kDebugMode)
        GoRoute(
          path: '/__gallery',
          builder: (context, state) => ValueListenableBuilder(
            valueListenable: themeMode,
            builder: (context, mode, _) => ComponentGallery(
              themeMode: mode,
              onThemeChanged: (value) => themeMode.value = value,
            ),
          ),
        ),
    ],
  );

  @override
  void dispose() {
    router.dispose();
    themeMode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: themeMode,
    builder: (context, mode, _) => MaterialApp.router(
      title: TetriStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: TetriTheme.light,
      darkTheme: TetriTheme.dark,
      themeMode: mode,
      themeAnimationDuration:
          MediaQueryData.fromView(View.of(context)).disableAnimations
          ? Duration.zero
          : TetriMotion.screen,
      routerConfig: router,
    ),
  );
}

class _BrandPreview extends StatelessWidget {
  const _BrandPreview();

  @override
  Widget build(BuildContext context) => TetriScaffold(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: TetriSpace.x64),
        GestureDetector(
          onLongPress: kDebugMode ? () => context.push('/__gallery') : null,
          child: const TetriWordmark(),
        ),
        const SizedBox(height: TetriSpace.x24),
        Text(
          TetriStrings.tagline,
          style: TetriTypography.headline.copyWith(
            color: TetriColors.of(context).textPrimary,
          ),
        ),
        const SizedBox(height: TetriSpace.x48),
        const TetriArtwork(),
        const SizedBox(height: TetriSpace.x48),
        Text(
          TetriStrings.sandbox,
          style: TetriTypography.label.copyWith(
            color: TetriColors.of(context).textSecondary,
          ),
        ),
      ],
    ),
  );
}
