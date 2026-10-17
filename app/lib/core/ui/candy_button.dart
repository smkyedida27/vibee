import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// Primary button: flat solid fill with a slim darker base edge for tactility.
/// Presses sink onto the edge with a quick, springy release.
class CandyButton extends StatefulWidget {
  const CandyButton({
    super.key,
    required this.label,
    this.onTap,
    this.candy = Candy.green,
    this.icon,
    this.leading,
    this.height = 56,
    this.width,
    this.fontSize,
    this.radius,
    this.depth = 3,
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

  /// Subtle breathing scale for the one primary call to action on a screen.
  final bool pulse;

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton> with TickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 60),
    reverseDuration: const Duration(milliseconds: 180),
  );
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
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
    final onColor = _enabled ? c.on : AppColors.inkFaint;
    final r = widget.radius ?? widget.height / 2;
    final fs = widget.fontSize ?? (widget.height * 0.3).clamp(13.0, 18.0);
    final depth = widget.depth.clamp(0.0, 5.0);
    final outlined = c == Candy.white;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label.isEmpty ? null : widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _enabled ? (_) => _press.forward() : null,
        onTapCancel: _enabled ? () => _press.reverse() : null,
        onTapUp: _enabled
            ? (_) {
                _press.reverse();
                Audio.instance.fx(widget.sound, HapticKind.light);
                widget.onTap!();
              }
            : null,
        child: AnimatedBuilder(
          animation: Listenable.merge([_press, _breath]),
          builder: (context, child) {
            final p = _press.value;
            final breathe = widget.pulse && !reduce ? 1 + 0.018 * Curves.easeInOut.transform(_breath.value) : 1.0;
            return Transform.scale(
              scale: breathe * (1 - 0.015 * p),
              child: SizedBox(
                height: widget.height,
                width: widget.width,
                child: Stack(
                  children: [
                    if (depth > 0)
                      Positioned.fill(
                        top: depth,
                        child: DecoratedBox(
                          decoration: BoxDecoration(color: c.dark, borderRadius: BorderRadius.circular(r)),
                        ),
                      ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: depth * p,
                      height: widget.height - depth,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color.lerp(c.base, c.dark, 0.25 * p),
                          borderRadius: BorderRadius.circular(r),
                          border: outlined ? Border.all(color: AppColors.border, width: 1.5) : null,
                        ),
                        child: child,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: widget.label.isEmpty ? 0 : 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.leading != null) ...[
                    widget.leading!,
                    if (widget.label.isNotEmpty) const SizedBox(width: 8),
                  ],
                  if (widget.icon != null) ...[
                    Icon(widget.icon, color: onColor, size: fs * 1.25),
                    if (widget.label.isNotEmpty) const SizedBox(width: 8),
                  ],
                  if (widget.label.isNotEmpty)
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(fs, color: onColor, weight: FontWeight.w700),
                      ),
                    ),
                  if (widget.trailing != null) ...[const SizedBox(width: 8), widget.trailing!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Icon-only button: a white chip with a hairline border and the accent-coloured icon.
class CandyIconButton extends StatelessWidget {
  const CandyIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.candy = Candy.purple,
    this.size = 48,
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
    final iconColor = candy == Candy.purple || candy == Candy.white || candy == Candy.grey || candy == Candy.ink
        ? AppColors.ink
        : candy.base;
    return Semantics(
      label: semanticLabel,
      button: true,
      excludeSemantics: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CandyButton(
            label: '',
            onTap: onTap,
            candy: Candy.white,
            height: size,
            width: size,
            depth: 0,
            radius: size / 2,
            sound: Sfx.tap,
            leading: Icon(icon, color: onTap == null ? AppColors.inkFaint : iconColor, size: size * 0.46),
          ),
          if (badge != null)
            Positioned(
              right: -5,
              top: -5,
              child: Container(
                constraints: const BoxConstraints(minWidth: 20),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.bg, width: 2),
                ),
                child: Text(
                  badge!,
                  textAlign: TextAlign.center,
                  style: AppText.body(11, color: Colors.white, weight: FontWeight.w800),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
