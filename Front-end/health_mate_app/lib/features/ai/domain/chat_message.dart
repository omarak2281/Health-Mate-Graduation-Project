class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? type; // 'text', 'options', 'diagnosis'
  final List<String>? options;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.type = 'text',
    this.options,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      text: json['text']?.toString() ?? '',
      isUser: json['is_user'] == true,
      timestamp: DateTime.now(),
      type: json['type']?.toString() ?? 'text',
      options: json['options'] != null
          ? List<String>.from(json['options'].map((e) => e.toString()))
          : null,
    );
  }
}
