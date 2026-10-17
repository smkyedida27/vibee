import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/audio/sfx.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/palette.dart';
import 'core/ui/phone_frame.dart';
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
import 'games/common/game_flow.dart';
import 'games/common/game_launcher.dart';
import 'games/common/results_overlay.dart';
import 'games/common/game_type.dart';
import 'services/content_repo.dart';
import 'services/services.dart';

class QuintileApp extends StatefulWidget {
  const QuintileApp({super.key, required this.services});
  final AppServices services;

  @override
  State<QuintileApp> createState() => _QuintileAppState();
}

class _QuintileAppState extends State<QuintileApp> with WidgetsBindingObserver {
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
            title: 'Quintile',
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
                child: PhoneFrame(child: child!),
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
      GoRoute(path: '/onboarding', pageBuilder: (_, st) => _page(st, const OnboardingScreen())),
      ShellRoute(
        navigatorKey: shellKey,
        builder: (context, state, child) => MainShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/', pageBuilder: (_, st) => _tabPage(st, const HomeScreen())),
          GoRoute(path: '/journey', pageBuilder: (_, st) => _tabPage(st, const JourneyScreen())),
          GoRoute(path: '/daily', pageBuilder: (_, st) => _tabPage(st, const DailyScreen())),
          GoRoute(path: '/leaders', pageBuilder: (_, st) => _tabPage(st, const LeaderboardScreen())),
          GoRoute(path: '/shop', pageBuilder: (_, st) => _tabPage(st, const ShopScreen())),
        ],
      ),
      GoRoute(path: '/profile', pageBuilder: (_, st) => _page(st, const ProfileScreen())),
      GoRoute(path: '/settings', pageBuilder: (_, st) => _page(st, const SettingsScreen())),
      GoRoute(path: '/spin', pageBuilder: (_, st) => _page(st, const SpinScreen())),
      // Design-review only (`--dart-define=PREVIEW=true`); never part of a normal build.
      if (const bool.fromEnvironment('PREVIEW'))
        GoRoute(path: '/preview/results', builder: (_, _) => const _ResultsPreview()),
      GoRoute(
        path: '/play/level/:n',
        pageBuilder: (_, st) {
          final n = int.tryParse(st.pathParameters['n'] ?? '') ?? 1;
          return _page(st, GameLauncher(resolve: (_) async => PlayRequest.level(n)));
        },
      ),
      GoRoute(
        path: '/play/daily/:game',
        pageBuilder: (_, st) {
          final g = GameType.values.byName(st.pathParameters['game']!);
          return _page(
            st,
            GameLauncher(
              resolve: (svc) async {
                final set = await svc.content.daily();
                final p = set.puzzles[g];
                if (p == null) throw StateError("Today's ${g.title} puzzle isn't available. Try another game!");
                return PlayRequest(game: g, difficulty: p.difficulty, source: PlaySource.daily, seed: 0, daily: p);
              },
            ),
          );
        },
      ),
      GoRoute(
        path: '/play/quick/:game',
        pageBuilder: (_, st) {
          final g = GameType.values.byName(st.pathParameters['game']!);
          return _page(
            st,
            GameLauncher(
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
            ),
          );
        },
      ),
    ],
  );
}

/// Pushed screens: a quick fade with a slight rise, smooth on low-end phones.
CustomTransitionPage<void> _page(GoRouterState st, Widget child) => CustomTransitionPage<void>(
  key: st.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 320),
  reverseTransitionDuration: const Duration(milliseconds: 240),
  transitionsBuilder: (context, anim, _, child) {
    final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  },
);

/// Bottom tabs cross-fade instead of cutting.
CustomTransitionPage<void> _tabPage(GoRouterState st, Widget child) => CustomTransitionPage<void>(
  key: st.pageKey,
  child: child,
  transitionDuration: const Duration(milliseconds: 220),
  reverseTransitionDuration: const Duration(milliseconds: 220),
  transitionsBuilder: (context, anim, _, child) => FadeTransition(
    opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
    child: child,
  ),
);

/// Bottom-tab shell: a clean white tab bar with a raised primary "Play" button.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  static const _tabs = [
    ('/', Icons.home_rounded, 'Home'),
    ('/daily', Icons.calendar_today_rounded, 'Daily'),
    ('/journey', Icons.play_arrow_rounded, 'Play'),
    ('/leaders', Icons.leaderboard_rounded, 'Ranks'),
    ('/shop', Icons.shopping_bag_rounded, 'Shop'),
  ];

  @override
  Widget build(BuildContext context) {
    final isMap = location == '/journey';
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: child,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
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
    final color = selected ? AppColors.primary : AppColors.inkFaint;
    return Pressable(
      onTap: () => context.go(path),
      sound: Sfx.tap,
      semanticLabel: label,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
            decoration: BoxDecoration(
              color: selected ? Candy.gold.light : Colors.transparent,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 23),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: AppText.body(11, color: color, weight: selected ? FontWeight.w700 : FontWeight.w600),
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
      child: Center(
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: selected ? 0.45 : 0.28),
                blurRadius: selected ? 16 : 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
        ),
      ),
    );
  }
}

class _ResultsPreview extends StatefulWidget {
  const _ResultsPreview();
  @override
  State<_ResultsPreview> createState() => _ResultsPreviewState();
}

class _ResultsPreviewState extends State<_ResultsPreview> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showResults(
        context,
        request: PlayRequest(game: GameType.connect, difficulty: Difficulty.medium, source: PlaySource.daily, seed: 1),
        result: RoundResult(won: true, stars: 3, submission: const {}, detail: 'Perfect — no mistakes!'),
        elapsed: const Duration(minutes: 1, seconds: 42),
        hintsUsed: 0,
        dailyCoins: 60,
        xpGained: 60,
      );
    });
  }

  @override
  Widget build(BuildContext context) => const Scaffold(backgroundColor: AppColors.bg);
}
