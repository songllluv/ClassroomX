/// 这个类只保存数据，不负责调用 Windows API。
class WindowInfo {
  const WindowInfo({
    required this.handle,
    required this.title,
  });

  /// 窗口句柄。
  ///
  /// 使用 int 保存 HWND 的地址，避免 UI 层依赖 win32 包。
  final int handle;

  /// 窗口标题。
  final String title;

  /// 用于界面显示的句柄文本。
  String get handleText =>
      '0x${handle.toRadixString(16).toUpperCase()}';
}