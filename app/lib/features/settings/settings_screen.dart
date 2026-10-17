import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_background.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/dialogs.dart';
import '../../services/api_client.dart';
import '../../services/firebase_setup.dart';
import '../../services/services.dart';
import '../../state/player.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final st = context.player.data.settings;
    void set(void Function(Settings) f) => s.player.updateSettings(f);
    return Scaffold(
      body: CandyBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Row(
                children: [
                  CandyIconButton(
                    icon: Icons.arrow_back_rounded,
                    size: 46,
                    onTap: () => context.pop(),
                    semanticLabel: 'Back',
                  ),
                  const SizedBox(width: 14),
                  Text('Settings', style: AppText.display(28)),
                ],
              ),
              const _Header('Sound & feel'),
              _Group(
                children: [
                  _Toggle(
                    icon: Icons.volume_up_rounded,
                    candy: Candy.ink,
                    label: 'Sound effects',
                    value: st.sound,
                    onChanged: (v) => set((x) => x.sound = v),
                  ),
                  _Toggle(
                    icon: Icons.vibration_rounded,
                    candy: Candy.blue,
                    label: 'Haptics',
                    value: st.haptics,
                    onChanged: (v) => set((x) => x.haptics = v),
                  ),
                  _Toggle(
                    icon: Icons.motion_photos_off_rounded,
                    candy: Candy.teal,
                    label: 'Reduce motion',
                    value: st.reducedMotion,
                    onChanged: (v) => set((x) => x.reducedMotion = v),
                  ),
                ],
              ),
              const _Header('Reminders'),
              _Group(
                children: [
                  _Toggle(
                    icon: Icons.notifications_active_rounded,
                    candy: Candy.orange,
                    label: 'Daily puzzle reminder',
                    value: st.reminders,
                    onChanged: (v) async {
                      if (v && !await s.reminders.requestPermission()) {
                        if (context.mounted) {
                          toast(context, 'Allow notifications for Quintile in your phone settings to get reminders');
                        }
                        return;
                      }
                      set((x) => x.reminders = v);
                      if (v) {
                        FirebaseSetup.enablePush(s.api).catchError((Object _) => false);
                        if (context.mounted) {
                          toast(
                            context,
                            'We\'ll remind you when new puzzles are ready',
                            icon: Icons.notifications_active_rounded,
                          );
                        }
                      }
                      s.api
                          .updatePreferences({
                            'notificationsEnabled': v,
                            'reminderTime': '${st.reminderHour.toString().padLeft(2, '0')}:00',
                          })
                          .catchError((Object _) {});
                    },
                  ),
                  if (st.reminders)
                    _Row(
                      icon: Icons.schedule_rounded,
                      candy: Candy.gold,
                      label: 'Remind me at',
                      trailing: DropdownButton<int>(
                        value: st.reminderHour,
                        underline: const SizedBox(),
                        borderRadius: BorderRadius.circular(14),
                        dropdownColor: AppColors.surface,
                        style: AppText.body(16, color: AppColors.primary, weight: FontWeight.w700),
                        items: [
                          for (var h = 6; h <= 22; h++)
                            DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00')),
                        ],
                        onChanged: (h) {
                          if (h == null) return;
                          set((x) => x.reminderHour = h);
                          s.api
                              .updatePreferences({'reminderTime': '${h.toString().padLeft(2, '0')}:00'})
                              .catchError((Object _) {});
                        },
                      ),
                    ),
                ],
              ),
              const _Header('Account'),
              _Group(
                children: [
                  _Row(
                    icon: Icons.cloud_upload_rounded,
                    candy: Candy.blue,
                    label: 'Back up now',
                    onTap: () async {
                      await s.sync.push();
                      if (context.mounted) toast(context, 'Progress backed up', icon: Icons.cloud_done_rounded);
                    },
                  ),
                  _Row(
                    icon: Icons.restore_rounded,
                    candy: Candy.ink,
                    label: 'Restore purchases',
                    onTap: s.purchases.restore,
                  ),
                  if (s.ads.privacyOptionsRequired)
                    _Row(
                      icon: Icons.privacy_tip_rounded,
                      candy: Candy.teal,
                      label: 'Privacy & ad choices',
                      onTap: s.ads.showPrivacyOptions,
                    ),
                  _Row(
                    icon: Icons.delete_forever_rounded,
                    candy: Candy.red,
                    label: 'Delete account',
                    destructive: true,
                    onTap: () => _delete(context),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  s.api.hasSession
                      ? 'Your progress is backed up to a guest account on this device.'
                      : 'Playing offline. Progress is stored on this device.',
                  style: AppText.body(13, color: AppColors.inkSoft),
                ),
              ),
              const _Header('About'),
              _Group(
                children: [
                  _Row(
                    icon: Icons.extension_rounded,
                    candy: Candy.ink,
                    label: 'Quintile',
                    trailing: Text('Version 1.0.0', style: AppText.body(14, color: AppColors.inkSoft)),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  'Privacy policy: puzzlehub.app/privacy\nTerms: puzzlehub.app/terms\nSupport: support@puzzlehub.app',
                  style: AppText.body(13, color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context) async {
    final s = context.services;
    final ok = await confirmDialog(
      context,
      title: 'Delete account?',
      message:
          'This permanently deletes your progress, scores, friends and purchase history from our servers and this device. '
          'Active subscriptions must be cancelled in Google Play.',
      yes: 'Delete',
      candy: Candy.red,
    );
    if (!ok || !context.mounted) return;
    try {
      if (s.api.hasSession) await s.api.deleteAccount();
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.isOffline ? 'Connect to the internet to delete your account' : e.message);
      return;
    }
    await s.player.wipe();
    if (context.mounted) context.go('/onboarding');
  }
}

/// Small tracked group label above an iOS-style grouped card.
class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
    child: Text(text.toUpperCase(), style: AppText.label(12)),
  );
}

/// White grouped card with hairline dividers between rows.
class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
      boxShadow: AppColors.cardShadow,
    ),
    clipBehavior: Clip.antiAlias,
    child: Material(
      type: MaterialType.transparency,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(height: 1, thickness: 1, indent: 62, color: AppColors.divider),
            children[i],
          ],
        ],
      ),
    ),
  );
}

class _IconTile extends StatelessWidget {
  const _IconTile(this.icon, this.candy);
  final IconData icon;
  final Candy candy;

  @override
  Widget build(BuildContext context) => Container(
    width: 34,
    height: 34,
    decoration: BoxDecoration(color: candy.light, borderRadius: BorderRadius.circular(10)),
    child: Icon(icon, color: candy.base, size: 20),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.candy,
    required this.label,
    this.onTap,
    this.trailing,
    this.destructive = false,
  });
  final IconData icon;
  final Candy candy;
  final String label;
  final VoidCallback? onTap;
  final Widget? trailing;
  final bool destructive;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        child: Row(
          children: [
            _IconTile(icon, candy),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppText.body(16, color: destructive ? AppColors.danger : AppColors.ink, weight: FontWeight.w600),
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkFaint),
          ],
        ),
      ),
    ),
  );
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    this.candy = Candy.purple,
  });
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Candy candy;

  @override
  Widget build(BuildContext context) => _Row(
    icon: icon,
    candy: candy,
    label: label,
    trailing: Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: AppColors.success),
  );
}
