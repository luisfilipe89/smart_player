class Event {
  final String title;
  final String dateTime;
  final String location;
  final String cost;
  final String targetGroup;
  final bool isRecurring;
  final String? imageUrl;
  final String? url;

  Event({
    required this.title,
    required this.dateTime,
    required this.location,
    required this.cost,
    required this.targetGroup,
    required this.url,
    required this.isRecurring,
    this.imageUrl,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    final String rawDateTime = json['date_time'] ?? '';

    final bool inferredRecurring =
        !(rawDateTime.toLowerCase().contains('1x op') ||
            rawDateTime.toLowerCase().contains('contact op na inschrijving'));

    return Event(
      title: json['title'] ?? '',
      dateTime: rawDateTime,
      location: json['location'] ?? '',
      cost: json['cost'] ?? '',
      targetGroup: json['target_group'] ?? '',
      url: json['url'] ?? '',
      imageUrl: json['imageUrl'],
      isRecurring: json['isRecurring'] ??
          inferredRecurring, // fallback to inferred if missing
    );
  }
}
