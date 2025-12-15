import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:convert';
import 'dart:async';
import 'package:app/models/collaboration.dart'; // We might need to update this model or use a Map for now since backend returns Map
import 'flowchart_screen.dart';
import 'mindmap_screen.dart';
import 'timeline_screen.dart';
import 'package:app/services/role_database_service.dart';
import 'package:app/services/websocket_service.dart';
import 'package:app/models/role.dart';

class CollaborationScreen extends StatefulWidget {
  const CollaborationScreen({super.key});

  @override
  State<CollaborationScreen> createState() => _CollaborationScreenState();
}

// Simple delegate used to host the content of a header that can collapse/expand
class _SimpleHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double minExtentValue;
  final double maxExtentValue;
  final Widget child;

  _SimpleHeaderDelegate({required this.minExtentValue, required this.maxExtentValue, required this.child});

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox.expand(child: child);
  }

  @override
  double get maxExtent => maxExtentValue;

  @override
  double get minExtent => minExtentValue;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
}

class _CollaborationScreenState extends State<CollaborationScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _selectedProject;
  late TabController _tabController;
  late String _currentUserEmail;
  late TextEditingController _titleController;

  final _roleDatabase = RoleBasedDatabaseService();
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;
  bool _isHeaderPinned = false; // mobile: whether the header is pinned (not collapsible)
  bool _isMobileHeaderExpanded = true; // mobile: toggle visibility

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Added Polls tab
    _titleController = TextEditingController();
    _loadData();
    
    // Listen for real-time updates
    WebSocketService().nodeStream.listen((msg) {
      if (!mounted) return;
      if (msg['type'] == 'POLL_UPDATE') {
        _loadData(); // Reload polls when an update is received
      }
    });
  }

  @override
  void dispose() {
    WebSocketService().disconnect();
    _tabController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final user = await _roleDatabase.getCurrentUser();
    if (user == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    _currentUserEmail = user.email;

    final projects = await _roleDatabase.getUserProjects(_currentUserEmail);
    
    if (mounted) {
      setState(() {
        _projects = projects;
        _isLoading = false;
        if (_projects.isNotEmpty && _selectedProject == null) {
          _selectedProject = _projects.first;
          _titleController.text = _selectedProject!['title'];
        } else if (_selectedProject != null) {
           // Refresh selected project with new data
           final updated = _projects.firstWhere((p) => p['id'] == _selectedProject!['id'], orElse: () => _selectedProject!);
           _selectedProject = updated;
        }
      });
      if (_selectedProject != null) {
        WebSocketService().connect(_selectedProject!['id'], _currentUserEmail);
      }
    }
  }

  Future<void> _createNewProject() async {
    final titleController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Project'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(labelText: 'Project Title'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result == true && titleController.text.isNotEmpty) {
      final newProject = await _roleDatabase.createProject(titleController.text, _currentUserEmail);
      if (newProject != null) {
        await _loadData();
        setState(() {
          _selectedProject = _projects.firstWhere((p) => p['id'] == newProject['id']);
          _titleController.text = _selectedProject!['title'];
        });
      }
    }
  }

  Future<void> _addMember() async {
    if (_selectedProject == null) return;
    
    final allUsers = await _roleDatabase.getAllUsers();
    UserLoginDetails? selectedUser;
    String selectedRole = 'EDITOR';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<UserLoginDetails>(
                displayStringForOption: (UserLoginDetails option) => option.username,
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text == '') return const Iterable.empty();
                  return allUsers.where((UserLoginDetails user) {
                    return user.username
                        .toLowerCase()
                        .contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (UserLoginDetails selection) {
                  selectedUser = selection;
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  return TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Search User',
                      hintText: 'Type username...',
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Role'),
                items: const [
                  DropdownMenuItem(value: 'EDITOR', child: Text('Editor')),
                  DropdownMenuItem(value: 'VIEWER', child: Text('Viewer')),
                ],
                onChanged: (val) => setState(() => selectedRole = val!),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedUser != null) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );

    if (result == true && selectedUser != null) {
      final success = await _roleDatabase.addMemberToProject(
        _selectedProject!['id'], 
        selectedUser!.email, // Assuming API matches by email/username
        role: selectedRole,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member added successfully')));
        _loadData(); 
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to add member')));
      }
    }
  }

  // --- Polls UI ---
  Widget _buildPollsTab() {
    if (_selectedProject == null) return const SizedBox.shrink();
    final List<dynamic> polls = _selectedProject!['polls'] ?? [];

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: _createPoll,
            icon: const Icon(Icons.poll),
            label: const Text('Create Poll'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: polls.length,
            itemBuilder: (context, index) {
              final poll = polls[index];
              final isOwner = poll['creatorId'] == _currentUserEmail || _selectedProject!['ownerId'] == _currentUserEmail;
              final isMultiSelect = poll['multiSelect'] == true;
              final isActive = poll['active'] != false;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Colors.deepPurple.shade50],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    poll['question'],
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.deepPurple),
                                  ),
                                  if (isMultiSelect)
                                    Container(
                                      margin: const EdgeInsets.only(top: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade100,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text('Multi-select', style: TextStyle(fontSize: 10, color: Colors.blue.shade900)),
                                    ),
                                ],
                              ),
                            ),
                            if (isOwner)
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(isActive ? Icons.stop_circle_outlined : Icons.play_circle_outline, color: isActive ? Colors.orange : Colors.green),
                                    tooltip: isActive ? 'Close Poll' : 'Re-open Poll',
                                    onPressed: () => _togglePollStatus(poll['id']),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                                    onPressed: () => _deletePoll(poll['id']),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...List.generate((poll['options'] as List).length, (optIndex) {
                          final option = poll['options'][optIndex];
                          final votesMap = poll['votes'] as Map<String, dynamic>? ?? {};
                          
                          int voteCount = 0;
                          bool isVotedByMe = false;
                          
                          votesMap.forEach((userId, userVotes) {
                            if (userVotes is int) {
                              if (userVotes == optIndex) voteCount++;
                              if (userId == _currentUserEmail && userVotes == optIndex) isVotedByMe = true;
                            } else if (userVotes is List) {
                              if (userVotes.contains(optIndex)) voteCount++;
                              if (userId == _currentUserEmail && userVotes.contains(optIndex)) isVotedByMe = true;
                            }
                          });

                          final totalVotes = votesMap.length; // Approximate unique voters
                          // Calculate total distinct votes for percentage if multi-select? 
                          // Usually percentage is based on total voters or total votes cast. 
                          // Let's use total voters for "What % of people chose this".
                          final percentage = totalVotes > 0 ? voteCount / totalVotes : 0.0;

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: InkWell(
                              onTap: isActive ? () => _votePoll(poll['id'], optIndex) : null,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: isVotedByMe ? Colors.deepPurple : Colors.grey.shade300, width: isVotedByMe ? 2 : 1),
                                  borderRadius: BorderRadius.circular(12),
                                  color: isVotedByMe ? Colors.deepPurple.withOpacity(0.05) : Colors.white,
                                  boxShadow: [
                                    if (isVotedByMe)
                                      BoxShadow(color: Colors.deepPurple.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
                                  ],
                                ),
                                child: Stack(
                                  children: [
                                    FractionallySizedBox(
                                      widthFactor: percentage.clamp(0.0, 1.0),
                                      child: Container(
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: isVotedByMe ? Colors.deepPurple.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(11),
                                        ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              option,
                                              style: TextStyle(
                                                fontWeight: isVotedByMe ? FontWeight.bold : FontWeight.normal,
                                                color: isVotedByMe ? Colors.deepPurple : Colors.black87,
                                              ),
                                            ),
                                          ),
                                          if (isVotedByMe)
                                            const Padding(
                                              padding: EdgeInsets.only(right: 8.0),
                                              child: Icon(Icons.check_circle, size: 16, color: Colors.deepPurple),
                                            ),
                                          Text(
                                            '${(percentage * 100).toStringAsFixed(1)}%',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isVotedByMe ? Colors.deepPurple : Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${poll['votes']?.length ?? 0} voters',
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                            if (!isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(color: Colors.red.shade100, borderRadius: BorderRadius.circular(4)),
                                child: Text('Closed', style: TextStyle(color: Colors.red.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _createPoll() async {
    if (_selectedProject == null) return;
    final questionController = TextEditingController();
    List<TextEditingController> optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
    bool multiSelect = false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create Poll'),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: questionController,
                    decoration: const InputDecoration(
                      labelText: 'Question',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Options', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...List.generate(optionControllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: optionControllers[index],
                              decoration: InputDecoration(
                                labelText: 'Option ${index + 1}',
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                          if (optionControllers.length > 2)
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                              onPressed: () {
                                setState(() {
                                  optionControllers.removeAt(index);
                                });
                              },
                            ),
                        ],
                      ),
                    );
                  }),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        optionControllers.add(TextEditingController());
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Add Option'),
                  ),
                  const Divider(),
                  SwitchListTile(
                    title: const Text('Allow Multiple Selections'),
                    value: multiSelect,
                    onChanged: (val) => setState(() => multiSelect = val),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, foregroundColor: Colors.white),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true && questionController.text.isNotEmpty) {
      final options = optionControllers.map((c) => c.text).where((s) => s.isNotEmpty).toList();
      if (options.length < 2) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least 2 options required')));
        return;
      }
      final success = await _roleDatabase.createPoll(_selectedProject!['id'], questionController.text, options, multiSelect: multiSelect);
      if (success) {
        _loadData();
        WebSocketService().sendNodeUpdate(_selectedProject!['id'], 'POLL_UPDATE', 'poll', {'action': 'CREATE'});
      }
    }
  }

  Future<void> _votePoll(String pollId, int optionIndex) async {
    if (_selectedProject == null) return;
    final success = await _roleDatabase.votePoll(_selectedProject!['id'], pollId, _currentUserEmail, optionIndex);
    if (success) {
      _loadData();
      WebSocketService().sendNodeUpdate(_selectedProject!['id'], 'POLL_UPDATE', pollId, {'action': 'VOTE'});
    }
  }

  Future<void> _deletePoll(String pollId) async {
    if (_selectedProject == null) return;
    final success = await _roleDatabase.deletePoll(_selectedProject!['id'], pollId);
    if (success) {
      _loadData();
      WebSocketService().sendNodeUpdate(_selectedProject!['id'], 'POLL_UPDATE', pollId, {'action': 'DELETE'});
    }
  }

  Future<void> _togglePollStatus(String pollId) async {
    if (_selectedProject == null) return;
    final success = await _roleDatabase.togglePollStatus(_selectedProject!['id'], pollId);
    if (success) {
      _loadData();
      WebSocketService().sendNodeUpdate(_selectedProject!['id'], 'POLL_UPDATE', pollId, {'action': 'TOGGLE_STATUS'});
    }
  }

  // --- Widget Builders ---

  Widget _buildCollaborationList(BuildContext context, bool isMobile) {
    final theme = Theme.of(context);
    return Material(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16.0, right: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Projects', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_box_outlined, color: Colors.green),
                  onPressed: _createNewProject,
                  tooltip: 'New Project',
                ),
              ],
            ),
          ),
          if (_isLoading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                itemCount: _projects.length,
                itemBuilder: (context, index) {
                  final p = _projects[index];
                  final isSelected = _selectedProject != null && _selectedProject!['id'] == p['id'];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
                    child: ListTile(
                      title: Text(p['title'], overflow: TextOverflow.ellipsis),
                      subtitle: Text('Owner: ${p['ownerId']}'),
                      selected: isSelected,
                      selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        setState(() {
                          _selectedProject = p;
                          _titleController.text = p['title'];
                        });
                        WebSocketService().disconnect(); // Disconnect previous
                        WebSocketService().connect(p['id'], _currentUserEmail); // Connect new
                        if (isMobile) Navigator.of(context).pop();
                      },
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDrawerMenuItem({
    required BuildContext context,
    String? lottieAsset,
    IconData? icon,
    required String title,
    required String routeName,
  }) {
    return ListTile(
      leading: lottieAsset != null 
          ? Lottie.asset(lottieAsset, width: 30, height: 30, repeat: true, animate: true)
          : Icon(icon, size: 24, color: Theme.of(context).iconTheme.color),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      onTap: () {
        Navigator.of(context).pop(); // Close drawer
        Navigator.of(context).pushReplacementNamed(routeName);
      },
    );
  }

  Widget _buildContentHeader(ThemeData theme, bool canEdit) {
    if (_selectedProject == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: canEdit ? Colors.green[50] : Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Flexible(
            child: Text(
              _selectedProject!['title'],
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
          Chip(
            label: Text(canEdit ? 'Editable' : 'Read-only'),
            backgroundColor: canEdit ? Colors.green[200] : Colors.grey[300],
            labelStyle: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (canEdit)
            ElevatedButton.icon(
              onPressed: _addMember,
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Add Member'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMobileHeader(ThemeData theme, bool canEdit) {
    // A small drag handle and pin indicator, followed by actual header content
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Drag handle row
        Container(
          width: double.infinity,
          color: theme.scaffoldBackgroundColor,
          padding: const EdgeInsets.only(top: 6, bottom: 6, left: 8, right: 8),
          child: Row(
            children: [
              const Expanded(child: SizedBox()),
              Container(width: 40, height: 6, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(4))),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(_isHeaderPinned ? Icons.push_pin : Icons.push_pin_outlined, size: 18),
                tooltip: _isHeaderPinned ? 'Unpin header' : 'Pin header',
                color: theme.colorScheme.primary,
                onPressed: () => setState(() => _isHeaderPinned = !_isHeaderPinned),
              ),
            ],
          ),
        ),
        // Actual header body
        _buildContentHeader(theme, canEdit),
      ],
    );
  }

  Collaboration? _currentCollaboration;

  Timer? _debounceTimer;

  Future<void> _saveCollaborationData() async {
    if (_selectedProject == null || _currentCollaboration == null) return;

    // Debounce the save operation (wait 1 second after last change)
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    
    _debounceTimer = Timer(const Duration(seconds: 1), () async {
      if (!mounted) return;
      
      final toolData = _currentCollaboration!.toolData;
      print('Auto-saving data... ToolData keys: ${toolData.keys}'); // DEBUG
      
      String? flowchartData;
      if (toolData.containsKey('flowchart_nodes')) {
        flowchartData = jsonEncode({
          'flowchart_nodes': toolData['flowchart_nodes'],
          'flowchart_annotations': toolData['flowchart_annotations'],
          'flowchart_connections': toolData['flowchart_connections'],
        });
      }

      String? mindmapData;
      if (toolData.containsKey('mindmap_nodes')) {
        mindmapData = jsonEncode(toolData['mindmap_nodes']);
      }

      String? timelineData;
      if (toolData.containsKey('timeline_milestones')) {
        timelineData = jsonEncode(toolData['timeline_milestones']);
        print('Saving Timeline Data: $timelineData'); // DEBUG
      } else {
        print('No timeline_milestones found in toolData'); // DEBUG
      }

      final success = await _roleDatabase.updateProjectData(
        _selectedProject!['id'],
        flowchartData: flowchartData,
        mindmapData: mindmapData,
        timelineData: timelineData,
      );
      
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to auto-save data')));
      }
      // Success is silent for auto-save
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool canEdit = _selectedProject != null && (_selectedProject!['ownerId'] == _currentUserEmail || (_selectedProject!['collaboratorIds'] as List).contains(_currentUserEmail));

    // Initialize _currentCollaboration if needed
    if (_selectedProject != null && (_currentCollaboration == null || _currentCollaboration!.id != _selectedProject!['id'])) {
       _currentCollaboration = Collaboration(
        id: _selectedProject!['id'],
        title: _selectedProject!['title'],
        leads: [_selectedProject!['ownerId']],
        members: List<String>.from(_selectedProject!['collaboratorIds'] ?? []),
        toolData: {
          if (_selectedProject!['flowchartData'] != null && (_selectedProject!['flowchartData'] as String).isNotEmpty)
            ...(){ 
              try { 
                return jsonDecode(_selectedProject!['flowchartData']) as Map<String, dynamic>; 
              } catch(e) { 
                print('Error parsing flowchartData: $e'); 
                return <String, dynamic>{}; 
              } 
            }(),
          if (_selectedProject!['mindmapData'] != null && (_selectedProject!['mindmapData'] as String).isNotEmpty)
            'mindmap_nodes': (){ 
              try { 
                return jsonDecode(_selectedProject!['mindmapData']); 
              } catch(e) { 
                print('Error parsing mindmapData: $e'); 
                return []; 
              } 
            }(),
          if (_selectedProject!['timelineData'] != null && (_selectedProject!['timelineData'] as String).isNotEmpty)
            'timeline_milestones': (){ 
              try { 
                return jsonDecode(_selectedProject!['timelineData']); 
              } catch(e) { 
                print('Error parsing timelineData: $e'); 
                return []; 
              } 
            }(),
        },
      );
    } else if (_selectedProject == null) {
      _currentCollaboration = null;
    }

    final List<Widget> tabChildren = _selectedProject == null
        ? <Widget>[]
        : <Widget>[
            FlowchartScreen(collaboration: _currentCollaboration, canEdit: canEdit, onSave: _saveCollaborationData),
            MindmapScreen(collaboration: _currentCollaboration, canEdit: canEdit, onSave: _saveCollaborationData),
            TimelineScreen(collaboration: _currentCollaboration, canEdit: canEdit, onSave: _saveCollaborationData),
            _buildPollsTab(),
          ];

    final emptyState = Center(
      child: Card(
        margin: const EdgeInsets.all(24),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.group_work, size: 64, color: theme.colorScheme.primary),
              const SizedBox(height: 16),
              Text('No Project Selected', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                'Select a project from the list or create a new one.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        if (isMobile) {
          return Scaffold(
            drawer: Drawer(
              child: Column(
                children: [
                  DrawerHeader(
                    decoration: BoxDecoration(color: theme.colorScheme.primary),
                    child: Center(
                      child: Text('Navigation', style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  _buildDrawerMenuItem(context: context, icon: Icons.home, title: 'Home', routeName: '/dashboard'),
                  _buildDrawerMenuItem(context: context, icon: Icons.co_present, title: 'Attendance', routeName: '/attendance'),
                  _buildDrawerMenuItem(context: context, icon: Icons.event, title: 'Events', routeName: '/events'),
                  _buildDrawerMenuItem(context: context, icon: Icons.logout, title: 'Logout', routeName: '/login'),
                  const Divider(height: 1),
                  Expanded(child: _buildCollaborationList(context, isMobile)),
                ],
              ),
            ),
            appBar: null,
            body: _selectedProject == null
                ? emptyState
                : SafeArea(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                      // Collapsible Header Area
                      // Collapsible Header Area
                      if (_isMobileHeaderExpanded)
                        Container(
                           color: theme.scaffoldBackgroundColor,
                           child: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                                // Custom Header
                                Container(
                                  decoration: BoxDecoration(
                                    color: theme.scaffoldBackgroundColor,
                                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
                                        child: Row(
                                          children: [
                                            // Drawer Button
                                            Builder(builder: (c) => IconButton(
                                              icon: const Icon(Icons.menu), 
                                              onPressed: () => Scaffold.of(c).openDrawer()
                                            )),
                                            // Title
                                            Expanded(
                                              child: Text(
                                                _selectedProject?['title'] ?? 'Collaboration',
                                                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // TabBar
                                      TabBar(
                                        controller: _tabController,
                                        isScrollable: true,
                                        labelColor: theme.colorScheme.primary,
                                        unselectedLabelColor: theme.disabledColor,
                                        indicatorColor: theme.colorScheme.primary,
                                        tabs: const [Tab(text: 'Flow'), Tab(text: 'Mind'), Tab(text: 'Time'), Tab(text: 'Polls')],
                                      ),
                                    ],
                                  ),
                                ),
                               _buildMobileHeader(theme, canEdit),
                             ],
                           ),
                        ),
                      // Toggle Handle
                      GestureDetector(
                        onTap: () => setState(() => _isMobileHeaderExpanded = !_isMobileHeaderExpanded),
                        child: Container(
                          width: double.infinity,
                          height: 24,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.2))),
                          ),
                          child: Icon(
                            _isMobileHeaderExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                            size: 20,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      // Main Content
                      Expanded(
                        child: Container(
                           color: theme.scaffoldBackgroundColor, // Ensure background is not black
                           child: TabBarView(
                              controller: _tabController,
                              physics: const NeverScrollableScrollPhysics(), // Disable swipe
                              children: tabChildren,
                           ),
                        ),
                      ),
                    ],
                  ),
                ),
          );
        } else {
          return Row(
            children: [
              Container(
                width: 260,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(right: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Material(
                  color: theme.cardColor,
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      ListTile(
                        leading: const Icon(Icons.arrow_back),
                        title: const Text('Back to Dashboard'),
                        onTap: () => Navigator.of(context).pushReplacementNamed('/dashboard'),
                      ),
                      const Divider(),
                      Expanded(child: _buildCollaborationList(context, isMobile)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text('Workspace'),
                    automaticallyImplyLeading: false,
                    bottom: _selectedProject == null
                        ? null
                        : TabBar(
                            controller: _tabController,
                            tabs: const [Tab(text: 'Flowchart'), Tab(text: 'Mindmap'), Tab(text: 'Timeline'), Tab(text: 'Polls')],
                          ),
                  ),
                  body: _selectedProject == null
                      ? emptyState
                      : Column(
                          children: [
                            _buildContentHeader(theme, canEdit),
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                physics: const NeverScrollableScrollPhysics(), // Disable swipe
                                children: tabChildren,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          );
        }
      },
    );
  }
}
