import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mordechaius_maximus/core/agent_intent.dart';
import 'package:mordechaius_maximus/data/local/launch_presets_store.dart';
import 'package:mordechaius_maximus/data/models/launch_preset.dart';

void main() {
  test('LaunchPreset round-trip JSON', () {
    final a = LaunchPreset.create(
      name: 'My preset',
      repoUrl: 'https://github.com/o/r',
      branch: 'main',
      prompt: 'hello',
      intent: AgentIntent.plan,
      model: 'auto',
      autoCreatePr: true,
      useDesktop: false,
    );
    final b = LaunchPreset.fromJson(a.toJson());
    expect(b.id, a.id);
    expect(b.name, a.name);
    expect(b.repoUrl, a.repoUrl);
    expect(b.branch, a.branch);
    expect(b.prompt, a.prompt);
    expect(b.intent, AgentIntent.plan);
    expect(b.model, a.model);
    expect(b.autoCreatePr, true);
    expect(b.useDesktop, false);
  });

  test('LaunchPresetsStore load and save', () async {
    final dir = await Directory.systemTemp.createTemp('mm_presets_');
    final file = File('${dir.path}/launch_presets.json');
    final store = LaunchPresetsStore.forFile(file);

    expect(await store.load(), isEmpty);

    final p = LaunchPreset.create(
      name: 'A',
      repoUrl: 'https://github.com/a/b',
      branch: '',
      prompt: 'x',
      intent: AgentIntent.normal,
      model: 'claude-4-sonnet',
      autoCreatePr: false,
      useDesktop: true,
    );
    await store.save([p]);

    final store2 = LaunchPresetsStore.forFile(file);
    final list = await store2.load();
    expect(list.length, 1);
    expect(list.first.id, p.id);
    expect(list.first.model, 'claude-4-sonnet');
    await dir.delete(recursive: true);
  });

  test('LaunchPreset copyWith updates timestamps', () {
    final a = LaunchPreset.create(
      name: 'N',
      repoUrl: 'https://github.com/x/y',
      branch: 'b',
      prompt: 'p',
      intent: AgentIntent.debug,
      model: 'auto',
      autoCreatePr: false,
      useDesktop: true,
    );
    final b = a.copyWith(name: 'N2');
    expect(b.name, 'N2');
    expect(b.id, a.id);
    expect(b.updatedAtMs >= a.updatedAtMs, isTrue);
  });
}
