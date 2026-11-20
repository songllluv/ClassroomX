import '../models/window_info.dart';
import '../platform/windows/window_api.dart';

/// 窗口管理服务。
///
/// UI 应当调用这个类，而不是直接调用 WindowApi。
class WindowService {
  WindowService({WindowApi? api}) : _api = api ?? WindowApi();

  final WindowApi _api;

  /// 获取窗口列表。
  List<WindowInfo> enumerateWindows() {
    return _api.enumerateWindows();
  }
}
