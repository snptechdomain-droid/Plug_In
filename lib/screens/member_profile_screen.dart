import 'package:flutter/material.dart';
import 'package:app/models/role.dart';
import 'package:app/widgets/glass_container.dart';
import 'package:app/models/domain.dart';
import 'package:app/screens/user_attendance_screen.dart';

class MemberProfileScreen extends StatelessWidget {
  final UserLoginDetails member;
  final double attendance;

  const MemberProfileScreen({
    super.key,
    required this.member,
    required this.attendance,
  });

  Color _getDomainColor(String? domainStr) {
    if (domainStr == null) return Colors.grey;
    final domain = DomainExtension.fromString(domainStr);
    switch (domain) {
      case Domain.management: return Colors.blue;
      case Domain.tech: return Colors.greenAccent;
      case Domain.webDev: return Colors.cyanAccent;
      case Domain.content: return Colors.purpleAccent;
      case Domain.design: return Colors.pinkAccent;
      case Domain.marketing: return Colors.orangeAccent;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final domainColor = _getDomainColor(member.domain);
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white70 : Colors.black87;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Member Profile', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // Avatar & Name
            CircleAvatar(
              radius: 50,
              backgroundColor: domainColor,
              child: CircleAvatar(
                radius: 46,
                backgroundColor: isDark ? Colors.grey[900] : Colors.grey[200],
                backgroundImage: member.avatarUrl != null 
                    ? NetworkImage(member.avatarUrl!) 
                    : null,
                child: member.avatarUrl == null
                    ? Text(member.username[0].toUpperCase(), 
                        style: TextStyle(fontSize: 40, color: isDark ? Colors.white : Colors.black))
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              member.username,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
            ),
            if (member.domain != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: domainColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: domainColor.withOpacity(0.5)),
                ),
                child: Text(
                  member.domain!.toUpperCase(),
                  style: TextStyle(color: domainColor, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            
            const SizedBox(height: 30),
            
            // Details Card
            GlassContainer(
              padding: const EdgeInsets.all(20),
              color: isDark ? Colors.white : Colors.black, // Invert base color
              opacity: 0.05,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('Student Details', style: TextStyle(color: subTextColor, fontSize: 18, fontWeight: FontWeight.bold)),
                   Divider(color: isDark ? Colors.white24 : Colors.black12, height: 20),
                   _infoRow('Register Number', member.registerNumber ?? 'N/A', textColor),
                   _infoRow('Department', member.department ?? 'N/A', textColor),
                   _infoRow('Year', member.year ?? 'N/A', textColor),
                   _infoRow('Section', member.section ?? 'N/A', textColor),
                   _infoRow('Role', member.role.name.toUpperCase(), textColor),
                ],
              ),
            ),

            const SizedBox(height: 16),

             // Attendance Card
            GlassContainer(
              padding: const EdgeInsets.all(20),
              color: isDark ? Colors.white : Colors.black, // Invert base color
              opacity: 0.05,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text('Performance', style: TextStyle(color: subTextColor, fontSize: 18, fontWeight: FontWeight.bold)),
                   Divider(color: isDark ? Colors.white24 : Colors.black12, height: 20),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text('Attendance', style: TextStyle(color: isDark ? Colors.grey : Colors.grey[600])),
                       Text('${attendance.toStringAsFixed(1)}%', 
                         style: TextStyle(
                           color: attendance >= 75 ? Colors.greenAccent : (isDark ? Colors.redAccent : Colors.red), 
                           fontWeight: FontWeight.bold,
                           fontSize: 18
                         )
                       ),
                     ],
                   ),
                   const SizedBox(height: 16),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton.icon(
                       icon: Icon(Icons.list_alt, color: isDark ? Colors.black : Colors.white),
                       label: Text('View Detailed Attendance Log', style: TextStyle(color: isDark ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                       style: ElevatedButton.styleFrom(
                         backgroundColor: domainColor,
                         padding: const EdgeInsets.symmetric(vertical: 12),
                       ),
                       onPressed: () {
                          // Using direct navigation with arguments as defined in main routes normally
                          Navigator.push(
                            context, 
                            MaterialPageRoute(builder: (_) => UserAttendanceScreen(username: member.email))
                          );
                       },
                     ),
                   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: textColor.withOpacity(0.6))),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
