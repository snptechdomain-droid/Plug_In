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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/utils/app_strings.dart';

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
  List<Map<String, dynamic>> _annotations = []; // New Annotations State
  String? _linkingFromId;
  Offset? _linkingToPoint;

  bool _didPanOnCanvas = false;

  String? _selectedId; // Restored public variable for state
  bool _isCommentMode = false; // New Comment Toggle State


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
  
  static const double nodeWidth = 180;
  static const double nodeHeight = 56;
  static const int defaultNodeColor = 0xFF2196F3;
  static const double kCenterOffset = 5000.0; // Optimized for mobile compatibility 
  
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
      'appeared': true, // Force visible to prevent stuck invisible nodes
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
    var data = widget.collaboration?.toolData['mindmap_nodes'];
    Map<String, dynamic>? viewData = widget.collaboration?.toolData['mindmap_view'];

    if (data == null && widget.collaboration?.toolData['mindmapData'] != null) {
       try {
         final decoded = jsonDecode(widget.collaboration!.toolData['mindmapData']);
         data = decoded['nodes'];
         if (decoded['view'] != null) {
            viewData = Map<String, dynamic>.from(decoded['view']);
         }
         // Load Annotations
         if (decoded['annotations'] != null) {
            _annotations = List<Map<String, dynamic>>.from(decoded['annotations']);
         }
       } catch (e) {
         print('Error parsing mindmapData: $e');
       }
    }

    // Restore View
    if (viewData != null && viewData['matrix'] != null) {
      try {
        final List<double> matrixList = List<double>.from(viewData['matrix']);
        if (matrixList.length == 16) {
           _transformationController.value = Matrix4.fromList(matrixList);
           // Update local offset/scale for grid
           WidgetsBinding.instance.addPostFrameCallback((_) {
             setState(() {
                _scale = _transformationController.value.getMaxScaleOnAxis();
                _offset = Offset(_transformationController.value.getTranslation().x, _transformationController.value.getTranslation().y);
             });
           });
        }
      } catch (e) {
        print('Error restoring view: $e');
      }
    }

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
     final size = MediaQuery.of(context).size;
     // Center the view on (0,0) data coordinates => (25000, 25000) UI coordinates
     final dx = -kCenterOffset + size.width / 2;
     final dy = -kCenterOffset + size.height / 2;
     
     _transformationController.value = Matrix4.identity()..translate(dx, dy);
     setState(() {
        _scale = 1.0;
        _offset = Offset(dx, dy);
     });
  }

  // Adjusted to rely on the tracking variables synced in onInteractionUpdate
  Offset _toLocal(Offset global) => (global - _offset) / _scale;

  void _save({bool local = false}) {
    if (!widget.canEdit) return;
    if (widget.collaboration != null) {
      widget.collaboration!.toolData['mindmap_nodes'] = _nodes;
      // Save annotations
      widget.collaboration!.toolData['mindmap_annotations'] = _annotations; 
      // Save viewport state
      widget.collaboration!.toolData['mindmap_view'] = {
        'matrix': _transformationController.value.storage.toList(),
      };
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

  void _addSmartChild(Map<String, dynamic> parent) {
    if (!widget.canEdit) return;
    
    final px = _toDouble(parent['x']);
    final py = _toDouble(parent['y']);
    
    // Smart Placement Logic: Try to find a spot to the right
    double cx = px + 240; // Horizontal spacing
    double cy = py;
    
    // Scan vertical slots until we find space
    int attempts = 0;
    while (_isOverlapping(Offset(cx, cy)) && attempts < 20) {
      if (attempts % 2 == 0) {
        cy = py + ((attempts/2 + 1) * 90); // Down
      } else {
        cy = py - ((attempts/2 + 1) * 90); // Up
      }
      attempts++;
    }
    
    _addNodeAt(Offset(cx, cy), parentId: parent['id']);
  }
  
  bool _isOverlapping(Offset pos) {
    const double w = 180;
    const double h = 56;
    final r = Rect.fromLTWH(pos.dx, pos.dy, w, h).inflate(20);
    
    for (final n in _nodes) {
      final nx = _toDouble(n['x']);
      final ny = _toDouble(n['y']);
      if (r.overlaps(Rect.fromLTWH(nx, ny, w, h))) return true;
    }
    return false;
  }

  void _addNode(Offset uiPos) {
    // uiPos is in 0..50000 space
    // Convert to Data Space
    _addNodeAt(uiPos - Offset(kCenterOffset, kCenterOffset));
  }

  void _addNodeAt(Offset dataPos, {String? parentId}) {
     if (!widget.canEdit) return;
     // Helper: dataPos is already -25k..25k
     final id = DateTime.now().millisecondsSinceEpoch.toString();
     
     final newNode = {
        'id': id,
        'x': dataPos.dx,
        'y': dataPos.dy,
        'label': 'New Idea',
        'shape': 'rounded',
        'connectedTo': <Map<String, dynamic>>[],
        'nodeColor': defaultNodeColor,
        'iconCodePoint': null,
        'appeared': false,
     };
     
     // Link if parent provided
     if (parentId != null) {
        final parentIndex = _nodes.indexWhere((n) => n['id'] == parentId);
        if (parentIndex != -1) {
           final parent = _nodes[parentIndex];
           final link = {
              'targetId': id,
              'style': 'curved',
              'color': parent['nodeColor'] ?? defaultNodeColor
           };
           (parent['connectedTo'] as List).add(link);
           _syncNode(parent); // Sync parent update
        }
     }

     setState(() {
       _nodes.add(newNode);
     });
     
     _save();
     _syncNode(newNode);

     // Animate appearance
     Future.delayed(const Duration(milliseconds: 50), () {
        if (!mounted) return;
        final idx = _nodes.indexWhere((e) => e['id'] == id);
        if (idx != -1) {
          setState(() => _nodes[idx]['appeared'] = true);
        }
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
          Positioned(
            right: 20,
            bottom: 20,
            child: Minimap(

              items: [
                ..._nodes.map((n) => MinimapItem(
                  x: _toDouble(n['x']) + kCenterOffset,
                  y: _toDouble(n['y']) + kCenterOffset,
                  width: _MindmapScreenState.nodeWidth,
                  height: _MindmapScreenState.nodeHeight,
                  color: Color((n['nodeColor'] as int?) ?? _MindmapScreenState.defaultNodeColor),
                )),
                ..._annotations.map((a) => MinimapItem(
                  x: _toDouble(a['x']) + kCenterOffset,
                  y: _toDouble(a['y']) + kCenterOffset,
                  width: _toDouble(a['width']),
                  height: _toDouble(a['height']),
                  color: Color((a['color'] as int?) ?? 0xFF9E9E9E).withOpacity(0.5),
                )),
              ],
              viewTransform: _transformationController.value, 
              viewportSize: MediaQuery.of(context).size,
              onViewChanged: (matrix) {
                // Determine new offset/scale from matrix
                // We must update the controller AND the state variables
                _transformationController.value = matrix;
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
        if (widget.canEdit)
          IconButton(
            icon: Icon(Icons.note_add_outlined, color: _isCommentMode ? Colors.orange : Colors.indigo),
            tooltip: _isCommentMode ? 'Tap canvas to place Note' : 'Toggle Note Mode',
            onPressed: () {
               setState(() => _isCommentMode = !_isCommentMode);
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text(_isCommentMode ? 'Tap canvas to add Note' : 'Note mode disabled'), duration: const Duration(milliseconds: 800)),
               );
            },
          ),
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
                              _annotations.clear();
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
              // If we reached here, the tap was NOT on a node (child won gesture arena)
              // So this is a BACKGROUND tap.

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
                 final worldPos = _toLocal(d.localPosition);
                 if (_isCommentMode) {
                    _addAnnotationAt(worldPos);
                    // Optional: Disable mode after adding? Or keep it enabled? 
                    // User said "if toggled then on click inserts", implies persistent mode until untoggled or single use.
                    // Let's keep it persistent for now or toggle off for UX safety.
                    setState(() => _isCommentMode = false); // Auto-turn off after one
                 } else {
                    _addNode(worldPos);
                 }
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
                   fit: StackFit.expand,
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
                       // Annotations (Behind nodes)
                       ..._annotations.map(_buildAnnotation),

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
      left: _toDouble(node['x']) + kCenterOffset,
      top: _toDouble(node['y']) + kCenterOffset,
      child: SizedBox(
        width: _MindmapScreenState.nodeWidth, // Match exact content width
        height: _MindmapScreenState.nodeHeight, // Match exact content height
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Node Content
            Positioned.fill(
                child: MouseRegion(
                  cursor: widget.canEdit ? SystemMouseCursors.click : SystemMouseCursors.basic,
                  child: GestureDetector(
                    onTap: () {
                       if (_linkingFromId != null) {
                          if (_linkingFromId != id) {
                             // Assuming _endLinking takes a map, but we have the ID and data here
                             // We can reconstruct the map or pass the node map if available in closure
                             _endLinking(node); 
                          }
                       } else {
                          setState(() => _selectedId = id);
                       }
                    },
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
    final hasLink = (node['link'] as String?)?.isNotEmpty ?? false;
    
    final content = Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (node['iconCodePoint'] != null)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Text(
                String.fromCharCode(node['iconCodePoint']),
                style: TextStyle(
                  fontFamily: 'MaterialIcons',
                  color: color,
                  fontSize: 20,
                ),
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
            ),
          ),
          if (hasLink)
            Padding(
               padding: const EdgeInsets.only(left: 4.0),
               child: Icon(Icons.link, size: 14, color: Colors.blue.shade400),
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

    final x = _toDouble(node['x']) + kCenterOffset;
    final y = _toDouble(node['y']) + kCenterOffset;
    final hasLink = (node['link'] as String?)?.isNotEmpty ?? false;
    
    // Position toolbar above the node
    return Positioned(
      left: x + nodeWidth / 2 - 120, // Slightly wider to accommodate new button
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
               _toolbarBtn(Icons.add_circle, () => _addSmartChild(node), color: Colors.blue), // Smart Add
               _toolbarBtn(Icons.linear_scale, () { // Renamed from link to avoid confusion
                  setState(() {
                    _linkingFromId = node['id'];
                    _linkingToPoint = Offset(x + nodeWidth/2, y + nodeHeight/2);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tap another node to connect'), duration: Duration(milliseconds: 1000)),
                  );
               }),
               _toolbarBtn(hasLink ? Icons.link_off : Icons.add_link, () => _editNodeURL(node), color: hasLink ? Colors.blue : Colors.black87),
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

  Future<void> _editNodeURL(Map<String, dynamic> node) async {
    final initial = (node['link'] as String?) ?? '';
    final ctrl = TextEditingController(text: initial);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Attachment / Link'),
        content: TextField(
          controller: ctrl, 
          decoration: const InputDecoration(
            labelText: 'URL',
            hintText: 'https://example.com',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Save')),
        ],
      ),
    );

    if (result != null) {
      final updated = Map<String, dynamic>.from(node);
      updated['link'] = result;
      _syncNode(updated);
    }
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



  // ✨ Big Box / Annotation Builder
  Widget _buildAnnotation(Map<String, dynamic> data) {
    // Offset relative to CenterOffset (5000)
    final double x = _toDouble(data['x']) + kCenterOffset;
    final double y = _toDouble(data['y']) + kCenterOffset;
    final double w = _toDouble(data['width']) == 0 ? 300.0 : _toDouble(data['width']);
    final double h = _toDouble(data['height']) == 0 ? 200.0 : _toDouble(data['height']);
    final String title = data['label'] ?? 'Comment';
    final String text = data['text'] ?? '';
    final int colorVal = (data['color'] as int?) ?? 0xFF9E9E9E; // Default Grey
    final Color color = Color(colorVal);

    return Positioned(
      left: x,
      top: y,
      child: GestureDetector(
         onPanUpdate: widget.canEdit ? (d) {
            setState(() {
               data['x'] = _toDouble(data['x']) + d.delta.dx;
               data['y'] = _toDouble(data['y']) + d.delta.dy;
            });
         } : null,
         onPanEnd: widget.canEdit ? (_) => _save() : null,
         onDoubleTap: widget.canEdit ? () {
            // Edit Text
            _editAnnotation(data);
         } : null,
         child: SizedBox(
           width: w,
           height: h,
           child: GlassContainer(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.3), width: 1.5),
              blur: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   // Header
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                     decoration: BoxDecoration(
                        color: color.withOpacity(0.2),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                     ),
                     child: Text(
                        title, 
                        style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)
                     ),
                   ),
                   // Body
                   Expanded(
                     child: Padding(
                       padding: const EdgeInsets.all(12.0),
                       child: Text(
                          text, 
                          style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87)
                       ),
                     ),
                   ),
                   // Resize Handle (Corner)
                   if (widget.canEdit)
                   Align(
                     alignment: Alignment.bottomRight,
                     child: GestureDetector(
                        onPanUpdate: (d) {
                           setState(() {
                              data['width'] = w + d.delta.dx;
                              data['height'] = h + d.delta.dy;
                           });
                        },
                        onPanEnd: (_) => _save(),
                        child: Icon(Icons.drag_handle_rounded, size: 20, color: color.withOpacity(0.5)),
                     ),
                   )
                ],
              ),
           ),
         ),
      ),
    );
  }

  Future<void> _editAnnotation(Map<String, dynamic> data) async {
      if (!widget.canEdit) return;
      final titleCtrl = TextEditingController(text: data['label']);
      final contentCtrl = TextEditingController(text: data['text']);
      int selectedColor = (data['color'] as int?) ?? 0xFF2196F3;
      
      final prefs = await SharedPreferences.getInstance();
      final lang = prefs.getString('language') ?? 'English';

      await showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(AppStrings.tr('edit', lang)), // "Edit"
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                   TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Header')),
                   TextField(controller: contentCtrl, decoration: const InputDecoration(labelText: 'Content'), maxLines: 3),
                   const SizedBox(height: 16),
                   Align(alignment: Alignment.centerLeft, child: Text(AppStrings.tr('comment_color', lang), style: const TextStyle(fontWeight: FontWeight.bold))),
                   const SizedBox(height: 8),
                   Wrap(
                     spacing: 8,
                     children: [
                        0xFFE53935, // Red
                        0xFF43A047, // Green
                        0xFF1E88E5, // Blue
                        0xFFFFB300, // Amber
                        0xFF9E9E9E, // Grey
                        0xFF9C27B0, // Purple
                     ].map((c) => GestureDetector(
                        onTap: () => setState(() => selectedColor = c),
                        child: CircleAvatar(
                           backgroundColor: Color(c),
                           radius: 16,
                           child: selectedColor == c ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                        ),
                     )).toList(),
                   )
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () { 
                   // Delete
                   Navigator.pop(ctx);
                   setState(() {
                      _annotations.remove(data);
                      _save();
                   });
                }, 
                child: Text(AppStrings.tr('delete', lang), style: const TextStyle(color: Colors.red))
              ),
              ElevatedButton(
                onPressed: () {
                   Navigator.pop(ctx);
                   setState(() {
                      data['label'] = titleCtrl.text;
                      data['text'] = contentCtrl.text;
                      data['color'] = selectedColor;
                      _save();
                   });
                },
                child: Text(AppStrings.tr('save', lang))
              )
            ],
          ),
        )
      );
  }

  void _addAnnotationAt(Offset pos) {
     setState(() {
        _annotations.add({
           'id': DateTime.now().millisecondsSinceEpoch.toString(),
           'x': pos.dx - kCenterOffset, // Correct for center offset
           'y': pos.dy - kCenterOffset,
           'width': 300.0,
           'height': 200.0,
           'label': 'New Group',
           'text': 'Add description here...',
           'color': 0xFF2196F3, // Blue
        });
        _save();
     });
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
    // Shift canvas to center
    canvas.save();
    canvas.translate(_MindmapScreenState.kCenterOffset, _MindmapScreenState.kCenterOffset);

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

        // Cubic Bezier for Organic Feel
        final Path path = Path();
        path.moveTo(src.dx, src.dy);

        final dist = (dst.dx - src.dx).abs();
        final cp1 = Offset(src.dx + dist * 0.5, src.dy);
        final cp2 = Offset(dst.dx - dist * 0.5, dst.dy);
        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, dst.dx, dst.dy);

        if (link['dashed'] == true) {
          _drawDashedPath(canvas, path, paint);
        } else {
          canvas.drawPath(path, glowPaint);
          canvas.drawPath(path, paint);
        }

        if (link['arrow'] == true) {
           // Calculate tangent at end for arrow
           var tangent = dst - cp2;
           if (tangent.distance < 0.1) tangent = dst - cp1;
           _drawArrowTip(canvas, dst, tangent.direction, color);
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
    canvas.restore();
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

  void _drawArrowTip(Canvas canvas, Offset tip, double angle, Color color) {
      final arrowPath = Path();
      const size = 6.0;
      final back = angle + pi; 
      
      arrowPath.moveTo(tip.dx, tip.dy);
      arrowPath.lineTo(tip.dx + cos(back + 0.5) * size * 2.5, tip.dy + sin(back + 0.5) * size * 2.5);
      arrowPath.lineTo(tip.dx + cos(back - 0.5) * size * 2.5, tip.dy + sin(back - 0.5) * size * 2.5);
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
