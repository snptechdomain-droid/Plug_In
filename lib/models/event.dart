class Event {
  final String? id;
  final String title;
  final DateTime date;
  final String description;
  final String venue;
  final bool isPublic;
  final String? createdBy;
  final String? eventCoordinator;
  final bool registrationStarted;
  final String? imageUrl;
  final List<EventRegistration> registrations;

  Event({
    this.id,
    required this.title,
    required this.date,
    required this.description,
    this.venue = 'TBD',
    this.isPublic = true,
    this.createdBy,
    this.eventCoordinator,
    this.registrationStarted = false,
    this.imageUrl,
    this.registrations = const [],
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      title: json['title'],
      date: json['date'] != null ? DateTime.parse(json['date']) : DateTime.now(),
      description: json['description'],
      venue: json['venue'] ?? 'TBD',
      isPublic: json['public'] ?? true, 
      createdBy: json['createdBy'],
      eventCoordinator: json['eventCoordinator'],
      registrationStarted: json['registrationStarted'] ?? false,
      imageUrl: json['imageUrl'],
      registrations: (json['registrations'] as List<dynamic>?)
              ?.map((e) => EventRegistration.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'description': description,
      'venue': venue,
      'public': isPublic,
      'createdBy': createdBy,
      'eventCoordinator': eventCoordinator,
      'registrationStarted': registrationStarted,
      'imageUrl': imageUrl,
    };
  }
}

class EventRegistration {
  final String name;
  final String phoneNumber;
  final String email;
  final String registerNumber;
  final String studentClass;
  final String year;
  final String department;

  EventRegistration({
    required this.name,
    required this.phoneNumber,
    required this.email,
    required this.registerNumber,
    required this.studentClass,
    required this.year,
    required this.department,
  });

  factory EventRegistration.fromJson(Map<String, dynamic> json) {
    return EventRegistration(
      name: json['name'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      email: json['email'] ?? '',
      registerNumber: json['registerNumber'] ?? '',
      studentClass: json['studentClass'] ?? '',
      year: json['year'] ?? '',
      department: json['department'] ?? '',
    );
  }
}
