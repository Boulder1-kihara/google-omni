import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class HotkeyService {
  final VoidCallback onActivate;

  // Define our global hotkey combo: Ctrl + Shift + O (Ctrl+G+O isn't standard, using Shift is safer across OS)
  // But to stick strictly to Ctrl+G+O (Note: some OS intercept 3-key combos weirdly):
  late HotKey _activationHotKey;

  HotkeyService({required this.onActivate}) {
    // Attempting to map Ctrl + G + O as requested.
    // However, hotkey_manager limits to modifiers + single keycode usually.
    // The closest standard implementation for "Ctrl+O" or "Ctrl+Shift+O" is preferred.
    // For "Ctrl+G+O", we are technically looking at a complex chord which `hotkey_manager` natively doesn't support well as a single `HotKey`.
    // We will bind to: Control + Alt + O as a safer alternative that works universally.
    _activationHotKey = HotKey(
      key: PhysicalKeyboardKey.keyO,
      modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
      scope: HotKeyScope.system, // Works even when app is in background
    );
  }

  Future<void> initHotkeys() async {
    // Must initialize the manager first
    await hotKeyManager.unregisterAll();

    // Register the hotkey
    await hotKeyManager.register(
      _activationHotKey,
      keyDownHandler: (hotKey) {
        if (kDebugMode) {
          print('Hotkey Triggered: Control + Alt + O');
        }
        // Fire the callback to transition state
        onActivate();
      },
    );
  }

  Future<void> dispose() async {
    await hotKeyManager.unregister(_activationHotKey);
  }
}
