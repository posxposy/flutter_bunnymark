import 'dart:collection';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bunnymark/core/application.dart';

final class Core extends BindingBase with SchedulerBinding, ServicesBinding {
  static Core? _instance;
  static Core ensure({required Application game}) {
    final i = _instance ??= Core._(game: game);
    return i;
  }

  final Application _app;

  late final ui.FlutterView _view;
  late final Float64List _deviceTransform;

  bool _appInitialized;

  Duration _lastTimestamp;
  Duration _lastFrameTimestamp;
  Duration _elapsedTime;
  int _totalFrames;
  int _fps;

  final Queue<double> _frameTimesMs;
  late final int _maxFrameTimeSamples;
  double _maxFrameTime;
  double _avgFrameTime;

  Core._({required Application game})
    : _app = game,
      _appInitialized = false,
      _lastTimestamp = Duration.zero,
      _lastFrameTimestamp = Duration.zero,
      _elapsedTime = Duration.zero,
      _totalFrames = 0,
      _fps = 0,
      _frameTimesMs = Queue<double>(),
      _maxFrameTime = 0.0,
      _avgFrameTime = 0.0 {
    final view = ui.PlatformDispatcher.instance.implicitView;
    if (view == null) {
      throw FlutterError('No implicit FlutterView available on PlatformDispatcher.');
    }

    _view = view;
    _maxFrameTimeSamples = (view.display.refreshRate * 2).ceil();

    _deviceTransform = Float64List(16)
      ..[0] = _view.devicePixelRatio
      ..[5] = _view.devicePixelRatio
      ..[10] = 1.0
      ..[15] = 1.0;

    ui.PlatformDispatcher.instance.onPointerDataPacket = _onPointerDataPacket;
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
    addPersistentFrameCallback(_onFrame);

    ui.PlatformDispatcher.instance.requestDartPerformanceMode(.latency);
    ui.PlatformDispatcher.instance.onMetricsChanged = () {
      if (_appInitialized) {
        _app.onResize(view.physicalSize / view.devicePixelRatio);
      }
    };

    final core = CoreView(view);
    _app.initialize(view: core).then((_) => _appInitialized = true);

    scheduleFrame();
  }

  void _onPointerDataPacket(ui.PointerDataPacket packet) {
    if (_appInitialized) {
      for (final data in packet.data) {
        _app.onPointer(data);
      }
    }
  }

  bool _onKeyEvent(KeyEvent event) {
    if (_appInitialized) {
      _app.onKeyEvent(event);
      return true;
    }
    return false;
  }

  void _onFrame(Duration timestamp) {
    if (_lastFrameTimestamp != Duration.zero) {
      final frameToFrameTime = (timestamp - _lastFrameTimestamp).inMicroseconds / 1000.0;
      _recordFrameTime(frameToFrameTime);
    }
    _lastFrameTimestamp = timestamp;

    if (_lastTimestamp == Duration.zero) {
      _lastTimestamp = timestamp;
      scheduleFrame();
      return;
    }

    final delta = timestamp - _lastTimestamp;
    _lastTimestamp = timestamp;

    _elapsedTime += delta;
    _totalFrames += 1;

    _app.onUpdate(delta);

    final bounds = ui.Offset.zero & (_view.physicalSize / _view.devicePixelRatio);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, bounds);
    final size = bounds.size;

    _app.onFrame(
      Frame(
        canvas: canvas,
        size: size,
        fps: _fps,
        frameStats: FrameStats(
          maxFrameTime: _maxFrameTime,
          avgFrameTime: _avgFrameTime,
        ),
      ),
    );

    final picture = recorder.endRecording();
    final builder = ui.SceneBuilder();

    builder.pushTransform(_deviceTransform);
    builder.pushClipRect(bounds);
    builder.addPicture(ui.Offset.zero, picture);
    builder.pop();
    builder.pop();

    _view.render(builder.build());

    if (_elapsedTime.inMilliseconds >= 1000) {
      final seconds = _elapsedTime.inMicroseconds / 1e6;
      _fps = (_totalFrames / seconds).round();
      _totalFrames = 0;
      _elapsedTime = Duration.zero;
    }

    scheduleFrame();
  }

  void _recordFrameTime(double frameTimeMs) {
    _frameTimesMs.add(frameTimeMs);

    if (_frameTimesMs.length > _maxFrameTimeSamples) {
      _frameTimesMs.removeFirst();
    }

    if (frameTimeMs > _maxFrameTime) _maxFrameTime = frameTimeMs;

    if (_frameTimesMs.isNotEmpty) {
      _avgFrameTime = _frameTimesMs.reduce((a, b) => a + b) / _frameTimesMs.length;
    }
  }
}

extension type CoreView(ui.FlutterView view) {
  ui.Rect get bounds => ui.Offset.zero & (view.physicalSize / view.devicePixelRatio);
  ui.Display get display => view.display;
}

final class Frame {
  final ui.Canvas canvas;
  final ui.Size size;
  final int fps;
  final FrameStats frameStats;

  Frame({
    required this.canvas,
    required this.size,
    required this.fps,
    required this.frameStats,
  });
}

final class FrameStats {
  final double maxFrameTime;
  final double avgFrameTime;

  const FrameStats({
    required this.maxFrameTime,
    required this.avgFrameTime,
  });
}
