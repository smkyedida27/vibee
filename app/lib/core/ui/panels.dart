import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// The main content surface: a white card with a hairline border and soft elevation.
/// [rim] is kept for compatibility; pass [accent] true to show it as a slim top bar.
class CandyPanel extends StatelessWidget {
  const CandyPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.rim = Candy.purple,
    this.radius = 20,
    this.color = AppColors.surface,
    this.accent = false,
  });

  final Widget child;
  final EdgeInsets padding;
  final Candy rim;
  final double radius;
  final Color color;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: accent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(height: 4, color: rim.base),
                Padding(padding: padding, child: child),
              ],
            )
          : Padding(padding: padding, child: child),
    );
  }
}

/// Secondary surface: white card, border only (lists, rows on the page background).
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.radius = 18});
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

/// Screen/popup title. Formerly a ribbon; now a clean heading.
class RibbonBanner extends StatelessWidget {
  const RibbonBanner(this.text, {super.key, this.candy = Candy.pink, this.fontSize = 24, this.width});
  final String text;
  final Candy candy;
  final double fontSize;
  final double? width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppText.display(fontSize.clamp(18.0, 26.0)),
      ),
    );
  }
}

/// Section header used on scrolling screens.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 24, 2, 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: AppText.display(19))),
          ?trailing,
        ],
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = AppColors.primary, this.icon});
  final String text;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 14, color: Colors.white), const SizedBox(width: 4)],
          Text(text, style: AppText.label(11, color: Colors.white)),
        ],
      ),
    );
  }
}
