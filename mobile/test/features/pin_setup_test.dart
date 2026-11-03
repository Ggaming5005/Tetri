import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tetri/core/app_pin.dart';
import 'package:tetri/core/providers.dart';
import 'package:tetri/core/session.dart';
import 'package:tetri/core/strings.dart';
import 'package:tetri/core/strings_auth.dart';
import 'package:tetri/core/strings_pin.dart';
import 'package:tetri/design/components/buttons.dart';
import 'package:tetri/design/theme.dart';
import 'package:tetri/features/auth/pin_setup_screen.dart';

class MockSession extends Mock implements SessionController {}

void main() {
  late MockSession session;
  setUp(() {
    session = MockSession();
    GoogleFonts.config.allowRuntimeFetching = false;
    when(() => session.setPin(any(), currentPin: any(named: 'currentPin')))
        .thenAnswer((_) async {});
  });

  Future<void> pump(
    WidgetTester tester, {
    bool changing = false,
    Size size = const Size(360, 800),
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final router = GoRouter(
      initialLocation: changing ? '/change-pin' : '/pin-setup',
      routes: [
        GoRoute(path: '/pin-setup', builder: (_, _) => const PinSetupScreen()),
        GoRoute(
          path: '/change-pin',
          builder: (_, _) => const PinSetupScreen(changing: true),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => const Scaffold(body: Text('/settings')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sessionProvider.overrideWithValue(session)],
        child: MaterialApp.router(
          theme: TetriTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: textScaler),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> enterAndContinue(WidgetTester tester, String pin) async {
    await tester.enterText(find.byType(TextField), pin);
    await tester.pump();
    await tester.ensureVisible(find.text(TetriStrings.continueLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.text(TetriStrings.continueLabel));
    await tester.pump();
  }

  testWidgets('new PIN is saved only after matching confirmation', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text(AuthStrings.createPinTitle), findsOneWidget);
    expect(find.byTooltip(AuthStrings.back), findsNothing);
    await enterAndContinue(tester, '0572');
    expect(find.text(AuthStrings.confirmPinTitle), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '',
    );
    await tester.enterText(find.byType(TextField), '0573');
    await tester.pump();
    await tester.tap(find.text(AuthStrings.savePin));
    await tester.pump();
    expect(find.text(AuthStrings.pinMismatch), findsOneWidget);
    verifyNever(
      () => session.setPin(any(), currentPin: any(named: 'currentPin')),
    );
    await tester.enterText(find.byType(TextField), '0572');
    await tester.pump();
    await tester.tap(find.text(AuthStrings.savePin));
    await tester.pump();
    verify(() => session.setPin('0572', currentPin: null)).called(1);
  });

  testWidgets('changing a PIN requires current, new and confirmation', (
    tester,
  ) async {
    await pump(tester, changing: true);
    expect(find.text(AuthStrings.currentPinTitle), findsOneWidget);
    await enterAndContinue(tester, '0572');
    expect(find.text(AuthStrings.createPinTitle), findsOneWidget);
    await enterAndContinue(tester, '4068');
    await tester.enterText(find.byType(TextField), '4068');
    await tester.pump();
    await tester.tap(find.text(AuthStrings.savePin));
    await tester.pumpAndSettle();
    verify(() => session.setPin('4068', currentPin: '0572')).called(1);
    expect(find.text('/settings'), findsOneWidget);
  });

  testWidgets(
    'wrong current PIN returns to current step without retaining inputs',
    (tester) async {
      when(() => session.setPin('4068', currentPin: '0573'))
          .thenThrow(const PinException(PinStrings.incorrect));
      await pump(tester, changing: true);
      await enterAndContinue(tester, '0573');
      await enterAndContinue(tester, '4068');
      await tester.enterText(find.byType(TextField), '4068');
      await tester.pump();
      await tester.tap(find.text(AuthStrings.savePin));
      await tester.pump();
      expect(find.text(AuthStrings.currentPinTitle), findsOneWidget);
      expect(find.text(PinStrings.incorrect), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(find.text('/settings'), findsNothing);
    },
  );

  testWidgets('save cannot be repeated while the PIN is being stored', (
    tester,
  ) async {
    final pending = Completer<void>();
    when(() => session.setPin('0572', currentPin: null))
        .thenAnswer((_) => pending.future);
    await pump(tester);
    await enterAndContinue(tester, '0572');
    await tester.enterText(find.byType(TextField), '0572');
    await tester.pump();
    await tester.tap(find.text(AuthStrings.savePin));
    await tester.pump();
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).isLoading,
      isTrue,
    );
    expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    pending.complete();
    await tester.pump();
    verify(() => session.setPin('0572', currentPin: null)).called(1);
  });

  testWidgets('PIN setup fits a small phone with keyboard and 2x text', (
    tester,
  ) async {
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    addTearDown(tester.view.resetViewInsets);
    await pump(
      tester,
      size: const Size(320, 568),
      textScaler: const TextScaler.linear(2),
    );
    await tester.ensureVisible(find.byType(TextField));
    await tester.pumpAndSettle();
    await enterAndContinue(tester, '0572');
    expect(find.text(AuthStrings.confirmPinTitle), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text(AuthStrings.savePin));
    await tester.pumpAndSettle();
    expect(find.text(AuthStrings.savePin).hitTestable(), findsOneWidget);
  });
}
