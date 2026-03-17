import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:screen_capturer/screen_capturer.dart';
import '../hardware/mouse_controller.dart';        // NEW
import '../hardware/screen_metrics_service.dart'; // NEW

// ---------------------------------------------------------------------------
// WAV header helper (unchanged)
// ---------------------------------------------------------------------------
Uint8List _buildWavBytes(Uint8List pcmBytes, {
  int sampleRate = 24000,
  int numChannels = 1,
  int bitsPerSample = 16,
}) {
  final int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  final int blockAlign = numChannels * bitsPerSample ~/ 8;
  final int dataSize = pcmBytes.length;
  final int chunkSize = 36 + dataSize;

  final header = ByteData(44)
    ..setUint8(0, 0x52) // 'R'
    ..setUint8(1, 0x49) // 'I'
    ..setUint8(2, 0x46) // 'F'
    ..setUint8(3, 0x46) // 'F'
    ..setUint32(4, chunkSize, Endian.little)
    ..setUint8(8, 0x57)  // 'W'
    ..setUint8(9, 0x41)  // 'A'
    ..setUint8(10, 0x56) // 'V'
    ..setUint8(11, 0x45) // 'E'
    ..setUint8(12, 0x66) // 'f'
    ..setUint8(13, 0x6D) // 'm'
    ..setUint8(14, 0x74) // 't'
    ..setUint8(15, 0x20) // ' '
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little)
    ..setUint16(22, numChannels, Endian.little)
    ..setUint32(24, sampleRate, Endian.little)
    ..setUint32(28, byteRate, Endian.little)
    ..setUint16(32, blockAlign, Endian.little)
    ..setUint16(34, bitsPerSample, Endian.little)
    ..setUint8(36, 0x64) // 'd'
    ..setUint8(37, 0x61) // 'a'
    ..setUint8(38, 0x74) // 't'
    ..setUint8(39, 0x61) // 'a'
    ..setUint32(40, dataSize, Endian.little);

  return Uint8List.fromList(header.buffer.asUint8List() + pcmBytes);
}

class LiveStreamingService {
  WebSocketChannel? _channel;
  final String _backendUrl = 'ws://127.0.0.1:8000/omni-live';
  
  // Audio Recording
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  StreamSubscription? _playerCompleteSubscription;
  bool _isRecording = false;

  // Screen Capture
  Timer? _screenCaptureTimer;
  int _consecutiveCaptureFailures = 0;
  static const int _screenCaptureIntervalSeconds = 5;

  // Audio Playback
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isAgentSpeaking = false;

  Offset _currentMousePos = Offset.zero;

  // NEW: Mouse control
  final MouseController _mouseController = MouseController();

  bool get isStreaming => _channel != null;

  Function(String)? onAgentTextMessage;

  Future<void> startSession() async {
    if (isStreaming) return;

    try {
      print('🔄 Connecting to Live Backend at $_backendUrl');
      _channel = WebSocketChannel.connect(Uri.parse(_backendUrl));
      
      _channel!.stream.listen(
        (data) => _handleIncomingServerData(data),
        onError: (error) => print('🔴 Live Session Error: $error'),
        onDone: () => _cleanupSession(),
      );

      print('🟢 Live Session Connected.');

      _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
        _isAgentSpeaking = false;
        print('🔇 Agent finished speaking — screen capture resuming.');
      });

      _startAudioStreaming();
      _startScreenCaptureLoop();   // ← NOW ENABLED

    } catch (e) {
      print('❌ Failed to start live session: $e');
      _cleanupSession();
    }
  }

  void endSession() {
    print('⏹️ Ending Live Session...');
    _cleanupSession();
  }

  Future<void> _startAudioStreaming() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        final stream = await _audioRecorder.startStream(const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
        ));

        _isRecording = true;
        print('🎙️ Started streaming microphone audio.');

        _audioStreamSubscription = stream.listen((data) {
          if (_channel != null && data.isNotEmpty) {
            final base64Audio = base64Encode(data);
            if (base64Audio.isNotEmpty) {
              final payload = jsonEncode({'audio': base64Audio});
              _channel!.sink.add(payload);
            }
          }
        });
      } else {
        print('❌ Microphone permission denied.');
      }
    } catch (e) {
      print('❌ Error starting audio stream: $e');
    }
  }

  void _startScreenCaptureLoop() {
    print('👁️ Screen capture loop ENABLED — sending 1 frame every 5s to Gemini Live');
    _screenCaptureTimer = Timer.periodic(
      const Duration(seconds: _screenCaptureIntervalSeconds),
      (timer) async {
        if (_isAgentSpeaking) {
          print('⏸️ Agent speaking — skipping frame');
          return;
        }
        await _captureAndSendScreen();
      },
    );
  }

  Future<void> _captureAndSendScreen() async {
    try {
      final tempDir = Directory.systemTemp;
      final imagePath = '${tempDir.path}${Platform.pathSeparator}omni_live_frame_${DateTime.now().millisecondsSinceEpoch}.png';
      
      CapturedData? capturedData = await ScreenCapturer.instance.capture(
        mode: CaptureMode.screen,
        imagePath: imagePath,
        copyToClipboard: false,
        silent: true,
      );

      if (capturedData == null || capturedData.imagePath == null) {
        _consecutiveCaptureFailures++;
        print('⚠️ Screen capture returned null. Failures: $_consecutiveCaptureFailures');
        if (_consecutiveCaptureFailures >= 3) {
           print('🛑 Too many screen capture failures. Pausing screen stream.');
           _screenCaptureTimer?.cancel();
        }
        return;
      }

      _consecutiveCaptureFailures = 0;

      final file = File(capturedData.imagePath!);
      final bytes = await file.readAsBytes();
      
      final base64Image = base64Encode(bytes);
      
      if (base64Image.isNotEmpty) {
        final payload = jsonEncode({
          'image': base64Image,
          'mouse_x': _currentMousePos.dx,
          'mouse_y': _currentMousePos.dy,
        });
        _channel?.sink.add(payload);
      }
      
      try {
        await file.delete();
      } catch (e) {
        print('⚠️ Could not delete temp live frame: $e');
      }
    } catch (e) {
      print('❌ Error capturing live frame: $e');
    }
  }

  void _handleIncomingServerData(dynamic data) async {
    try {
      final Map<String, dynamic> response = jsonDecode(data.toString());
      
      if (response.containsKey('audio')) {
        print('🔊 Received audio from AI — building WAV and playing back.');
        final String base64Audio = response['audio'];
        final Uint8List rawPcm = base64Decode(base64Audio);
        final Uint8List wavBytes = _buildWavBytes(rawPcm);

        final tempDir = Directory.systemTemp;
        final tempAudioFile = File('${tempDir.path}/temp_ai_response.wav');
        await tempAudioFile.writeAsBytes(wavBytes);

        _isAgentSpeaking = true;
        await _audioPlayer.play(DeviceFileSource(tempAudioFile.path));
      }

      if (response.containsKey('agent_text')) {
        final String textReply = response['agent_text'];
        if (onAgentTextMessage != null) {
          onAgentTextMessage!(textReply);
        }
        _tryParseAndExecuteAction(textReply); // ← NEW: mouse control from JSON
      }
      
    } catch (e) {
      print('❌ Error parsing live backend response: $e');
    }
  }

  // NEW: Parse JSON action from agent's transcription and execute mouse
  void _tryParseAndExecuteAction(String text) {
    final jsonMatches = RegExp(r'(\{[\s\S]*?\})').allMatches(text);
    if (jsonMatches.isEmpty) return;

    final lastJsonStr = jsonMatches.last.group(1)!;
    try {
      final actionMap = jsonDecode(lastJsonStr) as Map<String, dynamic>;
      final String? action = actionMap['action'] as String?;

      if (action == null) return;
      print('🖱️ Live Agent requested: $action');

      double targetX = (actionMap['x'] ?? 0).toDouble();
      double targetY = (actionMap['y'] ?? 0).toDouble();

      final screenWidth = ScreenMetricsService.getPrimaryMonitorWidth();
      final screenHeight = ScreenMetricsService.getPrimaryMonitorHeight();

      int finalX = targetX.round().clamp(0, screenWidth);
      int finalY = targetY.round().clamp(0, screenHeight);

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
          print('⌨️ Would type: ${actionMap['text_to_type'] ?? ''} (keyboard TODO)');
          break;
        case 'move_to':
          // already moved
          break;
        case 'done':
          print('✅ Agent task completed.');
          break;
      }
    } catch (_) {
      // not valid JSON — ignore
    }
  }

  void _cleanupSession() {
    _screenCaptureTimer?.cancel();
    _screenCaptureTimer = null;

    if (_isRecording) {
      _audioStreamSubscription?.cancel();
      _audioRecorder.stop();
      _isRecording = false;
    }

    _playerCompleteSubscription?.cancel();
    _audioPlayer.stop();

    _channel?.sink.close();
    _channel = null;

    print('🔴 Live Session Terminated.');
  }

  void updateMousePosition(Offset position) {
    _currentMousePos = position;
  }

  void sendText(String text) {
    if (isStreaming && _channel != null) {
      final trimmedText = text.trim();
      if (trimmedText.isNotEmpty) {
        _channel!.sink.add(jsonEncode({'text': trimmedText}));
      }
    }
  }
}