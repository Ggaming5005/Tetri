import 'package:flutter/material.dart';

import '../tokens.dart';
import '../typography.dart';

class TetriScaffold extends StatelessWidget {
  const TetriScaffold({
    super.key,
    required this.child,
    this.title,
    this.bottomNavigationBar,
    this.scrollController,
  });

  final Widget child;
  final String? title;
  final Widget? bottomNavigationBar;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: TetriColors.of(context).bg,
    bottomNavigationBar: bottomNavigationBar,
    body: SafeArea(
      child: CustomScrollView(
        controller: scrollController,
        slivers: [
          if (title != null)
            SliverPersistentHeader(
              pinned: true,
              delegate: _TitleHeader(title!, TetriColors.of(context)),
            ),
          SliverPadding(
            padding: const EdgeInsets.all(TetriSpace.x24),
            sliver: SliverToBoxAdapter(child: child),
          ),
        ],
      ),
    ),
  );
}

class _TitleHeader extends SliverPersistentHeaderDelegate {
  _TitleHeader(this.title, this.colors);

  final String title;
  final TetriColors colors;

  @override
  double get minExtent => TetriSizes.button56;

  @override
  double get maxExtent => TetriSizes.scaffoldExpandedHeight;

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
    );
  }

  @override
  bool shouldRebuild(_TitleHeader oldDelegate) =>
      title != oldDelegate.title || colors != oldDelegate.colors;
}
