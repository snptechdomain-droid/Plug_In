import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/services/role_database_service.dart';
import 'package:app/models/role.dart';
import 'package:app/models/domain.dart';
import 'dart:convert';
import 'package:app/widgets/glass_container.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:app/screens/member_profile_screen.dart';
import 'package:app/screens/user_attendance_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _roleDatabase = RoleBasedDatabaseService();
  List<UserLoginDetails> _members = [];
  List<Map<String, dynamic>> _attendanceRecords = [];
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
      
      if (mounted) {
        setState(() {
          _members = members;
          _attendanceRecords = attendance;
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

  double _calculateAttendance(String username) {
    if (_attendanceRecords.isEmpty) return 0.0;
    
    int presentCount = 0;
    for (var record in _attendanceRecords) {
      final presentIds = List<String>.from(record['presentUserIds'] ?? []);
      // Assuming username is used as ID for now, or we need to match by ID if available
      // Since UserLoginDetails doesn't have ID, we use username. 
      // Ideally backend should return ID and we use that.
      if (presentIds.contains(username)) {
        presentCount++;
      }
    }
    
    return (presentCount / _attendanceRecords.length) * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Members',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.yellow),
            onPressed: _loadData,
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black, Color(0xFF1E1E1E)],
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
            : _members.isEmpty
                ? const Center(child: Text('No members found', style: TextStyle(color: Colors.grey)))
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
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _StatCard(
                                title: 'Avg. Attendance',
                                value: '${_calculateAverageAttendance().toStringAsFixed(1)}%',
                                icon: Icons.bar_chart,
                                color: Colors.greenAccent,
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
                              final attendancePercentage = _calculateAttendance(member.email);

                              return AnimationConfiguration.staggeredList(
                                position: index,
                                duration: const Duration(milliseconds: 375),
                                child: SlideAnimation(
                                  verticalOffset: 50.0,
                                  child: FadeInAnimation(
                                    child: MemberCard(
                                      name: member.username,
                                      role: member.role,
                                      domain: member.domain,
                                      attendance: attendancePercentage,
                                      avatarUrl: member.avatarUrl,
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
                                              attendance: attendancePercentage,
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

  double _calculateAverageAttendance() {
    if (_members.isEmpty) return 0.0;
    double total = 0;
    for (var member in _members) {
      total += _calculateAttendance(member.username);
    }
    return total / _members.length;
  }

  Future<void> _confirmDelete(UserLoginDetails user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Confirm Deletion', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to remove ${user.username}?\nThis action cannot be undone.', 
          style: const TextStyle(color: Colors.grey),
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('Edit Role for ${user.username}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: UserRole.values.where((r) => r != UserRole.guest).map((role) {
            return ListTile(
              title: Text(role.displayName, style: const TextStyle(color: Colors.white)),
              leading: Radio<UserRole>(
                value: role,
                groupValue: user.role,
                activeColor: Colors.yellow,
                fillColor: MaterialStateProperty.resolveWith((states) => 
                  states.contains(MaterialState.selected) ? Colors.yellow : Colors.grey),
                onChanged: (UserRole? value) async {
                  if (value != null) {
                    Navigator.pop(dialogContext); // Close dialog using dialogContext
                    Domain? selectedDomain;
                    if (value == UserRole.moderator) {
                      selectedDomain = await _promptDomainSelection();
                      if (selectedDomain == null) return;
                    }

                    final success = await _roleDatabase.changeUserRole(
                      user.email,
                      value.value.toUpperCase(),
                      domain: selectedDomain,
                    );
                    
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

  Future<Domain?> _promptDomainSelection() async {
    Domain? selected = Domain.tech;
    return showDialog<Domain>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Select Domain', style: TextStyle(color: Colors.white)),
        content: StatefulBuilder(
          builder: (context, setState) => DropdownButtonFormField<Domain>(
            value: selected,
            dropdownColor: const Color(0xFF1E1E1E),
            iconEnabledColor: Colors.yellow,
            items: Domain.values
                .map((d) => DropdownMenuItem(
                      value: d,
                      child: Text(d.label, style: const TextStyle(color: Colors.white)),
                    ))
                .toList(),
            onChanged: (val) => setState(() => selected = val),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selected),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.yellow, foregroundColor: Colors.black),
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(16.0),
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      opacity: 0.05,
      border: Border.all(color: Colors.white.withOpacity(0.1)),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

class MemberCard extends StatelessWidget {
  final String name;
  final UserRole role;
  final double attendance;
  final String? avatarUrl;
  final Domain? domain;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onTap;

  const MemberCard({
    super.key,
    required this.name,
    required this.role,
    required this.attendance,
    required this.domain,
    this.avatarUrl,
    this.onEdit,
    this.onDelete,
    this.onTap,
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

  bool _isSvgData(String data) {
    final lower = data.toLowerCase();
    return lower.contains('svg+xml') ||
        lower.trim().startsWith('<svg') ||
        lower.startsWith('phn2zy'); // base64 for "<svg"
  }

  ImageProvider? _buildAvatarImage() {
    if (avatarUrl == null || avatarUrl!.isEmpty) return null;
    if (_isSvgData(avatarUrl!)) return null;

    if (avatarUrl!.startsWith('http')) {
      return NetworkImage(avatarUrl!);
    }

    try {
      final bytes = base64Decode(
          avatarUrl!.contains(',') ? avatarUrl!.split(',').last : avatarUrl!);
      return MemoryImage(bytes);
    } catch (_) {
      return null;
    }
  }

  Widget _buildAvatarChild() {
    if (avatarUrl != null && avatarUrl!.isNotEmpty && _isSvgData(avatarUrl!)) {
      try {
        final svgString = avatarUrl!.contains(',')
            ? utf8.decode(base64Decode(avatarUrl!.split(',').last))
            : avatarUrl!;
        return SvgPicture.string(
          svgString,
          width: 28,
          height: 28,
          colorFilter: const ColorFilter.mode(Colors.yellow, BlendMode.srcIn),
        );
      } catch (_) {
        // Fall through to domain badge
      }
    }
    final text = domain?.shortLabel ?? name.substring(0, 1).toUpperCase();
    final color = domain?.badgeColor ?? Colors.yellow;
    return Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }

  String _roleLabel() {
    if (role == UserRole.moderator) {
      return 'Lead (${domain?.label ?? 'Domain'})';
    }
    return role.displayName;
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      margin: const EdgeInsets.only(bottom: 12),
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      opacity: 0.05,
      border: Border.all(color: Colors.white.withOpacity(0.05)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: (domain?.badgeColor ?? Colors.yellow).withOpacity(0.18),
          backgroundImage: _buildAvatarImage(),
          child: _buildAvatarChild(),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
            if (domain != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: domain!.badgeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: domain!.badgeColor.withOpacity(0.4)),
                ),
                child: Text(
                  domain!.shortLabel,
                  style: TextStyle(
                    color: domain!.badgeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Text(
          _roleLabel(),
          style: TextStyle(fontSize: 15, color: Colors.grey.shade400),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                icon: const Icon(Icons.edit_note, color: Colors.yellow),
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
                color: _getAttendanceColor(attendance),
              ),
            ),
          ],
        ),
      ),
    );
  }
}