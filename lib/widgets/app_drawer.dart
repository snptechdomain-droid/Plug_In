
import 'package:app/screens/announcements_screen.dart';
import 'package:app/screens/attendance_screen.dart';
import 'package:app/screens/collaboration_screen.dart';
import 'package:app/screens/events_screen.dart';
import 'package:app/screens/members_screen.dart';
import 'package:app/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final List<Map<String, dynamic>> dashboardItems = [
      {
        'title': 'Attendance',
        'icon': Lottie.asset('assets/lottie/attendance.json',
            repeat: true, animate: true, fit: BoxFit.contain),
        'destination': const AttendanceScreen(),
      },
      {
        'title': 'Events',
        'icon': Lottie.asset('assets/lottie/events.json',
            repeat: true, animate: true, fit: BoxFit.contain),
        'destination': const EventsScreen(),
      },
      {
        'title': 'Collaboration',
        'icon': Lottie.asset('assets/lottie/collaboration.json',
            repeat: true, animate: true, fit: BoxFit.contain),
        'destination': const CollaborationScreen(),
      },
      {
        'title': 'Announcements',
        'icon': Lottie.asset('assets/lottie/announcements.json',
            repeat: true, animate: true, fit: BoxFit.contain),
        'destination': const AnnouncementsScreen(),
      },
      {
        'title': 'Members',
        'icon': Lottie.asset('assets/lottie/members.json',
            repeat: true, animate: true, fit: BoxFit.contain),
        'destination': const MembersScreen(),
      },
      {
        'title': 'Settings',
        'icon': const Icon(Icons.settings_outlined, size: 40, color: Colors.black),
        'destination': const SettingsScreen(),
      },
    ];

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primary),
            child: Text('Navigation',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(color: Colors.white)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.home, color: Colors.black87),
            title: const Text('Home'),
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacementNamed('/dashboard');
            },
          ),
          ...dashboardItems.map((item) {
            return ListTile(
              leading: SizedBox(
                width: 30,
                height: 30,
                child: item['icon'] as Widget,
              ),
              title: Text(item['title'] as String),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => item['destination'] as Widget));
              },
            );
          }).toList(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout'),
            onTap: () {
              Navigator.of(context)
                  .pushNamedAndRemoveUntil('/login', (route) => false);
            },
          ),
        ],
      ),
    );
  }
}
