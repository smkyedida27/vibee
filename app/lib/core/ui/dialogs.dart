import 'package:flutter/material.dart';

import '../audio/sfx.dart';
import '../theme/app_theme.dart';
import '../theme/palette.dart';
import 'candy_button.dart';
import 'panels.dart';

/// Pops a candy dialog with an elastic scale-in, ribbon title and close button.
Future<T?> showCandyDialog<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext) builder,
  Candy ribbon = Candy.pink,
  bool dismissible = true,
  bool showClose = true,
}) {
  Audio.instance.play(Sfx.whoosh, volume: 0.5);
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: title,
    barrierColor: const Color(0x8C17171C),
    transitionDuration: const Duration(milliseconds: 260),
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Center(
        // Scrolls instead of overflowing on short screens or with large text.
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [BoxShadow(color: Color(0x2917171C), blurRadius: 40, offset: Offset(0, 16))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        if (showClose) const SizedBox(width: 36),
                        Expanded(child: RibbonBanner(title, candy: ribbon, fontSize: 22)),
                        if (showClose)
                          Semantics(
                            button: true,
                            label: 'Close',
                            child: GestureDetector(
                              onTap: () => Navigator.of(ctx).maybePop(),
                              child: Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
                                child: const Icon(Icons.close_rounded, size: 20, color: AppColors.inkSoft),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    builder(ctx),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    transitionBuilder: (ctx, anim, _, child) {
      final reduce = MediaQuery.maybeDisableAnimationsOf(ctx) ?? false;
      final curved = CurvedAnimation(
        parent: anim,
        curve: reduce ? Curves.linear : Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: const Interval(0, 0.4)),
        child: ScaleTransition(scale: Tween(begin: 0.92, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

/// Simple confirm with two candy buttons.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String yes = 'Yes',
  String no = 'Cancel',
  Candy candy = Candy.orange,
}) async {
  final r = await showCandyDialog<bool>(
    context,
    title: title,
    ribbon: candy,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: AppText.body(17, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              child: CandyButton(label: no, candy: Candy.grey, height: 54, onTap: () => Navigator.pop(ctx, false)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CandyButton(label: yes, candy: Candy.green, height: 54, onTap: () => Navigator.pop(ctx, true)),
            ),
          ],
        ),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String message, {IconData icon = Icons.info_rounded}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1800),
        content: Row(
          children: [
            Icon(icon, color: AppColors.gold),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
}
