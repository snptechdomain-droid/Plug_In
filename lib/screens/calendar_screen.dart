import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:app/models/event.dart';
import 'package:app/models/schedule_entry.dart';
import 'package:app/models/role.dart';
import 'package:app/services/calendar_service.dart';
import 'package:app/services/role_database_service.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late final ValueNotifier<List<dynamic>> _selectedEvents;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  
  final CalendarService _service = CalendarService();
  final RoleBasedDatabaseService _roleService = RoleBasedDatabaseService();
  
  // Cache of all items loaded from API
  List<dynamic> _allItems = [];
  bool _isAdmin = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _selectedEvents = ValueNotifier(_getEventsForDay(_selectedDay!));
    _checkRole();
    _loadData();
  }

  Future<void> _checkRole() async {
    final user = await _roleService.getCurrentUser();
    setState(() {
      _isAdmin = user?.role == UserRole.admin || user?.role == UserRole.moderator;
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final items = await _service.fetchAllCalendarItems();
    setState(() {
      _allItems = items;
      _isLoading = false;
      _selectedEvents.value = _getEventsForDay(_selectedDay!);
    });
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    return _allItems.where((item) {
      final date = item is Event ? item.date : (item as ScheduleEntry).date;
      return isSameDay(date, day);
    }).toList();
  }

  Color _getItemColor(dynamic item) {
    if (item is Event) {
      if (item.venue.toLowerCase().contains('online') || 
          item.venue.toLowerCase().contains('meet') || 
          item.venue.toLowerCase().contains('zoom')) {
        return Colors.green; // Online Meet
      }
      return Colors.red; // Offline Event
    } else if (item is ScheduleEntry) {
      if (item.type.toLowerCase().contains('online')) return Colors.green;
      if (item.type.toLowerCase().contains('offline') || item.type.toLowerCase() == 'event') return Colors.red;
      if (item.type.toLowerCase() == 'exam') return Colors.orange;
      if (item.type.toLowerCase() == 'holiday') return Colors.purple;
      return Colors.blue;
    }
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar & TimeTable'),
        centerTitle: true,
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : Column(
            children: [
              TableCalendar(
                firstDay: DateTime.utc(2023, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                calendarFormat: _calendarFormat,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                eventLoader: _getEventsForDay,
                startingDayOfWeek: StartingDayOfWeek.monday,
                calendarStyle: CalendarStyle(
                  markerDecoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                  todayDecoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.5), shape: BoxShape.circle),
                  selectedDecoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                    _selectedEvents.value = _getEventsForDay(selectedDay);
                  });
                },
                onFormatChanged: (format) {
                  if (_calendarFormat != format) setState(() => _calendarFormat = format);
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
              ),
              const SizedBox(height: 8.0),
              Expanded(
                child: ValueListenableBuilder<List<dynamic>>(
                  valueListenable: _selectedEvents,
                  builder: (context, items, _) {
                    if (items.isEmpty) {
                      return const Center(child: Text('No events or classes for this day.'));
                    }
                    return ListView.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isEvent = item is Event;
                        final title = isEvent ? item.title : (item as ScheduleEntry).title;
                        final subtitle = isEvent ? item.venue : (item as ScheduleEntry).type;
                        final date = isEvent ? item.date : (item as ScheduleEntry).date;
                        final color = _getItemColor(item);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          color: Theme.of(context).cardColor,
                          child: ListTile(
                            leading: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                            ),
                            title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('$subtitle • ${DateFormat('jm').format(date)}'),
                            trailing: _isAdmin && !isEvent 
                                ? IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _deleteEntry(item as ScheduleEntry),
                                  )
                                : null,
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
      floatingActionButton: _isAdmin
          ? FloatingActionButton(
              onPressed: () => _showAddDialog(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
  
  void _deleteEntry(ScheduleEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: const Text('Are you sure you want to remove this?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      )
    );
    
    if (confirm == true) {
      await _service.deleteScheduleEntry(entry.id);
      _loadData();
    }
  }

  void _showAddDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final venueCtrl = TextEditingController();
    String type = 'Event';
    DateTime selectedTime = _selectedDay ?? DateTime.now(); // Start with currently selected day
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Add Schedule Entry'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: titleCtrl, decoration: const InputDecoration(labelText: 'Title')),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: 'Description')),
                  if (type.contains('Meet') || type == 'Event')
                    TextField(controller: venueCtrl, decoration: const InputDecoration(labelText: 'Venue (for Announcement)')),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                    value: type,
                    isExpanded: true,
                    items: ['Event', 'Meet (Online)', 'Meet (Offline)', 'Holiday', 'Exam']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                    onChanged: (v) => setDialogState(() => type = v!),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    title: Text('Date: ${DateFormat('MMM d, y').format(selectedTime)}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(
                        context: context,
                        initialDate: selectedTime,
                        firstDate: DateTime(2023),
                        lastDate: DateTime(2030),
                      );
                      if (d != null) {
                        setDialogState(() {
                          selectedTime = DateTime(
                            d.year, d.month, d.day,
                            selectedTime.hour, selectedTime.minute
                          );
                        });
                      }
                    },
                  ),
                  ListTile(
                    title: Text('Time: ${DateFormat('jm').format(selectedTime)}'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedTime));
                      if (t != null) {
                        setDialogState(() {
                          selectedTime = DateTime(
                            selectedTime.year, selectedTime.month, selectedTime.day, 
                            t.hour, t.minute
                          );
                        });
                      }
                    },
                  )
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleCtrl.text.isEmpty) return;
                  final entry = ScheduleEntry(
                    id: '',
                    title: titleCtrl.text, 
                    description: descCtrl.text, 
                    date: selectedTime, 
                    type: type,
                    venue: venueCtrl.text,
                    createdBy: (await _roleService.getCurrentUser())?.username ?? 'Admin'
                  );
                  await _service.createScheduleEntry(entry);
                  Navigator.pop(context);
                  _loadData();
                },
                child: const Text('Add'),
              ),
            ],
          );
        }
      )
    );
  }
}
