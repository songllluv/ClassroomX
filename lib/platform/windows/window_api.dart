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

      // 为窗口标题分配临时内存。
      using((arena) {
        final buffer = arena.pwstrBuffer(length + 1);

        final result = GetWindowText(hwnd, buffer, length + 1);

        if (result.value > 0) {
          windows.add(
            WindowInfo(handle: hWnd.address, title: buffer.toDartString()),
          );
        }
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
