import 'demo_mode_storage.dart';

DemoModeStorage createDemoModeStorage() => _UnavailableStorage();

class _UnavailableStorage implements DemoModeStorage {
  @override
  String? read() => null;
  @override
  void write(String value) => throw UnsupportedError('Browser storage is unavailable');
  @override
  void remove() {}
}
