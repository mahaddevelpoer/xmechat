import 'dart:io';

import 'package:flutter/foundation.dart';
import '../utils/desktop.dart';

/// Windows desktop toast notifications wrapper (uses `local_notifier`).
class WindowsNotifier {
  static final WindowsNotifier instance = WindowsNotifier._();
  WindowsNotifier._();

  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    if (kIsWeb || !Platform.isWindows) return;

    await localNotifier.setup(
      appName: 'XmeChat',
      shortcutPolicy: ShortcutPolicy.requireCreate,
    );
    _ready = true;
  }

  bool get isReady => _ready;

  Future<void> show({
    required String title,
    required String body,
    VoidCallback? onClick,
  }) async {
    if (!_ready) return;
    final n = LocalNotification(title: title, body: body);
    if (onClick != null) n.onClick = onClick;
    await n.show();
  }
}

