import 'package:flutter/material.dart';
import 'package:app/models/role.dart';
import 'package:app/models/domain.dart';
import 'package:app/screens/user_attendance_screen.dart';
import 'package:app/widgets/glass_container.dart';

class MemberProfileScreen extends StatelessWidget {
  final UserLoginDetails member;
  final double attendance;

  const MemberProfileScreen({
    super.key,
    required this.member,
    required this.attendance,
  });

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // FIX: Properly handle dynamic domain labels and bright badge colors
    final domainLabel = member.domain?.label ?? 'Not set';
    final badgeColor = member.domain?.badgeColor ?? Colors.yellow;
    final attendanceText = '${attendance.toStringAsFixed(1)}%';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        flexibleSpace: GlassContainer(child: Container(), opacity: 0.1, blur: 10),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.black, Color(0xFF1E1E1E)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 110, 16, 24),
          child: Column(
            children: [
              GlassContainer(
                padding: const EdgeInsets.all(20),
                borderRadius: BorderRadius.circular(18),
                color: Colors.white,
                opacity: 0.05,
                border: Border.all(color: Colors.white.withOpacity(0.08)),
                child: Column(
                  children: [
                    // FIX: Glowing Avatar using the Bright Domain Badge Color
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: badgeColor.withOpacity(0.3),
                            blurRadius: 15,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 34,
                        backgroundColor: badgeColor.withOpacity(0.15),
                        child: Text(
                          member.domain?.shortLabel ?? member.username.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            color: badgeColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      member.username,
                      style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    // FIX: Dynamic Role Display (Lead vs Member)
                    Text(
                      member.role == UserRole.moderator ? 'Lead ($domainLabel)' : member.role.displayName,
                      style: TextStyle(color: badgeColor.withOpacity(0.8), fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Colors.white10),
                    const SizedBox(height: 8),
                    _infoRow('Reg No', member.registerNumber ?? 'N/A'),
                    _infoRow('Email', member.email),
                    _infoRow('Year', member.year ?? 'N/A'),
                    _infoRow('Section', member.section ?? 'N/A'),
                    _infoRow('Domain', domainLabel),
                    _infoRow('Attendance', attendanceText),

                    // Display backend Bio if it contains formatted data
                    if (member.bio != null && member.bio!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Divider(color: Colors.white10),
                      const SizedBox(height: 8),
                      Text("Detailed Registration Info", style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(member.bio!, style: const TextStyle(color: Colors.white70, fontSize: 14), textAlign: TextAlign.center),
                    ],
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.yellow,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => UserAttendanceScreen(username: member.email),
                      ),
                    );
                  },
                  icon: const Icon(Icons.list_alt),
                  label: const Text('View Detailed Attendance Log'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}