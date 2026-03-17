import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/state/app_state.dart';
import '../../../core/agent/live_streaming_service.dart';

class ContextualInputPanel extends StatefulWidget {
  const ContextualInputPanel({super.key});

  @override
  State<ContextualInputPanel> createState() => _ContextualInputPanelState();
}

class _ContextualInputPanelState extends State<ContextualInputPanel> with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  final LiveStreamingService _liveService = LiveStreamingService();

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(1.0, 0.0), // Start hidden off-screen to the right
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    // Slide in as soon as it's built
    _slideController.forward();
  }

  @override
  void dispose() {
    _liveService.endSession();
    _slideController.dispose();
    super.dispose();
  }

  void _closePanel() async {
    _liveService.endSession();
    await _slideController.reverse();
    if (mounted) {
      context.read<AppState>().returnToStandby();
    }
  }

  void _toggleLiveSession() async {
    if (_liveService.isStreaming) {
      _liveService.endSession();
    } else {
      await _liveService.startSession();
    }
    setState(() {}); // Rebuild to toggle button state
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    
    // Safety check just in case it renders without an image
    if (appState.capturedImageBytes == null) {
      return const SizedBox.shrink();
    }

    final isLive = _liveService.isStreaming;

    // Use ValueListenableBuilder to avoid unnecessary rebuilds
    return ValueListenableBuilder<bool>(
      valueListenable: _liveService.isStreamingNotifier,
      builder: (context, isLive, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: Align(
            alignment: Alignment.centerRight,
            child: Container(
              width: 400,
              margin: const EdgeInsets.only(right: 24, top: 40, bottom: 40),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.65), // Strong glassmorphism
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.4),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- Header: Title & Close Button ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome, color: Color(0xFF4285F4), size: 24),
                        const SizedBox(width: 8),
                        Text(
                          "Deep Intel Omni",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.95),
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: _closePanel,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- Live Status Indicator ---
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isLive ? Colors.redAccent : Colors.grey,
                        boxShadow: isLive ? [
                          BoxShadow(color: Colors.redAccent.withOpacity(0.5), blurRadius: 10, spreadRadius: 2)
                        ] : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isLive ? "LIVE SESSION ACTIVE" : "SESSION INACTIVE",
                      style: TextStyle(
                        color: isLive ? Colors.redAccent : Colors.grey,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --- Action Buttons ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLive ? Colors.redAccent.withOpacity(0.2) : const Color(0xFF4285F4),
                      foregroundColor: isLive ? Colors.redAccent : Colors.white,
                      side: BorderSide(
                        color: isLive ? Colors.redAccent : Colors.transparent,
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _toggleLiveSession,
                    icon: Icon(isLive ? Icons.stop_circle_rounded : Icons.mic_rounded, size: 24),
                    label: Text(
                      isLive ? "End Live Session" : "Start Live Session",
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

