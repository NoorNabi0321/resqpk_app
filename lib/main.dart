import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'core/network/fcm_service.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/storage/secure_storage.dart';
import 'features/first_aid/data/first_aid_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is fully configured in Module 9 (google-services.json + options).
  // Until then, initialization is best-effort so the app still runs.
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase not configured yet (skipping): $e');
  }

  await Hive.initFlutter();

  // Register for push notifications if already logged in (best-effort).
  final savedToken = await SecureStorage.getToken();
  if (savedToken != null && savedToken.isNotEmpty) {
    await FCMService.initialize();
    FirstAidRepository().syncInBackground(); // fire-and-forget content refresh
  }

  runApp(const ProviderScope(child: ResQPKApp()));
}

class ResQPKApp extends StatelessWidget {
  const ResQPKApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ResQPK',
      debugShowCheckedModeBanner: false,
      // Dark for now, because most screens still hand-style dark surfaces.
      // Patient screens move to ResqTheme.light one at a time; the driver app
      // keeps this one for good — see Plan 3 §2.2.
      theme: ResqTheme.dark,
      routerConfig: appRouter,
    );
  }
}
