import 'dart:async';

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
import 'package:tetri/core/api_error.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/core/providers.dart';
import 'package:tetri/core/session.dart';
import 'package:tetri/core/strings_auth.dart';
import 'package:tetri/core/strings_money.dart';
import 'package:tetri/design/components/money_amount_input.dart';
import 'package:tetri/design/components/money_flow_components.dart';
import 'package:tetri/design/components/buttons.dart';
import 'package:tetri/design/components/confirmation_dialog.dart';
import 'package:tetri/design/components/pin_input.dart';
import 'package:tetri/features/auth/auth_screens.dart';
import 'package:tetri/features/auth/pin_setup_screen.dart';
import 'package:tetri/features/home/home_screen.dart';
import 'package:tetri/features/transfer/transfer_screen.dart';

import '../helpers/banking_fakes.dart';

class _Store extends Mock implements SessionStore {}

class _Biometrics extends Mock implements BiometricGate {}

class _Session extends SessionController {
  _Session(this.state)
    : super(dio: Dio(), store: _Store(), biometrics: _Biometrics());
  SessionStatus state;
  bool hasPin = true;
  bool hasBiometrics = true;
  final pinAttempts = <String>[];
  @override
  SessionStatus get status => state;
  @override
  AuthUser? get user => state == SessionStatus.signedIn ? sampleUser : null;
  @override
  bool get shouldOfferBiometrics => false;
  @override
  bool get pinEnabled => hasPin;
  @override
  bool get biometricsEnabled => hasBiometrics;
  @override
  Future<bool> unlockWithPin(String pin) async {
    pinAttempts.add(pin);
    return false;
  }

  void change(SessionStatus next) {
    state = next;
    notifyListeners();
  }
}

class _PaymentApi extends FakeBankApi {
  final firstAttempt = Completer<TransferReceipt>();
  final keys = <String>[];

  @override
  Future<TransferReceipt> transfer({
    required String recipientHandle,
    required Money amount,
    required String idempotencyKey,
  }) {
    keys.add(idempotencyKey);
    if (keys.length == 1) return firstAttempt.future;
    return Future.value(
      TransferReceipt(
        id: 'transfer-id',
        amount: amount,
        recipientHandle: recipientHandle,
        recipientDisplayName: 'Giorgi M.',
        createdAt: DateTime.utc(2026, 11, 3),
      ),
    );
  }
}

void main() {
  Future<void> pump(
    WidgetTester tester,
    _Session session, {
    FakeBankApi? api,
  }) async {
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
          bankApiProvider.overrideWithValue(api ?? FakeBankApi()),
          themeModeProvider.overrideWithValue(theme),
        ],
        child: const TetriApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openAmount(
    WidgetTester tester,
    _Session session, {
    FakeBankApi? api,
  }) async {
    final bank = api ?? FakeBankApi();
    bank.historyHandler =
        ({accountId, required filter, cursor, required pageSize}) async =>
            TransactionPage(
              items: filter == 'sent' ? [sampleTransaction('recent')] : [],
            );
    await pump(tester, session, api: bank);
    GoRouter.of(tester.element(find.byType(HomeScreen))).push('/send');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Giorgi M.'));
    await tester.pumpAndSettle();
  }

  Finder amountField() => find.descendant(
    of: find.byType(MoneyAmountInput),
    matching: find.byType(TextField),
  );

  testWidgets('welcome opens account creation', (tester) async {
    await pump(tester, _Session(SessionStatus.signedOut));
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await tester.tap(find.text(AuthStrings.createAccount));
    await tester.pumpAndSettle();
    expect(find.byType(SignUpScreen), findsOneWidget);
  });

  testWidgets('authenticated sessions set up a PIN before reaching accounts', (
    tester,
  ) async {
    final session = _Session(SessionStatus.signedIn)..hasPin = false;
    await pump(tester, session);
    expect(find.byType(PinSetupScreen), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);
    GoRouter.of(tester.element(find.byType(PinSetupScreen))).go('/home');
    await tester.pumpAndSettle();
    expect(find.byType(PinSetupScreen), findsOneWidget);
    session.hasPin = true;
    session.change(SessionStatus.signedIn);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
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

  testWidgets(
    'cold lock reset dialog cancels without exposing private routes',
    (tester) async {
      final session = _Session(SessionStatus.locked)..hasBiometrics = false;
      await pump(tester, session);
      await tester.tap(find.text(AuthStrings.forgotPin));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmationDialog), findsOneWidget);
      expect(find.text(AuthStrings.resetPinHint), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.text(AuthStrings.cancel));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmationDialog), findsNothing);
      expect(find.byType(LockScreen), findsOneWidget);
      expect(session.status, SessionStatus.locked);
      expect(find.byType(HomeScreen), findsNothing);

      await tester.tap(find.text(AuthStrings.forgotPin));
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmationDialog), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(ConfirmationDialog), findsNothing);
      expect(find.byType(LockScreen), findsOneWidget);
      expect(session.status, SessionStatus.locked);
      expect(find.byType(HomeScreen), findsNothing);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(LockScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final keyboardHeight in [300.0, 480.0]) {
    testWidgets(
      'cold PIN-only lock enables visible Unlock after IME edits with $keyboardHeight inset',
      (tester) async {
        final session = _Session(SessionStatus.locked)..hasBiometrics = false;
        await pump(tester, session);
        final pinInput = find.byType(PinInput);
        final field = find.descendant(
          of: pinInput,
          matching: find.byType(TextField),
        );
        expect(pinInput, findsOneWidget);
        final controller = tester.widget<TextField>(field).controller!;
        final button = find.descendant(
          of: find.byType(LockScreen),
          matching: find.byType(PrimaryButton),
        );
        expect(tester.widget<PrimaryButton>(button).onPressed, isNull);
        await tester.tap(field);
        await tester.pump();
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        for (final text in ['0', '05', '057', '0572']) {
          tester.testTextInput.updateEditingValue(
            TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: text.length),
            ),
          );
          await tester.pump();
        }
        expect(tester.widget<TextField>(field).controller, same(controller));
        expect(controller.text.length, 4);
        expect(tester.widget<TextField>(field).enabled, isTrue);
        expect(tester.widget<PrimaryButton>(button).onPressed, isNotNull);

        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '057',
            selection: TextSelection.collapsed(offset: 3),
          ),
        );
        await tester.pump();
        expect(tester.widget<PrimaryButton>(button).onPressed, isNull);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '0572',
            selection: TextSelection.collapsed(offset: 4),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<PrimaryButton>(button).onPressed, isNotNull);
        await tester.ensureVisible(find.text(AuthStrings.unlock));
        await tester.pumpAndSettle();
        expect(find.text(AuthStrings.unlock).hitTestable(), findsOneWidget);
        await tester.tap(find.text(AuthStrings.unlock));
        await tester.pumpAndSettle();
        expect(session.pinAttempts, ['0572']);
        expect(tester.takeException(), isNull);
      },
    );
  }

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

  testWidgets('locking detaches native amount input and preserves its value', (
    tester,
  ) async {
    final session = _Session(SessionStatus.signedIn);
    await openAmount(tester, session);
    final originalState = tester.state(find.byType(TransferScreen));
    await tester.enterText(amountField(), '25.00');
    await tester.pump();
    final editable = tester.widget<EditableText>(
      find.descendant(
        of: find.byType(MoneyAmountInput),
        matching: find.byType(EditableText),
      ),
    );
    expect(editable.focusNode.hasFocus, isTrue);
    expect(tester.testTextInput.isVisible, isTrue);

    session.change(SessionStatus.locked);
    await tester.pumpAndSettle();
    expect(find.byType(MoneyAmountInput), findsNothing);
    expect(find.byType(LockScreen), findsOneWidget);
    expect(editable.focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.isVisible, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);
    editable.focusNode.requestFocus();
    await tester.pump();
    expect(editable.focusNode.hasFocus, isFalse);
    expect(tester.testTextInput.hasAnyClients, isFalse);

    session.change(SessionStatus.signedIn);
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(TransferScreen)), same(originalState));
    expect(tester.widget<TextField>(amountField()).controller!.text, '25.00');
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets(
    'system back dismisses the native keyboard before leaving transfer',
    (tester) async {
      final session = _Session(SessionStatus.signedIn);
      await openAmount(tester, session);
      final originalState = tester.state(find.byType(TransferScreen));
      await tester.enterText(amountField(), '25.00');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(TransferScreen)), same(originalState));
      expect(tester.widget<TextField>(amountField()).controller!.text, '25.00');
      expect(tester.testTextInput.isVisible, isFalse);
      tester.view.viewInsets = const FakeViewPadding();
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(TransferScreen), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );

  testWidgets(
    'a payment in flight keeps its confirmation key across lock and unlock',
    (tester) async {
      final session = _Session(SessionStatus.signedIn);
      final api = _PaymentApi();
      await openAmount(tester, session, api: api);
      final originalState = tester.state(find.byType(TransferScreen));
      await tester.enterText(amountField(), '25.00');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(MoneyStrings.continueLabel));
      await tester.tap(find.text(MoneyStrings.continueLabel));
      await tester.pumpAndSettle();
      expect(find.byType(MoneyReviewSheet), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(MoneyReviewSheet),
          matching: find.text(MoneyStrings.sendConfirm),
        ),
      );
      await tester.pump();
      expect(api.keys, hasLength(1));

      session.change(SessionStatus.locked);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MoneyReviewSheet), findsNothing);
      expect(find.byType(LockScreen), findsOneWidget);
      await tester.binding.handlePopRoute();
      session.change(SessionStatus.signedIn);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(MoneyReviewSheet), findsOneWidget);
      api.firstAttempt.completeError(
        const ApiError(
          code: 'timeout',
          message: 'Retry',
          retryable: true,
          isTimeout: true,
          isTransport: true,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(api.keys, hasLength(2));
      expect(api.keys[1], api.keys[0]);
      expect(tester.state(find.byType(TransferScreen)), same(originalState));
      expect(find.text(MoneyStrings.sent), findsOneWidget);
    },
  );
}
