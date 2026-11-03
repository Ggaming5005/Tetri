import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tetri/core/api.dart';
import 'package:tetri/core/api_error.dart';
import 'package:tetri/core/providers.dart';
import 'package:tetri/core/session.dart';
import 'package:tetri/core/strings.dart';
import 'package:tetri/core/strings_auth.dart';
import 'package:tetri/design/components/skeleton.dart';
import 'package:tetri/design/theme.dart';
import 'package:tetri/features/auth/auth_screens.dart';

class MockApi extends Mock implements BankApi {}

class MockSession extends Mock implements SessionController {}

void main() {
  late MockApi api;
  late MockSession session;
  setUp(() {
    api = MockApi();
    session = MockSession();
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  Future<void> pump(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          bankApiProvider.overrideWithValue(api),
          sessionProvider.overrideWithValue(session),
        ],
        child: MaterialApp(theme: TetriTheme.light, home: screen),
      ),
    );
    await tester.pump();
  }

  Future<void> next(WidgetTester tester, String value) async {
    await tester.enterText(find.byType(TextField), value);
    await tester.tap(find.text(TetriStrings.continueLabel));
    await tester.pump();
  }

  testWidgets(
    'sign up validates empty input and shows only one field per step',
    (tester) async {
      await pump(tester, const SignUpScreen());
      expect(find.byType(TextField), findsOneWidget);
      await tester.tap(find.text(TetriStrings.continueLabel));
      await tester.pump();
      expect(find.text(TetriStrings.invalidEmail), findsOneWidget);
      await next(tester, 'giorgi@example.com');
      expect(find.text(AuthStrings.nameTitle), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    },
  );

  testWidgets('handle checks debounce and discard older responses', (
    tester,
  ) async {
    final older = Completer<bool>();
    when(() => api.handleAvailable('@giorgi')).thenAnswer((_) => older.future);
    when(() => api.handleAvailable('@giorgi_new'))
        .thenAnswer((_) async => true);
    await pump(tester, const SignUpScreen());
    await next(tester, 'giorgi@example.com');
    await next(tester, 'Giorgi');
    await tester.enterText(find.byType(TextField), '@giorgi');
    await tester.pump(const Duration(milliseconds: 399));
    verifyNever(() => api.handleAvailable(any()));
    await tester.pump(const Duration(milliseconds: 1));
    verify(() => api.handleAvailable('@giorgi')).called(1);
    expect(find.byType(Skeleton), findsOneWidget);
    await tester.enterText(find.byType(TextField), '@giorgi_new');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.text(AuthStrings.handleAvailable), findsOneWidget);
    older.complete(false);
    await tester.pump();
    expect(find.text(AuthStrings.handleTaken), findsNothing);
    expect(find.text(AuthStrings.handleAvailable), findsOneWidget);
  });

  testWidgets(
    'registration handle race returns to handle step with fields preserved',
    (tester) async {
      when(() => api.handleAvailable(any())).thenAnswer((_) async => true);
      when(
        () => session.register(
          email: any(named: 'email'),
          displayName: any(named: 'displayName'),
          handle: any(named: 'handle'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const ApiError(
          code: 'handle_taken',
          message: AuthStrings.handleTaken,
          status: 409,
        ),
      );
      await pump(tester, const SignUpScreen());
      await next(tester, 'giorgi@example.com');
      await next(tester, 'Giorgi');
      await tester.enterText(find.byType(TextField), '@giorgi');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(find.text(TetriStrings.continueLabel));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'sandbox-password');
      await tester.tap(find.text(AuthStrings.createAccount));
      await tester.pump();
      expect(find.text(AuthStrings.handleTitle), findsOneWidget);
      expect(find.text(AuthStrings.handleTaken), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '@giorgi',
      );
    },
  );

  testWidgets(
    'sign in shows retryable failure without losing entered credentials',
    (tester) async {
      when(
        () => session.signIn(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        const ApiError(
          code: 'offline',
          message: TetriStrings.offline,
          retryable: true,
        ),
      );
      await pump(tester, const SignInScreen());
      await tester.enterText(
        find.byType(TextField).first,
        'giorgi@example.com',
      );
      await tester.enterText(find.byType(TextField).last, 'sandbox-password');
      await tester.tap(find.text(AuthStrings.signIn));
      await tester.pump();
      expect(find.text(TetriStrings.offline), findsOneWidget);
      await tester.tap(find.text(TetriStrings.retry));
      await tester.pump();
      verify(
        () => session.signIn(
          email: 'giorgi@example.com',
          password: 'sandbox-password',
        ),
      ).called(2);
    },
  );

  testWidgets('cancelled biometric unlock stays locked and offers retry', (
    tester,
  ) async {
    when(() => session.unlock()).thenAnswer((_) async => false);
    await pump(tester, const LockScreen());
    await tester.tap(find.text(AuthStrings.unlock));
    await tester.pump();
    expect(find.text(AuthStrings.unlockCancelled), findsOneWidget);
    expect(find.text(AuthStrings.unlock), findsOneWidget);
    verify(() => session.unlock()).called(1);
  });
}
