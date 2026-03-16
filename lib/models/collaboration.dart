import 'package:app/models/event.dart';

class Collaboration {
  String id;
  String title;
  List<String> leads;
  List<String> members;
  Event? linkedEvent;
  DateTime createdAt;

  // toolData stores arbitrary per-tool state, e.g. nodes and edges for flowchart/mindmap/timeline
  Map<String, dynamic> toolData;

  Collaboration({
    required this.id,
    required this.title,
    this.leads = const [],
    this.members = const [],
    this.linkedEvent,
    DateTime? createdAt,
    Map<String, dynamic>? toolData,
  })  : createdAt = createdAt ?? DateTime.now(),
        toolData = toolData ?? {};

  factory Collaboration.fromMap(Map<String, dynamic> map) {
    final tools = map['toolData'] ?? map['tools'] ?? <String, dynamic>{};
    
    // Check for flattened data from backend and merge into tools
    if (map['mindmapData'] != null) tools['mindmapData'] = map['mindmapData'];
    if (map['flowchartData'] != null) tools['flowchartData'] = map['flowchartData'];

    // Timeline data can arrive under multiple keys depending on backend version
    if (map['timelineData'] != null) tools['timelineData'] = map['timelineData'];
    if (map['timeline_data'] != null) tools['timelineData'] = map['timeline_data'];
    if (map['timeline_milestones'] != null) tools['timeline_milestones'] = map['timeline_milestones'];

    return Collaboration(
      id: map['id'] ?? '',
      title: map['title'] ?? 'Untitled',
      leads: (map['leads'] as List?)?.cast<String>() ?? (map['ownerId'] != null ? [map['ownerId']] : []),
      members: (map['members'] as List?)?.cast<String>() ?? (map['activeUsers'] as List?)?.cast<String>() ?? [],
      createdAt: map['createdAt'] != null ? DateTime.tryParse(map['createdAt'].toString()) : null,
      toolData: tools,
    );
  }
}
