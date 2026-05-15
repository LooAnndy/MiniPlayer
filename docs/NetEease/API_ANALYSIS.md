# 网易云音乐 API 逆向分析完整流程

> 语言无关的协议级文档，可用任意编程语言复现。

---

## 目录

1. [概述与架构](#1-概述与架构)
2. [认证：Cookie 获取与管理](#2-认证cookie-获取与管理)
3. [核心加密协议：EAPI](#3-核心加密协议eapi)
4. [图片 ID 加密算法](#4-图片-id-加密算法)
5. [API 接口详解](#5-api-接口详解)
   - [5.1 获取歌曲播放 URL](#51-获取歌曲播放-url)
   - [5.2 获取歌曲详情](#52-获取歌曲详情)
   - [5.3 获取歌词](#53-获取歌词)
   - [5.4 搜索音乐](#54-搜索音乐)
   - [5.5 获取歌单详情](#55-获取歌单详情)
   - [5.6 获取专辑详情](#56-获取专辑详情)
6. [下载流程](#6-下载流程)
7. [完整调用流程示例](#7-完整调用流程示例)
8. [常量和配置](#8-常量和配置)
9. [各语言实现参考](#9-各语言实现参考)

---

## 1. 概述与架构

### 1.1 项目架构

```
┌──────────────┐     HTTP (Flask)     ┌─────────────────┐     EAPI/AES      ┌──────────────────┐
│   前端/客户端  │ ◄──────────────────► │  main.py (API服务) │ ◄───────────────► │ 网易云音乐服务器    │
│  (任意客户端)  │    JSON Response    │  port 5000        │   HTTP POST      │ music.163.com    │
└──────────────┘                      └─────────────────┘                   └──────────────────┘
```

### 1.2 两类 API 端点

网易云音乐的内部 API 分为两类：

| 类型 | 路径前缀 | 是否需要加密 | 使用场景 |
|------|---------|-------------|---------|
| **EAPI** | `/eapi/...` | **是** — 需要 AES 加密 `params` | 获取歌曲 URL、二维码登录 |
| **普通 API** | `/api/...` | 否 — 直接 POST form 数据 | 歌曲详情、歌词、搜索、歌单 |

### 1.3 HTTP 请求基本配置

所有请求必须携带以下 HTTP 头：

```http
User-Agent: Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Safari/537.36 Chrome/91.0.4472.164 NeteaseMusicDesktop/2.10.2.200154
Referer: https://music.163.com/
```

默认 Cookie（所有请求都需要带上这些基础 Cookie）：

```
os=pc; appver=; osver=; deviceId=pyncm!
```

---

## 2. 认证：Cookie 获取与管理

### 2.1 核心 Cookie 字段

| Cookie 名 | 用途 | 必需性 |
|-----------|------|--------|
| `MUSIC_U` | 用户身份标识（登录后获得） | **核心必需** |
| `MUSIC_A` | 用户认证令牌 | 重要 |
| `__csrf` | CSRF 防护令牌 | 重要 |
| `NMTID` | 设备标识 | 辅助 |
| `WEVNSM` | 会话管理 | 辅助 |
| `WNMCID` | 客户端标识 | 辅助 |

### 2.2 获取 Cookie 的方式

#### 方式一：浏览器手动提取

1. 在浏览器中打开 https://music.163.com 并登录
2. 打开开发者工具 → Application → Cookies
3. 复制所有 Cookie，格式为：`MUSIC_U=xxx; __csrf=xxx; ...`

#### 方式二：二维码登录（自动化）

详见 [二维码登录流程](#54-二维码登录流程)。

### 2.3 Cookie 存储格式

Cookie 以纯文本存储，格式为分号分隔的键值对：

```
MUSIC_U=abc123def456; os=pc; appver=8.9.70; deviceId=pyncm!
```

### 2.4 Cookie 有效性验证

最低验证标准：
- `MUSIC_U` 字段必须存在
- `MUSIC_U` 长度 ≥ 10 个字符

---

## 3. 核心加密协议：EAPI

这是整个逆向分析中最关键的部分。所有以 `/eapi/` 开头的接口都需要对请求参数进行 AES 加密。

### 3.1 密钥

```
AES Key (16 bytes): e82ckenh8dichen8
AES Mode: ECB
Padding: PKCS7
```

### 3.2 加密流程（伪代码）

```
输入: url (完整URL), payload (请求参数的字典/JSON对象)
输出: hex编码的密文字符串

步骤1: 提取路径并转换
       url_path = URL解析(url).path
       url_path = url_path.replace("/eapi/", "/api/")

步骤2: 构造摘要原文
       payload_json = JSON序列化(payload)
       digest_text = "nobody" + url_path + "use" + payload_json + "md5forencrypt"

步骤3: 计算 MD5
       digest = MD5(digest_text)  // 输出 32 字符的十六进制小写字符串

步骤4: 构造待加密原文
       plaintext = url_path + "-36cd479b6b5-" + payload_json + "-36cd479b6b5-" + digest

步骤5: AES-128-ECB 加密
       key = "e82ckenh8dichen8"  (UTF-8 编码, 16 bytes)
       使用 PKCS7 填充
       加密模式: ECB

步骤6: 输出
       将密文转为十六进制小写字符串
```

### 3.3 加密流程 — 详细图解

```
明文构造:
┌──────────┬───────────────┬───────────────┬───────────────┬──────────────────────────┐
│ url_path │ -36cd479b6b5- │ payload_json  │ -36cd479b6b5- │ MD5(nobody{path}use      │
│ (eapi→api)│   (分隔符1)   │   (请求参数)    │   (分隔符2)   │  {json}md5forencrypt)    │
└──────────┴───────────────┴───────────────┴───────────────┴──────────────────────────┘

例: /api/song/enhance/player/url/v1-36cd479b6b5-{"ids":[123],"level":"lossless"}-36cd479b6b5-a1b2c3d4e5f6...

                    ↓ AES-128-ECB + PKCS7 Padding ↓

密文 (hex): a1b2c3d4e5f67890abcdef...
```

### 3.4 发送加密请求

加密后的请求通过 POST 发送：

```http
POST https://interface3.music.163.com/eapi/song/enhance/player/url/v1
Content-Type: application/x-www-form-urlencoded

params={hex_encrypted_string}
```

### 3.5 各语言实现

#### Python

```python
import json
import urllib.parse
from hashlib import md5
from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

AES_KEY = b"e82ckenh8dichen8"

def encrypt_params(url: str, payload: dict) -> str:
    # 1. 提取路径并转换 eapi → api
    url_path = urllib.parse.urlparse(url).path.replace("/eapi/", "/api/")
    
    # 2. 计算 MD5 摘要
    payload_json = json.dumps(payload)
    digest_text = f"nobody{url_path}use{payload_json}md5forencrypt"
    digest = md5(digest_text.encode("utf-8")).hexdigest()
    
    # 3. 构造明文
    plaintext = f"{url_path}-36cd479b6b5-{payload_json}-36cd479b6b5-{digest}"
    
    # 4. PKCS7 填充
    padder = padding.PKCS7(128).padder()  # AES block size = 128 bits
    padded = padder.update(plaintext.encode()) + padder.finalize()
    
    # 5. AES-ECB 加密
    cipher = Cipher(algorithms.AES(AES_KEY), modes.ECB())
    encryptor = cipher.encryptor()
    encrypted = encryptor.update(padded) + encryptor.finalize()
    
    # 6. 返回 hex 字符串
    return encrypted.hex()
```

#### JavaScript/Node.js

```javascript
const crypto = require('crypto');

const AES_KEY = Buffer.from('e82ckenh8dichen8', 'utf8');

function encryptParams(url, payload) {
    // 1. 提取路径
    const urlObj = new URL(url);
    let urlPath = urlObj.pathname.replace('/eapi/', '/api/');
    
    // 2. 计算 MD5
    const payloadJson = JSON.stringify(payload);
    const digestText = `nobody${urlPath}use${payloadJson}md5forencrypt`;
    const digest = crypto.createHash('md5').update(digestText, 'utf8').digest('hex');
    
    // 3. 构造明文
    const plaintext = `${urlPath}-36cd479b6b5-${payloadJson}-36cd479b6b5-${digest}`;
    
    // 4. PKCS7 填充
    const blockSize = 16;
    const padding = blockSize - (plaintext.length % blockSize);
    const padded = plaintext + String.fromCharCode(padding).repeat(padding);
    
    // 5. AES-128-ECB 加密
    const cipher = crypto.createCipheriv('aes-128-ecb', AES_KEY, null);
    cipher.setAutoPadding(false);
    const encrypted = Buffer.concat([cipher.update(padded, 'utf8'), cipher.final()]);
    
    return encrypted.toString('hex');
}
```

#### Go

```go
import (
    "crypto/aes"
    "crypto/md5"
    "encoding/hex"
    "encoding/json"
    "fmt"
    "net/url"
    "strings"
)

var aesKey = []byte("e82ckenh8dichen8")

func pkcs7Pad(data []byte, blockSize int) []byte {
    padding := blockSize - len(data)%blockSize
    padText := bytes.Repeat([]byte{byte(padding)}, padding)
    return append(data, padText...)
}

func encryptParams(rawURL string, payload map[string]interface{}) (string, error) {
    // 1. 提取路径
    u, _ := url.Parse(rawURL)
    urlPath := strings.Replace(u.Path, "/eapi/", "/api/", 1)
    
    // 2. 计算 MD5
    payloadBytes, _ := json.Marshal(payload)
    payloadJSON := string(payloadBytes)
    digestText := fmt.Sprintf("nobody%suse%s%smd5forencrypt", urlPath, payloadJSON)
    hash := md5.Sum([]byte(digestText))
    digest := hex.EncodeToString(hash[:])
    
    // 3. 构造明文
    plaintext := fmt.Sprintf("%s-36cd479b6b5-%s-36cd479b6b5-%s", urlPath, payloadJSON, digest)
    
    // 4. PKCS7 填充 + AES-ECB 加密
    padded := pkcs7Pad([]byte(plaintext), aes.BlockSize)
    block, _ := aes.NewCipher(aesKey)
    encrypted := make([]byte, len(padded))
    
    for i := 0; i < len(padded); i += aes.BlockSize {
        block.Encrypt(encrypted[i:], padded[i:])
    }
    
    return hex.EncodeToString(encrypted), nil
}
```

#### Rust

```rust
use aes::Aes128;
use aes::cipher::{BlockEncrypt, KeyInit};
use aes::cipher::generic_array::GenericArray;
use md5::{Md5, Digest};
use serde_json::Value;

const AES_KEY: &[u8; 16] = b"e82ckenh8dichen8";

fn pkcs7_pad(data: &mut Vec<u8>, block_size: usize) {
    let padding = block_size - data.len() % block_size;
    data.extend(std::iter::repeat(padding as u8).take(padding));
}

fn encrypt_params(url: &str, payload: &Value) -> String {
    // 1. 提取路径
    let parsed = url::Url::parse(url).unwrap();
    let url_path = parsed.path().replace("/eapi/", "/api/");
    
    // 2. MD5 摘要
    let payload_json = serde_json::to_string(payload).unwrap();
    let digest_text = format!("nobody{}use{}md5forencrypt", url_path, payload_json);
    let digest = hex::encode(Md5::digest(digest_text.as_bytes()));
    
    // 3. 构造明文
    let plaintext = format!("{}-36cd479b6b5-{}-36cd479b6b5-{}", url_path, payload_json, digest);
    
    // 4. PKCS7 + AES-ECB
    let mut data = plaintext.into_bytes();
    pkcs7_pad(&mut data, 16);
    
    let cipher = Aes128::new(GenericArray::from_slice(AES_KEY));
    for chunk in data.chunks_mut(16) {
        let block = GenericArray::from_mut_slice(chunk);
        cipher.encrypt_block(block);
    }
    
    hex::encode(&data)
}
```

---

## 4. 图片 ID 加密算法

网易云音乐的封面图片 URL 不是直接暴露的，需要经过加密计算。

### 4.1 算法描述

```
输入: pic_id (数字ID的字符串)
输出: 加密后的字符串 (用于构造图片URL)

步骤:
1. magic = "3go8&$8*3*3h0k(2)2"  (固定密钥字符串)
2. 将 pic_id 的每个字符与 magic 对应位置的字符进行 XOR
   (magic 索引用 i % len(magic) 循环)
3. 对 XOR 结果字符串计算 MD5 哈希
4. 将 MD5 的 16 字节结果进行 Base64 编码
5. 替换 Base64 中的特殊字符: '/' → '_', '+' → '-'
```

### 4.2 图片 URL 构造

```
加密ID = encrypt_pic_id(pic_id)
图片URL = "https://p3.music.126.net/{加密ID}/{原始pic_id}.jpg?param={size}y{size}"
```

### 4.3 各语言实现

#### Python

```python
import hashlib
import base64

def encrypt_pic_id(pic_id: str) -> str:
    magic = list('3go8&$8*3*3h0k(2)2')
    song_id = list(pic_id)
    
    for i in range(len(song_id)):
        song_id[i] = chr(ord(song_id[i]) ^ ord(magic[i % len(magic)]))
    
    m = ''.join(song_id)
    md5_bytes = hashlib.md5(m.encode('utf-8')).digest()
    result = base64.b64encode(md5_bytes).decode('utf-8')
    result = result.replace('/', '_').replace('+', '-')
    return result

def get_pic_url(pic_id: int, size: int = 300) -> str:
    if pic_id is None:
        return ''
    enc_id = encrypt_pic_id(str(pic_id))
    return f'https://p3.music.126.net/{enc_id}/{pic_id}.jpg?param={size}y{size}'
```

#### JavaScript

```javascript
function encryptPicId(picId) {
    const magic = '3go8&$8*3*3h0k(2)2';
    const chars = [...picId].map((c, i) => 
        String.fromCharCode(c.charCodeAt(0) ^ magic.charCodeAt(i % magic.length))
    );
    const hash = require('crypto').createHash('md5').update(chars.join('')).digest();
    return Buffer.from(hash).toString('base64').replace(/\//g, '_').replace(/\+/g, '-');
}
```

---

## 5. API 接口详解

### 5.1 获取歌曲播放 URL

> 这是最核心的接口，返回歌曲的实际播放/下载地址。

- **URL:** `https://interface3.music.163.com/eapi/song/enhance/player/url/v1`
- **方法:** POST
- **加密:** 是 (EAPI)
- **需要 Cookie:** 是（关键接口）

#### 请求参数

| 参数 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `ids` | `[int]` | 歌曲 ID 数组 | `[123456]` |
| `level` | `string` | 音质等级 | `"lossless"` |
| `encodeType` | `string` | 编码类型，固定为 `"flac"` | `"flac"` |
| `header` | `string` | JSON 序列化的配置对象 | 见下文 |

**特殊参数（仅 sky 音质）：**

| 参数 | 类型 | 说明 |
|------|------|------|
| `immerseType` | `string` | 固定为 `"c51"` |

**header 配置对象：**

```json
{
    "os": "pc",
    "appver": "",
    "osver": "",
    "deviceId": "pyncm!",
    "requestId": "20000000~30000000 之间的随机整数"
}
```

#### 完整请求示例（加密前 payload）

```json
{
    "ids": [1860599566],
    "level": "lossless",
    "encodeType": "flac",
    "header": "{\"os\":\"pc\",\"appver\":\"\",\"osver\":\"\",\"deviceId\":\"pyncm!\",\"requestId\":\"25000000\"}"
}
```

#### 响应结构

```json
{
    "code": 200,
    "data": [
        {
            "id": 1860599566,
            "url": "https://m804.music.126.net/2024.../xxx.flac",
            "br": 921,
            "size": 28374612,
            "type": "flac",
            "level": "lossless",
            "encodeType": "flac",
            "freeTrialInfo": null,
            "time": 0,
            "gain": 0,
            "md5": "abc123..."
        }
    ]
}
```

| 字段 | 说明 |
|------|------|
| `url` | 歌曲播放/下载直链 |
| `br` | 比特率 (kbps) |
| `size` | 文件大小 (bytes) |
| `type` | 文件格式 (`mp3`, `flac`, `m4a`) |
| `level` | 实际返回的音质等级 |

#### 音质等级枚举

| 值 | 中文名称 | 典型格式 | 典型比特率 |
|----|---------|---------|-----------|
| `standard` | 标准音质 | mp3 | ~128 kbps |
| `exhigh` | 极高音质 | mp3 | ~320 kbps |
| `lossless` | 无损音质 | flac | ~900 kbps |
| `hires` | Hi-Res 音质 | flac | ~2000+ kbps |
| `sky` | 沉浸环绕声 | m4a | - |
| `jyeffect` | 高清环绕声 | m4a | - |
| `jymaster` | 超清母带 | flac | ~4000+ kbps |
| `dolby` | 杜比全景声 | m4a | - |

> **注意：** `sky`、`jyeffect`、`jymaster`、`dolby` 等高级音质可能需要 VIP 账号才能获取到有效 URL。

---

### 5.2 获取歌曲详情

- **URL:** `https://interface3.music.163.com/api/v3/song/detail`
- **方法:** POST
- **加密:** 否
- **需要 Cookie:** 否（但带上能获取更多信息）

#### 请求参数（form-encoded）

| 参数 | 类型 | 说明 |
|------|------|------|
| `c` | `string` | JSON 序列化的数组：`[{"id": 歌曲ID, "v": 0}]` |

#### 请求示例

```http
POST https://interface3.music.163.com/api/v3/song/detail
Content-Type: application/x-www-form-urlencoded

c=[{"id":1860599566,"v":0}]
```

#### 响应结构（关键字段）

```json
{
    "code": 200,
    "songs": [
        {
            "id": 1860599566,
            "name": "歌曲名称",
            "ar": [{"id": 123, "name": "歌手名"}],
            "al": {
                "id": 456,
                "name": "专辑名称",
                "picUrl": "https://p3.music.126.net/.../xxx.jpg",
                "pic": 109951167899998
            },
            "dt": 240000,
            "no": 1,
            "publishTime": 1700000000000
        }
    ]
}
```

| 字段 | 说明 |
|------|------|
| `ar` | 艺术家数组 |
| `al.picUrl` | 专辑封面 URL（可直接使用） |
| `al.pic` | 封面原始 ID（需经加密算法才可用于直链） |
| `dt` | 时长（毫秒） |
| `no` | 曲目序号 |

---

### 5.3 获取歌词

- **URL:** `https://interface3.music.163.com/api/song/lyric`
- **方法:** POST
- **加密:** 否
- **需要 Cookie:** 是

#### 请求参数（form-encoded）

| 参数 | 值 |
|------|-----|
| `id` | 歌曲 ID |
| `cp` | `"false"` |
| `tv` | `"0"` |
| `lv` | `"0"` |
| `rv` | `"0"` |
| `kv` | `"0"` |
| `yv` | `"0"` |
| `ytv` | `"0"` |
| `yrv` | `"0"` |

#### 响应结构

```json
{
    "code": 200,
    "lrc": {
        "version": 1,
        "lyric": "[00:00.00]歌词文本\n[00:10.00]下一行\n..."
    },
    "tlyric": {
        "version": 1,
        "lyric": "[00:00.00]Translated lyric\n..."
    }
}
```

| 字段 | 说明 |
|------|------|
| `lrc.lyric` | 原始歌词（LRC 格式） |
| `tlyric.lyric` | 翻译歌词（LRC 格式，可能为空） |

---

### 5.4 搜索音乐

- **URL:** `https://music.163.com/api/cloudsearch/pc`
- **方法:** POST
- **加密:** 否
- **需要 Cookie:** 是

#### 请求参数（form-encoded）

| 参数 | 类型 | 说明 |
|------|------|------|
| `s` | `string` | 搜索关键词 |
| `type` | `int` | 搜索类型：`1`=歌曲, `10`=专辑, `100`=歌手, `1000`=歌单 |
| `limit` | `int` | 返回数量（最大 100） |

#### 响应结构（关键字段）

```json
{
    "code": 200,
    "result": {
        "songs": [
            {
                "id": 1860599566,
                "name": "歌曲名",
                "ar": [{"name": "歌手A"}, {"name": "歌手B"}],
                "al": {
                    "name": "专辑名",
                    "picUrl": "https://..."
                }
            }
        ],
        "songCount": 500
    }
}
```

---

### 5.5 获取歌单详情

- **URL:** `https://music.163.com/api/v6/playlist/detail`
- **方法:** POST
- **加密:** 否
- **需要 Cookie:** 是

#### 请求参数（form-encoded）

| 参数 | 类型 | 说明 |
|------|------|------|
| `id` | `int` | 歌单 ID |

#### 响应结构（关键字段）

```json
{
    "code": 200,
    "playlist": {
        "id": 123456789,
        "name": "歌单名称",
        "coverImgUrl": "https://...",
        "creator": {"nickname": "创建者"},
        "trackCount": 50,
        "description": "歌单描述",
        "trackIds": [
            {"id": 111, "v": 0},
            {"id": 222, "v": 0}
        ]
    }
}
```

> **注意：** `trackIds` 只包含 ID 列表，不包含歌曲名称等详细信息。需要再调用「歌曲详情」接口（每次最多 100 首）来获取完整的歌曲信息。

#### 批量获取歌单歌曲详情

```
POST https://interface3.music.163.com/api/v3/song/detail
c=[{"id":111,"v":0},{"id":222,"v":0}, ...]  // 每次最多 100 个
```

---

### 5.6 获取专辑详情

- **URL:** `https://music.163.com/api/v1/album/{album_id}`
- **方法:** GET
- **加密:** 否
- **需要 Cookie:** 是

#### 响应结构（关键字段）

```json
{
    "code": 200,
    "album": {
        "id": 12345678,
        "name": "专辑名称",
        "pic": 109951167899998,
        "artist": {"name": "歌手名"},
        "publishTime": 1700000000000,
        "description": "专辑描述"
    },
    "songs": [
        {
            "id": 111,
            "name": "曲目1",
            "ar": [{"name": "歌手"}],
            "al": {"name": "专辑名", "pic": 12345}
        }
    ]
}
```

---

## 6. 下载流程

### 6.1 单曲下载完整流程

```
步骤1: 获取歌曲 URL
       POST /eapi/song/enhance/player/url/v1  (加密请求)
       输入: song_id, quality_level
       输出: download_url, file_type, file_size

步骤2: 获取歌曲详情
       POST /api/v3/song/detail
       输入: song_id
       输出: song_name, artists, album, pic_url, duration, track_number

步骤3: 获取歌词（可选）
       POST /api/song/lyric
       输入: song_id
       输出: lyric (LRC格式), translated_lyric

步骤4: 下载文件
       使用步骤1获取的 download_url 发起 GET 请求
       以流式方式写入本地文件

步骤5: 写入元数据标签（可选）
       根据文件格式 (mp3/flac/m4a) 写入:
       - 歌曲名 (title)
       - 艺术家 (artist)
       - 专辑名 (album)
       - 曲目号 (track number)
       - 封面图片 (cover art)
```

### 6.2 文件名安全化

下载的文件名需要在不同操作系统上合法，需要移除以下字符：

```
非法字符: < > : " / \ | ? *
替换为:   _ (下划线)
长度限制: 200 个字符
```

### 6.3 元数据标签对照表

| 信息字段 | MP3 (ID3v2) | FLAC (Vorbis) | M4A (MP4) |
|---------|-------------|---------------|-----------|
| 歌曲名 | `TIT2` | `TITLE` | `©nam` |
| 艺术家 | `TPE1` | `ARTIST` | `©ART` |
| 专辑 | `TALB` | `ALBUM` | `©alb` |
| 曲目号 | `TRCK` | `TRACKNUMBER` | `trkn` |
| 封面 | `APIC` | `Picture` | `covr` |

---

## 7. 二维码登录流程

### 7.1 流程概述

```
步骤1: 生成二维码 Key
       POST /eapi/login/qrcode/unikey (加密请求)
       输入: {"type": 1, "header": "{config_json}"}
       输出: unikey

步骤2: 显示二维码
       构造 URL: https://music.163.com/login?codekey={unikey}
       生成二维码图片（用户可以展示在终端或网页上）

步骤3: 轮询登录状态
       POST /eapi/login/qrcode/client/login (加密请求)
       输入: {"key": unikey, "type": 1, "header": "{config_json}"}
       每 2~5 秒轮询一次
        
       状态码说明:
       ┌──────┬──────────────────────────────┐
       │ code │ 含义                         │
       ├──────┼──────────────────────────────┤
       │ 801  │ 等待扫码                      │
       │ 802  │ 已扫码，等待用户在手机上确认     │
       │ 803  │ 登录成功（从 Set-Cookie 提取   │
       │      │ MUSIC_U）                     │
       │ 800  │ 二维码过期                    │
       │ 其他  │ 登录失败                      │
       └──────┴──────────────────────────────┘

步骤4: 提取 Cookie
       从响应头 Set-Cookie 中提取 MUSIC_U
       构造最终 Cookie: MUSIC_U={value};os=pc;appver=8.9.70;
```

### 7.2 登录状态码详解

| 状态码 | 说明 | 操作 |
|--------|------|------|
| `801` | 等待用户扫码 | 继续轮询 |
| `802` | 已扫码等待确认 | 继续轮询 |
| `803` | 登录成功 | 提取 Cookie 并保存 |
| `800` | 二维码已过期 | 重新生成二维码 |
| 其他 | 错误 | 检查错误信息 |

---

## 8. 常量与配置

### 8.1 全局常量

```
AES_KEY                  = "e82ckenh8dichen8"
USER_AGENT               = "Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 ... NeteaseMusicDesktop/2.10.2.200154"
REFERER                  = "https://music.163.com/"
IMG_ENCRYPT_MAGIC        = "3go8&$8*3*3h0k(2)2"
EAPI_DELIMITER           = "-36cd479b6b5-"
MD5_SALT_PREFIX          = "nobody"
MD5_SALT_SUFFIX          = "md5forencrypt"
DEFAULT_OS               = "pc"
DEFAULT_DEVICE_ID        = "pyncm!"
REQUEST_TIMEOUT          = 30s
MAX_FILE_SIZE            = 500 MB
```

### 8.2 API 端点汇总

| 接口 | URL | 方法 | 加密 | 需要 Cookie |
|------|-----|------|------|------------|
| 歌曲 URL | `https://interface3.music.163.com/eapi/song/enhance/player/url/v1` | POST | 是 | 是 |
| 歌曲详情 | `https://interface3.music.163.com/api/v3/song/detail` | POST | 否 | 否 |
| 歌词 | `https://interface3.music.163.com/api/song/lyric` | POST | 否 | 是 |
| 搜索 | `https://music.163.com/api/cloudsearch/pc` | POST | 否 | 是 |
| 歌单详情 | `https://music.163.com/api/v6/playlist/detail` | POST | 否 | 是 |
| 专辑详情 | `https://music.163.com/api/v1/album/{album_id}` | GET | 否 | 是 |
| 二维码 Key | `https://interface3.music.163.com/eapi/login/qrcode/unikey` | POST | 是 | 否 |
| 二维码状态 | `https://interface3.music.163.com/eapi/login/qrcode/client/login` | POST | 是 | 否 |

---

## 9. 完整调用流程示例

### 9.1 从搜索到下载的完整流程

```
1. 搜索音乐
   POST /api/cloudsearch/pc  {s: "关键词", type: 1, limit: 10}
   → 获取歌曲 ID 列表

2. 获取歌曲详情（验证歌曲信息）
   POST /api/v3/song/detail  {c: [{"id": song_id, "v": 0}]}
   → 获取歌曲名、歌手、专辑、时长

3. 获取播放 URL
   POST /eapi/song/enhance/player/url/v1  (加密)
   → 获取直链 URL、音质、文件大小

4. 获取歌词（可选）
   POST /api/song/lyric  {id: song_id, ...}
   → 获取 LRC 格式歌词

5. 下载文件
   GET {download_url}
   → 流式下载到本地文件

6. 写入元数据标签（可选）
   → 根据文件格式写入歌曲信息、封面
```

### 9.2 封装 API 服务的推荐端点

如果要把此项目封装成 API 服务，建议暴露以下端点：

| 端点 | 方法 | 参数 | 功能 |
|------|------|------|------|
| `/health` | GET | - | 健康检查、Cookie 状态 |
| `/song` | GET/POST | `id`, `level`, `type` | 获取歌曲信息（url/详情/歌词/全部） |
| `/search` | GET/POST | `keyword`, `limit` | 搜索歌曲 |
| `/playlist` | GET/POST | `id` | 获取歌单详情 |
| `/album` | GET/POST | `id` | 获取专辑详情 |
| `/download` | GET/POST | `id`, `quality`, `format` | 下载歌曲（文件流/JSON） |

### 9.3 错误处理

所有 API 返回统一结构：

```json
{
    "status": 200,
    "success": true,
    "message": "操作描述",
    "data": { ... }
}
```

常见错误场景：
- `code != 200`: 网易云 API 返回错误，检查 `message` 字段
- 版权限制：`data` 数组为空或 `url` 为空
- Cookie 失效：需要重新登录
- 音质不可用：尝试降级请求

---

## 10. 各语言实现参考

### 10.1 推荐的实现顺序

1. **常量定义** — URL、Key、User-Agent
2. **AES-ECB 加密** — PKCS7 填充 + hex 输出
3. **EAPI params 构造** — MD5 摘要 + 字符串拼接 + 加密
4. **HTTP 请求封装** — 统一 headers、cookies
5. **Cookie 管理** — 读取、解析、验证、存储
6. **各接口调用** — 按需实现
7. **下载功能** — 流式下载 + 可选标签写入

### 10.2 关键依赖（各语言）

| 功能 | Python | Node.js | Go | Rust |
|------|--------|---------|-----|------|
| HTTP 请求 | `requests` / `aiohttp` | `axios` / `fetch` | `net/http` | `reqwest` |
| AES-ECB | `cryptography` | `crypto` | `crypto/aes` | `aes` |
| MD5 | `hashlib` | `crypto` | `crypto/md5` | `md5` |
| Base64 | `base64` | `Buffer` | `encoding/base64` | `base64` |
| 二维码 | `qrcode` | `qrcode` | `go-qrcode` | `qrcode` |
| 音频标签 | `mutagen` | `music-metadata` | `taglib-go` | `id3` |

### 10.3 注意事项

1. **加密模式是 ECB**，不是 CBC，不需要 IV
2. **PKCS7 填充的块大小是 16 字节**（AES-128 的 block size）
3. **加密后的输出是十六进制小写字符串**，不是 Base64
4. **EAPI 和非 EAPI 接口使用不同的域名**：
   - EAPI: `interface3.music.163.com`
   - 普通 API: `music.163.com` 或 `interface3.music.163.com`
5. **requestId 必须是随机整数**（范围 20000000~30000000），每次都不同
6. **高级音质需要 VIP 账号**，否则返回的 URL 可能为空
7. **下载 URL 有时效性**，获取后需尽快使用
8. **短链接处理**：`163cn.tv` 短链接需要先跟随重定向获取真实 URL，再提取 `id=` 参数

---

> 文档版本: 基于 netease-url v2.0.0 分析  
> 分析日期: 2026-04-30
