import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:app/models/collaboration.dart';
import 'flowchart_screen.dart';
import 'mindmap_screen.dart';
import 'timeline_screen.dart';
import 'package:app/services/persistence_service.dart';
import 'package:app/services/auth_service.dart';

// In-memory collaborations (using model from lib/models/collaboration.dart)
List<Collaboration> collaborations = [];

class CollaborationScreen extends StatefulWidget {
  const CollaborationScreen({super.key});

  @override
  State<CollaborationScreen> createState() => _CollaborationScreenState();
}

class _CollaborationScreenState extends State<CollaborationScreen> with TickerProviderStateMixin {
  Collaboration? _selected;
  late TabController _tabController;
  late String _currentUser;
  late TextEditingController _titleController;

  final _listKey = GlobalKey<AnimatedListState>();
  final _persistence = PersistenceService();
  final _auth = AuthService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _titleController = TextEditingController();
    _loadCollabs();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadCollabs() async {
    final user = _auth.currentUser;
    if (user == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/login');
      return;
    }
    _currentUser = user.id;

    collaborations = await _persistence.loadCollaborations();
    if (collaborations.isEmpty) {
      collaborations.add(Collaboration(
        id: 'c1',
        title: 'Welcome Collaboration',
        leads: [_currentUser],
        members: [],
        linkedEvent: null,
        toolData: {}, // Initialize toolData
      ));
      await _persistence.saveCollaborations(collaborations);
    }

    if (!mounted) return;
    final visible = collaborations.where((c) =>
      c.leads.contains(_currentUser) || c.members.contains(_currentUser)
    ).toList();

    setState(() {
      _selected = visible.isNotEmpty ? visible.first : null;
      _titleController.text = _selected?.title ?? '';
    });
  }

  Future<void> _createNewCollab() async {
    final newCollab = Collaboration(
      id: 'c\${collaborations.length + 1}',
      title: 'New Collaboration \${collaborations.length + 1}',
      leads: [_currentUser],
      members: [],
      toolData: {}, // Ensure toolData is initialized
    );
    setState(() {
      // Find the insertion index for AnimatedList to animate.
      final visibleCollabsBefore = collaborations.where((c) => 
        c.leads.contains(_currentUser) || c.members.contains(_currentUser)
      ).length;

      collaborations.add(newCollab);
      _selected = newCollab;
      _titleController.text = newCollab.title;
      _listKey.currentState?.insertItem(visibleCollabsBefore, duration: const Duration(milliseconds: 300));
    });
    await _persistence.saveCollaborations(collaborations);
  }

  void _updateSelectedTitle(String newTitle) async {
    if (_selected == null || !_selected!.leads.contains(_currentUser)) return;
    setState(() {
      _selected!.title = newTitle;
    });
    await _persistence.saveCollaborations(collaborations);
  }

  // --- Widget Builders for both Mobile/Desktop Layouts ---

  Widget _buildCollaborationList(BuildContext context, bool isMobile, List<Collaboration> visibleCollabs) {
    final theme = Theme.of(context);
    return Material(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 16.0, bottom: 8.0, left: 16.0, right: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Collaborations', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_box_outlined, color: Colors.green),
                  onPressed: _createNewCollab,
                  tooltip: 'New collaboration',
                ),
              ],
            ),
          ),
          Expanded(
            child: AnimatedList(
              key: _listKey,
              initialItemCount: visibleCollabs.length,
              itemBuilder: (context, index, animation) {
                final c = visibleCollabs[index];
                final isSelected = _selected == c;
                return SizeTransition(
                  sizeFactor: animation,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.0, horizontal: 8.0),
                    child: ListTile(
                      title: Text(c.title, overflow: TextOverflow.ellipsis),
                      subtitle: Text('Leads: ${c.leads.join(', ')}'),
                      selected: isSelected,
                      selectedTileColor: theme.colorScheme.primary.withOpacity(0.1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        setState(() {
                          _selected = c;
                          _titleController.text = c.title;
                        });
                        if (isMobile) Navigator.of(context).pop();
                      },
                    ),
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
    required String lottieAsset,
    required String title,
    required String routeName,
  }) {
    return ListTile(
      leading: Lottie.asset(lottieAsset, width: 30, height: 30, repeat: true, animate: true),
      title: Text(title, style: Theme.of(context).textTheme.bodyLarge),
      onTap: () {
        Navigator.of(context).pop(); // Close drawer
        Navigator.of(context).pushReplacementNamed(routeName);
      },
    );
  }

  Widget _buildContentHeader(ThemeData theme, bool canEdit) {
    if (_selected == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: canEdit ? Colors.green[50] : Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            if (canEdit)
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: IntrinsicWidth(
                  child: TextField(
                    controller: _titleController,
                    onSubmitted: _updateSelectedTitle,
                    onTapOutside: (_) => _updateSelectedTitle(_titleController.text),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      border: InputBorder.none,
                      hintText: 'Collaboration Title',
                    ),
                  ),
                ),
              )
            else
              Text(
                _selected!.title,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            const SizedBox(width: 12),
            Chip(
              label: Text(canEdit ? 'Editable' : 'Read-only'),
              backgroundColor: canEdit ? Colors.green[200] : Colors.grey[300],
              labelStyle: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
            Text(
              'Leads: ${_selected!.leads.join(', ')}',
              style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // --- Build Method with Mobile/Desktop Logic ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visibleCollabs = collaborations.where((c) =>
      c.leads.contains(_currentUser) || c.members.contains(_currentUser)
    ).toList();
    final bool canEdit = _selected != null && _selected!.leads.contains(_currentUser);

    final List<Widget> tabChildren = _selected == null
        ? <Widget>[]
        : <Widget>[
            FlowchartScreen(collaboration: _selected, canEdit: canEdit),
            MindmapScreen(collaboration: _selected, canEdit: canEdit),
            TimelineScreen(collaboration: _selected, canEdit: canEdit),
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
              Text('No Active Collaborations', style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                'You are not part of any collaborations yet. Ask a lead to add you or click the "+" button to create a new one.',
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
          // MOBILE: Use Drawer for collaborations and navigation
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
                  _buildDrawerMenuItem(
                    context: context, lottieAsset: 'assets/lottie/attendance.json', title: 'Attendance', routeName: '/attendance'),
                  _buildDrawerMenuItem(
                    context: context, lottieAsset: 'assets/lottie/events.json', title: 'Events', routeName: '/events'),
                  _buildDrawerMenuItem(
                    context: context, lottieAsset: 'assets/lottie/logout.json', title: 'Logout', routeName: '/login'),
                  const Divider(height: 1),
                  Expanded(child: _buildCollaborationList(context, isMobile, visibleCollabs)),
                ],
              ),
            ),
            appBar: AppBar(
              title: Text(_selected?.title ?? 'Collaboration'),
              bottom: _selected == null
                  ? null
                  : TabBar(
                      controller: _tabController,
                      tabs: const [Tab(text: 'Flowchart'), Tab(text: 'Mindmap'), Tab(text: 'Timeline')],
                    ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.add_box_outlined),
                  onPressed: _createNewCollab,
                  tooltip: 'New collaboration',
                ),
              ],
            ),
            body: _selected == null
                ? emptyState
                : Column(
                    children: [
                      _buildContentHeader(theme, canEdit),
                      Expanded(
                        child: Stack(
                          children: [
                            TabBarView(
                              controller: _tabController,
                              children: tabChildren.map((e) => e as Widget).toList(),
                            ),
                            if (!canEdit)
                              Positioned.fill(
                                child: IgnorePointer(
                                  ignoring: true,
                                  child: Container(
                                    color: Colors.white.withOpacity(0.6), // Use opacity for a slight white overlay
                                    child: Center(
                                      child: Card(
                                        elevation: 4,
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Text('You have read-only access to this collaboration', style: theme.textTheme.titleMedium),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
          );
        } else {
          // DESKTOP: Original sidebar layout with improvements
          return Row(
            children: [
              Container(
                width: 260,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  border: Border(right: BorderSide(color: Colors.grey[300]!)),
                ),
                child: _buildCollaborationList(context, isMobile, visibleCollabs),
              ),
              Expanded(
                child: Scaffold(
                  appBar: AppBar(
                    title: const Text('Workspace'),
                    automaticallyImplyLeading: false,
                    bottom: _selected == null
                        ? null
                        : TabBar(
                            controller: _tabController,
                            tabs: const [Tab(text: 'Flowchart'), Tab(text: 'Mindmap'), Tab(text: 'Timeline')],
                          ),
                  ),
                  body: _selected == null
                      ? emptyState
                      : Column(
                          children: [
                            _buildContentHeader(theme, canEdit),
                            Expanded(
                              child: Stack(
                                children: [
                                  TabBarView(
                                    controller: _tabController,
                                    children: tabChildren.map((e) => e as Widget).toList(),
                                  ),
                                  if (!canEdit)
                                    Positioned.fill(
                                      child: IgnorePointer(
                                        ignoring: true,
                                        child: Container(
                                          color: Colors.white.withOpacity(0.6),
                                          child: Center(
                                            child: Card(
                                              elevation: 4,
                                              child: Padding(
                                                padding: const EdgeInsets.all(12.0),
                                                child: Text('You have read-only access to this collaboration', style: theme.textTheme.titleMedium),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
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
