# NetEase Cloud Music — UI Structure Reference

> 提取自 HarmonyOS NEXT 版网易云音乐客户端（ArkTS/ArkUI V2），仅保留 UI 结构与后端交互接口定义，可作为任意平台复刻的参考文档。

---

## 目录

1. [架构概览](#1-架构概览)
2. [导航与路由](#2-导航与路由)
3. [页面详解](#3-页面详解)
   - [3.1 启动页 SplashPage](#31-启动页-splashpage)
   - [3.2 主页壳 MainPage](#32-主页壳-mainpage)
   - [3.3 侧边抽屉 DrawerPage](#33-侧边抽屉-drawerpage)
   - [3.4 首页 HomePage](#34-首页-homepage)
   - [3.5 发现页 DiscoveryPage](#35-发现页-discoverypage)
   - [3.6 音乐页 MusicsPage](#36-音乐页-musicspage)
   - [3.7 心动模式 FavoriteMusicPage](#37-心动模式-favoritemusicpage)
   - [3.8 AI写歌 AIWriterPage](#38-ai写歌-aiwriterpage)
   - [3.9 分类/搜索页 CategoryPage](#39-分类搜索页-categorypage)
   - [3.10 笔记页 NotePage](#310-笔记页-notepage)
   - [3.11 笔记详情 NoteDetailPage](#311-笔记详情-notedetailpage)
   - [3.12 我的 MinePage](#312-我的-minepage)
   - [3.13 WebView 页面](#313-webview-页面)
   - [3.14 专辑详情 AlbumDetailComponent](#314-专辑详情-albumdetailcomponent)
   - [3.15 占位页面](#315-占位页面)
4. [播放系统](#4-播放系统)
   - [4.1 迷你播放条 PlayerBar](#41-迷你播放条-playerbar)
   - [4.2 播放控制 PlayerActionView](#42-播放控制-playeractionview)
   - [4.3 歌曲卡片 SongCard](#43-歌曲卡片-songcard)
   - [4.4 播放状态 MusicPlaybackState](#44-播放状态-musicplaybackstate)
   - [4.5 播放控制器接口](#45-播放控制器接口)
5. [可复用组件库](#5-可复用组件库)
   - [5.1 分段选择器 SegmentedView](#51-分段选择器-segmentedview)
   - [5.2 横向滚动列表 ScrollRow / ScrollGroupRow](#52-横向滚动列表-scrollrow--scrollgrouprow)
   - [5.3 瀑布流 WaterFlow](#53-瀑布流-waterflow)
   - [5.4 导航栏组件](#54-导航栏组件)
   - [5.5 空状态组件](#55-空状态组件)
6. [数据模型全集](#6-数据模型全集)
7. [后端 API 接口合约](#7-后端-api-接口合约)
8. [全局状态](#8-全局状态)

---

## 1. 架构概览

```
EntryAbility (UIAbility 入口)
  └── Index (Navigation 根容器，NavPathStack 路由栈)
        ├── SplashPage        (启动闪屏，5秒倒计时)
        └── MainPage          (主界面，4个Tab)
              ├── Tab1: HomePage      (首页，8个子频道 Swiper)
              ├── Tab2: CategoryPage  (分类/搜索，瀑布流)
              ├── Tab3: NotePage      (笔记社区，瀑布流)
              ├── Tab4: MinePage      (我的，个人中心)
              ├── PlayerBar           (全局浮动迷你播放条)
              └── DrawerPage          (侧边抽屉菜单)
```

**关键设计模式：**
- 全局路由通过 `NavPathStack`（HarmonyOS Navigation）管理
- 跨组件通信使用 `@Provider` / `@Consumer` 和 `AppStorageV2`
- 列表复用通过 `LazyForEach` + `WaterFlowDataSource` / `HomeSegmentDataSource`
- 播放器全局单例 `MusicPlayerController` + 响应式状态 `MusicPlaybackState`

---

## 2. 导航与路由

| 路由名称 | 目标页面 | 参数类型 | 说明 |
|---------|---------|---------|------|
| `Splash` | SplashPage | 无 | 启动页，5秒后自动跳转 Main |
| `Main` | MainPage | 无 | 主界面，不含返回按钮 |
| `Web` | WebPage | `{ url: string }` | 内嵌 WebView |
| `NoteDetail` | NoteDetailPage | `NoteItem` | 笔记详情（底层页弹出） |

非路由页面（由父组件直接构建，不注册路由）：
- DiscoveryPage, MusicsPage, PodcastPage, AudiobookPlayerPage, AIWriterPage, MidnightFlightPage, FavoriteMusicPage（HomePage 内 Swiper 子页）
- MusicPlayerPage, SearchPage（独立页面，未接入路由）

---

## 3. 页面详解

### 3.1 启动页 SplashPage

**视觉结构：**

```
┌──────────────────────────────┐
│                              │
│      启动图片（全屏）          │
│      launch_image            │
│                              │
│                    ┌────────┐│
│                    │跳过 5  ││  ← 倒计时按钮，右上角
│                    └────────┘│
└──────────────────────────────┘
```

**行为：**
- 展示全屏启动图（`launch_image`），`ImageFit.Cover`
- 右上角倒计时按钮："跳过 N"，从 5 递减
- 点击按钮或倒计时归零 → `replacePathByName('Main')`
- 背景色：黑色

**涉及数据模型：** 无（纯 UI，无数据加载）

---

### 3.2 主页壳 MainPage

**视觉结构：**

```
┌──────────────────────────────┐
│                              │
│     Tab 内容区                 │
│     (HomePage / CategoryPage  │
│      / NotePage / MinePage)  │
│                              │
│              ┌──────────────┐│
│              │  PlayerBar   ││  ← 迷你播放条（条件显示）
│              └──────────────┘│
├──────────────────────────────┤
│  首页  │ 搜索  │ 笔记  │ 我的  │  ← 底部 TabBar（文字，无图标）
└──────────────────────────────┘
```

**Tab 配置数据模型 (`TabBarItem`)：**

```typescript
interface TabBarItem {
  id: string;           // '2025001' | '2025002' | '2025003' | '2025004'
  name: string;         // '首页' | '搜索' | '笔记' | '我的'
  color: ResourceColor; // 未选中色
  selectedColor: ResourceColor; // 选中色
}
```

**Tab 映射：**

| Tab ID | 名称 | 页面组件 |
|--------|------|---------|
| `2025001` | 首页 | HomePage |
| `2025002` | 搜索 | CategoryPage |
| `2025003` | 笔记 | NotePage |
| `2025004` | 我的 | MinePage |

**PlayerBar 显示条件：**
- 播放状态 `isPlayed === true`
- 且不处于 HomePage 的第一个子页面（心动模式页，index=0）—— 因为心动模式页自带完整播放 UI

**背景色：** TabBar 背景 `#EFEDF0`，圆角 `20`

---

### 3.3 侧边抽屉 DrawerPage

**视觉结构：**

```
┌──────────────────────────────┐
│ ░░░░░░░░░░░┌────────────────┤
│ ░ 半透明   │ 用户头像+昵称    │  ← header
│ ░ 遮罩     │ vx:xmzd2522     │
│ ░ (30%黑) │ [语音][扫描]    │
│ ░          ├────────────────┤
│ ░          │ 🔲 我的消息    │
│ ░          │ 🔲 我的云贝    │
│ ░          │    免费兑换...  │
│ ░          │ 🔲 装扮中心    │
│ ░          │ 🔲 创作者中心  │
│ ░          │ 🔲 AI写歌      │
│ ░          │ 🔲 最近播放    │
│ ░          │ 🔲 定时开关    │
│ ░          │ 🔲 商城        │
│ ░          │ 🔲 云村有票    │
│ ░          │ 🔲 云推歌      │
│ ░          │ 🔲 我的客服    │
│ ░          ├────────────────┤
│ ░          │ [设置] [更多]  │  ← 底部操作
│ ░          └────────────────┤
└──────────────────────────────┘
```

**触发方式：**
- 点击各页面导航栏左侧菜单图标 → 设置 `GlobalDrawerState.isDrawerOpen = true`
- 点击半透明遮罩 → 关闭抽屉
- 动画：300ms EaseOut 滑入/滑出

**菜单项结构：**
```typescript
{
  icon: Resource;       // 图标
  title: string;        // 标题
  desc?: string;        // 副标题（可选）
  hasDivider: boolean;  // 是否显示底部分隔线
  position: 'top' | 'middle' | 'bottom'; // 位置（控制圆角）
}
```

**菜单列表：**

| 图标 | 标题 | 副标题 |
|------|------|--------|
| cm4_list_subscribed_Normal | 我的消息 | - |
| cm6_lay_icn_shopping_cart_Normal | 我的云贝 | 免费兑换黑胶VIP |
| cm8_setting_skinSquare_Normal | 装扮中心 | 守护甜心装扮 |
| album_normal | 创作者中心 | - |
| cm4_leaveInfo_Normal | AI写歌 | - |
| cm7_more_icon_giftcard_Normal | 最近播放 | - |
| cm6_set_icn_ring_tone_Normal | 定时开关 | - |
| cm8_playlist_menu_delete_Normal | 商城 | - |
| cm6_set_icn_coupon_Normal | 云村有票 | - |
| cm4_edit_keyboard_prs_Normal | 云推歌 | - |
| cm8_btm_icn_event_Normal | 我的客服 | - |

**背景色：** 抽屉内容 `#F4F6F9`，菜单项白色，圆角 8px

---

### 3.4 首页 HomePage

**视觉结构：**

```
┌──────────────────────────────┐
│ [☰] ── SegmentedView ── [🔍]│  ← HomeNavBar（左菜单/中分段/右搜索）
├──────────────────────────────┤
│                              │
│     Swiper 内容区              │
│     (8个子页面，横向滑动)       │
│                              │
└──────────────────────────────┘
```

**分段选择器（SegmentedView）子频道（8个）：**

| 索引 | ID | 名称 | 页面组件 |
|------|------|------|---------|
| 0 | `20025001` | 心动 | FavoriteMusicPage |
| 1 | `20025002` | 推荐 | DiscoveryPage |
| 2 | `20025003` | 音乐 | MusicsPage |
| 3 | `20025006` | AI写歌 | AIWriterPage |
| 4 | `20025007` | 年报 | WebComponent（掘金专栏） |
| 5 | `20025004` | 播客 | PodcastPage |
| 6 | `20025005` | 听书 | AudiobookPlayerPage |
| 7 | `20025008` | 午夜飞行 | MidnightFlightPage |

**默认选中：** 索引 1（"推荐"）

**联动机制：**
- SegmentedView 点击 → Swiper 切换
- Swiper 滑动 → SegmentedView 指示器跟随
- 动画曲线：EaseOut 250ms

**数据模型 (`SegmentItem`)：**
```typescript
interface SegmentItem {
  id: string;
  name: string;
}
```

---

### 3.5 发现页 DiscoveryPage

**视觉结构：**

```
┌──────────────────────────────┐
│  ↑ 纵向滚动 (Scroll)         │
│                              │
│  ┌─── RecommendView ───────┐ │
│  │ 横向 List:               │ │
│  │ [每日推荐][漫游][歌单推荐] │ │
│  │ [私人雷达][心动模式]...   │ │
│  └──────────────────────────┘ │
│                              │
│  场景歌单                      │
│  "专属你的「治愈」精选"         │
│  ┌─ ScrollRow: 横向滑动卡片 ─┐ │
│  │ [卡片][卡片][卡片]...     │ │
│  └──────────────────────────┘ │
│                              │
│  回忆歌单                      │
│  ┌─ ScrollRow: 横向滑动卡片 ─┐ │
│  │ [卡片][卡片][卡片]...     │ │
│  └──────────────────────────┘ │
│                              │
│  专属歌单                      │
│  ┌─ ScrollRow: 横向滑动卡片 ─┐ │
│  │ [卡片][卡片][卡片]...     │ │
│  └──────────────────────────┘ │
│                              │
│  热门节目推荐                   │
│  ┌─ ScrollGroupRow: 横向群组 ┐ │
│  │ [组1][组2][组3]...        │ │
│  └──────────────────────────┘ │
└──────────────────────────────┘
```

**数据加载（onAppear 时触发，并行请求）：**

| 方法 | 用途 | 数据类型 |
|------|------|---------|
| `getTopList()` | 回忆歌单数据 | `TopListItem[]` |
| `getRecommendPlaylist()` | 推荐歌单数据 | `RecommendItem[]` |
| `getNewSongs()` | 场景歌单数据 | `RecommendItem[]` |
| `getPrivateContent()` | 专属歌单数据 | `PersonalItem[]` |
| `getPersonalMV()` | 热门节目/新碟 | `MVItem[]` |

**卡片组件对应关系：**

| 区块 | 卡片组件 | 容器 | 高度 | 每项宽度 |
|------|---------|------|------|---------|
| 推荐 | RecommendView 内联 | List(横向) | 210 | 160 |
| 场景歌单 | PlaylistCard | ScrollRow | 200 | 160 |
| 回忆歌单 | MemoryCard | ScrollRow | 220 | 160 |
| 专属歌单 | PlaylistCard | ScrollRow | 200 | 160 |
| 热门节目 | GroupCard | ScrollGroupRow | 210 | 96%屏宽 |

---

#### 卡片组件详情

**PlaylistCard** — 场景/专属歌单卡片：

```
┌─────────────┐
│ [封面图片]   │
│ ♪ 10.6万    │  ← 左上角：播放量 + 图标
│      [▶]    │  ← 右下区域：播放按钮
├─────────────┤
│ 歌单标题     │  ← 底部 25% 白色区域
└─────────────┘
```

- Props: `item: RowEntity`
- 尺寸：宽 160，高 200

**MemoryCard** — 回忆歌单卡片：

```
┌─────────────┐
│ 标题文字      │  ← 左上角：白色文字
│ [封面图片]   │
├─────────────┤
│ 描述文字      │  ← 底部 25%：毛玻璃效果 + 白色文字
└─────────────┘
```

- Props: `item: RowEntity`
- 尺寸：宽 160，高 220

**RecommendView** — 推荐卡片：

```
┌──────────────┐
│ [封面图片]    │
│ 标签文字      │  ← 左上角：白色粗体，如"每日推荐"
│              │
│ [免费听] [▶] │  ← 中部偏下：条件标签+播放按钮
├──────────────┤
│ 推荐名称      │  ← 底部 26%：毛玻璃 + 居中文字
└──────────────┘
```

- Props:
  - `recommendItems: RecommendItem[]`
  - `onRecommendSelect: (index, item) => void`
- 尺寸：宽 160，高度由父组件控制 (210)
- 6 个固定标签名循环：`['每日推荐', '漫游', '歌单推荐', '私人雷达', '心动模式', '每日博客']`
- 索引 0 显示 "免费听" 标签
- 索引 0/2/5 显示播放按钮

**GroupCard** — 群组卡片（热门节目/新碟）：

```
┌──────────────────────────────┐
│ [封面]  标题          [▶]    │
│         描述                  │
├──────────────────────────────┤
│ [封面]  标题          [▶]    │
│         描述                  │
├──────────────────────────────┤
│ [封面]  标题          [▶]    │
│         描述                  │
└──────────────────────────────┘
```

- Props:
  - `items: RowEntity[]`（一个数组，纵向排列 3 行）
  - `onCardSelect: (item, index) => void`
- 每行：封面图(正方形, 80%高) + 标题(粗体) + 描述(灰色) + 播放按钮

---

### 3.6 音乐页 MusicsPage

**视觉结构：**

```
┌──────────────────────────────┐
│  ↑ 纵向滚动 (Scroll)         │
│                              │
│  ┌── 横幅轮播 Swiper ──────┐ │
│  │ [Banner 1][Banner 2]... │ │
│  │       ● ○ ○ ○           │ │  ← DotIndicator
│  └──────────────────────────┘ │
│                              │
│  ┌── 分类网格 Swiper ──────┐ │
│  │ [分类1][分类2][分类3]... │ │  4列 Grid
│  │ [分类5][分类6][分类7]... │ │
│  └──────────────────────────┘ │
│                              │
│  歌单 / 精选歌单               │
│  ┌─ ScrollRow: 横向滑动卡片 ─┐ │
│  │ [Card][Card][Card]...    │ │
│  └──────────────────────────┘ │
│                              │
│  新碟 / 新歌新碟 >            │
│  ┌─ ScrollGroupRow ─────────┐ │
│  │ [GroupCard][GroupCard].. │ │
│  └──────────────────────────┘ │
└──────────────────────────────┘
```

**数据加载（onAppear 时触发）：**

| 方法 | 用途 | 数据类型 |
|------|------|---------|
| `getMusicBanners()` | 横幅数据 | `BannerItem[]` |
| `getCateList()` | 分类网格数据 | `CateItem[][]`（分页二维数组） |

**横幅 BannerItem 数据模型：**
```typescript
interface BannerItem {
  bannerId: string;
  pic: string;        // 图片URL
  bannerBizType: string;
  url: string;        // 点击跳转URL（WebView打开）
}
```

**分类 CateItem 数据模型：**
```typescript
interface CateItem {
  id: number;
  name: string;
}
```
- 以 `CateItem[][]` 形式分页，每页 8 个（4列 × 2行）
- 分类以 Swiper 分页形式展示（非滚动）
- 每个分类：文字居中，黑色边框、4px 圆角

**横幅 Swiper 配置：**
- 自动轮播：是
- 圆点指示器：`DotIndicator`，6×6px，灰色/白色
- 宽高比：3:2
- 边距：12px padding
- 点击 → pushPathByName('Web', { url })

---

### 3.7 心动模式 FavoriteMusicPage

完整的黑胶唱片播放体验页面。

**视觉结构：**

```
┌──────────────────────────────┐
│    背景：当前专辑封面模糊       │
│    (blur=700 + 30%黑色遮罩)   │
│                              │
│         ═══════              │
│      ═══  唱针  ═══          │  ← 唱针图片（播放时角度0，暂停时-30°）
│    ══            ══          │
│   ═    ┌──────┐    ═         │
│  ═     │ 唱片 │     ═        │  ← 唱片背景圆盘
│  ═     │ ┌──┐ │     ═        │
│  ═     │ │封│ │     ═        │  ← 旋转的 SongCard（72×72 圆角封面）
│  ═     │ │面│ │     ═        │
│   ═    │ └──┘ │    ═         │
│    ══  └──────┘  ══          │
│      ════════════            │
│                              │
│  歌曲名                        │  ← 左侧：歌曲名 + 歌手名 + "关注"按钮
│  歌手名          ♥ 999w+      │  ← 右侧：收藏数/评论数/更多按钮
│                  💬 99w+  ⋯  │
│                              │
│  ════════════════════════    │
│  ===●===============○===     │  ← Slider 进度条
│  00:42          03:20         │  ← 时间显示
│                              │
│     ⏮     ▶/⏸     ⏭        │  ← 播放控制按钮
│                              │
└──────────────────────────────┘
```

**核心交互状态：**
- 唱片旋转动画：播放时持续旋转，暂停时停止
- 唱针动画：播放时角度 0°（落下），暂停时 -30°（抬起），500ms 过渡
- Swiper 横向滑动切歌
- 播放状态托管给全局 `MusicPlayerController`

**数据来源：** 复用 `DiscoveryPage` 的 `scenePlaylist`（RecommendItem[]），每项包含歌曲详情

**子组件：**
- `SongCard({ coverImage })` — 唱片上的封面
- `PlayerActionView({ songItem, actionCallback })` — 底部播放控制条

---

### 3.8 AI写歌 AIWriterPage

**视觉结构：**

```
┌──────────────────────────────┐
│  ┌──────────┐ ┌──────────┐  │
│  │ 🎵 我的创作│ │ 🏆 我的积分│  │  ← 两个操作按钮
│  └──────────┘ └──────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │ 一句话写歌词 │ 填词写歌 │  │  ← 分段选择器（中间项高亮）
│  │              │  纯音乐  │  │
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │                        │  │
│  │  TextArea 输入框        │  │  ← 提示词输入
│  │  placeholder:           │  │
│  │  "分享你的创作灵感..."   │  │
│  │                        │  │
│  │  ── or ──              │  │
│  │                        │  │
│  │  [AI生成的歌词结果]      │  │  ← 结果显示区（条件显示）
│  │                        │  │  ← 右上角关闭按钮
│  └────────────────────────┘  │
│                              │
│  ┌────────────────────────┐  │
│  │  生成歌词 (3积分）       │  │  ← 提交按钮（红色胶囊）
│  │  or LoadingProgress     │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

**交互流程：**
1. 用户在 TextArea 输入灵感提示词
2. 点击"生成歌词"按钮 → 调 DeepSeek API（SSE 流式）
3. 加载中显示 `LoadingProgress`
4. 结果区域覆盖在输入框上方，显示 AI 生成的歌词
5. 可点击关闭按钮清除结果、重新输入
6. 结果可复制（`copyOption: LocalDevice`）

**按钮启用条件：** 输入框非空 且 非加载状态

**错误处理：** 出错时弹出 AlertDialog

**数据模型：**
```typescript
// 输入
interface AIWriterViewModel {
  prompt: string;         // 用户输入的提示词
  lyricsText: string;     // AI 返回的歌词
  isLoading: boolean;     // 加载状态
  errorMessage: string;   // 错误消息
}
```

---

### 3.9 分类/搜索页 CategoryPage

Tab 栏显示为"搜索"，实际是音乐分类浏览页。

**视觉结构：**

```
┌──────────────────────────────┐
│  [☰] ┌────────────────┐ [🎤]│  ← HomeNavBar
│      │🔍 抖音热歌精选   │     │  ← 搜索栏（圆角灰色背景，不可输入）
│      └────────────────┘     │
├──────────────────────────────┤
│                              │
│  ┌── SearchHeaderView ────┐ │
│  │  [分类1][分类2]...[分类N]│ │  ← 顶部分类图标行
│  └────────────────────────┘ │
│                              │
│  ┌── WaterFlow ───────────┐ │
│  │  [卡片] [卡片]          │ │  ← 双列瀑布流
│  │  [卡片] [卡片]          │ │
│  │  [卡片] [卡片]          │ │
│  │  ...                   │ │
│  └────────────────────────┘ │
└──────────────────────────────┘
```

**SearchHeaderView** — 顶部分类：

```
┌────┬────┬────┬────┬────┐
│ 🎵 │ 🎤 │ 🎸 │ 🥁 │ 🎹 │
│分类1│分类2│分类3│分类4│分类5│
└────┴────┴────┴────┴────┘
```
- 每个分类：30×30 图标 + 6px 间距 + 文字
- 水平等分布局

**SearchCard** — 瀑布流卡片：

```
┌──────────┐
│          │
│ 专辑封面  │
│          │
│ 专辑名称  │  ← 左下区域
│ 发行公司  │
└──────────┘
```

**数据加载：**
- `loadData()` 在 `aboutToAppear` 触发
- 分类数据（SearchTopCate）：来自 mock / API
- 瀑布流数据（SearchCardItem[]）：来自歌单详情 API（默认 `id=19723756` 云音乐飙升榜）

**下拉刷新：** 支持

---

### 3.10 笔记页 NotePage

**视觉结构：**

```
┌──────────────────────────────┐
│ [SegmentedView: 分类选择]  [🔍][+]│  ← HomeNavBar
├──────────────────────────────┤
│                              │
│  Swiper（根据分类切换）        │
│                              │
│  分类0: "施工中..."           │
│                              │
│  分类1+:                     │
│  ┌── WaterFlow ───────────┐ │
│  │  [NoteCard] [NoteCard] │ │  ← 双列瀑布流
│  │  [NoteCard] [NoteCard] │ │
│  │  ...                   │ │
│  └────────────────────────┘ │
│                              │
│  ┌── NoteDetailPage ──────┐ │  ← 条件覆盖
│  │  (全屏弹出详情)          │ │
│  └────────────────────────┘ │
└──────────────────────────────┘
```

**NoteCard** — 笔记卡片：

```
┌──────────────┐
│              │
│  预览图片     │  ← aspectRatio 自适应
│  (带共享元素  │  ← geometryTransition(id)
│   过渡动画)   │
│              │
├──────────────┤
│ 标签文字      │  ← 最多2行，fontSize 16
├──────────────┤
│ 👤网易云  ♥42│  ← 底部：用户名 + 点赞数
└──────────────┘
```

- 点击 NoteCard → 显示 NoteDetailPage（全屏覆盖，带共享元素动画 + 淡入过渡）
- 支持下拉刷新和加载更多

---

### 3.11 笔记详情 NoteDetailPage

```
┌──────────────────────────────┐
│  ← 笔记详情                   │  ← NavBar（返回按钮）
│                              │
│  ┌────────────────────────┐  │
│  │                        │  │
│  │    笔记大图              │  │  ← geometryTransition 共享元素
│  │    (全宽展示)            │  │
│  │                        │  │
│  └────────────────────────┘  │
│                              │
└──────────────────────────────┘
```

- 全屏白色背景
- 返回触发 `onBack` 回调（由 NotePage 控制隐藏动画）
- 共享元素动画：`geometryTransition(noteId, { follow: true })`

---

### 3.12 我的 MinePage

**视觉结构：**

```
┌──────────────────────────────┐
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░│  ← headerBackground（背景图，动态伸缩）
│ ░  [☰]      [头像][昵称][🔍][⋮]│  ← MineNavBar（透明度随滚动变化）
│ ░                            │
│ ░      ┌────┐                │
│ ░      │头像│                │  ← 80×80 圆形头像，白色边框
│ ░      └────┘                │
│ ░      朽木自雕               │  ← 昵称
│ ░                            │
│ ░   "地球之所以是圆的..."      │  ← 个性签名
│ ░                            │
│ ░      18枚勋章               │
│ ░                            │
│ ░  30关注  9粉丝  Lv.8  1520小时│  ← 统计数据行
│ ░                            │
│ ░  [我的音乐][我的播客][我的笔记]│  ← 菜单标签行（半透明背景）
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
├──────────────────────────────┤
│ ┌── SegmentedView ─────────┐ │
│ │  音乐  │  播客  │  笔记    │ │  ← 白色背景，顶部圆角
│ └──────────────────────────┘ │
│                              │
│  Swiper（3个tab页）           │
│                              │
│  音乐Tab:                     │
│  ┌── MineMusicCard ────────┐ │
│  │ [封面] 我喜欢的音乐       │ │  ← 第一个固定为"我喜欢的音乐"
│  │         177首·3350次播放 │ │
│  │                     [⋮] │ │
│  ├─────────────────────────┤ │
│  │ [封面] 歌单名称          │ │
│  │         歌曲数·播放次数  │ │
│  │                     [⋮] │ │
│  └─────────────────────────┘ │
│                              │
│  播客Tab: 空状态              │
│  笔记Tab: 空状态              │
└──────────────────────────────┘
```

**滚动联动效果：**
- 背景图随向下滚动而伸展（`scrollY < 0` 时）
- 导航栏背景透明度 `navBgAlpha` 随滚动从 0 → 1（阈值点后渐变）
- `MineNavBar` 中用户信息区域在滚动超过阈值后以 `opacity(navBgAlpha)` 显示

**MineNavBar** — 随滚动渐显的导航栏：

```
┌──────────────────────────────┐
│ [☰]  [头像] 朽木自雕  [🔍][⋮]│
└──────────────────────────────┘
```

**SegmentedView 三个标签：**

| ID | 名称 | 组件 | 状态 |
|----|------|------|------|
| `2000811` | 音乐 | MineMusicComponent | 展示歌单列表 |
| `2000812` | 播客 | MinePodcastComponent | 空状态 |
| `2000813` | 笔记 | MineNoteComponent | 空状态 |

**MineMusicCard** — 歌单列表项：

```
┌──────────────────────────────┐
│ [60×60封面]  歌单名称    [⋮] │
│              177首·3350次播放 │
└──────────────────────────────┘
```

- 列表项高度 80px
- 第一个固定为"我喜欢的音乐"

**数据模型 (`MineFavItem`)：**
```typescript
interface MineFavItem {
  id: number;
  name: string;
  picUrl: string;
  trackCount: number;
}
```

**数据模型 (`MenuItem`)：**
```typescript
interface MenuItem {
  id: string;
  icon: ResourceStr;
  title: string;
}
```

---

### 3.13 WebView 页面

**WebPage** — NavDestination 包装器：

```
┌──────────────────────────────┐
│ ← {title}                    │  ← 导航栏（WebView 标题）
├──────────────────────────────┤
│                              │
│     WebView                  │
│     (加载指定 URL)            │
│                              │
└──────────────────────────────┘
```

**WebComponent** — 可复用 WebView：

```typescript
interface WebParams {
  url: string;
}
```
- Props: `url: string`, `webController`, `onTitleUpdate: (title) => void`
- 基于 HarmonyOS `webview.WebviewController`

---

### 3.14 专辑详情 AlbumDetailComponent

当前为占位状态：

```
┌──────────────────────────────┐
│ ← (返回按钮)                  │
│                              │
│     EmptyComponent           │
│     (空状态插画)              │
│                              │
└──────────────────────────────┘
```

- 通过 PlayerBar 的 `bindSheet` 以半屏形式弹出
- 预期扩展为完整专辑详情页（歌曲列表、专辑信息等）

---

### 3.15 占位页面

以下页面当前仅为简单占位（空 Column 或轻微内容）：

| 页面 | 文件 | 备注 |
|------|------|------|
| PodcastPage | PodcastPage.ets | 空 Column |
| AudiobookPlayerPage | AudiobookPlayerPage.ets | 空 Column |
| MidnightFlightPage | MidnightFlightPage.ets | 空 Column |
| MusicPlayerPage | MusicPlayerPage.ets | 预留，未接入 |
| SearchPage | SearchPage.ets | 预留，未接入 |

---

## 4. 播放系统

### 4.1 迷你播放条 PlayerBar

浮动在 MainPage 底部 TabBar 上方。

```
┌────────────────────────────────────┐
│ ┌──┐                              │  ← 渐变背景 (#F2F2F2 → 透明)
│ │封│  歌曲名 - 歌手名...            │  ← 歌曲名滚动跑马灯
│ │面│                              │
│ └──┘          ⏸/▶   📋          │  ← 右侧：播放暂停(环形进度) + 播放列表
└────────────────────────────────────┘
```
- 高度 48px，圆角 24px，毛玻璃效果
- 封面旋转动画（播放时 2°/150ms 持续旋转）
- 歌曲名 Marquee 跑马灯（播放时滚动）
- 环形进度条围绕播放/暂停按钮
- 点击封面 → bindSheet 弹出 AlbumDetailComponent（半屏）
- 点击列表图标 → bindSheet 弹出播放列表

**播放列表 Sheet：**

```
┌──────────────────────────────┐
│  当前播放  │  历史播放         │  ← 标题栏（"当前播放"下方有黑色指示条）
├──────────────────────────────┤
│  歌曲名 • 歌手名       [✕]   │  ← 当前播放项红色，其他黑色
│  歌曲名 • 歌手名       [✕]   │
│  歌曲名 • 歌手名       [✕]   │
│  ...                         │
└──────────────────────────────┘
```
- 点击歌曲 → 切歌
- 点击 ✕ → 从播放列表移除
- 高度自适应：≤8首用计算高度，>8首用 70%

---

### 4.2 播放控制 PlayerActionView

```
┌──────────────────────────────┐
│ ═══════●═══════════○═══      │  ← Slider（白色主题）
│  00:42             03:20     │  ← 时间
│                              │
│      ⏮      ▶      ⏭       │  ← 控制按钮（居中排列）
└──────────────────────────────┘
```

- Props:
  - `songItem: SongItem` — 当前歌曲
  - `actionCallback: (type, value?) => void` — 回调
    - `type: 'play' | 'pause' | 'prev' | 'next' | 'seek'`
    - `value: number` — seek 时的目标毫秒数
- Slider 拖动时锁定 UI（防止 `timeUpdate` 覆盖）
- 时间格式化：`MusicUtil.musicTimeFormatter(ms)` → `mm:ss`

---

### 4.3 歌曲卡片 SongCard

```
┌─────────────────┐
│    ═══════      │
│  ══  CD底  ══   │  ← 75% 宽 CD 底盘图
│ ═   ┌──┐   ═    │
│═    │封│    ═   │  ← 52% 宽圆形封面
│ ═   │面│   ═    │
│  ══ └──┘ ══     │
│    ═══════      │
└─────────────────┘
```

- Props: `coverImage: ResourceStr`

---

### 4.4 播放状态 MusicPlaybackState

全局响应式状态（`AppStorageV2` 连接）：

```typescript
class MusicPlaybackState {
  cover: string;          // 音乐封面 URL
  name: string;           // 歌曲名
  author: string;         // 作者
  url: string;            // 歌曲音频 URL
  time: number;           // 当前播放进度 (ms)
  duration: number;       // 歌曲总时长 (ms)
  playbackMode: '顺序播放' | '单曲循环' | '随机播放';
  isPlaying: boolean;     // 是否正在播放
  isPlayed: boolean;      // 是否有过播放历史
  isLoading: boolean;     // 是否加载中
  currentIndex: number;   // 当前播放索引
  playlist: SongItem[];   // 播放列表

  // 计算属性
  currentSongId: number;  // 当前歌曲ID（-1 表示无）
}
```

---

### 4.5 播放控制器接口

`MusicPlayerController`（全局单例，封装 HarmonyOS `media.AVPlayer`）：

```typescript
// 核心方法（语义接口，具体实现依赖平台）
interface IMusicPlayerController {
  // 加载并播放指定索引的歌曲
  loadSong(index: number): void;

  // 切换播放/暂停
  togglePlay(): void;

  // 添加歌曲到播放列表末尾
  addSongsToEnd(songs: SongItem[], playNow: boolean): void;

  // 从播放列表移除歌曲
  removeSong(songId: number): void;

  // 拖动进度
  seekTo(timeMs: number): void;

  // 获取当前播放状态
  playbackState: MusicPlaybackState;
}
```

`AVSessionManager` — 系统媒体会话管理（锁屏控制、后台播放任务）

---

## 5. 可复用组件库

### 5.1 分段选择器 SegmentedView

```
 推荐   音乐   AI写歌   播客   听书
 ═══                            ← 指示器（底部线条）
```

**配置接口：**

```typescript
// 数据项
interface SegmentItem {
  id: string;
  name: string;
}

// 样式配置
class SegmentedStyle {
  indicatorWidth: number;           // 指示器宽度
  indicatorHeight: number;          // 指示器高度（默认 3）
  indicatorColor: ResourceColor;    // 指示器颜色（默认黑色）
  indicatorVerticalGap: number;
  indicatorHorizontalInset: number; // 水平内缩（默认 26）
  contentPadding: Padding;          // 文字内边距
  contentNormalColor: ResourceColor; // 非选中色（默认 #8E8E93）
  contentSelectedColor: ResourceColor; // 选中色（默认黑色）
  spaceGap: number;                 // 项间距
}

// 控制器
class SegmentController {
  selectIndex(index: number, animated: boolean): void;
  setScrollOffset(offset: number): void; // Swiper 滑动联动
}
```

**Props：**
```typescript
{
  items: SegmentItem[];
  selectedIndex: number;
  segmentController: SegmentController;
  style?: SegmentedStyle;
  onSegmentSelect?: (index: number) => void;
}
```

**特性：**
- 水平可滚动（项多时）
- 指示器跟随选项宽度 + 水平内缩
- 支持 Swiper 联动（通过 SegmentController 的 offset 接口实现指示器平滑过渡）
- 动画：300ms FastOutSlowIn

---

### 5.2 横向滚动列表 ScrollRow / ScrollGroupRow

**ScrollRow** — 单项横向列表：

```typescript
interface ScrollRowProps {
  items: RowEntity[];              // 数据源
  itemExtent: Length;             // 每项宽度
  itemSpace: number;              // 项间距
  cardBuilder: (item, index) => void; // 卡片构建器（@BuilderParam）
  onCardSelect?: (item, index) => void;
}
```

**ScrollGroupRow** — 分组横向列表（每组包含多个 RowEntity）：

```typescript
interface ScrollGroupRowProps {
  itemsGroup: RowEntity[][];      // 分组数据
  itemExtent: Length;             // 每组宽度（如 '96%'）
  itemSpace: number;
  cardBuilder: (items[], groupIndex) => void; // 组卡片构建器
}
```

**RowEntity 接口（所有列表项数据的基础）：**
```typescript
interface RowEntity {
  id: string | number;
  title: string;
  coverImgUrl: string;
  description: string;
}
```

---

### 5.3 瀑布流 WaterFlow

由四个文件组成：`WaterFlowComponent` / `WaterFlowDataSource` / `WaterFlowItem` / `WaterFlowReusableContainer`

**核心接口：**

```typescript
interface WaterFlowItem {
  // 基础接口，具体数据模型需实现
}

interface WaterFlowSection {
  items: WaterFlowItem[];
  columns?: number; // 列数
}
```

**WaterFlowComponent Props：**
```typescript
{
  isRefreshing: boolean;           // 下拉刷新状态
  isLoadingMore?: boolean;         // 加载更多状态
  dataSource: IDataSource;         // LazyForEach 数据源
  waterFlowSections: WaterFlowSection[];
  itemBuilder: (item, index) => void;      // 卡片构建器
  headerBuilder?: (item, index) => void;   // 头部构建器（如分类行）
  getItemReuseId: (item, index) => string; // 复用ID
  onRefresh?: () => void;          // 下拉刷新回调
  onLoadMore?: () => void;         // 加载更多回调
}
```

---

### 5.4 导航栏组件

**HomeNavBar** — 通用导航栏（首页/搜索/笔记页使用）：

```
┌──────────────────────────────┐
│ [☰]     titleView      [右侧]│
└──────────────────────────────┘
```

```typescript
{
  titleView: () => void;   // @BuilderParam，中间内容（最大宽度 70%）
  rightView: () => void;   // @BuilderParam，右侧内容
}
```
- 左侧固定为菜单图标（☰），点击 → 打开 DrawerPage
- 白色背景，48px 高

**MineNavBar** — "我的"页面专用导航栏：

```
┌──────────────────────────────┐
│ [☰]  [头像] 朽木自雕  [🔍][⋮]│
└──────────────────────────────┘
```

```typescript
{
  isDark: boolean;     // 是否深色模式
  bgAlpha: number;     // 背景透明度（0~1，滚动联动）
}
```

**NavBar** — 通用返回式导航栏（详情页使用）：

```
┌──────────────────────────────┐
│ [‹]  标题文字                 │
└──────────────────────────────┘
```

```typescript
{
  title: ResourceStr;
  onBack: () => void;  // 默认 pop()
}
```

---

### 5.5 空状态组件

**EmptyComponent** — 统一的空状态插画：

```
┌──────────────────────────────┐
│                              │
│       [empty 插图]           │
│                              │
└──────────────────────────────┘
```

白色背景，居中显示空状态图片。

---

## 6. 数据模型全集

### 6.1 歌曲相关

```typescript
interface SongItem {
  id: number;
  name: string;
  position: number;
  alias: string[];
  status: number;
  fee: number;
  copyrightId: number;
  disc: string;
  no: number;
  artists: ArtistItem[];
  album: AlbumItem;
  duration: number;       // 时长 (ms)
  popularity: number;
  score: number;
  starredNum: number;
  playedNum: number;
  dayPlays: number;
  hearTime: number;
}

interface ArtistItem {
  id: number;
  name: string;
  picId: number;
  img1v1Id: number;
  briefDesc: string;
  picUrl: string;
  img1v1Url: string;
  albumSize: number;
  alias: string[];
  trans: string;
  musicSize: number;
  topicPerson: number;
}

class AlbumItem implements RowEntity {
  id: number;
  name: string;
  type: string;
  size: number;
  picId: number;
  blurPicUrl: string;    // 模糊封面（用于播放页背景）
  companyId: number;
  picUrl: string;        // 封面图
  description: string;
  tags: string;
  company: string;       // 发行公司
  artist: ArtistItem;
  songs: string[];
  alias: string[];
  status: number;
  copyrightId: number;
  artists: ArtistItem[];
  subType: string;
  transName: string;
  onSale: boolean;
  mark: number;

  // RowEntity 兼容属性
  get title(): string;       // → name
  get coverImgUrl(): string; // → picUrl
}
```

### 6.2 首页相关

```typescript
class RecommendItem implements RowEntity {
  id: number;
  type: number;
  name: string;
  picUrl: string;
  canDislike: boolean;
  alg: string;
  song: SongItem | undefined;

  get title(): string;       // → name
  get coverImgUrl(): string; // → picUrl
  get description(): string; // → ''
}

class TopListItem implements RowEntity {
  id: number;
  name: string;
  description: string;
  coverImgUrl: string;

  get title(): string;       // → name
}

class MVItem implements RowEntity {
  id: number;
  type: number;
  name: string;
  copywriter: string;    // 文案描述
  picUrl: string;
  playCount: number;
  artists: ArtistItem[];
  artistName: string;
  artistId: number;
  alg: string;

  get title(): string;       // → name
  get coverImgUrl(): string; // → picUrl
  get description(): string; // → copywriter
}

class PersonalItem implements RowEntity {
  id: number;
  url: string;
  picUrl: string;
  sPicUrl: string;       // 小图
  type: number;
  copywriter: string;
  name: string;

  get title(): string;       // → name
  get coverImgUrl(): string; // → sPicUrl
  get description(): string; // → copywriter
}

interface BannerItem {
  bannerId: string;
  pic: string;
  bannerBizType: string;
  url: string;

interface CateItem {
  id: number;
  name: string;
}
```

### 6.3 搜索相关

```typescript
interface SearchTopCate {
  id: string;
  title: string;
  icon: string;          // 图标资源路径
}

class SearchCardItem implements WaterFlowItem {
  id: string | number;
  topCates: SearchTopCate[];   // 顶部分类（仅 Header 项有此数据）
  album: AlbumItem;
}
```

### 6.4 笔记相关

```typescript
class NoteItem {
  id: number;
  pageURL: string;
  tags: string;
  previewURL: string;
  previewWidth: number;
  previewHeight: number;
  webformatURL: string;
  webformatWidth: number;
  webformatHeight: number;
  largeImageURL: string;
  imageWidth: number;
  imageHeight: number;
  imageSize: number;
  views: number;
  collections: number;
  likes: number;
  comments: number;
  userImageURL: string;
  user_id: number;
}
```

### 6.5 我的相关

```typescript
interface MineFavItem {
  id: number;
  name: string;
  picUrl: string;
  trackCount: number;
}

interface MenuItem {
  id: string;
  icon: ResourceStr;
  title: string;
}
```

### 6.6 通用

```typescript
interface SegmentItem {
  id: string;
  name: string;
}

interface TabBarItem {
  id: string;
  name: string;
  color: ResourceColor;
  selectedColor: ResourceColor;
}

interface RowEntity {
  id: string | number;
  title: string;
  coverImgUrl: string;
  description: string;
}
```

---

## 7. 后端 API 接口合约

> 当前代码在 DEBUG 模式下使用 mock 数据，生产模式调用 `https://music.163.com/api`。
> 以下为每个接口的请求/响应合约，可供其他项目实现对应的后端。

### 通用响应格式

```typescript
// 标准格式
interface BaseResponse<T> {
  code: number;      // 200 = 成功
  message: string;
  data: T;
}

// 列表结果
interface AppResultsResponse<T> {
  code: number;
  result: T[];
}

// 单个结果
interface AppResultResponse<T> {
  code: number;
  result: T;
}

// List 包装
interface AppListResponse<T> {
  code: number;
  list: T[];
}

// Album 包装
interface AppAlbumResponse<T> {
  code: number;
  albums: T[];
}
```

---

### 7.1 首页 - 排行榜

```
GET /toplist
```

**响应：**
```json
{
  "code": 200,
  "list": [
    {
      "id": 19723756,
      "name": "云音乐飙升榜",
      "description": "云音乐飙升榜",
      "coverImgUrl": "https://..."
    }
  ]
}
```
**返回类型：** `BaseResponse<AppListResponse<TopListItem>>`

---

### 7.2 首页 - 推荐歌单

```
GET /personalized/playlist?limit=10
```

**响应：**
```json
{
  "code": 200,
  "result": [
    {
      "id": 123456,
      "type": 0,
      "name": "歌单名称",
      "picUrl": "https://...",
      "canDislike": false,
      "alg": "推荐算法标识",
      "song": null
    }
  ]
}
```
**返回类型：** `BaseResponse<AppResultsResponse<RecommendItem>>`

---

### 7.3 首页 - 新歌推荐

```
GET /personalized/newsong
```

**响应：**
```json
{
  "code": 200,
  "result": [
    {
      "id": 123456,
      "name": "歌曲名",
      "picUrl": "https://...",
      "song": {
        "id": 789,
        "name": "歌曲名",
        "duration": 240000,
        "artists": [{ "id": 1, "name": "歌手名" }],
        "album": {
          "id": 100,
          "name": "专辑名",
          "picUrl": "https://...",
          "blurPicUrl": "https://..."
        }
      }
    }
  ]
}
```
**返回类型：** `BaseResponse<AppResultsResponse<RecommendItem>>`

---

### 7.4 首页 - 独家内容

```
GET /personalized/privatecontent
```

**响应：**
```json
{
  "code": 200,
  "result": [
    {
      "id": 123,
      "name": "独家内容名",
      "picUrl": "https://...",
      "sPicUrl": "https://...",
      "copywriter": "文案描述"
    }
  ]
}
```
**返回类型：** `BaseResponse<AppResultsResponse<PersonalItem>>`

---

### 7.5 首页 - 推荐MV

```
GET /personalized/mv
```

**响应：**
```json
{
  "code": 200,
  "result": [
    {
      "id": 123,
      "name": "MV名称",
      "copywriter": "MV简介",
      "picUrl": "https://...",
      "playCount": 100000,
      "artistName": "歌手名",
      "artistId": 456
    }
  ]
}
```
**返回类型：** `BaseResponse<AppResultsResponse<MVItem>>`

---

### 7.6 首页 - 新碟上架

```
GET /top/playlist?limit=10&order=new
```

**响应：**
```json
{
  "code": 200,
  "albums": [
    {
      "id": 123,
      "name": "专辑名",
      "picUrl": "https://...",
      "blurPicUrl": "https://...",
      "company": "发行公司",
      "artists": [{ "id": 1, "name": "歌手名" }]
    }
  ]
}
```
**返回类型：** `BaseResponse<AppAlbumResponse<AlbumItem>>`

---

### 7.7 首页 - 横幅

```
GET /banner  (当前为纯 mock)
```

**响应：**
```json
[
  {
    "bannerId": "xxx",
    "pic": "https://...",
    "bannerBizType": "type",
    "url": "https://..."
  }
]
```
**返回类型：** `BannerItem[]`

---

### 7.8 分类/搜索 - 歌单详情

```
GET /playlist/detail?id={playlistId}
```

默认查询 ID: `19723756`（云音乐飙升榜），其他榜单 ID：
- `3779629` — 云音乐新歌榜
- `3778678` — 云音乐热歌榜
- `2250011882` — 抖音排行榜

**响应：**
```json
{
  "code": 200,
  "result": {
    "tracks": [
      {
        "id": 123,
        "album": {
          "id": 456,
          "name": "专辑名",
          "picUrl": "https://...",
          "company": "发行公司"
        }
      }
    ]
  }
}
```
**返回类型：** `BaseResponse<AppResultResponse<SearchCardResultResponse>>`

---

### 7.9 AI写歌 - DeepSeek 流式 API

```
POST https://api.deepseek.com/v1/chat/completions
```

**请求头：**
```
Content-Type: application/json
Authorization: Bearer {API_KEY}
Accept: text/event-stream
```

**请求体：**
```json
{
  "model": "deepseek-chat",
  "messages": [
    {
      "role": "user",
      "content": "用户输入的提示词"
    }
  ],
  "stream": true
}
```

**响应：** SSE (Server-Sent Events) 流式数据
```
data: {"choices":[{"delta":{"content":"歌词片段"}}]}

data: [DONE]
```

**需要后端提供的等价接口：**
```typescript
// 请求
interface AIWriterRequest {
  prompt: string;          // 用户输入的创作灵感
}

// 回调
type StreamCallback = (chunk: string) => void;
type StatusCallback = (status: {
  status: 'started' | 'streaming' | 'completed' | 'error';
  message: string;
  error?: Error;
}) => void;

// 接口方法
function generateLyrics(
  prompt: string,
  onChunk: StreamCallback,
  onStatusChange: StatusCallback
): Promise<void>;
```

---

### 7.10 我的 - 用户歌单

```
GET /user/playlist?uid={userId}
```
**返回类型：** `MineFavItem[]`（当前 mock 实现）

---

### 7.11 笔记 - 笔记列表

```
GET /notes  (需自行实现)
```
**返回类型：** `NoteItem[]`（当前 mock 实现，使用 Pixabay API 格式）

---

## 8. 全局状态

### AppStorageV2 连接的状态

| Key | 类型 | 用途 |
|-----|------|------|
| `MusicPlaybackState` | `MusicPlaybackState` | 全局播放状态（所有播放相关组件共享） |
| `GlobalDrawerState` | `GlobalDrawerState` | 侧边抽屉开关状态 |

### 事件总线 (emitter)

| 事件 ID | 数据 | 用途 |
|---------|------|------|
| `EVENT_ID_TAB_SEGMENT_INDEX_DATA` | `{ segmentIdx: number }` | Tab 切到首页时恢复上次子频道索引 |

### @Provider / @Consumer 层级

```
Index (pathStack)
  └── HomePage (viewModel: HomeViewModel)
  │     └── DiscoveryPage / MusicsPage / ... (消费 viewModel)
  ├── CategoryPage (viewModel: CategoryViewModel)
  │     └── WaterFlowComponent (消费 viewModel)
  ├── NotePage
  │     └── NoteDetailPage
  └── MinePage
```

---

## 附录：配色与设计 Token

| 用途 | 颜色值 |
|------|--------|
| 页面主背景 | `#F4F6F9` |
| TabBar 背景 | `#EFEDF0` |
| 卡片/导航栏背景 | `Color.White` |
| 主文字色 | `Color.Black` |
| 次要文字色 | `#8E8E93` |
| 灰色文字 | `Color.Gray` |
| 半透明黑 | `#4D000000` (30%) / `#80000000` (50%) |
| AI写歌主色 | `#F44336` (红色) |
| AI写歌背景 | `#F7F8FA` |
| AI写歌按钮 | `#C8CAD1` |
| 抽屉背景 | `#F4F6F9` |
| 分隔线 | `#F2F2F2` |
| 进度条底色 | `#D8D8D8` |
| 半透明遮罩 | `#33000000` (20%) |
| 白色半透明 | `#B3FFFFFF` (70%) |
| 播放页遮罩 | `rgba(0,0,0,0.3)` |
| 播放页模糊 | `blur(700)` |
| Slider 轨道 | `#80FFFFFF` (50%白) |

---

> **文档版本：** 基于 `e:\Homo\HarmonyOS-NetEase-Cloud-Music` (commit: master branch, 2026-05-01)
> **原作者：** Finn Guo (朽木自雕)
> **包含文件：** 77 个 .ets 源文件，21 个数据模型，19 个页面，25 个可复用视图组件，5 个服务层文件
