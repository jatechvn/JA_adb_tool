TAG=v1.7.0
TITLE=JA ADB Tool v1.7.0
BODY=
## Highlights

- **Bento Liquid Glass UI & Design Tokens:** Complete modern desktop UI overhaul with token palette (`app_colors.dart`), Win10 Aero & Win11 Acrylic/Mica styles, GPU mesh background, and BentoCard widgets.
- **1-Click Theme Provider:** Instant Light/Dark theme switching with native Windows DWM title bar synchronization.
- **Dynamic Island Status Capsule:** Live real-time device connection state pill in top header with smooth marquee text.
- **Responsive Adaptive Navigation:** `SlidingPillTabBar` dynamically expands active tab and collapses unselected tabs on compact screens, preventing text clipping.
- **Asymmetric Ping-Pong Marquee Text:** High-performance text scrolling with edge pause intervals and zero idle CPU usage.
- **Streamlined Desktop Layout:** Compacted sidebar (230px) for maximum workspace and unified bottom-left toolbar.
- **Latest Media Preload & Cache:** Starts loading after device discovery and caches results per device, avoiding wait time when opening Latest Media or switching devices.
- **Synchronized Master UI Template:** All components and design guidelines synced with `flutter_ui_template`.

## Verification

- `dart analyze` completed with 0 errors.
- `flutter test` passed all 14 unit and widget test suites (100% pass).
- Full regression tests verified on Windows desktop.
