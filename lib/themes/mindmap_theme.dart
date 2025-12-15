import 'package:flutter/material.dart';

class MindMapTheme {
  final String id;
  final String name;
  final Color canvasColor;
  final bool isDark;
  final List<Color> palette;
  final double strokeWidth;
  final NodeShape nodeShape;

  const MindMapTheme({
    required this.id,
    required this.name,
    required this.canvasColor,
    required this.isDark,
    required this.palette,
    this.strokeWidth = 2.0,
    this.nodeShape = NodeShape.pill,
  });

  static const List<Color> defaultPalette = [
    Color(0xFFE63946), // Red
    Color(0xFF457B9D), // Blue
    Color(0xFF2A9D8F), // Teal
    Color(0xFFF4A261), // Orange
    Color(0xFF9B5DE5), // Purple
    Color(0xFFFF006E), // Pink
  ];

  static const MindMapTheme meister = MindMapTheme(
    id: 'meister',
    name: 'Meister Standard',
    canvasColor: Color(0xFFF5F7FA), // Very light grey/white
    isDark: false,
    palette: defaultPalette,
    nodeShape: NodeShape.pill,
  );

  static const MindMapTheme dark = MindMapTheme(
    id: 'dark',
    name: 'Dark Mode',
    canvasColor: Color(0xFF1A1A2E),
    isDark: true,
    palette: [
      Color(0xFFFFADAD),
      Color(0xFF9BF6FF),
      Color(0xFFFDFFB6),
      Color(0xFFBDB2FF),
    ],
  );
  
  Color getColor(int depth, int index) {
    if (depth == 0) return isDark ? Colors.white : Colors.black87;
    // Siblings at depth 1 get different colors
    // Children inherit parent color (logic handled in painter, here we just provide palette)
    return palette[index % palette.length];
  }
}

enum NodeShape {
  pill,
  rectangle,
  underline, // Just text with line
  bubble,
}
