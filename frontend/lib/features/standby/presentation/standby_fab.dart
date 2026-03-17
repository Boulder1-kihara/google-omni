import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/state/app_state.dart';

class StandbyFAB extends StatefulWidget {
  const StandbyFAB({super.key});

  @override
  State<StandbyFAB> createState() => _StandbyFABState();
}

class _StandbyFABState extends State<StandbyFAB> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _wavyAnimController;

  @override
  void initState() {
    super.initState();
    _wavyAnimController = AnimationController(
       vsync: this, 
       duration: const Duration(seconds: 3)
    )..repeat();
  }

  @override
  void dispose() {
    _wavyAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: GestureDetector(
          onTap: () {
            // Trigger activation when the FAB is clicked
            context.read<AppState>().triggerActivation();
          },
          child: AnimatedBuilder(
            animation: _wavyAnimController,
            builder: (context, child) {
               return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                transform: Matrix4.identity()..scale(_isHovered ? 1.05 : 1.0),
                transformAlignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    if (_isHovered)
                      BoxShadow(
                        color: const Color(0xFF4285F4).withOpacity(0.4), // Google blue glow
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    else
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                  ],
                ),
                child: ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16), // Made smaller
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isHovered ? null : Colors.white.withOpacity(0.1),
                        // Wavy fast-spinning pastel color fill on hover
                        gradient: _isHovered ? SweepGradient(
                          center: Alignment.center,
                          transform: GradientRotation(_wavyAnimController.value * 2 * 3.14159),
                          colors: const [
                            Color(0xFF4285F4),
                            Color(0xFFEA4335),
                            Color(0xFFFBBC04),
                            Color(0xFF34A853),
                            Color(0xFF4285F4),
                          ],
                        ) : null,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.blur_on,
                        color: _isHovered ? Colors.white : Colors.white70,
                        size: 28, // Made smaller
                      ),
                    ),
                  ),
                ),
              );
            }
          ),
        ),
      ),
    );
  }
}
