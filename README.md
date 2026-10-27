# 鹈鹕骑单车 🚴

一只鹈鹕骑着单车沿海岸线疾驰的 2.5D 躲避小游戏，基于 Flutter 与 Flame
开发，支持 Android、Windows 与 Web 三平台。玩法坐标、碰撞与计分都在世界空间
（10 单位 = 1 米）中计算，画面用固定机位的等距投影、程序化精灵与多层视差
滚动来呈现海岸公路的纵深，不再依赖 Flutter GPU 或 flutter_scene。

## 玩法

- 单车自动前进，速度随距离逐渐提升。
- 点击 / 上滑 / 空格 / ↑ 起跳，空中再按一次可二段跳；长按跳得更高。
- 下滑 / ↓ / S 俯身，穿过低垂的横幅；空中俯身会快速下落。
- 躲开礁石、木箱、浮木与横幅，收集小鱼获得额外分数。
- 连续吃鱼会累积连击倍率，最高 ×5。
- 拾取护盾可抵挡一次撞击，拾取磁铁会吸附附近的小鱼。
- 撞上障碍即结束，记录本局得分、距离与最高分。

## 功能

- 🧊 固定机位 2.5D：等距路面 + 侧视角色，前进方向保持水平
- 🧱 单层精灵：低多边形道具与椰树烘焙成一张 `Picture`，每帧只画一次
- 🎞️ 3D 装饰器：骑行者套 `Rotate3DDecorator`，带轻微偏航与透视
- 🌅 多层视差：云、远山、海浪、路面与近景草丛按不同倍率滚动
- 🖼️ 画布铺满：Flame 画布填满整个页面，HUD 按钮与计分悬浮在地图之上
- 📐 画幅适配：水平方向始终铺满，近方形画布（折叠屏展开）上下留白，不裁短左右可视距离
- ⚡ 渲染开销：静态图层按设备像素比烘焙，云 / 山脊 / 波光 / 路面装饰按平铺带绘制，暂停与结算停掉主循环
- 🧭 平台自适应提示：桌面讲键盘按键，移动端讲点击与滑动
- 🪟 沉浸 HUD：得分 / 距离 / 最高 / 小鱼贴顶显示，半透明悬浮层，开局提示数秒后自动淡出
- 🌇 强化夕阳：更大的日轮、放射状阳光与海面反光
- 🐟 海面远景：远离海岸的水面时而有鱼跃出
- 🛣️ 单向单车道：收窄的沥青带配沙石路肩，地面箭头指示行车方向
- 🧹 障碍与沿路草丛、碎石、椰树都完全离开画面后才回收，不会在镜头里突然消失
- 🐟 小鱼、护盾、磁铁三类拾取物与连击计分
- 😮 吃鱼张嘴：拾取小鱼时上下颌短暂张开再合拢，露出深色口腔
- 🪧 地面障碍与悬空横幅两种躲避方式（跳跃 / 俯身）
- 🎞️ 二段跳、可变跳跃高度、俯身加速下坠
- 💥 撞击慢动作、镜头震动、红闪与结算遮罩
- ⏱️ 开局 3-2-1-GO 倒计时与暂停遮罩
- 🏅 排行榜、最高分与最远距离持久化
- 🌓 深色 / 浅色主题与三档难度
- 🎵 程序化生成音效与循环背景音乐，无需外部音频资源
- 📝 日志按日落盘到用户目录 `BirdOnABike/logs/`
- 📱 手机进入游玩页自动锁定横屏并沉浸全屏，返回后恢复原方向
- 🖥️ 手机、折叠屏、平板与桌面自适应布局
- 🌐 简体中文界面
- 🕹️ Web 版：发布 tag 自动构建并部署到 GitHub Pages，每个 tag 一个独立版本

## 操作

| 平台    | 跳跃         | 二段跳       | 俯身         | 暂停       |
|---------|--------------|--------------|--------------|------------|
| Windows | 空格 / ↑ / W | 空中再按一次 | ↓ / S / Ctrl | P / Esc    |
| Web     | 空格 / ↑ / W | 空中再按一次 | ↓ / S        | P / Esc    |
| Android | 点击 / 上滑  | 空中再点一次 | 向下滑动     | 右上角暂停 |

手机进入游玩页会自动切换到横屏并隐藏系统栏，画布铺满整屏；点击与滑动在
整个游戏画面上生效，HUD 按钮浮在画面上方。退出后恢复原方向。

## 下载

最新版本 `v0.7.0` 将通过 GitHub Actions 与 Gitea Actions 自动构建：

- Android APK（arm64-v8a）
- Windows ZIP（x86-64）
- Web 版（GitHub Pages 在线试玩；Gitea Release 另附 `-web.zip` 归档）

发布后可在仓库的 Releases 页面下载对应产物。

### 在线试玩

推送到 GitHub 的每个 `v*` tag 都会额外构建 Web 版并发布到 GitHub Pages，
各版本互不覆盖，历史版本长期保留：

- 版本列表：<https://g-ai-002.github.io/bird-on-a-bike/>
  （首页顶部是最新正式版本的醒目入口，点开即玩；下方分「正式版本」与
  「调试版本」两列，历史正式版本从新到旧排列）
- 当前版本：<https://g-ai-002.github.io/bird-on-a-bike/v0.7.0/>
- 预览版：<https://g-ai-002.github.io/bird-on-a-bike/debug/>

非 tag 触发（手动运行 `Build & Release` 工作流）构建出来的站点会发到 `debug/`
目录，方便合并前验证效果；tag 触发时除了更新 `v<版本>/`，还会把 Web 产物
`<仓库名>-<版本>-web.zip` 一并归档到 GitHub Release，与 APK、Windows ZIP 放在一起。

Pages 首次使用需在仓库 Settings → Pages 里把发布来源设为 `gh-pages` 分支的
根目录；之后每次推送 tag 都会自动更新站点（含版本索引页与 `versions.json`）。

## 开发

### 环境要求

- Flutter 3.47.7+（内置 Dart 3.13.5+）
- Android SDK 37+（minSdk 35）
- Windows 10+
- 浏览器（Chrome / Edge / Safari 均可运行 Web 版）

### 运行

```bash
flutter pub get
flutter run
```

Android 与 Windows 使用同一套 Flame 渲染，无需开启 Flutter GPU，也不再需要
平台侧的额外开关。Windows 与 Web 平台文件不入库，首次本地构建前先执行：

```bash
flutter create --platforms=windows,web --project-name bird_on_a_bike .
```

浏览器里预览与构建 Web 版（`--base-href` 需与线上路径一致，否则资源 404）：

```bash
flutter run -d chrome
flutter build web --release --base-href /bird-on-a-bike/v0.7.0/
```

### 渲染结构

| 图层 | 组件 | 作用 |
|------|------|------|
| 留白 | `LetterboxComponent` | 近方形画布上下补天空色与近景墨色 |
| 远景 | `SkyBackdropComponent` | 渐变天空、落日、云、远山、灯塔与海面 |
| 路面 | `RoadComponent` | 单向单车道沥青带、沙石路肩、地面箭头、椰树与草丛 |
| 实体 | `RideEntitiesComponent` | 骑行者、障碍与拾取物，按路面深度排序 |
| 近景 | `ShoreForegroundComponent` | 画面下沿的草丛与碎石剪影 |
| 特效 | `SpeedLines` / `WheelSpray` / `Vignette` 等 | 屏幕空间速度线、水雾、暗角与粒子 |

世界坐标约定与投影见 `lib/game/world_layout.dart`、`lib/game/iso_projection.dart`；
道具画法与精灵烘焙见 `lib/game/painting/`、`lib/game/rendering/`。

### 测试与静态检查

```bash
flutter analyze
flutter test
```

### 发布

推送 `v*` 标签会触发 GitHub Actions 与 Gitea Actions 双流水线：

- GitHub Actions：Android APK、Windows ZIP、Web 版（发布到 GitHub Pages 并把 `-web.zip` 归档到 Release），并创建 GitHub Release
- Gitea Actions：Android APK、Windows ZIP、Web ZIP（Gitea 没有 Pages，Web 版只打包成
  `-web.zip` 归档到 Release），并创建 Gitea Release

```bash
git tag v0.7.0
git push origin v0.7.0
```

Web 版按 tag 分目录保存在 `gh-pages` 分支（`v0.7.0/`、`v0.6.0/` …），根目录的
版本索引页由 `.github/pages/index.template.html` 渲染，每次发布都会重新生成：
顶部是最新正式版本的醒目入口，点开即玩；下方左列「正式版本」按从新到旧列出
全部历史 tag，右列「调试版本」只放一条 `debug` 预览；
非 tag 运行（手动触发）写入 `debug/` 目录、不碰已有版本，同一时刻只允许一个
Web 发布任务写 `gh-pages`，避免并发覆盖。

Gitea Release 里的 `-web.zip` 用默认根路径构建，解压后在目录内起静态服务器
（如 `python -m http.server`）即可访问，不做在线托管。

应用内版本号位于 `lib/utils/constants.dart` 的 `AppConstants.version`，发版时需与
`pubspec.yaml` 的 `version` 同步。

## 技术栈

- Flutter 3.47.7（Android / Windows / Web）
- Flame 1.38.2（游戏主循环、组件树、3D 装饰器、输入与遮罩）
- 自绘 Canvas 精灵（程序化低多边形画法 + `Picture` 烘焙）
- Provider 状态管理
- Material 3 设计
- SharedPreferences 持久化
- audioplayers 音效播放
- window_manager 桌面窗口管理
- 条件导入隔离平台能力：`dart:io`、`path_provider`、`window_manager` 只进 IO 实现
- GitHub Pages 多版本站点：每个 tag 一个子目录，根目录自动生成版本索引

## 许可证

MIT
