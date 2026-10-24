import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/bike_game.dart';
import '../game/overlays/countdown_overlay.dart';
import '../game/overlays/game_over_overlay.dart';
import '../game/overlays/pause_overlay.dart';
import '../game/ride_style.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';

class GamePage extends StatefulWidget {
  const GamePage({super.key});

  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> {
  final FocusNode _gameFocusNode = FocusNode(
    debugLabel: 'bike-game',
    skipTraversal: true,
  );
  BikeGame? _game;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _gameFocusNode.requestFocus();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_game != null) return;

    final provider = context.read<GameProvider>();
    final settings = context.read<SettingsProvider>();
    provider.setDifficulty(settings.difficulty);
    _game = BikeGame(provider: provider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.start();
      _gameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _gameFocusNode.dispose();
    super.dispose();
  }

  void _focusGame() {
    if (!_gameFocusNode.hasFocus) {
      _gameFocusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final provider = context.read<GameProvider>();
    final game = _game;
    if (game == null) {
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Consumer<GameProvider>(
          builder: (context, game, _) => Text('得分 ${game.state.score}'),
        ),
        actions: [
          Consumer<GameProvider>(
            builder: (context, game, _) {
              if (!game.isPlaying && !game.isPaused) {
                return const SizedBox.shrink();
              }
              return IconButton(
                icon: Icon(game.isPaused ? Icons.play_arrow : Icons.pause),
                tooltip: game.isPaused ? '继续' : '暂停',
                onPressed: game.togglePause,
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Consumer<GameProvider>(
                builder: (context, game, _) {
                  final state = game.state;
                  return Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        '距离 ${state.distance.floor()} m',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colors.primary,
                            ),
                      ),
                      Text(
                        '最高 ${state.highScore}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.secondary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                      Text(
                        '小鱼 ${state.fish}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                            ),
                      ),
                      if (state.combo > 1)
                        Text(
                          '连击 ×${state.combo}',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: RideColors.fish,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Listener(
                      onPointerDown: (_) => _focusGame(),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: AspectRatio(
                            aspectRatio: 16 / 9,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: GameWidget<BikeGame>(
                                game: game,
                                focusNode: _gameFocusNode,
                                overlayBuilderMap: {
                                  BikeGame.pauseOverlayId: (_, BikeGame game) =>
                                      PauseOverlay(
                                        provider: game.provider,
                                        onResume: () {
                                          game.provider.togglePause();
                                          _gameFocusNode.requestFocus();
                                        },
                                      ),
                                  BikeGame.countdownOverlayId:
                                      (_, BikeGame game) => CountdownOverlay(
                                            countdown: game.countdown,
                                          ),
                                  BikeGame.gameOverOverlayId:
                                      (_, BikeGame game) => GameOverOverlay(
                                            provider: game.provider,
                                            onRestart: () {
                                              game.provider.start();
                                              _gameFocusNode.requestFocus();
                                            },
                                          ),
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    left: 16,
                    right: 16,
                    child: IgnorePointer(
                      child: Consumer<GameProvider>(
                        builder: (context, game, _) {
                          final state = game.state;
                          final chips = <Widget>[
                            if (state.hasShield)
                              _EffectChip(
                                icon: Icons.shield_outlined,
                                label: '护盾 ×${state.shieldCharges}',
                                color: RideColors.shield,
                              ),
                            if (state.magnetActive)
                              _EffectChip(
                                icon: Icons.attractions,
                                label:
                                    '磁铁 ${state.magnetRemaining.ceil()}s',
                                color: RideColors.magnet,
                              ),
                          ];
                          if (chips.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Align(
                            alignment: Alignment.topCenter,
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              alignment: WrapAlignment.center,
                              children: chips,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 52,
              child: Consumer<GameProvider>(
                builder: (context, game, _) {
                  final status = game.state.status;
                  if (status == GameStatus.playing ||
                      status == GameStatus.paused) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          defaultTargetPlatform == TargetPlatform.windows
                              ? '空格 / ↑ 跳跃（可二段跳）· 长按跳更高 · ↓ 俯身 · P 暂停'
                              : '点击跳跃（可二段跳）· 下滑俯身 · 点击右上角暂停',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colors.onSurfaceVariant,
                                  ),
                        ),
                      ),
                    );
                  }
                  if (status == GameStatus.idle) {
                    return Center(
                      child: ElevatedButton.icon(
                        onPressed: game.start,
                        icon: const Icon(Icons.replay),
                        label: const Text('重新开始'),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(180, 44),
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class _EffectChip extends StatelessWidget {
  const _EffectChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
