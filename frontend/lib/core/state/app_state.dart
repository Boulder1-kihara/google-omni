import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

/// The four distinct UI states of Deep Intel Omni
enum AppMode {
  standby,
  activated,
  highlighting,
  input
}

class AppState extends ChangeNotifier {
  AppMode _currentMode = AppMode.standby;
  Uint8List? capturedImageBytes;

  AppMode get currentMode => _currentMode;

  /// Update the application state and toggle window interaction appropriately
  Future<void> setMode(AppMode newMode) async {
    if (_currentMode == newMode) return;
    
    _currentMode = newMode;
    
    // In Standby mode, shrink the window to just the FAB area bottom right
    if (_currentMode == AppMode.standby) {
      await windowManager.unmaximize();
      await windowManager.setSize(const Size(150, 150));
      await windowManager.setAlignment(Alignment.bottomRight);
    } 
    // In all other modes (Activated, Highlighting, Input), full overlay
    else {
      await windowManager.maximize();
      await windowManager.focus();
    }

    notifyListeners();
  }

  // --- Actions to transition between app states ---

  void triggerActivation() {
    // Triggered by global hotkey (hotkey_manager), wake word (porcupine_flutter), or FAB
    setMode(AppMode.activated);
  }

  void startHighlighting() {
    setMode(AppMode.highlighting);
  }

  void completeHighlighting() {
    setMode(AppMode.input);
  }

  void triggerInputMode(Uint8List imageBytes) {
    capturedImageBytes = imageBytes;
    setMode(AppMode.input);
  }

  void returnToStandby() {
    capturedImageBytes = null;
    setMode(AppMode.standby);
  }
}
