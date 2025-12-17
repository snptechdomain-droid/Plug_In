import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:ui'; // For image filter
import 'package:app/models/collaboration.dart';
import 'flowchart_screen.dart';
import 'mindmap_screen.dart';
import 'timeline_screen.dart';
import 'package:app/services/role_database_service.dart';
import 'package:app/services/websocket_service.dart';
import 'package:app/models/role.dart';
import 'package:app/widgets/creative_toolbar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:app/utils/app_strings.dart'; // Import the new widget
import 'package:app/widgets/project_card.dart'; // Restored import

class CollaborationScreen extends StatefulWidget {
  const CollaborationScreen({super.key});

  @override
  State<CollaborationScreen> createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends State<CollaborationScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _selectedProject;
  late TabController _tabController;
  late String _currentUserEmail;
  String _displayName = '';
  String _currentLang = 'English'; // Default Language
  UserRole? _currentUserRole; // Added to track role
  late AnimationController _fabController;
  late Animation<double> _fabAnimation;
  bool _isFabExpanded = false;

  final _roleDatabase = RoleBasedDatabaseService();
  List<Map<String, dynamic>> _projects = [];
  bool _isLoading = true;

  bool get _canCreate {
    if (_currentUserRole == null) return false;
    // Allow Admin, Lead (Moderator), and Event Coordinator
    return _currentUserRole == UserRole.admin || 
           _currentUserRole == UserRole.moderator || 
           _currentUserRole == UserRole.eventCoordinator;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Projects, Polls, Team
    
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fabAnimation = CurvedAnimation(parent: _fabController, curve: Curves.easeOut);

    _loadData();
    
    // Listen for real-time updates
    WebSocketService().nodeStream.listen((msg) {
      if (!mounted) return;
      if (msg['type'] == 'POLL_UPDATE' || msg['type'] == 'PROJECT_UPDATE') {
        _loadData(); 
      }
    });

    _tabController.addListener(() {
      setState(() {}); // Rebuild to update FAB visibility/icon based on tab
    });
  }

  @override
  void dispose() {
    WebSocketService().disconnect();
    _tabController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    // Don't set isLoading = true here to avoid full screen flicker on periodic updates, 
    // unless it's the initial load.
    if (_projects.isEmpty) setState(() => _isLoading = true);
    
    final user = await _roleDatabase.getCurrentUser();
    if (user == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    _currentUserEmail = user.email;
    _displayName = user.username;
    _currentUserRole = user.role; // Store role

    final prefs = await SharedPreferences.getInstance();
    _currentLang = prefs.getString('language') ?? 'English';

    final projects = await _roleDatabase.getUserProjects(_currentUserEmail);
    
    if (mounted) {
      setState(() {
        _projects = projects;
        _isLoading = false;
        // Auto-select first if none selected
        if (_projects.isNotEmpty && _selectedProject == null) {
          _selectedProject = _projects.first;
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

  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabController.forward();
      } else {
        _fabController.reverse();
      }
    });
  }
  
  // Note: Skipping _openProject as it's separate block. 
  // Wait, I need to match StartLine carefully to not replace _openProject if not needed.
  // The block ends at _toggleFab end usually.
  // Let's replace up to _loadData end and keep _openProject intact if outside range.

  // Actually, I will replacing from line 25 to 113 roughly.


  Future<void> _openProject(Map<String, dynamic> project) async {
    setState(() => _selectedProject = project);
    // WebSocket connection is handled by the specific screen (MindmapScreen, etc.)
    // WebSocketService().connect(project['id'], _currentUserEmail);

    final title = (project['title'] as String).toLowerCase();
    
    Widget screen;
    // Simple heuristic for now, ideal would be a 'type' field in DB
    Future<void> saveProject(Collaboration c) async {
       print('Saving project: ${c.id}');
       try {
           // Serialize tool data back to JSON strings for the API
           String? mmData, fcData, tlData;
           
           if (c.toolData.containsKey('mindmap_nodes') || c.toolData.containsKey('mindmapData')) {
             if (c.toolData['mindmap_nodes'] != null) {
                try {
                  mmData = jsonEncode({
                    'nodes': c.toolData['mindmap_nodes'],
                    'view': c.toolData['mindmap_view'], // Persist Viewport
                    'annotations': c.toolData['mindmap_annotations'], // Persist Annotations
                  });
                } catch (e) {
                  print('ERROR encoding mindmap nodes: $e');
                }
             } else {
                mmData = c.toolData['mindmapData'];
             }
           }
           
           if (c.toolData.containsKey('timeline_milestones') || c.toolData.containsKey('timelineData')) {
              if (c.toolData['timeline_milestones'] != null) {
                 try {
                   tlData = jsonEncode(c.toolData['timeline_milestones']);
                 } catch (e) {
                   print('ERROR encoding timeline: $e');
                 }
              } else {
                 tlData = c.toolData['timelineData'];
              }
           }
           
           if (c.toolData.containsKey('flowchart_nodes') || c.toolData.containsKey('flowchartData')) {
              if (c.toolData['flowchart_nodes'] != null) {
                 try {
                   fcData = jsonEncode({
                     'nodes': c.toolData['flowchart_nodes'],
                     'connections': c.toolData['flowchart_connections']
                   });
                 } catch (e) {
                   print('ERROR encoding flowchart: $e');
                 }
              } else {
                 fcData = c.toolData['flowchartData'];
              }
           }
    
           print('Updating DB with: MM=${mmData?.length} chars, FC=${fcData?.length}, TL=${tlData?.length}');
           final success = await _roleDatabase.updateProjectData(c.id, mindmapData: mmData, flowchartData: fcData, timelineData: tlData);
           print('Update success: $success');
       } catch (e) {
         print('CRITICAL ERROR in saveProject: $e');
       }
    }

    // Create a mutable collaboration object that the screen can update
    final collaboration = Collaboration.fromMap(project);

    if (title.contains('mindmap')) {
      screen = MindmapScreen(
        collaboration: collaboration, 
        canEdit: true, 
        onSave: () => saveProject(collaboration),
      );
    } else if (title.contains('flowchart')) {
       screen = FlowchartScreen(
         collaboration: collaboration, 
         canEdit: true,
         onSave: () => saveProject(collaboration),
       );
    } else if (title.contains('timeline')) {
       screen = TimelineScreen(
         collaboration: collaboration, 
         canEdit: true,
         onSave: () => saveProject(collaboration),
       );
    } else {
       // Default fallback or prompt
       screen = MindmapScreen(
         collaboration: collaboration, 
         canEdit: true,
         onSave: () => saveProject(collaboration),
       );
    }

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => screen),
    );
    // Refresh data when returning from editor to ensure we have the latest updates
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // Background Elements (Subtle Gradients)
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                color: Colors.deepPurple.withOpacity(isDark ? 0.1 : 0.05),
                shape: BoxShape.circle,
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                expandedHeight: 180,
                floating: false,
                pinned: true,
                backgroundColor: Colors.transparent,
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildHeader(isDark),
                ),
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          color: isDark ? Colors.black54 : Colors.white.withOpacity(0.6),
                          child: TabBar(
                            controller: _tabController,
                            indicatorColor: Colors.deepPurple,
                            labelColor: Colors.deepPurple,
                            unselectedLabelColor: isDark ? Colors.grey : Colors.black54,
                            indicatorSize: TabBarIndicatorSize.label,
                            labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                            tabs: [
                    Tab(text: AppStrings.tr('projects', _currentLang)),
                    Tab(text: AppStrings.tr('polls', _currentLang)),
                    Tab(text: AppStrings.tr('templates', _currentLang)), // "Templates"
                  ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            body: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProjectsList(isDark),
                      _buildPollsTab(isDark),
                      _buildTemplatesTab(isDark),
                    ],
                  ),
          ),
          
          if (_isFabExpanded) _buildFabOverlay(),
        ],
      ),
      floatingActionButton: _buildFab(),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.deepPurple,
                child: Text(
                  _displayName.isNotEmpty ? _displayName[0].toUpperCase() : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.tr('welcome', _currentLang),
                    style: TextStyle(
                      fontSize: 14, 
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  Text(
                    _displayName,
                    style: TextStyle(
                      fontSize: 24, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Mini Stats
            _buildMiniStat(AppStrings.tr('projects', _currentLang), '${_projects.length}', isDark),
          ],
        ),
      ],
    ),
  );
}

  Widget _buildMiniStat(String label, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          if(!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ]
      ),
      child: Column(
        children: [
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
          Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.grey : Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildProjectsList(bool isDark) {
    if (_projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
           Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
           const SizedBox(height: 16),
           Text(AppStrings.tr('no_projects', _currentLang), style: TextStyle(color: Colors.grey.shade600)),
           if (_canCreate)
             TextButton(onPressed: () => _createNewProject(type: 'Mindmap'), child: Text(AppStrings.tr('create_first', _currentLang))),
           if (!_canCreate)
             const Text('You do not have permission to create projects.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _projects.length,
      itemBuilder: (context, index) {
        final project = _projects[index];
        final isSelected = _selectedProject != null && _selectedProject!['id'] == project['id'];
        return ProjectCard(
          project: project,
          isSelected: isSelected,
          onTap: () => _openProject(project),
          onSettingsTap: () => _showProjectSettings(project),
        );
      },
    );
  }

  void _showProjectSettings(Map<String, dynamic> project) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.group),
                title: const Text('Manage Team'),
                onTap: () {
                   Navigator.pop(context);
                   _showTeamManager(project);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename Project'),
                onTap: () {
                   Navigator.pop(context);
                   _renameProject(project);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Project', style: TextStyle(color: Colors.red)),
                onTap: () {
                   Navigator.pop(context);
                   _deleteProject(project);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showTeamManager(Map<String, dynamic> project) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        final members = [
          {'email': project['ownerId'], 'role': 'OWNER'},
          ...(project['activeUsers'] as List? ?? []).map((e) => {'email': e, 'role': 'ACTIVE'}),
        ];
        
        return FractionallySizedBox(
          heightFactor: 0.7,
          child: Column(
            children: [
               Padding(
                 padding: const EdgeInsets.all(16.0),
                 child: Text('Team: ${project['title']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
               ),
               Expanded(
                 child: ListView.builder(
                    itemCount: members.length + 1,
                    padding: const EdgeInsets.all(16),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ElevatedButton.icon(
                            onPressed: () { 
                               // Close sheet temporarily or stack dialog? Stack dialog works.
                               _addMemberToProject(project); 
                            },
                            icon: const Icon(Icons.person_add),
                            label: const Text('Add Team Member'),
                          ),
                        );
                      }
                      final m = members[index - 1];
                      return ListTile(
                        leading: CircleAvatar(child: Text((m['email'] as String)[0].toUpperCase())),
                        title: Text(m['email'] as String),
                        subtitle: Text(m['role'] as String),
                        trailing: m['role'] == 'OWNER' ? const Icon(Icons.star, color: Colors.amber) : IconButton(
                          icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                          onPressed: () {
                             // _removeMember(project, m['email']);
                             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Remove member feature pending backend')));
                          },
                        ),
                      );
                    },
                 ),
               ),
            ],
          ),
        );
      },
    );
  }

  // Refactored to accept project argument
  Future<void> _addMemberToProject(Map<String, dynamic> project) async {
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
                displayStringForOption: (option) => option.username,
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text == '') return const Iterable.empty();
                  return allUsers.where((user) {
                    return user.username.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (selection) => selectedUser = selection,
                fieldViewBuilder: (ctx, ctrl, focus, onSub) => TextField(
                  controller: ctrl, focusNode: focus, 
                  decoration: const InputDecoration(labelText: 'Search User')
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: const [
                  DropdownMenuItem(value: 'EDITOR', child: Text('Editor')),
                  DropdownMenuItem(value: 'VIEWER', child: Text('Viewer')),
                ],
                onChanged: (v) => setState(() => selectedRole = v!),
              )
            ],
          ),
          actions: [
             TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
             ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (result == true && selectedUser != null) {
      final success = await _roleDatabase.addMemberToProject(project['id'], selectedUser!.email, role: selectedRole);
      if (success) {
         Navigator.pop(context); // Close team manager to refresh? Or just refresh data
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member added')));
         _loadData(); // Will refresh the UI
      }
    }
  }

  Future<void> _renameProject(Map<String, dynamic> project) async {
     final ctrl = TextEditingController(text: project['title']);
     final result = await showDialog<String>(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text('Rename Project'),
         content: TextField(controller: ctrl, decoration: const InputDecoration(labelText: 'New Title')),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
           ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Save')),
         ],
       ),
     );
     
     if (result != null && result.isNotEmpty) {
        // Backend doesn't strictly support rename via specific endpoint yet? 
        // Based on RoleBasedDatabaseService, we might not have a rename method.
        // Checking service... we have createProject, addMember.
        // We do NOT have updateProject yet.
        // Fallback: Just update local list for demo or error if backend strict.
        // Actually, let's implement a dummy update or show "Not implemented" if backend missing.
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Renaming not supported by backend yet.')));
     }
  }

  Future<void> _deleteProject(Map<String, dynamic> project) async {
     final confirm = await showDialog<bool>(
       context: context,
       builder: (ctx) => AlertDialog(
         title: const Text('Delete Project'),
         content: Text('Are you sure you want to delete "${project['title']}"?'),
         actions: [
           TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
           ElevatedButton(
             style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
             onPressed: () => Navigator.pop(ctx, true), 
             child: const Text('Delete')
            ),
         ],
       ),
     );

     if (confirm == true) {
        final success = await _roleDatabase.deleteProject(project['id']);
        if (success) {
          setState(() {
             _projects.removeWhere((p) => p['id'] == project['id']);
             if (_selectedProject?['id'] == project['id']) _selectedProject = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Project deleted successfully')));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to delete project')));
        }
     }
  }

  Widget _buildPollsTab(bool isDark) {
    if (_selectedProject == null) {
      return Center(child: Text('Select a project to view polls', style: TextStyle(color: Colors.grey.shade600)));
    }
    
    final List<dynamic> polls = _selectedProject!['polls'] ?? [];
    if (polls.isEmpty) {
         return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Icon(Icons.poll, size: 64, color: Colors.grey.shade400),
               const SizedBox(height: 16),
               Text('No active polls', style: TextStyle(color: Colors.grey.shade600)),
               const SizedBox(height: 8),
                if (_canCreate)
                ElevatedButton.icon(
                  onPressed: _createPoll,
                  icon: const Icon(Icons.add),
                  label: const Text('Create Poll'),
                ),
            ],
          ),
        );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: polls.length,
      itemBuilder: (context, index) {
        final poll = polls[index];
        final isActive = poll['active'] != false;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Expanded(child: Text(poll['question'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(
                         color: isActive ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                         borderRadius: BorderRadius.circular(8),
                         border: Border.all(color: isActive ? Colors.green : Colors.grey),
                       ),
                       child: Text(isActive ? 'Active' : 'Closed', style: TextStyle(fontSize: 10, color: isActive ? Colors.green : Colors.grey)),
                     ),
                   ],
                 ),
                 const SizedBox(height: 16),
                 ..._buildPollOptions(poll, isDark),
                 
                 const Divider(height: 32),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.end,
                   children: [
                     if ((poll['creatorId'] == _currentUserEmail || _selectedProject!['ownerId'] == _currentUserEmail) && isActive)
                       TextButton(
                         onPressed: () => _togglePollStatus(poll['id']),
                         child: const Text('End Poll', style: TextStyle(color: Colors.orange)),
                       ),
                      if (poll['creatorId'] == _currentUserEmail || _selectedProject!['ownerId'] == _currentUserEmail)
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deletePoll(poll['id']),
                        ),
                   ],
                 )
              ],
            ),
          ),
        );
      },
    );
  }
  
  List<Widget> _buildPollOptions(Map<String, dynamic> poll, bool isDark) {
    final options = (poll['options'] as List<dynamic>).cast<String>();
    final votes = poll['votes'] as Map<String, dynamic>? ?? {};
    final isMulti = poll['multiSelect'] == true;
    final totalVotes = votes.length; // Approximate, or count total selections for simpler logic
    
    // Calculate counts
    final counts = List.filled(options.length, 0);
    votes.forEach((userId, voteVal) {
      if (voteVal is int) {
        if(voteVal < counts.length) counts[voteVal]++;
      } else if (voteVal is List) {
        for(var v in voteVal) {
           if(v is int && v < counts.length) counts[v]++;
        }
      }
    });

    return List.generate(options.length, (index) {
       final count = counts[index];
       final percentage = totalVotes == 0 ? 0.0 : (count / totalVotes); 
       // Note: Percentage calculation can be tricky with multi-select. 
       // Often simpler to just show raw count or % of *respondents*.
       
       return InkWell(
         onTap: () => _votePoll(poll['id'], index, isMulti),
         child: Container(
           margin: const EdgeInsets.only(bottom: 8),
           child: Stack(
             children: [
               ClipRRect(
                 borderRadius: BorderRadius.circular(8),
                 child: LinearProgressIndicator(
                   value: percentage,
                   minHeight: 40,
                   backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                   valueColor: AlwaysStoppedAnimation(Colors.deepPurple.withOpacity(0.2)),
                 ),
               ),
               Positioned.fill(
                 child: Padding(
                   padding: const EdgeInsets.symmetric(horizontal: 12),
                   child: Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text(options[index]),
                       Text('$count votes'),
                     ],
                   ),
                 ),
               ),
             ],
           ),
         ),
       );
    });
  }

  Widget _buildTemplatesTab(bool isDark) {
    if (!_canCreate) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text('Templates restricted to creators', style: TextStyle(color: Colors.grey.shade600)),
          ],
        ),
      );
    }

    final templates = [
    {'key': 'brainstorming', 'title': AppStrings.tr('brainstorming', _currentLang), 'type': 'Mindmap', 'desc': 'Central idea with branches', 'icon': Icons.psychology, 'color': Colors.orangeAccent},
    {'key': 'swot', 'title': AppStrings.tr('strategic_plan', _currentLang) + ' (SWOT)', 'type': 'Mindmap', 'desc': 'Strengths, Weaknesses...', 'icon': Icons.grid_view, 'color': Colors.blueAccent},
    {'key': 'timeline', 'title': AppStrings.tr('project_timeline', _currentLang), 'type': 'Timeline', 'desc': 'Phases and Milestones', 'icon': Icons.timeline, 'color': Colors.green},
    {'key': 'flowchart', 'title': AppStrings.tr('flowchart', _currentLang), 'type': 'Flowchart', 'desc': 'Process diagram', 'icon': Icons.account_tree, 'color': Colors.purple},
    {'key': 'task', 'title': AppStrings.tr('task_breakdown', _currentLang), 'type': 'Mindmap', 'desc': 'Divide and Conquer', 'icon': Icons.list_alt, 'color': Colors.teal},
  ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final t = templates[index];
        return InkWell(
          onTap: () => _createFromTemplate(t['type'] as String, t['title'] as String, t['key'] as String), // Pass Key
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                 if(!isDark) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2)),
              ],
              border: Border.all(color: (t['color'] as Color).withOpacity(0.3)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: (t['color'] as Color).withOpacity(0.1),
                  radius: 24,
                  child: Icon(t['icon'] as IconData, color: t['color'] as Color),
                ),
                const SizedBox(height: 12),
                Text(t['title'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text(t['desc'] as String, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createFromTemplate(String type, String templateName, String templateKey) async {
    final titleCtrl = TextEditingController(text: '$templateName Project');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Use $templateName Template?'),
        content: TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Project Name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      ),
    );

    if (confirm != true) return;

    final newProject = await _roleDatabase.createProject(titleCtrl.text + ' ($type)', _currentUserEmail);
    if (newProject == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to create project')));
      return;
    }

    // Populate data based on template
    String? mmData, fcData, tlData;
    

    if (templateKey == 'brainstorming' && type == 'Mindmap') {
      final rootId = 'root_${DateTime.now().millisecondsSinceEpoch}';
      mmData = jsonEncode({
         'rootId': rootId,
         'nodes': [
            {'id': rootId, 'label': 'Core Idea', 'x': 0.0, 'y': 0.0, 'color': 0xFF6200EA, 'iconCodePoint': 0xeb3c}, // Lightbulb
            {'id': '${rootId}_1', 'parentId': rootId, 'label': 'Concept A', 'x': -200.0, 'y': -150.0, 'color': 0xFF00BFA5},
            {'id': '${rootId}_1_1', 'parentId': '${rootId}_1', 'label': 'Detail 1', 'x': -350.0, 'y': -200.0, 'color': 0xFF00BFA5},
            {'id': '${rootId}_1_2', 'parentId': '${rootId}_1', 'label': 'Detail 2', 'x': -350.0, 'y': -100.0, 'color': 0xFF00BFA5},
            {'id': '${rootId}_2', 'parentId': rootId, 'label': 'Concept B', 'x': 200.0, 'y': -150.0, 'color': 0xFFFFAB00},
            {'id': '${rootId}_2_1', 'parentId': '${rootId}_2', 'label': 'Pro A', 'x': 350.0, 'y': -200.0, 'color': 0xFFFFAB00},
            {'id': '${rootId}_2_2', 'parentId': '${rootId}_2', 'label': 'Con A', 'x': 350.0, 'y': -100.0, 'color': 0xFFFFAB00},
            {'id': '${rootId}_3', 'parentId': rootId, 'label': 'Concept C', 'x': -200.0, 'y': 150.0, 'color': 0xFF2962FF},
            {'id': '${rootId}_3_1', 'parentId': '${rootId}_3', 'label': 'Cost', 'x': -350.0, 'y': 100.0, 'color': 0xFF2962FF},
            {'id': '${rootId}_4', 'parentId': rootId, 'label': 'Concept D', 'x': 200.0, 'y': 150.0, 'color': 0xFFD500F9},
            {'id': '${rootId}_4_1', 'parentId': '${rootId}_4', 'label': 'Risks', 'x': 350.0, 'y': 100.0, 'color': 0xFFD500F9},
         ],
         'annotations': [
            {'id': '${rootId}_parking', 'x': 500.0, 'y': -400.0, 'width': 300.0, 'height': 200.0, 'label': 'Parking Lot', 'text': 'Ideas for later...', 'color': 0xFF9E9E9E.toInt()},
         ]
      });
    } else if (templateKey == 'timeline' && type == 'Timeline') {
      tlData = jsonEncode({
        'items': [
          {'id': 'm1', 'label': 'Q1: Planning', 'x': 100.0, 'y': -50.0, 'color': 0xFF2196F3, 'notes': 'Define scope & requirements', 'link': 'https://jira.com/planning'},
          {'id': 'm2', 'label': 'Q2: Design', 'x': 400.0, 'y': 50.0, 'color': 0xFF9C27B0, 'notes': 'UI/UX Prototypes', 'link': 'https://figma.com/file/123'},
          {'id': 'm3', 'label': 'Q3: Development', 'x': 700.0, 'y': -50.0, 'color': 0xFF4CAF50, 'notes': 'MVP Build'},
          {'id': 'm4', 'label': 'Q4: Launch', 'x': 1000.0, 'y': 50.0, 'color': 0xFFFF9800, 'notes': 'Go-to-market', 'link': 'https://launch.com'},
          {'id': 'm5', 'label': 'Post-Launch', 'x': 1300.0, 'y': 0.0, 'color': 0xFF607D8B, 'notes': 'Feedback loop'},
        ]
      });
    } else if (templateKey == 'flowchart' && type == 'Flowchart') {
      fcData = jsonEncode({
        'nodes': [
          {'id': 'n1', 'label': 'Start', 'x': 300.0, 'y': 50.0, 'shape': 3, 'color': 0xFF4CAF50, 'width': 100.0, 'height': 50.0}, // Circle
          {'id': 'n2', 'label': 'Login Page', 'x': 250.0, 'y': 150.0, 'shape': 0, 'color': 0xFF2196F3, 'width': 200.0, 'height': 80.0}, // Rect
          {'id': 'n3', 'label': 'Enter Creds', 'x': 250.0, 'y': 280.0, 'shape': 5, 'color': 0xFF64B5F6, 'width': 200.0, 'height': 80.0}, // Parallelogram
          {'id': 'n4', 'label': 'Valid?', 'x': 280.0, 'y': 400.0, 'shape': 2, 'color': 0xFFFF9800, 'width': 140.0, 'height': 140.0}, // Diamond
          {'id': 'n5', 'label': 'Dashboard', 'x': 250.0, 'y': 600.0, 'shape': 0, 'color': 0xFF2196F3, 'width': 200.0, 'height': 80.0}, // Rect
          {'id': 'n6', 'label': 'Error Msg', 'x': 500.0, 'y': 430.0, 'shape': 1, 'color': 0xFFEF5350, 'width': 150.0, 'height': 80.0}, // Pill
          {'id': 'n7', 'label': 'End', 'x': 300.0, 'y': 750.0, 'shape': 3, 'color': 0xFF424242, 'width': 100.0, 'height': 50.0}, // Circle
        ],
        'connections': [
           {'id': 'c1', 'fromId': 'n1', 'toId': 'n2', 'label': 'Open App'},
           {'id': 'c2', 'fromId': 'n2', 'toId': 'n3'},
           {'id': 'c3', 'fromId': 'n3', 'toId': 'n4'},
           {'id': 'c4', 'fromId': 'n4', 'toId': 'n5', 'label': 'Yes'},
           {'id': 'c5', 'fromId': 'n4', 'toId': 'n6', 'label': 'No'},
           {'id': 'c6', 'fromId': 'n6', 'toId': 'n2', 'label': 'Retry'},
           {'id': 'c7', 'fromId': 'n5', 'toId': 'n7'},
        ],
        'annotations': []
      });
    } else if (templateKey == 'swot' && type == 'Mindmap') {
      final rootId = 'root_${DateTime.now().millisecondsSinceEpoch}';
      mmData = jsonEncode({
        'rootId': rootId,
        'nodes': [
          {'id': rootId, 'label': 'SWOT Analysis', 'x': 0.0, 'y': 0.0, 'color': 0xFF212121, 'iconCodePoint': 0xe06f}, // Assessment
          {'id': 'swot_S', 'parentId': rootId, 'label': 'STRENGTHS', 'x': -300.0, 'y': -200.0, 'color': 0xFF43A047, 'iconCodePoint': 0xe8e8},
          {'id': 'swot_S1', 'parentId': 'swot_S', 'label': 'Internal Positive', 'x': -500.0, 'y': -250.0, 'color': 0xFFA5D6A7},
          {'id': 'swot_S2', 'parentId': 'swot_S', 'label': 'Advantages', 'x': -500.0, 'y': -150.0, 'color': 0xFFA5D6A7},
          {'id': 'swot_W', 'parentId': rootId, 'label': 'WEAKNESSES', 'x': 300.0, 'y': -200.0, 'color': 0xFFE53935, 'iconCodePoint': 0xe002},
          {'id': 'swot_W1', 'parentId': 'swot_W', 'label': 'Internal Negative', 'x': 500.0, 'y': -250.0, 'color': 0xFFEF9A9A},
          {'id': 'swot_W2', 'parentId': 'swot_W', 'label': 'Limitations', 'x': 500.0, 'y': -150.0, 'color': 0xFFEF9A9A},
          {'id': 'swot_O', 'parentId': rootId, 'label': 'OPPORTUNITIES', 'x': -300.0, 'y': 200.0, 'color': 0xFF1E88E5, 'iconCodePoint': 0xea80},
          {'id': 'swot_O1', 'parentId': 'swot_O', 'label': 'External Positive', 'x': -500.0, 'y': 150.0, 'color': 0xFF90CAF9},
          {'id': 'swot_O2', 'parentId': 'swot_O', 'label': 'Trends', 'x': -500.0, 'y': 250.0, 'color': 0xFF90CAF9},
          {'id': 'swot_T', 'parentId': rootId, 'label': 'THREATS', 'x': 300.0, 'y': 200.0, 'color': 0xFFFFB300, 'iconCodePoint': 0xe14b},
          {'id': 'swot_T1', 'parentId': 'swot_T', 'label': 'External Negative', 'x': 500.0, 'y': 150.0, 'color': 0xFFFFE082},
          {'id': 'swot_T2', 'parentId': 'swot_T', 'label': 'Competitors', 'x': 500.0, 'y': 250.0, 'color': 0xFFFFE082},
        ],
        'annotations': [
           {'id': 'box_S', 'x': -700.0, 'y': -350.0, 'width': 500.0, 'height': 300.0, 'label': 'Strengths Zone', 'text': '', 'color': 0xFF43A047.toInt()},
           {'id': 'box_W', 'x': 300.0, 'y': -350.0, 'width': 500.0, 'height': 300.0, 'label': 'Weaknesses Zone', 'text': '', 'color': 0xFFE53935.toInt()},
           {'id': 'box_O', 'x': -700.0, 'y': 100.0, 'width': 500.0, 'height': 300.0, 'label': 'Opportunities Zone', 'text': '', 'color': 0xFF1E88E5.toInt()},
           {'id': 'box_T', 'x': 300.0, 'y': 100.0, 'width': 500.0, 'height': 300.0, 'label': 'Threats Zone', 'text': '', 'color': 0xFFFFB300.toInt()},
        ]
      });
    } else if (templateKey == 'task' && type == 'Mindmap') {
      final rootId = 'root_${DateTime.now().millisecondsSinceEpoch}';
      mmData = jsonEncode({
        'rootId': rootId,
        'nodes': [
          {'id': rootId, 'label': 'Main Task', 'x': 0.0, 'y': 0.0, 'color': 0xFF3F51B5, 'iconCodePoint': 0xe85d}, // Assignment
          // Phase 1 (Top Left)
          {'id': 'p1', 'parentId': rootId, 'label': 'Phase 1', 'x': -300.0, 'y': -200.0, 'color': 0xFF5C6BC0},
          {'id': 'p1_1', 'parentId': 'p1', 'label': 'Step 1.1', 'x': -500.0, 'y': -250.0, 'color': 0xFF7986CB},
          {'id': 'p1_2', 'parentId': 'p1', 'label': 'Step 1.2', 'x': -500.0, 'y': -150.0, 'color': 0xFF7986CB},
          // Phase 2 (Top Right)
          {'id': 'p2', 'parentId': rootId, 'label': 'Phase 2', 'x': 300.0, 'y': -200.0, 'color': 0xFFEC407A},
          {'id': 'p2_1', 'parentId': 'p2', 'label': 'Step 2.1', 'x': 500.0, 'y': -250.0, 'color': 0xFFF06292},
          {'id': 'p2_2', 'parentId': 'p2', 'label': 'Step 2.2', 'x': 500.0, 'y': -150.0, 'color': 0xFFF06292},
          // Phase 3 (Bottom Left)
          {'id': 'p3', 'parentId': rootId, 'label': 'Phase 3', 'x': -300.0, 'y': 200.0, 'color': 0xFFFFA726},
          {'id': 'p3_1', 'parentId': 'p3', 'label': 'Step 3.1', 'x': -500.0, 'y': 150.0, 'color': 0xFFFFB74D},
          {'id': 'p3_2', 'parentId': 'p3', 'label': 'Step 3.2', 'x': -500.0, 'y': 250.0, 'color': 0xFFFFB74D},
          // Phase 4 (Bottom Right)
          {'id': 'p4', 'parentId': rootId, 'label': 'Phase 4', 'x': 300.0, 'y': 200.0, 'color': 0xFF66BB6A},
          {'id': 'p4_1', 'parentId': 'p4', 'label': 'Step 4.1', 'x': 500.0, 'y': 150.0, 'color': 0xFF81C784},
          {'id': 'p4_2', 'parentId': 'p4', 'label': 'Step 4.2', 'x': 500.0, 'y': 250.0, 'color': 0xFF81C784},
        ],
        'annotations': [
           {'id': 'box_p1', 'x': -650.0, 'y': -350.0, 'width': 450.0, 'height': 300.0, 'label': '@Alice (Lead)', 'text': 'Responsible for Phase 1\n- UI Design\n- Prototypes', 'color': 0xFF5C6BC0},
           {'id': 'box_p2', 'x': 200.0, 'y': -350.0, 'width': 450.0, 'height': 300.0, 'label': '@Bob (Dev)', 'text': 'Responsible for Phase 2\n- API Integration\n- Database', 'color': 0xFFEC407A},
           {'id': 'box_p34', 'x': -600.0, 'y': 100.0, 'width': 1200.0, 'height': 350.0, 'label': '@Team (Execution)', 'text': 'Phase 3 & 4 Execution Area', 'color': 0xFF66BB6A},
        ]
      });
    }

    if (mmData != null || fcData != null || tlData != null) {
       await _roleDatabase.updateProjectData(newProject['id'], mindmapData: mmData, flowchartData: fcData, timelineData: tlData);
    }
    
    await _loadData();
    // Open new project
    final updatedList = await _roleDatabase.getUserProjects(_currentUserEmail);
    try {
      var freshProject = updatedList.firstWhere((p) => p['id'] == newProject['id']);
      
      // OPTIMISTIC UPDATE: Inject data locally in case backend hasn't synced yet
      // This ensures the screen opens with data even if the FETCH was too fast.
      freshProject = Map<String, dynamic>.from(freshProject); // Make mutable copy
      freshProject['toolData'] = <String, dynamic>{
        if (mmData != null) 'mindmapData': mmData,
        if (fcData != null) 'flowchartData': fcData,
        if (tlData != null) 'timelineData': tlData,
        ...(freshProject['toolData'] ?? {}),
      };

      _openProject(freshProject);
    } catch (e) {
      print('Error opening new template project: $e');
    }
  }

  // --- Logic Methods (Preserved & Adapted) ---

  Future<void> _createPoll() async {
     if (_selectedProject == null) return;
     final questionCtrl = TextEditingController();
     final optionsCtrl = TextEditingController(); // Comma separated for MVP
     bool multi = false;
     
     final result = await showDialog<bool>(
       context: context,
       builder: (ctx) => StatefulBuilder(
         builder: (context, setState) => AlertDialog(
           title: const Text('Create New Poll'),
           content: Column(
             mainAxisSize: MainAxisSize.min,
             children: [
               TextField(controller: questionCtrl, decoration: const InputDecoration(labelText: 'Question')),
               TextField(controller: optionsCtrl, decoration: const InputDecoration(labelText: 'Options (comma separated)')),
               CheckboxListTile(
                 title: const Text('Allow Multi-select'),
                 value: multi,
                 onChanged: (v) => setState(() => multi = v!),
               )
             ],
           ),
           actions: [
             TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
             ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Post')),
           ],
         ),
       ),
     );
     
     if (result == true && questionCtrl.text.isNotEmpty) {
       final options = optionsCtrl.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
       if (options.length < 2) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('At least 2 options required')));
         return;
       }
       final success = await _roleDatabase.createPoll(_selectedProject!['id'], questionCtrl.text, options, multiSelect: multi);
       if (success) {
         if (mounted) _loadData();
         WebSocketService().sendNodeUpdate(_selectedProject!['id'], 'POLL_UPDATE', 'poll', {'action': 'CREATE'});
       }
     }
  }

  Future<void> _votePoll(String pollId, int optionIdx, bool isMulti) async {
    if (_selectedProject == null) return;
    
    // Check if active
    final poll = (_selectedProject!['polls'] as List).firstWhere((p) => p['id'] == pollId);
    if (poll['active'] == false) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This poll is closed.')));
      return;
    }

    final success = await _roleDatabase.votePoll(_selectedProject!['id'], pollId, _currentUserEmail, optionIdx);
    if (success) {
      if (mounted) _loadData();
      WebSocketService().sendNodeUpdate(_selectedProject!['id'], 'POLL_UPDATE', pollId, {'action': 'VOTE'});
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vote recorded!')));
    } else {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to record vote.')));
    }
  }
  
  Future<void> _deletePoll(String pollId) async {
    if (_selectedProject == null) return;
    final success = await _roleDatabase.deletePoll(_selectedProject!['id'], pollId);
    if (success) {
      if (mounted) _loadData();
      WebSocketService().sendNodeUpdate(_selectedProject!['id'], 'POLL_UPDATE', pollId, {'action': 'DELETE'});
    }
  }
  
  Future<void> _togglePollStatus(String pollId) async {
    if (_selectedProject == null) return;
    final success = await _roleDatabase.togglePollStatus(_selectedProject!['id'], pollId);
    if (success) {
      if (mounted) _loadData();
      WebSocketService().sendNodeUpdate(_selectedProject!['id'], 'POLL_UPDATE', pollId, {'action': 'TOGGLE'});
    }
  }

  Future<void> _createNewProject({String? type}) async {
    final titleController = TextEditingController();
    String typeLabel = type != null ? 'New $type' : 'New Project';
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(typeLabel),
        content: TextField(
          controller: titleController,
          decoration: InputDecoration(
            labelText: 'Project Title', 
            hintText: type != null ? 'e.g., Marketing $type' : 'e.g., Marketing Strategy'
          ),
          autofocus: true,
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
      String finalTitle = titleController.text;
      // Heuristic: Append type if not present, to ensure navigation logic works
      if (type != null) {
         final lowerTitle = finalTitle.toLowerCase();
         final lowerType = type.toLowerCase();
         if (!lowerTitle.contains(lowerType)) {
            finalTitle = '$finalTitle ($type)'; 
         }
      }

      final newProject = await _roleDatabase.createProject(finalTitle, _currentUserEmail);
      if (newProject != null) {
        await _loadData();
        // Auto-open
        _openProject(newProject);
      }
    }
  }
  
  Future<void> _addMember() async {
    // Re-use existing add member logic from snippet/memory
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
                displayStringForOption: (option) => option.username,
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text == '') return const Iterable.empty();
                  return allUsers.where((user) {
                    return user.username.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (selection) => selectedUser = selection,
                fieldViewBuilder: (ctx, ctrl, focus, onSub) => TextField(
                  controller: ctrl, focusNode: focus, 
                  decoration: const InputDecoration(labelText: 'Search User')
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                items: const [
                  DropdownMenuItem(value: 'EDITOR', child: Text('Editor')),
                  DropdownMenuItem(value: 'VIEWER', child: Text('Viewer')),
                ],
                onChanged: (v) => setState(() => selectedRole = v!),
              )
            ],
          ),
          actions: [
             TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
             ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (result == true && selectedUser != null) {
      final success = await _roleDatabase.addMemberToProject(_selectedProject!['id'], selectedUser!.email, role: selectedRole);
      if (success) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member added')));
         _loadData();
      }
    }
  }

  // --- FLOATING ACTION BUTTON (SPEED DIAL) ---
  
  Widget _buildFab() {
    if (!_canCreate) return const SizedBox.shrink(); // Hide if no permission
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ScaleTransition(
          scale: _fabAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildFabItem(Icons.psychology, 'New Mindmap', () { _toggleFab(); _createNewProject(type: 'Mindmap'); }), 
              _buildFabItem(Icons.account_tree, 'New Flowchart', () { _toggleFab(); _createNewProject(type: 'Flowchart'); }),
              _buildFabItem(Icons.timeline, 'New Timeline', () { _toggleFab(); _createNewProject(type: 'Timeline'); }),
              if (_tabController.index == 1) // Only show Poll in Polls tab or generic?
                 _buildFabItem(Icons.poll, 'New Poll', () { _toggleFab(); _createPoll(); }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        FloatingActionButton(
          onPressed: _toggleFab,
          backgroundColor: Colors.deepPurple,
          child: Icon(_isFabExpanded ? Icons.close : Icons.add),
        ),
        const SizedBox(height: 60), // Space for bottom nav if exists, else standard padding
      ],
    );
  }
  
  Widget _buildFabItem(IconData icon, String label, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(
               color: Colors.black87,
               borderRadius: BorderRadius.circular(8),
             ),
             child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.small(
            heroTag: null,
            onPressed: onTap,
            backgroundColor: Colors.white,
            foregroundColor: Colors.deepPurple,
            child: Icon(icon),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFabOverlay() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: _toggleFab,
        child: Container(
          color: Colors.black54,
        ),
      ),
    );
  }

}
