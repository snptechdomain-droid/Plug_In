import 'package:flutter/material.dart';

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final String? tooltip;

  const _ToolButton({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip ?? '',
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 32,
          color: isSelected ? colorScheme.secondary.withOpacity(0.2) : Colors.transparent,
          child: Icon(
            icon,
            size: 18,
            color: isSelected ? colorScheme.secondary : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
