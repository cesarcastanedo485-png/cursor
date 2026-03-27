import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/launch_preset.dart';

const int _kFileFormatVersion = 1;

/// Persists launch presets as JSON under app documents.
class LaunchPresetsStore {
  LaunchPresetsStore._(this._file);

  final File _file;

  /// Production store in application documents.
  static Future<LaunchPresetsStore> create() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'launch_presets.json'));
    return LaunchPresetsStore._(file);
  }

  /// Tests and tooling.
  factory LaunchPresetsStore.forFile(File file) => LaunchPresetsStore._(file);

  Future<List<LaunchPreset>> load() async {
    if (!await _file.exists()) return [];
    try {
      final text = await _file.readAsString();
      final decoded = jsonDecode(text) as Map<String, dynamic>;
      final ver = decoded['version'] as int? ?? 0;
      if (ver != _kFileFormatVersion) return [];
      final list = decoded['presets'] as List<dynamic>? ?? [];
      return list
          .map((e) => LaunchPreset.fromJson(e as Map<String, dynamic>))
          .where((p) => p.id.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<LaunchPreset> presets) async {
    final dir = _file.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    final map = <String, dynamic>{
      'version': _kFileFormatVersion,
      'presets': presets.map((e) => e.toJson()).toList(),
    };
    await _file.writeAsString(jsonEncode(map));
  }
}
