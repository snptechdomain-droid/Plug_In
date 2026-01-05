import 'package:flutter/material.dart';
import 'package:app/services/role_database_service.dart';
import 'package:app/widgets/glass_container.dart';
import 'package:intl/intl.dart';
import 'package:app/models/role.dart';

class UserAttendanceScreen extends StatefulWidget {
  final String username;

  const UserAttendanceScreen({super.key, required this.username});

  @override
  State<UserAttendanceScreen> createState() => _UserAttendanceScreenState();
}

class _UserAttendanceScreenState extends State<UserAttendanceScreen> {
  final _roleDatabase = RoleBasedDatabaseService();
  List<Map<String, dynamic>> _attendanceHistory = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Fetch target user to get createdAt
      // 1. Fetch target user to get createdAt - Try specific fetch first
      var user = await _roleDatabase.getUserByUsername(widget.username);
      
      if (user == null) {
         // Fallback: try searching in all users list as backup
         final allUsers = await _roleDatabase.getAllUsers();
         user = allUsers.firstWhere(
            (u) => u.email == widget.username || u.username == widget.username,
            orElse: () => UserLoginDetails(
              username: widget.username, 
              email: '', 
              passwordHash: '', 
              role: UserRole.member,
              createdAt: DateTime(2000), // Fallback to 2000 to show ALL history if date unknown
            ),
         );
      }
      
      final joinDate = user.createdAt;

      // 2. Fetch all raw attendance history
      final history = await _roleDatabase.fetchUserAttendance(widget.username);
      
      // 3. Filter history based on joinDate
      final filteredHistory = history.where((record) {
        if (record['date'] == null) return false;
        final recordDate = RoleBasedDatabaseService.parseDate(record['date']).toUtc();
        final joinDateUtc = joinDate.toUtc();
        // Include events strictly after joining OR if they were marked present
        return recordDate.isAfter(joinDateUtc) || record['status'] == 'PRESENT';
      }).toList();

      if (mounted) {
        setState(() {
          _attendanceHistory = filteredHistory;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading attendance history: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _calculatePercentage() {
    if (_attendanceHistory.isEmpty) return 0.0;
    int present = _attendanceHistory.where((r) => r['status'] == 'PRESENT').length;
    return (present / _attendanceHistory.length) * 100.0;
  }

  @override
  Widget build(BuildContext context) {
    final percentage = _calculatePercentage();
    final isPresentable = percentage >= 75.0;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Attendance History', 
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black, // Dark text on light
            fontWeight: FontWeight.bold
          )
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black), // Dark icon on light
        flexibleSpace: GlassContainer(child: Container(), opacity: 0.1, blur: 10),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [Colors.black, const Color(0xFF1E1E1E)]
                : [const Color(0xFFF5F7FA), Colors.white], // Light gradient
          ),
        ),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.yellow))
            : Column(
                children: [
                  const SizedBox(height: 100),
                  // Stats Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: GlassContainer(
                      padding: const EdgeInsets.all(24),
                      borderRadius: BorderRadius.circular(16),
                      color: isDark ? Colors.white : Colors.black, // Invert base color
                      opacity: 0.05,
                      border: Border.all(color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.1)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              Text('${percentage.toStringAsFixed(1)}%', 
                                style: TextStyle(
                                  fontSize: 32, 
                                  fontWeight: FontWeight.bold, 
                                  color: isPresentable ? Colors.greenAccent : Colors.redAccent
                                )
                              ),
                              Text('Attendance Rate', 
                                style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600])
                              ),
                            ],
                          ),
                          Container(height: 50, width: 1, 
                            color: isDark ? Colors.white24 : Colors.black12
                          ),
                          Column(
                            children: [
                              Text('${_attendanceHistory.length}', 
                                style: TextStyle(
                                  fontSize: 32, 
                                  fontWeight: FontWeight.bold, 
                                  color: isDark ? Colors.white : Colors.black
                                )
                              ),
                              Text('Total Sessions', 
                                style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600])
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Timeline List
                  Expanded(
                    child: ListView.builder(
                      itemCount: _attendanceHistory.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, index) {
                        final record = _attendanceHistory[index];
                        final isPresent = record['status'] == 'PRESENT';
                        final date = RoleBasedDatabaseService.parseDate(record['date']);
                        final notes = record['notes'];

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: GlassContainer(
                            borderRadius: BorderRadius.circular(12),
                            color: isPresent ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                            // Tint background slightly for status, keep generic base
                            opacity: 0.05,
                            border: Border.all(color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05)),
                            child: ListTile(
                              leading: Icon(
                                isPresent ? Icons.check_circle : Icons.cancel,
                                color: isPresent ? Colors.greenAccent : Colors.redAccent,
                                size: 30,
                              ),
                                title: Text(
                                DateFormat('dd/MM/yyyy - hh:mm a').format(date.toLocal()),
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black87, 
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                              subtitle: notes != null && notes.isNotEmpty 
                                ? Text(notes, 
                                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54)
                                  )
                                : null,
                              trailing: Text(
                                isPresent ? 'PRESENT' : 'ABSENT',
                                style: TextStyle(
                                  color: isPresent ? Colors.greenAccent : Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
