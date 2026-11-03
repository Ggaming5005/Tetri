import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tetri/core/session.dart';
import 'package:tetri/core/strings_banking.dart';
import 'package:tetri/design/components/selection_controls.dart';
import 'package:tetri/features/settings/settings_screen.dart';

import '../helpers/banking_fakes.dart';

class MockSession extends Mock implements SessionController {}

void main() {
  late MockSession session;
  late ValueNotifier<ThemeMode> theme;
  setUp(() {
    session = MockSession();
    theme = ValueNotifier(ThemeMode.system);
    when(() => session.biometricsEnabled).thenReturn(false);
    when(() => session.biometricsAvailable()).thenAnswer((_) async => true);
    when(() => session.setBiometrics(any())).thenAnswer((_) async {});
    when(() => session.signOut()).thenAnswer((_) async {});
  });
  tearDown(() => theme.dispose());

  testWidgets('settings stays usable with enlarged text on a small phone', (
    tester,
  ) async {
    await pumpBanking(
      tester,
      const SettingsScreen(),
      FakeBankApi(),
      session: session,
      themePreference: theme,
      textScaler: const TextScaler.linear(2),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text(BankingStrings.signOut));
    await tester.pumpAndSettle();
    expect(find.text(BankingStrings.signOut).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text(BankingStrings.signOut));
    await tester.pumpAndSettle();
    verify(() => session.signOut()).called(1);
  });

  testWidgets('settings renders profile, changes theme and signs out', (
    tester,
  ) async {
    await pumpBanking(
      tester,
      const SettingsScreen(),
      FakeBankApi(),
      session: session,
      themePreference: theme,
    );
    await tester.pumpAndSettle();
    expect(find.text('Nino K.'), findsOneWidget);
    expect(find.text('@nino'), findsOneWidget);
    expect(find.text('nino@example.test'), findsOneWidget);
    await tester.tap(find.text(BankingStrings.dark));
    await tester.pumpAndSettle();
    expect(theme.value, ThemeMode.dark);
    await tester.ensureVisible(find.text(BankingStrings.signOut));
    await tester.tap(find.text(BankingStrings.signOut));
    await tester.pumpAndSettle();
    verify(() => session.signOut()).called(1);
  });

  testWidgets(
    'settings enables biometrics only after device support is checked',
    (tester) async {
      await pumpBanking(
        tester,
        const SettingsScreen(),
        FakeBankApi(),
        session: session,
        themePreference: theme,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TetriSwitch));
      await tester.pumpAndSettle();
      verifyInOrder([
        () => session.biometricsAvailable(),
        () => session.setBiometrics(true),
      ]);
    },
  );

  testWidgets('unsupported biometrics stays off with a useful error', (
    tester,
  ) async {
    when(() => session.biometricsAvailable()).thenAnswer((_) async => false);
    await pumpBanking(
      tester,
      const SettingsScreen(),
      FakeBankApi(),
      session: session,
      themePreference: theme,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TetriSwitch));
    await tester.pumpAndSettle();
    expect(find.text(BankingStrings.biometricUnavailable), findsOneWidget);
    verifyNever(() => session.setBiometrics(true));
  });

  testWidgets('profile failure has retry and later restores settings', (
    tester,
  ) async {
    var fail = true;
    final api = FakeBankApi()
      ..profileHandler = () async {
        if (fail) throw StateError('offline');
        return sampleUser;
      };
    await pumpBanking(
      tester,
      const SettingsScreen(),
      api,
      session: session,
      themePreference: theme,
    );
    await tester.pumpAndSettle();
    expect(find.text(BankingStrings.cannotLoad), findsOneWidget);
    fail = false;
    await tester.tap(find.text(BankingStrings.retry));
    await tester.pumpAndSettle();
    expect(find.byType(TetriSwitch), findsOneWidget);
  });
}
