import 'dart:math';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart';

class _LineIntersection {
  const _LineIntersection(this.t1, this.t2);

  final double t1;
  final double t2;
}

class EditActionDetails {
  EditorConfig? config;
  Rect? _layoutRect;
  Rect? get layoutRect => _layoutRect;
  Rect? _screenDestinationRect;
  Rect? _rawDestinationRect;

  double totalScale = 1.0;
  double preTotalScale = 1.0;

  Offset delta = Offset.zero;
  Offset? screenFocalPoint;
  EdgeInsets? cropRectPadding;
  Rect? cropRect;

  /// aspect ratio of image
  double? originalAspectRatio;

  ///  aspect ratio of crop rect

  double? _cropAspectRatio;

  /// the original aspect ratio
  double? get originalCropAspectRatio => _cropAspectRatio;

  /// current aspect ratio of crop rect
  double? get cropAspectRatio {
    if (_cropAspectRatio != null && _cropAspectRatio! <= 0) {
      return originalAspectRatio;
    }
    return _cropAspectRatio;
  }

  set cropAspectRatio(double? value) {
    if (_cropAspectRatio != value) {
      _cropAspectRatio = value;
    }
  }

  /// image
  Rect? get screenDestinationRect => _screenDestinationRect;

  void setScreenDestinationRect(Rect value) {
    _screenDestinationRect = value;
  }

  double _rotateRadians = 0.0;
  double get rotateRadians => _rotateRadians;
  set rotateRadians(double value) {
    // ingore precisionErrorTolerance
    if (value != 0.0 && value.isZero) {
      value = 0.0;
    }
    _rotateRadians = value;
  }

  double rotationYRadians = 0.0;

  List<Offset>? perspectiveOffsets;
  List<Offset>? meshWarpOffsets;

  bool get hasPerspective => perspectiveOffsets != null;
  bool get hasMeshWarp => meshWarpOffsets != null;

  bool get hasRotateDegrees => !isTwoPi;

  bool get hasEditAction =>
      hasRotateDegrees || rotationYRadians != 0 || hasPerspective || hasMeshWarp;

  bool get needCrop => screenCropRect != screenDestinationRect;

  double get rotateDegrees => degrees(rotateRadians);

  bool get needFlip => rotationYRadians != 0;

  bool get flipY => rotationYRadians != 0;

  bool get isHalfPi => (rotateRadians % (2 * pi)) == pi / 2;

  bool get isPi => (rotateRadians % (2 * pi)) == pi;

  bool get isTwoPi => (rotateRadians % (2 * pi)) == 0;

  /// destination rect base on layer
  Rect? get layerDestinationRect =>
      screenDestinationRect?.shift(-layoutTopLeft!);

  Offset? get layoutTopLeft => _layoutRect?.topLeft;

  Rect? get rawDestinationRect => _rawDestinationRect;

  Rect? get screenCropRect => cropRect?.shift(layoutTopLeft!);

  Rect? get cropRectLayoutRect {
    if (cropRectPadding != null) {
      return cropRectPadding!.deflateRect(_layoutRect!).shift(-layoutTopLeft!);
    }
    return _layoutRect?.shift(-layoutTopLeft!);
  }

  Offset? get cropRectLayoutRectCenter => cropRectLayoutRect?.center;

  void initRect(Rect layoutRect, Rect destinationRect) {
    if (_layoutRect != layoutRect) {
      _layoutRect = layoutRect;
      _screenDestinationRect = null;
    }

    if (_rawDestinationRect != destinationRect) {
      _rawDestinationRect = destinationRect;
      _screenDestinationRect = null;
    }
  }

  Rect getFinalDestinationRect() {
    if (screenDestinationRect != null) {
      /// scale
      final double scaleDelta = totalScale / preTotalScale;
      if (scaleDelta != 1.0) {
        Offset focalPoint = screenFocalPoint ?? _screenDestinationRect!.center;

        focalPoint = Offset(
          focalPoint.dx
              .clamp(
                _screenDestinationRect!.left,
                _screenDestinationRect!.right,
              )
              .toDouble(),
          focalPoint.dy
              .clamp(
                _screenDestinationRect!.top,
                _screenDestinationRect!.bottom,
              )
              .toDouble(),
        );

        _screenDestinationRect = Rect.fromLTWH(
          focalPoint.dx -
              (focalPoint.dx - _screenDestinationRect!.left) * scaleDelta,
          focalPoint.dy -
              (focalPoint.dy - _screenDestinationRect!.top) * scaleDelta,
          _screenDestinationRect!.width * scaleDelta,
          _screenDestinationRect!.height * scaleDelta,
        );

        preTotalScale = totalScale;

        delta = Offset.zero;
      }
      /// move
      else {
        if (_screenDestinationRect != screenCropRect) {
          _screenDestinationRect = _screenDestinationRect!.shift(delta);
        }
        // we have shift offset, we should clear delta.
        delta = Offset.zero;
      }
    } else {
      _screenDestinationRect = getRectWithScale(
        _rawDestinationRect!,
        totalScale,
      );
    }
    return _screenDestinationRect!;
  }

  Rect getRectWithScale(Rect rect, double totalScale) {
    final double width = rect.width * totalScale;
    final double height = rect.height * totalScale;
    final Offset center = rect.center;
    return Rect.fromLTWH(
      center.dx - width / 2.0,
      center.dy - height / 2.0,
      width,
      height,
    );
  }

  /// The path of the processed image, displayed on the screen
  ///
  Path getImagePath({Rect? rect, bool includePerspective = true}) {
    rect ??= _screenDestinationRect!;

    final List<Offset> rotatedCorners = includePerspective
        ? getPaintedImageCorners(rect: rect)
        : getImageCorners(rect: rect);

    final Path path = Path()
      ..moveTo(rotatedCorners[0].dx, rotatedCorners[0].dy)
      ..lineTo(rotatedCorners[1].dx, rotatedCorners[1].dy)
      ..lineTo(rotatedCorners[2].dx, rotatedCorners[2].dy)
      ..lineTo(rotatedCorners[3].dx, rotatedCorners[3].dy)
      ..close();
    if (includePerspective && hasMeshWarp) {
      for (final Offset point in getMeshWarpControlPoints(rect: rect)) {
        path.addOval(Rect.fromCircle(center: point, radius: 1));
      }
    }
    return path;
  }

  List<Offset> getImageCorners({Rect? rect}) {
    rect ??= _screenDestinationRect!;
    final Matrix4 result = getTransform();
    return <Offset>[
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ].map((Offset corner) {
      final Vector4 cornerVector = Vector4(corner.dx, corner.dy, 0.0, 1.0);
      final Vector4 newCornerVector = result.transform(cornerVector);
      return Offset(newCornerVector.x, newCornerVector.y);
    }).toList();
  }

  List<Offset> getPaintedImageCorners({Rect? rect}) {
    final List<Offset> corners = getImageCorners(rect: rect);
    if (!hasPerspective) {
      return corners;
    }
    return <Offset>[
      corners[0] + perspectiveOffsets![0],
      corners[1] + perspectiveOffsets![1],
      corners[2] + perspectiveOffsets![2],
      corners[3] + perspectiveOffsets![3],
    ];
  }

  List<Offset> getMeshWarpControlPoints({Rect? rect}) {
    rect ??= _screenDestinationRect!;
    final List<Offset> corners = getPaintedImageCorners(rect: rect);
    final List<Offset> offsets =
        meshWarpOffsets ?? List<Offset>.filled(9, Offset.zero);
    return <Offset>[
      for (int y = 0; y < 3; y++)
        for (int x = 0; x < 3; x++)
          _bilinearPoint(corners, x / 2, y / 2) + offsets[y * 3 + x],
    ];
  }

  Offset getWarpedImagePoint({Rect? rect, required double u, required double v}) {
    rect ??= _screenDestinationRect!;
    if (!hasMeshWarp) {
      return _bilinearPoint(getPaintedImageCorners(rect: rect), u, v);
    }

    final List<Offset> points = getMeshWarpControlPoints(rect: rect);
    final int cellX = min((u * 2).floor(), 1);
    final int cellY = min((v * 2).floor(), 1);
    final double localU = u * 2 - cellX;
    final double localV = v * 2 - cellY;
    final int topLeftIndex = cellY * 3 + cellX;
    return _bilinearPoint(
      <Offset>[
        points[topLeftIndex],
        points[topLeftIndex + 1],
        points[topLeftIndex + 4],
        points[topLeftIndex + 3],
      ],
      localU,
      localV,
    );
  }

  Offset _bilinearPoint(List<Offset> corners, double u, double v) {
    return corners[0] * (1 - u) * (1 - v) +
        corners[1] * u * (1 - v) +
        corners[3] * (1 - u) * v +
        corners[2] * u * v;
  }

  Rect rotateRect(Rect rect, Offset center, double angle) {
    final Offset leftTop = rotateOffset(rect.topLeft, center, angle);
    final Offset bottomRight = rotateOffset(rect.bottomRight, center, angle);
    return Rect.fromPoints(leftTop, bottomRight);
  }

  Offset rotateOffset(Offset input, Offset center, double angle) {
    final double x = input.dx;
    final double y = input.dy;
    final double rx0 = center.dx;
    final double ry0 = center.dy;
    final double x0 = (x - rx0) * cos(angle) - (y - ry0) * sin(angle) + rx0;
    final double y0 = (x - rx0) * sin(angle) + (y - ry0) * cos(angle) + ry0;
    return Offset(x0, y0);
  }

  Matrix4 getTransform({Offset? center}) {
    final Offset origin =
        center ?? _layoutRect?.center ?? _screenDestinationRect!.center;
    final Matrix4 result = Matrix4.identity();

    result.translate(origin.dx, origin.dy);
    if (rotationYRadians != 0) {
      result.multiply(Matrix4.rotationY(rotationYRadians));
    }
    if (hasRotateDegrees) {
      result.multiply(Matrix4.rotationZ(rotateRadians));
    }

    result.translate(-origin.dx, -origin.dy);

    return result;
  }

  Matrix4 getPaintTransform() {
    if (!hasPerspective) {
      return getTransform();
    }

    final Rect rect = _screenDestinationRect!;
    final List<Offset> corners = getImageCorners(rect: rect);
    final List<Offset> targetCorners = <Offset>[
      corners[0] + perspectiveOffsets![0],
      corners[1] + perspectiveOffsets![1],
      corners[2] + perspectiveOffsets![2],
      corners[3] + perspectiveOffsets![3],
    ];
    return getProjectiveTransform(<Offset>[
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ], targetCorners);
  }

  void updatePerspectiveOffset(int index, Offset delta) {
    assert(index >= 0 && index < 4);
    final List<Offset> offsets =
        perspectiveOffsets == null
            ? List<Offset>.filled(4, Offset.zero)
            : List<Offset>.of(perspectiveOffsets!);
    offsets[index] += delta;
    perspectiveOffsets = offsets;
  }

  bool tryUpdatePerspectiveOffsets(
    List<int> indexes,
    Offset delta, {
    Rect? bounds,
  }) {
    final Rect? rect = _screenDestinationRect;
    if (rect == null) {
      return false;
    }

    final List<Offset> corners = getImageCorners(rect: rect);
    final List<Offset> offsets =
        perspectiveOffsets == null
            ? List<Offset>.filled(4, Offset.zero)
            : List<Offset>.of(perspectiveOffsets!);

    Offset adjustedDelta = delta;
    if (bounds != null) {
      for (final int index in indexes) {
        final Offset point = corners[index] + offsets[index];
        adjustedDelta = Offset(
          adjustedDelta.dx.clamp(
            bounds.left - point.dx,
            bounds.right - point.dx,
          ),
          adjustedDelta.dy.clamp(
            bounds.top - point.dy,
            bounds.bottom - point.dy,
          ),
        );
      }
    }

    for (final int index in indexes) {
      assert(index >= 0 && index < 4);
      offsets[index] += adjustedDelta;
    }

    final List<Offset> points = <Offset>[
      corners[0] + offsets[0],
      corners[1] + offsets[1],
      corners[2] + offsets[2],
      corners[3] + offsets[3],
    ];
    if (!_isValidPerspectiveQuadrilateral(points)) {
      return false;
    }

    final List<Offset> sourceCorners = <Offset>[
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
    ];
    final List<double>? coefficients = _getProjectiveCoefficients(
      sourceCorners,
      points,
    );
    if (coefficients == null ||
        !_isStableProjectiveTransform(sourceCorners, coefficients)) {
      return false;
    }

    perspectiveOffsets = offsets;
    return true;
  }

  void setPerspectiveOffsets(List<Offset>? offsets) {
    assert(offsets == null || offsets.length == 4);
    perspectiveOffsets = offsets == null ? null : List<Offset>.of(offsets);
  }

  void resetPerspective() {
    perspectiveOffsets = null;
  }

  bool tryUpdateMeshWarpOffset(int index, Offset delta, {Rect? bounds}) {
    assert(index >= 0 && index < 9);
    final Rect? rect = _screenDestinationRect;
    if (rect == null) {
      return false;
    }
    final List<Offset> controls = getMeshWarpControlPoints(rect: rect);
    Offset adjustedDelta = delta;
    if (bounds != null) {
      final Offset point = controls[index];
      adjustedDelta = Offset(
        adjustedDelta.dx.clamp(bounds.left - point.dx, bounds.right - point.dx),
        adjustedDelta.dy.clamp(bounds.top - point.dy, bounds.bottom - point.dy),
      );
    }

    final List<Offset> offsets =
        meshWarpOffsets == null
            ? List<Offset>.filled(9, Offset.zero)
            : List<Offset>.of(meshWarpOffsets!);
    offsets[index] += adjustedDelta;
    meshWarpOffsets = offsets;
    return true;
  }

  void setMeshWarpOffsets(List<Offset>? offsets) {
    assert(offsets == null || offsets.length == 9);
    meshWarpOffsets = offsets == null ? null : List<Offset>.of(offsets);
  }

  void resetMeshWarp() {
    meshWarpOffsets = null;
  }

  Matrix4 getProjectiveTransform(List<Offset> from, List<Offset> to) {
    assert(from.length == 4 && to.length == 4);
    final List<double>? h = _getProjectiveCoefficients(from, to);
    if (h == null || !_isStableProjectiveTransform(from, h)) {
      return Matrix4.identity();
    }
    return _matrixFromProjectiveCoefficients(h);
  }

  List<double>? _getProjectiveCoefficients(List<Offset> from, List<Offset> to) {
    final List<List<double>> a = <List<double>>[];
    final List<double> b = <double>[];
    for (int i = 0; i < 4; i++) {
      final double x = from[i].dx;
      final double y = from[i].dy;
      final double u = to[i].dx;
      final double v = to[i].dy;
      a.add(<double>[x, y, 1, 0, 0, 0, -u * x, -u * y]);
      b.add(u);
      a.add(<double>[0, 0, 0, x, y, 1, -v * x, -v * y]);
      b.add(v);
    }
    final List<double>? h = _solveLinearSystem(a, b);
    if (h == null) {
      return null;
    }
    return <double>[h[0], h[1], h[2], h[3], h[4], h[5], h[6], h[7], 1];
  }

  Matrix4 _matrixFromProjectiveCoefficients(List<double> h) {
    return Matrix4.identity()
      ..setEntry(0, 0, h[0])
      ..setEntry(0, 1, h[1])
      ..setEntry(0, 3, h[2])
      ..setEntry(1, 0, h[3])
      ..setEntry(1, 1, h[4])
      ..setEntry(1, 3, h[5])
      ..setEntry(3, 0, h[6])
      ..setEntry(3, 1, h[7]);
  }

  bool _isValidPerspectiveQuadrilateral(List<Offset> points) {
    if (points.length != 4) {
      return false;
    }
    for (final Offset point in points) {
      if (!point.dx.isFinite || !point.dy.isFinite) {
        return false;
      }
    }

    const double minSide = 12;
    const double minCross = 50;
    const double minTriangleArea = 100;
    for (int i = 0; i < 4; i++) {
      if ((points[(i + 1) % 4] - points[i]).distance < minSide) {
        return false;
      }
    }

    for (int i = 0; i < 4; i++) {
      final Offset a = points[i];
      final Offset b = points[(i + 1) % 4];
      final Offset c = points[(i + 2) % 4];
      final double triangleArea =
          ((b.dx - a.dx) * (c.dy - a.dy) -
                  (b.dy - a.dy) * (c.dx - a.dx))
              .abs() /
          2;
      if (triangleArea < minTriangleArea) {
        return false;
      }
    }

    double signedArea = 0;
    for (int i = 0; i < 4; i++) {
      final Offset a = points[i];
      final Offset b = points[(i + 1) % 4];
      signedArea += a.dx * b.dy - b.dx * a.dy;
    }
    if (signedArea.abs() < 200) {
      return false;
    }

    double? crossSign;
    for (int i = 0; i < 4; i++) {
      final Offset a = points[i];
      final Offset b = points[(i + 1) % 4];
      final Offset c = points[(i + 2) % 4];
      final Offset ab = b - a;
      final Offset bc = c - b;
      final double cross = ab.dx * bc.dy - ab.dy * bc.dx;
      if (cross.abs() < minCross) {
        return false;
      }
      crossSign ??= cross.sign;
      if (cross.sign != crossSign) {
        return false;
      }
    }
    return crossSign != null &&
        !_segmentsIntersect(points[0], points[1], points[2], points[3]) &&
        !_segmentsIntersect(points[1], points[2], points[3], points[0]) &&
        _hasStableDiagonals(points);
  }

  bool _hasStableDiagonals(List<Offset> points) {
    const double minDiagonal = 24;
    if ((points[2] - points[0]).distance < minDiagonal ||
        (points[3] - points[1]).distance < minDiagonal) {
      return false;
    }

    final _LineIntersection? intersection = _lineIntersection(
      points[0],
      points[2],
      points[1],
      points[3],
    );
    if (intersection == null) {
      return false;
    }

    const double minT = 0.08;
    const double maxT = 0.92;
    return intersection.t1 > minT &&
        intersection.t1 < maxT &&
        intersection.t2 > minT &&
        intersection.t2 < maxT;
  }

  _LineIntersection? _lineIntersection(
    Offset a,
    Offset b,
    Offset c,
    Offset d,
  ) {
    final Offset r = b - a;
    final Offset s = d - c;
    final double denominator = _cross(r, s);
    if (denominator.abs() < 0.000001) {
      return null;
    }
    final Offset ca = c - a;
    return _LineIntersection(
      _cross(ca, s) / denominator,
      _cross(ca, r) / denominator,
    );
  }

  bool _segmentsIntersect(Offset a, Offset b, Offset c, Offset d) {
    final double d1 = _cross(c - a, b - a);
    final double d2 = _cross(d - a, b - a);
    final double d3 = _cross(a - c, d - c);
    final double d4 = _cross(b - c, d - c);
    return d1 * d2 < 0 && d3 * d4 < 0;
  }

  double _cross(Offset a, Offset b) {
    return a.dx * b.dy - a.dy * b.dx;
  }

  bool _isStableProjectiveTransform(List<Offset> source, List<double> h) {
    const double minAbsW = 0.02;
    double? sign;
    for (int y = 0; y <= 4; y++) {
      final double v = y / 4;
      for (int x = 0; x <= 4; x++) {
        final double u = x / 4;
        final Offset point =
            source[0] * (1 - u) * (1 - v) +
            source[1] * u * (1 - v) +
            source[3] * (1 - u) * v +
            source[2] * u * v;
        final double w = h[6] * point.dx + h[7] * point.dy + h[8];
        if (!w.isFinite || w.abs() < minAbsW) {
          return false;
        }
        sign ??= w.sign;
        if (w.sign != sign) {
          return false;
        }
        final double tx = (h[0] * point.dx + h[1] * point.dy + h[2]) / w;
        final double ty = (h[3] * point.dx + h[4] * point.dy + h[5]) / w;
        if (!tx.isFinite || !ty.isFinite) {
          return false;
        }
      }
    }
    return sign != null;
  }

  List<double>? _solveLinearSystem(List<List<double>> a, List<double> b) {
    final int n = b.length;
    for (int i = 0; i < n; i++) {
      int maxRow = i;
      for (int k = i + 1; k < n; k++) {
        if (a[k][i].abs() > a[maxRow][i].abs()) {
          maxRow = k;
        }
      }
      final List<double> tmpRow = a[i];
      a[i] = a[maxRow];
      a[maxRow] = tmpRow;
      final double tmpValue = b[i];
      b[i] = b[maxRow];
      b[maxRow] = tmpValue;

      final double pivot = a[i][i];
      if (pivot.abs() < 0.000001) {
        return null;
      }
      for (int k = i + 1; k < n; k++) {
        final double factor = a[k][i] / pivot;
        for (int j = i; j < n; j++) {
          a[k][j] -= factor * a[i][j];
        }
        b[k] -= factor * b[i];
      }
    }

    final List<double> x = List<double>.filled(n, 0);
    for (int i = n - 1; i >= 0; i--) {
      double sum = b[i];
      for (int j = i + 1; j < n; j++) {
        sum -= a[i][j] * x[j];
      }
      if (a[i][i].abs() < 0.000001) {
        return null;
      }
      x[i] = sum / a[i][i];
    }
    return x;
  }

  double reverseRotateRadians(double rotateRadians) {
    return rotationYRadians == 0 ? rotateRadians : -rotateRadians;
  }

  void updateRotateRadians(double rotateRadians, double maxScale) {
    this.rotateRadians = rotateRadians;
    scaleToFitRect(maxScale);
  }

  void scaleToFitRect(double maxScale) {
    double scaleDelta = scaleToFitCropRect();

    if (scaleDelta > 0) {
      // can't scale image
      // so we should scale the crop rect
      if (totalScale * scaleDelta > maxScale) {
        screenFocalPoint = null;
        preTotalScale = totalScale;
        totalScale = maxScale;
        getFinalDestinationRect();
        scaleDelta = scaleToFitImageRect();
        if (scaleDelta > 0) {
          cropRect = Rect.fromCenter(
            center: cropRect!.center,
            width: cropRect!.width * scaleDelta,
            height: cropRect!.height * scaleDelta,
          );
        } else {
          updateDelta(Offset.zero);
        }
      } else {
        screenFocalPoint = null;
        preTotalScale = totalScale;
        totalScale = totalScale * scaleDelta;
      }
    } else {
      // scale the image to align with the crop rect
      final Matrix4 result = getTransform();
      result.invert();
      final Rect rect = _screenDestinationRect!;
      final List<Offset> rectVertices =
          <Offset>[
            screenCropRect!.topLeft,
            screenCropRect!.topRight,
            screenCropRect!.bottomRight,
            screenCropRect!.bottomLeft,
          ].map((Offset element) {
            final Vector4 cornerVector = Vector4(
              element.dx,
              element.dy,
              0.0,
              1.0,
            );
            final Vector4 newCornerVector = result.transform(cornerVector);
            return Offset(newCornerVector.x, newCornerVector.y);
          }).toList();

      final double scaleDelta = scaleToMatchRect(rectVertices, rect);
      // apply it only scaleDelta is small.
      if (scaleDelta != double.negativeInfinity &&
          totalScale * (1 - scaleDelta) <= 0.05) {
        screenFocalPoint = null;
        preTotalScale = totalScale;
        totalScale = totalScale * scaleDelta;
      }
    }
  }

  double scaleToFitCropRect() {
    final Matrix4 result = getTransform();
    result.invert();
    final Rect rect = _screenDestinationRect!;
    final List<Offset> rectVertices =
        <Offset>[
          screenCropRect!.topLeft,
          screenCropRect!.topRight,
          screenCropRect!.bottomRight,
          screenCropRect!.bottomLeft,
        ].map((Offset element) {
          final Vector4 cornerVector = Vector4(
            element.dx,
            element.dy,
            0.0,
            1.0,
          );
          final Vector4 newCornerVector = result.transform(cornerVector);
          return Offset(newCornerVector.x, newCornerVector.y);
        }).toList();

    final double scaleDelta = scaleToFit(rectVertices, rect);
    return scaleDelta;
  }

  double scaleToMatchRect(List<Offset> rectVertices, Rect rect) {
    double scaleDelta = double.negativeInfinity;
    final Offset center = rect.center;
    for (final Offset element in rectVertices) {
      if (!rect.containsOffset(element)) {
        continue;
      }
      final double x = (element.dx - center.dx).abs();
      final double y = (element.dy - center.dy).abs();
      final double halfWidth = rect.width / 2;
      final double halfHeight = rect.height / 2;
      if (x < halfWidth || y < halfHeight) {
        scaleDelta = max(scaleDelta, max(x / halfWidth, y / halfHeight));
      }
    }

    return scaleDelta;
  }

  double scaleToFit(List<Offset> rectVertices, Rect rect) {
    double scaleDelta = 0.0;

    int contains = 0;
    final Offset center = rect.center;
    for (final Offset element in rectVertices) {
      if (rect.containsOffset(element)) {
        contains++;
        continue;
      }
      final double x = (element.dx - center.dx).abs();
      final double y = (element.dy - center.dy).abs();
      final double halfWidth = rect.width / 2;
      final double halfHeight = rect.height / 2;
      if (x > halfWidth || y > halfHeight) {
        scaleDelta = max(scaleDelta, max(x / halfWidth, y / halfHeight));
      }
    }
    if (contains == 4) {
      return -1;
    }
    return scaleDelta;
  }

  double scaleToFitImageRect() {
    final Matrix4 result = getTransform();
    result.invert();
    final Rect rect = _screenDestinationRect!;
    final List<Offset> rectVertices =
        <Offset>[
          screenCropRect!.topLeft,
          screenCropRect!.topRight,
          screenCropRect!.bottomRight,
          screenCropRect!.bottomLeft,
        ].map((Offset element) {
          final Vector4 cornerVector = Vector4(
            element.dx,
            element.dy,
            0.0,
            1.0,
          );
          final Vector4 newCornerVector = result.transform(cornerVector);
          return Offset(newCornerVector.x, newCornerVector.y);
        }).toList();

    final double scaleDelta = _scaleToFitImageRect(
      rectVertices,
      rect,
      rect.center,
    );
    return scaleDelta;
  }

  double _scaleToFitImageRect(
    List<Offset> rectVertices,
    Rect rect,
    Offset center,
  ) {
    double scaleDelta = double.maxFinite;
    final Offset cropRectCenter = (rectVertices[0] + (rectVertices[2])) / 2;
    int contains = 0;
    for (final Offset element in rectVertices) {
      if (rect.containsOffset(element)) {
        contains++;
        continue;
      }
      final List<Offset> list = getLineRectIntersections(
        rect,
        element,
        cropRectCenter,
      );
      if (list.isNotEmpty) {
        scaleDelta = min(
          scaleDelta,
          sqrt(
                pow(list[0].dx - cropRectCenter.dx, 2) +
                    pow(list[0].dy - cropRectCenter.dy, 2),
              ) /
              sqrt(
                pow(element.dx - cropRectCenter.dx, 2) +
                    pow(element.dy - cropRectCenter.dy, 2),
              ),
        );
      }
    }
    if (contains == 4 || scaleDelta == double.maxFinite) {
      return -1;
    }
    return scaleDelta;
  }

  void updateDelta(Offset delta) {
    double dx = delta.dx;
    final double dy = delta.dy;
    if (rotationYRadians == pi) {
      dx = -dx;
    }
    final double transformedDx =
        dx * cos(rotateRadians) + dy * sin(rotateRadians);
    final double transformedDy =
        dy * cos(rotateRadians) - dx * sin(rotateRadians);

    Offset offset = Offset(transformedDx, transformedDy);
    Rect rect = _screenDestinationRect!.shift(offset);

    final Matrix4 result = getTransform();
    result.invert();
    final List<Offset> rectVertices =
        <Offset>[
          screenCropRect!.topLeft,
          screenCropRect!.topRight,
          screenCropRect!.bottomRight,
          screenCropRect!.bottomLeft,
        ].map((Offset element) {
          final Vector4 cornerVector = Vector4(
            element.dx,
            element.dy,
            0.0,
            1.0,
          );
          final Vector4 newCornerVector = result.transform(cornerVector);
          return Offset(newCornerVector.x, newCornerVector.y);
        }).toList();

    for (final Offset element in rectVertices) {
      if (rect.containsOffset(element)) {
        continue;
      }

      // find nearest point on rect
      final double nearestX = element.dx.clamp(rect.left, rect.right);
      final double nearestY = element.dy.clamp(rect.top, rect.bottom);

      final Offset nearestOffset = Offset(nearestX, nearestY);

      if (nearestOffset != element) {
        offset -= nearestOffset - element;
        rect = _screenDestinationRect = _screenDestinationRect!.shift(offset);
        // clear
        offset = Offset.zero;
      }
    }

    this.delta += offset;
  }

  void updateScale(double totalScale) {
    final double scaleDelta = totalScale / preTotalScale;
    if (scaleDelta == 1.0) {
      return;
    }
    final Matrix4 result = getTransform();
    result.invert();
    final List<Offset> rectVertices =
        <Offset>[
          screenCropRect!.topLeft,
          screenCropRect!.topRight,
          screenCropRect!.bottomRight,
          screenCropRect!.bottomLeft,
        ].map((Offset element) {
          final Vector4 cornerVector = Vector4(
            element.dx,
            element.dy,
            0.0,
            1.0,
          );
          final Vector4 newCornerVector = result.transform(cornerVector);
          return Offset(newCornerVector.x, newCornerVector.y);
        }).toList();

    Offset focalPoint = screenFocalPoint ?? _screenDestinationRect!.center;

    focalPoint = Offset(
      focalPoint.dx
          .clamp(_screenDestinationRect!.left, _screenDestinationRect!.right)
          .toDouble(),
      focalPoint.dy
          .clamp(_screenDestinationRect!.top, _screenDestinationRect!.bottom)
          .toDouble(),
    );

    Rect rect = Rect.fromLTWH(
      focalPoint.dx -
          (focalPoint.dx - _screenDestinationRect!.left) * scaleDelta,
      focalPoint.dy -
          (focalPoint.dy - _screenDestinationRect!.top) * scaleDelta,
      _screenDestinationRect!.width * scaleDelta,
      _screenDestinationRect!.height * scaleDelta,
    );
    bool fixed = false;
    for (final Offset element in rectVertices) {
      if (rect.containsOffset(element)) {
        continue;
      }
      // find nearest point on rect
      final double nearestX = element.dx.clamp(rect.left, rect.right);
      final double nearestY = element.dy.clamp(rect.top, rect.bottom);

      final Offset nearestOffset = Offset(nearestX, nearestY);

      if (nearestOffset != element) {
        fixed = true;
        rect = rect.shift(-(nearestOffset - element));
      }
    }

    for (final Offset element in rectVertices) {
      if (!rect.containsOffset(element)) {
        return;
      }
    }
    if (fixed == true) {
      _screenDestinationRect = rect;
      // scale has already apply
      preTotalScale = totalScale;
    }

    this.totalScale = totalScale;
  }

  Rect updateCropRect(Rect cropRect) {
    Rect screenCropRect = cropRect.shift(layoutTopLeft!);
    final Matrix4 result = getTransform();
    final Rect rect = _screenDestinationRect!;
    result.invert();
    final List<Offset> rectVertices =
        <Offset>[
          screenCropRect.topLeft,
          screenCropRect.topRight,
          screenCropRect.bottomRight,
          screenCropRect.bottomLeft,
        ].map((Offset element) {
          final Vector4 cornerVector = Vector4(
            element.dx,
            element.dy,
            0.0,
            1.0,
          );
          final Vector4 newCornerVector = result.transform(cornerVector);
          return Offset(newCornerVector.x, newCornerVector.y);
        }).toList();

    final List<Offset> list = rectVertices.toList();
    bool hasOffsetOutSide = false;
    for (int i = 0; i < rectVertices.length; i++) {
      final Offset element = rectVertices[i];
      if (rect.containsOffset(element)) {
        continue;
      }
      late final Offset other = rectVertices[(i + 2) % 4];

      final Offset center = (element + other) / 2;

      final List<Offset> lineRectIntersections = getLineRectIntersections(
        _screenDestinationRect!,
        element,
        center,
      );
      if (lineRectIntersections.isNotEmpty) {
        hasOffsetOutSide = true;
        list[i] = lineRectIntersections.first;
      }
    }

    if (hasOffsetOutSide) {
      result.invert();
      final List<Offset> newOffsets =
          list.map((Offset element) {
            final Vector4 cornerVector = Vector4(
              element.dx,
              element.dy,
              0.0,
              1.0,
            );
            final Vector4 newCornerVector = result.transform(cornerVector);
            return Offset(newCornerVector.x, newCornerVector.y);
          }).toList();

      final Rect rect1 = Rect.fromPoints(newOffsets[0], newOffsets[2]);

      final Rect rect2 = Rect.fromPoints(newOffsets[1], newOffsets[3]);

      if (rect1.size < rect2.size) {
        screenCropRect = rect1;
      } else {
        screenCropRect = rect2;
      }
    }

    return screenCropRect.shift(-layoutTopLeft!);
  }

  Offset? getIntersection(Offset p1, Offset p2, Offset p3, Offset p4) {
    final double s1X = p2.dx - p1.dx;
    final double s1Y = p2.dy - p1.dy;
    final double s2X = p4.dx - p3.dx;
    final double s2Y = p4.dy - p3.dy;

    final double s =
        (-s1Y * (p1.dx - p3.dx) + s1X * (p1.dy - p3.dy)) /
        (-s2X * s1Y + s1X * s2Y);
    final double t =
        (s2X * (p1.dy - p3.dy) - s2Y * (p1.dx - p3.dx)) /
        (-s2X * s1Y + s1X * s2Y);

    if (s >= 0 && s <= 1 && t >= 0 && t <= 1) {
      final double intersectionX = p1.dx + (t * s1X);
      final double intersectionY = p1.dy + (t * s1Y);
      return Offset(intersectionX, intersectionY);
    }

    return null;
  }

  List<Offset> getLineRectIntersections(Rect rect, Offset p1, Offset p2) {
    final List<Offset> intersections = <Offset>[];

    final Offset topLeft = Offset(rect.left, rect.top);
    final Offset topRight = Offset(rect.right, rect.top);
    final Offset bottomLeft = Offset(rect.left, rect.bottom);
    final Offset bottomRight = Offset(rect.right, rect.bottom);

    final Offset? topIntersection = getIntersection(p1, p2, topLeft, topRight);
    if (topIntersection != null) {
      intersections.add(topIntersection);
    }

    final Offset? bottomIntersection = getIntersection(
      p1,
      p2,
      bottomLeft,
      bottomRight,
    );
    if (bottomIntersection != null) {
      intersections.add(bottomIntersection);
    }

    final Offset? leftIntersection = getIntersection(
      p1,
      p2,
      topLeft,
      bottomLeft,
    );
    if (leftIntersection != null) {
      intersections.add(leftIntersection);
    }

    final Offset? rightIntersection = getIntersection(
      p1,
      p2,
      topRight,
      bottomRight,
    );
    if (rightIntersection != null) {
      intersections.add(rightIntersection);
    }

    return intersections;
  }

  ///  The copyWith method allows you to create a modified copy of an instance.
  EditActionDetails copyWith({
    Rect? layoutRect,
    Rect? screenDestinationRect,
    Rect? rawDestinationRect,
    double? totalScale,
    double? preTotalScale,
    Offset? delta,
    Offset? screenFocalPoint,
    EdgeInsets? cropRectPadding,
    Rect? cropRect,
    double? originalAspectRatio,
    double? cropAspectRatio,
    double? rotateRadians,
    double? rotationYRadians,
    List<Offset>? perspectiveOffsets,
    List<Offset>? meshWarpOffsets,
  }) {
    return EditActionDetails()
      .._layoutRect = layoutRect ?? _layoutRect
      .._screenDestinationRect = screenDestinationRect ?? _screenDestinationRect
      .._rawDestinationRect = rawDestinationRect ?? _rawDestinationRect
      ..totalScale = totalScale ?? this.totalScale
      ..preTotalScale = preTotalScale ?? this.preTotalScale
      ..delta = delta ?? this.delta
      ..screenFocalPoint = screenFocalPoint ?? this.screenFocalPoint
      ..cropRectPadding = cropRectPadding ?? this.cropRectPadding
      ..cropRect = cropRect ?? this.cropRect
      ..originalAspectRatio = originalAspectRatio ?? this.originalAspectRatio
      ..cropAspectRatio = cropAspectRatio ?? _cropAspectRatio
      ..rotateRadians = rotateRadians ?? this.rotateRadians
      ..rotationYRadians = rotationYRadians ?? this.rotationYRadians
      ..perspectiveOffsets = perspectiveOffsets == null
          ? this.perspectiveOffsets == null
              ? null
              : List<Offset>.of(this.perspectiveOffsets!)
          : List<Offset>.of(perspectiveOffsets)
      ..meshWarpOffsets = meshWarpOffsets == null
          ? this.meshWarpOffsets == null
              ? null
              : List<Offset>.of(this.meshWarpOffsets!)
          : List<Offset>.of(meshWarpOffsets)
      ..config = config;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }

    return other is EditActionDetails &&
        _layoutRect.isSame(other._layoutRect) &&
        _screenDestinationRect.isSame(other._screenDestinationRect) &&
        _rawDestinationRect.isSame(other._rawDestinationRect) &&
        totalScale.equalTo(other.totalScale) &&
        preTotalScale.equalTo(other.preTotalScale) &&
        delta.isSame(other.delta) &&
        // screenFocalPoint == other.screenFocalPoint &&
        cropRectPadding == other.cropRectPadding &&
        cropRect.isSame(other.cropRect) &&
        originalAspectRatio.equalTo(other.originalAspectRatio) &&
        cropAspectRatio.equalTo(other.cropAspectRatio) &&
        rotateRadians.equalTo(other.rotateRadians) &&
        rotationYRadians.equalTo(other.rotationYRadians) &&
        _offsetListIsSame(perspectiveOffsets, other.perspectiveOffsets) &&
        _offsetListIsSame(meshWarpOffsets, other.meshWarpOffsets);
  }

  bool _offsetListIsSame(List<Offset>? a, List<Offset>? b) {
    if (a == null || b == null) {
      return a == b;
    }
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (!a[i].isSame(b[i])) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode {
    return _layoutRect.hashCode ^
        _screenDestinationRect.hashCode ^
        _rawDestinationRect.hashCode ^
        totalScale.hashCode ^
        preTotalScale.hashCode ^
        delta.hashCode ^
        // screenFocalPoint.hashCode ^
        cropRectPadding.hashCode ^
        cropRect.hashCode ^
        originalAspectRatio.hashCode ^
        cropAspectRatio.hashCode ^
        rotateRadians.hashCode ^
        rotationYRadians.hashCode ^
        Object.hashAll(perspectiveOffsets ?? <Offset>[]) ^
        Object.hashAll(meshWarpOffsets ?? <Offset>[]);
  }
}
