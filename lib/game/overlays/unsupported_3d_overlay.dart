import 'package:flutter/material.dart';

/// Flutter GPU / flutter_scene 初始化失败时的提示。
///
/// 3D 场景不可用时不启动玩法，也不再回退到 2D 渲染。
class Unsupported3DOverlay extends StatelessWidget {
  const Unsupported3DOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return SizedBox.expand(
      child: ColoredBox(
        color: Colors.black.withValues(alpha: 0.72),
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 18),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.view_in_ar_outlined, size: 40, color: colors.primary),
                const SizedBox(height: 10),
                Text(
                  '无法启动 3D 场景',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '当前设备或构建没有可用的 Flutter GPU。\n'
                  '请使用支持 Impeller 的设备，或在启动时加上 '
                  '--enable-flutter-gpu。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('返回'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
