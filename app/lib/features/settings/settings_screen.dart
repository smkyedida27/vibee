import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_background.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/outlined_text.dart';
import '../../core/ui/panels.dart';
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
              Row(children: [
                CandyIconButton(icon: Icons.arrow_back_rounded, size: 46, onTap: () => context.pop(), semanticLabel: 'Back'),
                const SizedBox(width: 12),
                const OutlinedText('Settings', size: 32),
              ]),
              const SectionTitle('Sound & feel'),
              CandyPanel(
                child: Column(children: [
                  _Toggle(icon: Icons.volume_up_rounded, label: 'Sound effects', value: st.sound, onChanged: (v) => set((x) => x.sound = v)),
                  _Toggle(icon: Icons.vibration_rounded, label: 'Haptics', value: st.haptics, onChanged: (v) => set((x) => x.haptics = v)),
                  _Toggle(
                    icon: Icons.motion_photos_off_rounded,
                    label: 'Reduce motion',
                    value: st.reducedMotion,
                    onChanged: (v) => set((x) => x.reducedMotion = v),
                  ),
                ]),
              ),
              const SectionTitle('Reminders'),
              CandyPanel(
                child: Column(children: [
                  _Toggle(
                    icon: Icons.notifications_active_rounded,
                    label: 'Daily puzzle reminder',
                    value: st.reminders,
                    onChanged: (v) {
                      set((x) => x.reminders = v);
                      if (v) FirebaseSetup.enablePush(s.api).catchError((Object _) => false);
                      s.api.updatePreferences({'notificationsEnabled': v, 'reminderTime': '${st.reminderHour.toString().padLeft(2, '0')}:00'}).catchError((Object _) {});
                    },
                  ),
                  if (st.reminders)
                    Row(children: [
                      const SizedBox(width: 8),
                      Text('Remind me at', style: AppText.body(15)),
                      const Spacer(),
                      DropdownButton<int>(
                        value: st.reminderHour,
                        underline: const SizedBox(),
                        style: AppText.display(18, color: AppColors.royal),
                        items: [for (var h = 6; h <= 22; h++) DropdownMenuItem(value: h, child: Text('${h.toString().padLeft(2, '0')}:00'))],
                        onChanged: (h) {
                          if (h == null) return;
                          set((x) => x.reminderHour = h);
                          s.api.updatePreferences({'reminderTime': '${h.toString().padLeft(2, '0')}:00'}).catchError((Object _) {});
                        },
                      ),
                    ]),
                ]),
              ),
              const SectionTitle('Account'),
              CandyPanel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    s.api.hasSession
                        ? 'Your progress is backed up to a guest account on this device.'
                        : 'Playing offline. Progress is stored on this device.',
                    style: AppText.body(14, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 12),
                  CandyButton(
                    label: 'Back up now',
                    icon: Icons.cloud_upload_rounded,
                    candy: Candy.blue,
                    height: 52,
                    onTap: () async {
                      await s.sync.push();
                      if (context.mounted) toast(context, 'Progress backed up', icon: Icons.cloud_done_rounded);
                    },
                  ),
                  const SizedBox(height: 10),
                  CandyButton(
                    label: 'Restore purchases',
                    icon: Icons.restore_rounded,
                    candy: Candy.purple,
                    height: 52,
                    onTap: s.purchases.restore,
                  ),
                  if (s.ads.privacyOptionsRequired) ...[
                    const SizedBox(height: 10),
                    CandyButton(
                      label: 'Privacy & ad choices',
                      icon: Icons.privacy_tip_rounded,
                      candy: Candy.teal,
                      height: 52,
                      onTap: s.ads.showPrivacyOptions,
                    ),
                  ],
                  const SizedBox(height: 10),
                  CandyButton(
                    label: 'Delete account',
                    icon: Icons.delete_forever_rounded,
                    candy: Candy.red,
                    height: 52,
                    onTap: () => _delete(context),
                  ),
                ]),
              ),
              const SectionTitle('About'),
              GlassPanel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Puzzle Hub', style: AppText.display(20)),
                  Text('Version 1.0.0', style: AppText.body(13, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Text('Privacy policy: puzzlehub.app/privacy\nTerms: puzzlehub.app/terms\nSupport: support@puzzlehub.app',
                      style: AppText.body(13, color: Colors.white)),
                ]),
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
      message: 'This permanently deletes your progress, scores, friends and purchase history from our servers and this device. '
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

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.value, required this.onChanged});
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          Icon(icon, color: AppColors.royal),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppText.body(16))),
          Switch.adaptive(value: value, onChanged: onChanged, activeTrackColor: AppColors.success),
        ]),
      );
}
