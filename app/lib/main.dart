import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/firebase_setup.dart';
import 'services/services.dart';

Future<void> main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          systemNavigationBarColor: Color(0xFF1A0838),
        ),
      );
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        FirebaseSetup.recordFlutterError(details);
      };
      await FirebaseSetup.init();
      final services = await AppServices.create();
      runApp(PuzzleHubApp(services: services));
    },
    (error, stack) {
      debugPrint('Uncaught: $error\n$stack');
      FirebaseSetup.recordError(error, stack);
    },
  );
}
