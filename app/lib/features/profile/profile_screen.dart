import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_background.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/dialogs.dart';
import '../../core/ui/game_art.dart';
import '../../core/ui/hud.dart';
import '../../core/ui/outlined_text.dart';
import '../../core/ui/panels.dart';
import '../../core/ui/pressable.dart';
import '../../games/common/game_type.dart';
import '../../services/api_client.dart';
import '../../services/services.dart';
import '../../state/player.dart';
import '../home/home_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Future<Map<String, dynamic>>? _remote;
  Future<List<dynamic>>? _friends;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _remote ??= context.services.api.profile();
    _friends ??= context.services.api.friends();
  }

  void _reloadFriends() => setState(() => _friends = context.services.api.friends());

  Future<void> _removeFriend(Map<String, dynamic> f) async {
    final ok = await confirmDialog(context,
        title: 'Remove friend?', message: 'Remove ${f['displayName']} from your friends?', yes: 'Remove', candy: Candy.red);
    if (!ok || !mounted) return;
    try {
      await context.services.api.removeFriend('${f['userId']}');
      _reloadFriends();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.isOffline ? "You're offline" : e.message, icon: Icons.error_rounded);
    }
  }

  Future<void> _editName() async {
    final s = context.services;
    final ctrl = TextEditingController(text: s.player.data.displayName);
    final name = await showCandyDialog<String>(
      context,
      title: 'Your name',
      ribbon: Candy.blue,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: ctrl,
          autofocus: true,
          maxLength: 20,
          textAlign: TextAlign.center,
          style: AppText.display(24, color: AppColors.ink),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF3EAFF),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 8),
        CandyButton(label: 'Save', candy: Candy.green, height: 56, onTap: () => Navigator.pop(ctx, ctrl.text)),
      ]),
    );
    if (name == null) return;
    if (cleanDisplayName(name) == null) {
      if (mounted) toast(context, 'Names need 2–20 letters or numbers');
      return;
    }
    s.player.updateProfile(name: name);
    unawaited(s.pushProfile());
  }

  @override
  Widget build(BuildContext context) {
    final s = context.services;
    final d = context.player.data;
    return Scaffold(
      body: CandyBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              Row(children: [
                CandyIconButton(icon: Icons.arrow_back_rounded, size: 46, onTap: () => context.pop(), semanticLabel: 'Back'),
                const Spacer(),
                CandyIconButton(
                    icon: Icons.settings_rounded, size: 46, candy: Candy.blue, onTap: () => context.push('/settings'), semanticLabel: 'Settings'),
              ]),
              const SizedBox(height: 8),
              Center(child: Avatar(index: d.avatar, size: 110, ring: true)),
              const SizedBox(height: 8),
              Center(
                child: Pressable(
                  onTap: _editName,
                  semanticLabel: 'Edit name',
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    OutlinedText(d.displayName, size: 32),
                    const SizedBox(width: 6),
                    const Icon(Icons.edit_rounded, color: Colors.white70),
                  ]),
                ),
              ),
              if (d.isVip)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Pill('VIP MEMBER', color: Color(0xFFE08A00), icon: Icons.workspace_premium_rounded),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 64,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: Avatar.count,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Pressable(
                    onTap: () {
                      s.player.updateProfile(avatar: i);
                      unawaited(s.pushProfile());
                    },
                    semanticLabel: 'Avatar ${i + 1}',
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: d.avatar == i ? AppColors.gold : Colors.transparent, width: 3),
                      ),
                      child: Avatar(index: i, size: 52),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(children: [
                Expanded(child: _BigStat(icon: Icons.local_fire_department_rounded, color: const Color(0xFFFF7A1A), value: '${d.streak}', label: 'Day streak')),
                const SizedBox(width: 10),
                Expanded(child: _BigStat(art: ArtKind.star, value: '${d.totalStars}', label: 'Stars')),
                const SizedBox(width: 10),
                Expanded(child: _BigStat(art: ArtKind.crown, value: '${d.highestCleared}', label: 'Levels')),
              ]),
              const SectionTitle('Game stats'),
              CandyPanel(
                rim: Candy.purple,
                child: Column(children: [
                  for (final g in GameType.values) _GameStatRow(game: g),
                ]),
              ),
              const SectionTitle('Friends'),
              FutureBuilder<Map<String, dynamic>>(
                future: _remote,
                builder: (context, snap) {
                  final code = snap.data?['friendCode'] as String?;
                  return GlassPanel(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Your friend code', style: AppText.body(13, color: Colors.white70)),
                      Row(children: [
                        Expanded(
                          child: Text(code ?? (snap.hasError ? 'Go online to get your code' : '…'),
                              style: AppText.display(code == null ? 16 : 26, color: Colors.white)),
                        ),
                        if (code != null)
                          CandyIconButton(
                            icon: Icons.copy_rounded,
                            size: 42,
                            candy: Candy.teal,
                            semanticLabel: 'Copy friend code',
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: code));
                              toast(context, 'Friend code copied');
                            },
                          ),
                      ]),
                      FutureBuilder<List<dynamic>>(
                        future: _friends,
                        builder: (context, fs) {
                          final list = fs.data ?? const [];
                          if (list.isEmpty) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(children: [
                              for (final f in list.cast<Map<String, dynamic>>())
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(children: [
                                    Avatar(index: (f['avatarId'] as num?)?.toInt() ?? 0, size: 38),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text('${f['displayName']}',
                                          overflow: TextOverflow.ellipsis, style: AppText.display(18, color: Colors.white)),
                                    ),
                                    IconButton(
                                      tooltip: 'Remove friend',
                                      icon: const Icon(Icons.person_remove_rounded, color: Colors.white70),
                                      onPressed: () => _removeFriend(f),
                                    ),
                                  ]),
                                ),
                            ]),
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      CandyButton(
                        label: 'Add a friend',
                        icon: Icons.person_add_alt_1_rounded,
                        candy: Candy.blue,
                        height: 52,
                        onTap: () => _addFriend(context),
                      ),
                    ]),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addFriend(BuildContext context) async {
    final ctrl = TextEditingController();
    final code = await showCandyDialog<String>(
      context,
      title: 'Add friend',
      ribbon: Candy.blue,
      builder: (ctx) => Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: ctrl,
          textCapitalization: TextCapitalization.characters,
          textAlign: TextAlign.center,
          style: AppText.display(24, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: 'FRIEND CODE',
            filled: true,
            fillColor: const Color(0xFFF3EAFF),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 12),
        CandyButton(label: 'Add', candy: Candy.green, height: 56, onTap: () => Navigator.pop(ctx, ctrl.text.trim())),
      ]),
    );
    if (code == null || code.isEmpty || !context.mounted) return;
    try {
      await context.services.api.addFriend(code.toUpperCase());
      if (context.mounted) toast(context, 'Friend added!', icon: Icons.favorite_rounded);
      _reloadFriends();
    } on ApiException catch (e) {
      if (context.mounted) toast(context, e.isOffline ? 'You\'re offline' : e.message, icon: Icons.error_rounded);
    }
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({this.icon, this.art, this.color, required this.value, required this.label});
  final IconData? icon;
  final ArtKind? art;
  final Color? color;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => CandyPanel(
        rim: Candy.white,
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(children: [
          if (art != null) GameArt(art!, size: 32) else Icon(icon, color: color, size: 32),
          Text(value, style: AppText.display(24, color: AppColors.ink)),
          Text(label, style: AppText.body(11, color: AppColors.inkSoft)),
        ]),
      );
}

class _GameStatRow extends StatelessWidget {
  const _GameStatRow({required this.game});
  final GameType game;

  @override
  Widget build(BuildContext context) {
    final st = context.player.data.stats[game.wire];
    final played = st?.played ?? 0, won = st?.won ?? 0;
    final best = st?.bestMs;
    final rate = played == 0 ? 0.0 : won / played;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        GameBadge(game: game, size: 36),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(game.title, style: AppText.body(14, weight: FontWeight.w700))),
              Text('$won/$played', style: AppText.body(13, color: AppColors.inkSoft, weight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: rate,
                minHeight: 8,
                color: game.candy.base,
                backgroundColor: const Color(0xFFEDE4FF),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 52,
          child: Text(best == null ? '—' : '${best ~/ 60000}:${((best ~/ 1000) % 60).toString().padLeft(2, '0')}',
              textAlign: TextAlign.right, style: AppText.display(15, color: AppColors.royal)),
        ),
      ]),
    );
  }
}
