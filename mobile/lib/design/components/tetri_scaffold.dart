import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

class TetriScaffold extends StatelessWidget {
  const TetriScaffold({
    super.key,
    required this.child,
    this.title,
    this.bottomNavigationBar,
    this.bottomAction,
    this.scrollController,
    this.fillViewport = false,
  });

  final Widget child;
  final String? title;
  final Widget? bottomNavigationBar;
  final Widget? bottomAction;
  final ScrollController? scrollController;
  final bool fillViewport;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TetriColors.of(context).bg,
    bottomNavigationBar: bottomNavigationBar,
    resizeToAvoidBottomInset: true,
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final inlineAction =
              bottomAction != null &&
              constraints.maxHeight < TetriSizes.compactViewportHeight;
          final scroll = CustomScrollView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              if (title != null)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _TitleHeader(
                    title!,
                    TetriColors.of(context),
                    MediaQuery.textScalerOf(context),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.all(TetriSpace.x24),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: TetriSizes.contentMaxWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          child,
                          if (inlineAction) ...[
                            const SizedBox(height: TetriSpace.x24),
                            bottomAction!,
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
          return Column(
            children: [
              Expanded(
                child: fillViewport
                    ? Padding(
                        padding: const EdgeInsets.all(TetriSpace.x24),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: TetriSizes.contentMaxWidth,
                            ),
                            child: SizedBox.expand(child: child),
                          ),
                        ),
                      )
                    : scroll,
              ),
              if (bottomAction != null && !inlineAction)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    TetriSpace.x24,
                    TetriSpace.x8,
                    TetriSpace.x24,
                    TetriSpace.x16,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: TetriSizes.contentMaxWidth,
                    ),
                    child: bottomAction!,
                  ),
                ),
            ],
          );
        },
      ),
    ),
  );
}

class _TitleHeader extends SliverPersistentHeaderDelegate {
  _TitleHeader(this.title, this.colors, this.textScaler);

  final String title;
  final TetriColors colors;
  final TextScaler textScaler;

  double _lineHeight(TextStyle style) =>
      textScaler.scale(style.fontSize!) * style.height!;

  @override
  double get minExtent => math.max(
    TetriSizes.button56,
    _lineHeight(TetriTypography.title) + TetriSpace.x16 * 2,
  );

  @override
  double get maxExtent => math.max(
    TetriSizes.scaffoldExpandedHeight,
    _lineHeight(TetriTypography.headline) + TetriSpace.x16 * 2 + TetriSpace.x48,
  );

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final collapse = (shrinkOffset / (maxExtent - minExtent)).clamp(0.0, 1.0);
    return ColoredBox(
      color: colors.bg,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: TetriSpace.x24,
          vertical: TetriSpace.x16,
        ),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: TetriSizes.contentMaxWidth,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle.lerp(
                    TetriTypography.headline,
                    TetriTypography.title,
                    collapse,
                  )!.copyWith(color: colors.textPrimary),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_TitleHeader oldDelegate) =>
      title != oldDelegate.title ||
      colors != oldDelegate.colors ||
      textScaler != oldDelegate.textScaler;
}
