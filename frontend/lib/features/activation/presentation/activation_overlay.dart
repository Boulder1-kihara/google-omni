import 'dart:ui';
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:screen_capturer/screen_capturer.dart';
import 'package:image/image.dart' as img;
import '../../../core/agent/live_streaming_service.dart';
import '../../../core/state/app_state.dart';
import '../../highlight/presentation/widgets/highlight_painter.dart';
import 'widgets/listening_orb.dart';

class ActivationOverlay extends StatefulWidget {
  final VoidCallback onDismiss;

  const ActivationOverlay({
    super.key,
    required this.onDismiss,
  });

  @override
  State<ActivationOverlay> createState() => _ActivationOverlayState();
}

class _ActivationOverlayState extends State<ActivationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  // Custom Cursor variables
  Offset _mousePosition = Offset.zero;
  bool _isHovering = false;

  // Selection Box variables
  Offset? _dragStart;
  Offset? _dragCurrent;
  bool _isDragging = false;
  bool _isFinished = false;

  // Screenshot state
  bool _isCapturing = false;

  // Live Streaming state
  final LiveStreamingService _liveService = LiveStreamingService();
  bool _isLiveSessionActive = false;

  // Chat state
  final List<Map<String, String>> _chatMessages = [];
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _chatFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Reusable controller for gradient rotation and highlight pulsing
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _liveService.onAgentTextMessage = (text) {
      if (mounted) {
        setState(() {
          _chatMessages.add({"sender": "agent", "text": text});
        });
        _scrollToBottom();
      }
    };
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendTextMessage() {
    final text = _chatController.text.trim();
    if (text.isNotEmpty) {
      setState(() {
        _chatMessages.add({"sender": "user", "text": text});
        _chatController.clear();
      });
      _liveService.sendText(text);
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _liveService.endSession();
    _animController.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    _chatFocusNode.dispose();
    super.dispose();
  }


  /// Calculates the current selection rectangle from drag points
  Rect? get _selectionRect {
    if (_dragStart == null || _dragCurrent == null) return null;
    return Rect.fromPoints(_dragStart!, _dragCurrent!);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MouseRegion(
        // Changes user cursor to the '+' crosshair globally during activation
        cursor: SystemMouseCursors.precise,
        onHover: (event) {
          setState(() {
            _mousePosition = event.localPosition;
          });
          _liveService.updateMousePosition(event.position);
        },
        onEnter: (_) => setState(() => _isHovering = true),
        onExit: (_) => setState(() => _isHovering = false),
        child: Listener(
          // Listen for right-click drag (buttons == 2 is standard secondary right-click)
          onPointerDown: (event) {
            if (event.buttons == 2) {
              setState(() {
                _dragStart = event.localPosition;
                _dragCurrent = event.localPosition;
                _isDragging = true;
                _isFinished = false;
              });
            }
          },
          onPointerMove: (event) {
            if (_isDragging) {
              setState(() {
                _dragCurrent = event.localPosition;
              });
            }
          },
          onPointerUp: (event) async {
            if (_isDragging) {
              setState(() {
                _isDragging = false;
                _isFinished = true;
              });

              if (_selectionRect != null && _selectionRect!.width > 10 && _selectionRect!.height > 10) {
                await _captureAndCropScreen();
              }
            }
          },
          child: _isCapturing 
            ? const SizedBox.expand() // Hide everything when capturing
            : Row(
                children: [
                  Expanded(
                    child: Stack(
                      children: [
              // 1. Google Lens styled Fading Edge Gradient Overlay
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: _LensGradientBorderPainter(
                      animationValue: _animController.value,
                    ),
                  );
                },
              ),

              // 2. The Custom Highlight Painter
              AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return CustomPaint(
                    size: Size.infinite,
                    painter: SelectionHighlightPainter(
                      selectionRect: _selectionRect,
                      isFinished: _isFinished,
                      animationValue: _animController.value,
                    ),
                  );
                },
              ),

              // 3. Top Button - Return to Standby
              Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 40.0),
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(color: Colors.white.withOpacity(0.2)),
                      ),
                    ),
                    onPressed: widget.onDismiss,
                    icon: const Icon(Icons.close),
                    label: const Text('Return to Standby'),
                  ),
                ),
              ),

              // 4. Custom Trailing Cursor: Small Camera Icon attaches to '+'
              if (_isHovering && !_isFinished)
                Positioned(
                  // Offset slightly right and down to act as a "tail" for the crosshair
                  left: _mousePosition.dx + 16,
                  top: _mousePosition.dy + 8,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white30, width: 1),
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ),
                ),

              // 5. Bottom Center Bar: Mic and Screen-Share Icons
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 60.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(40),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4), // Dark frosted glass
                          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1.5),
                          borderRadius: BorderRadius.circular(40),
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildBottomActionIcon(
                                  Icons.mic, "Talk to Agent", Colors.blueAccent),
                              const SizedBox(width: 16),
                              // Small divider
                              Container(width: 1, height: 30, color: Colors.white24),
                              const SizedBox(width: 16),
                              _buildBottomActionIcon(
                                  Icons.screen_share, "Live Screen Action", Colors.greenAccent),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // 6. The Pulsing Listening Orb (Bottom Right)
              if (_isLiveSessionActive)
                Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(40.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // The Orb
                        ListeningOrb(
                          onCancel: () {
                            _liveService.endSession();
                            setState(() {
                              _isLiveSessionActive = false;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // 7. Split Screen Chat Interface (Right Side)
          if (_isLiveSessionActive)
             _buildChatInterface(),
        ],
      ),
    ),
  ),
);
  }

  Widget _buildBottomActionIcon(IconData icon, String tooltip, Color hoverGlowColor) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 32),
        onPressed: () {
          if (icon == Icons.mic) {
            if (_isLiveSessionActive) {
              _liveService.endSession();
              setState(() {
                _isLiveSessionActive = false;
              });
            } else {
              setState(() {
                _isLiveSessionActive = true;
              });
              _liveService.startSession();
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) _chatFocusNode.requestFocus();
              });
            }
          } else if (icon == Icons.screen_share) {
            // Full Screen Capture & Transition to Live Input Mode
            setState(() {
              _dragStart = null;
              _dragCurrent = null;
            });
            _captureAndCropScreen();
          }
        },
      ),
    );
  }

  Future<void> _captureAndCropScreen() async {
    // 1. Hide UI
    setState(() => _isCapturing = true);
    // Give Flutter a few frames to render the empty screen
    await Future.delayed(const Duration(milliseconds: 150));

    try {
      final tempImagePath = '${Directory.systemTemp.path}${Platform.pathSeparator}deep_intel_omni_screenshot.png';
      print('📸 Taking screenshot to: $tempImagePath');
      final capturedData = await screenCapturer.capture(
        mode: CaptureMode.screen,
        imagePath: tempImagePath,
        copyToClipboard: false,
        silent: true,
      );
      print('📸 Capture result: ${capturedData?.imagePath}, bytes length: ${capturedData?.imageBytes?.length}');

      if (capturedData != null && capturedData.imageBytes != null) {
        print('📸 Decoding image...');
        // 3. Decode and Crop
        final originalImage = img.decodeImage(capturedData.imageBytes!);
        if (originalImage != null) {
          if (_selectionRect != null) {
            print('📸 Original image size: ${originalImage.width}x${originalImage.height}');
            final rect = _selectionRect!;
            
            // Ensure crop rectangle is within image bounds
            final x = rect.left.toInt().clamp(0, originalImage.width);
            final y = rect.top.toInt().clamp(0, originalImage.height);
            final w = rect.width.toInt().clamp(0, originalImage.width - x);
            final h = rect.height.toInt().clamp(0, originalImage.height - y);

            if (w > 0 && h > 0) {
              final croppedImage = img.copyCrop(originalImage, x: x, y: y, width: w, height: h);
              final croppedBytes = img.encodeJpg(croppedImage, quality: 90);

              if (mounted) {
                print('📸 Triggering input mode with ${croppedBytes.length} bytes');
                context.read<AppState>().triggerInputMode(Uint8List.fromList(croppedBytes));
              }
            } else {
              print('📸 Invalid crop dimensions: $w x $h');
            }
          } else {
            // No selection rect - Full screen was requested!
            final fullScreenBytes = img.encodeJpg(originalImage, quality: 90);
            if (mounted) {
              print('📸 Triggering input mode with Full Screen (${fullScreenBytes.length} bytes)');
              context.read<AppState>().triggerInputMode(Uint8List.fromList(fullScreenBytes));
            }
          }
        } else {
           print('📸 Decode failed');
        }
      } else {
        print('📸 Captured data or bytes are null');
      }
    } catch (e, stacktrace) {
      print('❌ Failed to capture screen: $e');
      print(stacktrace);
    } finally {
      if (mounted) {
        setState(() => _isCapturing = false);
      }
    }
  }

  Widget _buildChatInterface() {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        border: Border(left: BorderSide(color: Colors.white.withOpacity(0.2))),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: const Row(
              children: [
                Icon(Icons.chat_bubble_outline, color: Colors.blueAccent),
                SizedBox(width: 8),
                Text('Omni Chat', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          
          // Messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _chatMessages.length,
              itemBuilder: (context, index) {
                final msg = _chatMessages[index];
                final isUser = msg["sender"] == "user";
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isUser ? Colors.blueAccent.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: Radius.circular(isUser ? 4 : 16),
                        bottomLeft: Radius.circular(isUser ? 16 : 4),
                      ),
                      border: Border.all(
                        color: isUser ? Colors.blueAccent.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      msg["text"] ?? "",
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _chatController,
                    focusNode: _chatFocusNode,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onSubmitted: (_) => _sendTextMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blueAccent),
                  onPressed: _sendTextMessage,
                )
              ],
            ),
          )
        ],
      )
    );
  }
}

/// Creates a Google-Lens styled Sweep Gradient but fades it transparently towards the center using massive blur and stroke.
class _LensGradientBorderPainter extends CustomPainter {
  final double animationValue;

  _LensGradientBorderPainter({required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final paint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        transform: GradientRotation(animationValue * 2 * 3.14159),
        colors: const [
          Color(0xFF4285F4), // Google Blue
          Color(0xFFEA4335), // Google Red
          Color(0xFFFBBC04), // Google Yellow
          Color(0xFF34A853), // Google Green
          Color(0xFF4285F4), // Match start
        ],
        stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 140.0 // Exceptionally thick edges so it fades into center
      // Using normal BlurStyle causes the stroke to dramatically blur inwards towards transparency at center
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 100.0);

    // We draw slightly outside the screen bounds so the hard outer edge of the screen isn't cut off by the stroke center
    canvas.drawRect(rect.inflate(80), paint);
  }

  @override
  bool shouldRepaint(covariant _LensGradientBorderPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
