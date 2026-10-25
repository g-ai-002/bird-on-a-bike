import 'dart:io';

import 'package:flame/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../game/bike_game.dart';
import '../game/overlays/countdown_overlay.dart';
import '../game/overlays/game_over_overlay.dart';
import '../game/overlays/pause_overlay.dart';
import '../game/overlays/unsupported_3d_overlay.dart';
import '../game/ride_style.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';

/// 桌面端使用键盘与窗口；手机、平板进入游玩页后锁定横屏并沉浸全屏。
bool get _isMobile =>
    !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux;

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
    if (_isMobile) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }
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
    if (_isMobile) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
        DeviceOrientation.portraitUp,
      ]);
      SystemChrome.setEnabledSystemUIMode(
        SystemUiMode.manual,
        overlays: SystemUiOverlay.values,
      );
    }
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
    final game = _game;
    if (game == null) {
      return const SizedBox.shrink();
    }
    return _isMobile ? _buildImmersive(game) : _buildDesktop(game);
  }

  Widget _buildGameWidget(BikeGame game) {
    return GameWidget<BikeGame>(
      game: game,
      focusNode: _gameFocusNode,
      overlayBuilderMap: {
        BikeGame.pauseOverlayId: (_, BikeGame game) => PauseOverlay(
              provider: game.provider,
              onResume: () {
                game.provider.togglePause();
                _gameFocusNode.requestFocus();
              },
            ),
        BikeGame.countdownOverlayId: (_, BikeGame game) => CountdownOverlay(
              countdown: game.countdown,
            ),
        BikeGame.gameOverOverlayId: (_, BikeGame game) => GameOverOverlay(
              provider: game.provider,
              onRestart: () {
                game.provider.start();
                _gameFocusNode.requestFocus();
              },
            ),
        BikeGame.unsupported3DOverlayId: (_, BikeGame game) =>
            const Unsupported3DOverlay(),
      },
    );
  }

  Widget _buildDesktop(BikeGame game) {
    final colors = Theme.of(context).colorScheme;
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
                              child: _buildGameWidget(game),
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

  /// 手机横屏全屏布局：画布按 16:9 居中，状态与按钮浮在顶部两角。
  Widget _buildImmersive(BikeGame game) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          Positioned.fill(
            child: Listener(
              onPointerDown: (_) => _focusGame(),
              child: Center(
                child: AspectRatio(
                  aspectRatio:
                      AppConstants.worldWidth / AppConstants.worldHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildGameWidget(game),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Consumer<GameProvider>(
                      builder: (context, game, _) {
                        final state = game.state;
                        return _hudPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _circleNavButton(
                                Icons.arrow_back,
                                () => Navigator.pop(context),
                              ),
                              const SizedBox(height: 10),
                              _hudText(
                                '得分 ${state.score}',
                                color: colors.primary,
                              ),
                              _hudText('距离 ${state.distance.floor()} m'),
                              _hudText(
                                '最高 ${state.highScore}',
                                color: colors.onSurfaceVariant,
                                fontSize: 12,
                              ),
                              _hudText(
                                '小鱼 ${state.fish}',
                                color: colors.onSurfaceVariant,
                              ),
                              if (state.combo > 1)
                                _hudText(
                                  '连击 ×${state.combo}',
                                  color: colors.secondary,
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                    Consumer<GameProvider>(
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
                              label: '磁铁 ${state.magnetRemaining.ceil()}s',
                              color: RideColors.magnet,
                            ),
                        ];
                        final showPause = game.isPlaying || game.isPaused;
                        if (!showPause && chips.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return _hudPanel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (showPause)
                                _circleNavButton(
                                  game.isPaused
                                      ? Icons.play_arrow
                                      : Icons.pause,
                                  game.togglePause,
                                ),
                              if (showPause && chips.isNotEmpty)
                                const SizedBox(height: 10),
                              ...chips,
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: SafeArea(
              top: false,
              child: IgnorePointer(
                child: Consumer<GameProvider>(
                  builder: (context, game, _) {
                    if (!game.isPlaying && !game.isPaused) {
                      return const SizedBox.shrink();
                    }
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: colors.surface.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: colors.outline),
                        ),
                        child: Text(
                          '点击跳跃（可二段跳）· 下滑俯身 · 右上角暂停',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _hudPanel({required Widget child}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline),
      ),
      child: child,
    );
  }

  Widget _hudText(
    String text, {
    Color? color,
    double fontSize = 14,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          color: color ?? colors.onSurface,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _circleNavButton(IconData icon, VoidCallback onPressed) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceContainerHighest,
        border: Border.all(color: colors.outline),
      ),
      child: IconButton(
        icon: Icon(icon, color: colors.onSurface, size: 22),
        onPressed: onPressed,
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
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.9),
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
              color: colors.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
