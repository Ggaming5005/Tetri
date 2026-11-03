import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/providers.dart';
import '../core/session.dart';
import '../core/strings.dart';
import '../design/component_gallery.dart';
import '../design/components/inline_banner.dart';
import '../design/theme.dart';
import '../design/tokens.dart';
import '../features/accounts/account_screen.dart';
import '../features/activity/activity_screen.dart';
import '../features/activity/transaction_detail_screen.dart';
import '../features/auth/auth_screens.dart';
import '../features/convert/convert_screen.dart';
import '../features/home/banking_providers.dart';
import '../features/home/home_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/transfer/transfer_screen.dart';
import 'preferences.dart';

class TetriApp extends ConsumerStatefulWidget {
  const TetriApp({super.key});
  @override
  ConsumerState<TetriApp> createState() => _TetriAppState();
}

class _TetriAppState extends ConsumerState<TetriApp>
    with WidgetsBindingObserver {
  late final session = ref.read(sessionProvider);
  String? _previousUserId;

  late final router = GoRouter(
    initialLocation: kDebugMode && const bool.fromEnvironment('TETRI_GALLERY')
        ? '/__gallery'
        : '/',
    refreshListenable: session,
    redirect: (context, state) {
      final path = state.uri.path;
      if (kDebugMode && path == '/__gallery') return null;
      if (session.status == SessionStatus.restoring) {
        return path == '/starting' ? null : '/starting';
      }
      if (session.status == SessionStatus.locked) {
        // A warm lock covers the live route, preserving pending payment keys.
        return const ['/', '/starting', '/sign-in', '/sign-up'].contains(path)
            ? '/lock'
            : null;
      }
      if (session.status == SessionStatus.signedOut) {
        if (const ['/', '/sign-in', '/sign-up'].contains(path)) return null;
        return path == '/starting' ? '/' : '/sign-in';
      }
      if (const [
        '/',
        '/starting',
        '/lock',
        '/sign-in',
        '/sign-up',
      ].contains(path)) {
        return session.shouldOfferBiometrics ? '/biometrics' : '/home';
      }
      return null;
    },
    routes: [
      _route('/', (_) => const WelcomeScreen()),
      _route('/starting', (_) => const StartupScreen()),
      _route('/sign-in', (_) => const SignInScreen()),
      _route('/sign-up', (_) => const SignUpScreen()),
      _route('/lock', (_) => const LockScreen()),
      _route('/biometrics', (_) => const BiometricsOfferScreen()),
      _route('/home', (_) => const HomeScreen()),
      _route(
        '/accounts/:id',
        (state) => AccountScreen(accountId: state.pathParameters['id']!),
      ),
      _route('/activity', (_) => const ActivityScreen()),
      _route(
        '/transactions/:id',
        (state) =>
            TransactionDetailScreen(transactionId: state.pathParameters['id']!),
      ),
      _route('/settings', (_) => const SettingsScreen()),
      _route(
        '/send',
        (state) => TransferScreen(
          initialCurrency: state.uri.queryParameters['currency'],
        ),
      ),
      _route(
        '/convert',
        (state) => ConvertScreen(
          initialCurrency: state.uri.queryParameters['currency'],
        ),
      ),
      if (kDebugMode)
        _route(
          '/__gallery',
          (_) => ValueListenableBuilder(
            valueListenable: ref.read(themeModeProvider),
            builder: (context, mode, _) => ComponentGallery(
              themeMode: mode,
              onThemeChanged: (value) =>
                  ref.read(themeModeProvider).value = value,
            ),
          ),
        ),
    ],
  );

  GoRoute _route(String path, Widget Function(GoRouterState) builder) =>
      GoRoute(
        path: path,
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: builder(state),
          transitionDuration: TetriMotion.screen,
          reverseTransitionDuration: TetriMotion.screen,
          transitionsBuilder: (context, animation, secondaryAnimation, child) =>
              FadeTransition(
                opacity: animation.drive(CurveTween(curve: TetriMotion.curve)),
                child: child,
              ),
        ),
      );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    final userId = session.user?.id;
    if (_previousUserId == userId) return;
    _previousUserId = userId;
    refreshBankViews(ref);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) session.lock();
  }

  @override
  Future<bool> didPopRoute() async => session.status == SessionStatus.locked;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.removeListener(_sessionChanged);
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: ref.watch(themeModeProvider),
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
      builder: (context, child) => ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final locked = session.status == SessionStatus.locked;
          final offline =
              session.status == SessionStatus.signedIn &&
              session.error?.retryable == true &&
              session.error?.code != 'rates_unavailable' &&
              session.error?.code != 'request_in_progress';
          return ColoredBox(
            color: TetriColors.of(context).bg,
            child: Column(
              children: [
                if (offline)
                  SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.all(TetriSpace.x16),
                      child: InlineBanner(
                        message: session.error!.message,
                        kind: BannerKind.warning,
                      ),
                    ),
                  ),
                Expanded(
                  child: MediaQuery.removePadding(
                    context: context,
                    removeTop: offline,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Offstage(
                          offstage: locked,
                          child: TickerMode(enabled: !locked, child: child!),
                        ),
                        if (locked) const LockScreen(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );
}
