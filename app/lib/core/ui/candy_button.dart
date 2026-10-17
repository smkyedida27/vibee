import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../theme/palette.dart';
import 'outlined_text.dart';

/// Glossy, 3D "jelly" button — a dark lip under a gradient face with a specular
/// highlight. The face sinks into the lip when pressed.
class CandyButton extends StatefulWidget {
  const CandyButton({
    super.key,
    required this.label,
    this.onTap,
    this.candy = Candy.green,
    this.icon,
    this.leading,
    this.height = 64,
    this.width,
    this.fontSize,
    this.radius,
    this.depth = 7,
    this.sound = Sfx.pop,
    this.pulse = false,
    this.trailing,
  });

  final String label;
  final VoidCallback? onTap;
  final Candy candy;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final double height;
  final double? width;
  final double? fontSize;
  final double? radius;
  final double depth;
  final Sfx sound;

  /// Gentle breathing scale to draw attention to the primary CTA.
  final bool pulse;

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton> with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 70),
    reverseDuration: const Duration(milliseconds: 220),
  );
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  bool get _enabled => widget.onTap != null;

  @override
  void initState() {
    super.initState();
    if (widget.pulse) _breath.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant CandyButton old) {
    super.didUpdateWidget(old);
    if (widget.pulse && !_breath.isAnimating) _breath.repeat(reverse: true);
    if (!widget.pulse && _breath.isAnimating) _breath.stop();
  }

  @override
  void dispose() {
    _press.dispose();
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _enabled ? widget.candy : Candy.grey;
    final r = widget.radius ?? widget.height * 0.36;
    final fs = widget.fontSize ?? widget.height * 0.38;
    final faceH = widget.height - widget.depth;

    final button = Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _press.forward() : null,
        onTapCancel: _enabled ? () => _press.reverse() : null,
        onTapUp: _enabled
            ? (_) {
                _press.reverse();
                Audio.instance.fx(widget.sound, HapticKind.medium);
                widget.onTap!();
              }
            : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_press, _breath]),
          builder: (context, _) {
            final p = _press.value;
            final sink = widget.depth * 0.75 * p;
            final breathe = widget.pulse ? 1 + 0.035 * Curves.easeInOut.transform(_breath.value) : 1.0;
            return Transform.scale(
              scale: breathe * (1 - 0.02 * p),
              child: SizedBox(
                height: widget.height,
                width: widget.width,
                child: Stack(
                  children: [
                    // Lip + soft drop shadow.
                    Positioned.fill(
                      top: widget.depth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: c.dark,
                          borderRadius: BorderRadius.circular(r),
                          boxShadow: [
                            BoxShadow(
                              color: c.dark.withValues(alpha: 0.45),
                              blurRadius: 14,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Face.
                    Positioned(
                      left: 0,
                      right: 0,
                      top: sink,
                      height: faceH,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: c.face,
                          borderRadius: BorderRadius.circular(r),
                          border: Border.all(color: c.dark.withValues(alpha: 0.55), width: 2),
                        ),
                        child: Stack(
                          children: [
                            // Specular gloss.
                            Positioned(
                              left: r * 0.45,
                              right: r * 0.45,
                              top: 3,
                              height: faceH * 0.42,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(r),
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.white.withValues(alpha: 0.75),
                                      Colors.white.withValues(alpha: 0.05),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Little sparkle dot top-left.
                            Positioned(
                              left: r * 0.55,
                              top: faceH * 0.18,
                              child: Container(
                                width: faceH * 0.11,
                                height: faceH * 0.11,
                                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: widget.label.isEmpty ? 0 : widget.height * 0.3,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (widget.leading != null) ...[
                                      widget.leading!,
                                      if (widget.label.isNotEmpty) const SizedBox(width: 8),
                                    ],
                                    if (widget.icon != null) ...[
                                      Icon(
                                        widget.icon,
                                        color: c.on,
                                        size: fs * 1.15,
                                        shadows: [Shadow(color: c.dark, offset: const Offset(0, 2), blurRadius: 0)],
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    if (widget.label.isNotEmpty)
                                      Flexible(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: OutlinedText(
                                            widget.label,
                                            size: fs,
                                            color: c.on,
                                            stroke: c.dark,
                                            shadow: false,
                                            maxLines: 1,
                                          ),
                                        ),
                                      ),
                                    if (widget.trailing != null) ...[const SizedBox(width: 8), widget.trailing!],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
    // A breathing button repaints every frame; keep that on its own layer.
    return widget.pulse ? RepaintBoundary(child: button) : button;
  }
}

/// Round icon-only candy button (back, settings, close…).
class CandyIconButton extends StatelessWidget {
  const CandyIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.candy = Candy.purple,
    this.size = 50,
    this.semanticLabel,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Candy candy;
  final double size;
  final String? semanticLabel;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CandyButton(
            label: '',
            onTap: onTap,
            candy: candy,
            height: size,
            width: size,
            depth: size * 0.12,
            radius: size * 0.34,
            sound: Sfx.tap,
            leading: Icon(
              icon,
              color: candy.on,
              size: size * 0.48,
              shadows: [Shadow(color: candy.dark, offset: const Offset(0, 2))],
            ),
          ),
          if (badge != null)
            Positioned(
              right: -4,
              top: -6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.heart,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(fontFamily: 'LilitaOne', color: Colors.white, fontSize: 12, height: 1.1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
