#pragma once

#include <Windows.h>
#include <memory>
#include <unordered_map>
#include <algorithm>

class OverlayManager {
public:
    OverlayManager() = default;
    ~OverlayManager();

    OverlayManager(const OverlayManager&) = delete;
    OverlayManager& operator=(const OverlayManager&) = delete;

    // Add a yellow border for a target window.
    bool Add(HWND target);

    // Remove the border for a target window.
    void Remove(HWND target);

    // Update the position of all borders.
    void UpdateAll();

    // Remove all borders.
    void Clear();

private:
    struct Overlay {
        HWND target = nullptr;
        HWND window = nullptr;
    };

    static constexpr int kBorderWidth = 3;

    static ATOM RegisterWindowClass();
    static LRESULT CALLBACK WindowProc(
        HWND hwnd,
        UINT message,
        WPARAM wParam,
        LPARAM lParam
    );

    bool CreateOverlay(Overlay& overlay);
    void UpdateOverlay(Overlay& overlay);

    std::unordered_map<HWND, std::unique_ptr<Overlay>> overlays_;
};