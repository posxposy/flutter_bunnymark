import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_bunnymark/core/core.dart';

abstract class Application {
  Future<void> initialize({required CoreView view});

  void onPointer(ui.PointerData data) {}
  void onKeyEvent(KeyEvent event) {}
  void onUpdate(Duration dt) {}
  void onResize(ui.Size size) {}

  void onFrame(Frame frame);
}
