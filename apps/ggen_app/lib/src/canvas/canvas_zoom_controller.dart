import 'package:flutter/foundation.dart';

/// Commands that the shell can send to the canvas zoom controller.
enum CanvasZoomCommand { zoomIn, zoomOut, fitToScreen }

/// A simple command channel between the shell and the canvas for zoom
/// operations. The shell fires commands; the canvas listens and executes.
///
/// This avoids coupling the shell to the canvas state type (which is
/// library-private) while keeping zoom as viewport state that does not
/// belong in the project controller.
class CanvasZoomController extends ChangeNotifier {
  CanvasZoomCommand? _pending;

  /// The most recently fired command, consumed by the canvas on build.
  CanvasZoomCommand? consumeCommand() {
    final cmd = _pending;
    _pending = null;
    return cmd;
  }

  void zoomIn() {
    _pending = CanvasZoomCommand.zoomIn;
    notifyListeners();
  }

  void zoomOut() {
    _pending = CanvasZoomCommand.zoomOut;
    notifyListeners();
  }

  void fitToScreen() {
    _pending = CanvasZoomCommand.fitToScreen;
    notifyListeners();
  }
}
