import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/constants.dart';
import '../utils/ride_hints.dart';
import '../widgets/pelican_badge.dart';
import 'game_page.dart';
import 'leaderboard_page.dart';
import 'settings_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final highScore =
        context.select<GameProvider, int>((game) => game.state.highScore);
    final bestDistance =
        context.select<GameProvider, double>((game) => game.state.bestDistance);
    final darkMode =
        context.select<SettingsProvider, bool>((settings) => settings.darkMode);
    final difficulty = context
        .select<SettingsProvider, String>((settings) => settings.difficultyLabel);
    final settings = context.read<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(AppConstants.appName),
        actions: [
          IconButton(
            icon: Icon(darkMode ? Icons.light_mode : Icons.dark_mode),
            tooltip: darkMode ? '切换浅色模式' : '切换深色模式',
            onPressed: () => settings.toggleDarkMode(!darkMode),
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = math.min(constraints.maxWidth, 360.0);
                      return Center(
                        child: PelicanBadge(
                          size: Size(width, width * 0.64),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '鹈鹕骑单车',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '海风、单车，还有一路的小鱼',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const GamePage()),
                        );
                      },
                      icon: const Icon(Icons.pedal_bike),
                      label: const Text(
                        '开始骑行',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const LeaderboardPage(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.emoji_events_outlined),
                      label: const Text('排行榜'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: colors.outline),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _HomeStat(
                            label: '最高分',
                            value: '$highScore',
                          ),
                        ),
                        _divider(colors),
                        Expanded(
                          child: _HomeStat(
                            label: '最远距离',
                            value: '${bestDistance.floor()} m',
                          ),
                        ),
                        _divider(colors),
                        Expanded(
                          child: _HomeStat(
                            label: '难度',
                            value: difficulty,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    RideHints.home,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _divider(ColorScheme colors) {
    return Container(
      width: 0.5,
      height: 32,
      color: colors.outline,
    );
  }
}

class _HomeStat extends StatelessWidget {
  const _HomeStat({required this.label, required this.value});

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
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colors.primary,
              ),
        ),
        const SizedBox(height: 2),
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
