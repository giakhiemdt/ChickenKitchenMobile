import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';

class DeepLinkService {
  static const _method = MethodChannel('com.example.mobiletest/deep_links/methods');
  static const _events = EventChannel('com.example.mobiletest/deep_links/events');

  static Stream<String?>? _stream;

  static Stream<String?> linkStream() {
    _stream ??= _events.receiveBroadcastStream().map<String?>((event) {
      if (event == null) return null;
      return event.toString();
    });
    return _stream!;
  }

  static Future<String?> getInitialLink() async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _method.invokeMethod<String>('getInitialLink');
      return result;
    } on PlatformException {
      return null;
    }
  }
}

