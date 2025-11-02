import 'package:flutter/material.dart';
import 'package:app/models/announcement.dart';
import 'package:app/models/event.dart';
import 'package:app/screens/announcements_screen.dart' as announcements_data;
import 'package:app/screens/events_screen.dart' as events_data;
import 'package:intl/intl.dart';

class GuestScreen extends StatefulWidget {
  const GuestScreen({super.key});

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  final List<Event> _events = events_data.events;
  final List<Announcement> _announcements = announcements_data.announcements;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Welcome to Slug N Plug'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // About Us Section
          Card(
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About Us',
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Slug N Plug is a club for students interested in technology and software development. We organize events, workshops, and projects to help our members learn and grow.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Upcoming Events Section
          Text(
            'Upcoming Events',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _events.length,
              itemBuilder: (context, index) {
                return EventCard(event: _events[index]);
              },
            ),
          ),
          const SizedBox(height: 24),

          // Recent Announcements Section
          Text(
            'Recent Announcements',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ..._announcements.map((announcement) => AnnouncementCard(announcement: announcement)).toList(),

          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/register');
            },
            child: const Text('Become a member'),
          ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () {
              Navigator.of(context).pushNamed('/login');
            },
            child: const Text('Already a member? Login here'),
          ),
        ],
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final Event event;

  const EventCard({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 250,
      child: Card(
        elevation: 4,
        margin: const EdgeInsets.only(right: 16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                event.title,
                style: theme.textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    DateFormat.yMMMd().format(event.date),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                event.description,
                style: theme.textTheme.bodyMedium,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
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
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              announcement.title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              DateFormat.yMMMd().format(announcement.date),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(announcement.content, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}