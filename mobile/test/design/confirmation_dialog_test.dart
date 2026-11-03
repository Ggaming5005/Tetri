import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tetri/core/strings_auth.dart';
import 'package:tetri/design/components/confirmation_dialog.dart';

import '../helpers/pump_tetri.dart';

void main() {
  testWidgets('confirmation dialog wraps at 320 dp with enlarged text', (
    tester,
  ) async {
    bool? result;
    await pumpTetri(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            result = await showDialog<bool>(
              context: context,
              builder: (_) => const ConfirmationDialog(
                title: AuthStrings.resetPinTitle,
                message: AuthStrings.resetPinHint,
                confirmLabel: AuthStrings.signIn,
                cancelLabel: AuthStrings.cancel,
              ),
            );
          },
          child: const Text(AuthStrings.forgotPin),
        ),
      ),
      size: const Size(320, 568),
      textScaler: const TextScaler.linear(2),
    );
    await tester.tap(find.text(AuthStrings.forgotPin));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text(AuthStrings.cancel));
    await tester.pumpAndSettle();
    expect(find.text(AuthStrings.cancel).hitTestable(), findsOneWidget);
    await tester.tap(find.text(AuthStrings.cancel));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
