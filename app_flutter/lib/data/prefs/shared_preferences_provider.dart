import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in main() with the instance loaded before runApp, so reads
/// are synchronous and the first frame already has the saved values.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override in main()'),
);
