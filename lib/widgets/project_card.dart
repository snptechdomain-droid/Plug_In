import 'package:flutter/material.dart';
import 'package:app/models/collaboration.dart'; // Using generic Map, or Collaboration model if needed

class ProjectCard extends StatelessWidget {
  final Map<String, dynamic> project;
  final VoidCallback onTap;
  final VoidCallback? onSettingsTap;
  final bool isSelected;

  const ProjectCard({
    super.key,
    required this.project,
    required this.onTap,
    this.onSettingsTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    // Determine Type Icon & Color
    IconData icon = Icons.folder;
    Color color = Colors.blue;
    final String title = project['title'] ?? 'Untitled';
    
    // Heuristic to guess type if not explicit, or use explicit 'type' field
    // For now, defaulting to generic, but can be enhanced based on 'tools' usage
    if (title.toLowerCase().contains('mindmap')) {
      icon = Icons.psychology;
      color = Colors.purple;
    } else if (title.toLowerCase().contains('flowchart')) {
      icon = Icons.account_tree;
      color = Colors.orange; 
    } else if (title.toLowerCase().contains('timeline')) {
      icon = Icons.timeline;
      color = Colors.teal;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withOpacity(0.15) 
              : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white10 : Colors.black12),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              offset: const Offset(0, 4),
              blurRadius: 12,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Background Gradient Splash
              Positioned(
                right: -20,
                top: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Icon Container
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const SizedBox(width: 16),
                    // Text Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Owner: ${(project['ownerId'] as String).split('@')[0]}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                          const SizedBox(height: 4),
                           Text(
                            'Active Users: ${(project['activeUsers'] as List?)?.length ?? 0}',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Action
                    if (onSettingsTap != null)
                      IconButton(
                        icon: const Icon(Icons.settings, size: 20),
                        onPressed: onSettingsTap,
                        color: theme.iconTheme.color?.withOpacity(0.5),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
