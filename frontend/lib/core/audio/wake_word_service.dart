import 'dart:async';
import 'package:flutter/foundation.dart';

/// MOCKED WAKE WORD SERVICE
/// The porcupine_flutter package natively lacks a pre-compiled C++ library (.dll)
/// for Windows desktop environments. To unblock development, this service
/// stubs the initialization and listening mechanics.
class WakeWordService extends ChangeNotifier {
  bool _isListening = false;
  final VoidCallback onWakeWordDetected;

  WakeWordService({required this.onWakeWordDetected});

  bool get isListening => _isListening;

  /// Initializes the Mock Service
  Future<void> initialize(String accessKey) async {
    if (kDebugMode) {
      print("WakeWordService (MOCKED): Initialization bypassed for Windows Desktop.");
    }
  }

  Future<void> startListening() async {
    if (!_isListening) {
      _isListening = true;
      if (kDebugMode) {
        print("WakeWordService (MOCKED): Started 'listening'. Use the FAB or Ctrl+Alt+O to trigger.");
      }
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    if (_isListening) {
      _isListening = false;
      if (kDebugMode) {
        print("WakeWordService (MOCKED): Stopped 'listening'.");
      }
      notifyListeners();
    }
  }

  /// Optional debug method to manually fire the trigger programmatically
  void simulateWakeWord() {
    if (_isListening) {
      if (kDebugMode) {
        print("Wake word detected! (Simulated)");
      }
      onWakeWordDetected();
    }
  }

  @override
  void dispose() {
    stopListening();
    super.dispose();
  }
}
