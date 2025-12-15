import 'package:flutter/material.dart';
import 'package:app/models/collaboration.dart';
import 'package:app/widgets/creative_toolbar.dart';
import 'package:app/widgets/glass_container.dart';
import 'package:app/widgets/live_cursors.dart';
import 'package:app/services/websocket_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

class TimelineScreen extends StatefulWidget {
  final Collaboration? collaboration;
  final bool canEdit;
  final Future<void> Function()? onSave;
  const TimelineScreen({super.key, this.collaboration, this.canEdit = false, this.onSave});

  @override
  State<TimelineScreen> createState() => _TimelineScreenState();
}

class _TimelineScreenState extends State<TimelineScreen> {
  final TransformationController _transformationController = TransformationController();
  final WebSocketService _ws = WebSocketService();
  late String _projectId;
  late String _myUserId;
  List<Map<String, dynamic>> _milestones = [];
  final List<String> _phases = ['Phase 1', 'Phase 2', 'Phase 3', 'Phase 4'];
  final double _laneHeight = 200.0;
  bool _isPanMode = true; // Default to Pan

  final List<Color> colors = const [
    Color(0xFFFFD700), // Gold
    Colors.white,
    Colors.redAccent,
    Colors.greenAccent,
    Colors.blueAccent,
    Colors.purpleAccent,
  ];

  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Map<String, dynamic> _sanitizeMilestone(Map<String, dynamic> m) {
    return {
      ...m,
      'id': m['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'x': _toDouble(m['x']),
      'y': _toDouble(m['y']),
      'label': m['label']?.toString() ?? 'Milestone',
      'color': (m['color'] as int?) ?? 0xFFFFD700,
      'comments': m['comments'] is List ? m['comments'] : [],
      'notes': m['notes']?.toString() ?? '',
      'assignee': m['assignee']?.toString(),
    };
  }

  @override
  void initState() {
    super.initState();
    _projectId = widget.collaboration?.id ?? 'demo_project';
    _myUserId = 'user_${DateTime.now().millisecondsSinceEpoch % 1000}';
    
    _ws.connect(_projectId, _myUserId);
    _ws.nodeStream.listen((msg) {
      if (!mounted) return;
      if (msg['type'] == 'TIMELINE_UPDATE') {
        final data = msg['data'];
        final nodeId = msg['nodeId'];
        var action = msg['action'];
        
        // Fallback: check data for action if not at top level
        if (action == null && data is Map && data['action'] != null) {
          action = data['action'];
        }

        setState(() {
          if (action == 'DELETE') {
            _milestones.removeWhere((m) => m['id'] == nodeId);
          } else {
            final idx = _milestones.indexWhere((m) => m['id'] == nodeId);
            // Don't add if it's just a command object without ID/content
            if (data is Map && (data['x'] != null || data['label'] != null)) {
               final sanitized = _sanitizeMilestone(Map<String, dynamic>.from(data));
               if (idx >= 0) {
                 _milestones[idx] = sanitized;
               } else {
                 _milestones.add(sanitized);
               }
            } else if (idx >= 0 && data is Map) {
               // Update existing partial
               final existing = _milestones[idx];
               _milestones[idx] = _sanitizeMilestone({...existing, ...Map<String, dynamic>.from(data)});
            }
          }
        });
      }
    });
    _loadMilestones();
  }

  @override
  void didUpdateWidget(TimelineScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.collaboration != oldWidget.collaboration) {
      _loadMilestones();
    }
  }

  void _loadMilestones() {
    final data = widget.collaboration?.toolData['timeline_milestones'];
    if (data is List) {
      setState(() {
        _milestones = data.map((e) {
          final m = Map<String, dynamic>.from(e);
          // If the DB has corrupted "action" objects in the list, we filter them 
          // either here or rely on sanitize to fix them.
          // Sanitize will give them a valid ID/label, making them harmless ghosts.
          // Better to filter if possible, but strict sanitization prevents crashes.
          return _sanitizeMilestone(m);
        }).toList();
      });
    }
  }

  void _save() {
    if (!widget.canEdit) return;
    if (widget.collaboration != null) {
      widget.collaboration!.toolData['timeline_milestones'] = _milestones;
    }
    widget.onSave?.call();
  }

  void _syncMilestone(Map<String, dynamic> m) {
    _ws.sendNodeUpdate(_projectId, 'TIMELINE_UPDATE', m['id'], {
      ...m,
      'action': 'UPDATE'
    });
  }

  void _addMilestoneDefault() {
    if (!widget.canEdit) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newMilestone = {
      'id': id,
      'x': 0.0,
      'y': 0.0,
      'label': 'New Milestone',
      'color': 0xFFFFD700,
      'comments': [],
      'notes': '',
      'assignee': null,
    };
    setState(() {
      _milestones.add(newMilestone);
      _save();
    });
    _ws.sendNodeUpdate(_projectId, 'TIMELINE_UPDATE', id, {
      ...newMilestone,
      'action': 'ADD'
    });
  }

  void _changeMilestoneColor(Map<String, dynamic> milestone) async {
    if (!widget.canEdit) return;
    final Color? picked = await showDialog<Color>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Pick Color'),
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            children: colors.map((c) => GestureDetector(
              onTap: () => Navigator.pop(context, c),
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: Colors.grey)),
              ),
            )).toList(),
          ),
        ],
      ),
    );
    if (picked != null) {
      setState(() {
        milestone['color'] = picked.value;
        _save();
      });
      _syncMilestone(milestone);
    }
  }

  void _assignUser(Map<String, dynamic> milestone) async {
    if (!widget.canEdit) return;
    final users = ['Alice', 'Bob', 'Charlie', 'Dave', 'Eve'];
    final picked = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Assign To'),
        children: users.map((u) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, u),
          child: Row(children: [
            CircleAvatar(radius: 12, backgroundColor: Colors.blueGrey, child: Text(u[0], style: const TextStyle(fontSize: 10, color: Colors.white))),
            const SizedBox(width: 10),
            Text(u),
          ]),
        )).toList(),
      ),
    );
    if (picked != null) {
      setState(() {
        milestone['assignee'] = picked;
        _save();
      });
      _syncMilestone(milestone);
    }
  }

  void _editMilestoneLabel(Map<String, dynamic> milestone) async {
    if (!widget.canEdit) return;
    final newLabel = await showDialog<String>(
      context: context,
      builder: (_) => _NodeEditDialog(initialLabel: milestone['label']),
    );
    if (newLabel != null && newLabel.isNotEmpty) {
      setState(() {
        milestone['label'] = newLabel;
        _save();
      });
      _syncMilestone(milestone);
    }
  }

  void _deleteMilestone(Map<String, dynamic> milestone) {
    if (!widget.canEdit) return;
    setState(() {
      _milestones.remove(milestone);
      _save();
      widget.onSave?.call();
    });
    _ws.sendNodeUpdate(_projectId, 'TIMELINE_UPDATE', milestone['id'], {'action': 'DELETE'});
  }

  void _showCommentsDialog(Map<String, dynamic> milestone) {
    showDialog(
      context: context,
      builder: (_) => _CommentsDialog(
        milestoneLabel: milestone['label'],
        initialComments: List<String>.from(milestone['comments'] ?? []),
        canEdit: widget.canEdit,
        onCommentsChanged: (newComments) {
          setState(() {
            milestone['comments'] = newComments;
            _save();
          });
          _syncMilestone(milestone);
        },
      ),
    );
  }

  void _editNotes(Map<String, dynamic> milestone) async {
    if (!widget.canEdit) return;
    final newNotes = await showDialog<String>(
      context: context,
      builder: (_) => _NotesDialog(initialNotes: milestone['notes'] ?? ''),
    );
    if (newNotes != null) {
      setState(() {
        milestone['notes'] = newNotes;
        _save();
      });
      _syncMilestone(milestone);
    }
  }

  void _showEditOptions(Map<String, dynamic> milestone) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename'),
            onTap: () {
              Navigator.pop(context);
              _editMilestoneLabel(milestone);
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text('Assign User'),
            onTap: () {
              Navigator.pop(context);
              _assignUser(milestone);
            },
          ),
          ListTile(
            leading: const Icon(Icons.comment),
            title: const Text('Comments'),
            onTap: () {
              Navigator.pop(context);
              _showCommentsDialog(milestone);
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Notes/Attachments'),
            onTap: () {
              Navigator.pop(context);
              _editNotes(milestone);
            },
          ),
          ListTile(
            leading: const Icon(Icons.color_lens),
            title: const Text('Change Color'),
            onTap: () {
              Navigator.pop(context);
              _changeMilestoneColor(milestone);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _deleteMilestone(milestone);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: widget.canEdit
          ? FloatingActionButton(
              onPressed: _addMilestoneDefault,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          CreativeToolbar(
            title: 'Timeline 2D',
            iconPath: 'assets/svg/timeline_custom.svg',
            canEdit: widget.canEdit,
            activeUsers: const ['Alice', 'Bob', 'Charlie'],
            isPanMode: _isPanMode,
            onModeChanged: (v) => setState(() => _isPanMode = v),
            onSave: _save,
            onZoomIn: () {
              _transformationController.value = _transformationController.value.scaled(1.2);
            },
            onZoomOut: () {
              _transformationController.value = _transformationController.value.scaled(0.8);
            },
            onResetView: () {
               final size = MediaQuery.of(context).size;
               final x = size.width / 2 - 25000;
               final y = size.height / 2 - 25000;
               _transformationController.value = Matrix4.identity()..translate(x, y);
            },
            extraActions: [
               IconButton(
                  icon: SvgPicture.asset(
                    'assets/svg/clear_custom.svg',
                    width: 24,
                    height: 24,
                    colorFilter: ColorFilter.mode(Colors.red.shade600, BlendMode.srcIn),
                  ),
                  tooltip: 'Clear All',
                  onPressed: widget.canEdit 
                    ? () {
                       showDialog(
                         context: context,
                         builder: (ctx) => AlertDialog(
                           title: const Text('Clear Timeline'),
                           content: const Text('Delete all milestones?'),
                           actions: [
                             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                             ElevatedButton(
                               onPressed: () {
                                 Navigator.pop(ctx);
                                 setState(() {
                                   _milestones.clear();
                                   _save();
                                 });
                               }, 
                               child: const Text('Clear')
                             ),
                           ],
                         ),
                       );
                    }
                    : null,
               ),
            ],
          ),
          Expanded(
            child: Stack(
              children: [
                LiveCursors(
                  cursorStream: null,
                  myUserId: null,
                  child: InteractiveViewer(
                    transformationController: _transformationController,
                    boundaryMargin: const EdgeInsets.all(20000),
                    minScale: 0.1,
                    maxScale: 5.0,
                    constrained: false,
                    panEnabled: _isPanMode,
                    child: Stack(
                      children: [
                        // Infinite Canvas Background/Grid
                        SizedBox(
                          width: 50000,
                          height: 50000,
                          child: CustomPaint(
                            painter: _TimelinePainter(
                              milestones: _milestones,
                              colorScheme: Theme.of(context).colorScheme,
                              phases: _phases,
                              laneHeight: _laneHeight,
                            ),
                          ),
                        ),
                        // Milestones
                        ..._milestones.map(_buildMilestone),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMilestone(Map<String, dynamic> m) {
    // Center of the large canvas
    const double centerX = 25000;
    const double centerY = 25000;
    
    final double x = _toDouble(m['x']) + centerX;
    final double y = _toDouble(m['y']) + centerY;
    
    const double dotSize = 20.0;
    final Color color = Color((m['color'] as int?) ?? 0xFFFFD700);
    final bool hasComments = (m['comments'] as List?)?.isNotEmpty ?? false;
    final bool hasNotes = (m['notes'] as String?)?.isNotEmpty ?? false;
    final String? assignee = m['assignee'];

    return Positioned(
      left: x - dotSize / 2,
      top: y - dotSize / 2,
      child: IgnorePointer(
        ignoring: widget.canEdit ? _isPanMode : false, // In read-only, gestures might just be click, but pan mode is for canvas moving.
        child: GestureDetector(
          onTap: () => _showEditOptions(m),
        onPanUpdate: (details) {
          if (!widget.canEdit) return;
          setState(() {
            m['x'] = _toDouble(m['x']) + details.delta.dx / _transformationController.value.getMaxScaleOnAxis();
            m['y'] = _toDouble(m['y']) + details.delta.dy / _transformationController.value.getMaxScaleOnAxis();
          });
        },
        onPanEnd: (_) {
           _save();
           _syncMilestone(m);
        },
        child: MouseRegion(
          cursor: widget.canEdit ? SystemMouseCursors.click : SystemMouseCursors.basic,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dot with Comment Indicator & Assignee
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.6),
                          blurRadius: 10,
                          spreadRadius: 2,
                        )
                      ],
                    ),
                  ),
                  if (hasComments)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.comment, size: 8, color: Colors.white),
                      ),
                    ),
                  if (assignee != null)
                    Positioned(
                      left: -12,
                      top: -12,
                      child: Tooltip(
                        message: 'Assigned to $assignee',
                        child: CircleAvatar(
                          radius: 8,
                          backgroundColor: Colors.blueGrey,
                          child: Text(assignee[0], style: const TextStyle(fontSize: 8, color: Colors.white)),
                        ),
                      ),
                    ),
                  if (hasNotes)
                    Positioned(
                      left: -6,
                      bottom: -6,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.description, size: 8, color: Colors.white),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              GlassContainer(
                borderRadius: BorderRadius.circular(8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.black54,
                child: Text(
                  m['label'],
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  final List<Map<String, dynamic>> milestones;
  final ColorScheme colorScheme;
  final List<String> phases;
  final double laneHeight;

  _TimelinePainter({
    required this.milestones,
    required this.colorScheme,
    required this.phases,
    required this.laneHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double centerX = 25000;
    const double centerY = 25000;

    // Draw Swimlanes (Phases)
    final lanePaint = Paint()
      ..style = PaintingStyle.fill;
      
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
    );

    // Draw lanes centered vertically around centerY
    // Let's say we stack them: Phase 1 (top) to Phase 4 (bottom)
    // Total height = phases.length * laneHeight
    // Start Y = centerY - (totalHeight / 2)
    final double totalHeight = phases.length * laneHeight;
    final double startY = centerY - (totalHeight / 2);

    for (int i = 0; i < phases.length; i++) {
      final double y = startY + (i * laneHeight);
      final bool isEven = i % 2 == 0;
      
      // Background band
      lanePaint.color = isEven 
          ? colorScheme.surfaceContainerHighest.withOpacity(0.3) 
          : colorScheme.surface.withOpacity(0.1);
          
      // Draw infinite horizontal band
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, laneHeight), lanePaint);
      
      // Draw Label (repeated every 1000px for visibility)
      textPainter.text = TextSpan(
        text: phases[i].toUpperCase(),
        style: TextStyle(
          color: colorScheme.onSurface.withOpacity(0.2),
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      );
      textPainter.layout();
      
      // Draw labels periodically
      for (double lx = centerX - 2000; lx < centerX + 2000; lx += 800) {
         textPainter.paint(canvas, Offset(lx, y + 20));
      }
      
      // Separator line
      canvas.drawLine(
        Offset(0, y + laneHeight),
        Offset(size.width, y + laneHeight),
        Paint()..color = colorScheme.outlineVariant.withOpacity(0.2)..strokeWidth = 1,
      );
    }

    final paint = Paint()
      ..color = colorScheme.primary
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    final glowPaint = Paint()
      ..color = colorScheme.secondary.withOpacity(0.3)
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    final p1 = Offset(0, centerY);
    final p2 = Offset(size.width, centerY);

    canvas.drawLine(p1, p2, glowPaint);
    canvas.drawLine(p1, p2, paint);

    // Draw vertical connectors
    final connectorPaint = Paint()
      ..color = colorScheme.secondary.withOpacity(0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    for (var m in milestones) {
      final double x = ((m['x'] as num?)?.toDouble() ?? 0.0) + centerX;
      final double y = ((m['y'] as num?)?.toDouble() ?? 0.0) + centerY;

      // Draw line from axis (x, centerY) to milestone (x, y)
      canvas.drawLine(Offset(x, centerY), Offset(x, y), connectorPaint);
      
      // Draw a small dot on the axis
      canvas.drawCircle(Offset(x, centerY), 4, Paint()..color = colorScheme.secondary);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter oldDelegate) {
    return true; 
  }
}

class _NodeEditDialog extends StatelessWidget {
  final String initialLabel;
  const _NodeEditDialog({required this.initialLabel});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: initialLabel);
    return AlertDialog(
      title: const Text('Edit Label'),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'New Label'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _CommentsDialog extends StatefulWidget {
  final String milestoneLabel;
  final List<String> initialComments;
  final bool canEdit;
  final ValueChanged<List<String>> onCommentsChanged;

  const _CommentsDialog({
    required this.milestoneLabel,
    required this.initialComments,
    required this.canEdit,
    required this.onCommentsChanged,
  });

  @override
  State<_CommentsDialog> createState() => _CommentsDialogState();
}

class _CommentsDialogState extends State<_CommentsDialog> {
  late List<String> _comments;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _comments = widget.initialComments;
  }

  void _addComment() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _comments.add(_controller.text.trim());
      _controller.clear();
    });
    widget.onCommentsChanged(_comments);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Comments (${widget.milestoneLabel})'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          children: [
            Expanded(
              child: _comments.isEmpty
                  ? const Center(child: Text('No comments yet.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                      itemCount: _comments.length,
                      itemBuilder: (context, index) => ListTile(
                        leading: const CircleAvatar(radius: 10, child: Icon(Icons.person, size: 12)),
                        title: Text(_comments[index]),
                        dense: true,
                      ),
                    ),
            ),
            if (widget.canEdit)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(hintText: 'Add a comment...'),
                        onSubmitted: (_) => _addComment(),
                      ),
                    ),
                    IconButton(onPressed: _addComment, icon: const Icon(Icons.send)),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
      ],
    );
  }
}

class _NotesDialog extends StatelessWidget {
  final String initialNotes;
  const _NotesDialog({required this.initialNotes});

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: initialNotes);
    return AlertDialog(
      title: const Text('Notes & Attachments'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(
            hintText: 'Enter detailed notes, paste links, or reference attachments here...',
            border: OutlineInputBorder(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}