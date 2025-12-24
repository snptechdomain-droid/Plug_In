import 'package:flutter/material.dart';
import 'package:app/models/announcement.dart';
import 'package:app/services/role_database_service.dart';
import 'package:app/models/role.dart';
import 'package:intl/intl.dart';
import 'package:app/widgets/glass_container.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _roleDatabase = RoleBasedDatabaseService();
  List<Announcement> _announcements = [];
  bool _isLoading = true;
  UserLoginDetails? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
    _markRead();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final user = await _roleDatabase.getCurrentUser();
      final data = await _roleDatabase.fetchAnnouncements();
      
      if (mounted) {
        setState(() {
          _currentUser = user;
          _announcements = data.map((json) => Announcement(
            title: json['title'],
            content: json['content'],
            date: DateTime.parse(json['date']),
            authorName: json['authorName'] ?? 'Unknown',
          )).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading announcements: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markRead() async {
    final user = await _roleDatabase.getCurrentUser();
    if (user != null) {
      await _roleDatabase.markAnnouncementsRead(user.email);
    }
  }

  bool get _canCreateAnnouncement {
    if (_currentUser == null) return false;
    final role = _currentUser!.role;
    return role == UserRole.admin || role == UserRole.moderator || role == UserRole.eventCoordinator;
  }

  void _showCreateDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('New Announcement', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Title',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.yellow)),
              ),
            ),
            TextField(
              controller: contentController,
              style: const TextStyle(color: Colors.white),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Content',
                labelStyle: TextStyle(color: Colors.grey),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.yellow)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Cancel', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black),
            onPressed: () async {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                final success = await _roleDatabase.createAnnouncement(
                  titleController.text,
                  contentController.text,
                  _currentUser?.username ?? 'Admin',
                );
                if (mounted) {
                  Navigator.pop(context);
                  if (success) {
                    _loadData();
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Announcement posted')));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to post')));
                  }
                }
              }
            },
            child: const Text('Post'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: const Text('Announcements'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: GlassContainer(
          child: Container(), // Empty child
          blur: 10,
          opacity: 0.1,
          borderRadius: BorderRadius.zero,
        ),
      ),
      floatingActionButton: _canCreateAnnouncement
          ? FloatingActionButton(
              onPressed: _showCreateDialog,
              backgroundColor: Colors.yellow,
              foregroundColor: Colors.black,
              child: const Icon(Icons.add),
            )
          : null,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [Colors.black, const Color(0xFF1A1A1A)]
                : [const Color(0xFFF5F7FA), Colors.white],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
            : _announcements.isEmpty
                ? const Center(child: Text('No announcements yet', style: TextStyle(color: Colors.grey)))
                : AnimationLimiter(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 100, 16, 16), // Top padding for transparent AppBar
                      itemCount: _announcements.length,
                      itemBuilder: (context, index) {
                        return AnimationConfiguration.staggeredList(
                          position: index,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: AnnouncementCard(announcement: _announcements[index]),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  final Announcement announcement;

  const AnnouncementCard({super.key, required this.announcement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16.0),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
      color: isDark ? Colors.white : Colors.black, // Invert base color for glass effect
      opacity: 0.05,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  announcement.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: isDark ? Colors.yellow : theme.colorScheme.primary, // Yellow in dark, black/primary in light
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat.MMMd().format(announcement.date),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
           if (announcement.authorName != null)
            Row(
              children: [
                Icon(Icons.person, size: 14, color: isDark ? Colors.grey : Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${announcement.authorName}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontStyle: FontStyle.italic, 
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          const SizedBox(height: 12),
          Text(
            announcement.content, 
            style: theme.textTheme.bodyLarge?.copyWith(
              color: isDark ? Colors.white.withOpacity(0.9) : Colors.black87,
            )
          ),
        ],
      ),
    );
  }
}
