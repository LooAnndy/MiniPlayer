# MiniPlayer — 鸿蒙聚合音乐播放器

基于 **HarmonyOS NEXT API 23** + **ArkTS V2** 的多源音乐搜索与流媒体播放器。直接对接网易云音乐、QQ音乐后端 API，支持关键词搜索、Cookie 持久化鉴权、在线流播放。

---

## 功能

| 模块 | 状态 | 说明 |
|------|------|------|
| 网易云搜索 + 播放 | 已完成 | cloudsearch/pc + eapi 加密获取流地址 |
| QQ 音乐搜索 + 播放 | 已完成 | musicu.fcg + vkey 获取流地址 |
| Bilibili | 预留 | API 已分析，待接入 |
| Cookie 持久化 | 已完成 | Preferences 存储，三平台独立管理 |
| 多源切换 | 已完成 | 搜索页内置网易云/QQ/B站切换条 |
| 流播放 | 已完成 | AVPlayer 直连 CDN 流地址 |
| 进度条 | 已完成 | PlayerBar 顶部线性进度 + 环形进度 |
| 全屏播放页 | 已完成 | 黑胶唱片风格 |
| 下载管理 | 预留 | 页面已就绪 |

---

## 项目结构

```
entry/src/main/ets/
├── pages/
│   ├── Index.ets              # 启动页（3s 倒计时 → MainPage）
│   ├── MainPage.ets           # 主 Tab 壳（首页/搜索/笔记/我的 + PlayerBar）
│   ├── HomePage.ets           # 首页（分段选择器 + 推荐/歌单）
│   ├── SearchPage.ets         # 搜索页（关键词搜索 + 平台切换条）
│   ├── PlayerPage.ets         # 全屏播放页（唱片 + 唱针动画）
│   ├── MinePage.ets           # 我的页（三平台 Cookie 配置与测试）
│   └── DownloadPage.ets       # 下载管理页（预置 UI）
├── service/
│   ├── AVPlayerService.ets    # 音频播放引擎（状态机 + 流播放）
│   ├── NetEaseService.ets     # 网易云 API（搜索 + EAPI 加密获取流）
│   └── QQMusicService.ets     # QQ 音乐 API（搜索 + vkey 获取流）
├── view/
│   ├── PlayerBar.ets          # 底部迷你播放条（进度 + 封面 + 控制）
│   └── SongItem.ets           # 歌曲列表项
├── viewmodel/
│   └── PlayerViewModel.ets    # 播放器 ViewModel（状态/进度/拖拽）
├── model/
│   └── Song.ets               # 数据模型（Song / Platform / PlatformInfo / PLATFORM_LIST）
└── utils/
    ├── HttpUtils.ets           # HTTP 封装（GET / POST form / POST JSON）
    ├── CryptoUtils.ets         # EAPI 加密（AES-128-ECB + MD5）
    ├── CookieStorage.ets       # Cookie Preferences 持久化
    └── FileUtils.ets           # 本地文件选取与 fd 播放
```

---

## API 对接

### 网易云音乐

| 接口 | URL | 方法 | 加密 |
|------|-----|------|------|
| 搜索 | `music.163.com/api/cloudsearch/pc` | POST form | 否 |
| 播放地址 | `interface3.music.163.com/eapi/song/enhance/player/url/v1` | POST form | **EAPI** |

### QQ 音乐

| 接口 | URL | 方法 | 加密 |
|------|-----|------|------|
| 搜索 | `u.y.qq.com/cgi-bin/musicu.fcg` | POST JSON | 否 |
| 播放地址 | `u.y.qq.com/cgi-bin/musicu.fcg` | POST JSON | 否 |

---

## 快速开始

1. 安装 DevEco Studio + HarmonyOS SDK (API 23)
2. 克隆项目，DevEco 打开 `MiniPlayer/` 目录
3. Build → Run 到模拟器或真机
4. 首次使用：进入"我的"→ 填写各平台 Cookie → 点击「测试连接」→ 验证通过
5. 搜索歌曲 → 点击播放

### Cookie 获取

| 平台 | Cookie 关键字段 | 获取方式 |
|------|----------------|---------|
| 网易云 | `MUSIC_U` | 浏览器登录 music.163.com → F12 → Cookies |
| QQ 音乐 | `uin` + `qm_keyst` | 浏览器登录 y.qq.com → F12 → Cookies |

---

## 技术栈

| 维度 | 方案 |
|------|------|
| UI 框架 | ArkTS V2 (`@ComponentV2` / `@Local` / `@Param` / `@Event`) |
| 音频引擎 | `@ohos.multimedia.media` AVPlayer |
| 网络请求 | `@ohos.net.http` |
| 加密 | `@ohos.security.cryptoFramework` (AES-128-ECB + MD5) |
| 持久化 | `@ohos.data.preferences` |
| 权限 | `ohos.permission.INTERNET` |

---

## 免责声明

本项目仅供 HarmonyOS 开发学习及技术研究使用。所有音视频资源均通过公开 API 动态获取，应用本身不存储任何版权音频内容。请遵守各平台服务条款。
