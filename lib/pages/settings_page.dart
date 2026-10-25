import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../game/ride_style.dart';
import '../models/difficulty.dart';
import '../providers/game_provider.dart';
import '../providers/settings_provider.dart';
import '../services/file_system_service.dart';
import '../services/log_service.dart';
import '../utils/constants.dart';
import '../utils/ride_hints.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _logContent = '';
  String _logDir = '';

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _loadLogDir();
  }

  Future<void> _loadLogs() async {
    final logs = LogService.getRecentLogs();
    if (mounted) {
      setState(() => _logContent = logs.join('\n'));
    }
  }

  Future<void> _loadLogDir() async {
    try {
      final dir = await FileSystemService.instance.getLogRoot();
      if (!mounted) return;
      setState(() => _logDir = dir.path);
    } catch (e, stack) {
      LogService.error('读取日志目录失败', e, stack);
    }
  }

  bool get _canOpenDir =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final settings = context.watch<SettingsProvider>();
    final game = context.read<GameProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          const _SectionHeader(title: '外观'),
          SwitchListTile(
            title: const Text('深色模式'),
            subtitle: const Text('切换深色/浅色主题'),
            value: settings.darkMode,
            onChanged: settings.toggleDarkMode,
            secondary: Icon(
              settings.darkMode ? Icons.dark_mode : Icons.light_mode,
              color: colors.primary,
            ),
          ),
          const Divider(),
          const _SectionHeader(title: '音效'),
          SwitchListTile(
            title: const Text('静音'),
            subtitle: const Text('关闭音效与背景音乐'),
            value: settings.muted,
            onChanged: settings.setMuted,
            secondary: Icon(
              settings.muted ? Icons.volume_off : Icons.volume_up,
              color: colors.primary,
            ),
          ),
          const Divider(),
          const _SectionHeader(title: '骑行难度'),
          ...Difficulty.values.map((difficulty) {
            return RadioListTile<Difficulty>(
              title: Text(difficulty.label),
              subtitle: Text(difficulty.description),
              value: difficulty,
              groupValue: settings.difficulty,
              onChanged: (value) {
                if (value == null) return;
                settings.setDifficulty(value);
                game.setDifficulty(value);
              },
              secondary: Icon(
                difficultyIcon(difficulty),
                color: colors.primary,
              ),
            );
          }),
          const Divider(),
          const _SectionHeader(title: '玩法'),
          ..._buildPlayHints(),
          const Divider(),
          const _SectionHeader(title: '关于'),
          ListTile(
            leading: Icon(Icons.info_outline, color: colors.primary),
            title: const Text('版本'),
            trailing: const Text(AppConstants.version),
          ),
          if (_logDir.isNotEmpty)
            _buildDirTile(
              theme,
              icon: Icons.folder_special,
              title: '日志目录',
              path: _logDir,
              hint: '出现问题时可提供此目录下日志文件',
            ),
          ListTile(
            leading: Icon(Icons.description_outlined, color: colors.primary),
            title: const Text('查看日志'),
            subtitle: const Text('查看应用运行日志'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLogDialog(context),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  /// 玩法说明按平台切换：桌面讲按键，移动端讲触屏手势。
  List<Widget> _buildPlayHints() {
    final jumpIcon =
        isDesktopPlatform ? Icons.keyboard_arrow_up : Icons.touch_app_outlined;
    return <Widget>[
      ListTile(
        leading: Icon(jumpIcon),
        title: const Text('跳跃与二段跳'),
        subtitle: Text(RideHints.jump),
      ),
      ListTile(
        leading: const Icon(Icons.keyboard_arrow_down),
        title: const Text('俯身'),
        subtitle: Text(RideHints.duck),
      ),
      ListTile(
        leading: const Icon(Icons.pause_circle_outline),
        title: const Text('暂停'),
        subtitle: Text(RideHints.pause),
      ),
    ];
  }

  Widget _buildDirTile(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String path,
    required String hint,
  }) {
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            path,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            hint,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 10,
            ),
          ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.copy, color: theme.colorScheme.primary),
            tooltip: '复制路径',
            onPressed: () => _copyText(context, path),
          ),
          if (_canOpenDir)
            IconButton(
              icon: Icon(Icons.open_in_new, color: theme.colorScheme.primary),
              tooltip: '打开目录',
              onPressed: () async {
                final ok = await FileSystemService.instance.openDirectory(path);
                if (!ok && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('当前平台不支持打开目录')),
                  );
                }
              },
            ),
        ],
      ),
    );
  }

  void _copyText(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showLogDialog(BuildContext context) {
    _loadLogs();
    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppBar(
                    title: const Text('应用日志'),
                    automaticallyImplyLeading: false,
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () {
                          _loadLogs();
                          setDialogState(() {});
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        tooltip: '复制全部',
                        onPressed: () => _copyText(ctx, _logContent),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: SelectableText(
                        _logContent.isEmpty ? '暂无日志' : _logContent,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }
}
