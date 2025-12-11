import 'package:app/screens/announcements_screen.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart'; 
import 'package:flutter_svg/flutter_svg.dart';
import 'package:app/screens/settings_screen.dart';
import 'package:app/services/role_database_service.dart';
import 'dart:ui' show lerpDouble; // For smooth animation interpolation
import 'dart:math' as math; // For math operations in custom painter
import 'package:app/services/theme_service.dart';
import 'package:app/widgets/glass_container.dart'; // Import GlassContainer
import 'dart:convert'; // For base64Decode
import 'package:lottie/lottie.dart'; // Import Lottie

// --- Assuming these screen imports exist in your project ---
import 'package:app/models/role.dart';
import 'package:app/screens/membership_requests_screen.dart';

// --- Assuming these screen imports exist in your project ---
import 'attendance_screen.dart'; 
import 'events_screen.dart'; 
import 'members_screen.dart'; 
import 'collaboration_screen.dart';
// ---------------------------------------------------------


// A type-safe data class for our dashboard items
class _DashboardItem {
  final String title;
  final String? lottieAsset; // Path to local Lottie JSON
  final Widget? icon; // Fallback or static icon
  final Widget drawerIcon;
  final String subtitle;
  final Widget destination;
  final Color color;

  _DashboardItem({
    required this.title,
    this.lottieAsset,
    this.icon,
    required this.drawerIcon,
    required this.subtitle,
    required this.destination,
    required this.color,
  });
}

// Class to represent a single "flying bit"
class _TechBit {
  final String text;
  final Offset initialPosition; // Relative position (0.0 to 1.0)
  final double speed; // Speed multiplier
  final Color color;
  final double fontSize;

  _TechBit({
    required this.text,
    required this.initialPosition,
    required this.speed,
    required this.color,
    required this.fontSize,
  });
}

// Converted to a StatefulWidget to manage animation state
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with TickerProviderStateMixin {
  bool _showContent = false;
  String _currentUsername = 'User';
  String? _currentUserAvatar;
  bool _isAdmin = false;
  int _unreadAnnouncements = 0;
  
  // Animation controller for the tech background
  late AnimationController _techAnimationController;

  // Stores the mouse position
  Offset _mousePosition = Offset.zero;

  // List to hold all the flying bits
  final List<_TechBit> _techBits = [];

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadUnreadAnnouncements();

    _techAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10), 
    )..repeat(); 

    _populateTechBits();

    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _showContent = true;
        });
      }
    });
  }

  Future<void> _loadCurrentUser() async {
    final roleDatabase = RoleBasedDatabaseService();
    final user = await roleDatabase.getCurrentUser();
    if (user != null) {
      if (mounted) {
        setState(() {
          _currentUsername = user.username;
          _currentUserAvatar = user.avatarUrl;
          _isAdmin = user.role == UserRole.admin; // Check role
        });
      }
    }
  }

  Future<void> _loadUnreadAnnouncements() async {
    final roleDatabase = RoleBasedDatabaseService();
    final user = await roleDatabase.getCurrentUser();
    if (user != null) {
      final count = await roleDatabase.getUnreadAnnouncementCount(user.email);
       if (mounted) {
        setState(() {
          _unreadAnnouncements = count;
        });
      }
    }
  }

  // ✨ --- NEW: Helper method to create multi-colored bits --- ✨
  void _populateTechBits() {
    final random = math.Random();
    
    // --- Define our code snippet palettes ---
    const List<String> normalCodes = [
      'import pandas as pd', 'df.head()', 'model.fit(X, y)', 'import numpy as np',
      'plt.show()', 'System.out.println(...)'
    ];
    const List<String> specialCodes = [
      'from sklearn.model_selection import train_test_split', 'tf.keras.models.Sequential()', 'import weka.core.Instances;',
      'LinearRegression model = new LinearRegression();', 'model.buildClassifier(data);', 'new NeuralNetConfiguration.Builder()'
    ];
    const List<String> errorCodes = [
      'Error 404', 'NULL_PTR', 'FATAL', 'Access Denied', 'Segfault', 'ERR: 500'
    ];

    const Color normalColor = Colors.white70;
    const Color specialColor = Color(0xFFFFD700); // Gold
    const Color errorColor = Color(0xFFFF5252); // Red Accent

    for (int i = 0; i < (kIsWeb ? 8 : 25); i++) { // Reduced to 8 on Web for performance
      final String text;
      final Color color;
      final double roll = random.nextDouble();

      if (roll < 0.1) { // 10% chance for an error code
        text = errorCodes[random.nextInt(errorCodes.length)];
        color = errorColor.withOpacity(random.nextDouble() * 0.5 + 0.5); // Brighter
      } else if (roll < 0.3) { // 20% chance for a special code
        text = specialCodes[random.nextInt(specialCodes.length)];
        color = specialColor.withOpacity(random.nextDouble() * 0.4 + 0.4);
      } else { // 70% chance for a normal code
        text = normalCodes[random.nextInt(normalCodes.length)];
        color = normalColor.withOpacity(random.nextDouble() * 0.3 + 0.3);
      }
      
      _techBits.add(
        _TechBit(
          text: text,
          initialPosition: Offset(random.nextDouble(), random.nextDouble()), 
          speed: random.nextDouble() * 1.5 + 0.5, // Increased speed
          color: color,
          fontSize: random.nextDouble() * 6 + 8,
        ),
      );
    }
  }
  
  @override
  void dispose() {
    _techAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
        valueListenable: themeService,
        builder: (context, themeMode, child) {
    final theme = Theme.of(context);
    final isDarkMode = themeMode == ThemeMode.dark;

    final primaryColor = theme.colorScheme.primary;
    final appBarTextColor = theme.colorScheme.onSurface;

  final List<_DashboardItem> dashboardItems = [
    _DashboardItem(
      title: 'Attendance',
      lottieAsset: 'assets/lottie/attendance.json',
      icon: Icon(Icons.co_present, size: 40, color: Colors.white),
      drawerIcon: Icon(Icons.co_present, size: 30, color: isDarkMode ? Colors.white : Colors.black87),
      subtitle: 'View & mark attendance logs',
      destination: const AttendanceScreen(),
      color: const Color(0xFF0077B6), // Strong Blue
    ),
    _DashboardItem(
      title: 'Events',
      lottieAsset: 'assets/lottie/events.json',
      icon: Icon(Icons.event, size: 40, color: Colors.white),
      drawerIcon: Icon(Icons.event, size: 30, color: isDarkMode ? Colors.white : Colors.black87),
      subtitle: 'Manage and view club events',
      destination: const EventsScreen(),
      color: const Color(0xFFF25C54), // Coral Red
    ),
    _DashboardItem(
      title: 'Collaboration',
      lottieAsset: 'assets/lottie/collaboration.json',
      icon: Icon(Icons.handshake, size: 40, color: Colors.white),
      drawerIcon: Icon(Icons.handshake, size: 30, color: isDarkMode ? Colors.white : Colors.black87),
      subtitle: 'Access mindmaps and timelines',
      destination: const CollaborationScreen(),
      color: const Color(0xFF6A4C93), // Royal Purple
    ),
    _DashboardItem(
      title: 'Announcements',
      lottieAsset: 'assets/lottie/announcements.json',
      icon: _unreadAnnouncements > 0
          ? Badge(
              label: Text('$_unreadAnnouncements'),
              child: const Icon(Icons.campaign, size: 40, color: Colors.black87),
            )
          : const Icon(Icons.campaign, size: 40, color: Colors.black87),
      drawerIcon: _unreadAnnouncements > 0
          ? Badge(
              label: Text('$_unreadAnnouncements'),
              child: Icon(Icons.campaign, size: 30, color: isDarkMode ? Colors.white : Colors.black87),
            )
          : Icon(Icons.campaign, size: 30, color: isDarkMode ? Colors.white : Colors.black87),
      subtitle: 'Read the latest club news',
      destination: const AnnouncementsScreen(),
      color: const Color(0xFF06D6A0), // Bright Mint
    ),
    _DashboardItem(
      title: 'Members',
      lottieAsset: 'assets/lottie/members.json',
      icon: Icon(Icons.people, size: 40, color: Colors.black87),
      drawerIcon: Icon(Icons.people, size: 30, color: isDarkMode ? Colors.white : Colors.black87),
      subtitle: 'Directory of all club members',
      destination: const MembersScreen(),
      color: const Color(0xFFFFB703), // Vibrant Gold
    ),
    if (_isAdmin)
      _DashboardItem(
        title: 'Join Requests',
        lottieAsset: 'assets/lottie/join_requests.json',
        icon: Icon(Icons.person_add, size: 40, color: Colors.white),
        drawerIcon: Icon(Icons.person_add, size: 30, color: isDarkMode ? Colors.white : Colors.black87),
        subtitle: 'Approve new members',
        destination: const MembershipRequestsScreen(),
        color: Colors.teal, 
      ),
    _DashboardItem(
      title: 'Settings',
      lottieAsset: 'assets/lottie/settings.json',
      icon: Icon(Icons.settings, size: 40, color: Colors.white),
      drawerIcon: Icon(Icons.settings, size: 30, color: isDarkMode ? Colors.white : Colors.black87),
      subtitle: 'App and profile settings',
      destination: const SettingsScreen(),
      color: const Color(0xFF495057), // Slate Grey
    ),
  ];

    return Scaffold(
      drawer: Drawer(
        backgroundColor: theme.scaffoldBackgroundColor,
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            _buildDrawerHeader(context, theme, primaryColor, appBarTextColor, isDarkMode),
            ListTile(
              leading: Icon(Icons.home, color: isDarkMode ? Colors.white : Colors.black87),
              title: const Text('Home'),
              onTap: () {
                Navigator.of(context).pop();
                if (ModalRoute.of(context)?.settings.name != '/dashboard') {
                   Navigator.of(context).pushReplacement(MaterialPageRoute(
                     builder: (_) => const DashboardScreen(),
                     settings: const RouteSettings(name: '/dashboard')
                   ));
                }
              },
            ),
            const Divider(),
            ...dashboardItems.map((item) {
              return ListTile(
                leading: SizedBox(width: 30, height: 30, child: item.drawerIcon),
                title: Text(item.title),
                onTap: () async {
                  Navigator.of(context).pop();
                  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => item.destination));
                  if (item.title == 'Announcements') {
                    _loadUnreadAnnouncements();
                  }
                },
              );
            }).toList(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout'),
              onTap: () {
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              },
            ),
          ],
        ),
      ),
      body: AnimationLimiter(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverAppBar(
              expandedHeight: 160.0, // Retained smaller header
              floating: true,
              pinned: true,
              foregroundColor: appBarTextColor, 
              backgroundColor: theme.scaffoldBackgroundColor, 
              
              title: Text(
                'Dashboard',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: appBarTextColor,
                ),
              ), 

              flexibleSpace: FlexibleSpaceBar(
                title: null,
                centerTitle: false,
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    // --- Technical Grid Background ---
                    Container(
                      color: theme.scaffoldBackgroundColor,
                    ),
                    
                    // --- Mouse Reactive Wrapper ---
                    MouseRegion(
                      onHover: (event) {
                        setState(() {
                          _mousePosition = event.localPosition;
                        });
                      },
                      onExit: (event) {
                        setState(() {
                          _mousePosition = Offset.zero;
                        });
                      },
                      child: AnimatedBuilder(
                        animation: _techAnimationController,
                        builder: (context, child) {
                          return CustomPaint(
                            painter: TechGridPainter(
                              animationValue: _techAnimationController.value,
                              lineColor: theme.colorScheme.primary.withOpacity(0.1),
                              squareColor: theme.colorScheme.secondary.withOpacity(0.05),
                              mousePosition: _mousePosition,
                              techBits: _techBits,
                            ),
                            child: child,
                          );
                        },
                      ),
                    ),

                    // ✨ --- NEW: "PROPERLY POSITIONED" CONTENT --- ✨
                    LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        final double maxExtent = 160.0; 
                        final double minExtent = kToolbarHeight + (View.of(context).padding.top);
                        
                        final double t = (constraints.maxHeight - minExtent) / (maxExtent - minExtent);
                        final double tClamped = t.clamp(0.0, 1.0);

                        // Animate opacity, scale, and position of the WHOLE block
                        final double contentOpacity = tClamped;
                        final double contentScale = lerpDouble(0.8, 1.0, tClamped)!;
                        final double contentYOffset = lerpDouble(20.0, 0.0, tClamped)!;

                        return Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned(
                              bottom: 16.0,
                              left: 20.0,
                              right: 20.0,
                              child: AnimatedOpacity(
                                duration: Duration.zero, 
                                opacity: contentOpacity,
                                // This block now animates as one unit
                                child: Transform.translate(
                                  offset: Offset(0, contentYOffset),
                                  child: Transform.scale(
                                    scale: contentScale,
                                    alignment: Alignment.bottomLeft,
                                    child: Row(
                                      children: [
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: theme.colorScheme.primary.withOpacity(0.3),
                                                blurRadius: 10,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: CircleAvatar(
                                            radius: 25,
                                            backgroundColor: theme.colorScheme.primary,
                                            backgroundImage: (_currentUserAvatar != null && _currentUserAvatar!.isNotEmpty)
                                                ? (_currentUserAvatar!.startsWith('http')
                                                    ? NetworkImage(_currentUserAvatar!)
                                                    : (() {
                                                        try {
                                                          return MemoryImage(base64Decode(_currentUserAvatar!.contains(',') ? _currentUserAvatar!.split(',').last : _currentUserAvatar!));
                                                        } catch (e) {
                                                          print('Error decoding avatar: $e');
                                                          return null;
                                                        }
                                                      })() as ImageProvider?)
                                                : null,
                                            child: (_currentUserAvatar == null || _currentUserAvatar!.isEmpty)
                                                ? Text(
                                                    _currentUsername.isNotEmpty ? _currentUsername.substring(0, 1).toUpperCase() : 'U',
                                                    style: theme.textTheme.headlineSmall?.copyWith(
                                                      color: theme.colorScheme.onPrimary, 
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Flexible(
                                          child: Column(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text('Welcome back,', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
                                              Text(
                                                _currentUsername,
                                                style: theme.textTheme.headlineSmall?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                  color: appBarTextColor,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.logout, color: appBarTextColor), 
                  tooltip: 'Logout',
                  onPressed: () {
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  },
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.all(16.0),
              sliver: SliverAnimatedOpacity(
                duration: const Duration(milliseconds: 500),
                opacity: _showContent ? 1.0 : 0.0,
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 350, // Fluidly adapts columns
                    mainAxisExtent: 200, // Fixed height for consistency
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    // childAspectRatio is removed in favor of mainAxisExtent for precise control
                  ),
  
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final item = dashboardItems[index];
                      return AnimationConfiguration.staggeredGrid(
                        position: index,
                        duration: const Duration(milliseconds: 375), 
                        columnCount: (MediaQuery.of(context).size.width / 320.0).floor().clamp(1, 4),
                        child: ScaleAnimation(
                          child: FadeInAnimation(
                            child: _DashboardCard(
                              item: item,
                              onTap: () async {
                                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => item.destination));
                                if (item.title == 'Announcements') {
                                  _loadUnreadAnnouncements();
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: dashboardItems.length,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
        });
  }

  Widget _buildDrawerHeader(BuildContext context, ThemeData theme, Color primaryColor, Color appBarTextColor, bool isDarkMode) {
    return DrawerHeader(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ), 
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 30,
              backgroundColor: primaryColor,
              backgroundImage: (_currentUserAvatar != null && _currentUserAvatar!.isNotEmpty)
                  ? (_currentUserAvatar!.startsWith('http')
                      ? NetworkImage(_currentUserAvatar!)
                      : (() {
                          try {
                            return MemoryImage(base64Decode(_currentUserAvatar!.contains(',') ? _currentUserAvatar!.split(',').last : _currentUserAvatar!));
                          } catch (e) {
                            print('Error decoding avatar: $e');
                            return null;
                          }
                        })() as ImageProvider?)
                  : null,
              child: (_currentUserAvatar == null || _currentUserAvatar!.isEmpty)
                  ? Text(
                      _currentUsername.isNotEmpty ? _currentUsername.substring(0, 1).toUpperCase() : 'U',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.onPrimary, 
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome,', style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.7))),
              Text(
                _currentUsername,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: appBarTextColor
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// A dedicated StatefulWidget for the card tap animation
class _DashboardCard extends StatefulWidget {
  final _DashboardItem item;
  final VoidCallback onTap;

  const _DashboardCard({
    required this.item,
    required this.onTap,
  });

  @override
  State<_DashboardCard> createState() => _DashboardCardState();
}

class _DashboardCardState extends State<_DashboardCard> {
  bool _isTapped = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;

    final isDark = theme.brightness == Brightness.dark;
    final textColor = Colors.white; 
    final subtitleColor = Colors.white70;

    return AnimatedScale(
      scale: _isTapped ? 0.95 : 1.0,
      duration: const Duration(milliseconds: 150),
      child: GlassContainer(
        opacity: isDark ? 0.1 : 0.8,
        color: item.color,
        blur: 10,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        child: InkWell(
          onTapDown: (_) => setState(() => _isTapped = true),
          onTapUp: (_) => setState(() => _isTapped = false),
          onTapCancel: () => setState(() => _isTapped = false),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                 widget.onTap();
              }
            });
          },
          child: Stack(
            children: [
              // --- Background Animation Layer ---
              if (item.lottieAsset != null)
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.5, // Increased visibility
                    child: Lottie.asset(
                      item.lottieAsset!,
                      fit: BoxFit.cover,
                      onLoaded: (composition) {
                        print('Lottie Loaded: ${item.lottieAsset}');
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print('Lottie Error for ${item.lottieAsset}: $error');
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
                
              // --- Foreground Content Layer ---
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: item.icon ?? const SizedBox(),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: subtitleColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ✨ --- UPDATED CUSTOM PAINTER --- ✨
class TechGridPainter extends CustomPainter {
  final double animationValue;
  final Color lineColor;
  final Color squareColor;
  final Offset mousePosition;
  final List<_TechBit> techBits;

  // Re-usable painter for text
  final TextPainter _textPainter = TextPainter(
    textDirection: TextDirection.ltr,
  );


  TechGridPainter({
    required this.animationValue,
    required this.lineColor,
    required this.squareColor,
    required this.mousePosition,
    required this.techBits,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // --- 1. Draw Mouse Reactive Spotlight (draw first so it's behind) ---
    if (mousePosition != Offset.zero) { 
      final double radius = 150.0; 
      final Paint mousePaint = Paint()
        ..shader = RadialGradient(
          colors: [
            lineColor.withOpacity(0.3), // Spotlight matches line color
            Colors.transparent,
          ],
          stops: [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: mousePosition, radius: radius));
    
      canvas.drawCircle(mousePosition, radius, mousePaint);
    }
    // --- End Mouse Reactive Component ---


    // --- 2. Draw Animated Grid ---
    final Paint linePaint = Paint()
      ..color = lineColor 
      ..strokeWidth = 0.5 // Thinner lines
      ..style = PaintingStyle.stroke;

    final Paint squareFillPaint = Paint()
      ..color = squareColor
      ..style = PaintingStyle.fill;

    const double gridSize = 40.0; 
    const double maxOffset = 20.0; 

    final double offsetX = (math.sin(animationValue * math.pi * 2) * maxOffset);
    final double offsetY = (math.cos(animationValue * math.pi * 2) * maxOffset);

    for (double i = 0; i <= size.height + gridSize; i += gridSize) {
      final double y = i + offsetY;
      if (y >= -gridSize && y <= size.height + gridSize) { 
        canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      }
    }
    for (double i = 0; i <= size.width + gridSize; i += gridSize) {
      final double x = i + offsetX;
      if (x >= -gridSize && x <= size.width + gridSize) { 
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
    }

    // --- 3. Draw Animated Accent Shapes ---
    final double squareSize = 10.0;
    final double rectPulse = (math.sin(animationValue * math.pi * 4) + 1) / 2;
    
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.2 + offsetX * 0.5,
        size.height * 0.3 + offsetY * 0.5,
        squareSize + (squareSize * 0.5 * rectPulse),
        squareSize + (squareSize * 0.5 * rectPulse),
      ),
      squareFillPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.7 + (offsetX * 0.8),
        size.height * 0.6 + offsetY * 0.2,
        squareSize * 2,
        squareSize,
      ),
      squareFillPaint,
    );

    // --- 4. Draw Flying Bits & Code --- ✨
    double masterOffset = animationValue * size.height * 2.5; // Increased speed

    for (final bit in techBits) {
      double currentY = (bit.initialPosition.dy * size.height) + (masterOffset * bit.speed);
      
      // Check if the bit is off-screen and reset it to the top
      if (currentY > size.height + 20) {
        currentY = (currentY % (size.height + 20)) - 40;
      }

      double currentX = bit.initialPosition.dx * size.width;

      double opacity = 1.0;
      if (currentY < 20) { 
          opacity = currentY / 20;
      } else if (currentY > size.height - 20) { 
          opacity = (size.height - currentY) / 20;
      }
      opacity = opacity.clamp(0.0, 1.0);

      _textPainter.text = TextSpan(
          text: bit.text,
          style: TextStyle(
              // Use the color from the bit object!
              color: bit.color.withOpacity(opacity * bit.color.opacity), 
              fontSize: bit.fontSize,
              fontFamily: 'monospace', // Monospace for code
          ),
      );
      _textPainter.layout();
      _textPainter.paint(canvas, Offset(currentX, currentY));
    }
  }

  @override
  bool shouldRepaint(covariant TechGridPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
           oldDelegate.mousePosition != mousePosition;
  }
}

// -------------------------------------------------------------------
// NOTE: I have REMOVED the "Fake Stubs" for AuthService, User, etc.
// Please ensure you have these files in your own project:
// - 'package:app/services/auth_service.dart'
// - 'package:app/models/user.dart'
// - 'package:app/screens/attendance_screen.dart'
// - (and all other screen files)
// -------------------------------------------------------------------