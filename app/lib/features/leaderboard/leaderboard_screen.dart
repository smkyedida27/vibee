import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/audio/sfx.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/palette.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/hud.dart';
import '../../core/ui/pressable.dart';
import '../../games/common/game_type.dart';
import '../../services/api_client.dart';
import '../../services/services.dart';
import '../shop/shop_sheets.dart';

class LeaderEntry {
  LeaderEntry({
    required this.rank,
    required this.userId,
    required this.name,
    required this.avatar,
    required this.score,
    this.me = false,
  });
  final int rank;
  final String userId;
  final String name;
  final int avatar;
  final int score;
  final bool me;

  static LeaderEntry fromJson(Map<String, dynamic> j, String? myId) => LeaderEntry(
    rank: (j['rank'] as num).toInt(),
    userId: '${j['userId']}',
    name: (j['displayName'] ?? 'Player') as String,
    avatar: (j['avatarId'] as num?)?.toInt() ?? 0,
    score: (j['score'] as num?)?.toInt() ?? 0,
    me: '${j['userId']}' == myId,
  );
}

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});
  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _period = 'daily';
  String _scope = 'GLOBAL';
  GameType? _game;
  late Future<(List<LeaderEntry>, LeaderEntry?)> _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _data = _load();
  }

  Future<(List<LeaderEntry>, LeaderEntry?)> _load() async {
    final api = context.services.api;
    final j = await api.leaderboard(period: _period, scope: _scope, gameType: _period == 'daily' ? _game?.wire : null);
    final list = ((j['entries'] ?? j['items'] ?? []) as List)
        .map((e) => LeaderEntry.fromJson((e as Map).cast<String, dynamic>(), api.userId))
        .toList();
    final meJson = j['me'] as Map<String, dynamic>?;
    return (list, meJson == null ? null : LeaderEntry.fromJson(meJson, api.userId));
  }

  void _reload() => setState(() => _data = _load());

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          TopHud(onAvatar: () => context.push('/profile'), onHearts: () => showOutOfLives(context, browsing: true)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('RANKINGS', style: AppText.label(11)),
                  const SizedBox(height: 4),
                  Text('Leaderboard', style: AppText.display(30)),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: _Segmented(
              values: const {'daily': 'Today', 'weekly': 'This Week'},
              selected: _period,
              onChanged: (v) {
                _period = v;
                _reload();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _Segmented(
              values: const {'FRIENDS': 'Friends', 'GLOBAL': 'Global', 'COUNTRY': 'Country'},
              selected: _scope,
              small: true,
              onChanged: (v) {
                _scope = v;
                _reload();
              },
            ),
          ),
          if (_period == 'daily')
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                children: [
                  _GameChip(
                    label: 'Overall',
                    selected: _game == null,
                    onTap: () {
                      _game = null;
                      _reload();
                    },
                  ),
                  for (final g in GameType.values)
                    _GameChip(
                      label: g.title,
                      candy: g.candy,
                      selected: _game == g,
                      onTap: () {
                        _game = g;
                        _reload();
                      },
                    ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<(List<LeaderEntry>, LeaderEntry?)>(
              future: _data,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3));
                }
                if (snap.hasError) {
                  final offline = snap.error is ApiException && (snap.error as ApiException).isOffline;
                  return _Empty(
                    icon: offline ? Icons.cloud_off_rounded : Icons.error_outline_rounded,
                    title: offline ? 'You\'re offline' : 'Couldn\'t load rankings',
                    message: offline ? 'Connect to the internet to see how you rank.' : 'Please try again in a moment.',
                    onRetry: _reload,
                  );
                }
                final (list, me) = snap.data!;
                if (list.isEmpty) {
                  return _Empty(
                    icon: _scope == 'FRIENDS' ? Icons.group_add_rounded : Icons.emoji_events_rounded,
                    title: _scope == 'FRIENDS' ? 'No friends yet' : 'Be the first!',
                    message: _scope == 'FRIENDS'
                        ? 'Share your friend code from your profile and compete together.'
                        : 'Solve today\'s puzzles to claim the top spot.',
                    onRetry: _scope == 'FRIENDS' ? () => context.push('/profile') : () => context.go('/daily'),
                    retryLabel: _scope == 'FRIENDS' ? 'Add friends' : 'Play daily',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 130),
                    children: [
                      _Podium(top: list.take(3).toList()),
                      const SizedBox(height: 16),
                      for (final e in list.skip(3)) _Row(e: e),
                      if (me != null && !list.any((e) => e.me)) ...[
                        const SizedBox(height: 4),
                        const Center(child: Icon(Icons.more_vert_rounded, color: AppColors.inkFaint)),
                        const SizedBox(height: 4),
                        _Row(e: me),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({required this.values, required this.selected, required this.onChanged, this.small = false});
  final Map<String, String> values;
  final String selected;
  final ValueChanged<String> onChanged;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: small ? 40 : 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (final e in values.entries)
            Expanded(
              child: Pressable(
                onTap: () => onChanged(e.key),
                sound: Sfx.tap,
                semanticLabel: e.value,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: selected == e.key ? AppColors.surface : null,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: selected == e.key ? AppColors.cardShadow : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    e.value,
                    style: AppText.body(
                      small ? 13 : 14,
                      color: selected == e.key ? AppColors.ink : AppColors.inkSoft,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GameChip extends StatelessWidget {
  const _GameChip({required this.label, required this.selected, required this.onTap, this.candy = Candy.purple});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Candy candy;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? candy.base : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? candy.base : AppColors.border),
        ),
        child: Text(
          label,
          style: AppText.body(13, color: selected ? candy.on : AppColors.inkSoft, weight: FontWeight.w700),
        ),
      ),
    ),
  );
}

/// Subtle medal accents for the top three.
class _Medal {
  const _Medal(this.color, this.tint);
  final Color color;
  final Color tint;

  static const gold = _Medal(AppColors.gold, Color(0xFFFBF0D6));
  static const silver = _Medal(Color(0xFF9AA1AC), Color(0xFFF0F1F3));
  static const bronze = _Medal(Color(0xFFC07A45), Color(0xFFF8ECE2));

  static _Medal? of(int rank) => switch (rank) {
    1 => gold,
    2 => silver,
    3 => bronze,
    _ => null,
  };
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top});
  final List<LeaderEntry> top;

  @override
  Widget build(BuildContext context) {
    LeaderEntry? at(int i) => i < top.length ? top[i] : null;
    return Container(
      height: 236,
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: AppColors.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: _Pillar(e: at(1), height: 72, medal: _Medal.silver, place: 2),
          ),
          Expanded(
            child: _Pillar(e: at(0), height: 100, medal: _Medal.gold, place: 1),
          ),
          Expanded(
            child: _Pillar(e: at(2), height: 56, medal: _Medal.bronze, place: 3),
          ),
        ],
      ),
    );
  }
}

class _Pillar extends StatelessWidget {
  const _Pillar({required this.e, required this.height, required this.medal, required this.place});
  final LeaderEntry? e;
  final double height;
  final _Medal medal;
  final int place;

  @override
  Widget build(BuildContext context) {
    if (e == null) return const SizedBox.shrink();
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.all(2.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: medal.color, width: 2),
          ),
          child: Avatar(index: e!.avatar, size: place == 1 ? 56 : 46),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            e!.me ? 'You' : e!.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.body(13, weight: FontWeight.w700),
          ),
        ),
        Text('${e!.score}', style: AppText.display(15, color: AppColors.inkSoft)),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: height),
          duration: Duration(milliseconds: 450 + place * 80),
          curve: Curves.easeOutCubic,
          builder: (_, h, _) => Container(
            height: h,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: medal.tint,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            alignment: Alignment.topCenter,
            padding: const EdgeInsets.only(top: 8),
            child: h < 36 ? null : Text('$place', style: AppText.display(24, color: medal.color)),
          ),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.e});
  final LeaderEntry e;

  @override
  Widget build(BuildContext context) {
    final medal = _Medal.of(e.rank);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: e.me ? const Color(0xFFFBF0D6) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: e.me ? AppColors.primary.withValues(alpha: 0.35) : AppColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${e.rank}',
              style: AppText.display(15, color: medal?.color ?? (e.me ? AppColors.primary : AppColors.inkSoft)),
            ),
          ),
          Avatar(index: e.avatar, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              e.me ? '${e.name} (You)' : e.name,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(15, color: e.me ? AppColors.primary : AppColors.ink, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Text('${e.score}', style: AppText.display(16)),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Retry',
  });
  final IconData icon;
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.surface, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.inkFaint, size: 36),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: AppText.display(22)),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.body(15, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 24),
          CandyButton(label: retryLabel, candy: Candy.ink, width: 220, height: 52, onTap: onRetry),
        ],
      ),
    ),
  );
}
