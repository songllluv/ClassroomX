import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

import '../../models/window_info.dart';

/// Windows 窗口 API 封装。
///
/// 这里只处理 Windows API，不包含任何 UI 代码。
class WindowApi {
  /// 获取当前所有可见且具有标题的顶层窗口。
  List<WindowInfo> enumerateWindows() {
    final windows = <WindowInfo>[];

    // EnumWindows 要求传入一个原生回调函数。
    // isolateLocal 表示该回调在当前 Dart isolate 中执行。
    final callback = NativeCallable<WNDENUMPROC>.isolateLocal((
      Pointer hWnd,
      int lParam,
    ) {
      final hwnd = HWND(hWnd);

      // 忽略不可见窗口。
      if (!IsWindowVisible(hwnd)) {
        return TRUE;
      }

      // 获取标题长度。
      final length = GetWindowTextLength(hwnd).value;

      // 忽略没有标题的窗口。
      if (length <= 0) {
        return TRUE;
      }

      using((arena) {
        // 获取窗口标题。
        final titleBuffer = arena.pwstrBuffer(length + 1);
        final titleLength = GetWindowText(hwnd, titleBuffer, length + 1);

        if (titleLength.value <= 0) {
          return;
        }

        // 获取所属进程 PID。
        final processIdPointer = arena<Uint32>();
        GetWindowThreadProcessId(hwnd, processIdPointer);
        final processId = processIdPointer.value;

        // 获取窗口外框坐标和尺寸。
        final rectPointer = arena<RECT>();
        final rectResult = GetWindowRect(hwnd, rectPointer);

        var x = 0;
        var y = 0;
        var width = 0;
        var height = 0;

        if (rectResult.value != 0) {
          final rect = rectPointer.ref;
          x = rect.left;
          y = rect.top;
          width = rect.right - rect.left;
          height = rect.bottom - rect.top;
        }

        windows.add(
          WindowInfo(
            handle: hWnd.address,
            title: titleBuffer.toDartString(),
            processId: processId,
            x: x,
            y: y,
            width: width,
            height: height,
            isMinimized: IsIconic(hwnd).value != 0,
            isMaximized: IsZoomed(hwnd).value != 0,
          ),
        );
      });

      // TRUE 表示继续枚举下一个窗口。
      return TRUE;
    }, exceptionalReturn: 0);

    try {
      EnumWindows(callback.nativeFunction, LPARAM(0));
    } finally {
      callback.close();
    }

    return windows;
  }
}
