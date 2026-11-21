#include "overlay_manager.h"

#include <algorithm>

namespace {

constexpr wchar_t kOverlayClassName[] =
    L"ClassroomX.ProtectionOverlay";

constexpr COLORREF kTransparentColor = RGB(0, 0, 0);
constexpr COLORREF kBorderColor = RGB(255, 220, 0);

} // namespace

OverlayManager::~OverlayManager() {
    Clear();
}

ATOM OverlayManager::RegisterWindowClass() {
    static ATOM atom = 0;

    if (atom != 0) {
        return atom;
    }

    WNDCLASSEXW wc{};
    wc.cbSize = sizeof(wc);
    wc.lpfnWndProc = OverlayManager::WindowProc;
    wc.hInstance = GetModuleHandleW(nullptr);
    wc.lpszClassName = kOverlayClassName;
    wc.hCursor = LoadCursorW(nullptr, IDC_ARROW);

    atom = RegisterClassExW(&wc);

    if (atom == 0 && GetLastError() == ERROR_CLASS_ALREADY_EXISTS) {
        atom = 1;
    }

    return atom;
}

bool OverlayManager::CreateOverlay(Overlay& overlay) {
    if (!RegisterWindowClass()) {
        return false;
    }

    const DWORD exStyle =
        WS_EX_LAYERED |
        WS_EX_TRANSPARENT |
        WS_EX_NOACTIVATE |
        WS_EX_TOOLWINDOW;

    overlay.window = CreateWindowExW(
        exStyle,
        kOverlayClassName,
        L"",
        WS_POPUP,
        0, 0, 1, 1,
        nullptr,
        nullptr,
        GetModuleHandleW(nullptr),
        &overlay
    );

    if (!overlay.window) {
        return false;
    }

    // Black pixels are transparent; the yellow border remains visible.
    if (!SetLayeredWindowAttributes(
            overlay.window,
            kTransparentColor,
            0,
            LWA_COLORKEY)) {
        DestroyWindow(overlay.window);
        overlay.window = nullptr;
        return false;
    }

    return true;
}

bool OverlayManager::Add(HWND target) {
    if (!IsWindow(target)) {
        return false;
    }

    if (overlays_.find(target) != overlays_.end()) {
        return true;
    }

    auto overlay = std::make_unique<Overlay>();
    overlay->target = target;

    if (!CreateOverlay(*overlay)) {
        return false;
    }

    HWND overlayWindow = overlay->window;
    overlays_.emplace(target, std::move(overlay));

    auto it = overlays_.find(target);
    UpdateOverlay(*it->second);

    return IsWindow(overlayWindow);
}

void OverlayManager::Remove(HWND target) {
    auto it = overlays_.find(target);

    if (it == overlays_.end()) {
        return;
    }

    if (IsWindow(it->second->window)) {
        DestroyWindow(it->second->window);
    }

    overlays_.erase(it);
}

void OverlayManager::Clear() {
    for (auto& entry : overlays_) {
        HWND hwnd = entry.second->window;

        if (IsWindow(hwnd)) {
            DestroyWindow(hwnd);
        }
    }

    overlays_.clear();
}

void OverlayManager::UpdateAll() {
    for (auto it = overlays_.begin(); it != overlays_.end();) {
        Overlay& overlay = *it->second;

        if (!IsWindow(overlay.target) ||
            !IsWindow(overlay.window)) {
            if (IsWindow(overlay.window)) {
                DestroyWindow(overlay.window);
            }

            it = overlays_.erase(it);
            continue;
        }

        UpdateOverlay(overlay);
        ++it;
    }
}

void OverlayManager::UpdateOverlay(Overlay& overlay) {
    HWND target = overlay.target;
    HWND window = overlay.window;

    if (!IsWindow(target) || !IsWindow(window)) {
        return;
    }

    if (!IsWindowVisible(target) || IsIconic(target)) {
        ShowWindow(window, SW_HIDE);
        return;
    }

    RECT rect{};

    if (!GetWindowRect(target, &rect)) {
        ShowWindow(window, SW_HIDE);
        return;
    }

    // Expand slightly so the border does not cover the target's contents.
    InflateRect(&rect, kBorderWidth, kBorderWidth);

    const int width = rect.right - rect.left;
    const int height = rect.bottom - rect.top;

    if (width <= 0 || height <= 0) {
        ShowWindow(window, SW_HIDE);
        return;
    }

    // Place the overlay immediately above the target in the Z-order.
    HWND previous = GetWindow(target, GW_HWNDPREV);

    UINT flags =
        SWP_NOACTIVATE |
        SWP_SHOWWINDOW |
        SWP_NOOWNERZORDER;

    if (previous == window) {
        flags |= SWP_NOZORDER;
        previous = nullptr;
    } else if (previous == nullptr) {
        previous = HWND_TOP;
    }

    SetWindowPos(
        window,
        previous,
        rect.left,
        rect.top,
        width,
        height,
        flags
    );
}

LRESULT CALLBACK OverlayManager::WindowProc(
    HWND hwnd,
    UINT message,
    WPARAM wParam,
    LPARAM lParam
) {
    switch (message) {
    case WM_NCCREATE: {
        auto* createStruct =
            reinterpret_cast<CREATESTRUCTW*>(lParam);

        SetWindowLongPtrW(
            hwnd,
            GWLP_USERDATA,
            reinterpret_cast<LONG_PTR>(createStruct->lpCreateParams)
        );

        return TRUE;
    }

    case WM_NCHITTEST:
        return HTTRANSPARENT;

    case WM_MOUSEACTIVATE:
        return MA_NOACTIVATE;

    case WM_ERASEBKGND:
        return 1;

    case WM_PAINT: {
        PAINTSTRUCT ps{};
        HDC hdc = BeginPaint(hwnd, &ps);

        RECT rect{};
        GetClientRect(hwnd, &rect);

        // Fill the transparent color first.
        HBRUSH transparentBrush = CreateSolidBrush(kTransparentColor);
        FillRect(hdc, &rect, transparentBrush);
        DeleteObject(transparentBrush);

        // Draw the four sides of the yellow border.
        HBRUSH borderBrush = CreateSolidBrush(kBorderColor);

        RECT top{
            0,
            0,
            rect.right,
            kBorderWidth
        };

        RECT bottom{
            0,
            std::max<LONG>(0L, rect.bottom - kBorderWidth),
            rect.right,
            rect.bottom
        };

        RECT left{
            0,
            kBorderWidth,
            kBorderWidth,
            std::max<LONG>(kBorderWidth, rect.bottom - kBorderWidth)
        };

        RECT right{
            std::max<LONG>(0L, rect.right - kBorderWidth),
            kBorderWidth,
            rect.right,
            std::max<LONG>(kBorderWidth, rect.bottom - kBorderWidth)
        };

        FillRect(hdc, &top, borderBrush);
        FillRect(hdc, &bottom, borderBrush);
        FillRect(hdc, &left, borderBrush);
        FillRect(hdc, &right, borderBrush);

        DeleteObject(borderBrush);

        EndPaint(hwnd, &ps);
        return 0;
    }

    case WM_DESTROY:
        return 0;
    }

    return DefWindowProcW(hwnd, message, wParam, lParam);
}