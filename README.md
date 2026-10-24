# 鹈鹕骑单车 🚴

一只鹈鹕骑着单车沿海岸线疾驰的横版躲避小游戏，基于 Flutter + Flame 开发，
支持 Android 与 Windows 双平台。

## 玩法

- 单车自动前进，速度随距离逐渐提升。
- 点击 / 空格 / ↑ 起跳，空中再按一次可二段跳；长按跳得更高。
- 下滑 / ↓ / S 俯身，穿过低垂的横幅；空中俯身会快速下落。
- 躲开礁石、木箱、浮木与横幅，收集小鱼获得额外分数。
- 连续吃鱼会累积连击倍率，最高 ×5。
- 拾取护盾可抵挡一次撞击，拾取磁铁会吸附附近的小鱼。
- 撞上障碍即结束，记录本局得分、距离与最高分。

## 功能

- 🚴 Flame 组件化渲染：天空、海面、远山、路面与骑行者分层绘制
- 🌅 黄昏海岸视差背景：云、海浪、山影随速度滚动
- 🐟 小鱼、护盾、磁铁三类拾取物与连击计分
- 🪧 地面障碍与悬空横幅两种躲避方式（跳跃 / 俯身）
- 🎞️ 二段跳、可变跳跃高度、俯身加速下坠
- 💥 撞击慢动作、镜头震动、红闪与结算遮罩
- ⏱️ 开局 3-2-1-GO 倒计时与暂停遮罩
- 🎨 手绘鹈鹕与自行车：蹬踏、扇翅、围巾、护盾与磁铁光效
- 🏅 排行榜、最高分与最远距离持久化
- 🌓 深色 / 浅色主题与三档难度
- 🎵 程序化生成音效与循环背景音乐，无需外部音频资源
- 📝 日志按日落盘到用户目录 `BirdOnABike/logs/`
- 📱 手机、折叠屏、平板与桌面自适应布局
- 🌐 简体中文界面

## 操作

| 平台    | 跳跃         | 二段跳       | 俯身         | 暂停       |
|---------|--------------|--------------|--------------|------------|
| Windows | 空格 / ↑ / W | 空中再按一次 | ↓ / S / Ctrl | P / Esc    |
| Android | 点击画面     | 空中再点一次 | 向下滑动     | 右上角暂停 |

## 下载

首个版本 `v0.1.0` 通过 CI 验证后，将通过 GitHub Actions 与 Gitea Actions 自动构建：

- Android APK（arm64-v8a）
- Windows ZIP（x86-64）

发布后可在仓库的 Releases 页面下载对应产物。

## 开发

### 环境要求

- Flutter 3.47.7+（内置 Dart 3.13.5+）
- Android SDK 37+（minSdk 35）
- Windows 10+

### 运行

```bash
flutter pub get
flutter run
```

Windows 平台文件不入库，首次本地构建前先执行：

```bash
flutter create --platforms=windows --project-name bird_on_a_bike .
```

### 测试与静态检查

```bash
flutter analyze
flutter test
```

### 发布

推送 `v*` 标签会触发 GitHub Actions 与 Gitea Actions 双流水线，分别构建 Android APK
与 Windows ZIP，并在对应平台创建 Release：

```bash
git tag v0.1.0
git push origin v0.1.0
```

应用内版本号位于 `lib/utils/constants.dart` 的 `AppConstants.version`，发版时需与
`pubspec.yaml` 的 `version` 同步。

## 技术栈

- Flutter 3.47.7
- Flame 1.38.2（组件化渲染、游戏主循环与输入）
- Provider 状态管理
- Material 3 设计
- SharedPreferences 持久化
- audioplayers 音效播放
- window_manager 桌面窗口管理

## 许可证

MIT
