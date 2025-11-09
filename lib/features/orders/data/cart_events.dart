import 'dart:async';

class CartEvents {
  static final StreamController<void> _controller = StreamController<void>.broadcast();

  static Stream<void> get stream => _controller.stream;

  static void notifyChanged() {
    try {
      _controller.add(null);
    } catch (_) {}
  }
}

