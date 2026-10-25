import 'dart:async';

import 'package:flame/game.dart';
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
import '../utils/ride_hints.dart';

/// 桌面端使用键盘与窗口；手机、平板进入游玩页后锁定横屏并沉浸全屏。
bool get _isMobile => !isDesktopPlatform;

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
  GameProvider? _provider;
  Timer? _hintTimer;
  bool _showHint = false;
  GameStatus _lastStatus = GameStatus.idle;

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
    _provider = provider;
    _lastStatus = provider.state.status;
    provider.addListener(_handleGameState);
    _game = BikeGame(provider: provider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      provider.start();
      _gameFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _provider?.removeListener(_handleGameState);
    _hintTimer?.cancel();
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

  /// 只在进入新一局时短暂展示玩法提示，避免一直占用画面。
  void _handleGameState() {
    final provider = _provider;
    if (provider == null || !mounted) return;
    final status = provider.state.status;
    final previous = _lastStatus;
    if (status == previous) return;
    _lastStatus = status;
    if (status == GameStatus.playing &&
        (previous == GameStatus.idle || previous == GameStatus.over)) {
      _showHintFor(const Duration(seconds: 6));
    }
  }

  void _showHintFor(Duration duration) {
    _hintTimer?.cancel();
    setState(() => _showHint = true);
    _hintTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() => _showHint = false);
    });
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
          Positioned.fill(child: _buildHud()),
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

  Widget _buildHud() {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _circleNavButton(
                  Icons.arrow_back,
                  () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: IgnorePointer(child: _buildStats(colors)),
                ),
                const SizedBox(width: 8),
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
            IgnorePointer(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                child: _showHint
                    ? _buildHint()
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(ColorScheme colors) {
    return Consumer<GameProvider>(
      builder: (context, game, _) {
        final state = game.state;
        return Align(
          alignment: Alignment.topLeft,
          child: _hudPanel(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 2,
              children: [
                _hudText(
                  '得分 ${state.score}',
                  color: colors.primary,
                  fontSize: 15,
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
                  _hudText('连击 ×${state.combo}', color: colors.secondary),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHint() {
    return Consumer<GameProvider>(
      builder: (context, game, _) {
        final status = game.state.status;
        if (status != GameStatus.playing && status != GameStatus.paused) {
          return const SizedBox.shrink();
        }
        final colors = Theme.of(context).colorScheme;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: colors.surface.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: colors.outline.withValues(alpha: 0.55),
            ),
          ),
          child: Text(
            RideHints.inGame,
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
        color: colors.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outline.withValues(alpha: 0.5)),
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
    return Text(
      text,
      style: TextStyle(
        color: color ?? colors.onSurface,
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _circleNavButton(IconData icon, VoidCallback onPressed) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
        border: Border.all(color: colors.outline.withValues(alpha: 0.55)),
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
        color: colors.surfaceContainerHighest.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.65)),
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
