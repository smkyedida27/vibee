import 'package:flutter/material.dart';

import '../audio/sfx.dart';

/// Springy press feedback used by every tappable surface in the app.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.93,
    this.sound = Sfx.tap,
    this.semanticLabel,
    this.enabled = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final Sfx? sound;
  final String? semanticLabel;
  final bool enabled;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 260),
  );

  bool get _active => widget.enabled && widget.onTap != null;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _active,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _active ? (_) => _c.forward() : null,
        onTapCancel: _active ? () => _c.reverse() : null,
        onTapUp: _active
            ? (_) {
                _c.reverse();
                if (widget.sound != null) Audio.instance.fx(widget.sound!, HapticKind.light);
                widget.onTap!();
              }
            : null,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = Curves.easeOut.transform(_c.value);
            final s = 1 - (1 - widget.scale) * t;
            return Transform.scale(scale: s, child: child);
          },
          child: widget.child,
        ),
      ),
    );
  }
}
