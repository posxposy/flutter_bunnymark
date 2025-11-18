import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bunnymark/assets.dart';
import 'package:flutter_bunnymark/bunny.dart';
import 'package:flutter_bunnymark/core/application.dart';
import 'package:flutter_bunnymark/core/core.dart';

final class Bunnymark extends Application {
  static const coordsPerVertex = 2;
  static const verticesPerQuadWithIndices = 4;
  static const indicesPerQuad = 6;
  static const maxVertices = 65535;
  static const bunniesPerBatch = maxVertices ~/ verticesPerQuadWithIndices;
  static const double gravity = 0.5;

  late final Float32List _positions;
  late final Float32List _textureCoordinates;
  late final Uint16List _indices;
  late final math.Random _random;
  late final CoreView _view;
  late final Paint _paint;

  final _paragraphStyle = ParagraphStyle(
    fontSize: 14.0,
    textAlign: TextAlign.left,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.normal,
    height: 1.5,
  );

  final List<Bunny> _bunnies = [];

  ImageAsset? _asset;

  double _maxX = 0.0;
  double _maxY = 0.0;
  double _marginX = 0.0;
  double _marginY = 0.0;
  double _touchX = 0.0;
  double _touchY = 0.0;
  bool _isTouching = false;
  double _pixelRatio = 1.0;

  @override
  Future<void> initialize({required CoreView view}) async {
    _view = view;
    _pixelRatio = view.display.devicePixelRatio;
    _positions = Float32List(bunniesPerBatch * verticesPerQuadWithIndices * coordsPerVertex);
    _textureCoordinates = Float32List(bunniesPerBatch * verticesPerQuadWithIndices * coordsPerVertex);
    _indices = Uint16List(bunniesPerBatch * indicesPerQuad);
    _paint = Paint();

    _prefillIndices();

    _random = math.Random();
    _bunnies.clear();

    _maxX = view.bounds.width;
    _maxY = view.bounds.height;

    final bytes = await Assets.getByPath('assets/images/wabbit_alpha.png');
    decodeImageFromList(
      bytes,
      (result) {
        _marginX = result.width / 2.0;
        _marginY = result.height / 2.0;

        _asset = ImageAsset(
          result,
          ImageShader(result, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage),
        );

        _prefillTextureCoordinates(result.width.toDouble(), result.height.toDouble());
      },
    );
  }

  @override
  void onResize(Size size) {
    _maxX = size.width;
    _maxY = size.height;
  }

  @override
  void onKeyEvent(KeyEvent event) {
    final isDesktop = kIsWeb || (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
    if (isDesktop && event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.escape) {
        exit(0);
      }
    }
  }

  @override
  void onPointer(PointerData data) {
    _touchX = data.physicalX / _pixelRatio;
    _touchY = data.physicalY / _pixelRatio;
    if (data.change == PointerChange.down) {
      _isTouching = true;
    } else if (data.change == PointerChange.up) {
      _isTouching = false;
    }
  }

  @override
  void onUpdate(Duration dt) {
    const minX = 0.0;
    const minY = 0.0;
    final count = _bunnies.length;

    for (int i = 0; i < count; i++) {
      final bunny = _bunnies[i];
      bunny.x += bunny.speedX;
      bunny.y += bunny.speedY;
      bunny.speedY += gravity;

      if (bunny.x > _maxX - _marginX) {
        bunny.speedX *= -1;
        bunny.x = _maxX - _marginX;
      } else if (bunny.x < minX + _marginX) {
        bunny.speedX *= -1;
        bunny.x = minX + _marginX;
      }
      if (bunny.y > _maxY - _marginY) {
        bunny.speedY *= -0.6;
        bunny.y = _maxY - _marginY;
        final rnd = _random.nextDouble();
        if (rnd > 0.5) {
          bunny.speedY -= 3 + rnd * 4;
        }
      } else if (bunny.y < minY + _marginY) {
        bunny.speedY = 0;
        bunny.y = minY + _marginY;
      }
    }

    if (_isTouching) {
      _bunnies.addAll(
        Iterable<Bunny>.generate(
          kIsWeb || (Platform.isLinux || Platform.isWindows || Platform.isMacOS) ? 250 : 25,
          (_) => Bunny(
            x: _touchX,
            y: _touchY,
            speedX: _random.nextDouble() * 5,
            speedY: _random.nextDouble() * 5 - 2.5,
          ),
        ),
      );
    }
  }

  @override
  void onFrame(Frame frame) {
    final canvas = frame.canvas;
    final size = frame.size;
    final paint = _paint;
    paint.shader = null;

    paint.color = const Color.fromARGB(255, 10, 130, 125);
    canvas.drawRect(Offset.zero & size, paint);

    final asset = _asset;
    if (asset != null) {
      final hw = asset.image.width / 2.0;
      final hh = asset.image.height / 2.0;

      paint
        ..shader = asset.shader
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none;

      final batches = (_bunnies.length / bunniesPerBatch).ceil();

      for (int i = 0; i < batches; i++) {
        final start = i * bunniesPerBatch;
        final count = math.min(bunniesPerBatch, _bunnies.length - start);

        _fillBuffers(count, start, hw, hh);

        final usedFloats = count * verticesPerQuadWithIndices * coordsPerVertex;
        final usedIndices = count * indicesPerQuad;

        final positionsView = Float32List.sublistView(_positions, 0, usedFloats);
        final texCoordsView = Float32List.sublistView(_textureCoordinates, 0, usedFloats);
        final indicesView = Uint16List.sublistView(_indices, 0, usedIndices);

        final vertices = Vertices.raw(
          VertexMode.triangles,
          positionsView,
          indices: indicesView,
          textureCoordinates: texCoordsView,
        );
        canvas.drawVertices(vertices, BlendMode.srcOver, paint);
      }
    }

    final rate = _view.display.refreshRate;
    final ratio = _view.display.devicePixelRatio;
    final stats = frame.frameStats;
    final textColor = const Color(0xFFFFFFFF);

    final paragraphBuilder = ParagraphBuilder(_paragraphStyle);
    paragraphBuilder.pushStyle(TextStyle(fontWeight: FontWeight.normal, fontSize: 14.0, color: textColor));
    paragraphBuilder.addText(
      'fps: ${frame.fps}'
      '\nwindow: ${_view.bounds.width.toInt()}x${_view.bounds.height.toInt()}'
      '\ndisplay: ${(_view.display.size.width / ratio).toInt()}x${(_view.display.size.height / ratio).toInt()}'
      ' (~${rate.toStringAsFixed(0)}Hz)',
    );
    paragraphBuilder.pop();

    paragraphBuilder.pushStyle(TextStyle(fontWeight: FontWeight.bold, fontSize: 18.0, color: textColor));
    paragraphBuilder.addText('\nbunnies: ${_bunnies.length}');
    paragraphBuilder.pop();

    paragraphBuilder.pushStyle(TextStyle(fontWeight: FontWeight.normal, fontSize: 12.0, color: textColor));
    paragraphBuilder.addText(
      '\n\nFrame Time (ms):'
      '\n  avg: ${stats.avgFrameTime.toStringAsFixed(2)}'
      '\n  max: ${stats.maxFrameTime.toStringAsFixed(2)}'
      '\n  target: ${(1000.0 / rate).toStringAsFixed(2)} (${rate.toInt()}fps)',
    );
    paragraphBuilder.pop();

    final paragraph = paragraphBuilder.build();
    paragraph.layout(ParagraphConstraints(width: size.width));

    canvas.drawParagraph(
      paragraph,
      const Offset(10.0, 10.0),
    );
    paragraph.dispose();
  }

  void _fillBuffers(int count, int start, double hw, double hh) {
    for (int j = 0; j < count; j++) {
      final bunny = _bunnies[j + start];
      final x = bunny.x;
      final y = bunny.y;
      final vertexOffset = j * verticesPerQuadWithIndices * coordsPerVertex;

      _positions[vertexOffset + 0] = -hw + x;
      _positions[vertexOffset + 1] = -hh + y;
      _positions[vertexOffset + 2] = hw + x;
      _positions[vertexOffset + 3] = -hh + y;
      _positions[vertexOffset + 4] = hw + x;
      _positions[vertexOffset + 5] = hh + y;
      _positions[vertexOffset + 6] = -hw + x;
      _positions[vertexOffset + 7] = hh + y;
    }
  }

  void _prefillIndices() {
    for (int j = 0; j < bunniesPerBatch; j++) {
      final indexOffset = j * indicesPerQuad;
      final baseIndex = j * verticesPerQuadWithIndices;
      _indices[indexOffset + 0] = baseIndex + 0;
      _indices[indexOffset + 1] = baseIndex + 1;
      _indices[indexOffset + 2] = baseIndex + 2;
      _indices[indexOffset + 3] = baseIndex + 0;
      _indices[indexOffset + 4] = baseIndex + 2;
      _indices[indexOffset + 5] = baseIndex + 3;
    }
  }

  void _prefillTextureCoordinates(double w, double h) {
    for (int j = 0; j < bunniesPerBatch; j++) {
      final vertexOffset = j * verticesPerQuadWithIndices * coordsPerVertex;
      _textureCoordinates[vertexOffset + 0] = 0.0;
      _textureCoordinates[vertexOffset + 1] = 0.0;
      _textureCoordinates[vertexOffset + 2] = w;
      _textureCoordinates[vertexOffset + 3] = 0.0;
      _textureCoordinates[vertexOffset + 4] = w;
      _textureCoordinates[vertexOffset + 5] = h;
      _textureCoordinates[vertexOffset + 6] = 0.0;
      _textureCoordinates[vertexOffset + 7] = h;
    }
  }
}

final class ImageAsset {
  final Image image;
  final ImageShader shader;

  const ImageAsset(this.image, this.shader);
}
