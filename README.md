# 🎵 MiniPlayer — 鸿蒙聚合音乐播放器

基于 **HarmonyOS NEXT (API 23)** + **ArkTS V2** 构建的纯血鸿蒙多源音乐搜索与流媒体播放工具。

## 🚩 开发必读 (Development Essentials)

在开始贡献代码前，请务必熟悉以下资源，这能减少 80% 的编译错误与逻辑偏差。

### 1. 核心参考文档

* **[首选]** [IMA 鸿蒙开发者知识库**](https://ima.qq.com)：查询关键词 **"鸿蒙api23"**，能解决一些报错问题。
* **[UI]** [AVPlayer 播放器示例**](https://gitcode.com/HarmonyOS_Samples/avplayer-play-formatted-audio-arkts)：本项目播放页布局、唱片动画及图标来源。
* **[技巧]** [HarmonyOS Skills 汇总**](https://github.com/linhay/harmony-next.skills)：基础概念查阅，建议配合 AI 使用时手动校对 API 23 的变动。
* **[玄学]** [官方智能客服 (FAQ)**](https://developer.huawei.com/consumer/cn/customerService)：遇到 DevEco Studio 报错或编译链异常时的“终极求助站”。

### 2. 第三方 API 参考

粗略内容使用AI提取在docs里面，下面是参考。

| 平台 | 参考仓库 / 文档 | 说明 |
| --- | --- | --- |
| **QQ 音乐** | [QQMusicApi-nodejs](https://github.com/guowenye/QQMusicApi-nodejs) | 搜索接口参数与加签逻辑参考 |
| **网易云** | [Netease_url](https://github.com/Suxiaoqinx/Netease_url) | 音频播放链接 (URL) 的解析逻辑 |
| **Bilibili** | [API Collect](https://sessionhu.github.io/bilibili-API-collect/) / [Parser](https://github.com/Suxiaoqinx/bilibili) | 搜索分区及视频转音频下载解析 |

---

## ✨ 功能实现

| 模块 | 状态 | 说明 |
| --- | --- | --- |
| **网易云 / QQ / B站** | ✅ | 跨平台搜索 + 音频流媒体播放 |
| **Cookie 管理** | ✅ | 三平台独立配置 / 持久化 / 自动恢复 / 连接测试 |
| **多源切换** | ✅ | 搜索页内一键切换平台搜索源 |
| **播放控制** | ✅ | 播放、暂停、切歌、进度拖拽、播完重播 |
| **UI 交互** | ✅ | 底部迷你播放条 + 全屏唱片播放页 |
| **本地播放** | ✅ | 支持选取本地音频文件 FD 播放 |
| **下载管理** | ⏳ | UI 已就绪，待接入沙箱存储下载服务 |

---

## 🏗 项目结构

```text
entry/src/main/ets/
├── pages/          # UI 页面：启动/首页/搜索/播放/我的/下载
├── service/        # 核心服务：播放器引擎 + 三方平台接口适配 (Adapter)
├── view/           # 复用组件：播放条 / 歌单项 / 弹窗
├── viewmodel/      # 状态管理：基于 @Observed/@ObjectLink 的播放状态控制
├── model/          # 数据实体：API 返回值定义 (Interface)
└── utils/          # 工具类：HTTP(rcp) / 加密 / Cookie 管理 / 文件操作

```

---

## 🚀 快速开始

1. **环境准备**：使用 **DevEco Studio** 6.0+，安装 **HarmonyOS NEXT SDK (API 23)**。
2. **克隆项目**：`git clone [repository-url]`。
3. **配置 AI**：查阅 **[贡献指南](docs/CONTRIBUTING.md)** 配置 `claude review` 提示词。
4. **运行**：Build → Run。在模拟器或真机进入「我的」配置 Cookie 即可开始搜索。

---

## 📅 下一阶段目标

### Phase 2：本地音乐管理与 UI 优化

* **离线存储**：实现流 URL 到沙箱存储的持久化。
* **下载增强**：支持下载进度显示与断点续传。
* **自定义 UI**：重构视觉风格，使其更符合用户操作逻辑且美观。

### Phase 3：系统级体验

* **播控中心**：接入 **AVSession**，实现锁屏控歌与通知栏联动。
* **歌词同步**：接入逐字/逐行歌词滚动显示。
* **登录增强**：B 站二维码登录与 Wbi 签名自动刷新。

---

## 🤝 参与贡献

在提交任何代码前，请务必详细阅读：
👉 **[项目贡献指南](docs/CONTRIBUTING.md)**

> **核心提示**：本项目所有的 API 接口细节、逻辑变更请在修改代码前查阅 `docs/` 目录。

---

## ⚖️ 免责声明

本项目仅供 HarmonyOS 开发学习及技术研究使用。所有音视频资源均通过公开 API 动态获取，应用本身不存储任何版权音频内容。请遵守各平台服务条款。

---

### 💡 协作技巧：

**“如果遇到 API 23 的语法问题，优先复制 [IMA 知识库](https://ima.qq.com) 的内容喂给 AI。”** 这能极大减少 AI 因为旧版本文档产生的逻辑误导。