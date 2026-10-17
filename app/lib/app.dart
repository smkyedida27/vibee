import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/audio/sfx.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/palette.dart';
import 'core/ui/candy_background.dart';
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

/// Bottom-tab shell: the animated world behind every tab and a glossy royal-navy tab bar
/// with a raised green "Play" jewel.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  static const _tabs = [
    ('/', Icons.home_rounded, 'Home'),
    ('/daily', Icons.calendar_month_rounded, 'Daily'),
    ('/journey', Icons.play_arrow_rounded, 'Play'),
    ('/leaders', Icons.emoji_events_rounded, 'Ranks'),
    ('/shop', Icons.storefront_rounded, 'Shop'),
  ];

  @override
  Widget build(BuildContext context) {
    final isMap = location == '/journey';
    return Scaffold(
      extendBody: true,
      body: CandyBackground(child: child),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          height: 76,
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF4A6BDB), Color(0xFF2E4BB8), Color(0xFF223C9E)],
            ),
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: const [
              BoxShadow(color: Color(0xFF172873), offset: Offset(0, 5)),
              BoxShadow(color: Color(0x66172873), blurRadius: 18, offset: Offset(0, 10)),
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
            scale: selected ? 1.2 : 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.elasticOut,
            child: Icon(
              icon,
              color: selected ? AppColors.gold : Colors.white70,
              size: 28,
              shadows: selected ? const [Shadow(color: Color(0xFFC77800), offset: Offset(0, 2))] : null,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppText.body(11, color: selected ? Colors.white : Colors.white70, weight: FontWeight.w700),
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
          offset: const Offset(0, -18),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.3, -0.5),
                colors: [Candy.green.light, Candy.green.base, Candy.green.dark],
              ),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(color: Candy.green.dark, offset: const Offset(0, 5)),
                BoxShadow(color: Candy.green.base.withValues(alpha: selected ? 0.8 : 0.35), blurRadius: 18),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              color: Colors.white,
              size: 48,
              shadows: [Shadow(color: Color(0xFF16810C), offset: Offset(0, 2))],
            ),
          ),
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
