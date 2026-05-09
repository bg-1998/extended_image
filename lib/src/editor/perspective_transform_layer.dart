import 'package:flutter/material.dart';

import 'edit_action_details.dart';
import 'editor_config.dart';

class ExtendedImagePerspectiveTransformLayer extends StatefulWidget {
  const ExtendedImagePerspectiveTransformLayer({
    Key? key,
    required this.editActionDetails,
    required this.editorConfig,
    required this.onChanged,
    required this.onChangeEnd,
  }) : super(key: key);

  final EditActionDetails editActionDetails;
  final EditorConfig editorConfig;
  final ValueChanged<EditActionDetails> onChanged;
  final VoidCallback onChangeEnd;

  @override
  State<ExtendedImagePerspectiveTransformLayer> createState() =>
      _ExtendedImagePerspectiveTransformLayerState();
}

class _ExtendedImagePerspectiveTransformLayerState
    extends State<ExtendedImagePerspectiveTransformLayer> {
  static const double _handleSize = 18;

  @override
  Widget build(BuildContext context) {
    final Rect? destinationRect =
        widget.editActionDetails.screenDestinationRect;
    final bool meshWarpMode = widget.editorConfig.enableMeshWarpTransform;
    final bool isCropMode = widget.editorConfig.editorMode == EditorMode.crop;
    
    if (isCropMode || 
        (!widget.editorConfig.enablePerspectiveTransform && !meshWarpMode) ||
        destinationRect == null) {
      return const SizedBox.shrink();
    }

    final Offset layoutTopLeft =
        widget.editActionDetails.layoutTopLeft ?? Offset.zero;
    final List<Offset> points = meshWarpMode
        ? widget.editActionDetails.getMeshWarpControlPoints(
            rect: destinationRect,
          )
        : widget.editActionDetails.getPaintedImageCorners(
            rect: destinationRect,
          );
    final List<Offset> localPoints =
        points.map((Offset point) => point - layoutTopLeft).toList();
    final List<_PerspectiveHandle> handles = meshWarpMode
        ? _buildMeshWarpHandles(localPoints)
        : _buildPerspectiveHandles(localPoints);

    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: IgnorePointer(
            child: CustomPaint(
              painter: _PerspectiveTransformPainter(
                points: localPoints,
                meshWarpMode: meshWarpMode,
                color:
                    widget.editorConfig.perspectiveLineColor ??
                    Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
        for (final _PerspectiveHandle handle in handles)
          Positioned(
            left: handle.position.dx - widget.editorConfig.hitTestSize,
            top: handle.position.dy - widget.editorConfig.hitTestSize,
            width: widget.editorConfig.hitTestSize * 2,
            height: widget.editorConfig.hitTestSize * 2,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (DragUpdateDetails details) {
                final Rect? localBounds =
                    widget.editActionDetails.cropRectLayoutRect;
                final Rect? bounds = localBounds?.shift(layoutTopLeft);
                final bool changed = meshWarpMode
                    ? widget.editActionDetails.tryUpdateMeshWarpOffset(
                        handle.cornerIndexes.single,
                        details.delta,
                        bounds: bounds,
                      )
                    : widget.editActionDetails.tryUpdatePerspectiveOffsets(
                        handle.cornerIndexes,
                        details.delta,
                        bounds: bounds,
                      );
                if (changed) {
                  setState(() {});
                  widget.onChanged(widget.editActionDetails);
                }
              },
              onPanEnd: (_) => widget.onChangeEnd(),
              child: Center(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color:
                        widget.editorConfig.perspectiveHandleColor ??
                        Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const SizedBox.square(dimension: _handleSize),
                ),
              ),
            ),
          ),
      ],
    );
  }

  List<_PerspectiveHandle> _buildPerspectiveHandles(List<Offset> points) {
    return <_PerspectiveHandle>[
      _PerspectiveHandle(points[0], <int>[0]),
      _PerspectiveHandle((points[0] + points[1]) / 2, <int>[0, 1]),
      _PerspectiveHandle(points[1], <int>[1]),
      _PerspectiveHandle((points[1] + points[2]) / 2, <int>[1, 2]),
      _PerspectiveHandle(points[2], <int>[2]),
      _PerspectiveHandle((points[2] + points[3]) / 2, <int>[2, 3]),
      _PerspectiveHandle(points[3], <int>[3]),
      _PerspectiveHandle((points[3] + points[0]) / 2, <int>[3, 0]),
    ];
  }

  List<_PerspectiveHandle> _buildMeshWarpHandles(List<Offset> points) {
    return <_PerspectiveHandle>[
      for (int i = 0; i < points.length; i++)
        _PerspectiveHandle(points[i], <int>[i]),
    ];
  }
}

class _PerspectiveHandle {
  const _PerspectiveHandle(this.position, this.cornerIndexes);

  final Offset position;
  final List<int> cornerIndexes;
}

class _PerspectiveTransformPainter extends CustomPainter {
  const _PerspectiveTransformPainter({
    required this.points,
    required this.meshWarpMode,
    required this.color,
  });

  final List<Offset> points;
  final bool meshWarpMode;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = color;
    if (meshWarpMode) {
      if (points.length != 9) {
        return;
      }
      for (int y = 0; y < 3; y++) {
        canvas.drawLine(points[y * 3], points[y * 3 + 2], paint);
      }
      for (int x = 0; x < 3; x++) {
        canvas.drawLine(points[x], points[6 + x], paint);
      }
    } else {
      if (points.length != 4) {
        return;
      }
      canvas.drawPath(
        Path()
          ..moveTo(points[0].dx, points[0].dy)
          ..lineTo(points[1].dx, points[1].dy)
          ..lineTo(points[2].dx, points[2].dy)
          ..lineTo(points[3].dx, points[3].dy)
          ..close(),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PerspectiveTransformPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.meshWarpMode != meshWarpMode ||
        oldDelegate.color != color;
  }
}
