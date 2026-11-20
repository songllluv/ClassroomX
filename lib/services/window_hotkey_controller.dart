
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models/window_info.dart';
import 'window_service.dart';

class WindowHotkeyController extends ChangeNotifier {
  static const MethodChannel _channel =
      MethodChannel('classroomx/hotkeys');

  static const int _step = 5;

  final WindowService service = WindowService();
  final Map<String, int> _opacityValues = {};


  bool isRegistered = false;
  String? lastError;

  String _key(WindowInfo window) =>
      '${window.handle}:${window.processId}';

  int opacityFor(WindowInfo window) {
    return _opacityValues[_key(window)] ?? 100;
  }

  bool isModified(WindowInfo window) {
    return service.isModified(window);
  }

  String get statusText {
    if (lastError != null) return lastError!;
    return isRegistered ? '全局快捷键已启用' : '全局快捷键未启用';
  }

  Future<void> initialize() async {
    _channel.setMethodCallHandler(_handleNativeCall);

    try {
      await _channel.invokeMethod<void>('registerHotkeys');

      isRegistered = true;
      lastError = null;
    } on PlatformException catch (e) {
      isRegistered = false;
      lastError = '快捷键注册失败：${e.message ?? e.code}';
    } catch (e) {
      isRegistered = false;
      lastError = '快捷键初始化失败：$e';
    }

    notifyListeners();
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onHotkey') return;

    final args = call.arguments;

    if (args is! List ||
        args.length != 2 ||
        args[0] is! String ||
        args[1] is! int) {
      return;
    }

    _handleAction(args[0] as String, args[1] as int);
  }

  void selectTarget(WindowInfo window) {
    _opacityValues.putIfAbsent(_key(window), () => 100);
    lastError = null;
    notifyListeners();
  }

  void setOpacity(WindowInfo window, int value) {
    if (value < 0 || value > 100) {
      throw RangeError.range(value, 0, 100);
    }

    service.setOpacity(window, value);

    _opacityValues[_key(window)] = value;
    lastError = null;

    notifyListeners();
  }

  void restore(WindowInfo window) {
    service.restore(window);

    _opacityValues.remove(_key(window));

    lastError = null;
    notifyListeners();
  }

  void _handleAction(String action, int handle) {
    try {
      // Find the current foreground window in the latest snapshot.
      final windows = service.enumerateWindows();

      WindowInfo? window;

      for (final item in windows) {
        if (item.handle == handle) {
          window = item;
          break;
        }
      }

      if (window == null) {
        lastError = '无法获取当前前台窗口信息';
        notifyListeners();
        return;
      }

      final current = opacityFor(window);

      switch (action) {
        case 'increase':
          if (current < 100) {
            setOpacity(
              window,
              (current + _step).clamp(0, 100).toInt(),
            );
          }
          break;

        case 'decrease':
          if (current > 0) {
            setOpacity(
              window,
              (current - _step).clamp(0, 100).toInt(),
            );
          }
          break;

        case 'resetOpacity':
          setOpacity(window, 100);
          break;
      }
    } catch (e) {
      lastError = '快捷键操作失败：$e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _channel.setMethodCallHandler(null);

    if (isRegistered) {
      _channel.invokeMethod<void>('unregisterHotkeys').catchError((_) {});
    }

    super.dispose();
  }
}
