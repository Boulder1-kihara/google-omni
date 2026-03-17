lib/
├── main.dart                      # App entry point, window init & multi-provider setup
├── app.dart                       # Root MaterialApp widget & global theming
├── core/
│   ├── state/
│   │   └── app_state.dart         # Core AppMode state enum (Standby, Activated, etc.) & click-through toggling
│   ├── hotkeys/
│   │   └── hotkey_service.dart    # hotkey_manager: Ctrl+G+O global shortcut registration
│   ├── audio/
│   │   ├── wake_word_service.dart # porcupine_flutter integration for "Hey Omni"
│   │   └── mic_stream_service.dart# real-time volume detection (record or mic_stream)
│   └── utils/
│       └── window_utils.dart      # Helpers for screen maximize, bounds checks
└── features/
    ├── standby/
    │   └── presentation/
    │       └── standby_fab.dart   # Floating action button (hover & glowing shadow)
    ├── activation/
    │   └── presentation/
    │       ├── activation_overlay.dart # Full-screen SweepGradient colorful glowing edges
    │       └── listening_orb.dart      # Orb with ripple animations tied to mic volume
    ├── highlight/
    │   └── presentation/
    │       ├── highlight_screen.dart   # MouseRegion custom cursor & GestureDetector dragging
    │       └── widgets/
    │           └── highlight_painter.dart # CustomPainter matching drawn box with wavy glows
    └── panel/
        └── presentation/
            └── contextual_input_panel.dart # Slide-out glassmorphism TextField panel
