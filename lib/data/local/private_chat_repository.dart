import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// All private-AI messages in one append-only log (cross-AI memory).
class PrivateChatEntry {
  PrivateChatEntry({
    required this.aiId,
    required this.role,
    required this.content,
    required this.ts,
    this.mediaNote,
  });

  final String aiId;
  final String role;
  final String content;
  final int ts;
  final String? mediaNote;

  Map<String, dynamic> toJson() => {
        'aiId': aiId,
        'role': role,
        'content': content,
        'ts': ts,
        if (mediaNote != null) 'mediaNote': mediaNote,
      };

  static PrivateChatEntry fromJson(Map<String, dynamic> j) => PrivateChatEntry(
        aiId: j['aiId'] as String? ?? '',
        role: j['role'] as String? ?? 'user',
        content: j['content'] as String? ?? '',
        ts: j['ts'] as int? ?? 0,
        mediaNote: j['mediaNote'] as String?,
      );
}

class PrivateChatRepository {
  PrivateChatRepository(this._box);

  final Box<String> _box;
  static const _key = '_mm_all_private_messages';

  List<PrivateChatEntry> _load() {
    final raw = _box.get(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => PrivateChatEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<PrivateChatEntry> all) async {
    await _box.put(_key, jsonEncode(all.map((e) => e.toJson()).toList()));
  }

  /// Messages visible in this AI's thread (its own + optional global memory injection at API layer).
  List<PrivateChatEntry> threadForAi(String aiId) {
    return _load().where((e) => e.aiId == aiId).toList();
  }

  Future<void> append({
    required String aiId,
    required String role,
    required String content,
    String? mediaNote,
  }) async {
    final all = _load();
    all.add(PrivateChatEntry(
      aiId: aiId,
      role: role,
      content: content,
      ts: DateTime.now().millisecondsSinceEpoch,
      mediaNote: mediaNote,
    ));
    await _save(all);
  }

  /// Recent context from *other* AIs for the model (trimmed).
  String globalMemoryExcerpt(String currentAiId, {int maxChars = 6000}) {
    final all = _load()
        .where((e) => e.aiId != currentAiId)
        .toList()
      ..sort((a, b) => b.ts.compareTo(a.ts));
    final buf = StringBuffer();
    for (final e in all) {
      if (buf.length >= maxChars) break;
      buf.writeln('[${e.aiId} / ${e.role}] ${e.content}');
    }
    final s = buf.toString();
    if (s.length > maxChars) return s.substring(0, maxChars);
    return s.isEmpty ? '(no prior cross-AI messages)' : s;
  }

  Future<void> clearThread(String aiId) async {
    final all = _load().where((e) => e.aiId != aiId).toList();
    await _save(all);
  }
}
