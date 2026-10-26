/// Storage is deliberately limited to one non-secret UI-mode marker.
abstract interface class DemoModeStorage {
  String? read();
  void write(String value);
  void remove();
}

/// Browser lifecycle notifications, not persistent state or authentication.
abstract interface class DemoModeEvents {
  void Function() watch(void Function() validate);
}

class DemoSession {
  DemoSession(this.storage);

  static const key = 'aiovy.demo-only-mode';
  static const marker = 'enabled-v1';
  final DemoModeStorage storage;

  bool get canRestore {
    try {
      return storage.read() == marker;
    } catch (_) {
      return false;
    }
  }

  // No credentials, user identity, route or assessment can be passed here.
  bool enable() {
    try {
      storage.write(marker);
      return canRestore;
    } catch (_) {
      return false;
    }
  }

  bool clear() {
    try {
      if (storage.read() == null) return true;
      // Invalidate before removing: an interrupted removal must not leave an
      // enabled marker. Neither value is a credential or an API token.
      storage.write('disabled');
      storage.remove();
      return storage.read() == null;
    } catch (_) {
      return false;
    }
  }
}
