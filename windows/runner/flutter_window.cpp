
#include "flutter_window.h"

#include <optional>
#include <string>
#include <utility>
#include <cstdint>

#include "flutter/generated_plugin_registrant.h"

namespace {

// 热键 ID。WM_HOTKEY 的 wParam 会携带对应 ID。
constexpr int kHotkeyIncrease = 1;
constexpr int kHotkeyDecrease = 2;
constexpr int kHotkeyResetOpacity = 3;

// 所有快捷键共用 Ctrl + Alt。
constexpr UINT kHotkeyModifiers =
    MOD_CONTROL | MOD_ALT;

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);

  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }

  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // 建立 Flutter MethodChannel。
  hotkey_channel_ =
      std::make_unique<
          flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "classroomx/hotkeys",
          &flutter::StandardMethodCodec::GetInstance());

  // 接收 Dart 发来的注册和注销请求。
  hotkey_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<
                 flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "registerHotkeys") {
          if (RegisterHotkeys()) {
            result->Success(flutter::EncodableValue());
          } else {
            result->Error(
                "HOTKEY_REGISTER_FAILED",
                "Failed to register global hotkeys. A shortcut may already be in use.",
                flutter::EncodableValue(
                    static_cast<int>(last_hotkey_error_)));
          }
          return;
        }

        if (call.method_name() == "unregisterHotkeys") {
          UnregisterHotkeys();
          result->Success(flutter::EncodableValue());
          return;
        }

        result->NotImplemented();
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

bool FlutterWindow::RegisterHotkeys() {
  // 已经全部注册成功时，不重复注册。
  if (registered_hotkey_ids_.size() == 4) {
    return true;
  }

  // 清理可能存在的部分注册状态。
  UnregisterHotkeys();

  struct HotkeyDefinition {
    int id;
    UINT key;
  };

  const HotkeyDefinition hotkeys[] = {
      {kHotkeyIncrease, VK_UP},
      {kHotkeyDecrease, VK_DOWN},
      {kHotkeyResetOpacity, '0'},
  };

  for (const auto& hotkey : hotkeys) {
    if (!RegisterHotKey(GetHandle(), hotkey.id,
                        kHotkeyModifiers, hotkey.key)) {
      last_hotkey_error_ = GetLastError();

      // 注册失败时回滚之前已经注册的快捷键。
      UnregisterHotkeys();
      return false;
    }

    registered_hotkey_ids_.push_back(hotkey.id);
  }

  last_hotkey_error_ = ERROR_SUCCESS;
  return true;
}

void FlutterWindow::UnregisterHotkeys() {
  for (const int id : registered_hotkey_ids_) {
    UnregisterHotKey(GetHandle(), id);
  }

  registered_hotkey_ids_.clear();
}

void FlutterWindow::DispatchHotkey(int hotkey_id) {
  if (!hotkey_channel_) {
    return;
  }

  const char* action = nullptr;

  switch (hotkey_id) {
    case kHotkeyIncrease:
      action = "increase";
      break;
    case kHotkeyDecrease:
      action = "decrease";
      break;
    case kHotkeyResetOpacity:
      action = "resetOpacity";
      break;
    default:
      return;
  }

  HWND foreground = GetForegroundWindow();
  if (foreground == nullptr) {
    return;
  }

  flutter::EncodableList arguments;
  arguments.emplace_back(action);
  arguments.emplace_back(
      static_cast<int64_t>(reinterpret_cast<intptr_t>(foreground)));

  hotkey_channel_->InvokeMethod(
      "onHotkey",
      std::make_unique<flutter::EncodableValue>(arguments));
}

void FlutterWindow::OnDestroy() {
  // 窗口销毁前注销所有全局快捷键。
  UnregisterHotkeys();

  hotkey_channel_.reset();

  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT FlutterWindow::MessageHandler(
    HWND hwnd,
    UINT const message,
    WPARAM const wparam,
    LPARAM const lparam) noexcept {

  // 优先处理全局快捷键消息。
  // 不将 WM_HOTKEY 交给 Flutter 或 Win32Window。
  if (message == WM_HOTKEY) {
    DispatchHotkey(static_cast<int>(wparam));
    return 0;
  }

  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(
            hwnd, message, wparam, lparam);

    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(
      hwnd, message, wparam, lparam);
}