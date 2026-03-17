import 'package:win32/win32.dart';

class MouseController {
  /// Uses SetCursorPos to physically move the Windows cursor.
  void moveTo(int x, int y) {
    SetCursorPos(x, y);
  }

  /// Uses mouse_event with MOUSEEVENTF_LEFTDOWN and MOUSEEVENTF_LEFTUP.
  void leftClick() {
    mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0);
    mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0);
  }

  /// Executes two left clicks in rapid succession.
  void doubleClick() {
    leftClick();
    // A tiny delay can help ensure the OS registers it as a double click, 
    // but typically consecutive rapid clicks work fine.
    leftClick();
  }

  /// Uses mouse_event with MOUSEEVENTF_RIGHTDOWN and MOUSEEVENTF_RIGHTUP.
  void rightClick() {
    mouse_event(MOUSEEVENTF_RIGHTDOWN, 0, 0, 0, 0);
    mouse_event(MOUSEEVENTF_RIGHTUP, 0, 0, 0, 0);
  }
}
