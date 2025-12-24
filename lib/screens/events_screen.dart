import 'package:flutter/material.dart';
import 'package:app/models/event.dart';
import 'package:app/services/role_database_service.dart';
import 'package:app/models/role.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:app/screens/registrations_screen.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final RoleBasedDatabaseService _databaseService = RoleBasedDatabaseService();
  List<Event> _events = [];
  bool _isLoading = true;
  bool _canEdit = false; // Admin or Moderator
  List<UserLoginDetails> _members = [];
  bool _loadingMembers = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _loadEvents();
    _loadMembers();
  }

  Future<void> _checkPermissions() async {
    final user = await _databaseService.getCurrentUser();
    if (mounted) {
      setState(() {
        _canEdit = user?.role == UserRole.admin || user?.role == UserRole.moderator;
      });
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    final data = await _databaseService.fetchEvents(publicOnly: false);
    if (mounted) {
      setState(() {
        _events = data.map((json) => Event.fromJson(json)).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMembers() async {
    setState(() => _loadingMembers = true);
    final members = await _databaseService.fetchMembers();
    if (mounted) {
      setState(() {
        _members = members;
        _loadingMembers = false;
      });
    }
  }

  Future<void> _showEventDialog({Event? event}) async {
    if (_members.isEmpty && !_loadingMembers) {
      _loadMembers();
    }
    final isEditing = event != null;
    final titleController = TextEditingController(text: event?.title ?? '');
    final descriptionController = TextEditingController(text: event?.description ?? '');
    final venueController = TextEditingController(text: event?.venue ?? '');
    // final imageUrlController = TextEditingController(text: event?.imageUrl ?? ''); // Removed API text field
    
    DateTime selectedDate = event?.date ?? DateTime.now();
    bool isPublic = event?.isPublic ?? true;
    bool registrationStarted = event?.registrationStarted ?? false;
    String? selectedCoordinator = event?.eventCoordinator;
    
    String? currentImageUrl = event?.imageUrl;
    Uint8List? newImageBytes;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(isEditing ? 'Edit Event' : 'Add New Event'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Preview / Picker
                GestureDetector(
                  onTap: () async {
                    final ImagePicker picker = ImagePicker();
                    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50); // Quality 50 to save space
                    if (image != null) {
                       final bytes = await image.readAsBytes();
                       setState(() {
                         newImageBytes = bytes;
                       });
                    }
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[400]!),
                      image: newImageBytes != null 
                          ? DecorationImage(image: MemoryImage(newImageBytes!), fit: BoxFit.cover)
                          : (currentImageUrl != null && currentImageUrl!.isNotEmpty)
                              ? DecorationImage(
                                  image: currentImageUrl!.startsWith('http') 
                                      ? NetworkImage(currentImageUrl!) 
                                      : MemoryImage(base64Decode(currentImageUrl!)) as ImageProvider,
                                  fit: BoxFit.cover
                                )
                              : null
                    ),
                    child: (newImageBytes == null && (currentImageUrl == null || currentImageUrl!.isEmpty))
                        ? const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                              SizedBox(height: 8),
                              Text('Tap to upload banner', style: TextStyle(color: Colors.grey)),
                            ],
                          )
                        : null,
                  ),
                ),
                if (newImageBytes != null || (currentImageUrl != null && currentImageUrl!.isNotEmpty))
                    TextButton.icon(
                        onPressed: () {
                            setState(() {
                                newImageBytes = null;
                                currentImageUrl = null;
                            });
                        }, 
                        icon: const Icon(Icons.delete, color: Colors.red, size: 16),
                        label: const Text('Remove Image', style: TextStyle(color: Colors.red))
                    ),
                
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                TextField(
                  controller: venueController,
                  decoration: const InputDecoration(labelText: 'Venue'),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Event Coordinator',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedCoordinator,
                  isExpanded: true,
                  hint: const Text('Select coordinator'),
                  items: (_members.isEmpty
                          ? <UserLoginDetails>[]
                          : _members)
                      .map((user) => DropdownMenuItem(
                            value: user.email,
                            child: Text(user.username),
                          ))
                      .toList(),
                  onChanged: (value) => setState(() {
                    selectedCoordinator = value;
                  }),
                ),
                if (_loadingMembers)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: LinearProgressIndicator(minHeight: 2),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Date: ${DateFormat.yMd().format(selectedDate)}'),
                    TextButton(
                      child: const Text('Select Date'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2101),
                        );
                        if (picked != null) {
                          setState(() => selectedDate = picked);
                        }
                      },
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Public Event'),
                  subtitle: const Text('Visible to guests?'),
                  value: isPublic,
                  onChanged: (val) => setState(() => isPublic = val),
                ),
                SwitchListTile(
                  title: const Text('Enable Registration'),
                  subtitle: const Text('Show "Register" button to guests?'),
                  value: registrationStarted,
                  onChanged: (val) => setState(() => registrationStarted = val),
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
              onPressed: () async {
                final String? finalBase64Image = newImageBytes != null 
                    ? base64Encode(newImageBytes!) 
                    : currentImageUrl;

                final newEventData = Event(
                  id: event?.id,
                  title: titleController.text,
                  description: descriptionController.text,
                  venue: venueController.text,
                  date: selectedDate,
                  isPublic: isPublic,
                  imageUrl: finalBase64Image,
                  eventCoordinator: selectedCoordinator,
                  registrationStarted: registrationStarted,
                  createdBy: (await _databaseService.getCurrentUser())?.username ?? 'Admin',
                ).toJson();
                
                if (isEditing) {
                   await _databaseService.updateEvent(event!.id!, newEventData);
                } else {
                   await _databaseService.createEvent(newEventData);
                }

                if (context.mounted) Navigator.pop(context);
                if (mounted) _loadEvents();
              },
              child: Text(isEditing ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Events'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _events.isEmpty
              ? const Center(child: Text('No events scheduled.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    return _EventCard(
                      event: _events[index], 
                      canEdit: _canEdit, 
                      onEdit: () => _showEventDialog(event: _events[index]),
                      onDelete: () async {
                         await _databaseService.deleteEvent(_events[index].id!);
                         _loadEvents();
                      }
                    );
                  },
                ),
      floatingActionButton: _canEdit
          ? FloatingActionButton(
              onPressed: () => _showEventDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

class _EventCard extends StatelessWidget {
  final Event event;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event, 
    required this.canEdit, 
    required this.onEdit,
    required this.onDelete
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: theme.textTheme.titleLarge,
                  ),
                ),
                if (!event.isPublic)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('INTERNAL ONLY', style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                if (canEdit)
                   Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       IconButton(
                         icon: const Icon(Icons.edit, color: Colors.blue), 
                         onPressed: onEdit
                       ),
                       IconButton(
                         icon: const Icon(Icons.delete, color: Colors.red), 
                         onPressed: onDelete
                       ),
                     ],
                   ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  DateFormat.yMMMd().format(event.date),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(width: 16),
                Icon(Icons.location_on, size: 16, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  event.venue,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(event.description, style: theme.textTheme.bodyLarge),
            
            // View Registrations Button (Admin Only)
            if (canEdit && event.registrationStarted)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: SizedBox(
                   width: double.infinity,
                   child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => RegistrationsScreen(event: event))
                      );
                    }, 
                    icon: const Icon(Icons.people),
                    label: Text('View Registrations (${event.registrations.length})'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
