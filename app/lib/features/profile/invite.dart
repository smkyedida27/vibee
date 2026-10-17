import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/panels.dart';
import '../../services/api_client.dart';
import '../../services/services.dart';

/// "Invite friends, you both get gems" card. [compact] is the Home-screen variant.
class InviteCard extends StatefulWidget {
  const InviteCard({super.key, this.compact = false});
  final bool compact;

  @override
  State<InviteCard> createState() => _InviteCardState();
}

class _InviteCardState extends State<InviteCard> {
  Future<Map<String, dynamic>>? _stats;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!widget.compact) _stats ??= context.services.growth.referralStats();
  }

  void _reload() => setState(() => _stats = context.services.growth.referralStats());

  @override
  Widget build(BuildContext context) {
    final growth = context.services.growth;
    return FutureBuilder<Map<String, dynamic>>(
      future: _stats,
      builder: (context, snap) {
        final st = snap.data;
        final code = (st?['inviteCode'] as String?) ?? growth.inviteCode;
        final invited = (st?['invited'] as num?)?.toInt() ?? 0;
        final canRedeem = st?['canRedeem'] == true;
        return CandyPanel(
          rim: Candy.pink,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const GameArt(ArtKind.gem, size: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Invite friends', style: AppText.display(20, color: AppColors.ink)),
                        Text(
                          'You both get 20 gems when they join with your code',
                          style: AppText.body(13, color: AppColors.inkSoft),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!widget.compact) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        code ?? (snap.hasError ? 'Go online to get your code' : '…'),
                        style: AppText.display(code == null ? 16 : 26, color: AppColors.royal),
                      ),
                    ),
                    if (code != null)
                      CandyIconButton(
                        icon: Icons.copy_rounded,
                        size: 42,
                        candy: Candy.teal,
                        semanticLabel: 'Copy invite code',
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: code));
                          toast(context, 'Invite code copied');
                        },
                      ),
                  ],
                ),
                if (invited > 0)
                  Text(
                    '$invited friend${invited == 1 ? '' : 's'} joined with your code',
                    style: AppText.body(13, color: AppColors.inkSoft, weight: FontWeight.w700),
                  ),
              ],
              const SizedBox(height: 10),
              CandyButton(
                label: 'Invite friends',
                icon: Icons.ios_share_rounded,
                candy: Candy.pink,
                height: 50,
                onTap: () => growth.shareInvite(context),
              ),
              if (canRedeem && !widget.compact) ...[
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () async {
                      if (await showRedeemInvite(context) && mounted) _reload();
                    },
                    child: Text(
                      'Have an invite code?',
                      style: AppText.body(14, color: AppColors.royal, weight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Asks for a friend's invite code and redeems it. Returns true on success.
Future<bool> showRedeemInvite(BuildContext context) async {
  final ctrl = TextEditingController();
  final code = await showCandyDialog<String>(
    context,
    title: 'Invite code',
    ribbon: Candy.pink,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Enter a friend\'s code and you both get 20 gems.',
          textAlign: TextAlign.center,
          style: AppText.body(15, color: AppColors.inkSoft),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 8,
          textCapitalization: TextCapitalization.characters,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]'))],
          textAlign: TextAlign.center,
          style: AppText.display(24, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'ABCD2345',
            counterText: '',
            filled: true,
            fillColor: const Color(0xFFF3EAFF),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        CandyButton(label: 'Claim gems', candy: Candy.green, height: 56, onTap: () => Navigator.pop(ctx, ctrl.text)),
      ],
    ),
  );
  ctrl.dispose();
  if (code == null || !context.mounted) return false;
  if (code.trim().length != 8) {
    toast(context, 'Invite codes have 8 letters and numbers');
    return false;
  }
  try {
    final gems = await context.services.growth.redeem(code);
    if (context.mounted) {
      Audio.instance.fx(Sfx.coin, HapticKind.medium);
      toast(context, '+$gems gems! You\'re now friends', icon: Icons.favorite_rounded);
    }
    return true;
  } on ApiException catch (e) {
    if (context.mounted) toast(context, e.isOffline ? 'You\'re offline' : e.message, icon: Icons.error_rounded);
    return false;
  }
}
