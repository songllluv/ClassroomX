 
#include "flutter_window.h"

#include <optional>
#include <string>
#include <utility>
#include <cstdint>
#include <variant>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Hotkey IDs carried by WM_HOTKEY.
constexpr int kHotkeyIncrease = 1;
constexpr int kHotkeyDecrease = 2;
constexpr int kHotkeyResetOpacity = 3;

// All shortcuts use Ctrl + Alt.
constexpr UINT kHotkeyModifiers = MOD_CONTROL | MOD_ALT;

// Protection overlay refresh interval.
constexpr UINT_PTR kOverlayTimerId = 0xCA11;
constexpr UINT kOverlayRefreshIntervalMs = 100;

// Convert an integer received from Dart into a native HWND.
bool TryGetWindowHandle(
    const flutter::EncodableValue* value,
    HWND* window) {
  if (value == nullptr || window == nullptr) {
    return false;
  }

  int64_t raw_handle = 0;

  if (const auto* value32 = std::get_if<int32_t>(value)) {
    raw_handle = *value32;
  } else if (const auto* value64 = std::get_if<int64_t>(value)) {
    raw_handle = *value64;
  } else {
    return false;
  }

  if (raw_handle <= 0) {
    return false;
  }

  *window = reinterpret_cast<HWND>(
      static_cast<uintptr_t>(raw_handle));
  return true;
}

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

  // Create the global hotkey channel.
  hotkey_channel_ =
      std::make_unique<
          flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "classroomx/hotkeys",
          &flutter::StandardMethodCodec::GetInstance());

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

  // Create the protection overlay channel.
  protection_channel_ =
      std::make_unique<
          flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "classroomx/protection",
          &flutter::StandardMethodCodec::GetInstance());

  protection_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<
                 flutter::MethodResult<flutter::EncodableValue>> result) {
        HWND target = nullptr;

        if (!TryGetWindowHandle(call.arguments(), &target)) {
          result->Error(
              "INVALID_WINDOW_HANDLE",
              "Expected a valid native window handle.");
          return;
        }

        if (call.method_name() == "addOverlay") {
          const bool added = overlay_manager_.Add(target);
          result->Success(flutter::EncodableValue(added));
          return;
        }

        if (call.method_name() == "removeOverlay") {
          overlay_manager_.Remove(target);
          result->Success(flutter::EncodableValue(true));
          return;
        }

        result->NotImplemented();
      });

  // Keep overlays aligned with their target windows.
  SetTimer(
      GetHandle(),
      kOverlayTimerId,
      kOverlayRefreshIntervalMs,
      nullptr);

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  flutter_controller_->ForceRedraw();

  return true;
}

bool FlutterWindow::RegisterHotkeys() {
  // Do not register the same hotkeys twice.
  if (registered_hotkey_ids_.size() == 3) {
    return true;
  }

  // Roll back any partially registered state.
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
    if (!RegisterHotKey(
            GetHandle(), hotkey.id, kHotkeyModifiers, hotkey.key)) {
      last_hotkey_error_ = GetLastError();
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
  // Stop the overlay timer before destroying overlay windows.
  KillTimer(GetHandle(), kOverlayTimerId);
  overlay_manager_.Clear();
  protection_channel_.reset();

  // Unregister all global hotkeys before destroying the main window.
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

  if (message == WM_HOTKEY) {
    DispatchHotkey(static_cast<int>(wparam));
    return 0;
  }

  if (message == WM_TIMER &&
      wparam == kOverlayTimerId) {
    overlay_manager_.UpdateAll();
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
