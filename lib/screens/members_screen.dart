import 'package:flutter/material.dart';
import 'package:app/services/role_database_service.dart';
import 'package:app/models/role.dart';
import 'dart:convert';
import 'package:app/widgets/glass_container.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:app/screens/user_attendance_screen.dart';
import 'package:app/screens/member_profile_screen.dart';
import 'package:app/models/domain.dart';

import 'package:app/widgets/app_drawer.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _roleDatabase = RoleBasedDatabaseService();
  List<UserLoginDetails> _members = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
  Map<String, double> _attendanceMap = {}; // Cache for O(1) Access
  bool _isLoading = true;

  UserLoginDetails? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadCurrentUser();
  }

  Future<void> _loadCurrentUser() async {
    final user = await _roleDatabase.getCurrentUser();
    if (mounted) {
      setState(() {
        _currentUser = user;
      });
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final members = await _roleDatabase.fetchAllUsers();
      final attendance = await _roleDatabase.fetchAttendanceRecords();
      
      // OPTIMIZATION: Pre-calculate attendance here
      final Map<String, double> calculatedMap = {};
      
      // Parse attendance ONCE
      final parsedRecords = attendance.where((r) => r['date'] != null).map((record) {
          return {
            'date': RoleBasedDatabaseService.parseDate(record['date']).toUtc(),
            'presentById': Set<String>.from(record['presentUserIds'] ?? []),
             // Fallback support if needed (username/email in list) but usually IDs are best
          };
      }).toList();

      for (var member in members) {
          final joinDate = member.createdAt.toUtc();
          int totalApplicable = 0;
          int presentCount = 0;

          for (var record in parsedRecords) {
              final recordDate = record['date'] as DateTime;
              if (recordDate.isAfter(joinDate)) {
                  totalApplicable++;
                  final presentSet = record['presentById'] as Set<String>;
                  if (presentSet.contains(member.id) || 
                      presentSet.contains(member.username) || 
                      presentSet.contains(member.email)) {
                      presentCount++;
                  }
              }
          }
          
          calculatedMap[member.username] = (totalApplicable == 0) 
              ? 0.0 
              : (presentCount / totalApplicable) * 100.0;
      }
      
      if (mounted) {
        setState(() {
          _members = members;
          _attendanceRecords = attendance;
          _attendanceMap = calculatedMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading members data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      drawer: const AppDrawer(currentRoute: '/members'),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          'Members',
          style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.yellow : Colors.blue), // Yellow/Blue refresh
            onPressed: () => _loadData(), // Fixed lambda reference
          ),
        ],
        flexibleSpace: GlassContainer(
          child: Container(), // Empty child
          blur: 10,
          opacity: 0.1,
          borderRadius: BorderRadius.zero,
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [Colors.black, const Color(0xFF1E1E1E)]
                : [const Color(0xFFF5F7FA), Colors.white],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
            : _members.isEmpty
                ? Center(child: Text('No members found', style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600])))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 100.0, left: 16, right: 16, bottom: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: _StatCard(
                                title: 'Total Members',
                                value: _members.length.toString(),
                                icon: Icons.group,
                                color: Colors.blueAccent,
                                isDark: isDark,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _StatCard(
                                title: 'Avg. Attendance',
                                value: '${_calculateAverageAttendance().toStringAsFixed(1)}%',
                                icon: Icons.bar_chart,
                                color: Colors.greenAccent,
                                isDark: isDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: AnimationLimiter(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            itemCount: _members.length,
                            itemBuilder: (context, index) {
                              final member = _members[index];
                              final attendancePercentage = _attendanceMap[member.username] ?? 0.0;

                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: MemberCard(
                                      name: member.username,
                                      role: member.role.displayName,
                                      attendance: attendancePercentage,
                                      avatarUrl: member.avatarUrl,
                                      domains: member.domains, // Pass list
                                      isDark: isDark,
                                      onEdit: (_currentUser?.role == UserRole.admin && member.username != 'admin')
                                          ? () => _showRoleDialog(member)
                                          : null,
                                      onDelete: _canDelete(member)
                                          ? () => _confirmDelete(member)
                                          : null,
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => MemberProfileScreen(
                                              member: member, 
                                              attendance: attendancePercentage
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  // ... (keeping other methods same, skipping large blocks of code if possible but need class structure)
  // Since I'm replacing build, I need to match everything or close bracket correctly.
  // Wait, I am replacing from 'build' onwards. I need to keep valid structure.
  
  // Actually, I'll update the _StatCard and MemberCard classes first as they are clean targets.
  // Then update build.
  bool _canDelete(UserLoginDetails targetUser) {
    if (_currentUser == null) return false;
    if (targetUser.username == 'admin') return false; // Protect root admin
    if (targetUser.username == _currentUser!.username) return false; // Prevent self-delete

    if (_currentUser!.role == UserRole.admin) return true;
    
    if (_currentUser!.role == UserRole.moderator) {
      return targetUser.role == UserRole.member || targetUser.role == UserRole.eventCoordinator;
    }
    
    return false;
  }

  double _calculateAttendance(UserLoginDetails user) {
    final joinDate = user.createdAt;

    int totalApplicable = 0;
    int presentCount = 0;

    for (var record in _attendanceRecords) {
      if (record['date'] != null) {
        final recordDate = RoleBasedDatabaseService.parseDate(record['date']).toUtc();
        final joinDateUtc = joinDate.toUtc();
        // Only count records AFTER the user joined
        if (recordDate.isAfter(joinDateUtc)) {
           totalApplicable++;
           final presentIds = List<String>.from(record['presentUserIds'] ?? []);
           // Match by ID (primary), or username/email (legacy/fallback)
           if (presentIds.contains(user.id) || presentIds.contains(user.username) || presentIds.contains(user.email)) {
             presentCount++;
           }
        }
      }
    }

    if (totalApplicable == 0) return 0.0;
    return (presentCount / totalApplicable) * 100.0;
  }

  double _calculateAverageAttendance() {
    if (_members.isEmpty) return 0.0;
    double total = 0;
    for (var member in _members) {
      total += _calculateAttendance(member);
    }
    return total / _members.length;
  }

  Future<void> _confirmDelete(UserLoginDetails user) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Confirm Deletion', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Text(
          'Are you sure you want to remove ${user.username}?\nThis action cannot be undone.', 
          style: TextStyle(color: isDark ? Colors.grey : Colors.grey[800]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _roleDatabase.deleteUserFromBackend(user.email); // Use email as ID/username
      if (success) {
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${user.username} removed successfully')),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to remove user')),
          );
        }
      }
    }
  }

  void _showRoleDialog(UserLoginDetails user) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Edit Role for ${user.username}', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: UserRole.values.where((r) => r != UserRole.guest).map((role) {
            return ListTile(
              title: Text(role.displayName, style: TextStyle(color: isDark ? Colors.white : Colors.black)),
              leading: Radio<UserRole>(
                value: role,
                groupValue: user.role,
                activeColor: isDark ? Colors.yellow : Colors.blue,
                fillColor: MaterialStateProperty.resolveWith((states) => 
                  states.contains(MaterialState.selected) ? (isDark ? Colors.yellow : Colors.blue) : Colors.grey),
                onChanged: (UserRole? value) async {
                  if (value != null) {
                    Navigator.pop(dialogContext); // Close dialog using dialogContext
                    final success = await _roleDatabase.changeUserRole(user.email, value.value.toUpperCase());
                    
                    if (!mounted) return; // Check if MembersScreen is mounted

                    if (success) {
                      _loadData(); // Reload list
                      ScaffoldMessenger.of(context).showSnackBar( // Use MembersScreen context
                        const SnackBar(content: Text('Role updated successfully')),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to update role')),
                      );
                    }
                  }
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark; // Added

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark, // Added
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16.0),
      borderRadius: BorderRadius.circular(16),
      color: isDark ? Colors.white : Colors.black, // Invert base color
      opacity: 0.05,
      border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
          Text(title, style: TextStyle(fontSize: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class MemberCard extends StatelessWidget {
  final String name;
  final String role;
  final double attendance;
  final String? avatarUrl; 
  final String? domain; // Legacy
  final List<String> domains; // Added
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;
  final bool isDark; 

  const MemberCard({
    super.key,
    required this.name,
    required this.role,
    required this.attendance,
    this.avatarUrl,
    this.domain, 
    this.domains = const [], // Added
    this.onEdit,
    this.onDelete,
    this.onTap,
    required this.isDark, 
  });

  Color _getAttendanceColor(double percentage) {
    if (percentage >= 75.0) {
      return Colors.greenAccent;
    } else if (percentage >= 50.0) {
      return Colors.orangeAccent;
    } else {
      return Colors.redAccent;
    }
  }

  Color _getDomainColor(String? domainStr) {
    if (domainStr == null) return Colors.grey;
    final domainEnum = DomainExtension.fromString(domainStr);
    switch (domainEnum) {
      case Domain.management: return Colors.blue;
      case Domain.tech: return Colors.tealAccent;
      case Domain.webDev: return Colors.cyan;
      case Domain.content: return Colors.purpleAccent;
      case Domain.design: return Colors.pinkAccent;
      case Domain.marketing: return Colors.orangeAccent;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final domainColor = _getDomainColor(domain);

    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(16),
      color: isDark ? Colors.white : Colors.black, // Invert base
      opacity: 0.05,
      border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: domainColor.withOpacity(0.2), // Use domain color
          backgroundImage: (avatarUrl != null && avatarUrl!.isNotEmpty)
              ? (avatarUrl!.startsWith('http') 
                  ? NetworkImage(avatarUrl!) 
                  : MemoryImage(base64Decode(avatarUrl!.contains(',') ? avatarUrl!.split(',').last : avatarUrl!)) as ImageProvider)
              : null,
          child: (avatarUrl == null || avatarUrl!.isEmpty)
              ? Text(
                  domain != null ? DomainExtension.fromString(domain!)?.code ?? 'U' : 'U',
                  style: TextStyle(fontWeight: FontWeight.bold, color: domainColor),
                )
              : null,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        title: Row(
          children: [
             if (domains.isNotEmpty) ...[
               for (var domainStr in domains.take(2)) ...[
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getDomainColor(domainStr).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _getDomainColor(domainStr).withOpacity(0.5), width: 0.5),
                    ),
                    child: Text(
                      domainStr.toUpperCase(),
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getDomainColor(domainStr)),
                    ),
                  ),
               ],
               if (domains.length > 2)
                 Text('+${domains.length - 2}', style: TextStyle(fontSize: 10, color: isDark ? Colors.grey : Colors.grey[600])),
            ],
            // Legacy/Fallback for null list but present single domain (transition phase)
            if (domains.isEmpty && domain != null) ...[ 
               Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _getDomainColor(domain).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getDomainColor(domain).withOpacity(0.5), width: 0.5),
                ),
                child: Text(
                  domain!.toUpperCase(),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: _getDomainColor(domain)),
                ),
              ),
            ],
            Flexible(
              child: Text(
                name,
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Text(
          role,
          style: TextStyle(fontSize: 15, color: isDark ? Colors.grey.shade400 : Colors.grey.shade700),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                icon: Icon(Icons.edit_note, color: isDark ? Colors.yellow : Colors.blue),
                onPressed: onEdit,
              ),
            if (onDelete != null)
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: onDelete,
              ),
            Text(
              '${attendance.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _getAttendanceColor(attendance), // Keep colorful status
              ),
            ),
          ],
        ),
      ),
    );
  }
}