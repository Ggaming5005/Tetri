import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../tokens.dart';

class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.semanticLabel,
  });

  final double width;
  final double height;
  final String? semanticLabel;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: TetriMotion.skeletonPulse,
  );
  late final Animation<double> _opacity = Tween(
    begin: TetriOpacity.skeletonMin,
    end: TetriOpacity.skeletonMax,
  ).animate(CurvedAnimation(parent: _controller, curve: TetriMotion.curve));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1;
    } else {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: widget.semanticLabel ?? TetriStrings.loading,
    child: FadeTransition(
      opacity: _opacity,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: TetriColors.of(context).surface,
          borderRadius: BorderRadius.circular(TetriRadii.r8),
        ),
      ),
    ),
  );
}
