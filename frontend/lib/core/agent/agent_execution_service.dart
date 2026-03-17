import 'dart:convert';
import 'dart:typed_data';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../hardware/mouse_controller.dart';
import '../hardware/screen_metrics_service.dart';

class AgentExecutionService {
  WebSocketChannel? _channel;
  final String _backendUrl = 'ws://127.0.0.1:8000/omni-vision';
  final MouseController _mouseController = MouseController();

  /// Connects to the Python backend via WebSocket
  void connect() {
    try {
      _channel = WebSocketChannel.connect(Uri.parse(_backendUrl));
      print('🟢 Connected to backend at $_backendUrl');
      
      _channel!.stream.listen(
        (data) => _handleResponse(data),
        onError: (error) => print('🔴 WebSocket Error: $error'),
        onDone: () => print('🔴 WebSocket Disconnected'),
      );
    } catch (e) {
      print('❌ Connection failed: $e');
    }
  }

  /// Base64 encodes the image bytes and sends it to the backend along with the prompt
  void executeTask(String prompt, Uint8List screenBytes) {
    if (_channel == null) {
      print('WebSocket not connected. Attempting to connect...');
      connect();
      if (_channel == null) {
        print('❌ Failed to connect.');
        return;
      }
    }

    try {
      // Encode to base64
      final base64Image = base64Encode(screenBytes);

      // Package payload
      final payload = jsonEncode({
        'prompt': prompt,
        'image': base64Image,
      });
      
      _channel!.sink.add(payload);
      print('🧠 Sent task and screenshot to backend: "$prompt"');
      
    } catch (e) {
      print('❌ Error during task execution: $e');
    }
  }

  /// Handles the JSON response from the Python backend
  void _handleResponse(dynamic data) {
    try {
      final String jsonStr = data.toString();
      print('🎯 Received from backend: $jsonStr');
      final Map<String, dynamic> response = jsonDecode(jsonStr);

      final String action = response['action'] ?? '';
      
      // Print the rationale to the debug console
      final String rationale = response['rationale'] ?? 'No rationale provided.';
      print('💡 AI Rationale: $rationale');
      
      if (action == 'done') {
        print('✅ Agent task completed.');
        return;
      }

      // Parse coordinates
      double targetX = (response['x'] ?? 0).toDouble();
      double targetY = (response['y'] ?? 0).toDouble();
      
      // Translate coordinates
      final screenWidth = ScreenMetricsService.getPrimaryMonitorWidth();
      final screenHeight = ScreenMetricsService.getPrimaryMonitorHeight();
      
      int finalX = targetX.round();
      int finalY = targetY.round();

      // Ensure coordinates are within bounds
      if (finalX < 0) finalX = 0;
      if (finalY < 0) finalY = 0;
      if (finalX > screenWidth) finalX = screenWidth;
      if (finalY > screenHeight) finalY = screenHeight;

      print('🖱️ Executing Action: $action at ($finalX, $finalY)');

      // Physically execute the action
      _mouseController.moveTo(finalX, finalY);

      switch (action) {
        case 'left_click':
          _mouseController.leftClick();
          break;
        case 'right_click':
          _mouseController.rightClick();
          break;
        case 'double_click':
          _mouseController.doubleClick();
          break;
        case 'type_text':
          final text = response['text_to_type'] ?? '';
          print('⌨️ keyboard action to type: $text'); // Reserved for future keyboard implementation
          break;
        default:
          print('⚠️ Unknown action: $action');
      }

    } catch (e) {
      print('❌ Error parsing backend response: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    print('🔴 Disconnected from backend.');
  }
}

