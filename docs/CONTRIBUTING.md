# 🛠 贡献指南 (MiniPlayer)

为了保证大作业代码的高效与统一，请大家在开发前务必花 1 分钟阅读此流程。

## 1. 📖 开发必读：参考资料库

本项目要求在 AI 生成代码前，让其参考以下文档以减少“幻觉”：

### 📂 本地 API 逻辑 (内部文档)
*   **路径**：`docs/` 文件夹。
*   **说明**：记录了 B 站签名、Cookie 校验、音量换算等核心逻辑。
*   **调教指令**：若 Claude Code 逻辑跑偏，请说：*“请阅读 docs/ 下的文档，按定义的接口规范重构。”*

### 🌐 外部技术栈 (核心链接)
| 类别 | 推荐资源 (优先级高) | 说明 |
| :--- | :--- | :--- |
| **鸿蒙知识库** | [**IMA 鸿蒙知识库**](https://ima.qq.com/wikis?knowledgeBaseId=7310975208261454) | **首选**。内容比一般 Skill 更扎实，适合解决疑难杂症。 |
| **API 23 示例** | [官方 Sample 仓](https://developer.huawei.com/consumer/cn/samples/) | 查阅 API 23 最标准的代码写法。 |
| **UI/播放参考** | [AVPlayer 布局示例](https://gitcode.com/HarmonyOS_Samples/avplayer-play-formatted-audio-arkts) | 本项目播放页与图标的布局来源。 |
| **神秘支持** | [官方 FAQ 机器人](https://developer.huawei.com/consumer/cn/customerService/#/bot-dev-top/faq-top/faq-talk-top/) | 遇到编译器或环境的“玄学问题”去碰运气。 |
| **三方 API** | [QQ 音乐](https://github.com/guowenye/QQMusicApi-nodejs) \| [网易云](https://github.com/Suxiaoqinx/Netease_url) \| [B 站搜索](https://sessionhu.github.io/bilibili-API-collect/) \| [B 站解析](https://github.com/Suxiaoqinx/bilibili) | 查阅各平台数据接口的字段与加签。 |

---

## 2. 🔄 极简 Git 工作流

1.  **同步主线**：`git pull origin main`
2.  **创建分支**：`git checkout -b feat-功能名` (如 `feat-lyrics`)
3.  **AI 审计**：开发完成后，必须运行 `claude review` 检查 ArkTS 规范。
4.  **合回主线**：
    ```powershell
    git checkout main
    git merge feat-功能名
    git push origin main
    git branch -d feat-功能名
    ```

---

## 3. ⚠️ 代码“红线” (HarmonyOS NEXT)

*   **🚫 严禁 `any`**：API 23 严格模式下，所有变量必须有明确类型。
*   **🛡️ 异常捕获**：网络请求必须包裹 `try-catch`，避免因为接口失效导致全量闪退。
*   **🎨 资源解耦**：禁止在 `.ets` 中硬编码中文字符串，统一存入 `base/element/string.json`。
*   **🧩 模块化**：新增功能请参考 `docs/`，不要在 `Page` 层写复杂的业务逻辑。

---

## 4. 📝 提交信息规范 (Commit Message)

请使用以下前缀，方便回溯：
*   `feat`: 新功能 (New Feature)
*   `fix`: 修复 Bug
*   `refactor`: 代码重构（不改变功能）
*   `docs`: 文档更新

---

## 💡 常见问题 (FAQ)

*   **.claude/ 冲突？** 运行 `git rm -r --cached .claude/` 然后重新提交，千万不要把 AI 的缓存传到库里。
*   **Claude 不认识新 API？** 将 [IMA 知识库](https://ima.qq.com/wikis?knowledgeBaseId=7310975208261454) 里的核心内容复制到 `api-analysis/` 下的一个临时文件里喂给它。

---
