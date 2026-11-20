/// 这个类只保存数据，不负责调用 Windows API。
class WindowInfo {
  const WindowInfo({
    required this.handle,
    required this.title,
    required this.processId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.isMinimized,
    required this.isMaximized,
  });

  /// 窗口句柄。使用 int 保存，避免 UI 层依赖 win32 包。
  final int handle;

  /// 窗口标题。
  final String title;

  /// 所属进程的 PID。
  final int processId;

  /// 窗口外框左上角坐标（屏幕坐标）。
  final int x;
  final int y;

  /// 窗口外框尺寸。
  final int width;
  final int height;

  /// 是否最小化。
  final bool isMinimized;

  /// 是否最大化。
  final bool isMaximized;

  /// 用于界面显示的句柄文本。
  String get handleText =>
      '0x${handle.toRadixString(16).toUpperCase()}';
}
