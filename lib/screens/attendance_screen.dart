import 'package:flutter/material.dart';
import 'package:app/services/role_database_service.dart';
import 'package:app/models/role.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _roleDatabase = RoleBasedDatabaseService();
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

  bool get _canManageAttendance {
    return _currentUser?.role == UserRole.admin || _currentUser?.role == UserRole.moderator;
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final attendance = await _roleDatabase.fetchAttendanceRecords();
      if (mounted) {
        setState(() {
          _attendanceRecords = attendance;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading attendance data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showMarkAttendanceDialog() async {
    final users = await _roleDatabase.fetchAllUsers();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _MarkAttendanceDialog(
        users: users,
        onSave: (selectedUserIds, notes) async {
          final success = await _roleDatabase.markAttendance(selectedUserIds, notes);
          if (success) {
            if (mounted) {
              Navigator.pop(context);
              _loadData(); // Refresh list
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Attendance marked successfully')),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Failed to mark attendance')),
              );
            }
          }
        },
      ),
    );
  }

  void _showEditAttendanceDialog(Map<String, dynamic> record) async {
    final users = await _roleDatabase.fetchAllUsers();
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => _MarkAttendanceDialog(
        users: users,
        initialSelectedIds: List<String>.from(record['presentUserIds'] ?? []),
        initialNotes: record['notes'],
        onSave: (selectedUserIds, notes) async {
          final errorMsg = await _roleDatabase.updateAttendance(record['id'], selectedUserIds, notes);
          if (errorMsg == null) {
            if (mounted) {
              Navigator.pop(context);
              _loadData(); // Refresh list
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Attendance updated successfully')),
              );
            }
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(errorMsg)),
              );
            }
          }
        },
      ),
    );
  }

  void _deleteAttendance(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Attendance'),
        content: const Text('Are you sure you want to delete this record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await _roleDatabase.deleteAttendance(id);
      if (mounted) {
        if (success) {
          _loadData();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attendance deleted successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete attendance')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Logs'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      floatingActionButton: _canManageAttendance 
          ? FloatingActionButton(
              onPressed: _showMarkAttendanceDialog,
              child: const Icon(Icons.add),
            )
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _attendanceRecords.isEmpty
              ? const Center(child: Text('No attendance records found'))
              : Column(
                  children: [
                    // Stats Summary
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatCard(
                              title: 'Total Sessions',
                              value: _attendanceRecords.length.toString(),
                              icon: Icons.event_note,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _StatCard(
                              title: 'Avg. Attendance',
                              value: _calculateAverageAttendance().toStringAsFixed(1),
                              icon: Icons.groups,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: _attendanceRecords.length,
                        itemBuilder: (context, index) {
                          final record = _attendanceRecords[index];
                          final date = DateTime.parse(record['date']);
                          final presentCount = (record['presentUserIds'] as List).length;
                          final notes = record['notes'] ?? '';

                          final isEditable = DateTime.now().difference(date).inMinutes < 60;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.blue.shade100,
                                child: Text(
                                  DateFormat('dd').format(date),
                                  style: TextStyle(color: Colors.blue.shade800, fontWeight: FontWeight.bold),
                                ),
                              ),
                              title: Text(DateFormat('MMMM yyyy, HH:mm').format(date)),
                              subtitle: Text(notes.isNotEmpty ? notes : 'No notes'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: Text('$presentCount Present'),
                                    backgroundColor: Colors.green.shade100,
                                    labelStyle: TextStyle(color: Colors.green.shade800),
                                  ),
                                  if (_canManageAttendance) ...[
                                     if (isEditable)
                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () => _showEditAttendanceDialog(record),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _deleteAttendance(record['id']),
                                    ),
                                  ],
                                ],
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
  

  double _calculateAverageAttendance() {
    if (_attendanceRecords.isEmpty) return 0.0;
    int totalPresent = 0;
    for (var record in _attendanceRecords) {
      totalPresent += (record['presentUserIds'] as List).length;
    }
    return totalPresent / _attendanceRecords.length;
  }
}

class _MarkAttendanceDialog extends StatefulWidget {
  final List<UserLoginDetails> users;
  final Function(List<String>, String) onSave;
  final List<String>? initialSelectedIds;
  final String? initialNotes;

  const _MarkAttendanceDialog({
    required this.users, 
    required this.onSave,
    this.initialSelectedIds,
    this.initialNotes,
  });

  @override
  State<_MarkAttendanceDialog> createState() => _MarkAttendanceDialogState();
}

class _MarkAttendanceDialogState extends State<_MarkAttendanceDialog> {
  late List<String> _selectedUsernames;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _selectedUsernames = widget.initialSelectedIds != null 
        ? List.from(widget.initialSelectedIds!) 
        : [];
    _notesController = TextEditingController(text: widget.initialNotes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mark Attendance'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Select Present Members:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.users.length,
                itemBuilder: (context, index) {
                  final user = widget.users[index];
                  final isSelected = _selectedUsernames.contains(user.bio) ||
                                     _selectedUsernames.contains(user.email) || 
                                     _selectedUsernames.contains(user.username);
                  
                  return CheckboxListTile(
                    title: Text(user.username),
                    subtitle: Text(user.role.displayName),
                    value: isSelected,
                      // Change lines 253-259 in attendance_screen.dart to this:
                      onChanged: (bool? value) {
                        setState(() {
                          // Teammate likely removed .id. Use .email as the primary identifier
                          final idToSave = user.email.isNotEmpty ? user.email : user.username;

                          if (value == true) {
                            _selectedUsernames.add(idToSave);
                          } else {
                            _selectedUsernames.remove(user.email);
                            _selectedUsernames.remove(user.username);
                          }
                        });
                      }

                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onSave(_selectedUsernames, _notesController.text);
          },
          child: const Text('Save'),
        ),
      ],
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
          ],
        ),
      ),
    );
  }
}