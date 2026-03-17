import 'dart:math';
import 'package:flutter/material.dart';

class ListeningOrb extends StatefulWidget {
  final VoidCallback onCancel;

  const ListeningOrb({super.key, required this.onCancel});

  @override
  State<ListeningOrb> createState() => _ListeningOrbState();
}

class _ListeningOrbState extends State<ListeningOrb> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
  }

  void startAnimation() {
    if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  void stopAnimation() {
    if (_controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    stopAnimation();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onCancel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox(
          width: 150,
          height: 150,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final scale = 1.0 + (_controller.value * 0.15);
              final rotation = _controller.value * 2 * pi;

              return Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glowing rings (multiple colors blending)
                  Transform.scale(
                    scale: scale * 1.2,
                    child: Transform.rotate(
                      angle: rotation,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const SweepGradient(
                            colors: [
                              Color(0xFF4285F4), // Blue
                              Color(0xFFEA4335), // Red
                              Color(0xFFFBBC04), // Yellow
                              Color(0xFF34A853), // Green
                              Color(0xFF4285F4),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF4285F4).withValues(alpha: 0.5),
                              blurRadius: 30,
                              spreadRadius: 10 * _controller.value,
                            ),
                          ],
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black, // Inner dark void
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  // Inner pulsing core
                  Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.1 + (_controller.value * 0.2)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.3),
                            blurRadius: 20,
                            spreadRadius: 5 * _controller.value,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          Icons.mic,
                          color: Colors.white.withValues(alpha: 0.7 + (_controller.value * 0.3)),
                          size: 32,
                        ),
                      ),
                    ),
                  ),
                  
                  // Cancel hints on hover could be added here, but simplicity is key
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
