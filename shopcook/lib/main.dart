import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show timeDilation;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/crash_reporter.dart';
import 'core/settings.dart';
import 'core/supabase_config.dart';

/// Development only: `--dart-define=SLOWMO=5` plays every animation five
/// times slower, so motion can be checked frame by frame on a device. It is
/// a compile-time constant, so an ordinary build carries none of it.
const _slowMo = int.fromEnvironment('SLOWMO');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_slowMo > 1) timeDilation = _slowMo.toDouble();
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );
  await CrashReporter.install();

  // Loaded before the first frame so the app opens in the user's chosen
  // theme instead of rendering the default and then snapping to it.
  final preferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
      child: const ShopCookApp(),
    ),
  );
}
