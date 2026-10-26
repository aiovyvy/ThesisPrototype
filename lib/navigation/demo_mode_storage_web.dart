import 'dart:js_interop';

import 'demo_mode_storage.dart';

@JS('window.sessionStorage')
external _SessionStorage get _storage;

@JS('window.addEventListener')
external void _listen(String event, JSFunction callback);
@JS('window.removeEventListener')
external void _unlisten(String event, JSFunction callback);

extension type _SessionStorage(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

DemoModeStorage createDemoModeStorage() => _BrowserDemoStorage();

class _BrowserDemoStorage implements DemoModeStorage, DemoModeEvents {
  @override
  void Function() watch(void Function() validate) {
    final callback = ((JSAny? _) {
      validate();
    }).toJS;
    _listen('pageshow', callback);
    _listen('focus', callback);
    return () {
      _unlisten('pageshow', callback);
      _unlisten('focus', callback);
    };
  }

  @override
  String? read() => _storage.getItem(DemoSession.key);
  @override
  void write(String value) => _storage.setItem(DemoSession.key, value);
  @override
  void remove() => _storage.removeItem(DemoSession.key);
}
