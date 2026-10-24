import 'package:flutter/material.dart';

import '../../providers/game_provider.dart';

/// 暂停时覆盖在游戏画面上的半透明遮罩。
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    super.key,
    required this.provider,
    this.onResume,
  });

  final GameProvider provider;

  /// 继续游戏后的回调，用于把键盘焦点交还游戏。
  final VoidCallback? onResume;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.48),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.pause_circle_outline,
                size: 44,
                color: Colors.white70,
              ),
              const SizedBox(height: 8),
              Text(
                '已暂停',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                '海风也停下来等你',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                    ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onResume ?? provider.togglePause,
                icon: const Icon(Icons.play_arrow),
                label: const Text('继续'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
