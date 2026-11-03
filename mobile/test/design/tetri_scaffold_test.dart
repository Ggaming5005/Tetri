import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tetri/design/components/tetri_scaffold.dart';
import 'package:tetri/design/theme.dart';
import 'package:tetri/design/tokens.dart';
import 'package:tetri/design/typography.dart';

void main() {
  testWidgets('collapsed title reserves enough height for accessibility text', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: TetriTheme.light,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: TetriScaffold(
            title: 'Activity',
            scrollController: controller,
            child: const SizedBox(height: 1600),
          ),
        ),
      ),
    );
    controller.jumpTo(240);
    await tester.pump();
    final title = tester.getRect(find.text('Activity'));
    expect(title.height, greaterThanOrEqualTo(48));
    expect(title.top, greaterThanOrEqualTo(0));
    expect(title.bottom, lessThanOrEqualTo(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('scaffold respects safe area and 24 point side padding', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: TetriTheme.light,
        home: const MediaQuery(
          data: MediaQueryData(padding: EdgeInsets.only(top: 32, bottom: 20)),
          child: TetriScaffold(child: Text('Content')),
        ),
      ),
    );
    final content = tester.getRect(find.text('Content'));
    expect(content.left, TetriSpace.x24);
    expect(content.top, 32 + TetriSpace.x24);
  });

  testWidgets('large title collapses on scroll and stays visible', (
    tester,
  ) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: TetriTheme.light,
        home: TetriScaffold(
          title: 'Activity',
          scrollController: controller,
          child: const SizedBox(height: 1600, child: Text('Content')),
        ),
      ),
    );
    expect(
      tester.widget<Text>(find.text('Activity')).style!.fontSize,
      TetriTypography.headline.fontSize,
    );
    controller.jumpTo(240);
    await tester.pump();
    expect(
      tester.widget<Text>(find.text('Activity')).style!.fontSize,
      TetriTypography.title.fontSize,
    );
    expect(tester.getRect(find.text('Activity')).top, greaterThanOrEqualTo(0));
    expect(tester.takeException(), isNull);
  });
}
