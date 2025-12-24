
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:app/models/event.dart';
import 'package:app/utils/pattern_generator.dart';
import 'package:app/widgets/registration_dialog.dart';

class EventDetailsScreen extends StatelessWidget {
  final Event event;

  const EventDetailsScreen({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final patternSvg = PatternGenerator.generateRandomSvgPattern(event.id ?? event.title);

    bool _isSvg(String data) {
      final lower = data.toLowerCase();
      return lower.contains('svg+xml') ||
          lower.trim().startsWith('<svg') ||
          lower.startsWith('phn2zy'); // base64 for <svg
    }

    Widget _buildHeaderImage() {
      if (event.imageUrl == null || event.imageUrl!.isEmpty) {
        return SvgPicture.string(patternSvg, fit: BoxFit.cover);
      }
      final value = event.imageUrl!;
      if (value.startsWith('http')) {
        if (value.toLowerCase().endsWith('.svg')) {
          return SvgPicture.network(value, fit: BoxFit.cover);
        }
        return Image.network(value, fit: BoxFit.cover);
      }

      if (_isSvg(value)) {
        try {
          final svgString = value.contains(',')
              ? utf8.decode(base64Decode(value.split(',').last))
              : utf8.decode(base64Decode(value));
          return SvgPicture.string(svgString, fit: BoxFit.cover);
        } catch (_) {
          return SvgPicture.string(patternSvg, fit: BoxFit.cover);
        }
      }

      try {
        return Image.memory(base64Decode(value), fit: BoxFit.cover);
      } catch (_) {
        return SvgPicture.string(patternSvg, fit: BoxFit.cover);
      }
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Event Details'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(color: Colors.white),
      ),
      body: Stack(
        children: [
          // 1. Dynamic Pattern or Uploaded Image
          Positioned.fill(
             child: _buildHeaderImage(),
          ),
          
          // 2. Glassy Overlay/Gradient for readability
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),

          // 3. Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title & Date
                  Text(
                    event.title,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      _buildInfoBadge(context, Icons.calendar_today, DateFormat.yMMMd().format(event.date)),
                      const SizedBox(width: 12),
                      _buildInfoBadge(context, Icons.access_time, DateFormat.jm().format(event.date)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoBadge(context, Icons.location_on, event.venue),

                  const SizedBox(height: 32),
                  
                  // Description Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: theme.cardColor.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                         BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, 5)),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'About Event',
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          event.description,
                          style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                        ),
                        
                        // Registration Status
                        const SizedBox(height: 32),
                        if (event.registrationStarted)
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => RegistrationDialog(
                                    eventId: event.id ?? '', 
                                    eventTitle: event.title,
                                  ),
                                );
                              },
                              icon: const Icon(Icons.confirmation_number),
                              label: const Text('Register Now'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        else
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey),
                            ),
                            child: const Column(
                              children: [
                                Icon(Icons.lock_clock, color: Colors.grey, size: 32),
                                SizedBox(height: 8),
                                Text(
                                  'Registration Opens Soon',
                                  style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBadge(BuildContext context, IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
