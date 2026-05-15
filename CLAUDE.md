# CLAUDE.md

本文件为 Claude Code（claude.ai/code）在此仓库中工作时提供指导。

## 项目概览

基于 HarmonyOS NEXT（API 23 / 6.1.0）+ ArkTS/ArkUI V2 的多源音乐搜索与流媒体播放器。支持网易云音乐、QQ 音乐、Bilibili 三平台搜索与在线播放。目标 SDK：`6.1.0(23)`，包名：`com.example.miniplayer`。

## 构建与测试

- **构建**：使用 DevEco Studio 打开项目，Build → Run。构建系统为 Hvigor（`hvigorfile.ts`），不支持命令行直接构建。
- **运行单元测试**：DevEco Studio 中 Run → ohosTest，或项目根目录执行 `hvigorw test`。
- **运行单个测试**：测试框架为 `@ohos/hypium`（`describe`/`it`/`expect`）。单元测试位于 `entry/src/test/`，集成测试位于 `entry/src/ohosTest/`。
- **代码检查**：`code-linter.json5` 对所有 `**/*.ets` 文件启用 `@performance/recommended` 和 `@typescript-eslint/recommended` 规则集，并强制多项加密安全规则。

## ArkTS 严格编码约束（关键）

本项目在默认编译器规则之上强制执行更严格的 ArkTS 子集。**违反以下任何一条均会导致编译错误：**

1. 禁止无类型对象字面量 —— 每个 `{}` 必须对应一个显式声明的 `interface` 或 `class`。
2. 所有变量、参数、返回值必须显式标注类型，不允许隐式推断。
3. 先定义 interface，再声明该类型的变量，最后赋值。
4. interface 内部不允许内联对象字面量作为类型声明 —— 必须提取为独立命名的 interface。
5. 禁止对象展开 `{ ...obj }` —— 改为手动逐字段赋值。
6. `@Builder` 函数体内只允许 UI 组件语法（组件构造器、`if`/`else`、`ForEach`、事件回调），禁止普通变量声明或非 UI 语句。
7. interface 定义中所有内部对象类型必须提取为独立命名的 interface。
8. 禁止将对象字面量直接作为函数实参传递 —— 必须先赋值给带类型注解的变量。

## 架构

### 页面与路由树

```
EntryAbility → pages/Index（Navigation 根容器，NavPathStack）
  ├── SplashPage（3 秒倒计时启动页）
  └── MainPage（Tabs + 全局 PlayerBar）
        ├── Tab0: HomePage（8 个子频道 Swiper：心动/推荐/音乐/AI写歌/年报/播客/听书/午夜飞行）
        ├── Tab1: SearchPage（搜索源切换：网易云/QQ音乐/B站）
        ├── Tab2: 占位页面"笔记社区"
        └── Tab3: MinePage（三平台 Cookie 配置管理）
        └── PlayerBar（isPlayed=true 时显示，位于 TabBar 上方）
              → router.pushUrl → PlayerPage（全屏播放详情页）
```

页面跳转通过 `UIContext.getRouter().pushUrl()` 实现。MainPage 底部的自定义 TabBar 通过 `TabsController.changeIndex()` 控制 Tabs 切换。

### 状态架构（MVVM + @ObservedV2）

```
PlayerStateCenter（单例中间件，位于 common/）
  ├── 暴露: PlayerViewModel, currentSong
  ├── init() / release() —— 生命周期由页面管理
  └── play/pause/seek/togglePlayPause —— 统一播放控制 API

PlayerViewModel（@ObservedV2，位于 viewmodel/）
  ├── @Trace 字段: isPlaying, isPlayed, currentTime, duration, progressValue, isDragging
  ├── 封装 AVPlayerService（位于 service/）
  └── 管理播放源生命周期（本地 fd:// 与 流 URL）

AVPlayerService（位于 service/）
  └── 封装 @ohos.multimedia.media AVPlayer
      状态机: idle → initialized → prepared → playing ↔ paused → completed → idle
```

组件通过导入单例 `playerState` 实现响应式绑定：`MainPage`、`PlayerBar`、`PlayerPage` 均从 `common/PlayerStateCenter` 引入同一实例。`PlayerViewModel` 中任何 `@Trace` 字段的变化会自动同步到所有绑定的 UI 组件。

### 平台服务（service/）

每个平台服务导出为全局单例，均提供 `testCookie()` / `search()` / `getSongUrl()`（B 站为 `getAudioUrl`）：

| 服务 | 搜索 API | 流地址 API | 鉴权方式 |
|------|---------|-----------|---------|
| `NetEaseService` | POST cloudsearch/pc（x-www-form-urlencoded） | eapi `/song/enhance/player/url/v1`（AES-128-ECB 加密） | Cookie `MUSIC_U` |
| `QQMusicService` | POST musicu.fcg（JSON 信封，含 module/method） | music.vkey.GetVkey → purl + sip host | Cookie `uin`/`qm_keyst` |
| `BilibiliService` | GET wbi/search/type（tids=3 音乐分区） | GET player/playurl（fnval=16 DASH → `.m4a` 纯音频），流地址需带 `Referer` 请求头 | Cookie `SESSDATA` |

`HttpUtils` 封装 `@ohos.net.http`，提供 `get`/`postForm`/`postJson` 方法。所有服务接受 Headers 为 `Object` 类型（而非 `Record<string, string>`），以绕过 ArkTS 类型限制，`HttpUtils` 内部进行强制转换。

### Cookie 持久化

`CookieStorage` 基于 `@ohos.data.preferences`（存储名：`netEaseCookie`）。`model/Song.ets` 中的 `PLATFORM_LIST` 是平台配置的唯一数据源（storageKey、颜色、提示文本）。应用启动时（`Index.aboutToAppear`），从磁盘恢复三平台 Cookie 并自动注入各服务单例。

### 数据模型

`Song` 是核心数据模型 —— 所有平台将各自的原始 API 响应映射为这一统一结构。关键字段：`id`、`title`、`artist`、`album`、`duration`、`coverUrl`、`audioUrl`、`platform`、`sourceId`（平台原生 ID，如 QQ 的 songmid、B 站的 bvid）。

### 依赖

`oh-package.json5` 中仅声明了 `@ohos/hypium`（测试框架）和 `@ohos/hamock`（Mock 工具）。无其他第三方依赖。

## 关键文件

| 文件 | 职责 |
|------|------|
| `common/PlayerStateCenter.ets` | 单例中间件 —— 所有播放操作统一入口 |
| `viewmodel/PlayerViewModel.ets` | 响应式播放状态 + AVPlayerService 桥接 |
| `service/AVPlayerService.ets` | AVPlayer 封装 —— 播放状态机 + 事件回调 |
| `service/NetEaseService.ets` | 网易云搜索 + eapi 加密获取流地址 |
| `service/QQMusicService.ets` | QQ 音乐搜索 + 多音质 vkey 降级 |
| `service/BilibiliService.ets` | B 站搜索 + DASH 纯音频流获取 |
| `utils/HttpUtils.ets` | HTTP 客户端（get/postForm/postJson） |
| `utils/CryptoUtils.ets` | EAPI AES-128-ECB 加密 + MD5 摘要 |
| `utils/CookieStorage.ets` | 基于 Preferences 的 Cookie 持久化 |
| `model/Song.ets` | 全部数据模型 + 平台配置表 |
| `pages/SearchPage.ets` | 搜索 UI（平台切换 + 流地址解析） |
| `view/PlayerBar.ets` | Tab 栏上方的迷你播放条 |
| `pages/PlayerPage.ets` | 全屏播放详情页（含播放控制） |

## 已知技术债务

### 平台服务耦合（高优先级）

三平台服务（`NetEaseService` / `QQMusicService` / `BilibiliService`）未实现统一的 `PlatformService` 接口，导致以下两个页面成为耦合热点：

**SearchPage.ets —— 两处 if/else 链：**
- `performSearch()` (L180-188)：按 `Platform` 枚举分支调用不同服务的 `search()` 方法
- `playSong()` (L200-222)：双 if/else 链 —— 先分支获取流 URL（`getSongUrl` vs `getAudioUrl`，参数类型不一致），再分支判断是否需要 B 站专有的 Referer 请求头

**MinePage.ets —— 六处 if/else 链：**
- `getState()` / `setCookieInput()` / `updateStatus()` / `runTest()` / `updateTestState()` / `syncCookieToService()` 均按 `Platform` 枚举分支操作三个独立的 `@Local CookieState` 变量

**Index.ets —— 硬编码三平台恢复链：**
- `aboutToAppear()` 中逐一调用 `loadCookie` + `setCookie`，新增平台需手动添加

**影响**：新增第四个平台（如酷我、咪咕）需修改至少 5 个文件、约 15 处代码。

**建议方案**：在 `common/` 下引入 `PlatformService` 接口（统一 `search`/`getSongUrl`/`testCookie`/`setCookie` 签名）和 `ServiceRegistry`（按 Platform 查表），可将新平台改动降至 3 个文件，并启用编译期方法签名校验。

### 播放链（低风险）

`PlayerStateCenter → PlayerViewModel → AVPlayerService` 播放链解耦良好，新增平台对该链零改动。

### B 站 Referer 泄漏

`SearchPage.playSong()` 中硬编码了 B 站 CDN 的 Referer/User-Agent 请求头 (L213-216)。该 header 应由 `BilibiliService` 内部构造并随流 URL 一并返回，避免平台细节泄漏到页面层。

### ArkTS 合规

所有源文件通过 8 条严格模式规则。`SongItem.ets:9` 和 `PlayerStateCenter.ets:10` 存在对象字面量用于 `@Param` 默认值和类字段默认值，属编译器允许的边界情况。
