import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/palette.dart';

/// On wide screens (web on a laptop, tablets in landscape) the game is shown at phone size
/// in a centred frame instead of stretching edge to edge; phones get the child unchanged.
class PhoneFrame extends StatelessWidget {
  const PhoneFrame({super.key, required this.child});
  final Widget child;

  static const _maxPhoneWidth = 600.0;
  static const _width = 412.0;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    if (mq.size.width <= _maxPhoneWidth) return child;
    final height = (mq.size.height - 48).clamp(560.0, 900.0);
    final showBrand = mq.size.width >= 1000;
    final phone = Container(
      width: _width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppColors.ink, width: 8),
        boxShadow: const [BoxShadow(color: Color(0x33403A2E), blurRadius: 40, offset: Offset(0, 20))],
      ),
      clipBehavior: Clip.antiAlias,
      child: MediaQuery(
        data: mq.copyWith(
          size: Size(_width - 16, height - 16),
          padding: const EdgeInsets.only(top: 12),
          viewPadding: const EdgeInsets.only(top: 12),
        ),
        child: child,
      ),
    );
    return Material(
      color: const Color(0xFFE9E5DC),
      child: Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showBrand) ...[
              SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quintile', style: AppText.display(64)),
                    const SizedBox(height: 10),
                    Container(width: 80, height: 2, color: AppColors.ink),
                    const SizedBox(height: 16),
                    Text(
                      'Five puzzles.\nOne daily ritual.',
                      style: AppText.display(28, color: AppColors.inkSoft, height: 1.2),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Word Connect, Crowns, Sudoku, Word Ladder and Number Merge — a fresh set every day. '
                      'Best on your phone.',
                      style: AppText.body(16, color: AppColors.inkSoft),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        for (final c in [Candy.gold, Candy.orange, Candy.blue, Candy.green, Candy.purple])
                          Container(
                            width: 26,
                            height: 26,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(color: c.base, borderRadius: BorderRadius.circular(6)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 80),
            ],
            phone,
          ],
        ),
      ),
    );
  }
}
