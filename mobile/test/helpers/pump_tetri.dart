import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tetri/design/theme.dart';
import 'package:tetri/design/tokens.dart';

Future<void> pumpTetri(
  WidgetTester tester,
  Widget child, {
  Brightness brightness = Brightness.light,
  bool disableAnimations = false,
  Size size = const Size(360, 800),
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: brightness == Brightness.dark ? TetriTheme.dark : TetriTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: disableAnimations),
        child: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(TetriSpace.x24),
              child: child,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}
