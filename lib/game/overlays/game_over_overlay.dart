import 'package:flutter/material.dart';

import '../../providers/game_provider.dart';

/// 骑行结束结算遮罩。
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    super.key,
    required this.provider,
    this.onRestart,
  });

  final GameProvider provider;

  /// 再来一局后的回调，用于把键盘焦点交还游戏。
  final VoidCallback? onRestart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final state = provider.state;
    final isRecord = state.score > 0 && state.score >= state.highScore;

    return SizedBox.expand(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.55),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight =
                constraints.maxHeight > 24 ? constraints.maxHeight - 24 : 0.0;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(22, 18, 22, 16),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black26,
                          blurRadius: 24,
                          offset: Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          isRecord ? '新纪录！' : '骑行结束',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color:
                                isRecord ? colors.secondary : colors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '本局得分',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          '${state.score}',
                          style: theme.textTheme.displaySmall?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 18,
                          runSpacing: 4,
                          children: [
                            _Stat(
                              label: '距离',
                              value: '${state.distance.floor()} m',
                            ),
                            _Stat(label: '小鱼', value: '${state.fish} 条'),
                            _Stat(
                              label: '最高分',
                              value: '${state.highScore}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '最远 ${state.bestDistance.floor()} m',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: onRestart ?? provider.start,
                          icon: const Icon(Icons.replay),
                          label: const Text('再来一局'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(180, 42),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 11,
              ),
        ),
      ],
    );
  }
}
