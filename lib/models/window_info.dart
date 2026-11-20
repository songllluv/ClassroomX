
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
  final String title;

  /// 用于界面显示的句柄文本。
  String get handleText =>
      '0x${handle.toRadixString(16).toUpperCase()}';
}
