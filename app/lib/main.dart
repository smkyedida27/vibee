import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/palette.dart';
import 'core/ui/phone_frame.dart';
import 'features/splash/splash_screen.dart';
import 'services/firebase_setup.dart';
import 'services/services.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        FirebaseSetup.recordFlutterError(details);
      };
      // Draw the branded splash on the very first frame; start services behind it.
      runApp(const _Boot());
    },
    (error, stack) {
      debugPrint('Uncaught: $error\n$stack');
      FirebaseSetup.recordError(error, stack);
    },
  );
}

/// Shows the animated splash while Firebase and app services start, then cross-fades
/// into the app. The splash stays up long enough to play its intro, never longer than needed.
class _Boot extends StatefulWidget {
  const _Boot();

  @override
  State<_Boot> createState() => _BootState();
}

class _BootState extends State<_Boot> {
  AppServices? _services;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    if (_error != null) setState(() => _error = null);
    try {
      final minSplash = Future<void>.delayed(const Duration(milliseconds: 1500));
      await FirebaseSetup.init();
      final services = await AppServices.create();
      await minSplash;
      if (mounted) setState(() => _services = services);
    } catch (e, st) {
      FirebaseSetup.recordError(e, st);
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _services;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 600),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(scale: Tween(begin: 1.04, end: 1.0).animate(anim), child: child),
      ),
      child: s != null
          ? QuintileApp(key: const ValueKey('app'), services: s)
          : MaterialApp(
              key: const ValueKey('splash'),
              debugShowCheckedModeBanner: false,
              theme: buildAppTheme(),
              builder: (context, child) => PhoneFrame(child: child!),
              home: _error == null ? const SplashScreen() : _BootError(onRetry: _start),
            ),
    );
  }
}

class _BootError extends StatelessWidget {
  const _BootError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Something went wrong starting the game.', style: AppText.body(16)),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
