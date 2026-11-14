class SupportTopic {
  const SupportTopic({required this.id, required this.title, required this.body});

  final String id;
  final String title;
  final String body;

  factory SupportTopic.fromJson(Map<String, dynamic> json) => SupportTopic(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'body': body};
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.author,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String author;
  final String body;
  final DateTime createdAt;

  factory SupportMessage.fromJson(Map<String, dynamic> json) => SupportMessage(
        id: json['id'] as String,
        author: json['author'] as String? ?? 'you',
        body: json['body'] as String? ?? '',
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'body': body,
        'created_at': createdAt.toIso8601String(),
      };
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.category,
    required this.status,
    required this.createdAt,
    this.bookingId,
    this.messages = const [],
  });

  final String id;
  final String subject;
  final String category;
  final String status;
  final DateTime createdAt;
  final String? bookingId;
  final List<SupportMessage> messages;

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
        id: json['id'] as String,
        subject: json['subject'] as String? ?? '',
        category: json['category'] as String? ?? 'general',
        status: json['status'] as String? ?? 'open',
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            DateTime.now(),
        bookingId: json['booking_id'] as String?,
        messages: (json['messages'] as List<dynamic>? ?? [])
            .map((m) => SupportMessage.fromJson(m as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'category': category,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'booking_id': bookingId,
        'messages': messages.map((m) => m.toJson()).toList(),
      };
}
