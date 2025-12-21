import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:app/models/announcement.dart';
import 'package:app/models/event.dart';
import 'package:app/screens/announcements_screen.dart' as announcements_data;
import 'package:app/screens/events_screen.dart' as events_data;
import 'package:intl/intl.dart';
import 'package:app/services/role_database_service.dart';
import 'package:app/screens/event_details_screen.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/utils/pattern_generator.dart' as app_utils;
// Fix prefix overlap if any, or just import normally
import 'package:app/utils/pattern_generator.dart';

class GuestScreen extends StatefulWidget {
  const GuestScreen({super.key});

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> {
  final RoleBasedDatabaseService _databaseService = RoleBasedDatabaseService();
  List<Event> _events = [];
  bool _isLoadingEvents = true;
  
  // Form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _departmentController = TextEditingController();
  final _yearController = TextEditingController(); 
  final _sectionController = TextEditingController();
  final _registerNumberController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadPublicEvents();
  }

  Future<void> _loadPublicEvents() async {
    final data = await _databaseService.fetchEvents(publicOnly: true);
    if (mounted) {
      setState(() {
        _events = data.map((json) => Event.fromJson(json)).toList();
        _isLoadingEvents = false;
      });
    }
  }

  Future<void> _submitApplication() async {
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty ||
        _departmentController.text.isEmpty ||
        _registerNumberController.text.isEmpty ||
        _mobileNumberController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all required fields')));
       return;
    }

    setState(() => _isSubmitting = true);

    final success = await _databaseService.submitMembershipRequest({
      'name': _nameController.text,
      'email': _emailController.text,
      'department': _departmentController.text,
      'year': _yearController.text,
      'section': _sectionController.text,
      'registerNumber': _registerNumberController.text,
      'mobileNumber': _mobileNumberController.text,
      'reason': _reasonController.text,
    });

    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        _nameController.clear();
        _emailController.clear();
        _departmentController.clear();
        _yearController.clear();
        _sectionController.clear();
        _registerNumberController.clear();
        _mobileNumberController.clear();
        _reasonController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application sent successfully!'), backgroundColor: Colors.green),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send application. Try again.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerPattern = _events.isNotEmpty 
        ? 'seed${_events.first.title}' // Dynamic based on content
        : 'guest_dashboard_seed';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200.0,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text('Slug N Plug'),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Use a fixed seed for dashboard or random
                   SvgPicture.string(
                     PatternGenerator.generateRandomSvgPattern(headerPattern),
                     fit: BoxFit.cover,
                   ),
                   Container(
                     decoration: BoxDecoration(
                       gradient: LinearGradient(
                         begin: Alignment.topCenter,
                         end: Alignment.bottomCenter,
                         colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                       ),
                     ),
                   ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // About Us Card (Glassy)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                            Icon(Icons.info_outline, color: theme.colorScheme.primary), 
                            const SizedBox(width: 8),
                            Text('About Us', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))
                        ]),
                        const SizedBox(height: 8),
                        const Text(
                          'Slug N Plug is a club for students interested in technology and software development. We organize events, workshops, and projects to help our members learn and grow.',
                          style: TextStyle(height: 1.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Events Header
                  Text('Upcoming Events', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  
                  // Events List (Horizontal)
                  SizedBox(
                    height: 220,
                    child: _isLoadingEvents
                        ? const Center(child: CircularProgressIndicator())
                        : _events.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.event_busy, size: 48, color: Colors.grey.withOpacity(0.5)),
                                    const SizedBox(height: 8),
                                    const Text('No upcoming public events.'),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _events.length,
                                itemBuilder: (context, index) {
                                  final event = _events[index];
                                  return GestureDetector(
                                    onTap: () {
                                       Navigator.of(context).push(
                                         MaterialPageRoute(builder: (_) => EventDetailsScreen(event: event))
                                       );
                                    },
                                    child: EventCard(event: event),
                                  );
                                },
                              ),
                  ),
                  const SizedBox(height: 32),

                   // Membership Form (Collapsible/Glassy)
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
                       boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Become a Member', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                         const Text('Join our community to access exclusive events and projects.'),
                        const SizedBox(height: 24),

                         // Fields
                        _buildGlassTextField(_nameController, 'Full Name', Icons.person),
                        const SizedBox(height: 16),
                        _buildGlassTextField(_emailController, 'Email Address', Icons.email),
                        const SizedBox(height: 16),
                        Row(children: [
                           Expanded(child: _buildGlassTextField(_registerNumberController, 'Register No', Icons.numbers)),
                           const SizedBox(width: 12),
                           Expanded(child: _buildGlassTextField(_mobileNumberController, 'Mobile', Icons.phone)),
                        ]),
                        const SizedBox(height: 16),
                        _buildGlassTextField(_departmentController, 'Department', Icons.school),
                        const SizedBox(height: 16),
                        Row(children: [
                           Expanded(child: _buildGlassTextField(_yearController, 'Year', Icons.calendar_today)),
                           const SizedBox(width: 12),
                           Expanded(child: _buildGlassTextField(_sectionController, 'Section', Icons.class_)),
                        ]),
                        const SizedBox(height: 16),
                        _buildGlassTextField(_reasonController, 'Why join?', Icons.edit, maxLines: 3),
                        
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _submitApplication,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: theme.colorScheme.onPrimary,
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: _isSubmitting 
                                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                                : const Icon(Icons.send_rounded),
                            label: Text(_isSubmitting ? 'Sending...' : 'Submit Application', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  Center(
                    child: TextButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed('/login'),
                      icon: const Icon(Icons.login),
                      label: const Text('Member Login'),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
      return Container(
        constraints: BoxConstraints(minHeight: maxLines > 1 ? 100 : 60), // Enforce minimum height
        child: TextField(
          controller: controller,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 16), // Larger text
          decoration: InputDecoration(
            labelText: label,
            labelStyle: const TextStyle(fontSize: 15),
            prefixIcon: Icon(icon, size: 24, color: Theme.of(context).primaryColor), // Larger icon
            filled: true,
            fillColor: Colors.grey.withOpacity(0.05),
            isDense: false, // Ensure it's not too compact
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
               borderRadius: BorderRadius.circular(12),
               borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
               borderRadius: BorderRadius.circular(12),
               borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20), // Bigger padding
          ),
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
    // Use generated pattern for card bg with low opacity
    final cardPattern = PatternGenerator.generateRandomSvgPattern(event.id ?? event.title);

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 16),
      child: Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias, // Clip for Stack
        child: Stack(
          children: [
            // Background Pattern or Image
            Positioned.fill(
                child: (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                    ? Opacity(
                        opacity: 0.2, // Subtle background image
                        child: event.imageUrl!.startsWith('http')
                            ? Image.network(event.imageUrl!, fit: BoxFit.cover)
                            : Image.memory(base64Decode(event.imageUrl!), fit: BoxFit.cover),
                      )
                    : Opacity(
                        opacity: 0.1, 
                        child: SvgPicture.string(cardPattern, fit: BoxFit.cover)
                    ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   // Date Badge
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                     decoration: BoxDecoration(
                       color: theme.colorScheme.primaryContainer,
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: Text(
                       DateFormat.yMMMd().format(event.date),
                       style: TextStyle(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold, fontSize: 12),
                     ),
                   ),
                   const SizedBox(height: 12),
                   Text(
                     event.title,
                     style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                     maxLines: 2,
                     overflow: TextOverflow.ellipsis,
                   ),
                   const SizedBox(height: 8),
                   Row(children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Expanded(child: Text(event.venue, style: TextStyle(color: Colors.grey[600], fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
                   ]),
                   const Spacer(),
                   SizedBox(
                     width: double.infinity,
                     child: OutlinedButton(
                       onPressed: null, // Handled by GestureDetector parent
                       style: OutlinedButton.styleFrom(
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                       ),
                       child: const Text('View Details'),
                     ),
                   )
                ],
              ),
            ),
            
            // "Registration Open" Banner if applicable
            if (event.registrationStarted)
               Positioned(
                 top: 12,
                 right: 12,
                 child: Container(
                   padding: const EdgeInsets.all(6),
                   decoration: const BoxDecoration(
                     color: Colors.green,
                     shape: BoxShape.circle,
                   ),
                   child: const Icon(Icons.confirmation_number, color: Colors.white, size: 16),
                 ),
               ),
          ],
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