# BiliBili 视频 API 逆向文档

> 语言无关的实现指南，侧重 B站接口契约与数据结构，附 TypeScript 类型定义。

---

## 目录

1. [B站接口清单](#一b站接口清单)
2. [音乐搜索 API](#二音乐搜索-api)
3. [视频数据提取](#三视频数据提取)
4. [DASH 流数据结构](#四dash-流数据结构)
5. [质量码表](#五质量码表)
6. [下载流程](#六下载流程)
7. [Cookie 认证（二维码登录）](#七cookie-认证二维码登录)
8. [自建 API 端点规范](#八自建-api-端点规范)
9. [任务管理模型](#九任务管理模型)

---

## 一、B站接口清单

实现本服务只需调用以下 B站接口：

### 1.1 视频页面 HTML（提取数据用）

```
GET {bilibili_video_url}
Headers:
  User-Agent: Mozilla/5.0 ... Chrome/91.0 ...
  Accept: text/html,application/xhtml+xml,...
  Accept-Language: zh-CN,zh;q=0.9
Cookie: {cookies}
```

**用途**: 从 HTML 源码中提取 `window.__playinfo__` JSON 和视频元信息。

### 1.2 视频/音频流 CDN 地址

URL 来自 `__playinfo__` 解析结果中的 `backupUrl` 字段，直接对 CDN 发起 GET 请求下载。

```
GET {stream_backupUrl}
Headers:
  User-Agent: Mozilla/5.0 ... Chrome/91.0 ...
  Referer: https://www.bilibili.com/
```

**要点**: `Referer` 必须设置为 `https://www.bilibili.com/`，否则 CDN 会拒绝请求。

### 1.3 二维码登录（获取 Cookie）

详见 [第七章](#七cookie-认证二维码登录)。

### 1.4 音乐搜索

```
GET https://api.bilibili.com/x/web-interface/wbi/search/type
Headers:
  User-Agent: Mozilla/5.0 ... Chrome/120.0 ...
  Referer: https://www.bilibili.com/
  Cookie: {buvid3=xxx; buvid4=xxx; ...}
```

**用途**: 按音乐分区搜索视频，返回视频条目列表（每页 20 条）。

**鉴权**: Wbi 签名（`w_rid` + `wts`），Cookie 至少含 `buvid3`，Referer 在 `.bilibili.com` 下。

**参数**:

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `search_type` | str | 是 | 固定 `video` |
| `keyword` | str | 是 | 搜索关键词 |
| `tids` | num | 否 | 分区 tid，默认 0（全部）。音乐主分区 `3` |
| `order` | str | 否 | 排序：`totalrank`(综合)/`click`(播放)/`pubdate`(最新)/`dm`(弹幕)/`stow`(收藏) |
| `duration` | num | 否 | 时长筛选：0全部/1(<10min)/2(10-30)/3(30-60)/4(60+) |
| `page` | num | 否 | 页码，默认 1 |

**响应** (`data.result[]` 视频条目):

| 字段 | 类型 | 说明 |
|------|------|------|
| `type` | str | 固定 `video` |
| `id` / `aid` | num | 稿件 avid |
| `bvid` | str | 稿件 bvid，用于构建视频页 URL |
| `title` | str | 标题（关键词用 `<em class="keyword">` 高亮） |
| `author` | str | UP 主昵称 |
| `mid` | num | UP 主 mid |
| `typeid` | str | 分区 tid |
| `typename` | str | 子分区名（如 "翻唱"、"VOCALOID·UTAU"） |
| `pic` | str | 封面图 URL（`//` 开头，需补 `https:`） |
| `play` | num | 播放量 |
| `duration` | str | 时长 `HH:MM` |
| `tag` | str | TAG，逗号分隔 |
| `pubdate` | num | 投稿时间戳 |

---

## 二、音乐搜索 API

### 2.1 音乐分区 tid 表

| 名称 | tid | 简介 |
|------|-----|------|
| 音乐(主分区) | 3 | 全部音乐类视频 |
| 原创音乐 | 28 | 原创歌曲、纯音乐、改编、remix |
| 音乐现场 | 29 | 演唱会、音乐节、打歌舞台等实况 |
| 翻唱 | 31 | 人声再演绎 |
| 演奏 | 59 | 乐器及非传统器材演奏 |
| 乐评盘点 | 243 | 音乐新闻、盘点、reaction、采访 |
| VOCALOID·UTAU | 30 | 歌声合成引擎创作 |
| MV | 193 | 音乐录影带及自制 MV |
| 音乐粉丝饭拍 | 266 | 粉丝拍摄的非官方现场记录 |
| AI音乐 | 265 | AI 作曲、AI 翻唱、AI 变声等 |
| 电台 | 267 | 音乐分享、白噪音、有声读物 |
| 音乐教学 | 244 | 音乐教学内容 |
| 音乐综合 | 130 | 无法归入以上分区的音乐视频 |

搜索时传 `tids=3` 可覆盖全部音乐分区。

### 2.2 Wbi 签名算法

```
1. GET https://api.bilibili.com/x/web-interface/nav
   → 从 data.wbi_img 中提取 img_url 和 sub_url
2. img_key = img_url 路径中 /wbi/ 和 .png 之间的字符串
   sub_key = sub_url 路径中 /wbi/ 和 .png 之间的字符串
3. salt = img_key + sub_key
4. 请求参数按 key 排序，拼接为 query string
5. w_rid = MD5(query_string + salt)
6. 追加参数 w_rid={md5}&wts={当前秒级时间戳}
```

### 2.3 完整搜索 → 播放链路

```
搜索:
  关键词 keyword + 分区 tid
    → GET /x/web-interface/wbi/search/type
    → 解析 data.result[N].bvid

获取 cid:
    → GET /x/web-interface/view?bvid={bvid}
    → data.cid

获取播放 URL (非 DASH):
    → GET /x/player/playurl?bvid={bvid}&cid={cid}&qn=0&fnval=2&fnver=0
    → data.durl[0].url  (MP4/FLV 完整文件，非分段)

播放:
    → GET {url}  (需 Referer: https://www.bilibili.com/)
```

> #### AVPlayer 格式兼容性
>
> HarmonyOS AVPlayer 官方支持：HLS(.m3u8)、DASH(.mpd)、**HTTP/HTTPS(.mp4/.m4a)**、HTTP-FLV(.flv)
>
> B站 playurl API 的 `fnval` 返回格式对照：
>
> | fnval | 返回格式 | AVPlayer 支持？ | 说明 |
> |-------|---------|----------------|------|
> | 0 | FLV | ✅ HTTP-FLV | 需 Referer 鉴权 |
> | 16 | DASH .m4a | ✅ HTTP/HTTPS | `dash.audio[].base_url` 纯音频 |
> | 1/2 | MP4 | ✅ HTTP/HTTPS | 含视频轨，可能影响纯音频播放 |
>
> **B站 `.m4a` 为 HTTP/HTTPS 协议，AVPlayer 原生支持。** CDN 需 Referer 鉴权时，使用 `createMediaSourceWithUrl()` 替代直接设 `url`：
>
> ```typescript
> const mediaSrc = media.createMediaSourceWithUrl(url, {
>   'Referer': 'https://www.bilibili.com/',
>   'User-Agent': 'Chrome/120...'
> });
> avPlayer.setMediaSource(mediaSrc);
> ```
>
> **禁止的做法**:
> - 用 HTML 正则提取 `__playinfo__`（ArkTS `/s` flag 不可用）
> - 用 `fnval=16` 的 DASH `.m4s` 分段（不兼容）

### 2.4 Python 验证脚本

### 2.4 Python 验证脚本

项目根目录 `bilibili_search_demo.py`，运行方式：

```bash
# 游客模式（低码率）
python bilibili_search_demo.py

# 带 Cookie（高音质）
python bilibili_search_demo.py --cookie "SESSDATA=xxx; bili_jct=yyy; ..."

# 或写入本地文件 .bilibili_cookie 自动加载
```

---

## 三、视频数据提取

### 2.1 从 HTML 提取 `__playinfo__`

**输入**: B站视频页面的 HTML 源码  
**输出**: 解析后的 playinfo JSON 对象

**正则表达式**:
```
<script>window\.__playinfo__\s*=\s*({.*?})</script>
```

**TypeScript 实现参考**:
```typescript
function extractPlayinfo(html: string): PlayinfoData | null {
  const re = /<script>window\.__playinfo__\s*=\s*({.*?})<\/script>/s;
  const match = html.match(re);
  if (!match) return null;
  return JSON.parse(match[1]) as PlayinfoData;
}
```

### 2.2 从 HTML 提取标题

**正则**: `<title[^>]*>([^<]+)</title>`  
**后处理**: 移除后缀 `_哔哩哔哩_bilibili`

```typescript
function extractTitle(html: string): string {
  const match = html.match(/<title[^>]*>([^<]+)<\/title>/i);
  if (!match) return "";
  return match[1].replace(/_哔哩哔哩_bilibili$/, "").trim();
}
```

### 2.3 从 HTML 提取封面

**优先级降级链**（找到即停止）:

1. `<meta property="og:image" content="{url}">`
2. `<meta name="twitter:image" content="{url}">`
3. HTML 中的 JSON 字段 `"pic"` 或 `"cover"`
4. `window.__INITIAL_STATE__` 内的 `videoData.pic`

```typescript
function extractCover(html: string): string {
  // 策略1: og:image meta
  let m = html.match(/<meta\s+property="og:image"\s+content="([^"]+)"/i);
  if (m) return m[1].replace("http://", "https://");

  // 策略2: twitter:image meta
  m = html.match(/<meta\s+name="twitter:image"\s+content="([^"]+)"/i);
  if (m) return m[1].replace("http://", "https://");

  // 策略3: JSON内嵌字段
  m = html.match(/"pic"\s*:\s*"([^"]+)"/) || html.match(/"cover"\s*:\s*"([^"]+)"/);
  if (m) return m[1].replace(/\\\//g, "/").replace("http://", "https://");

  // 策略4: __INITIAL_STATE__
  const initMatch = html.match(/window\.__INITIAL_STATE__\s*=\s*({.*?});/s);
  if (initMatch) {
    try {
      const init = JSON.parse(initMatch[1]);
      const pic = init?.videoData?.pic;
      if (pic) return pic.replace("http://", "https://");
    } catch {}
  }

  return "";
}
```

---

## 四、DASH 流数据结构

### 3.1 `__playinfo__` 完整类型

```typescript
interface PlayinfoData {
  code: number;
  message: string;
  data: {
    dash: DashData;
    // ... 其他字段
  };
}

interface DashData {
  duration: number;       // 视频时长（秒）
  video: DashStream[];    // 视频流列表
  audio: DashStream[];    // 普通音频流列表
  dolby?: {               // 杜比音频（可选）
    audio: DashStream[];
  };
  flac?: {                // Hi-Res FLAC（可选）
    audio: DashStream | null;  // 注意：是对象，不是数组！
  };
}

interface DashStream {
  id: number;             // 质量ID
  backupUrl: string | string[];  // 下载地址
  bandwidth: number;      // 码率（bps）
  codecs: string;         // 编码格式
  // --- 仅视频流有 ---
  width?: number;
  height?: number;
  frameRate?: string;
}
```

### 3.2 关键陷阱

| 陷阱 | 说明 |
|------|------|
| `backupUrl` 类型 | 可能是 `string`，也可能是 `string[]`。统一处理：数组取第一项 |
| `flac.audio` 是对象 | 不是数组，需单独处理 `dash.flac?.audio` 判断非空 |
| `dolby.audio` 是数组 | 正常遍历即可 |
| `frameRate` 是字符串 | B站返回的是 `"30"` 而非 `30`，需 `parseInt` |

### 3.3 流提取算法（语言无关伪代码）

```
function extractStreams(playinfo):
    dash = playinfo.data.dash

    videos = []
    for each v in dash.video:
        url = normalizeUrl(v.backupUrl)
        videos.push({ id: v.id, url, bandwidth: v.bandwidth,
                      codecs: v.codecs, width: v.width,
                      height: v.height, frameRate: parseInt(v.frameRate) })

    audios = []
    for each a in dash.audio:
        url = normalizeUrl(a.backupUrl)
        audios.push({ id: a.id, url, bandwidth: a.bandwidth, codecs: a.codecs })

    // 可选：杜比音频
    if dash.dolby?.audio:
        for each a in dash.dolby.audio:
            audios.push({ id: a.id, url: normalizeUrl(a.backupUrl),
                          bandwidth: a.bandwidth, codecs: a.codecs })

    // 可选：Hi-Res FLAC（对象，非数组）
    flac = dash.flac?.audio
    if flac and flac.backupUrl:
        url = normalizeUrl(flac.backupUrl)
        if url:
            audios.push({ id: flac.id ?? 30251, url,
                          bandwidth: flac.bandwidth || 1, codecs: flac.codecs || "fLaC" })

    // 排序
    videos.sort(by id descending)
    audios.sort(priority: FLAC(30251) > Dolby(30250) > rest by bandwidth descending)

    return { videos, audios, duration: dash.duration }
```

**`normalizeUrl` 实现**:
```
function normalizeUrl(backupUrl):
    if backupUrl is Array  → return backupUrl[0]
    if backupUrl is string → return backupUrl
    return ""
```

---

## 五、质量码表

### 4.1 视频质量映射

```typescript
const VIDEO_QUALITY_MAP: Record<number, string> = {
  127: "超高清 8K",
  126: "杜比视界",
  125: "HDR真彩",
  120: "超高清 4K",
  116: "1080P 60帧",
  112: "1080P 高码率",
  80:  "高清 1080P",
  74:  "高清 720P60",
  64:  "高清 720P",
  32:  "清晰 480P",
  16:  "流畅 360P",
};

function getVideoQualityName(id: number): string {
  return VIDEO_QUALITY_MAP[id] ?? `未知质量(${id})`;
}
```

### 4.2 音频质量映射

```typescript
const AUDIO_QUALITY_MAP: Record<number, string> = {
  30251: "Hi-Res无损",
  30250: "杜比音频",
  30280: "320K",
  30232: "128K",
  30216: "64K",
};

function getAudioQualityName(id: number): string {
  return AUDIO_QUALITY_MAP[id] ?? `未知音质(${id})`;
}
```

---

## 六、下载流程

### 5.1 流式下载算法

**输入**: 流 URL, 输出路径  
**输出**: 下载完成的文件

```
function downloadStream(url, outputPath, onProgress):
    headers = {
        "User-Agent": "Mozilla/5.0 ...",
        "Referer": "https://www.bilibili.com/"
    }

    response = httpGET(url, headers, stream=true)
    totalSize = parseInt(response.headers["content-length"] ?? 0)
    downloaded = 0
    startTime = now()

    file = open(outputPath, write_binary)
    for each chunk in response.readChunks(8192):  // 8KB每块
        file.write(chunk)
        downloaded += chunk.length

        if totalSize > 0:
            progress = downloaded / totalSize * 100
            speed = downloaded / (now() - startTime)
            onProgress?.({ current: downloaded, total: totalSize, progress, speed })
        else:
            onProgress?.({ current: downloaded, total: 0 })

    file.close()
    return success
```

### 5.2 选择质量并下载

```
function selectAndDownload(url, cookies, options):
    // options: { qualityIndex, audioIndex, filename? }

    // 1. 获取视频页面
    html = fetchHTML(url, cookies)

    // 2. 提取 __playinfo__
    playinfo = extractPlayinfo(html)

    // 3. 提取流列表
    { videos, audios, duration } = extractStreams(playinfo)

    // 4. 选择质量（索引 0 = 最高质量）
    selectedVideo = videos[options.qualityIndex ?? 0]
    selectedAudio = audios[options.audioIndex ?? 0]

    // 5. 生成文件名
    filename = options.filename ?? extractBVid(url) ?? `bilibili_${timestamp}`

    // 6. 下载视频流
    videoPath = `${outputDir}/${filename}_video.m4v`
    downloadStream(selectedVideo.url, videoPath, onProgress)

    // 7. 下载音频流
    ext = selectedAudio.id === 30251 ? ".flac" : ".m4a"
    audioPath = `${outputDir}/${filename}_audio${ext}`
    downloadStream(selectedAudio.url, audioPath, onProgress)

    return { videoPath, audioPath, videoQuality: selectedVideo, audioQuality: selectedAudio }
```

### 5.3 BV 号提取

```typescript
function extractBVid(url: string): string | null {
  const match = url.match(/BV[a-zA-Z0-9]+/);
  return match ? match[0] : null;
}
```

---

## 七、Cookie 认证（二维码登录）

### 6.1 完整登录流程

```
Step 1: 获取二维码
  GET https://passport.bilibili.com/x/passport-login/web/qrcode/generate
  → { code: 0, data: { qrcode_key, url } }

Step 2: 生成二维码图片
  使用 qrcode_key 对应的 url，调用任意 QR 码生成库生成图片

Step 3: 轮询扫码状态
  GET https://passport.bilibili.com/x/passport-login/web/qrcode/poll?qrcode_key={key}
  每 3 秒轮询一次，直到登录成功或过期

Step 4: 获取用户信息（可选）
  GET https://api.bilibili.com/x/web-interface/nav
  Cookie: {登录后得到的cookie}
  → { code: 0, data: { mid, uname, face, level_info, vipStatus, isLogin } }

Step 5: 保存 Cookie
  格式: "key1=val1; key2=val2"
```

### 6.2 扫码状态码

| 响应 code | 含义 |
|-----------|------|
| `86101` | 等待扫码 |
| `86090` | 已扫码，等待用户在手机确认 |
| `86038` | 二维码已过期 |
| `0` | 登录成功，`data.url` 为回调地址 |

### 6.3 Cookie 存储格式

从 `__playinfo__` 无法获取高画质流时，需要携带登录后的 Cookie。存储格式：

```
SESSDATA=xxxx; bili_jct=yyyy; DedeUserID=zzzz; ...
```

**解析为请求头**:
```typescript
function parseCookie(raw: string): Record<string, string> {
  const map: Record<string, string> = {};
  for (const item of raw.split(";")) {
    const eq = item.indexOf("=");
    if (eq > 0) {
      map[item.slice(0, eq).trim()] = item.slice(eq + 1).trim();
    }
  }
  return map;
}
```

---

## 八、自建 API 端点规范

以下规范与实现语言无关，定义了每个端点的输入/输出/行为。

### 7.1 `GET /api/video/info` — 获取视频信息

**Query 参数**:

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `url` | string | 是 | B站视频页面 URL |
| `q` | string | 否 | 设为 `"auto"` 返回完整流 URL |
| `stream_type` | string | 否 | `"video"` \| `"audio"` \| `"all"`（默认） |

**内部调用链**:
```
fetchHTML(url) → extractPlayinfo(html) → extractStreams(playinfo)
fetchHTML(url) → extractTitle(html) + extractCover(html)
→ 拼接文本响应
```

**响应字段**:
- 标题、封面、时长
- 最高质量视频/音频流信息
- 可用视频流列表（质量名、分辨率、帧率、编码、带宽）
- 可用音频流列表（质量名、编码、带宽）
- 当 `q=auto` 时包含每个流的下载 URL

**TypeScript 类型**:
```typescript
interface VideoInfoResponse {
  title: string;
  cover: string;         // HTTPS URL
  duration: number;      // 秒
  videos: StreamInfo[];
  audios: StreamInfo[];
  highestVideo: StreamInfo | null;
  highestAudio: StreamInfo | null;
}

interface StreamInfo {
  qualityId: number;
  qualityName: string;
  url: string;           // 仅 q=auto 时有值
  bandwidth: number;
  codecs: string;
  width?: number;        // 仅视频
  height?: number;       // 仅视频
  frameRate?: number;    // 仅视频
}
```

### 7.2 `GET /api/video/quality` — 获取可用质量选项

**Query 参数**:

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `url` | string | 是 | B站视频页面 URL |

**内部调用链**: 同 info，但只返回质量列表（含索引号供下载时选择）。

```typescript
interface QualityOptionsResponse {
  videoOptions: QualityOption[];
  audioOptions: QualityOption[];
  duration: number;
}

interface QualityOption {
  index: number;         // 用于 download 接口的 quality_index 参数
  qualityId: number;
  qualityName: string;
  bandwidth: number;
  codecs: string;
  width?: number;
  height?: number;
  frameRate?: number;
}
```

### 7.3 `GET /api/video/download` — 发起下载任务

**Query 参数**:

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `url` | string | (必填) | B站视频页面 URL |
| `video_quality` | number | `0` | 视频质量索引，0=最高 |
| `audio_quality` | number | `0` | 音频质量索引，0=最高 |
| `filename` | string | 自动提取 | 自定义文件名（不含扩展名） |

**行为**:
1. 检查是否有相同 URL 的活跃任务 → 返回 409
2. 生成 UUID 作为 taskId
3. 创建任务记录，状态 = `pending`
4. 异步执行下载（不阻塞响应）
5. 立即返回 taskId

**响应**: `{ taskId: string, url: string, status: "pending" }`

**下载流程**（异步执行）:
```
pending → downloading:
  1. fetchHTML(url) → extractPlayinfo → extractStreams
  2. 按 quality_index 选择流
  3. 流式下载视频流 → 更新 progress
  4. 流式下载音频流 → 更新 progress
  5. → completed: { videoPath, audioPath }
  或 → failed: { error }
```

### 7.4 `GET /api/download/status/{taskId}` — 查询任务状态

**路径参数**: `taskId`（UUID）

**响应**:
```typescript
interface TaskStatusResponse {
  taskId: string;
  status: "pending" | "downloading" | "completed" | "failed";
  progress: number;      // 0-100
  message: string;
  createdAt: string;     // ISO 8601
  url: string;
  videoQualityIndex: number;
  audioQualityIndex: number;
  filename: string | null;
  // completed 时有:
  videoPath?: string;
  audioPath?: string;
  // failed 时有:
  error?: string;
}
```

### 7.5 `GET /api/download/file/{taskId}` — 下载已完成文件

**路径参数**: `taskId`（UUID）  
**Query 参数**: `type` = `"video"` | `"audio"` (默认 `"video"`)

**行为**:
1. 校验任务存在且 status=completed
2. 读取对应文件路径
3. 返回文件流（`Content-Type: application/octet-stream`）

### 7.6 `GET /api/tasks` — 列出所有任务

**响应**: 所有任务按创建时间倒序排列的列表。

---

## 九、任务管理模型

### 8.1 状态机

```
         ┌──────────┐
         │ pending  │  任务已创建，等待线程调度
         └────┬─────┘
              │ 线程开始执行
         ┌────▼──────┐
         │downloading│  正在解析/下载
         └─┬──────┬──┘
           │      │
    成功 ┌─┘      └── 失败
    ┌───▼─────┐  ┌───▼─────┐
    │completed│  │ failed  │
    └─────────┘  └─────────┘
```

### 8.2 数据结构

```typescript
interface DownloadTask {
  id: string;                      // UUID v4
  url: string;
  status: TaskStatus;
  progress: number;                // 0-100
  message: string;
  createdAt: string;               // ISO 8601
  videoQualityIndex: number;
  audioQualityIndex: number;
  filename: string | null;
  videoPath: string | null;
  audioPath: string | null;
  error: string | null;
}

type TaskStatus = "pending" | "downloading" | "completed" | "failed";

// 任务存储（内存 Map）
const tasks: Map<string, DownloadTask> = new Map();
```

### 8.3 并发控制

```typescript
// 关键约束
const MAX_CONCURRENT = 5;

// 使用信号量或任务队列限制并发
// 每个下载任务应在独立线程/Worker 中执行
// 通过回调更新主线程中的任务状态
```

### 8.4 线程安全要点

在 TypeScript/Node.js 中，JS 是单线程事件循环模型，不存在真正的竞态条件。但需注意：

- 如果使用 Worker Threads，需要用 `postMessage` 通信
- 如果使用 `Promise` + `async/await`，对 `Map` 的操作是原子的
- 进度回调直接修改任务对象即可，无需加锁

在 Go/Rust/Java 等多线程语言中，需要使用 Mutex/RwLock 保护 `tasks` Map 的读写。

### 8.5 重复请求检测

```
function checkDuplicate(url):
    for each task in tasks.values():
        if task.url === url AND task.status in [pending, downloading, completed]:
            return task.id   // 已存在
    return null
```

---

## 九、补充说明

### Cookie 必要性

- 无 Cookie → 仅能获取 360P/480P 流（B站游客限制）
- 有 Cookie → 可获取登录用户权限对应的高画质流
- Cookie 过期时间约 30 天，过期后需重新扫码登录

### 响应格式选择

本项目使用纯文本响应（`Content-Type: text/plain`），便于浏览器直接查看和脚本 `regex` 提取。跨语言复刻时可改为 JSON：

```typescript
// JSON 版本示例
interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: string;
}
```

### 关键 HTTP 头

所有对 B站服务器的请求必须携带：

```
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
Referer: https://www.bilibili.com/          # 下载 CDN 流时必需
Accept: text/html,application/xhtml+xml     # 请求页面时
Accept-Language: zh-CN,zh;q=0.9             # 中文内容
```
