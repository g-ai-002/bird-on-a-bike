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
import '../game/ride_style.dart';
import '../models/game_state.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';

/// 桌面端使用键盘与窗口；手机、平板进入游玩页后锁定横屏并沉浸全屏。
bool get _isMobile =>
    !Platform.isWindows && !Platform.isMacOS && !Platform.isLinux;

/// 游玩页：Flame 画布铺满整个页面，计分与按钮以悬浮 HUD 叠在其上。
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
    return Scaffold(
      backgroundColor: RideColors.skyTop,
      body: Stack(
        children: [
          // 画布铺满整页；相机按 cover 缩放，四周只会裁切、不会留黑边。
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) => _focusGame(),
              child: _buildGameWidget(game),
            ),
          ),
          Positioned.fill(child: _buildHud(game)),
        ],
      ),
    );
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
      },
    );
  }

  Widget _buildHud(BikeGame game) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _circleNavButton(
                      Icons.arrow_back,
                      () => Navigator.pop(context),
                    ),
                    const SizedBox(height: 8),
                    IgnorePointer(child: _buildStats(colors)),
                  ],
                ),
                const Spacer(),
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
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showPause)
                          _circleNavButton(
                            game.isPaused ? Icons.play_arrow : Icons.pause,
                            game.togglePause,
                          ),
                        if (chips.isNotEmpty) const SizedBox(height: 8),
                        if (chips.isNotEmpty)
                          IgnorePointer(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final chip in chips)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: chip,
                                  ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ],
            ),
            const Spacer(),
            IgnorePointer(child: _buildHint(game)),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(ColorScheme colors) {
    return Consumer<GameProvider>(
      builder: (context, game, _) {
        final state = game.state;
        return _hudPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _hudText('得分 ${state.score}', color: colors.primary),
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
                _hudText('连击 ×${state.combo}', color: colors.secondary),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHint(BikeGame game) {
    return Consumer<GameProvider>(
      builder: (context, game, _) {
        final status = game.state.status;
        if (status != GameStatus.playing && status != GameStatus.paused) {
          return const SizedBox.shrink();
        }
        final colors = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: colors.outline),
          ),
          child: Text(
            defaultTargetPlatform == TargetPlatform.windows
                ? '空格 / ↑ 跳跃（可二段跳）· 长按跳更高 · ↓ 俯身 · P 暂停'
                : '点击 / 上滑跳跃 · 下滑俯身 · 右上角暂停',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.onSurfaceVariant,
              fontSize: 11,
            ),
          ),
        );
      },
    );
  }

  Widget _hudPanel({required Widget child}) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.surface.withValues(alpha: 0.84),
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
        color: colors.surfaceContainerHighest.withValues(alpha: 0.9),
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
