import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tetri/app/preferences.dart';
import 'package:tetri/app/tetri_app.dart';
import 'package:tetri/core/api_models.dart';
import 'package:tetri/core/providers.dart';
import 'package:tetri/core/session.dart';
import 'package:tetri/core/strings_auth.dart';
import 'package:tetri/features/auth/auth_screens.dart';
import 'package:tetri/features/home/home_screen.dart';
import 'package:tetri/features/transfer/transfer_screen.dart';

import '../helpers/banking_fakes.dart';

class _Store extends Mock implements SessionStore {}

class _Biometrics extends Mock implements BiometricGate {}

class _Session extends SessionController {
  _Session(this.state)
    : super(dio: Dio(), store: _Store(), biometrics: _Biometrics());
  SessionStatus state;
  @override
  SessionStatus get status => state;
  @override
  AuthUser? get user => state == SessionStatus.signedIn ? sampleUser : null;
  @override
  bool get shouldOfferBiometrics => false;
  void change(SessionStatus next) {
    state = next;
    notifyListeners();
  }
}

void main() {
  Future<void> pump(WidgetTester tester, _Session session) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final theme = ValueNotifier(ThemeMode.light);
    addTearDown(theme.dispose);
    addTearDown(session.dispose);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sessionProvider.overrideWithValue(session),
          bankApiProvider.overrideWithValue(FakeBankApi()),
          themeModeProvider.overrideWithValue(theme),
        ],
        child: const TetriApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('welcome opens account creation', (tester) async {
    await pump(tester, _Session(SessionStatus.signedOut));
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await tester.tap(find.text(AuthStrings.createAccount));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
  });

  testWidgets('expired session removes private screen and routes to sign in', (
    tester,
  ) async {
    final session = _Session(SessionStatus.signedIn);
    await pump(tester, session);
    expect(find.byType(HomeScreen), findsOneWidget);
    session.change(SessionStatus.signedOut);
    await tester.pumpAndSettle();
    expect(find.byType(SignInScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
  });

  testWidgets('locking hides private routes until session unlocks', (
    tester,
  ) async {
    final session = _Session(SessionStatus.signedIn);
    await pump(tester, session);
    session.change(SessionStatus.locked);
    await tester.pumpAndSettle();
    expect(find.byType(LockScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    session.change(SessionStatus.signedIn);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('lock and system back preserve the live transfer state', (
    tester,
  ) async {
    final session = _Session(SessionStatus.signedIn);
    await pump(tester, session);
    GoRouter.of(tester.element(find.byType(HomeScreen))).push('/send');
    await tester.pumpAndSettle();
    final originalState = tester.state(find.byType(TransferScreen));
    session.change(SessionStatus.locked);
    await tester.pumpAndSettle();
    expect(find.byType(TransferScreen), findsNothing);
    expect(find.byType(LockScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    session.change(SessionStatus.signedIn);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(TransferScreen)), same(originalState));
  });
}
