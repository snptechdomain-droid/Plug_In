import 'dart:ui' show Tangent, PathMetric, PathMetrics; // for PathMetric.getTangentForOffset
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vec; // for Vector3
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/models/collaboration.dart';
import 'package:app/widgets/glass_container.dart';
import 'package:app/widgets/creative_toolbar.dart';
import 'package:app/widgets/live_cursors.dart';
import 'package:app/widgets/minimap.dart';
import 'package:app/services/websocket_service.dart';

class FlowchartScreen extends StatefulWidget {
  final Collaboration? collaboration;
  final bool canEdit;
  final Future<void> Function()? onSave;
  const FlowchartScreen({super.key, this.collaboration, this.canEdit = false, this.onSave});

  @override
  State<FlowchartScreen> createState() => _FlowchartScreenState();
}

/// Backward-compatible node model with extras for mind-map connections.
enum FlowShape { rectangle, pill, diamond, circle, triangle, parallelogram }
enum ConnectionStyle { curved, orthogonal, straight }

class FlowNode {
  String id;
  double x;
  double y;
  String label;
  String? parentId;
  int colorValue;
  FlowShape shape;

  FlowNode({
    required this.id,
    required this.x,
    required this.y,
    required this.label,
    this.parentId,
    this.colorValue = 0xFFFFF176,
    this.shape = FlowShape.rectangle,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'x': x,
        'y': y,
        'label': label,
        'parentId': parentId,
        'color': colorValue,
        'shape': shape.index,
      };

  static FlowNode fromMap(Map<String, dynamic> map) => FlowNode(
        id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        x: (map['x'] as num?)?.toDouble() ?? 0.0,
        y: (map['y'] as num?)?.toDouble() ?? 0.0,
        label: (map['label'] ?? '').toString(),
        parentId: map['parentId']?.toString(),
        colorValue: (map['color'] is int)
            ? map['color']
            : (map['color'] is num)
                ? (map['color'] as num).toInt()
                : 0xFFFFF176,
        shape: (map['shape'] is int && map['shape'] >= 0 && map['shape'] < FlowShape.values.length) 
            ? FlowShape.values[map['shape']] 
            : FlowShape.rectangle,
      );
}

class FlowAnnotation {
  String id;
  double x;
  double y;
  String text;
  double width;
  double height;

  FlowAnnotation({
    required this.id,
    required this.x,
    required this.y,
    required this.text,
    this.width = 200,
    this.height = 150,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'x': x,
        'y': y,
        'text': text,
        'width': width,
        'height': height,
      };

  static FlowAnnotation fromMap(Map<String, dynamic> map) => FlowAnnotation(
        id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        x: (map['x'] as num?)?.toDouble() ?? 0.0,
        y: (map['y'] as num?)?.toDouble() ?? 0.0,
        text: (map['text'] ?? '').toString(),
        width: (map['width'] as num?)?.toDouble() ?? 200.0,
        height: (map['height'] as num?)?.toDouble() ?? 150.0,
      );
}

class FlowConnection {
  String id;
  String fromId;
  String toId;
  String? label;

  FlowConnection({
    required this.id,
    required this.fromId,
    required this.toId,
    this.label,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'fromId': fromId,
        'toId': toId,
        'label': label,
      };

  factory FlowConnection.fromMap(Map<String, dynamic> map) {
    return FlowConnection(
      id: map['id']?.toString() ?? '',
      fromId: map['fromId']?.toString() ?? '',
      toId: map['toId']?.toString() ?? '',
      label: map['label']?.toString(),
    );
  }
}

class _FlowchartScreenState extends State<FlowchartScreen> {
  final TransformationController _transformCtrl = TransformationController();
  final GlobalKey _viewerKey = GlobalKey();
  final WebSocketService _ws = WebSocketService();
  
  // State
  List<FlowNode> _nodes = [];
  List<FlowConnection> _connections = [];
  List<FlowAnnotation> _annotations = [];
  
  late String _projectId;
  late String _myUserId;
  
  // Interaction Mode
  bool _isPanMode = true; // Default to Pan for better mobile UX

  // Interaction
  String? _selectedId;
  String? _linkingFromId;
  Offset? _linkingToPoint;
  Offset? _tempEnd; // For temporary link visualization
  bool _isInteractingWithHandle = false;
  
  // Settings
  bool _snapToGrid = true;
  bool _showGrid = true;
  double _grid = 20.0;
  Size _nodeSize = const Size(160, 80);
  final EdgeInsets _nodePadding = const EdgeInsets.all(8);
  
  // Connection Settings
  ConnectionStyle _style = ConnectionStyle.curved;
  bool _dashedLine = false;

  final List<Color> _palette = [
    const Color(0xFFFFF176), // Yellow
    const Color(0xFF81C784), // Green
    const Color(0xFF64B5F6), // Blue
    const Color(0xFFE57373), // Red
    const Color(0xFFBA68C8), // Purple
    const Color(0xFFFFB74D), // Orange
  ];

  @override
  void initState() {
    super.initState();
    _projectId = widget.collaboration?.id ?? 'demo_project';
    _myUserId = 'user_${DateTime.now().millisecondsSinceEpoch % 1000}';
    _ws.connect(_projectId, _myUserId);
    
    // Listen for node updates
    _ws.nodeStream.listen((msg) {
       if (!mounted) return;
       final type = msg['type'];
       final nodeId = msg['nodeId'];
       final data = msg['data'];
       
       setState(() {
         if (type == 'ADD' || type == 'UPDATE') {
            final idx = _nodes.indexWhere((n) => n.id == nodeId);
            final newNode = FlowNode.fromMap(data);
            if (idx >= 0) {
              _nodes[idx] = newNode;
            } else {
              _nodes.add(newNode);
            }
         } else if (type == 'DELETE') {
            _nodes.removeWhere((n) => n.id == nodeId);
            _connections.removeWhere((c) => c.fromId == nodeId || c.toId == nodeId);
         } else if (type == 'CONNECTION_ADD') {
            final newConn = FlowConnection.fromMap(data);
            if (!_connections.any((c) => c.id == newConn.id)) {
               _connections.add(newConn);
            }
         }
       });
    });

    _loadData();
  }

  @override
  void dispose() {
    _ws.disconnect();
    _transformCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    // Load nodes
    final nodeData = widget.collaboration?.toolData['flowchart_nodes'];
    if (nodeData is List) {
      _nodes = nodeData.map((e) => FlowNode.fromMap(e)).toList();
    }
    
    // Load annotations
    final noteData = widget.collaboration?.toolData['flowchart_annotations'];
    if (noteData is List) {
      _annotations = noteData.map((e) => FlowAnnotation.fromMap(e)).toList();
    }

    // Load connections
    final connData = widget.collaboration?.toolData['flowchart_connections'];
    if (connData is List) {
      for (final raw in connData) {
        try {
          _connections.add(FlowConnection.fromMap(Map<String, dynamic>.from(raw)));
        } catch (_) {}
      }
    } else {
      // Migration: Create connections from parentId if no explicit connections exist
      for (final n in _nodes) {
        if (n.parentId != null) {
          _connections.add(FlowConnection(
            id: 'migrated_${n.id}',
            fromId: n.parentId!,
            toId: n.id,
          ));
        }
      }
    }

    // Migration: Shift nodes to center if they are near 0,0 (Legacy coordinates)
    if (_nodes.isNotEmpty) {
      double sumX = 0;
      double sumY = 0;
      for (final n in _nodes) {
        sumX += n.x;
        sumY += n.y;
      }
      final avgX = sumX / _nodes.length;
      final avgY = sumY / _nodes.length;

      // If average position is far from center (e.g. < 10000), shift them
      if (avgX < 10000 && avgY < 10000) {
        final double offsetX = 25000.0 - avgX;
        final double offsetY = 25000.0 - avgY;
        
        for (final n in _nodes) {
          n.x += offsetX;
          n.y += offsetY;
        }
        for (final a in _annotations) {
          a.x += offsetX;
          a.y += offsetY;
        }
        _save(); // Save the migrated positions
      }
    }
    
    // Center View
    WidgetsBinding.instance.addPostFrameCallback((_) {
       if (!mounted) return;
       final size = MediaQuery.of(context).size;
       final x = size.width / 2 - 25000;
       final y = size.height / 2 - 25000;
       _transformCtrl.value = Matrix4.identity()..translate(x, y);
    });
  }

  // ========================= SAVE =========================
  void _save() {
    if (!widget.canEdit) return;
    if (widget.collaboration != null) {
      widget.collaboration!.toolData['flowchart_nodes'] =
          _nodes.map((n) => n.toMap()).toList();
      widget.collaboration!.toolData['flowchart_annotations'] =
          _annotations.map((n) => n.toMap()).toList();
      widget.collaboration!.toolData['flowchart_connections'] =
          _connections.map((c) => c.toMap()).toList();
    }
    widget.onSave?.call();
  }

  // ========================= HELPERS =========================
  Offset _snap(Offset p) {
    if (!_snapToGrid) return p;
    double rx = (p.dx / _grid).roundToDouble() * _grid;
    double ry = (p.dy / _grid).roundToDouble() * _grid;
    return Offset(rx, ry);
  }

  Offset _sceneFromGlobal(Offset global) {
    final RenderBox? box =
        _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return global;
    final Offset local = box.globalToLocal(global);
    return _transformCtrl.toScene(local);
  }

  void _addNodeAt(Offset scenePos, {String? parentId}) {
    final color = _palette[_nodes.length % _palette.length];
    Offset pos = _snap(scenePos);
    
    // Prevent exact overlap: shift down if occupied
    int attempts = 0;
    while (_nodes.any((n) => (n.x - pos.dx).abs() < 10 && (n.y - pos.dy).abs() < 10) && attempts < 20) {
       pos = Offset(pos.dx, pos.dy + _nodeSize.height + 20);
       attempts++;
    }

    final newNodeId = DateTime.now().millisecondsSinceEpoch.toString();
    
    setState(() {
      final newNode = FlowNode(
        id: newNodeId,
        x: pos.dx,
        y: pos.dy,
        label: 'Node ${_nodes.length + 1}',
        parentId: parentId,
        colorValue: color.value,
      );
      _nodes.add(newNode);
      _save();
      
      // Send Update
      _ws.sendNodeUpdate(_projectId, 'ADD', newNodeId, newNode.toMap());
      
      if (parentId != null) {
        final newConn = FlowConnection(
          id: 'conn_$newNodeId',
          fromId: parentId,
          toId: newNodeId,
        );
        _connections.add(newConn);
        _ws.sendNodeUpdate(_projectId, 'CONNECTION_ADD', newConn.id, newConn.toMap());
      }
    });
  }

  void _deleteNode(String id) {
    setState(() {
      final FlowNode? me = _nodes
          .cast<FlowNode?>()
          .firstWhere((n) => n?.id == id, orElse: () => null);
      final parentId = me?.parentId;
      // Remove connections involving this node
      _connections.removeWhere((c) => c.fromId == id || c.toId == id);
      
      _nodes.removeWhere((n) => n.id == id);
      if (_selectedId == id) _selectedId = null;
      _save();
      widget.onSave?.call();
    });
  }

  Future<void> _renameNode(FlowNode n) async {
    final controller = TextEditingController(text: n.label);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename node'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Node label'),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Save')),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) {
      setState(() => n.label = value);
    }
  }

  Future<void> _editConnectionLabel(FlowConnection c) async {
    final controller = TextEditingController(text: c.label);
    final newLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Connection Label'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter label'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    
    if (newLabel != null) {
      setState(() {
        c.label = newLabel;
        _save();
      });
    }
  }

  Future<void> _changeNodeShape(FlowNode n) async {
    final FlowShape? picked = await showDialog<FlowShape>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Pick Shape'),
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _ShapeOption(icon: Icons.crop_square, label: 'Rect', value: FlowShape.rectangle, onTap: () => Navigator.pop(ctx, FlowShape.rectangle)),
              _ShapeOption(icon: Icons.horizontal_rule, label: 'Pill', value: FlowShape.pill, onTap: () => Navigator.pop(ctx, FlowShape.pill)),
              _ShapeOption(icon: Icons.change_history, label: 'Diamond', value: FlowShape.diamond, onTap: () => Navigator.pop(ctx, FlowShape.diamond)),
              _ShapeOption(icon: Icons.circle_outlined, label: 'Circle', value: FlowShape.circle, onTap: () => Navigator.pop(ctx, FlowShape.circle)),
              _ShapeOption(icon: Icons.details, label: 'Triangle', value: FlowShape.triangle, onTap: () => Navigator.pop(ctx, FlowShape.triangle)),
              _ShapeOption(icon: Icons.check_box_outline_blank, label: 'Parallel', value: FlowShape.parallelogram, onTap: () => Navigator.pop(ctx, FlowShape.parallelogram)),
            ],
          ),
        ],
      ),
    );

    if (picked != null) {
      setState(() {
        n.shape = picked;
        _save();
      });
    }
  }

  void _showNodeMenu(Offset position, FlowNode n) async {
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(position.dx, position.dy, position.dx, position.dy),
      items: [
        const PopupMenuItem(
            value: 'add_child',
            child: ListTile(
                leading: Icon(Icons.add_circle_outline),
                title: Text('Add child'))),
        const PopupMenuItem(
            value: 'rename',
            child: ListTile(
                leading: Icon(Icons.edit_outlined), title: Text('Rename'))),
        const PopupMenuItem(
            value: 'shape',
            child: ListTile(
                leading: Icon(Icons.category), title: Text('Change Shape'))),
        const PopupMenuItem(
            value: 'delete',
            child:
                ListTile(leading: Icon(Icons.delete_outline), title: Text('Delete'))),
      ],
    );
    switch (selected) {
      case 'add_child':
        if (!widget.canEdit) return;
        _addNodeAt(Offset(n.x + _nodeSize.width + 120, n.y), parentId: n.id);
        break;
      case 'rename':
        if (!widget.canEdit) return;
        _renameNode(n);
        break;
      case 'shape':
        if (!widget.canEdit) return;
        _changeNodeShape(n);
        break;
      case 'delete':
        if (!widget.canEdit) return;
        _deleteNode(n.id);
        break;
      default:
        break;
    }
  }

  void _addNodeDefault() {
    if (!widget.canEdit) return;
    // Add to center of the virtual canvas or a safe spot
    double newX = 25000;
    double newY = 25000;
    
    if (_nodes.isNotEmpty) {
      newX = _nodes.last.x + 50;
      newY = _nodes.last.y + 50;
    }

    _addNodeAt(Offset(newX, newY));
  }

  void _addAnnotationDefault() {
    if (!widget.canEdit) return;
    setState(() {
      _annotations.add(FlowAnnotation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        x: _nodes.isNotEmpty ? _nodes.last.x + 200 : 100,
        y: _nodes.isNotEmpty ? _nodes.last.y : 100,
        text: 'New Note',
      ));
      _save();
    });
  }

  void _updateAnnotation(FlowAnnotation note, String newText) {
    setState(() {
      note.text = newText;
      _save();
    });
  }

  void _deleteAnnotation(FlowAnnotation note) {
    setState(() {
      _annotations.remove(note);
      _save();
      widget.onSave?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: widget.canEdit
          ? FloatingActionButton(
              onPressed: _addNodeDefault,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              foregroundColor: Theme.of(context).colorScheme.onSecondary,
              child: const Icon(Icons.add),
            )
          : null,
      body: Stack(
        children: [
          // Canvas Area
          Positioned.fill(
            child: LiveCursors(
              cursorStream: _ws.cursorStream,
              myUserId: _myUserId,
              child: InteractiveViewer(
                key: _viewerKey,
                transformationController: _transformCtrl,
                boundaryMargin: const EdgeInsets.all(20000),
                minScale: 0.1,
                maxScale: 5.0,
                constrained: false,
                panEnabled: _isPanMode, // Controlled by toolbar
                onInteractionUpdate: (details) {
                   setState(() {}); // For Minimap sync
                   if (details.pointerCount == 1) {
                      final scene = _sceneFromGlobal(details.focalPoint);
                      _ws.sendCursorMove(_projectId, _myUserId, scene.dx, scene.dy, '#FF0000');
                   }
                },
                child: Stack(
                  children: [
                    // Grid & Connections Painter
                    CustomPaint(
                      size: const Size(50000, 50000),
                      painter: _ConnectionsPainter(
                        nodes: _nodes,
                        connections: _connections,
                        linkingFromId: _linkingFromId,
                        linkingToPoint: _linkingToPoint,
                        selectedId: _selectedId,
                        nodeSize: _nodeSize,
                        showGrid: _showGrid,
                        grid: _grid,
                        style: _style,
                        dashed: _dashedLine,
                        showArrows: true,
                        viewportSize: MediaQuery.of(context).size,
                        transform: _transformCtrl.value,
                      ),
                    ),
                    // Connection Hit Targets
                    if (widget.canEdit)
                      ..._connections.expand((c) {
                         final fromIndex = _nodes.indexWhere((n) => n.id == c.fromId);
                         final toIndex = _nodes.indexWhere((n) => n.id == c.toId);
                         
                         if (fromIndex == -1 || toIndex == -1) return const <Widget>[];
                         
                         final from = _nodes[fromIndex];
                         final to = _nodes[toIndex];
                         final midX = (from.x + to.x + _nodeSize.width) / 2;
                         final midY = (from.y + to.y + _nodeSize.height) / 2;
                         
                         return [Positioned(
                           left: midX - 15,
                           top: midY - 15,
                           child: GestureDetector(
                             onTap: () => _editConnectionLabel(c),
                             child: Container(
                               width: 30,
                               height: 30,
                               decoration: BoxDecoration(
                                 color: Colors.transparent, 
                                 shape: BoxShape.circle,
                                 border: Border.all(color: Colors.transparent),
                               ),
                             ),
                           ),
                         )];
                      }),
                    // Nodes & Annotations
                    ..._nodes.map(_buildPositionedNode),
                    ..._annotations.map(_buildPositionedAnnotation),
                  ],
                ),
              ),
            ),
          ),
          
          // Toolbar Overlay
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    elevation: 4,
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: CreativeToolbar(
                      title: 'Flowchart',
                      iconPath: 'assets/svg/flowchart_custom.svg',
                      canEdit: widget.canEdit,
                      activeUsers: const ['Alice', 'Bob', 'Charlie'],
                      isPanMode: _isPanMode,
                      onModeChanged: (v) => setState(() => _isPanMode = v),
                      onSave: _save,
                  showGrid: _showGrid,
                  onGridChanged: (v) => setState(() => _showGrid = v),
                  showSnap: _snapToGrid,
                  onSnapChanged: (v) => setState(() => _snapToGrid = v),
                  onZoomIn: () {
                     _transformCtrl.value = _transformCtrl.value.scaled(1.2);
                     setState(() {});
                  },
                  onZoomOut: () {
                     _transformCtrl.value = _transformCtrl.value.scaled(0.8);
                     setState(() {});
                  },
                  onResetView: () {
                     final size = MediaQuery.of(context).size;
                     final x = size.width / 2 - 25000;
                     final y = size.height / 2 - 25000;
                     _transformCtrl.value = Matrix4.identity()..translate(x, y);
                     setState(() {});
                  },
                  extraActions: [
                    DropdownButton<ConnectionStyle>(
                      value: _style,
                      dropdownColor: Theme.of(context).cardColor,
                      underline: const SizedBox(),
                      onChanged: (v) => setState(() => _style = v ?? _style),
                      items: const [
                        DropdownMenuItem(
                          value: ConnectionStyle.orthogonal,
                          child: Text('Orthogonal', style: TextStyle(fontSize: 12)),
                        ),
                        DropdownMenuItem(
                          value: ConnectionStyle.curved,
                          child: Text('Curved', style: TextStyle(fontSize: 12)),
                        ),
                        DropdownMenuItem(
                          value: ConnectionStyle.straight,
                          child: Text('Straight', style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(_dashedLine ? Icons.more_horiz : Icons.remove, size: 20),
                      tooltip: 'Toggle Dashed Line',
                      onPressed: () => setState(() => _dashedLine = !_dashedLine),
                    ),
                    IconButton(
                      icon: const Icon(Icons.note_add, size: 20),
                      tooltip: 'Add Sticky Note',
                      onPressed: _addAnnotationDefault,
                    ),
                    const VerticalDivider(width: 20),
                    IconButton(
                      icon: SvgPicture.asset(
                        'assets/svg/clear_custom.svg',
                        width: 24,
                        height: 24,
                        colorFilter: ColorFilter.mode(Colors.red.shade600, BlendMode.srcIn),
                      ),
                      tooltip: 'Clear All',
                      onPressed: () {
                         showDialog(
                           context: context,
                           builder: (ctx) => AlertDialog(
                             title: const Text('Clear Flowchart'),
                             content: const Text('Delete all nodes, connections, and notes?'),
                             actions: [
                               TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                               ElevatedButton(
                                 onPressed: () {
                                   Navigator.pop(ctx);
                                   setState(() {
                                     _nodes.clear();
                                     _connections.clear();
                                     _annotations.clear();
                                     _selectedId = null;
                                     _linkingFromId = null;
                                     _save();
                                   });
                                 }, 
                                 child: const Text('Clear')
                               ),
                             ],
                           ),
                         );
                      },
                    ),
                  ],
                ),
              ),
              _instructionBar(),
            ],
          ),
        ),
      ),

          // Minimap Overlay
          Positioned(
            right: 20,
            bottom: 20,
            child: Minimap(
              items: _nodes.map((n) => MinimapItem(
                x: n.x,
                y: n.y,
                width: _nodeSize.width,
                height: _nodeSize.height,
                color: Color(n.colorValue),
              )).toList(),
              viewTransform: _transformCtrl.value,
              viewportSize: MediaQuery.of(context).size,
              onViewChanged: (matrix) {
                setState(() {
                  _transformCtrl.value = matrix;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionBar() {
    final linking = _linkingFromId != null;
    return Container(
      width: double.infinity,
      color: linking ? Colors.orange.shade50 : Colors.blueGrey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        linking
            ? 'Link mode: tap a target node or tap canvas to cancel.'
            : 'Tap + to add node • Drag to pan • Tap node to edit',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontWeight: FontWeight.w600, color: Colors.blueGrey[800]),
      ),
    );
  }

  Widget _buildPositionedNode(FlowNode n) {
    return Positioned(
      left: n.x,
      top: n.y,
      child: IgnorePointer(
        ignoring: _isPanMode, // Ignore touches in Pan Mode so they pass to InteractiveViewer
        child: _buildDraggableNode(n),
      ),
    );
  }

  Widget _buildPositionedAnnotation(FlowAnnotation n) {
    return Positioned(
      left: n.x,
      top: n.y,
      width: n.width,
      height: n.height,
      child: GestureDetector(
        onPanUpdate: widget.canEdit ? (d) {
          setState(() {
             n.x += d.delta.dx / _transformCtrl.value.getMaxScaleOnAxis();
             n.y += d.delta.dy / _transformCtrl.value.getMaxScaleOnAxis();
          });
        } : null,
        onPanEnd: (_) => _save(),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFF9C4),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(2, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 20,
                    color: const Color(0xFFFFF59D),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (widget.canEdit)
                          GestureDetector(
                            onTap: () => _deleteAnnotation(n),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Icon(Icons.close, size: 14, color: Colors.brown),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: TextEditingController(text: n.text)..selection = TextSelection.collapsed(offset: n.text.length),
                        maxLines: null,
                        expands: true,
                        decoration: const InputDecoration.collapsed(hintText: 'Enter text...'),
                        style: const TextStyle(fontFamily: 'Kalam', fontSize: 16, color: Colors.black87),
                        onChanged: (v) {
                           n.text = v;
                        },
                        onSubmitted: (_) => _save(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (widget.canEdit)
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    setState(() {
                      n.width = (n.width + d.delta.dx).clamp(100.0, 500.0);
                      n.height = (n.height + d.delta.dy).clamp(100.0, 500.0);
                    });
                  },
                  onPanEnd: (_) => _save(),
                  child: const Icon(Icons.drag_handle, size: 16, color: Colors.brown),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDraggableNode(FlowNode n) {
    final bool selected = _selectedId == n.id;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: () {
            if (_linkingFromId != null && _linkingFromId != n.id) {
               // Finish Linking
               final fromNode = _nodes.firstWhere((x) => x.id == _linkingFromId);
               setState(() {
                 _connections.add(FlowConnection(
                   id: DateTime.now().millisecondsSinceEpoch.toString(),
                   fromId: fromNode.id,
                   toId: n.id,
                 ));
                 _linkingFromId = null;
                 _tempEnd = null;
                 _save();
               });
               _ws.sendConnection(_projectId, 'ADD', _connections.last.toMap());
            } else {
               _showNodeMenu(Offset(n.x + _nodeSize.width / 2, n.y + _nodeSize.height / 2), n);
            }
          },
          onDoubleTap: widget.canEdit ? () => _renameNode(n) : null, // Double tap to Rename
          onLongPress: widget.canEdit ? () {
             // Long Press to Start Link
             setState(() {
               _linkingFromId = n.id;
               _tempEnd = Offset(n.x + _nodeSize.width/2, n.y + _nodeSize.height/2);
             });
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content: Text('Link Mode Started! Tap another node to connect.'),
                 duration: Duration(milliseconds: 1500),
               ),
             );
          } : null,
          onPanUpdate: (details) {
            if (!widget.canEdit) return;
            final matrix = _transformCtrl.value;
            final scale = matrix.getMaxScaleOnAxis();
            setState(() {
              n.x += details.delta.dx / scale;
              n.y += details.delta.dy / scale;
            });
          },
          onPanEnd: (details) {
            if (!widget.canEdit) return;
            setState(() {
              final p = _snap(Offset(n.x, n.y));
              n.x = p.dx;
              n.y = p.dy;
              _save();
              _ws.sendNodeUpdate(_projectId, 'UPDATE', n.id, n.toMap());
            });
          },
          child: _buildNodeBox(n, selected: selected),
        ),
        if (widget.canEdit)
          Positioned(
            right: -25, // Move further out for thumb access
            top: _nodeSize.height / 2 - 25, // Center vertically (50/2)
            child: GestureDetector(
              behavior: HitTestBehavior.translucent, // Capture all touches in this area
              onPanDown: (_) => setState(() => _isInteractingWithHandle = true),
              onTapUp: (_) => setState(() => _isInteractingWithHandle = false),
              onTapCancel: () => setState(() => _isInteractingWithHandle = false),
              onPanStart: (d) {
                setState(() {
                  _linkingFromId = n.id;
                  _linkingToPoint = _sceneFromGlobal(d.globalPosition);
                });
              },
              onPanUpdate: (d) {
                setState(() {
                  _linkingToPoint = _sceneFromGlobal(d.globalPosition);
                });
              },
              onPanEnd: (d) {
                setState(() => _isInteractingWithHandle = false);
                final endPoint = _sceneFromGlobal(d.globalPosition);
                String? targetId;
                for (final other in _nodes) {
                  if (other.id == n.id) continue;
                  // Increase target detection area slightly for easier linking
                  final rect = Rect.fromLTWH(
                    other.x - 10, other.y - 10, 
                    _nodeSize.width + 20, _nodeSize.height + 20
                  );
                  if (rect.contains(endPoint)) {
                    targetId = other.id;
                    break;
                  }
                }
                
                if (targetId != null) {
                  setState(() {
                    final newConn = FlowConnection(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      fromId: n.id,
                      toId: targetId!,
                    );
                    _connections.add(newConn);
                    _save();
                    _ws.sendNodeUpdate(_projectId, 'CONNECTION_ADD', newConn.id, newConn.toMap());
                  });
                }
                
                setState(() {
                  _linkingFromId = null;
                  _linkingToPoint = null;
                });
              },
              onPanCancel: () {
                 setState(() {
                   _isInteractingWithHandle = false;
                   _linkingFromId = null;
                   _linkingToPoint = null;
                 });
              },
              child: Container(
                width: 50, // Larger hit area
                height: 50,
                color: Colors.transparent, // Invisible hit box
                alignment: Alignment.center,
                child: Container(
                  width: 24, // Slightly larger visual
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.5),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
                    ]
                  ),
                  child: const Icon(Icons.add, size: 16, color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }



  Widget _buildNodeBox(FlowNode n,
      {bool dragging = false, bool selected = false}) {
    final Color fill = Color(n.colorValue);
    final bool isDark = fill.computeLuminance() < 0.5;
    
    Widget content;
    
    // Custom shape rendering
    if (n.shape == FlowShape.diamond || n.shape == FlowShape.triangle || n.shape == FlowShape.parallelogram || n.shape == FlowShape.circle) {
      content = SizedBox(
        width: _nodeSize.width,
        height: _nodeSize.height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Shape Background
            if (n.shape == FlowShape.diamond)
               Transform.rotate(
                angle: 0.785398, // 45 deg
                child: Container(
                  width: _nodeSize.height * 1.2,
                  height: _nodeSize.height * 1.2,
                  decoration: BoxDecoration(
                    color: fill.withOpacity(0.2),
                    border: Border.all(
                      color: selected ? Colors.white : fill.withOpacity(0.5),
                      width: selected ? 2 : 1,
                    ),
                  ),
                ),
              )
            else if (n.shape == FlowShape.circle)
               Container(
                  width: _nodeSize.height * 1.5,
                  decoration: BoxDecoration(
                    color: fill.withOpacity(0.2),
                    shape: BoxShape.circle,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: selected ? Colors.white : fill.withOpacity(0.5),
                      width: selected ? 2 : 1,
                    ),
                  ),
               )
            else if (n.shape == FlowShape.triangle)
               CustomPaint(
                 size: Size(_nodeSize.width, _nodeSize.height),
                 painter: _TrianglePainter(color: fill.withOpacity(0.2), borderColor: selected ? Colors.white : fill.withOpacity(0.5)),
               )
             else if (n.shape == FlowShape.parallelogram)
               CustomPaint(
                 size: Size(_nodeSize.width, _nodeSize.height),
                 painter: _ParallelogramPainter(color: fill.withOpacity(0.2), borderColor: selected ? Colors.white : fill.withOpacity(0.5)),
               ),

            // Text
            Center(
              child: Padding(
                padding: _nodePadding,
                child: Text(
                  n.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      // Default Rect/Pill
      BorderRadius radius = (n.shape == FlowShape.pill) ? BorderRadius.circular(30) : BorderRadius.circular(12);
      
      content = SizedBox(
        width: _nodeSize.width,
        height: _nodeSize.height,
        child: GlassContainer(
          borderRadius: radius,
          blur: 10,
          opacity: 0.0,
          color: Colors.transparent,
          border: Border.all(color: Colors.transparent),
          child: Container(
            decoration: BoxDecoration(
              color: fill.withOpacity(0.2),
              borderRadius: radius,
              border: Border.all(
                color: selected ? Colors.white : fill.withOpacity(0.5),
                width: selected ? 2 : 1,
              ),
            ),
            child: Center(
              child: Padding(
                padding: _nodePadding,
                child: Text(
                  n.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return content;
  }
}

class _ShapeOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final FlowShape value;
  final VoidCallback onTap;

  const _ShapeOption({required this.icon, required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  _TrianglePainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, Paint()..color = borderColor ..style = PaintingStyle.stroke ..strokeWidth = 1.5);
  }
  @override
  bool shouldRepaint(covariant _TrianglePainter old) => false;
}

class _ParallelogramPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  _ParallelogramPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final skew = 20.0;
    final path = Path()
      ..moveTo(skew, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - skew, size.height)
      ..lineTo(0, size.height)
      ..close();
    
    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, Paint()..color = borderColor ..style = PaintingStyle.stroke ..strokeWidth = 1.5);
  }
  @override
  bool shouldRepaint(covariant _ParallelogramPainter old) => false;
}

class _ConnectionsPainter extends CustomPainter {
  final List<FlowNode> nodes;
  final List<FlowConnection> connections;
  final String? linkingFromId;
  final Offset? linkingToPoint;
  final String? selectedId;
  final Size nodeSize;
  final bool showGrid;
  final double grid;
  final ConnectionStyle style;
  final bool dashed;
  final bool showArrows;

  _ConnectionsPainter({
    required this.nodes,
    required this.connections,
    this.linkingFromId,
    this.linkingToPoint,
    required this.selectedId,
    required this.nodeSize,
    required this.showGrid,
    required this.grid,
    required this.style,
    required this.dashed,
    required this.showArrows,
    required this.viewportSize,
    required this.transform,
  });

  final Size viewportSize;
  final Matrix4 transform;

  @override
  void paint(Canvas canvas, Size size) {
    if (showGrid) _paintGrid(canvas, size);
    try {
      _paintConnections(canvas);
    } catch (e) {
      print('Error painting connections: $e');
    }
    try {
      _paintLinking(canvas);
    } catch (e) {
      print('Error painting linking: $e');
    }
  }

  void _paintGrid(Canvas canvas, Size size) {
    final Paint p = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1.5;

    // Calculate visible bounds to optimize drawing
    final double scale = transform.getMaxScaleOnAxis();
    final Offset translation = Offset(-transform.getTranslation().x, -transform.getTranslation().y);
    
    final double left = (translation.dx / scale).floorToDouble();
    final double top = (translation.dy / scale).floorToDouble();
    final double right = ((translation.dx + viewportSize.width) / scale).ceilToDouble();
    final double bottom = ((translation.dy + viewportSize.height) / scale).ceilToDouble();
    
    // Clamp to canvas size
    final double startX = (left / grid).floor() * grid;
    final double startY = (top / grid).floor() * grid;
    final double endX = right;
    final double endY = bottom;

    for (double x = startX; x < endX; x += grid) {
      if (x < 0 || x > size.width) continue;
      for (double y = startY; y < endY; y += grid) {
        if (y < 0 || y > size.height) continue;
        canvas.drawCircle(Offset(x, y), 1.0, p);
      }
    }
  }

  Offset _anchorFor(FlowNode n, FlowNode other) {
    final Rect rect =
        Rect.fromLTWH(n.x, n.y, nodeSize.width, nodeSize.height);
    final Rect orect =
        Rect.fromLTWH(other.x, other.y, nodeSize.width, nodeSize.height);
    final Offset nCenter = rect.center;
    final Offset oCenter = orect.center;

    final dx = oCenter.dx - nCenter.dx;
    final dy = oCenter.dy - nCenter.dy;

    if (dx.abs() > dy.abs()) {
      if (dx >= 0) {
        return Offset(rect.right - 6, nCenter.dy);
      } else {
        return Offset(rect.left + 6, nCenter.dy);
      }
    } else {
      if (dy >= 0) {
        return Offset(nCenter.dx, rect.bottom - 6);
      } else {
        return Offset(nCenter.dx, rect.top + 6);
      }
    }
  }

  Offset _oppositeAnchorFor(FlowNode n, FlowNode other) {
    final Rect rect =
        Rect.fromLTWH(n.x, n.y, nodeSize.width, nodeSize.height);
    final Rect orect =
        Rect.fromLTWH(other.x, other.y, nodeSize.width, nodeSize.height);
    final Offset nCenter = rect.center;
    final Offset oCenter = orect.center;

    final dx = nCenter.dx - oCenter.dx;
    final dy = nCenter.dy - oCenter.dy;

    if (dx.abs() > dy.abs()) {
      if (dx >= 0) {
        return Offset(rect.left + 6, nCenter.dy);
      } else {
        return Offset(rect.right - 6, nCenter.dy);
      }
    } else {
      if (dy >= 0) {
        return Offset(nCenter.dx, rect.top + 6);
      } else {
        return Offset(nCenter.dx, rect.bottom - 6);
      }
    }
  }

  void _paintConnections(Canvas canvas) {
    final Map<String, FlowNode> byId = {for (final n in nodes) n.id: n};

    for (final conn in connections) {
      try {
        final parent = byId[conn.fromId];
        final child = byId[conn.toId];
        if (parent == null || child == null) continue;

        final start = _anchorFor(parent, child);
        final end = _oppositeAnchorFor(child, parent);

        final bool emphasize = (selectedId != null) &&
            (conn.id == selectedId || child.id == selectedId || parent.id == selectedId);

        final Path path;
        switch (style) {
          case ConnectionStyle.curved:
            path = _cubic(start, end);
            break;
          case ConnectionStyle.orthogonal:
            path = _orthogonalRounded(start, end);
            break;
          case ConnectionStyle.straight:
          default:
            path = _straight(start, end);
            break;
        }

        final Paint glow = Paint()
          ..color = const Color(0xFFFFD700).withOpacity(emphasize ? 0.4 : 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = emphasize ? 6.0 : 4.0
          ..strokeCap = StrokeCap.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        
        if (dashed) {
          _drawDashedPath(canvas, path, glow);
        } else {
          canvas.drawPath(path, glow);
        }

        final Rect bounds = path.getBounds();
        final Paint stroke = Paint()
          ..shader = LinearGradient(
            colors: [
               const Color(0xFFFFD700),
               Colors.white.withOpacity(0.8),
            ], 
          ).createShader(bounds)
          ..style = PaintingStyle.stroke
          ..strokeWidth = emphasize ? 3.0 : 2.0
          ..strokeCap = StrokeCap.round
          ..isAntiAlias = true;
          
        if (dashed) {
          _drawDashedPath(canvas, path, stroke);
        } else {
          canvas.drawPath(path, stroke);
        }

        final Paint dot = Paint()..color = const Color(0xFFFFD700);
        canvas.drawCircle(start, emphasize ? 3.8 : 3.2, dot);
        canvas.drawCircle(end, emphasize ? 3.8 : 3.2, dot);

        if (showArrows) _drawArrowhead(canvas, path, emphasize);
        
        if (conn.label != null && conn.label!.isNotEmpty) {
          _drawLabel(canvas, path, conn.label!);
        }
      } catch (e) {
        print('Error painting connection ${conn.id}: $e');
      }
    }
  }

  void _paintLinking(Canvas canvas) {
    try {
      if (linkingFromId == null || linkingToPoint == null) return;
      final Map<String, FlowNode> byId = {for (final n in nodes) n.id: n};
      final startNode = byId[linkingFromId!];
      if (startNode == null) return;
      
      final start = startNode.x < linkingToPoint!.dx 
          ? Offset(startNode.x + nodeSize.width, startNode.y + nodeSize.height/2)
          : Offset(startNode.x, startNode.y + nodeSize.height/2);
          
      final end = linkingToPoint!;
      
      final Path path;
      switch (style) {
        case ConnectionStyle.curved:
          path = _cubic(start, end);
          break;
        case ConnectionStyle.orthogonal:
          path = _orthogonalRounded(start, end);
          break;
        case ConnectionStyle.straight:
        default:
          path = _straight(start, end);
          break;
      }
      
      final Paint paint = Paint()
        ..color = Colors.blueAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
        
      if (dashed) {
        _drawDashedPath(canvas, path, paint);
      } else {
        canvas.drawPath(path, paint);
      }
    } catch (e) {
      print('Error painting linking: $e');
    }
  }
  
  void _drawLabel(Canvas canvas, Path path, String text) {
    try {
      final metrics = path.computeMetrics();
      final list = metrics.toList();
      if (list.isEmpty) return;
      final metric = list.first;
      final center = metric.getTangentForOffset(metric.length / 2)?.position ?? Offset.zero;
      
      final textSpan = TextSpan(
        text: text,
        style: const TextStyle(color: Colors.black, fontSize: 12, backgroundColor: Colors.white),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      
      final rect = Rect.fromCenter(center: center, width: textPainter.width + 8, height: textPainter.height + 4);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), Paint()..color = Colors.white..style = PaintingStyle.fill);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), Paint()..color = Colors.grey.withOpacity(0.5)..style = PaintingStyle.stroke);
      
      textPainter.paint(canvas, center - Offset(textPainter.width / 2, textPainter.height / 2));
    } catch (e) {
      // Ignore label errors
    }
  }

  Path _cubic(Offset start, Offset end) {
    final Path path = Path()..moveTo(start.dx, start.dy);
    final double dx = (end.dx - start.dx).abs();
    final double dy = (end.dy - start.dy).abs();

    final cp1 = Offset(start.dx + dx * 0.35, start.dy);
    final cp2 = Offset(end.dx - dx * 0.35, end.dy);
    final cp1Adj = Offset(cp1.dx, cp1.dy + (end.dy - start.dy) * 0.15);
    final cp2Adj = Offset(cp2.dx, cp2.dy - (end.dy - start.dy) * 0.15);

    path.cubicTo(cp1Adj.dx, cp1Adj.dy, cp2Adj.dx, cp2Adj.dy, end.dx, end.dy);
    return path;
  }

  Path _orthogonalRounded(Offset start, Offset end, {double r = 16}) {
    final List<Offset> pts = <Offset>[];
    pts.add(start);

    if ((start.dx - end.dx).abs() < 1e-3 || (start.dy - end.dy).abs() < 1e-3) {
      pts.add(end);
      return _roundedPolyline(pts, r);
    }

    final bool horizontalFirst =
        (end.dx - start.dx).abs() > (end.dy - start.dy).abs();

    if (horizontalFirst) {
      pts.add(Offset(end.dx, start.dy));
    } else {
      pts.add(Offset(start.dx, end.dy));
    }
    pts.add(end);
    return _roundedPolyline(pts, r);
  }

  Path _roundedPolyline(List<Offset> points, double radius) {
    final Path path = Path();
    if (points.length < 2) return path;
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];

      final double d1 = (p1 - p0).distance;
      final double d2 = (p2 - p1).distance;
      final double r = radius.clamp(0.0, (d1 < d2 ? d1 : d2) / 2);

      final Offset v1 = (p0 - p1) / d1;
      final Offset v2 = (p2 - p1) / d2;

      final Offset start = p1 + v1 * r;
      final Offset end = p1 + v2 * r;

      path.lineTo(start.dx, start.dy);
      path.quadraticBezierTo(p1.dx, p1.dy, end.dx, end.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  Path _straight(Offset start, Offset end) {
    return Path()..moveTo(start.dx, start.dy)..lineTo(end.dx, end.dy);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {double dashWidth = 10, double dashSpace = 5}) {
    final PathMetrics pathMetrics = path.computeMetrics();
    for (final PathMetric pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        final double length = dashWidth;
        if (distance + length > pathMetric.length) {
          final double remaining = pathMetric.length - distance;
          final Path extract = pathMetric.extractPath(distance, distance + remaining);
          canvas.drawPath(extract, paint);
          break;
        }
        final Path extract = pathMetric.extractPath(distance, distance + length);
        canvas.drawPath(extract, paint);
        distance += length + dashSpace;
      }
    }
  }

  void _drawArrowhead(Canvas canvas, Path path, bool emphasize) {
    try {
      final PathMetrics pm = path.computeMetrics();
      final list = pm.toList();
      if (list.isEmpty) return;
      final PathMetric metric = list.last;
      if (metric.length <= 0) return; 
      final Tangent? t = metric.getTangentForOffset(metric.length);
      if (t == null) return;

      final Offset pos = t.position;
      final Offset dir = -t.vector;
      final double angle = dir.direction;

      final double size = emphasize ? 8.0 : 6.0;
      final Path head = Path();
      head.moveTo(0, 0);
      head.lineTo(-size * 1.5, -size);
      head.lineTo(-size * 1.5, size);
      head.close();

      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle);
      canvas.drawPath(head, Paint()..color = const Color(0xFFFFD700));
      canvas.restore();
    } catch (e) {
      // Ignore arrowhead errors
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectionsPainter old) => true;
}



extension on vec.Vector3 {
  Offset get asOffset => Offset(x, y);
}




