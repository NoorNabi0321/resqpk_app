/// Preset one-tap messages exchanged between hospital and driver.
/// Text lives on the backend (constants/quick.messages.js) and is fetched via
/// GET /api/decisions/constants, so both apps stay in sync automatically.
class QuickMessage {
  final String key;
  final String text;
  final String role; // 'hospital' | 'driver' — who may SEND it

  const QuickMessage({required this.key, required this.text, required this.role});

  factory QuickMessage.fromJson(Map<String, dynamic> json) {
    return QuickMessage(
      key: json['key']?.toString() ?? '',
      text: json['text']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'key': key, 'text': text, 'role': role};
}

/// One line in a case's message feed.
class CaseMessage {
  final String senderRole; // 'hospital' | 'driver'
  final String messageKey;
  final String messageText;
  final DateTime? createdAt;

  const CaseMessage({
    required this.senderRole,
    required this.messageKey,
    required this.messageText,
    this.createdAt,
  });

  bool get isFromHospital => senderRole == 'hospital';

  factory CaseMessage.fromJson(Map<String, dynamic> json) {
    // Accepts both the REST row (snake_case) and the socket payload (camelCase).
    final created = json['created_at'] ?? json['createdAt'] ?? json['timestamp'];
    return CaseMessage(
      senderRole: (json['sender_role'] ?? json['senderRole'] ?? '').toString(),
      messageKey: (json['message_key'] ?? json['messageKey'] ?? '').toString(),
      messageText: (json['message_text'] ?? json['messageText'] ?? '').toString(),
      createdAt: created == null ? null : DateTime.tryParse(created.toString()),
    );
  }
}
