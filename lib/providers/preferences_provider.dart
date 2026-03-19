import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/local/preferences_service.dart';

final preferencesProvider = FutureProvider<PreferencesService>((ref) async {
  return PreferencesService.create();
});
