import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CreativeToolbar extends StatelessWidget {
  final String title;
  final String iconPath;
  final bool canEdit;
  final VoidCallback? onBack;
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;
  final VoidCallback? onResetView;
  final VoidCallback? onSave;
  final bool showGrid;
  final ValueChanged<bool>? onGridChanged;
  final bool showSnap;
  final ValueChanged<bool>? onSnapChanged;
  final List<String>? activeUsers;
  final List<Widget>? extraActions;

  const CreativeToolbar({
    super.key,
    required this.title,
    required this.iconPath,
    this.canEdit = false,
    this.onBack, // New
    this.onZoomIn,
    this.onZoomOut,
    this.onResetView,
    this.onSave,
    this.showGrid = false,
    this.onGridChanged,
    this.showSnap = false,
    this.onSnapChanged,
    this.extraActions,
    this.activeUsers,
    this.isPanMode,
    this.onModeChanged,
  });

  final bool? isPanMode;
  final ValueChanged<bool>? onModeChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant.withOpacity(0.3))),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isSmallScreen = constraints.maxWidth < 600;
          
          if (isSmallScreen) {
            // Mobile Layout: Compact Single Row
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                   // 0. Back Button (Critical)
                   if (onBack != null) 
                     IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack, padding: EdgeInsets.zero),
                   
                  // 1. Icon & Title (Compact)

                  // 1. Icon & Title (Compact)
                  SvgPicture.asset(
                    iconPath,
                    width: 20,
                    height: 20,
                    colorFilter: ColorFilter.mode(Colors.blue.shade600, BlendMode.srcIn),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 12),
                  
                  // 2. Pan/Edit Toggle (Crucial)
                  if (isPanMode != null && onModeChanged != null) ...[
                    Container(
                      height: 28,
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _ToolButton(
                            icon: Icons.pan_tool,
                            isSelected: isPanMode!,
                            onTap: () => onModeChanged!(true),
                          ),
                          Container(width: 1, color: colorScheme.outlineVariant.withOpacity(0.5)),
                          _ToolButton(
                            icon: Icons.mouse,
                            isSelected: !isPanMode!,
                            onTap: () => onModeChanged!(false),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],

                  // 3. Save Button
                  if (canEdit && onSave != null)
                    IconButton(
                      onPressed: onSave,
                      icon: const Icon(Icons.save, size: 18),
                      color: colorScheme.secondary,
                      tooltip: 'Save',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  const SizedBox(width: 8),

                  // 4. View Controls (Compact)
                  if (onZoomOut != null) IconButton(icon: const Icon(Icons.remove, size: 18), onPressed: onZoomOut, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  const SizedBox(width: 4),
                  if (onResetView != null) IconButton(icon: const Icon(Icons.center_focus_strong, size: 18), onPressed: onResetView, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  const SizedBox(width: 4),
                  if (onZoomIn != null) IconButton(icon: const Icon(Icons.add, size: 18), onPressed: onZoomIn, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                  
                  // 5. Extra Actions
                  if (extraActions != null) ...[
                    const SizedBox(width: 8),
                    ...extraActions!,
                  ],
                ],
              ),
            );
          }

          // Desktop / Tablet Layout
          return Row(
            children: [
              // 0. Back Button
              if (onBack != null) ...[
                 IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
                 const SizedBox(width: 8),
              ],
              
              // Title Section
              SvgPicture.asset(
                iconPath,
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(Colors.blue.shade600, BlendMode.srcIn),
              ),
              const SizedBox(width: 12),
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Chip(
                label: Text(canEdit ? 'Editable' : 'Read-only'),
                backgroundColor: canEdit ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
                labelStyle: TextStyle(color: canEdit ? Colors.green : Colors.grey, fontSize: 12),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              
              const Spacer(),
              
              // Active Users
              if (activeUsers != null && activeUsers!.isNotEmpty) ...[
                SizedBox(
                  height: 32,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    shrinkWrap: true,
                    itemCount: activeUsers!.length,
                    itemBuilder: (context, index) {
                      return Align(
                        widthFactor: 0.6,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.primaries[index % Colors.primaries.length],
                          child: Text(
                            activeUsers![index][0],
                            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 16),
              ],

              // View Controls
              if (onZoomOut != null)
                IconButton(
                  icon: const Icon(Icons.zoom_out),
                  tooltip: 'Zoom Out',
                  onPressed: onZoomOut,
                  iconSize: 20,
                ),
              if (onResetView != null)
                IconButton(
                  icon: const Icon(Icons.center_focus_strong),
                  tooltip: 'Reset View',
                  onPressed: onResetView,
                  iconSize: 20,
                ),
              if (onZoomIn != null)
                IconButton(
                  icon: const Icon(Icons.zoom_in),
                  tooltip: 'Zoom In',
                  onPressed: onZoomIn,
                ),
              
              if (isPanMode != null && onModeChanged != null) ...[
                const SizedBox(width: 8),
                Container(
                  height: 32,
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _ToolButton(
                        icon: Icons.pan_tool,
                        tooltip: 'Pan Tool (Move Canvas)',
                        isSelected: isPanMode!,
                        onTap: () => onModeChanged!(true),
                      ),
                      Container(width: 1, color: colorScheme.outlineVariant.withOpacity(0.5)),
                      _ToolButton(
                        icon: Icons.mouse, // or near_me / arrow_selector_tool
                        tooltip: 'Select Tool (Edit Nodes)',
                        isSelected: !isPanMode!,
                        onTap: () => onModeChanged!(false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
              ],
                
              const SizedBox(width: 16),
              
              // Toggles
              if (onGridChanged != null) ...[
                Row(
                  children: [
                    const Text('Grid', style: TextStyle(fontSize: 12)),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: showGrid,
                        activeColor: colorScheme.secondary,
                        onChanged: onGridChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],
              if (onSnapChanged != null) ...[
                Row(
                  children: [
                    const Text('Snap', style: TextStyle(fontSize: 12)),
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: showSnap,
                        activeColor: colorScheme.secondary,
                        onChanged: onSnapChanged,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
              ],

              // Extra Actions
              if (extraActions != null) ...extraActions!,

              // Save
              if (canEdit && onSave != null) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text('Save'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colorScheme.secondary,
                    foregroundColor: colorScheme.onSecondary,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ]
            ],
          );
        }
      ),
    );
  }
}

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
