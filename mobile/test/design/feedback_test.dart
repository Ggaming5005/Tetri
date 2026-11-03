import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphor_glyphs/phosphor_glyphs.dart';
import 'package:tetri/core/money.dart';
import 'package:tetri/design/components/amount_text.dart';
import 'package:tetri/design/components/avatar.dart';
import 'package:tetri/design/components/buttons.dart';
import 'package:tetri/design/components/empty_state.dart';
import 'package:tetri/design/components/inline_banner.dart';
import 'package:tetri/design/components/skeleton.dart';
import 'package:tetri/design/components/status_view.dart';
import 'package:tetri/design/tokens.dart';

import '../helpers/pump_tetri.dart';

void main() {
  for (final success in [true, false]) {
    testWidgets(
      'status ${success ? 'success' : 'failure'} uses one amount and one action',
      (tester) async {
        var taps = 0;
        await pumpTetri(
          tester,
          StatusView(
            title: success ? 'Sent' : 'Money was not sent',
            amount: const Money(2500, 'GEL'),
            actionLabel: 'Done',
            onAction: () => taps++,
            isSuccess: success,
            message: success ? null : 'Try again.',
          ),
          brightness: success ? Brightness.light : Brightness.dark,
        );
        expect(find.byType(AmountText), findsOneWidget);
        expect(find.byType(PrimaryButton), findsOneWidget);
        expect(
          find.byIcon(
            success
                ? PhosphorIconsRegular.checkCircle
                : PhosphorIconsRegular.warningCircle,
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Done'));
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('empty state supports an optional action', (tester) async {
    var taps = 0;
    await pumpTetri(
      tester,
      EmptyState(
        icon: PhosphorIconsRegular.receipt,
        message: 'No activity yet',
        actionLabel: 'Send money',
        onAction: () => taps++,
      ),
    );
    expect(find.text('No activity yet'), findsOneWidget);
    await tester.tap(find.text('Send money'));
    expect(taps, 1);
    await pumpTetri(
      tester,
      const EmptyState(
        icon: PhosphorIconsRegular.receipt,
        message: 'No activity yet',
      ),
    );
    expect(find.byType(TetriTextButton), findsNothing);
  });

  for (final kind in BannerKind.values) {
    testWidgets('$kind banner has readable message and appropriate surface', (
      tester,
    ) async {
      await pumpTetri(
        tester,
        InlineBanner(
          message: 'Check your connection and try again.',
          kind: kind,
        ),
        brightness: Brightness.dark,
      );
      final decorated = tester.widget<DecoratedBox>(
        find
            .descendant(
              of: find.byType(InlineBanner),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(
        (decorated.decoration as BoxDecoration).color,
        kind == BannerKind.warning
            ? TetriColors.dark.warningBg
            : TetriColors.dark.surface,
      );
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      expect(find.byType(Icon), findsOneWidget);
    });
  }

  testWidgets('avatar uses first and last initials and stable user colors', (
    tester,
  ) async {
    await pumpTetri(
      tester,
      const Row(
        children: [
          Avatar(userId: 'user-17', name: 'Nino Kate Smith'),
          Avatar(userId: 'user-17', name: 'Different Name'),
        ],
      ),
    );
    expect(find.text('NS'), findsOneWidget);
    final avatars = find.byType(Avatar);
    Color? colorAt(int index) =>
        (tester
                    .widget<Container>(
                      find.descendant(
                        of: avatars.at(index),
                        matching: find.byType(Container),
                      ),
                    )
                    .decoration
                as BoxDecoration)
            .color;
    expect(colorAt(0), colorAt(1));
    expect(tester.getSize(avatars.first), const Size.square(TetriSizes.tap48));
    expect(Avatar.paletteIndex('user-17', 4), 0);
  });

  testWidgets(
    'avatar accepts empty and grapheme names without splitting characters',
    (tester) async {
      await pumpTetri(
        tester,
        const Row(
          children: [
            Avatar(userId: 'a', name: ''),
            Avatar(userId: 'b', name: 'Éva Li'),
          ],
        ),
      );
      expect(find.text('ÉL'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('skeleton softly pulses without a spinner', (tester) async {
    await pumpTetri(tester, const Skeleton(width: 160, height: 24));
    final fade = find.descendant(
      of: find.byType(Skeleton),
      matching: find.byType(FadeTransition),
    );
    final before = tester.widget<FadeTransition>(fade).opacity.value;
    await tester.pump(const Duration(milliseconds: 600));
    expect(tester.widget<FadeTransition>(fade).opacity.value, isNot(before));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.getSize(find.byType(Skeleton)), const Size(160, 24));
  });

  testWidgets(
    'reduced motion leaves skeleton static and keeps its loading label',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTetri(
        tester,
        const Skeleton(height: 24),
        disableAnimations: true,
      );
      final fade = find.descendant(
        of: find.byType(Skeleton),
        matching: find.byType(FadeTransition),
      );
      expect(
        tester.widget<FadeTransition>(fade).opacity.value,
        TetriOpacity.skeletonMax,
      );
      await tester.pump(const Duration(seconds: 3));
      expect(
        tester.widget<FadeTransition>(fade).opacity.value,
        TetriOpacity.skeletonMax,
      );
      expect(tester.binding.transientCallbackCount, 0);
      expect(find.bySemanticsLabel('Loading'), findsOneWidget);
      semantics.dispose();
    },
  );
}
