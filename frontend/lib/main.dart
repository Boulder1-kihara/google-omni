import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'core/state/app_state.dart';
import 'features/standby/presentation/standby_fab.dart';
import 'features/activation/presentation/activation_overlay.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shell_executor/shell_executor.dart';
import 'core/utils/default_shell_executor.dart';
import 'core/hotkeys/hotkey_service.dart';
import 'core/audio/wake_word_service.dart';
import 'features/panel/presentation/contextual_input_panel.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Required by screen_capturer on Windows to execute native clipboard binaries
  ShellExecutor.global = DefaultShellExecutor();
  
  // Initialize window_manager for desktop window manipulation
  await windowManager.ensureInitialized();

  // Define the main application window properties
  WindowOptions windowOptions = const WindowOptions(
    size: Size(800, 600), // Default start size, will be maximized
    center: true,
    backgroundColor: Colors.transparent, // Background must be perfectly transparent
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden, // Frameless UI
    alwaysOnTop: true, // Float above all OS windows at all times
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    // Strip default OS window decorations
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false);
    
    // Start as a transparent small window for the FAB so nothing is blocked
    await windowManager.setSize(const Size(150, 150));
    // Important for Frameless Windows using hotkeys
    await windowManager.setSkipTaskbar(false);
    await windowManager.setAlignment(Alignment.bottomRight);
    
    await windowManager.show();
  });

  // Setup Global App State
  final appState = AppState();

  // Setup Global Hotkey for "Deep Intel Omni"
  // Needs to be initialized after windowManager ensures binding
  await hotKeyManager.unregisterAll();
  final hotkeyService = HotkeyService(
    onActivate: () {
      appState.triggerActivation();
    },
  );
  await hotkeyService.initHotkeys();

  // Setup Wake Word Service
  final wakeWordService = WakeWordService(
    onWakeWordDetected: () {
      appState.triggerActivation();
    },
  );
  
  // !IMPORTANT: Replace this string with your actual Picovoice AccessKey
  // It won't throw a fatal error if wrong, but it will fail to initialize silently.
  try {
    await wakeWordService.initialize("pQMoeqV5npBPp4Hcb+MlpymMP02j0Zgv40x7dEY7mwmiozq6sy4KJw==");
  } catch (e) {
    print("Error initializing Wake Word Service: ");
    print(e);
    // Optionally, log this error to a monitoring service
  }
  
  // Start continuous listening in the background
  await wakeWordService.startListening();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appState),
        ChangeNotifierProvider.value(value: wakeWordService),
      ],
      // Wrapping with a temp MaterialApp for visibility
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.transparent,
          body: RootUIOverlay(),
        ),
      ),
    ),
  );
}

class RootUIOverlay extends StatelessWidget {
  const RootUIOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Stack(
          children: [
            // Always show the FAB if in Standby
            if (appState.currentMode == AppMode.standby)
              const StandbyFAB(),
            
            // When Activated, show the full screen glowing edge overlay
            if (appState.currentMode == AppMode.activated)
              ActivationOverlay(
                onDismiss: () => appState.returnToStandby(),
              ),
              
            // Slide-out panel for asking questions about screenshots
            if (appState.currentMode == AppMode.input)
              const ContextualInputPanel(),
          ],
        );
      },
    );
  }
}

