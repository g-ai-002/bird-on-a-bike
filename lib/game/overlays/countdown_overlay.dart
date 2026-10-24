import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 开局倒计时遮罩：3、2、1、GO。
class CountdownOverlay extends StatelessWidget {
  const CountdownOverlay({super.key, required this.countdown});

  final ValueListenable<int> countdown;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: Center(
          child: ValueListenableBuilder<int>(
            valueListenable: countdown,
            builder: (context, value, _) {
              final label = value > 0 ? '$value' : 'GO';
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: Text(
                  label,
                  key: ValueKey(label),
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Colors.black54,
                        blurRadius: 18,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
