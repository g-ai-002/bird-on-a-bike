import 'dart:io';

/// 当前是否运行在桌面平台；其余平台一律按触屏处理。
bool get isDesktopPlatform =>
    Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// 各界面展示的玩法提示：桌面端讲按键，移动端讲触屏手势。
class RideHints {
  RideHints._();

  /// 主界面底部的一句话提示。
  static String get home => isDesktopPlatform
      ? '空格 / ↑ 跳跃，空中再按一次二段跳；↓ / S 俯身穿过横幅'
      : '点击或上滑跳跃，再点一次二段跳；下滑俯身穿过横幅';

  /// 游戏画面底部的开局提示，几秒后自动淡出。
  static String get inGame => isDesktopPlatform
      ? '空格 / ↑ 跳跃（可二段跳）· 长按跳更高 · ↓ 俯身 · P 暂停'
      : '点击 / 上滑跳跃 · 下滑俯身 · 右上角暂停';

  /// 设置页：跳跃与二段跳。
  static String get jump => isDesktopPlatform
      ? '空格 / ↑ / W 起跳，空中再按一次可二段跳；松开按键跳得更矮'
      : '点击或上滑起跳，空中再点/上滑一次可二段跳；长按跳得更高';

  /// 设置页：俯身。
  static String get duck => isDesktopPlatform
      ? '↓ / S 按住俯身，穿过低垂的横幅；空中俯身会快速下落'
      : '下滑俯身，穿过低垂的横幅；空中下滑会快速下落';

  /// 设置页：暂停。
  static String get pause => isDesktopPlatform
      ? 'P / Esc 暂停，再按一次回到骑行'
      : '点右上角暂停按钮，再点一次回到骑行';
}
