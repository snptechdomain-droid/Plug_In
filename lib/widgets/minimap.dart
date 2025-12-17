import 'package:flutter/material.dart';

class MinimapItem {
  final double x;
  final double y;
  final double width;
  final double height;
  final Color color;

  MinimapItem({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.color,
  });
}

class Minimap extends StatelessWidget {
  final List<MinimapItem> items;
  final Matrix4 viewTransform;
  final Size viewportSize;
  final ValueChanged<Matrix4>? onViewChanged;

  const Minimap({
    super.key,
    required this.items,
    required this.viewTransform,
    required this.viewportSize,
    this.onViewChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double viewScale = viewTransform.getMaxScaleOnAxis();
            final double transX = viewTransform.getTranslation().x;
            final double transY = viewTransform.getTranslation().y;
            
            // World coordinate of top-left screen corner (0,0)
            final double viewLeft = -transX / viewScale;
            final double viewTop = -transY / viewScale;
            final double viewW = viewportSize.width / viewScale;
            final double viewH = viewportSize.height / viewScale;
            final double viewRight = viewLeft + viewW;
            final double viewBottom = viewTop + viewH;

            double minX = double.infinity, minY = double.infinity;
            double maxX = double.negativeInfinity, maxY = double.negativeInfinity;

            if (items.isEmpty) {
              minX = viewLeft; minY = viewTop; maxX = viewRight; maxY = viewBottom;
            } else {
              for (var item in items) {
                if (item.x < minX) minX = item.x;
                if (item.y < minY) minY = item.y;
                if (item.x + item.width > maxX) maxX = item.x + item.width;
                if (item.y + item.height > maxY) maxY = item.y + item.height;
              }
            }
            
            // Ensure bounds include the viewport (so yellow box never disappears)
            if (viewLeft < minX) minX = viewLeft;
            if (viewTop < minY) minY = viewTop;
            if (viewRight > maxX) maxX = viewRight;
            if (viewBottom > maxY) maxY = viewBottom;

            // Add padding
            minX -= 500; minY -= 500; maxX += 500; maxY += 500;

            final double worldW = maxX - minX;
            final double worldH = maxY - minY;
            
            if (worldW <= 0 || worldH <= 0) return const SizedBox();

            final double scaleX = constraints.maxWidth / worldW;
            final double scaleY = constraints.maxHeight / worldH;
            final double scale = scaleX < scaleY ? scaleX : scaleY;

            return Stack(
              children: [
                // Draw items
                ...items.map((item) {
                  return Positioned(
                    left: (item.x - minX) * scale,
                    top: (item.y - minY) * scale,
                    width: item.width * scale,
                    height: item.height * scale,
                    child: Container(
                      color: item.color.withOpacity(0.8),
                    ),
                  );
                }),
                
                // Draw Viewport Rect
                Positioned(
                  left: (viewLeft - minX) * scale,
                  top: (viewTop - minY) * scale,
                  width: viewW * scale,
                  height: viewH * scale,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.yellow, width: 2),
                      color: Colors.yellow.withOpacity(0.1),
                    ),
                  ),
                ),
                
                // Interactive area to jump to position
                GestureDetector(
                  onPanUpdate: (details) {
                    if (onViewChanged == null) return;
                    // Convert local tap position to world position
                    final double localX = details.localPosition.dx;
                    final double localY = details.localPosition.dy;
                    
                    // World pos relative to minX/minY
                    final double worldX = localX / scale + minX;
                    final double worldY = localY / scale + minY;
                    
                    // We want to center the view on this world position
                    // NewTransX = - (WorldX - ViewW/2) * Scale
                    // But simpler: just move the view center to worldX, worldY
                    
                    final double newViewLeft = worldX - viewW / 2;
                    final double newViewTop = worldY - viewH / 2;
                    
                    final double newTransX = -newViewLeft * viewScale;
                    final double newTransY = -newViewTop * viewScale;
                    
                    final Matrix4 newMatrix = Matrix4.identity()
                      ..translate(newTransX, newTransY)
                      ..scale(viewScale);
                      
                    onViewChanged!(newMatrix);
                  },
                  onTapUp: (details) {
                     if (onViewChanged == null) return;
                    final double localX = details.localPosition.dx;
                    final double localY = details.localPosition.dy;
                    
                    final double worldX = localX / scale + minX;
                    final double worldY = localY / scale + minY;
                    
                    final double newViewLeft = worldX - viewW / 2;
                    final double newViewTop = worldY - viewH / 2;
                    
                    final double newTransX = -newViewLeft * viewScale;
                    final double newTransY = -newViewTop * viewScale;
                    
                    final Matrix4 newMatrix = Matrix4.identity()
                      ..translate(newTransX, newTransY)
                      ..scale(viewScale);
                      
                    onViewChanged!(newMatrix);
                  },
                  child: Container(color: Colors.transparent),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
