// bitsdojo_window
void doWhenWindowReady(void Function() callback) {}
class AppWindow {
  dynamic minSize;
  dynamic size;
  dynamic alignment;
  String title = '';
  void show() {}
  void restore() {}
}
final appWindow = AppWindow();

// win32_registry
class Registry {
  static final currentUser = _RegistryKey();
}
class _RegistryKey {
  _RegistryKey createKey(String path) => this;
  void createValue(dynamic value) {}
  void deleteValue(String name) {}
  void close() {}
}
class RegistryValue {
  RegistryValue(String name, dynamic type, dynamic value);
}
class RegistryValueType {
  static const string = 0;
}

// local_notifier
class LocalNotifier {
  Future<void> setup({required String appName, required dynamic shortcutPolicy}) async {}
}
final localNotifier = LocalNotifier();
class ShortcutPolicy {
  static const requireCreate = 0;
}
class LocalNotification {
  LocalNotification({required String title, required String body});
  dynamic onClick;
  Future<void> show() async {}
}
