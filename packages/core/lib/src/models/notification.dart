class ZNotification {
  const ZNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.readAt,
    this.data,
  });

  final String id;
  final String title;
  final String body;
  final String type;
  final DateTime createdAt;
  final DateTime? readAt;
  final Map<String, dynamic>? data;

  bool get isUnread => readAt == null;

  factory ZNotification.fromJson(Map<String, dynamic> json) => ZNotification(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        type: json['type'] as String? ?? 'system',
        createdAt: DateTime.tryParse((json['created_at'] as String?) ?? '') ??
            DateTime.now(),
        readAt: json['read_at'] == null
            ? null
            : DateTime.tryParse(json['read_at'] as String),
        data: (json['data'] as Map<String, dynamic>?),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'type': type,
        'created_at': createdAt.toIso8601String(),
        'read_at': readAt?.toIso8601String(),
        'data': data,
      };
}
