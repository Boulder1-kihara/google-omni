import 'package:win32/win32.dart';

class ScreenMetricsService {
  /// Returns the width of the primary monitor in pixels.
  static int getPrimaryMonitorWidth() {
    return GetSystemMetrics(SM_CXSCREEN);
  }

  /// Returns the height of the primary monitor in pixels.
  static int getPrimaryMonitorHeight() {
    return GetSystemMetrics(SM_CYSCREEN);
  }
}
