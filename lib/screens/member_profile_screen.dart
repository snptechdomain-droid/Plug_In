import 'package:flutter/material.dart';
import 'package:app/models/role.dart';
import 'package:app/widgets/glass_container.dart';
import 'package:app/models/domain.dart';
import 'package:app/screens/user_attendance_screen.dart';
import 'package:app/services/role_database_service.dart';

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
    
    // Use first domain for primary color context, or gray
    final primaryDomain = (member.domains.isNotEmpty) ? member.domains.first : member.domain;
    final domainColor = _getDomainColor(primaryDomain);
    
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white70 : Colors.black87;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text('Member Profile', style: TextStyle(color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
           IconButton(
             icon: const Icon(Icons.edit),
             onPressed: () => _showEditProfileDialog(context),
           ),
        ],
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
            const SizedBox(height: 16),
            Text(
              member.username,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textColor),
            ),
            if (member.leadOfDomain != null && member.leadOfDomain!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.amber),
                  ),
                  child: Text(
                    '${member.leadOfDomain} Lead',
                    style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                 if (member.domains.isNotEmpty)
                    for (var d in member.domains)
                      _buildDomainBadge(d, _getDomainColor(d))
                 else if (member.domain != null)
                      _buildDomainBadge(member.domain!, domainColor),
              ],
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
                   _infoRow('Mobile', member.mobileNumber ?? 'N/A', textColor),
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
  Widget _buildDomainBadge(String domain, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        domain.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
  
  void _showEditProfileDialog(BuildContext context) async {
    final currentUser = await RoleBasedDatabaseService().getCurrentUser();
    final isAdmin = currentUser?.role == UserRole.admin;

    final nameCtrl = TextEditingController(text: member.username); // username is display name
    final bioCtrl = TextEditingController(text: member.bio ?? '');
    final deptCtrl = TextEditingController(text: member.department ?? '');
    final yearCtrl = TextEditingController(text: member.year ?? '');
    final secCtrl = TextEditingController(text: member.section ?? '');
    final regCtrl = TextEditingController(text: member.registerNumber ?? '');
    final mobileCtrl = TextEditingController(text: member.mobileNumber ?? '');
    final emailCtrl = TextEditingController(text: member.email);
    
    // Domain & Lead State
    List<String> selectedDomains = List.from(member.domains);
    String? selectedLeadDomain = member.leadOfDomain;

    // Available domains
    final allDomains = Domain.values.map((d) => d.name).toList();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          return AlertDialog(
             backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
             title: Text('Edit Profile', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
             content: SingleChildScrollView(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                    TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Display Name')),
                    TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: 'Email Address')),
                    TextField(controller: bioCtrl, decoration: const InputDecoration(labelText: 'Bio')),
                    const Divider(),
                    TextField(controller: regCtrl, decoration: const InputDecoration(labelText: 'Register Number')),
                    TextField(controller: mobileCtrl, decoration: const InputDecoration(labelText: 'Mobile Number')),
                    Row(children: [
                        Expanded(child: TextField(controller: deptCtrl, decoration: const InputDecoration(labelText: 'Dept'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'Year'))),
                        const SizedBox(width: 8),
                        Expanded(child: TextField(controller: secCtrl, decoration: const InputDecoration(labelText: 'Sec'))),
                    ]),
                    const SizedBox(height: 10),
                    
                    if (isAdmin) ...[
                      const Divider(),
                      const Text('Admin Controls', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      // Multi-select Domains
                      ExpansionTile(
                        title: const Text('Domains'),
                        subtitle: Text(selectedDomains.join(', ')),
                        children: allDomains.map((domainStr) {
                          return CheckboxListTile(
                            title: Text(domainStr.toUpperCase()),
                            value: selectedDomains.contains(domainStr),
                            onChanged: (val) {
                              setState(() {
                                if (val == true) {
                                  selectedDomains.add(domainStr);
                                } else {
                                  selectedDomains.remove(domainStr);
                                  // If removed domain was the lead domain, clear lead
                                  if (selectedLeadDomain == domainStr) {
                                    selectedLeadDomain = null;
                                  }
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 8),
                      // Lead Selection
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Lead of Domain'),
                        value: selectedDomains.contains(selectedLeadDomain) ? selectedLeadDomain : null,
                        items: [
                          const DropdownMenuItem<String>(value: null, child: Text('None')),
                          ...selectedDomains.map((d) => DropdownMenuItem(
                            value: d, 
                            child: Text(d.toUpperCase()),
                          ))
                        ],
                        onChanged: (val) => setState(() => selectedLeadDomain = val),
                      ),
                    ] else 
                      const Text('Role and Domain cannot be changed here.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                 ],
               ),
             ),
             actions: [
               TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
               ElevatedButton(
                 onPressed: () async {
                    final service = RoleBasedDatabaseService();
                    final success = await service.updateUserProfile(
                      member.email, 
                      nameCtrl.text, 
                      bioCtrl.text, 
                      member.avatarUrl,
                      department: deptCtrl.text,
                      year: yearCtrl.text,
                      section: secCtrl.text,
                      registerNumber: regCtrl.text,
                      mobileNumber: mobileCtrl.text,
                      newEmail: emailCtrl.text.trim() != member.email ? emailCtrl.text.trim() : null,
                      domains: isAdmin ? selectedDomains : null,
                      leadOfDomain: isAdmin ? (selectedLeadDomain ?? '') : null, // Empty string to clear
                    );
                    
                    if (context.mounted) {
                      Navigator.pop(context);
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile Updated!')));
                      } else {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update. Check conflicts.')));
                      }
                    }
                 },
                 child: const Text('Save'),
               ),
             ],
          );
        }
      ),
    );
  }
}
