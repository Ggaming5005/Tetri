import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:tetri/core/session.dart';
import 'package:tetri/core/strings_banking.dart';
import 'package:tetri/design/components/browse_components.dart';
import 'package:tetri/design/tokens.dart';
import 'package:tetri/features/activity/activity_screen.dart';
import 'package:tetri/features/home/home_screen.dart';
import 'package:tetri/features/settings/settings_screen.dart';

import '../helpers/banking_fakes.dart';

class _Session extends Mock implements SessionController {}

void main() {
  const sizes = [
    Size(320, 640),
    Size(360, 800),
    Size(430, 932),
    Size(800, 1024),
    Size(800, 360),
  ];
  for (final size in sizes) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'browsing fits ${size.width} by ${size.height} at text scale $scale',
        (tester) async {
          final session = _Session();
          when(() => session.biometricsEnabled).thenReturn(false);
          when(() => session.pinEnabled).thenReturn(true);
          final theme = ValueNotifier(ThemeMode.system);
          addTearDown(theme.dispose);
          for (final screen in const [
            HomeScreen(),
            ActivityScreen(),
            SettingsScreen(),
          ]) {
            await pumpBanking(
              tester,
              screen,
              FakeBankApi(),
              size: size,
              textScaler: TextScaler.linear(scale),
              session: session,
              themePreference: theme,
            );
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '${screen.runtimeType} should fit the viewport',
            );
            if (screen is SettingsScreen) {
              expect(find.byType(TetriNavigation), findsNothing);
              expect(find.byTooltip(BankingStrings.back), findsOneWidget);
              await tester.ensureVisible(find.text(BankingStrings.signOut));
              await tester.pumpAndSettle();
              expect(
                find.text(BankingStrings.signOut).hitTestable(),
                findsOneWidget,
              );
            } else {
              final navigationFinder = find.byType(TetriNavigation);
              final navigation = tester.getRect(navigationFinder);
              expect(navigation.left, greaterThanOrEqualTo(0));
              expect(navigation.right, lessThanOrEqualTo(size.width));
              for (final label in [
                BankingStrings.home,
                BankingStrings.payments,
                BankingStrings.activity,
              ]) {
                expect(
                  find.descendant(
                    of: navigationFinder,
                    matching: find.text(label),
                  ),
                  findsOneWidget,
                );
              }
              expect(
                find.descendant(
                  of: navigationFinder,
                  matching: find.text(BankingStrings.settings),
                ),
                findsNothing,
              );
              if (screen is HomeScreen) {
                expect(
                  find.byTooltip(BankingStrings.profile).hitTestable(),
                  findsOneWidget,
                );
                await tester.ensureVisible(find.byType(RoundAction).first);
                await tester.pumpAndSettle();
                expect(
                  tester.getSize(find.byType(RoundAction).first).width,
                  greaterThanOrEqualTo(TetriSizes.tap48),
                );
              }
            }
            expect(tester.takeException(), isNull);
          }
        },
      );
    }
  }
}
