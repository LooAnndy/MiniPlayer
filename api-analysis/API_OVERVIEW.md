# 三平台 API 对接总结

> MiniPlayer 已接入的三个音乐平台 API，含请求格式、关键注意事项和踩坑记录。

---

## 目录

1. [网易云音乐](#1-网易云音乐)
2. [QQ 音乐](#2-qq-音乐)
3. [Bilibili](#3-bilibili)
4. [通用规范](#4-通用规范)

---

## 1. 网易云音乐

### 1.1 搜索

| 项目 | 值 |
|------|-----|
| URL | `POST https://music.163.com/api/cloudsearch/pc` |
| Content-Type | `application/x-www-form-urlencoded` |
| 加密 | **否**（普通 form POST） |
| 鉴权 | Cookie（至少 `MUSIC_U`） |

**请求参数**（form-encoded）：

| 参数 | 类型 | 说明 |
|------|------|------|
| `s` | string | 搜索关键词 |
| `type` | string | `1`=歌曲, `10`=专辑, `100`=歌手, `1000`=歌单 |
| `limit` | string | 返回数量 (1-100) |

**请求头**（必带）：
```
User-Agent: Mozilla/5.0 ... NeteaseMusicDesktop/2.10.2.200154
Referer: https://music.163.com/
Cookie: MUSIC_U=xxx; os=pc; ...
```

**响应**（关键字段）：
```json
{
  "code": 200,
  "result": {
    "songs": [
      {
        "id": 1860599566,
        "name": "歌曲名",
        "ar": [{"name": "歌手"}],
        "al": { "name": "专辑", "picUrl": "https://..." },
        "dt": 240000
      }
    ]
  }
}
```

### 1.2 获取流播放地址

| 项目 | 值 |
|------|-----|
| URL | `POST https://interface3.music.163.com/eapi/song/enhance/player/url/v1` |
| Content-Type | `application/x-www-form-urlencoded` |
| 加密 | **EAPI**（AES-128-ECB + MD5） |
| 鉴权 | Cookie（**MUSIC_U 必需**） |

**加密流程**（详见 `NetEase/API_ANALYSIS.md §3`）：
```
1. payload_json = JSON.stringify({ids, level, encodeType, header})
2. url_path = URL.path 替换 /eapi/ 为 /api/
3. digest = MD5("nobody" + url_path + "use" + payload_json + "md5forencrypt")
4. plaintext = url_path + "-36cd479b6b5-" + payload_json + "-36cd479b6b5-" + digest
5. AES-128-ECB-PKCS7 加密 → hex string
6. POST body: params={hexString}
```

**AES 密钥**：`e82ckenh8dichen8`

**请求参数**（加密前 payload）：
```json
{
  "ids": [123456],
  "level": "exhigh",
  "encodeType": "mp3",
  "header": "{\"os\":\"pc\",\"appver\":\"\",\"osver\":\"\",\"deviceId\":\"pyncm!\",\"requestId\":\"25000000\"}"
}
```

**音质等级**（降级策略）：
| level | 说明 | VIP 要求 |
|-------|------|---------|
| `standard` | 128kbps MP3 | 否 |
| `exhigh` | 320kbps MP3 | 通常需要 |
| `lossless` | FLAC 无损 | 是 |
| `hires` | Hi-Res | 是 |

### 1.3 注意事项

- **音质降级**：先请求 `exhigh`，失败降级到 `standard`（后者通常无需 VIP）
- **试听检测**：响应 `br=0 && size<500KB` 为试听片段，跳过
- **Cookie 格式**：`MUSIC_U=xxx; os=pc; appver=8.9.70; deviceId=pyncm!`
- **请求体加密**：仅 `params={hex}` 一个字段，不是 JSON
- **流 URL 时效**：获取后尽快使用，CDN 链接有有效期

---

## 2. QQ 音乐

### 2.1 搜索

| 项目 | 值 |
|------|-----|
| URL | `POST https://u.y.qq.com/cgi-bin/musicu.fcg` |
| Content-Type | `application/json` |
| 加密 | 否 |
| 鉴权 | Cookie（至少 `uin`） |

**请求体**（JSON）：
```json
{
  "comm": {
    "ct": "11", "cv": "13.2.5.8", "v": "13.2.5.8",
    "tmeAppID": "qqmusic", "format": "json",
    "inCharset": "utf-8", "outCharset": "utf-8", "uin": "0"
  },
  "req_0": {
    "module": "music.search.SearchCgiService",
    "method": "DoSearchForQQMusicMobile",
    "param": {
      "query": "关键词",
      "search_type": 0,
      "num_per_page": 20,
      "page_num": 1,
      "grp": true,
      "highlight": true,
      "searchid": "1715000000000"
    }
  }
}
```

**请求头**（必带）：
```
User-Agent: Chrome/120.0
Referer: https://y.qq.com/
Origin: https://y.qq.com
Cookie: uin=xxx; qm_keyst=xxx; ...
```

**响应**（关键字段）：
```json
{
  "code": 0,
  "req_0": {
    "code": 0,
    "data": {
      "body": {
        "item_song": [  ← 注意：是直接数组，不是 {list:[...]}
          {
            "id": 12345,
            "mid": "004YZbkL2MNHoY",
            "name": "歌曲名",
            "singer": [{"name": "歌手", "mid": "xxx"}],
            "album": {"name": "专辑", "mid": "aaa"},
            "interval": 240
          }
        ]
      }
    }
  }
}
```

### 2.2 获取流播放地址

| 项目 | 值 |
|------|-----|
| URL | `POST https://u.y.qq.com/cgi-bin/musicu.fcg` |
| Content-Type | `application/json` |
| 加密 | 否 |

**请求体**：
```json
{
  "comm": { "ct": "19", ... },  ← ct=19 为歌曲 URL 专用
  "req_0": {
    "module": "music.vkey.GetVkey",
    "method": "UrlGetVkey",
    "param": {
      "guid": "10000",
      "songmid": ["004YZbkL2MNHoY"],
      "songtype": [0],
      "uin": "0",
      "loginflag": 1,
      "platform": "20",
      "filename": ["M800004YZbkL2MNHoY004YZbkL2MNHoY.mp3"]
    }
  }
}
```

**音质代码**（`filename` 前缀）：
| 代码 | 格式 | kbps | VIP 要求 |
|------|------|------|---------|
| `M800` | MP3 | 320 | 是 |
| `M500` | MP3 | 128 | 否 |
| `C400` | AAC | 96 | 否 |
| `F000` | FLAC | 无损 | 是 |

**响应解析**：
```json
{
  "req_0": {
    "code": 0,
    "data": {
      "midurlinfo": [{"purl": "M800...mp3"}],  ← 空字符串 = 无权限
      "sip": ["https://aqqmusic.tc.qq.com/"]
    }
  }
}
```
完整 URL = `sip[0]` (替换 http→https) + `purl`

### 2.3 注意事项

- **响应字段**：`body.item_song` 是**直接数组**，不是 `{list:[...]}`，与网易云不同
- **purl 为空**：`code=0` 但 `purl=""` → 无权限/VIP 限定的音质，需降级
- **音质降级**：M800 → M500 → C400
- **comm.ct 区分**：搜索用 `11`，歌曲 URL 用 `19`
- **Cookie 关键字段**：`uin=xxx; qm_keyst=xxx; qqmusic_key=xxx`

---

## 3. Bilibili

### 3.1 搜索

| 项目 | 值 |
|------|-----|
| URL | `GET https://api.bilibili.com/x/web-interface/wbi/search/type` |
| Content-Type | 无（GET） |
| 加密 | Wbi 签名（当前未实现，Guest 模式可用） |
| 鉴权 | Cookie（至少 `buvid3`） |

**请求参数**（Query String）：
| 参数 | 值 | 说明 |
|------|-----|------|
| `search_type` | `video` | 固定 |
| `keyword` | 关键词 | URL 编码 |
| `tids` | `3` | 音乐主分区 |
| `page` | `1` | 页码 |

**请求头**（必带）：
```
User-Agent: Chrome/120.0
Referer: https://www.bilibili.com/
Cookie: buvid3=xxx; ...
```

**响应**（关键字段）：
```json
{
  "code": 0,
  "data": {
    "result": [
      {
        "id": 12345,
        "bvid": "BV1xx411c7mD",
        "title": "歌曲标题",
        "author": "UP主",
        "pic": "//i0.hdslb.com/bfs/xxx.jpg",
        "duration": "04:32",
        "play": 10000
      }
    ]
  }
}
```

**title 处理**：`title.replace(/<[^>]*>/g, '')` 去除 HTML 高亮标签
**封面处理**：`pic.startsWith('//')` → 补 `https:`
**时长处理**：`HH:MM` → `HH*60+MM` 秒

### 3.2 获取流播放地址

| 项目 | 值 |
|------|-----|
| 步骤1 | `GET https://api.bilibili.com/x/web-interface/view?bvid={bvid}` → `data.cid` |
| 步骤2 | `GET https://api.bilibili.com/x/player/playurl?bvid={bvid}&cid={cid}&qn=0&fnval=16&fnver=0` |

**DASH 音频流**（`fnval=16`）：
```json
{
  "code": 0,
  "data": {
    "dash": {
      "audio": [
        {
          "id": 30280,
          "base_url": "https://xxx.bilibili.com/audio-xxx.m4a",
          "mime_type": "audio/mp4"
        }
      ]
    }
  }
}
```

`data.dash.audio[0].base_url` 是纯音频 `.m4a` 流，AVPlayer 可直接播放。

### 3.3 AVPlayer 格式兼容性

| fnval | 返回格式 | AVPlayer 支持 | 说明 |
|-------|---------|--------------|------|
| 0 | FLV | ❌ 5400106 | FLV 容器不支持 |
| 1 | MP4 (HLS) | ⚠️ 含视频轨 | 音视频混合 |
| 2 | MP4 (HTTP) | ⚠️ 含视频轨 | 音视频混合 |
| **16** | **DASH** | **✅ .m4a 纯音频** | `audio[].base_url` 可直接播放 |

### 3.4 注意事项

- **只用 `fnval=16`**：获取 DASH 音频流，取 `dash.audio[0].base_url`
- **禁止 HTML 正则提取**：ArkTS `/s` flag 不可用；`__playinfo__` 的 DASH URL 与 playurl API 相同
- **cid 必需**：先通过 `/web-interface/view` 获取 `cid`，再调 playurl
- **字段兼容**：同时支持 `baseUrl` (camelCase) 和 `base_url` (snake_case)
- **Referer**：B站 CDN 要求 `Referer: https://www.bilibili.com/`
- **Wbi 签名**：搜索接口理论需要 Wbi 签名（`w_rid`+`wts`），当前 Guest 模式可用，后续可能失效

---

## 4. 通用规范

### 4.1 HTTP 请求

- **导入**：`import { http } from '@kit.NetworkKit'`
- **权限**：`ohos.permission.INTERNET`
- **User-Agent**：各平台要求不同，必须按平台设置
- **Referer**：网易云/QQ/B站都要求 Referer

### 4.2 ArkTS 编码约束

- **接口内联类型**：`interface` 中禁止 `{ key: type }` 写法，必须提取为独立 `interface`
- **对象字面量**：直接作为函数参数传入的 `{ k: v }` 需要显式类型标注
- **Record 禁止**：`Record<string, string>` 不可用于对象字面量，需替换为具名 `interface` 或 `class`
- **对象展开禁止**：`{ ...obj }` 不可用，需手动逐字段赋值
- **`@Builder` 体内**：只允许 UI 组件语法，禁用普通变量声明

### 4.3 Cookie 持久化

- **存储**：`@ohos.data.preferences` (`@kit.ArkData`)
- **初始化**：`getPreferences(context, storeName)` → 需异步等待
- **读写**：`put()` + `flush()` / `get()`
- **时序**：`Index.aboutToAppear` 中初始化，用 `Promise` 确保后续调用就绪
- **多平台**：按 `Platform` 枚举区分存储 key

### 4.4 播放器流播放

HarmonyOS AVPlayer 官方支持的流媒体协议：

| 协议 | 示例 | 点播 | 直播 | 鉴权 |
|------|------|------|------|------|
| HLS | `https://xxx/index.m3u8` | ✅ | ✅ | DRM Kit |
| DASH | `https://xxx/stream.mpd` | ✅ | ❌ | DRM Kit |
| HTTP/HTTPS | `https://xxx/audio.mp4` / `.m4a` | ✅ | ❌ | ✗ |
| HTTP-FLV | `https://xxx.flv` | ✅ | ✅ | ✗ |

**标准播放流程**：
```
1. media.createAVPlayer()                    → idle
2. 注册 stateChange / error / timeUpdate
3. avPlayer.url = url                        → initialized
4. avPlayer.prepare()                        → prepared
5. avPlayer.play()                           → playing
6. avPlayer.pause() / play() / seek() / stop()
7. avPlayer.reset() 或 avPlayer.release()
```

**鉴权资源播放**（需传递 Referer/Cookie 的 CDN）：
```typescript
import media from '@ohos.multimedia.media';

// 创建带请求头的 MediaSource
const mediaSrc = media.createMediaSourceWithUrl(url, {
  'Referer': 'https://www.bilibili.com/',
  'User-Agent': 'Chrome/120...'
});
avPlayer.setMediaSource(mediaSrc);
// → initialized → prepare → play
```

**注意事项**：
- 监听必须在 **idle 状态且设置 url 前**注册
- `audioRendererInfo` 在 `initialized` 回调中设置，`prepare` 之前
- 流播放时 `bufferingUpdate` 可监听缓冲状态
- AVPlayer **不携带 Cookie**，需鉴权的 CDN 通过 `createMediaSourceWithUrl` 设 headers 解决
- HLS / DASH / HTTP 协议 AVPlayer 直接支持，**.m4a (AAC)** 属于 HTTP/HTTPS 协议支持范围

### 4.5 各平台音频格式兼容性

| 平台 | 流格式 | 容器 | AVPlayer 支持 | 备注 |
|------|--------|------|--------------|------|
| 网易云 | HTTPS CDN | MP3/FLAC | ✅ | URL 自身含鉴权参数 |
| QQ 音乐 | HTTPS CDN | MP3/AAC | ✅ | `purl` 拼接 sip |
| Bilibili DASH | HTTP CDN | .m4a(AAC) | ✅ | `fnval=16` → `dash.audio[].base_url` |
| Bilibili FLV | HTTP CDN | FLV | ✅ (HTTP-FLV) | `fnval=0` → `durl[].url` |
| Bilibili DASH .m4s | CDN | 分段 | ❌ | 非标准容器 |

> Bilibili DASH `.m4a` 音频为 HTTP/HTTPS 协议，AVPlayer 原生支持。
> 若 CDN 需 Referer 鉴权，用 `createMediaSourceWithUrl()` 替代直接设 `url`。

### 4.5 错误处理统一

| 场景 | 处理 |
|------|------|
| API 返回 `code ≠ 0` / `code ≠ 200` | 返回空数组/空字符串，记录日志 |
| 网络异常 | try-catch 兜底，返回空值 |
| 音质不可用 | 降级尝试，全部失败返回空 |
| Cookie 无效 | 引导用户去"我的"页配置 |
