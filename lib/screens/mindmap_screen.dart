import 'dart:math';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/models/collaboration.dart';
import 'package:app/widgets/glass_container.dart';
import 'package:app/widgets/creative_toolbar.dart';
import 'package:app/widgets/live_cursors.dart';
import 'package:app/widgets/minimap.dart';
import 'package:app/services/websocket_service.dart';
import 'package:app/themes/mindmap_theme.dart';

/// Mindmap screen component — complete, polished and fixed nearest-edge + zoom logic.
/// Use: MindmapScreen(collaboration: ..., canEdit: true/false)
class MindmapScreen extends StatefulWidget {
  final Collaboration? collaboration;
  final bool canEdit;
  final Future<void> Function()? onSave;
  const MindmapScreen({super.key, this.collaboration, this.canEdit = false, this.onSave});

  @override
  State<MindmapScreen> createState() => _MindmapScreenState();
}

class _MindmapScreenState extends State<MindmapScreen>
    with TickerProviderStateMixin {
  final GlobalKey _canvasKey = GlobalKey();
  List<Map<String, dynamic>> _nodes = [];
  String? _linkingFromId;
  Offset? _linkingToPoint;

  bool _didPanOnCanvas = false;
  String? _selectedId; // Restored public variable for state


  double _toDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  late final AnimationController _pulseController;
  late final AnimationController _inertiaController;
  Animation<Offset>? _inertiaAnimation;

  // Zoom & pan
  double _scale = 1.0;
  double _initialScale = 1.0;

  Offset _offset = Offset.zero; // Restored
  
  static const double nodeWidth = 160; 
  static const double nodeHeight = 50;
  static const int defaultNodeColor = 0xFF457B9D; 
  
  MindMapTheme _theme = MindMapTheme.meister;

  final TransformationController _transformationController = TransformationController();
  final WebSocketService _ws = WebSocketService();
  late String _projectId;
  late String _myUserId;
  
  bool _isPanMode = false; // Default to Select/Edit mode for immediate interaction

  Map<String, dynamic> _sanitizeNode(Map<String, dynamic> map) {
    // normalize connectedTo
    final rawConn = map['connectedTo'];
    List<Map<String, dynamic>> connections = [];
    if (rawConn is List) {
      for (var c in rawConn) {
        if (c is Map) {
          final m = <String, dynamic>{};
          c.forEach((k, v) => m[k.toString()] = v);
          connections.add(m);
        }
      }
    }
    
    return {
      ...map,
      'id': map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'label': map['label']?.toString() ?? 'Node',
      'shape': map['shape']?.toString() ?? 'rounded',
      'x': _toDouble(map['x']),
      'y': _toDouble(map['y']),
      'nodeColor': (map['nodeColor'] as int?) ?? defaultNodeColor,
      'iconCodePoint': map['iconCodePoint'] is int 
          ? map['iconCodePoint'] 
          : int.tryParse(map['iconCodePoint']?.toString() ?? ''),
      'connectedTo': connections,
      'appeared': map['appeared'] ?? true,
    };
  }

  @override
  void initState() {
    super.initState();
    _pulseController =
        AnimationController(vsync: this, duration: const Duration(seconds: 4))
          ..repeat();
    
    _projectId = widget.collaboration?.id ?? 'demo_project';
    _myUserId = 'user_${DateTime.now().millisecondsSinceEpoch % 1000}';

    _ws.connect(_projectId, _myUserId);
    _ws.nodeStream.listen((msg) {
      if (!mounted) return;
      if (msg['type'] == 'MINDMAP_UPDATE') {
        final data = msg['data'];
        final nodeId = msg['nodeId'];
        final action = msg['action'];

        setState(() {
          if (action == 'DELETE') {
            _nodes.removeWhere((n) => n['id'] == nodeId);
            // Also remove connections to this node
            for (final n in _nodes) {
              ((n['connectedTo'] as List?) ?? []).removeWhere((l) => l['targetId'] == nodeId);
            }
          } else {
            final sanitized = _sanitizeNode(Map<String, dynamic>.from(data));
            final idx = _nodes.indexWhere((n) => n['id'] == nodeId);
            if (idx >= 0) {
              _nodes[idx] = sanitized;
            } else {
              _nodes.add(sanitized);
            }
          }
        });
      }
    });

    _loadNodes();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _loadNodes() {
    final data = widget.collaboration?.toolData['mindmap_nodes'];
      Map<String, dynamic> _toMap(dynamic it) {
        if (it == null) return <String, dynamic>{};
        if (it is Map<String, dynamic>) return Map<String, dynamic>.from(it);
        if (it is Map) {
          final m = <String, dynamic>{};
          it.forEach((k, v) {
            m[k.toString()] = v;
          });
          return m;
        }
        if (it is String) {
          try {
            final d = jsonDecode(it);
            if (d is Map) {
              final m = <String, dynamic>{};
              d.forEach((k, v) => m[k.toString()] = v);
              return m;
            }
          } catch (_) {}
        }
        return <String, dynamic>{};
      }

      if (data is List) {
        _nodes = data.map((item) {
          final map = _toMap(item);
          return _sanitizeNode(map);
        }).toList();
    }
  }

  // --- ZOOM, PAN, and INERTIA LOGIC ---


  void _resetView() {
     _transformationController.value = Matrix4.identity();
     setState(() {
        _scale = 1.0;
        _offset = Offset.zero;
     });
  }

  // Adjusted to rely on the tracking variables synced in onInteractionUpdate
  Offset _toLocal(Offset global) => (global - _offset) / _scale;

  void _save({bool local = false}) {
    if (!widget.canEdit) return;
    if (widget.collaboration != null) {
      widget.collaboration!.toolData['mindmap_nodes'] = _nodes;
    }
    widget.onSave?.call();
  }

  void _syncNode(Map<String, dynamic> node) {
    _ws.sendNodeUpdate(_projectId, 'MINDMAP_UPDATE', node['id'], {
      ...node,
      'action': 'UPDATE'
    });
  }

  Offset _nonOverlapping(Offset pos) {
    const double minDistance = 90.0;
    var result = pos;
    bool overlaps(Offset a, Offset b) => (a - b).distance < minDistance;
    for (final n in _nodes) {
      final other = Offset(_toDouble(n['x']), _toDouble(n['y']));
      if (overlaps(other, result)) {
        result = result.translate(minDistance * 0.6, minDistance * 0.6);
      }
    }
    return result;
  }

  void _addNode(Offset pos) {
    if (!widget.canEdit) return;
    pos = _nonOverlapping(pos);
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    setState(() {
      _nodes.add({
        'id': id,
        'x': pos.dx,
        'y': pos.dy,
        'label': 'Idea ${_nodes.length + 1}',
        'nodeColor': defaultNodeColor,
        'iconCodePoint': null,
        'connectedTo': <Map<String, dynamic>>[],
        'appeared': false,
        'shape': 'rounded',
      });
    });
    Future.delayed(const Duration(milliseconds: 20), () {
      final idx = _nodes.indexWhere((e) => e['id'] == id);
      if (idx != -1) {
        setState(() => _nodes[idx]['appeared'] = true);
        _ws.sendNodeUpdate(_projectId, 'MINDMAP_UPDATE', id, {
          ..._nodes[idx],
          'action': 'ADD'
        });
      }
      _save(local: true);
    });
  }



  void _endLinking(Map<String, dynamic> target) async {
    if (!widget.canEdit || _linkingFromId == null) return;
    final sourceId = _linkingFromId!;
    final targetId = target['id'];

    if (sourceId == targetId) {
      setState(() {
        _linkingFromId = null;
        _linkingToPoint = null;
      });
      return;
    }

    final source =
        _nodes.firstWhere((n) => n['id'] == sourceId, orElse: () => {});
    if (source.isEmpty) {
      setState(() {
        _linkingFromId = null;
        _linkingToPoint = null;
      });
      return;
    }

    final props = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _LinkDialog(),
    );

    if (!mounted) return;
    String? message;

    setState(() {
      _linkingFromId = null;
      _linkingToPoint = null;
      if (props != null) {
        final links = source['connectedTo'] as List;
        if (!links.any((l) => l['targetId'] == targetId)) {
          props['targetId'] = targetId;
          links.add(props);
          _save();
          _syncNode(source);
          message = 'Link created successfully!';
        } else {
          message = 'Link already exists';
        }
      } else {
        message = 'Link creation cancelled';
      }
    });

    if (message != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message!)));
    }
  }





  @override
  Widget build(BuildContext context) {
    // Make the canvas fill the entire viewport (100vw x 100vh) and overlay
    // the top controls so the canvas behaves like a full-screen area while the
    // toolbar remains accessible.
    return Stack(
      children: [
        Positioned.fill(child: _canvasArea()),
        // Top controls overlay
        Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Material(
                  elevation: 4,
                  color: Theme.of(context).scaffoldBackgroundColor,
                  child: Column(children: [_topBar(), _instructionBar()]),
                ),
              ),
            ),
        // Minimap Overlay
        Positioned(
          right: 20,
          bottom: 20,
          child: Minimap(
            items: _nodes.map((n) => MinimapItem(
              x: _toDouble(n['x']),
              y: _toDouble(n['y']),
              width: _MindmapScreenState.nodeWidth,
              height: _MindmapScreenState.nodeHeight,
              color: Color((n['nodeColor'] as int?) ?? _MindmapScreenState.defaultNodeColor),
            )).toList(),
            viewTransform: Matrix4.identity()
              ..translate(_offset.dx, _offset.dy)
              ..scale(_scale),
            viewportSize: MediaQuery.of(context).size,
            onViewChanged: (matrix) {
              setState(() {
                _scale = matrix.getMaxScaleOnAxis();
                _offset = Offset(matrix.getTranslation().x, matrix.getTranslation().y);
              });
            },
          ),
        ),
        

      ],
    );
  }

  Widget _topBar() {
    return CreativeToolbar(
      title: 'Mindmap',
      iconPath: 'assets/svg/mindmap_custom.svg',
      canEdit: widget.canEdit,
      onBack: () => Navigator.of(context).pop(), // Connected
      activeUsers: const ['Alice', 'Bob', 'Charlie'],
      isPanMode: _isPanMode,
      onModeChanged: (v) => setState(() => _isPanMode = v),
      onSave: _save,
      onZoomIn: () {
        setState(() {
          _scale = (_scale * 1.2).clamp(0.4, 3.0);
        });
      },
      onZoomOut: () {
        setState(() {
          _scale = (_scale * 0.8).clamp(0.4, 3.0);
        });
      },
      onResetView: _resetView,
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
                      title: const Text('Clear Mindmap'),
                      content: const Text('Remove all nodes and connections?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            setState(() {
                              _nodes.clear();
                              _linkingFromId = null;
                              _linkingToPoint = null;
                              _save();
                            });
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
                }
              : null,
        ),
      ],
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
            : 'Tap canvas to create node • Use 2 fingers to pan',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontWeight: FontWeight.w600, color: Colors.blueGrey[800]),
      ),
    );
  }

  Widget _canvasArea() {
    return Listener(
      onPointerDown: (_) => _didPanOnCanvas = false,
      child: Stack(
        children: [
          // Background adapts to theme
          Positioned.fill(
            child: Container(color: Theme.of(context).scaffoldBackgroundColor),
          ),
          // Grid
          Positioned.fill(
            child: CustomPaint(
              painter: _GridPainter(
                  offset: _offset, 
                  scale: _scale, 
                  isDark: Theme.of(context).brightness == Brightness.dark
              ),
            ),
          ),
          // Content Layer (Interactions)
          Positioned.fill(
            child: GestureDetector(
              key: _canvasKey,
              behavior: HitTestBehavior.translucent,
              onTapUp: (d) {
              if (_didPanOnCanvas) {
                _didPanOnCanvas = false;
                return;
              }

              final worldPos = _toLocal(d.localPosition);
              Map<String, dynamic>? hitNode;
              // Reverse iterate to hit top-most node first
              for (final node in _nodes.reversed) {
                 final rect = Rect.fromLTWH(
                    _toDouble(node['x']),
                    _toDouble(node['y']),
                    _MindmapScreenState.nodeWidth,
                    _MindmapScreenState.nodeHeight,
                 );
                 if (rect.contains(worldPos)) {
                   hitNode = node;
                   break;
                 }
              }

              if (hitNode != null) {
                 // NODE TAP LOGIC
                 if (_linkingFromId != null) {
                    if (_linkingFromId != hitNode['id']) {
                        _endLinking(hitNode);
                    }
                 } else {
                    setState(() => _selectedId = hitNode!['id']);
                 }
                 return;
              }

              // BACKGROUND TAP LOGIC
              if (_linkingFromId != null) {
                setState(() {
                  _linkingFromId = null;
                  _linkingToPoint = null;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Link cancelled'), duration: Duration(milliseconds: 500)),
                );
              } else if (_selectedId != null) {
                 setState(() => _selectedId = null);
              } else {
                _addNode(worldPos);
              }
            },
            // Note: onScale* removed. InteractiveViewer handles pan/zoom below.
            child: InteractiveViewer(
              transformationController: _transformationController,
              boundaryMargin: const EdgeInsets.all(double.infinity),
              constrained: false,
              minScale: 0.1,
              maxScale: 5.0,
              onInteractionUpdate: (d) {
                // Sync state for Painter/Grid
                if (_transformationController.value != Matrix4.identity()) {
                   setState(() {
                      _scale = _transformationController.value.getMaxScaleOnAxis();
                      final t = _transformationController.value.getTranslation();
                      _offset = Offset(t.x, t.y);
                   });
                }
              },
              child: SizedBox(
                width: 10000, 
                height: 10000,
                child: Stack(
                   clipBehavior: Clip.none,
                   children: [
                       // Connections
                       Positioned.fill(
                         child: CustomPaint(
                           painter: _MindmapPainter(
                             nodes: _nodes,
                             pulseT: _pulseController.value,
                             linkingFromId: _linkingFromId,
                             linkingToPoint: _linkingToPoint,
                           ),
                         ),
                       ),
                       // Nodes
                       ..._nodes.map(_nodeWidget),
                       
                       // Floating Toolbar (Re-positioned via Overlay or Stack?)
                       // If inside InteractiveViewer, it scales. 
                       // For now, keep it here to ensure it moves with the node.
                       if (_selectedId != null && widget.canEdit)
                         _buildFloatingToolbar(),
                   ],
                ),
              ),
            ),
          ),
        ),
      ],
      ),
    );
  }

  Widget _nodeWidget(Map<String, dynamic> node) {
    final id = (node['id'] as String?) ?? '';
    final color = Color((node['nodeColor'] as int?) ?? defaultNodeColor);
    final linking = _linkingFromId == id;
    final appeared = (node['appeared'] as bool?) ?? true;

    return Positioned(
      left: _toDouble(node['x']),
      top: _toDouble(node['y']),
      child: SizedBox(
        width: _MindmapScreenState.nodeWidth, // Match exact content width
        height: _MindmapScreenState.nodeHeight, // Match exact content height
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Node Content
            Positioned.fill(
              child: MouseRegion(
                cursor: widget.canEdit ? SystemMouseCursors.move : SystemMouseCursors.basic,
                child: GestureDetector(
                  onPanUpdate: (d) {
                    if (!widget.canEdit) return;
                    setState(() {
                      node['x'] = _toDouble(node['x']) + d.delta.dx / _scale;
                      node['y'] = _toDouble(node['y']) + d.delta.dy / _scale;
                    });
                  },
                  onPanEnd: (d) {
                     if (widget.canEdit) {
                        _save();
                        _syncNode(node);
                     }
                  },
                  child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 260),
                      opacity: appeared ? 1.0 : 0.0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 220),
                        scale: linking ? 1.06 : 1.0,
                        child: _buildNodeShape(node, color, linking),
                      ),
                    ),
                ),
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildNodeShape(Map<String, dynamic> node, Color color, bool linking) {
    final shape = node['shape'] ?? 'rounded';
    final bool isSelected = _selectedId == node['id'];
    
    // MindMeister Style: Clean White background, Colored Border
    // Content is Dark (Black87)
    final content = Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node['iconCodePoint'] != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(
                IconData(node['iconCodePoint'], fontFamily: 'MaterialIcons'),
                color: color, // Icon matches border color
                size: 20,
              ),
            ),
          Flexible(
            child: Text(
              node['label'],
              style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    BoxDecoration baseDecoration({BoxShape shape = BoxShape.rectangle, BorderRadius? borderRadius}) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        shape: shape,
        borderRadius: borderRadius,
        border: Border.all(
          color: isSelected ? Colors.blueAccent : color,
          width: isSelected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
          if (isSelected)
             BoxShadow(
              color: Colors.blueAccent.withOpacity(0.2),
              spreadRadius: 2,
              blurRadius: 8,
            )
        ],
      );
    }

    if (shape == 'circle') {
      return Container(
        decoration: baseDecoration(shape: BoxShape.circle),
        child: content,
      );
    } else if (shape == 'diamond') {
       // Diamond is tricky with Border. We rotate a container.
       return Stack(
         alignment: Alignment.center,
         children: [
           Transform.rotate(
             angle: 0.785398,
             child: Container(
               width: _MindmapScreenState.nodeHeight * 1.2,
               height: _MindmapScreenState.nodeHeight * 1.2,
               decoration: baseDecoration(borderRadius: BorderRadius.circular(4)),
             ),
           ),
           content,
         ],
       );
    } else if (shape == 'triangle') {
        // Custom Paint for Triangle
        return CustomPaint(
            painter: _TrianglePainter(
               color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white, 
               borderColor: isSelected ? Colors.blueAccent : color,
            ),
            child: Center(child: content),
        );
    } else if (shape == 'parallelogram') {
         // Custom Paint for Parallelogram
        return CustomPaint(
            painter: _ParallelogramPainter(
               color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E1E) : Colors.white, 
               borderColor: isSelected ? Colors.blueAccent : color,
            ),
            child: Center(child: content),
        );
    }

    // Default Rounded (Pill)
    return Container(
      decoration: baseDecoration(borderRadius: BorderRadius.circular(24)),
      child: content,
    );
  }




  
  void _startLinking(Map<String, dynamic> source) {
      setState(() {
        _linkingFromId = source['id'];
        _linkingToPoint = Offset(_toDouble(source['x']) + nodeWidth + 50, _toDouble(source['y']) + nodeHeight/2);
      });
  }

  void _addNodeAt(Offset pos, {String? parentId}) {
    if (!widget.canEdit) return;
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final newNode = {
      'id': id,
      'label': 'New Node',
      'x': pos.dx,
      'y': pos.dy,
      'shape': _theme.nodeShape == NodeShape.pill ? 'rounded' : 'rounded',
      'nodeColor': _theme.palette[_nodes.length % _theme.palette.length].value,
      'connectedTo': parentId != null ? [{'targetId': parentId, 'color': Colors.grey.value}] : [],
      'appeared': true,
    };
    
    // If parentId provided, also link parent TO child? 
    // Usually tree structure: Parent -> Child.
    // If we want Parent -> Child link:
    if (parentId != null) {
       final parent = _nodes.firstWhere((n) => n['id'] == parentId);
       final connections = parent['connectedTo'] as List;
       connections.add({
         'targetId': id,
         'color': parent['nodeColor'] ?? Colors.blue.value,
         'style': 'curved'
       });
    }

    setState(() {
      _nodes.add(newNode);
      _selectedId = id; // Auto-select new node
      _save();
    });
    
    // Broadcast change
    _ws.sendNodeUpdate(_projectId, 'MINDMAP_UPDATE', id, {
       ...newNode,
       'action': 'ADD'
    });
    
    // Also broadcast parent update regarding new connection?
    if (parentId != null) {
       final parent = _nodes.firstWhere((n) => n['id'] == parentId);
       _syncNode(parent);
    }
  }

  void _deleteNode(String id) {
     if (!widget.canEdit) return;
     setState(() {
       _nodes.removeWhere((n) => n['id'] == id);
       // Remove connections to this node
       for (var n in _nodes) {
         final connections = n['connectedTo'] as List;
         connections.removeWhere((c) => c['targetId'] == id);
       }
       if (_selectedId == id) _selectedId = null;
       _save();
     });
     _ws.sendNodeUpdate(_projectId, 'MINDMAP_UPDATE', id, {'action': 'DELETE'});
  }

  Future<void> _renameNode(Map<String, dynamic> node) async {
    if (!widget.canEdit) return;
    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => _RenameDialog(initial: node['label']),
    );
    if (newLabel != null && newLabel.isNotEmpty) {
      setState(() {
        node['label'] = newLabel;
        _save();
      });
      _syncNode(node);
    }
  }

  Future<void> _pickColor(Map<String, dynamic> node) async {
    if (!widget.canEdit) return;
    final newColor = await showDialog<int>(
      context: context,
      builder: (ctx) => _ColorPickerDialog(initial: node['nodeColor'] ?? Colors.blue.value),
    );
    if (newColor != null) {
      setState(() {
        node['nodeColor'] = newColor;
        _save();
      });
      _syncNode(node);
    }
  }

  Widget _buildFloatingToolbar() {
    final node = _nodes.firstWhere((n) => n['id'] == _selectedId, orElse: () => {});
    if (node.isEmpty) return const SizedBox.shrink();

    final x = _toDouble(node['x']);
    final y = _toDouble(node['y']);
    
    // Position toolbar above the node
    return Positioned(
      left: x + nodeWidth / 2 - 100, // Center horizontally (approx width 200)
      top: y - 60,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(24),
        color: Colors.white,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               _toolbarBtn(Icons.add, () => _addNodeAt(Offset(x + nodeWidth + 50, y), parentId: node['id'])),
               _toolbarBtn(Icons.link, () {
                  setState(() {
                    _linkingFromId = node['id'];
                    _linkingToPoint = Offset(x + nodeWidth/2, y + nodeHeight/2);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tap another node to link'), duration: Duration(milliseconds: 1000)),
                  );
               }),
               _toolbarBtn(Icons.edit, () => _renameNode(node)),
               _toolbarBtn(Icons.palette, () => _pickColor(node)),
               Container(width: 1, height: 20, color: Colors.grey.shade300, margin: const EdgeInsets.symmetric(horizontal: 4)),
               _toolbarBtn(Icons.delete, () => _deleteNode(node['id']), color: Colors.red),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toolbarBtn(IconData icon, VoidCallback onTap, {Color color = Colors.black87}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }


} // End of _MindmapScreenState

// ---------------------- Dialogs ----------------------

class _RenameDialog extends StatelessWidget {
  final String initial;
  const _RenameDialog({required this.initial});

  @override
  Widget build(BuildContext context) {
    final ctrl = TextEditingController(text: initial);
    return AlertDialog(
      title: const Text('Rename Node'),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Label'),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('Save')),
      ],
    );
  }
}

class _ColorPickerDialog extends StatefulWidget {
  final int initial;
  const _ColorPickerDialog({required this.initial});
  @override
  State<_ColorPickerDialog> createState() => _ColorPickerDialogState();
}

class _ColorPickerDialogState extends State<_ColorPickerDialog> {
  late Color _selected;
  @override
  void initState() {
    super.initState();
    _selected = Color(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final palette = [
      0xFFFFD700, // Gold
      0xFFFFFFFF, // White
      0xFF000000, // Black
      0xFFE53935, // Red
      0xFF43A047, // Green
      0xFF1E88E5, // Blue
      0xFF8E24AA, // Purple
      0xFF00ACC1, // Cyan
      0xFFFFB300, // Amber
    ].map((c) => Color(c)).toList();
    return AlertDialog(
      title: const Text('Pick Color'),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: palette
            .map((c) => GestureDetector(
                  onTap: () => setState(() => _selected = c),
                  child: CircleAvatar(
                      backgroundColor: c,
                      radius: 20,
                      child: _selected == c
                          ? const Icon(Icons.check, color: Colors.white)
                          : null),
                ))
            .toList(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, _selected.value),
            child: const Text('Apply')),
      ],
    );
  }
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog();
  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  Color _color = Colors.blue;
  double _stroke = 2.6;
  bool _dashed = false;
  bool _arrow = true;
  String _style = 'straight';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Link Settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            children: [
              Colors.white, 
              Colors.black, 
              const Color(0xFFFFD700), // Gold
              Colors.redAccent,
              Colors.blueAccent
            ]
                .map((c) => GestureDetector(
                    onTap: () => setState(() => _color = c),
                    child: CircleAvatar(
                        backgroundColor: c,
                        child: _color == c
                            ? const Icon(Icons.check, color: Colors.white)
                            : null)))
                .toList(),
          ),
          const SizedBox(height: 8),
          Row(
              children: [
                const Text('Thickness'),
                const Spacer(),
                Text(_stroke.toStringAsFixed(1))
              ]),
          Slider(
              value: _stroke,
              min: 1,
              max: 6,
              divisions: 10,
              onChanged: (v) => setState(() => _stroke = v)),
          Row(
              children: [
                const Text('Dashed'),
                const Spacer(),
                Switch(value: _dashed, onChanged: (v) => setState(() => _dashed = v))
              ]),
          Row(
              children: [
                const Text('Arrow'),
                const Spacer(),
                Switch(value: _arrow, onChanged: (v) => setState(() => _arrow = v))
              ]),
          const SizedBox(height: 8),
          const Text('Style'),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _styleOption('Straight', 'straight'),
              _styleOption('Curved', 'curved'),
              _styleOption('Orthogonal', 'orthogonal'),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        ElevatedButton(
            onPressed: () => Navigator.pop(context, {
                  'color': _color.value,
                  'strokeWidth': _stroke,
                  'dashed': _dashed,
                  'arrow': _arrow,
                  'style': _style,
                }),
            child: const Text('Create')),
      ],
    );
  }

  Widget _styleOption(String label, String value) {
    final selected = _style == value;
    return GestureDetector(
      onTap: () => setState(() => _style = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
          border: Border.all(color: selected ? Colors.blue : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(label, style: TextStyle(
          color: selected ? Colors.blue : Colors.black87,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          fontSize: 12,
        )),
      ),
    );
  }
}

// ---------------------- Painter ----------------------

class _MindmapPainter extends CustomPainter {
  final List<Map<String, dynamic>> nodes;
  final double pulseT;
  final String? linkingFromId;
  final Offset? linkingToPoint;
  
  _MindmapPainter({
    required this.nodes,
    required this.pulseT,
    this.linkingFromId,
    this.linkingToPoint,
  });

  static const double nodeW = 180;
  static const double nodeH = 56;
  static const double arrowSize = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final centers = <String, Offset>{};
    for (final n in nodes) {
      centers[n['id']] =
          Offset(((n['x'] as num?)?.toDouble() ?? 0.0) + nodeW / 2, ((n['y'] as num?)?.toDouble() ?? 0.0) + nodeH / 2);
    }

    for (final n in nodes) {
      final links = (n['connectedTo'] as List).cast<Map<String, dynamic>>();
      for (final link in links) {
        final targetId = link['targetId'] as String?;
        if (targetId == null) continue;
        if (!centers.containsKey(targetId)) continue;

        final src = centers[n['id']]!;
        final dst = centers[targetId]!;

        final color = Color(link['color'] ?? Colors.blue.value);
        final strokeWidth = (link['strokeWidth'] ?? 2.0).toDouble();

        // Glow Paint
        final glowPaint = Paint()
          ..color = color.withOpacity(0.4)
          ..strokeWidth = strokeWidth + 4
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        // Main Paint
        final paint = Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final style = link['style'] ?? 'straight';
        final Path path;
        
        if (style == 'curved') {
          path = _cubic(src, dst);
        } else if (style == 'orthogonal') {
          path = _orthogonalRounded(src, dst);
        } else {
          path = Path()..moveTo(src.dx, src.dy)..lineTo(dst.dx, dst.dy);
        }

        if (link['dashed'] == true) {
          _drawDashedPath(canvas, path, paint);
        } else {
          canvas.drawPath(path, glowPaint);
          canvas.drawPath(path, paint);
        }

        if (link['arrow'] == true) {
          _drawArrow(canvas, src, dst, paint, color);
        }
      }
    }
    
    // Draw temporary linking line
    if (linkingFromId != null && linkingToPoint != null) {
      final srcNode = nodes.firstWhere((n) => n['id'] == linkingFromId, orElse: () => {});
      if (srcNode.isNotEmpty) {
        final src = Offset(
          ((srcNode['x'] as num?)?.toDouble() ?? 0.0) + nodeW, 
          ((srcNode['y'] as num?)?.toDouble() ?? 0.0) + nodeH / 2
        );
        final dst = linkingToPoint!;
        
        final paint = Paint()
          ..color = Colors.blueAccent
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
          
        // Draw dashed line
        _drawDashedPath(canvas, Path()..moveTo(src.dx, src.dy)..lineTo(dst.dx, dst.dy), paint);
      }
    }
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

  Path _cubic(Offset start, Offset end) {
    final Path path = Path()..moveTo(start.dx, start.dy);
    final double dx = (end.dx - start.dx).abs();
    final double dy = (end.dy - start.dy).abs();

    final cp1 = Offset(start.dx + dx * 0.5, start.dy);
    final cp2 = Offset(end.dx - dx * 0.5, end.dy);

    path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, end.dx, end.dy);
    return path;
  }

  Path _orthogonalRounded(Offset start, Offset end, {double r = 16}) {
    final List<Offset> pts = <Offset>[];
    pts.add(start);

    if ((start.dx - end.dx).abs() < 1e-3 || (start.dy - end.dy).abs() < 1e-3) {
      pts.add(end);
      return _roundedPolyline(pts, r);
    }

    final bool horizontalFirst = (end.dx - start.dx).abs() > (end.dy - start.dy).abs();

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

  void _drawArrow(Canvas canvas, Offset p1, Offset p2, Paint paint, Color color) {
    final angle = (p2 - p1).direction;
    final arrowPath = Path();
    final mid = (p1 + p2) / 2;
    
    // Simpler, cleaner arrow
    arrowPath.moveTo(mid.dx + cos(angle) * arrowSize, mid.dy + sin(angle) * arrowSize);
    arrowPath.lineTo(mid.dx + cos(angle + 2.5) * arrowSize, mid.dy + sin(angle + 2.5) * arrowSize);
    arrowPath.lineTo(mid.dx + cos(angle - 2.5) * arrowSize, mid.dy + sin(angle - 2.5) * arrowSize);
    arrowPath.close();
    
    canvas.drawPath(arrowPath, Paint()..color = color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_MindmapPainter old) => true;
}

class _GridPainter extends CustomPainter {
  final Offset offset;
  final double scale;
  final bool isDark;
  _GridPainter({required this.offset, required this.scale, this.isDark = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.1) : Colors.grey.withOpacity(0.3)
      ..style = PaintingStyle.fill; // Dots are filled circles

    const double gridSize = 40.0;
    
    // Calculate visible world bounds
    // We want to draw grid dots that cover the screen.
    final double left = -offset.dx / scale;
    final double top = -offset.dy / scale;
    final double right = (size.width - offset.dx) / scale;
    final double bottom = (size.height - offset.dy) / scale;

    // Align to grid
    final double startX = (left / gridSize).floor() * gridSize;
    final double startY = (top / gridSize).floor() * gridSize;

    for (double x = startX; x < right; x += gridSize) {
      for (double y = startY; y < bottom; y += gridSize) {
        final screenPos = (Offset(x, y) * scale) + offset;
        canvas.drawCircle(screenPos, 1.5 * scale.clamp(0.5, 1.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.offset != offset || old.scale != scale;
}

class _IconPickerDialog extends StatelessWidget {
  final int? initial;
  const _IconPickerDialog({this.initial});

  @override
  Widget build(BuildContext context) {
    final icons = [
      Icons.star, Icons.favorite, Icons.flag, Icons.check_circle, Icons.warning,
      Icons.lightbulb, Icons.access_time, Icons.attach_file, Icons.image, Icons.face,
      Icons.work, Icons.school, Icons.flight, Icons.home, Icons.shopping_cart,
      Icons.build, Icons.code, Icons.bug_report, Icons.lock, Icons.visibility,
    ];

    return AlertDialog(
      title: const Text('Select Icon'),
      content: SizedBox(
        width: 300,
        height: 300,
        child: GridView.count(
          crossAxisCount: 4,
          children: [
            IconButton(
              icon: const Icon(Icons.close, color: Colors.red),
              onPressed: () => Navigator.pop(context, 0), // 0 means remove icon
              tooltip: 'Remove Icon',
            ),
            ...icons.map((icon) => IconButton(
              icon: Icon(icon, color: icon.codePoint == initial ? Colors.blue : null),
              onPressed: () => Navigator.pop(context, icon.codePoint),
            )),
          ],
        ),
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
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color || old.borderColor != borderColor;
}

class _ParallelogramPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  _ParallelogramPainter({required this.color, required this.borderColor});

  @override
  void paint(Canvas canvas, Size size) {
    final skew = size.width * 0.2;
    final path = Path();
    path.moveTo(skew, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width - skew, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, Paint()..color = color);
    canvas.drawPath(path, Paint()..color = borderColor..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(covariant _ParallelogramPainter old) => old.color != color || old.borderColor != borderColor;
}

class _ShapePickerDialog extends StatelessWidget {
  final String initial;
  const _ShapePickerDialog({required this.initial});

  @override
  Widget build(BuildContext context) {
    final shapes = [
      {'id': 'rounded', 'icon': Icons.crop_square, 'label': 'Rounded'},
      {'id': 'circle', 'icon': Icons.circle_outlined, 'label': 'Circle'},
      {'id': 'diamond', 'icon': Icons.change_history, 'label': 'Diamond'}, // Using triangle icon rotated or similar
      {'id': 'triangle', 'icon': Icons.change_history, 'label': 'Triangle'},
      {'id': 'parallelogram', 'icon': Icons.view_comfy, 'label': 'Skew'},
    ];

    return AlertDialog(
      title: const Text('Pick Shape'),
      content: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: shapes.map((s) {
          final selected = s['id'] == initial;
          return GestureDetector(
            onTap: () => Navigator.pop(context, s['id']),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: selected ? Colors.blue.withOpacity(0.1) : Colors.transparent,
                    border: Border.all(color: selected ? Colors.blue : Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(s['icon'] as IconData, color: selected ? Colors.blue : Colors.grey),
                ),
                const SizedBox(height: 4),
                Text(s['label'] as String, style: TextStyle(
                  fontSize: 12,
                  color: selected ? Colors.blue : Colors.black87,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
