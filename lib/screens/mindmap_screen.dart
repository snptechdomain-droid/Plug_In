import 'dart:math';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/models/collaboration.dart';
import 'package:app/widgets/glass_container.dart';
import 'package:app/widgets/creative_toolbar.dart';
import 'package:app/widgets/live_cursors.dart';
import 'package:app/widgets/minimap.dart';
import 'package:app/services/websocket_service.dart';

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
  Offset _offset = Offset.zero;
  Offset _lastFocal = Offset.zero;
  Offset _velocity = Offset.zero;
  // Dragging a node via canvas-scale gestures
  String? _draggingNodeId;
  Offset? _dragStartLocal;
  Offset? _nodeStartPos;

  static const double nodeWidth = 180; // Slightly wider for glass effect
  static const double nodeHeight = 56;
  static const int defaultNodeColor = 0xFFFFD700; // Gold

  final WebSocketService _ws = WebSocketService();
  late String _projectId;
  late String _myUserId;
  
  bool _isPanMode = true; // Default to Pan for mobile

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
    _inertiaController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    
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
    _inertiaController.dispose();
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
  void _onScaleStart(ScaleStartDetails details) {
    _lastFocal = details.localFocalPoint;
    _inertiaController.stop();
    _initialScale = _scale;
    
    // Store the initial position to check for node hits on first update
    if (details.pointerCount == 1 && widget.canEdit && !_isPanMode) {
      final local = _toLocal(details.localFocalPoint);
      print('DEBUG: ScaleStart at $local (raw: ${details.localFocalPoint})');
      for (final n in _nodes) {
        final nx = _toDouble(n['x']);
        final ny = _toDouble(n['y']);
        final rect = Rect.fromLTWH(nx, ny, nodeWidth, nodeHeight);
        if (rect.contains(local)) {
          // Mark this node as a potential drag target
          _dragStartLocal = local;
          _nodeStartPos = Offset(nx, ny);
          _draggingNodeId = n['id'] as String;
          print('DEBUG: Node detected for dragging: $_draggingNodeId');
          break;
        }
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    _didPanOnCanvas = true;
    final local = _toLocal(details.localFocalPoint);
    
    // Handle pinch-to-zoom when two or more pointers are present
    if (details.pointerCount >= 2) {
      setState(() {
        _scale = (_initialScale * details.scale).clamp(0.4, 3.0);
      });
    } else if (_draggingNodeId != null) {
      // Dragging a node
      print('DEBUG: Dragging node $_draggingNodeId');
      final idx = _nodes.indexWhere((e) => e['id'] == _draggingNodeId);
      if (idx != -1 && _dragStartLocal != null && _nodeStartPos != null) {
        final deltaLocal = local - _dragStartLocal!;
        print('DEBUG: Moving node by delta: $deltaLocal');
        setState(() {
          _nodes[idx]['x'] = _nodeStartPos!.dx + deltaLocal.dx;
          _nodes[idx]['y'] = _nodeStartPos!.dy + deltaLocal.dy;
          _save(local: true);
        });
      }
    } else {
      // Pan the canvas
      if (_isPanMode) {
        final delta = details.localFocalPoint - _lastFocal;
        setState(() => _offset += delta);
        _velocity = delta;
      }
    }
    _lastFocal = details.localFocalPoint;
  }

  void _onScaleEnd(ScaleEndDetails details) {
    if (_velocity.distance > 1) {
      final begin = _offset;
      final end = _offset + _velocity * 20;
      final curve =
          CurvedAnimation(parent: _inertiaController, curve: Curves.decelerate);
      _inertiaAnimation = Tween(begin: begin, end: end).animate(curve)
        ..addListener(() => setState(() => _offset = _inertiaAnimation!.value));
      _inertiaController
        ..reset()
        ..forward();
    }
    
    // Sync dragged node position
    if (_draggingNodeId != null) {
      final node = _nodes.firstWhere((n) => n['id'] == _draggingNodeId, orElse: () => {});
      if (node.isNotEmpty) {
        _syncNode(node);
      }
    }

    // Clear any node-drag state
    _draggingNodeId = null;
    _dragStartLocal = null;
    _nodeStartPos = null;
  }

  void _resetView() => setState(() {
        _scale = 1.0;
        _offset = Offset.zero;
      });

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

  void _renameNode(Map<String, dynamic> node) async {
    final res = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: node['label']),
    );
    if (res != null && res.trim().isNotEmpty) {
      setState(() {
        node['label'] = res.trim();
        _save();
      });
      _syncNode(node);
    }
  }

  void _pickColor(Map<String, dynamic> node) async {
    final res = await showDialog<int>(
      context: context,
      builder: (_) => _ColorPickerDialog(initial: (node['nodeColor'] as int?) ?? defaultNodeColor),
    );
    if (res != null) {
      setState(() {
        node['nodeColor'] = res;
        _save();
      });
      _syncNode(node);
    }
  }

  void _pickIcon(Map<String, dynamic> node) async {
    final res = await showDialog<int>(
      context: context,
      builder: (_) => _IconPickerDialog(initial: node['iconCodePoint']),
    );
    if (res != null) {
      setState(() {
        node['iconCodePoint'] = res == 0 ? null : res;
        _save();
      });
      _syncNode(node);
    }
  }

  void _pickShape(Map<String, dynamic> node) async {
    final res = await showDialog<String>(
      context: context,
      builder: (_) => _ShapePickerDialog(initial: node['shape'] ?? 'rounded'),
    );
    if (res != null) {
      setState(() {
        node['shape'] = res;
        _save();
      });
      _syncNode(node);
    }
  }

  void _deleteNode(Map<String, dynamic> node) {
    setState(() {
      _nodes.removeWhere((n) => n['id'] == node['id']);
      for (final n in _nodes) {
        ((n['connectedTo'] as List?) ?? [])
            .removeWhere((l) => l['targetId'] == node['id']);
      }
      _save();
      widget.onSave?.call();
    });
    _ws.sendNodeUpdate(_projectId, 'MINDMAP_UPDATE', node['id'], {
      'action': 'DELETE'
    });
  }

  void _startLinking(Map<String, dynamic> node) {
    if (!widget.canEdit) return;
    setState(() {
      _linkingFromId = node['id'];
      _linkingToPoint = Offset(node['x'] + nodeWidth, node['y'] + nodeHeight / 2);
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

  void _showNodeMenu(Map<String, dynamic> node) {
    if (_linkingFromId != null) {
      setState(() {
        _linkingFromId = null;
        _linkingToPoint = null;
      });
    }
  // compute the global position for the node taking current transform into account
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
  // Node local coordinates -> transformed (screen) coordinates: offset + local*scale
  final nodeLocal = Offset(_toDouble(node['x']), _toDouble(node['y']));
  final transformed = _offset + nodeLocal * _scale;
  final offset = transformed;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      showMenu<String>(
        context: context,
        position: RelativeRect.fromLTRB(
          offset.dx + 50,
          offset.dy + 10,
          overlay.size.width - offset.dx,
          overlay.size.height - offset.dy,
        ),
        items: [
          PopupMenuItem(
            value: 'rename',
            child: const ListTile(
                leading: Icon(Icons.edit), title: Text('Rename')),
            onTap: () => Future.delayed(Duration.zero, () => _renameNode(node)),
          ),
          PopupMenuItem(
            value: 'color',
            child: const ListTile(
                leading: Icon(Icons.palette), title: Text('Color')),
            onTap: () => Future.delayed(Duration.zero, () => _pickColor(node)),
          ),
          PopupMenuItem(
            value: 'icon',
            child: const ListTile(
                leading: Icon(Icons.emoji_emotions), title: Text('Icon')),
            onTap: () => Future.delayed(Duration.zero, () => _pickIcon(node)),
          ),
          PopupMenuItem(
            value: 'link',
            child: const ListTile(
                leading: Icon(Icons.link), title: Text('Start Link')),
            onTap: () => Future.delayed(Duration.zero, () => _startLinking(node)),
          ),
          PopupMenuItem(
            value: 'shape',
            child: const ListTile(
                leading: Icon(Icons.category), title: Text('Shape')),
            onTap: () => Future.delayed(Duration.zero, () => _pickShape(node)),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'delete',
            child: const ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title:
                    Text('Delete', style: TextStyle(color: Colors.red))),
            onTap: () => Future.delayed(Duration.zero, () => _deleteNode(node)),
          ),
        ],
      );
    });
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
            : 'Tap canvas to create node • Drag to pan',
        textAlign: TextAlign.center,
        style: TextStyle(
            fontWeight: FontWeight.w600, color: Colors.blueGrey[800]),
      ),
    );
  }

  Widget _canvasArea() {
    return Listener(
      onPointerDown: (_) => _didPanOnCanvas = false,
      child: GestureDetector(
        key: _canvasKey,
        behavior: HitTestBehavior.translucent,
        onTapUp: (d) {
          if (_linkingFromId != null) {
            setState(() {
              _linkingFromId = null;
              _linkingToPoint = null;
            });
          } else if (!_didPanOnCanvas) {
            final localPos = _toLocal(d.localPosition);
            // Check if tap is on an existing node
            Map<String, dynamic>? tappedNode;
            for (final node in _nodes) {
              final rect = Rect.fromLTWH(
                _toDouble(node['x']),
                _toDouble(node['y']),
                _MindmapScreenState.nodeWidth,
                _MindmapScreenState.nodeHeight,
              );
              if (rect.contains(localPos)) {
                tappedNode = node;
                break;
              }
            }
            if (tappedNode != null) {
              _showNodeMenu(tappedNode);
            } else {
              _addNode(localPos);
            }
          }
        },
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        onScaleEnd: _onScaleEnd,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            return Stack(
              children: [
                // Infinite Grid Background
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GridPainter(offset: _offset, scale: _scale),
                  ),
                ),
                // Mindmap Content
                ClipRect(
                  child: Transform(
                    alignment: Alignment.topLeft,
                    transform: Matrix4.identity()
                      ..translate(_offset.dx, _offset.dy)
                      ..scale(_scale),
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
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
                        ..._nodes.map(_nodeWidget),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
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
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Node Content
          MouseRegion(
            cursor: widget.canEdit ? SystemMouseCursors.move : SystemMouseCursors.basic,
            child: AnimatedOpacity(
                duration: const Duration(milliseconds: 260),
                opacity: appeared ? 1.0 : 0.0,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 220),
                  scale: linking ? 1.06 : 1.0,
                  child: SizedBox(
                    width: _MindmapScreenState.nodeWidth,
                    height: _MindmapScreenState.nodeHeight,
                    child: _buildNodeShape(node, color, linking),
                  ),
                ),
              ),
          ),
          // Link Handle
          if (widget.canEdit)
            Positioned(
              right: -30, // Move further out for thumb access
              top: _MindmapScreenState.nodeHeight / 2 - 25, // Center vertically
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent, // Ensure touches are caught
                  onPanStart: (d) {
                    final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final local = box.globalToLocal(d.globalPosition);
                      setState(() {
                        _linkingFromId = id;
                        _linkingToPoint = _toLocal(local);
                      });
                    }
                  },
                  onPanUpdate: (d) {
                    final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final local = box.globalToLocal(d.globalPosition);
                      setState(() {
                        _linkingToPoint = _toLocal(local);
                      });
                    }
                  },
                  onPanEnd: (d) {
                    final RenderBox? box = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                    if (box != null) {
                      final local = box.globalToLocal(d.globalPosition);
                      final endPoint = _toLocal(local);
                      Map<String, dynamic>? target;
                      for (final other in _nodes) {
                        if (other['id'] == id) continue;
                        final rect = Rect.fromLTWH(
                          other['x'], 
                          other['y'], 
                          _MindmapScreenState.nodeWidth, 
                          _MindmapScreenState.nodeHeight
                        );
                        if (rect.contains(endPoint)) {
                          target = other;
                          break;
                        }
                      }
                      
                      if (target != null) {
                        _endLinking(target);
                      } else {
                        setState(() {
                          _linkingFromId = null;
                          _linkingToPoint = null;
                        });
                      }
                    }
                  },
                  child: Container(
                    width: 60, // Large hit area
                    height: 50,
                    color: Colors.transparent, // Invisible hit box
                    alignment: Alignment.center,
                    child: Container(
                      width: 24, // Visual circle
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.purple.withOpacity(0.5), // Mindmap theme color
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 4, spreadRadius: 1),
                        ]
                      ),
                      child: const Icon(Icons.add, size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNodeShape(Map<String, dynamic> node, Color color, bool linking) {
    final shape = node['shape'] ?? 'rounded';
    final content = Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node['iconCodePoint'] != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Icon(
                IconData(node['iconCodePoint'], fontFamily: 'MaterialIcons'),
                color: color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white70,
                size: 20,
              ),
            ),
          Flexible(
            child: Text(
              node['label'],
              style: TextStyle(
                color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );

    if (shape == 'circle') {
      return Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(
            color: linking ? Colors.white : color.withOpacity(0.5),
            width: linking ? 2 : 1,
          ),
        ),
        child: content,
      );
    } else if (shape == 'diamond') {
      return Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 0.785398,
            child: Container(
              width: nodeHeight * 1.2,
              height: nodeHeight * 1.2,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                border: Border.all(
                  color: linking ? Colors.white : color.withOpacity(0.5),
                  width: linking ? 2 : 1,
                ),
              ),
            ),
          ),
          content,
        ],
      );
    } else if (shape == 'triangle') {
      return Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(nodeWidth, nodeHeight),
            painter: _TrianglePainter(
              color: color.withOpacity(0.2),
              borderColor: linking ? Colors.white : color.withOpacity(0.5),
            ),
          ),
          content,
        ],
      );
    } else if (shape == 'parallelogram') {
      return Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(nodeWidth, nodeHeight),
            painter: _ParallelogramPainter(
              color: color.withOpacity(0.2),
              borderColor: linking ? Colors.white : color.withOpacity(0.5),
            ),
          ),
          content,
        ],
      );
    }

    // Default Rounded
    return GlassContainer(
      blur: 15,
      opacity: 0.2,
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: linking ? Colors.white : color.withOpacity(0.5),
        width: linking ? 2 : 1,
      ),
      child: content,
    );
  }
}

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
          _drawArrow(canvas, src, dst, paint);
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

  void _drawArrow(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final angle = (p2 - p1).direction;
    final arrowPath = Path();
    final mid = (p1 + p2) / 2;
    
    arrowPath.moveTo(mid.dx + cos(angle) * arrowSize, mid.dy + sin(angle) * arrowSize);
    arrowPath.lineTo(mid.dx + cos(angle + 2.6) * arrowSize, mid.dy + sin(angle + 2.6) * arrowSize);
    arrowPath.lineTo(mid.dx + cos(angle - 2.6) * arrowSize, mid.dy + sin(angle - 2.6) * arrowSize);
    arrowPath.close();
    
    // Draw arrow glow
    canvas.drawPath(arrowPath, Paint()..color = paint.color.withOpacity(0.4)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)..style = PaintingStyle.fill);
    canvas.drawPath(arrowPath, Paint()..color = paint.color..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_MindmapPainter old) => true;
}

class _GridPainter extends CustomPainter {
  final Offset offset;
  final double scale;
  _GridPainter({required this.offset, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.15)
      ..strokeWidth = 1.5;

    const double gridSize = 40.0;
    
    // Calculate visible world bounds
    // We want to draw grid lines that cover the screen.
    // Screen coordinate (sx, sy) corresponds to world coordinate (wx, wy) by:
    // sx = wx * scale + offset.dx
    // wx = (sx - offset.dx) / scale
    
    final double left = -offset.dx / scale;
    final double top = -offset.dy / scale;
    final double right = (size.width - offset.dx) / scale;
    final double bottom = (size.height - offset.dy) / scale;

    // Align to grid
    final double startX = (left / gridSize).floor() * gridSize;
    final double startY = (top / gridSize).floor() * gridSize;

    for (double x = startX; x < right; x += gridSize) {
      for (double y = startY; y < bottom; y += gridSize) {
         // Draw dot in screen coordinates
         final screenX = x * scale + offset.dx;
         final screenY = y * scale + offset.dy;
         canvas.drawCircle(Offset(screenX, screenY), 1.5 * scale, paint);
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
