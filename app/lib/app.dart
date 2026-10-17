import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/audio/sfx.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/palette.dart';
import 'core/ui/candy_background.dart';
import 'core/ui/pressable.dart';
import 'features/daily/daily_screen.dart';
import 'features/home/home_screen.dart';
import 'features/leaderboard/leaderboard_screen.dart';
import 'features/map/journey_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/rewards/rewards.dart';
import 'features/settings/settings_screen.dart';
import 'features/shop/shop_screen.dart';
import 'games/common/game_launcher.dart';
import 'games/common/game_type.dart';
import 'services/content_repo.dart';
import 'services/services.dart';

class PuzzleHubApp extends StatefulWidget {
  const PuzzleHubApp({super.key, required this.services});
  final AppServices services;

  @override
  State<PuzzleHubApp> createState() => _PuzzleHubAppState();
}

class _PuzzleHubAppState extends State<PuzzleHubApp> with WidgetsBindingObserver {
  late final GoRouter _router = buildRouter(widget.services);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.services.warmUp();
    // Tapping a daily reminder opens the Daily tab (warm start, or cold start once ready).
    final reminders = widget.services.reminders;
    reminders.onOpenDaily = () => _router.go('/daily');
    reminders.init().then((_) {
      if (reminders.consumeLaunchedFromReminder() && widget.services.player.data.onboarded) _router.go('/daily');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Persist and back up whenever the app goes to the background.
    if (state == AppLifecycleState.paused) {
      widget.services.player.save();
      widget.services.sync.push();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: Builder(
        builder: (context) {
          final reduce = context.player.data.settings.reducedMotion;
          return MaterialApp.router(
            title: 'Puzzle Hub',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            routerConfig: _router,
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              return MediaQuery(
                // Respect the OS setting or the in-app toggle; clamp extreme font scales so boards stay usable.
                data: mq.copyWith(
                  disableAnimations: mq.disableAnimations || reduce,
                  textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.3),
                ),
                child: child!,
              );
            },
          );
        },
      ),
    );
  }
}

GoRouter buildRouter(AppServices s) {
  final shellKey = GlobalKey<NavigatorState>();
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final onboarded = s.player.data.onboarded;
      final atOnboarding = state.matchedLocation == '/onboarding';
      if (!onboarded && !atOnboarding) return '/onboarding';
      if (onboarded && atOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      ShellRoute(
        navigatorKey: shellKey,
        builder: (context, state, child) => MainShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (_, _) => const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/journey',
            pageBuilder: (_, _) => const NoTransitionPage(child: JourneyScreen()),
          ),
          GoRoute(
            path: '/daily',
            pageBuilder: (_, _) => const NoTransitionPage(child: DailyScreen()),
          ),
          GoRoute(
            path: '/leaders',
            pageBuilder: (_, _) => const NoTransitionPage(child: LeaderboardScreen()),
          ),
          GoRoute(
            path: '/shop',
            pageBuilder: (_, _) => const NoTransitionPage(child: ShopScreen()),
          ),
        ],
      ),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
      GoRoute(path: '/spin', builder: (_, _) => const SpinScreen()),
      GoRoute(
        path: '/play/level/:n',
        builder: (_, st) {
          final n = int.tryParse(st.pathParameters['n'] ?? '') ?? 1;
          return GameLauncher(resolve: (_) async => PlayRequest.level(n));
        },
      ),
      GoRoute(
        path: '/play/daily/:game',
        builder: (_, st) {
          final g = GameType.values.byName(st.pathParameters['game']!);
          return GameLauncher(
            resolve: (svc) async {
              final set = await svc.content.daily();
              final p = set.puzzles[g];
              if (p == null) throw StateError("Today's ${g.title} puzzle isn't available. Try another game!");
              return PlayRequest(game: g, difficulty: p.difficulty, source: PlaySource.daily, seed: 0, daily: p);
            },
          );
        },
      ),
      GoRoute(
        path: '/play/quick/:game',
        builder: (_, st) {
          final g = GameType.values.byName(st.pathParameters['game']!);
          return GameLauncher(
            resolve: (svc) async {
              // Quick play scales with the player's journey progress.
              final lvl = svc.player.data.currentLevel;
              final diff = Difficulty.values[(lvl ~/ 40).clamp(0, 3)];
              return PlayRequest(
                game: g,
                difficulty: diff,
                source: PlaySource.quick,
                seed: DateTime.now().microsecondsSinceEpoch & 0x7FFFFFFF,
              );
            },
          );
        },
      ),
    ],
  );
}

/// Bottom-tab shell with a raised candy "Play" button for the Journey.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  static const _tabs = [
    ('/', Icons.home_rounded, 'Home'),
    ('/daily', Icons.today_rounded, 'Daily'),
    ('/journey', Icons.map_rounded, 'Play'),
    ('/leaders', Icons.emoji_events_rounded, 'Ranks'),
    ('/shop', Icons.storefront_rounded, 'Shop'),
  ];

  @override
  Widget build(BuildContext context) {
    final isMap = location == '/journey';
    return Scaffold(
      extendBody: true,
      body: isMap ? child : CandyBackground(child: child),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 78,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(colors: [Color(0xFF2A0B5E), Color(0xFF451092)]),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 2),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            children: [
              for (final t in _tabs)
                Expanded(
                  child: t.$1 == '/journey'
                      ? _PlayTab(selected: isMap)
                      : _Tab(icon: t.$2, label: t.$3, selected: location == t.$1, path: t.$1),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.icon, required this.label, required this.selected, required this.path});
  final IconData icon;
  final String label;
  final bool selected;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.go(path),
      sound: Sfx.tap,
      semanticLabel: label,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.18 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            child: Icon(
              icon,
              color: selected ? AppColors.gold : Colors.white60,
              size: 28,
              shadows: selected ? const [Shadow(color: Color(0xFFE08A00), offset: Offset(0, 2))] : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppText.body(11, color: selected ? Colors.white : Colors.white60, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _PlayTab extends StatelessWidget {
  const _PlayTab({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => context.go('/journey'),
      sound: Sfx.pop,
      semanticLabel: 'Journey',
      child: OverflowBox(
        maxHeight: 110,
        child: Transform.translate(
          offset: const Offset(0, -16),
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.5),
                colors: [Candy.green.light, Candy.green.base, Candy.green.dark],
              ),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(color: Candy.green.dark, offset: const Offset(0, 5)),
                BoxShadow(color: Candy.green.base.withValues(alpha: selected ? 0.8 : 0.3), blurRadius: 18),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 46,
              shadows: [Shadow(color: Color(0xFF0E8A45), offset: Offset(0, 2))],
            ),
          ),
        ),
      ),
    );
  }
}
