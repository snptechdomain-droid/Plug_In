import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:math';
import 'package:app/models/announcement.dart';
import 'package:app/models/event.dart';
import 'package:app/screens/event_details_screen.dart';
import 'package:app/services/role_database_service.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
// ignore: unused_import
import 'package:app/widgets/glass_container.dart'; 
import 'dart:ui';

class GuestScreen extends StatefulWidget {
  const GuestScreen({super.key});

  @override
  State<GuestScreen> createState() => _GuestScreenState();
}

class _GuestScreenState extends State<GuestScreen> with TickerProviderStateMixin {
  final RoleBasedDatabaseService _databaseService = RoleBasedDatabaseService();
  List<Event> _events = [];
  bool _isLoadingEvents = true;
  
  // Animation Controllers
  late AnimationController _bgController;

  // Form controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _departmentController = TextEditingController();
  final _yearController = TextEditingController(); 
  final _sectionController = TextEditingController();
  final _registerNumberController = TextEditingController();
  final _mobileNumberController = TextEditingController();
  final _reasonController = TextEditingController();
  List<String> _selectedDomains = []; 
  bool _isSubmitting = false;

  // Randomness
  late Color _randomPrimary;
  late Color _randomSecondary;
  late String _randomQuote;

  final List<String> _quotes = [
    "Software is eating the world.",
    "Talk is cheap. Show me the code.",
    "Stay hungry, stay foolish.",
    "It’s not a bug, it’s a feature.",
    "Code is poetry.",
    "Simplicity is the soul of efficiency.",
    "Make it work, make it right, make it fast.",
    "First, solve the problem. Then, write the code.",
    "Of it works it works, doesn't matter how it works.",
    "See you on the other side"
  ];

  @override
  void initState() {
    super.initState();
    _generateRandomTheme();
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 10))..repeat(reverse: true);
    _loadPublicEvents();
  }

  @override
  void dispose() {
    _bgController.dispose();
    super.dispose();
  }

  void _generateRandomTheme() {
    final random = Random();
    final colors = [
      Colors.blueAccent, Colors.purpleAccent, Colors.orangeAccent, 
      Colors.greenAccent, Colors.pinkAccent, Colors.cyanAccent,
      Colors.tealAccent, Colors.indigoAccent
    ];
    _randomPrimary = colors[random.nextInt(colors.length)];
    _randomSecondary = colors[random.nextInt(colors.length)];
    _randomQuote = _quotes[random.nextInt(_quotes.length)];
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
  
  void _showDomainDialog() async {
      final domains = ['management', 'tech', 'webdev', 'content', 'design', 'marketing'];
      await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                backgroundColor: Colors.grey[900], // Dark theme default for contrast
                title: const Text('Select Domains', style: TextStyle(color: Colors.white)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: domains.map((domain) {
                      final isSelected = _selectedDomains.contains(domain);
                      return CheckboxListTile(
                        title: Text(domain.toUpperCase(), style: const TextStyle(color: Colors.white70)),
                        value: isSelected,
                        activeColor: _randomPrimary,
                        checkColor: Colors.black,
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              if (!_selectedDomains.contains(domain)) _selectedDomains.add(domain);
                            } else {
                              _selectedDomains.remove(domain);
                            }
                          });
                          this.setState(() {}); 
                        },
                      );
                    }).toList(),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Done', style: TextStyle(color: _randomPrimary)),
                  ),
                ],
              );
            }
          );
        },
      );
    }

  Future<void> _submitApplication() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all basic details!')));
       return;
    }
    setState(() => _isSubmitting = true);
    final success = await _databaseService.submitMembershipRequest({
      'name': _nameController.text, 'email': _emailController.text,
      'department': _departmentController.text, 'year': _yearController.text,
      'section': _sectionController.text, 'registerNumber': _registerNumberController.text,
      'mobileNumber': _mobileNumberController.text, 'reason': _reasonController.text,
      'domains': _selectedDomains,
    });
    if (mounted) {
      setState(() => _isSubmitting = false);
      if (success) {
        _nameController.clear(); _emailController.clear(); _reasonController.clear();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Welcome to the club! Request Sent 🚀'), backgroundColor: _randomPrimary));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed. Try again.'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Dark Base
      body: Stack(
        children: [
          // 1. Dynamic Animated Background
          _buildAnimatedBackground(),
          
          // 2. Glass Overlay
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),

          // 3. Scrollable Content
          SafeArea(
            child: AnimationLimiter(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: AnimationConfiguration.toStaggeredList(
                    duration: const Duration(milliseconds: 600),
                    childAnimationBuilder: (widget) => SlideAnimation(
                      verticalOffset: 50.0,
                      child: FadeInAnimation(child: widget),
                    ),
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Slug N Plug.', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -1)),
                              Text('Innovate. Build. Lead.', style: TextStyle(color: Colors.white70, fontSize: 14, letterSpacing: 1)),
                            ],
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pushNamed('/login'),
                            icon: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.login, color: Colors.white),
                            ),
                          )
                        ],
                      ),
                      
                      const SizedBox(height: 30),

                      // Quote Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [_randomPrimary.withOpacity(0.8), _randomSecondary.withOpacity(0.8)]),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [BoxShadow(color: _randomPrimary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10))],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                             const Icon(Icons.format_quote, color: Colors.white, size: 30),
                             Text(_randomQuote, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600, height: 1.4)),
                             const SizedBox(height: 10),
                             const Text('- Random Tech Wisdom', style: TextStyle(color: Colors.white70, fontSize: 12)),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                      Text('Upcoming Events', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      // Events List
                      SizedBox(
                        height: 240,
                        child: _isLoadingEvents 
                          ? Center(child: CircularProgressIndicator(color: _randomPrimary))
                          : _events.isEmpty 
                              ? _buildEmptyState()
                              : ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: _events.length,
                                  physics: const BouncingScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    return GestureDetector(
                                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EventDetailsScreen(event: _events[index]))),
                                        child: _buildEventCard(_events[index]),
                                    );
                                  },
                                ),
                      ),
                      
                      const SizedBox(height: 40),
                      Text('Join The Community', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      
                      // Membership Form
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Column(
                          children: [
                             _buildFancyTextField(_nameController, 'Full Name', Icons.person),
                             const SizedBox(height: 16),
                             _buildFancyTextField(_emailController, 'Email Address', Icons.email),
                             const SizedBox(height: 16),
                             Row(children: [
                               Expanded(child: _buildFancyTextField(_registerNumberController, 'Reg No', Icons.numbers)),
                               const SizedBox(width: 12),
                               Expanded(child: _buildFancyTextField(_mobileNumberController, 'Mobile', Icons.phone)),
                             ]),
                             const SizedBox(height: 16),
                             Row(children: [
                               Expanded(child: _buildFancyTextField(_departmentController, 'Dept', Icons.school)),
                               const SizedBox(width: 12),
                               Expanded(child: _buildFancyTextField(_yearController, 'Year', Icons.calendar_today)),
                             ]),
                             const SizedBox(height: 16),
                             
                             // Domain Selector
                             GestureDetector(
                               onTap: _showDomainDialog,
                               child: Container(
                                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                 decoration: BoxDecoration(
                                   color: Colors.grey.withOpacity(0.1),
                                   borderRadius: BorderRadius.circular(16),
                                   border: Border.all(color: Colors.white.withOpacity(0.1)),
                                 ),
                                 child: Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     Text(
                                       _selectedDomains.isEmpty ? 'Select Interested Domains' : _selectedDomains.map((e) => e.toUpperCase()).join(', '),
                                       style: TextStyle(color: _selectedDomains.isEmpty ? Colors.white54 : Colors.white, fontWeight: FontWeight.bold),
                                       overflow: TextOverflow.ellipsis,
                                     ),
                                     Icon(Icons.arrow_drop_down, color: _randomPrimary),
                                   ],
                                 ),
                               ),
                             ),
                             
                             const SizedBox(height: 24),
                             SizedBox(
                               width: double.infinity,
                               height: 56,
                               child: ElevatedButton(
                                 onPressed: _isSubmitting ? null : _submitApplication,
                                 style: ElevatedButton.styleFrom(
                                   backgroundColor: _randomPrimary,
                                   foregroundColor: Colors.black,
                                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                   elevation: 8,
                                   shadowColor: _randomPrimary.withOpacity(0.5),
                                 ),
                                 child: _isSubmitting 
                                    ? const CircularProgressIndicator(color: Colors.black)
                                    : const Text('SUBMIT APPLICATION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                               ),
                             ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),
                      Center(child: Text('© 2025 Slug N Plug', style: TextStyle(color: Colors.white30))),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widgets
  Widget _buildEmptyState() {
     return Container(
       width: double.infinity,
       decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(20)),
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           Icon(Icons.rocket_launch, size: 48, color: Colors.white24),
           SizedBox(height: 8),
           Text('No Events Yet', style: TextStyle(color: Colors.white54)),
         ],
       ),
     );
  }

  Widget _buildEventCard(Event event) {
    return Container(
      width: 260,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Stack(
        children: [
          // Image
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Opacity(
              opacity: 0.6,
              child: (event.imageUrl != null && event.imageUrl!.isNotEmpty)
                 ? Image.network(event.imageUrl!, width: double.infinity, height: double.infinity, fit: BoxFit.cover, 
                     errorBuilder: (c,e,s) => Container(color: Colors.grey[800]))
                 : Container(color: Colors.grey[800]),
            ),
          ),
          // Gradient Overlay
          Container(
             decoration: BoxDecoration(
               borderRadius: BorderRadius.circular(24),
               gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Colors.black]),
             ),
          ),
          // Content
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _randomPrimary, borderRadius: BorderRadius.circular(8)),
                  child: Text(DateFormat.MMMd().format(event.date), style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const SizedBox(height: 8),
                Text(event.title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text(event.venue, style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFancyTextField(TextEditingController ctrl, String hint, IconData icon) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextField(
        controller: ctrl,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white30),
          prefixIcon: Icon(icon, color: _randomSecondary),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildAnimatedBackground() {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, child) {
        return Stack(
          children: [
            // Blob 1
            Positioned(
              top: -100 + (_bgController.value * 50),
              left: -50 + (_bgController.value * 30),
              child: Container(
                width: 300, height: 300,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _randomPrimary.withOpacity(0.4)),
              ),
            ),
             // Blob 2
            Positioned(
              bottom: -50 - (_bgController.value * 50),
              right: -50 - (_bgController.value * 30),
              child: Container(
                width: 350, height: 350,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _randomSecondary.withOpacity(0.4)),
              ),
            ),
          ],
        );
      },
    );
  }
}