/// Single message in agent conversation (GET /v0/agents/:id/conversation).
class ConversationMessage {
  const ConversationMessage({
    required this.role,
    required this.content,
    this.timestamp,
  });

  final String role; // "user" | "assistant"
  final String content;
  final DateTime? timestamp;

  factory ConversationMessage.fromJson(Map<String, dynamic> json) {
    return ConversationMessage(
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? json['text'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'] as String)
          : null,
    );
  }

  bool get isUser => role.toLowerCase() == 'user';
}

/// Conversation response (list of messages).
class Conversation {
  const Conversation({required this.messages});

  final List<ConversationMessage> messages;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final list = json['messages'] as List<dynamic>? ?? json['conversation'] as List<dynamic>? ?? [];
    return Conversation(
      messages: list
          .map((e) => ConversationMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  factory Conversation.fromList(List<dynamic> list) {
    return Conversation(
      messages: list
          .map((e) => ConversationMessage.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
