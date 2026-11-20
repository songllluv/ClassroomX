import '../models/window_info.dart';
import '../models/window_style_backup.dart';
import '../platform/windows/window_api.dart';

class WindowService {
  WindowService({WindowApi? api}) : _api = api ?? WindowApi();

  final WindowApi _api;
  final Map<String, WindowStyleBackup> _backups = {};

  String _key(WindowInfo window) =>
      '${window.handle}:${window.processId}';

  List<WindowInfo> enumerateWindows() {
    return _api.enumerateWindows();
  }

  bool isModified(WindowInfo window) {
    return _backups.containsKey(_key(window));
  }

  /// opacityPercent 的范围是 0～100。
  void setOpacity(WindowInfo window, int opacityPercent) {
    if (opacityPercent < 0 || opacityPercent > 100) {
      throw RangeError.range(opacityPercent, 0, 100);
    }

    final key = _key(window);
    final isFirstChange = !_backups.containsKey(key);

    if (isFirstChange) {
      _backups[key] = _api.captureWindowStyle(
        handle: window.handle,
        processId: window.processId,
      );
    }

    final alpha = (opacityPercent * 255 + 50) ~/ 100;

    try {
      _api.setWindowOpacity(window.handle, alpha);
    } catch (_) {
      if (isFirstChange) {
        _backups.remove(key);
      }
      rethrow;
    }
  }

  /// 恢复该窗口第一次修改前的状态。
  void restore(WindowInfo window) {
    final key = _key(window);
    final backup = _backups[key];

    if (backup == null) return;

    _api.restoreWindowStyle(backup);
    _backups.remove(key);
  }

  /// 尝试恢复所有仍有备份的窗口。
  /// 返回恢复失败的数量。
  int restoreAll() {
    var failed = 0;

    for (final entry in _backups.entries.toList()) {
      try {
        _api.restoreWindowStyle(entry.value);
        _backups.remove(entry.key);
      } catch (_) {
        failed++;
      }
    }

    return failed;
  }
}