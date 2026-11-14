class Paged<T> {
  const Paged({required this.results, required this.count, required this.next});

  final List<T> results;
  final int count;
  final bool next;

  factory Paged.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      Paged(
        results: (json['results'] as List<dynamic>? ?? [])
            .map((e) => fromJson(e as Map<String, dynamic>))
            .toList(),
        count: (json['count'] as num?)?.toInt() ?? 0,
        next: json['next'] != null,
      );
}
