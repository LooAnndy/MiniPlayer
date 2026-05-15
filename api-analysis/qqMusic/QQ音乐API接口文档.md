# QQ音乐 API 接口文档 (ArkTS 复现参考)

> 基于 QQMusicApi-nodejs v1.0.0 整理，所有接口已标注 QQ音乐后台真实 module/method 及参数。

---

## 一、架构总览

```
客户端 (ArkTS) ──HTTP──> Node.js 中间层 ──POST──> QQ音乐后台
                                                  │
                          u.y.qq.com/cgi-bin/musicu.fcg  (未签名)
                          u.y.qq.com/cgi-bin/musics.fcg  (带签名)
```

### 1.1 请求封装核心 (ArkTS 需实现)

**请求方式:** `POST`，`Content-Type: application/json`

**请求体结构:**
```typescript
interface QQMusicRequest {
  comm: CommParams
  [key: string]: Object  // key = `${module}.${method}`, value = { module, method, param }
}
```

**公共参数 CommParams:**
| 字段 | 值 | 说明 |
|------|-----|------|
| ct | `'11'` (默认), `'19'` (歌曲URL) | 客户端类型 |
| cv | `'13.2.5.8'` | 版本号 |
| v | `'13.2.5.8'` | 版本号 |
| tmeAppID | `'qqmusic'` | 应用ID |
| format | `'json'` | 返回格式 |
| inCharset | `'utf-8'` | 输入编码 |
| outCharset | `'utf-8'` | 输出编码 |
| qq | musicid (有登录时) | 用户ID |
| authst | musickey (有登录时) | 授权密钥 |
| tmeLoginType | `'1'` 或 `'2'` | 登录类型 |

**Cookie (有登录时):** `uin=${musicid}; qm_keyst=${musickey}; qqmusic_key=${musickey}`

**请求头:**
```
User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36
Referer: https://y.qq.com/
Origin: https://y.qq.com
```

### 1.2 签名算法 (ArkTS 需实现)

使用带签名端点 `musics.fcg` 时，query string 需携带 `sign` 参数：

```
sign = "zzc" + part1 + b64Part + part2 (全小写)
```

**步骤:**
1. `JSON.stringify(requestData)` 后计算 **SHA-1** 哈希，转为大写十六进制字符串
2. 取索引 `[21,4,9,26,16,20,27,30]` 的字符 → `part1`
3. 取索引 `[18,11,3,2,1,7,6,25]` 的字符 → `part2`
4. 遍历 `SCRAMBLE = [21,4,9,26,16,20,27,30,18,11,3,2,1,7,6,25,13,22,19,14]`，每轮取哈希的 2 个十六进制字符转整数，与 `SCRAMBLE[i]` 做 XOR，结果写入 20 字节 Buffer
5. Buffer 转 base64，去掉 `/` `\` `+` `=` → `b64Part`
6. 拼接: `"zzc" + part1 + b64Part + part2`，全转小写

### 1.3 ArkTS 实现注意事项

- **禁止无类型对象字面量**: 所有对象必须先用 `interface` 声明类型
- **所有变量显式标注类型**: 参数、返回值、中间变量全部带类型
- **内联对象必须提取为独立 interface**: 如 `v_songInfo` 需要单独定义 `SongInfoItem`
- **使用 `@ohos.net.http` 发起请求**, 不用 axios

---

## 二、所有 API 接口明细

> 每个接口标注: `module` / `method` (QQ音乐后台真实调用) + 参数

---

### 2.1 搜索 (`/search`)

#### 2.1.1 按类型搜索 `GET/POST /search`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| keyword | string | 是 | - | 搜索关键词 |
| type | number | 否 | 0 | 搜索类型 (见下表) |
| num | number | 否 | 10 | 每页数量 |
| page | number | 否 | 1 | 页码 |
| highlight | boolean | 否 | true | 是否高亮 |

**type 枚举:**
| 值 | 含义 | 返回字段 |
|----|------|----------|
| 0 | 歌曲 | `body.item_song` |
| 1 | 歌手 | `body.singer` |
| 2 | 专辑 | `body.item_album` |
| 3 | 歌单 | `body.item_songlist` |
| 4 | MV | `body.item_mv` |
| 7 | 歌词 | `body.item_song` |
| 8 | 用户 | `body.item_user` |
| 15 | 节目专辑 | `body.item_audio` |
| 18 | 节目 | `body.item_song` |

**QQ音乐后台调用:**
```
module: "music.search.SearchCgiService"
method: "DoSearchForQQMusicMobile"
param: { searchid, query, search_type, num_per_page, page_num, highlight, grp: true }
```

#### 2.1.2 热门搜索词 `GET/POST /search/hotkey`

无参数。

**QQ音乐后台调用:**
```
module: "music.musicsearch.HotkeyService"
method: "GetHotkeyForQQMusicMobile"
param: { search_id }
```

#### 2.1.3 搜索自动补全 `GET/POST /search/complete`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| keyword | string | 是 | 输入词 |

**QQ音乐后台调用:**
```
module: "music.smartboxCgi.SmartBoxCgi"
method: "GetSmartBoxResult"
param: { search_id, query, num_per_page: 0, page_idx: 0 }
```

#### 2.1.4 综合搜索 `GET/POST /search/general`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| keyword | string | 是 | - | 搜索关键词 |
| page | number | 否 | 1 | 页码 |
| highlight | boolean | 否 | true | 是否高亮 |

**QQ音乐后台调用:**
```
module: "music.adaptor.SearchAdaptor"
method: "do_search_v2"
param: { searchid, search_type: 100, page_num: 15, query, page_id, highlight, grp: true }
```

---

### 2.2 歌曲 (`/song`)

#### 2.2.1 查询歌曲信息 `GET/POST /song/query`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | string | 二选一 | 歌曲ID，逗号分隔多个 |
| mid | string | 二选一 | 歌曲mid，逗号分隔多个 |

**QQ音乐后台调用:**
```
module: "music.trackInfo.UniformRuleCtrl"
method: "CgiGetTrackInfo"
param: { ids: number[] } 或 { mids: string[] }, types, modify_stamp, ctx: 0, client: 1
```
返回: `data.tracks`

#### 2.2.2 歌曲详情 `GET/POST /song/detail`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | string/number | 二选一 | 歌曲ID |
| mid | string | 二选一 | 歌曲mid |

**QQ音乐后台调用:**
```
module: "music.pf_song_detail_svr"
method: "get_song_detail_yqq"
param: { song_id: number } 或 { song_mid: string }
```

#### 2.2.3 歌曲播放URL `GET/POST /song/url`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| mid | string | 是 | - | 歌曲mid，逗号分隔多个 |
| type | string | 否 | MP3_128 | 音质类型 |

**音质类型枚举 (SongFileType):**
| 值 | code | 扩展名 | 说明 |
|----|------|--------|------|
| MASTER | AI00 | .flac | 臻品母带 |
| ATMOS_2 | Q000 | .flac | 臻品全景声 |
| ATMOS_51 | Q001 | .flac | 臻品音质 |
| FLAC | F000 | .flac | 无损 |
| OGG_640 | O801 | .ogg | OGG 640kbps |
| OGG_320 | O800 | .ogg | OGG 320kbps |
| OGG_192 | O600 | .ogg | OGG 192kbps |
| OGG_96 | O400 | .ogg | OGG 96kbps |
| MP3_320 | M800 | .mp3 | MP3 320kbps |
| MP3_128 | M500 | .mp3 | MP3 128kbps |
| AAC_192 | C600 | .m4a | AAC 192kbps |
| AAC_96 | C400 | .m4a | AAC 96kbps |
| AAC_48 | C200 | .m4a | AAC 48kbps |

文件命名规则: `{code}{mid}{mid}{ext}` 例: `M500001abc001abc.mp3`
URL 前缀: `https://isure.stream.qqmusic.qq.com/`

**QQ音乐后台调用:**
```
module: "music.vkey.GetVkey"
method: "UrlGetVkey"
param: { filename, guid, songmid, songtype }
common: { ct: "19" }
```
返回: `data.midurlinfo[].purl` 拼接域名得完整URL

#### 2.2.4 相似歌曲 `GET/POST /song/similar`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | number | 是 | 歌曲ID |

**QQ音乐后台调用:**
```
module: "music.recommend.TrackRelationServer"
method: "GetSimilarSongs"
param: { songid: number }
```
返回: `data.vecSong`

#### 2.2.5 歌曲标签 `GET/POST /song/labels`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | number | 是 | 歌曲ID |

**QQ音乐后台调用:**
```
module: "music.recommend.TrackRelationServer"
method: "GetSongLabels"
param: { songid: number }
```
返回: `data.labels`

#### 2.2.6 相关歌单 `GET/POST /song/related/songlist`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | number | 是 | 歌曲ID |

**QQ音乐后台调用:**
```
module: "music.recommend.TrackRelationServer"
method: "GetRelatedPlaylist"
param: { songid: number }
```
返回: `data.vecPlaylist`

#### 2.2.7 相关MV `GET/POST /song/related/mv`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | number | 是 | 歌曲ID |
| lastMvId | string | 否 | 上一条MV ID(翻页) |

**QQ音乐后台调用:**
```
module: "MvService.MvInfoProServer"
method: "GetSongRelatedMv"
param: { songid: number, songtype: 1, lastmvid? }
```
返回: `data.list`

#### 2.2.8 其他版本 `GET/POST /song/other/version`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | number | 二选一 | 歌曲ID |
| mid | string | 二选一 | 歌曲mid |

**QQ音乐后台调用:**
```
module: "music.musichallSong.OtherVersionServer"
method: "GetOtherVersionSongs"
param: { songid } 或 { songmid }
```
返回: `data.versionList`

#### 2.2.9 歌曲收藏数 `GET/POST /song/fav/num`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | string | 是 | 歌曲ID，逗号分隔多个 |

**QQ音乐后台调用:**
```
module: "music.musicasset.SongFavRead"
method: "GetSongFansNumberById"
param: { v_songId: number[] }
```
返回: `data.m_show` (以 songId 为 key 的对象)

---

### 2.3 歌词 (`/lyric`)

#### 2.3.1 获取歌词 `GET/POST /lyric`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | number | 二选一 | - | 歌曲ID |
| mid | string | 二选一 | - | 歌曲mid |
| qrc | boolean | 否 | false | 是否获取逐字歌词 |
| trans | boolean | 否 | true | 是否获取翻译 |
| roma | boolean | 否 | false | 是否获取罗马音 |

**QQ音乐后台调用:**
```
module: "music.musichallSong.PlayLyricInfo"
method: "GetPlayLyricInfo"
param: { songId / songMid, crypt: 1, ct: 11, cv: 13020508, lrc_t: 0, qrc, qrc_t: 0, roma, roma_t: 0, trans, trans_t: 0, type: 1 }
```

**歌词解码:** QQ音乐返回的 `lyric`/`trans`/`roma` 字段为 **base64 编码**，需 `Buffer.from(data, 'base64').toString('utf-8')` 解码。

返回结构:
```typescript
interface LyricData {
  lyric: string   // 原始歌词
  trans: string   // 翻译歌词
  roma: string    // 罗马音
}
```

---

### 2.4 歌手 (`/singer`)

#### 常量枚举 (ArkTS 中需定义为常量)

**AreaType (地区):**
| 值 | 含义 |
|----|------|
| -100 | 全部 |
| 200 | 内地 |
| 2 | 台湾 |
| 5 | 欧美 |
| 4 | 日本 |
| 3 | 韩国 |

**SexType (性别/类型):**
| 值 | 含义 |
|----|------|
| -100 | 全部 |
| 0 | 男 |
| 1 | 女 |
| 2 | 组合 |

**GenreType (风格):**
| 值 | 含义 |
|----|------|
| -100 | 全部 |
| 7 | 流行 |
| 3 | 说唱 |
| 19 | 国风 |
| 4 | 摇滚 |
| 2 | 电子 |
| 8 | 民谣 |
| 11 | R&B |

**IndexType (索引):**
| 值 | 含义 |
|----|------|
| -100 | 全部 |
| 27 | # |

#### 2.4.1 歌手详情 `GET/POST /singer/detail`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mid | string | 是 | 歌手mid |

**QQ音乐后台调用:**
```
module: "music.musichallSinger.SingerInfoInter"
method: "GetSingerDetail"
param: { singer_mids: string[], groups: 1, wikis: 1 }
```
返回: `data.singer_list`

#### 2.4.2 歌手主页信息 `GET/POST /singer/info`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mid | string | 是 | 歌手mid |

**QQ音乐后台调用:**
```
module: "music.UnifiedHomepage.UnifiedHomepageSrv"
method: "GetHomepageHeader"
param: { SingerMid: string }
```

#### 2.4.3 歌手歌曲列表 `GET/POST /singer/songs`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| mid | string | 是 | - | 歌手mid |
| num | number | 否 | 30 | 每页数量 |
| begin | number | 否 | 0 | 起始偏移 |

**QQ音乐后台调用:**
```
module: "musichall.song_list_server"
method: "GetSingerSongList"
param: { singerMid, order: 1, number, begin }
```
返回: `{ total: data.totalNum, list: data.songList[].songInfo }`

#### 2.4.4 歌手专辑列表 `GET/POST /singer/albums`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| mid | string | 是 | - | 歌手mid |
| num | number | 否 | 30 | 每页数量 |
| begin | number | 否 | 0 | 起始偏移 |

**QQ音乐后台调用:**
```
module: "music.musichallAlbum.AlbumListServer"
method: "GetAlbumList"
param: { singerMid, order: 1, number, begin }
```
返回: `{ total: data.total, list: data.albumList }`

#### 2.4.5 歌手MV列表 `GET/POST /singer/mvs`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| mid | string | 是 | - | 歌手mid |
| num | number | 否 | 30 | 每页数量 |
| begin | number | 否 | 0 | 起始偏移 |

**QQ音乐后台调用:**
```
module: "MvService.MvInfoProServer"
method: "GetSingerMvList"
param: { singermid, order: 1, count, start }
```
返回: `{ total: data.total, list: data.list }`

#### 2.4.6 相似歌手 `GET/POST /singer/similar`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| mid | string | 是 | - | 歌手mid |
| num | number | 否 | 10 | 数量 |

**QQ音乐后台调用:**
```
module: "music.SimilarSingerSvr"
method: "GetSimilarSingerList"
param: { singerMid, number }
```
返回: `data.singerlist`

#### 2.4.7 热门歌手 `GET/POST /singer/hot`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| area | number | 否 | -100 | 地区 |
| sex | number | 否 | -100 | 性别 |
| genre | number | 否 | -100 | 风格 |

**QQ音乐后台调用:**
```
module: "music.musichallSinger.SingerList"
method: "GetSingerList"
param: { hastag: 0, area, sex, genre }
```
返回: `data.hotlist`

#### 2.4.8 歌手分类列表 `GET/POST /singer/list`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| area | number | 否 | -100 | 地区 |
| sex | number | 否 | -100 | 性别 |
| genre | number | 否 | -100 | 风格 |
| index | number | 否 | -100 | 首字母索引 |
| page | number | 否 | 1 | 页码(每页80条) |

**QQ音乐后台调用:**
```
module: "music.musichallSinger.SingerList"
method: "GetSingerListIndex"
param: { area, sex, genre, index, sin: (page-1)*80, cur_page: page }
```
返回: `{ total, list: data.singerlist }`

#### 2.4.9 歌手粉丝数 `GET/POST /singer/fans/num`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| mid | string | 是 | 歌手mid，逗号分隔多个 |

**QQ音乐后台调用:**
```
module: "music.concern.RelationServer"
method: "GetFollowSingerNum"
param: { vec_singer: [{ singer_mid }...] }
```
返回: `data.map`

---

### 2.5 专辑 (`/album`)

#### 2.5.1 专辑封面 `GET/POST /album/cover`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| mid | string | 是 | - | 专辑mid |
| size | number | 否 | 300 | 尺寸 (150/300/500/800) |

**直接返回URL，不调用后台API:**
```
https://y.gtimg.cn/music/photo_new/T002R{size}x{size}M000{mid}.jpg
```

#### 2.5.2 专辑详情 `GET/POST /album/detail`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| id | number | 二选一 | 专辑ID |
| mid | string | 二选一 | 专辑mid |

**QQ音乐后台调用:**
```
module: "music.musichallAlbum.AlbumInfoServer"
method: "GetAlbumDetail"
param: { albumId } 或 { albumMId }
```

#### 2.5.3 专辑歌曲列表 `GET/POST /album/songs`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | number | 二选一 | - | 专辑ID |
| mid | string | 二选一 | - | 专辑mid |
| num | number | 否 | 50 | 每页数量 |
| page | number | 否 | 1 | 页码 |

**QQ音乐后台调用:**
```
module: "music.musichallAlbum.AlbumSongList"
method: "GetAlbumSongList"
param: { albumId/albumMid, begin: (page-1)*num, num }
```
返回: `data.songList[].songInfo`

#### 2.5.4 新专辑 `GET/POST /album/new`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| area | number | 否 | 1 | 地区 |
| num | number | 否 | 20 | 每页数量 |
| page | number | 否 | 1 | 页码 |

**QQ音乐后台调用:**
```
module: "music.musichallAlbum.AlbumListServer"
method: "GetAlbumList"
param: { area, sin: (page-1)*num, num }
```

---

### 2.6 歌单 (`/songlist`)

#### 2.6.1 歌单详情 `GET/POST /songlist/detail`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | number | 是 | - | 歌单ID |
| dirid | number | 否 | 0 | 目录ID |

**QQ音乐后台调用:**
```
module: "music.srfDissInfo.DissInfo"
method: "CgiGetDiss"
param: { disstid, dirid, song_num: 0, song_begin: 0, onlysonglist: 0, tag: true, userinfo: true, orderlist: true }
```
返回: `{ dirinfo, total_song_num, songlist_size, songlist, songtag, orderlist }`

#### 2.6.2 歌单歌曲列表 `GET/POST /songlist/songs`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | number | 是 | - | 歌单ID |
| dirid | number | 否 | 0 | 目录ID |
| num | number | 否 | 50 | 每页数量 |
| page | number | 否 | 1 | 页码 |

**QQ音乐后台调用:**
```
module: "music.srfDissInfo.DissInfo"
method: "CgiGetDiss"
param: { disstid, dirid, song_num: num, song_begin: (page-1)*num, onlysonglist: 1, tag: false, userinfo: false, orderlist: false }
```
返回: `data.songlist`

#### 2.6.3 歌单分类 `GET/POST /songlist/category`

无参数。

**QQ音乐后台调用:**
```
module: "music.playlist.PlaylistSquare"
method: "GetAllTag"
param: {}
```

#### 2.6.4 分类歌单列表 `GET/POST /songlist/list`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| categoryId | number | 否 | 10000000 | 分类ID |
| sortId | number | 否 | 5 | 排序ID |
| num | number | 否 | 20 | 每页数量 |
| page | number | 否 | 1 | 页码 |

**QQ音乐后台调用:**
```
module: "music.playlist.PlaylistSquare"
method: "GetPlaylistByCategory"
param: { categoryId, sortId, sin: (page-1)*num, ein: page*num-1 }
```

#### 2.6.5 推荐歌单 `GET/POST /songlist/recommend`

无参数。

**QQ音乐后台调用:**
```
module: "music.playlist.PlaylistSquare"
method: "GetRecommendFeed"
param: { From: 0, Size: 25 }
```

#### 2.6.6 创建歌单 `GET/POST /songlist/create` ⚠需登录

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| name | string | 是 | 歌单名称 |

**QQ音乐后台调用:**
```
module: "music.musicasset.PlaylistBaseWrite"
method: "AddPlaylist"
param: { dirName }
```

#### 2.6.7 删除歌单 `GET/POST /songlist/delete` ⚠需登录

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| dirid | number | 是 | 歌单目录ID |

**QQ音乐后台调用:**
```
module: "music.musicasset.PlaylistBaseWrite"
method: "DelPlaylist"
param: { dirId }
```

#### 2.6.8 添加歌曲到歌单 `GET/POST /songlist/add/songs` ⚠需登录

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| dirid | number | 否 | 1 | 歌单目录ID |
| songIds | string | 是 | - | 歌曲ID，逗号分隔 |

**QQ音乐后台调用:**
```
module: "music.musicasset.PlaylistDetailWrite"
method: "AddSonglist"
param: { dirId, v_songInfo: [{ songType: 0, songId }...] }
```

**ArkTS 接口定义:**
```typescript
interface SongInfoItem {
  songType: number
  songId: number
}
```

#### 2.6.9 从歌单移除歌曲 `GET/POST /songlist/del/songs` ⚠需登录

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| dirid | number | 否 | 1 | 歌单目录ID |
| songIds | string | 是 | - | 歌曲ID，逗号分隔 |

**QQ音乐后台调用:**
```
module: "music.musicasset.PlaylistDetailWrite"
method: "DelSonglist"
param: { dirId, v_songInfo: [{ songType: 0, songId }...] }
```

---

### 2.7 排行榜 (`/top`)

#### 2.7.1 排行榜分类 `GET/POST /top/category`

无参数。

**QQ音乐后台调用:**
```
module: "music.musicToplist.Toplist"
method: "GetAll"
param: {}
```
返回: `data.group`

#### 2.7.2 排行榜详情 `GET/POST /top/detail`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | number | 是 | - | 排行榜ID |
| num | number | 否 | 100 | 每页数量 |
| page | number | 否 | 1 | 页码 |
| tag | boolean | 否 | true | 是否包含标签 |

**QQ音乐后台调用:**
```
module: "music.musicToplist.Toplist"
method: "GetDetail"
param: { topId, offset: (page-1)*num, num, withTags: tag }
```

---

### 2.8 推荐 (`/recommend`)

#### 2.8.1 首页推荐 `GET/POST /recommend/home`

无参数。

**QQ音乐后台调用:**
```
module: "music.recommend.RecommendFeed"
method: "get_recommend_feed"
param: { direction: 0, page: 1, s_num: 0 }
```

#### 2.8.2 猜你喜欢 `GET/POST /recommend/guess`

无参数。

**QQ音乐后台调用:**
```
module: "music.radioProxy.MbTrackRadioSvr"
method: "get_radio_track"
param: { id: 99, num: 5, from: 0, scene: 0, song_ids: [], ext: { bluetooth: "" }, should_count_down: 1 }
```

#### 2.8.3 雷达推荐 `GET/POST /recommend/radar`

无参数。

**QQ音乐后台调用:**
```
module: "music.recommend.TrackRelationServer"
method: "GetRadarSong"
param: { Page: 1, ReqType: 0, FavSongs: [], EntranceSongs: [] }
```

#### 2.8.4 每日推荐 `GET/POST /recommend/daily` ⚠需登录

无参数。

**QQ音乐后台调用:**
```
module: "music.recommend.RecSongListServer"
method: "get_daily_recommend_song"
param: {}
```

#### 2.8.5 推荐歌单 `GET/POST /recommend/songlist`

无参数。

**QQ音乐后台调用:**
```
module: "music.playlist.PlaylistSquare"
method: "GetRecommendFeed"
param: { From: 0, Size: 25 }
```

#### 2.8.6 新歌推荐 `GET/POST /recommend/new/songs`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| type | number | 否 | 5 | 类型 |

**QQ音乐后台调用:**
```
module: "newsong.NewSongServer"
method: "get_new_song_info"
param: { type }
```

#### 2.8.7 电台推荐 `GET/POST /recommend/radio`

无参数。

**QQ音乐后台调用:**
```
module: "music.radiosvr.RadioProxy"
method: "GetRadioList"
param: {}
```

---

### 2.9 MV (`/mv`)

#### 2.9.1 MV详情 `GET/POST /mv/detail`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| vid | string | 是 | MV的vid，逗号分隔多个 |

**QQ音乐后台调用:**
```
module: "video.VideoDataServer"
method: "get_video_info_batch"
param: {
  vidlist: string[],
  required: ['vid','type','sid','cover_pic','duration','singers','video_switch','msg','name','desc','playcnt','pubdate','isfav','gmid','uploader_headurl','uploader_nick','uploader_encuin','uploader_uin','uploader_hasfollow','uploader_follower_num','related_songs']
}
```

#### 2.9.2 MV播放URL `GET/POST /mv/url`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| vid | string | 是 | MV的vid，逗号分隔多个 |

**QQ音乐后台调用:**
```
module: "music.stream.MvUrlProxy"
method: "GetMvUrls"
param: { vids, request_type: 10003, guid, videoformat: 1, format: 265, dolby: 1, use_new_domain: 1, use_ipv6: 1 }
```

**返回结构 (ArkTS interface):**
```typescript
interface MvUrlResult {
  [vid: string]: {
    mp4: Record<string, string>   // key=filetype, value=url
    hls: Record<string, string>   // key=filetype, value=url
  }
}
```

URL 取自 `freeflow_url[0]`。

#### 2.9.3 推荐MV `GET/POST /mv/recommend`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| num | number | 否 | 20 | 每页数量 |
| page | number | 否 | 1 | 页码 |

**QQ音乐后台调用:**
```
module: "MvService.MvInfoProServer"
method: "GetRecommendMv"
param: { start: (page-1)*num, size: num }
```

#### 2.9.4 MV排行榜 `GET/POST /mv/rank`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| area | number | 否 | 15 | 地区 |
| num | number | 否 | 20 | 每页数量 |
| page | number | 否 | 1 | 页码 |

**QQ音乐后台调用:**
```
module: "MvService.MvInfoProServer"
method: "GetMvRank"
param: { area, start: (page-1)*num, size: num }
```

---

### 2.10 评论 (`/comment`)

**CommentType 枚举:**

| 值 | 含义 |
|----|------|
| 1 | 歌曲 |
| 2 | 专辑 |
| 3 | 歌单 |
| 5 | MV |

**评论返回结构 (ArkTS interface):**
```typescript
interface SubComment {
  Avatar: string
  Nick: string
  Content: string
  Pic: string
  PraiseNum: number
  SeqNo: string
}

interface CommentItem {
  Avatar: string
  CmId: string
  PraiseNum: number
  Nick: string
  Pic: string
  Content: string
  SeqNo: string
  SubComments: SubComment[]
}
```

#### 2.10.1 评论数量 `GET/POST /comment/count`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | string | 是 | - | 目标ID |
| type | number | 否 | 1 | 评论类型 |

**QQ音乐后台调用:**
```
module: "music.globalComment.CommentCountSrv"
method: "GetCmCount"
param: { request: { biz_id, biz_type, biz_sub_type: 2 } }
```
返回: `data.response`

#### 2.10.2 热门评论 `GET/POST /comment/hot`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | string | 是 | - | 目标ID |
| type | number | 否 | 1 | 评论类型 |
| pageNum | number | 否 | 1 | 页码 |
| pageSize | number | 否 | 15 | 每页数量 |
| lastSeqNo | string | 否 | '' | 上一页最后序号 |

**QQ音乐后台调用:**
```
module: "music.globalComment.CommentRead"
method: "GetHotCommentList"
param: { BizType, BizId, LastCommentSeqNo, PageSize, PageNum: pageNum-1, HotType: 1, WithAirborne: 0, PicEnable: 1 }
```
返回: `processComments(data)` → `data.CommentList.Comments[]`

#### 2.10.3 最新评论 `GET/POST /comment/new`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | string | 是 | - | 目标ID |
| type | number | 否 | 1 | 评论类型 |
| pageNum | number | 否 | 1 | 页码 |
| pageSize | number | 否 | 15 | 每页数量 |
| lastSeqNo | string | 否 | '' | 上一页最后序号 |

**QQ音乐后台调用:**
```
module: "music.globalComment.CommentRead"
method: "GetNewCommentList"
param: { PageSize, PageNum: pageNum-1, HashTagID: '', BizType, PicEnable: 1, LastCommentSeqNo, SelfSeeEnable: 1, BizId, AudioEnable: 1 }
```

#### 2.10.4 推荐评论 `GET/POST /comment/recommend`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| id | string | 是 | - | 目标ID |
| type | number | 否 | 1 | 评论类型 |
| pageNum | number | 否 | 1 | 页码 |
| pageSize | number | 否 | 15 | 每页数量 |
| lastSeqNo | string | 否 | '' | 上一页最后序号 |

**QQ音乐后台调用:**
```
module: "music.globalComment.CommentRead"
method: "GetRecCommentList"
param: { PageSize, PageNum: pageNum-1, BizType, PicEnable: 1, Flag: 1, LastCommentSeqNo, CmListUIVer: 1, BizId, AudioEnable: 1 }
```

---

### 2.11 用户 (`/user`)

#### 2.11.1 musicid→euin `GET/POST /user/euin`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| musicid | string | 是 | QQ音乐用户ID |

**调用方式:** 直接 GET (非标准 apiRequest)
```
GET https://c6.y.qq.com/rsc/fcgi-bin/fcg_get_profile_homepage.fcg
  ?ct=20&cv=4747474&cid=205360838&userid=${musicid}
```
返回: `data.data.creator.encrypt_uin`

#### 2.11.2 euin→musicid `GET/POST /user/musicid`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| euin | string | 是 | 加密uin |

**QQ音乐后台调用:**
```
module: "music.srfDissInfo.DissInfo"
method: "CgiGetDiss"
param: { disstid: 0, dirid: 201, song_num: 1, enc_host_uin: euin, onlysonglist: 1 }
```
返回: `data.dirinfo.creator.musicid`

#### 2.11.3 用户主页 `GET/POST /user/homepage`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| euin | string | 是 | 加密uin |

**QQ音乐后台调用:**
```
module: "music.UnifiedHomepage.UnifiedHomepageSrv"
method: "GetHomepageHeader"
param: { uin: euin, IsQueryTabDetail: 1 }
```

#### 2.11.4 VIP信息 `GET/POST /user/vip` ⚠需登录

无参数。

**QQ音乐后台调用:**
```
module: "VipLogin.VipLoginInter"
method: "vip_login_base"
param: {}
```

#### 2.11.5 用户创建的歌单 `GET/POST /user/songlist/created`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| uin | string | 是 | 用户QQ号 |

**QQ音乐后台调用:**
```
module: "music.musicasset.PlaylistBaseRead"
method: "GetPlaylistByUin"
param: { uin }
```
返回: `data.v_playlist`

#### 2.11.6 用户收藏的歌曲 `GET/POST /user/fav/songs`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| euin | string | 是 | - | 加密uin |
| num | number | 否 | 10 | 每页数量 |
| page | number | 否 | 1 | 页码 |

**QQ音乐后台调用:**
```
module: "music.srfDissInfo.DissInfo"
method: "CgiGetDiss"
param: { disstid: 0, dirid: 201, tag: true, song_begin: num*(page-1), song_num: num, userinfo: true, orderlist: true, enc_host_uin: euin }
```
返回: `{ dirinfo, total_song_num, songlist }`

#### 2.11.7 用户收藏的歌单 `GET/POST /user/fav/songlist`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| euin | string | 是 | - | 加密uin |
| num | number | 否 | 10 | 每页数量 |
| page | number | 否 | 1 | 页码 |

**QQ音乐后台调用:**
```
module: "music.musicasset.PlaylistFavRead"
method: "CgiGetPlaylistFavInfo"
param: { uin: euin, offset: (page-1)*num, size: num }
```

#### 2.11.8 用户收藏的专辑 `GET/POST /user/fav/album`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| euin | string | 是 | - | 加密uin |
| num | number | 否 | 10 | 每页数量 |
| page | number | 否 | 1 | 页码 |

**QQ音乐后台调用:**
```
module: "music.musicasset.AlbumFavRead"
method: "CgiGetAlbumFavInfo"
param: { euin, offset: (page-1)*num, size: num }
```

#### 2.11.9 用户收藏的MV `GET/POST /user/fav/mv`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| euin | string | 是 | - | 加密uin |
| num | number | 否 | 10 | 每页数量 |
| page | number | 否 | 1 | 页码 |

**QQ音乐后台调用:**
```
module: "music.musicasset.MVFavRead"
method: "getMyFavMV_v2"
param: { encuin: euin, pagesize: num, num: page-1 }
```

#### 2.11.10 关注的歌手 `GET/POST /user/follow/singers`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| euin | string | 是 | - | 加密uin |
| num | number | 否 | 10 | 每页数量 |
| page | number | 否 | 1 | 页码 |

**QQ音乐后台调用:**
```
module: "music.concern.RelationList"
method: "GetFollowSingerList"
param: { HostUin: euin, From: (page-1)*num, Size: num }
```
返回: `{ total: data.Total, list: data.List }`

#### 2.11.11 粉丝列表 `GET/POST /user/fans`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| euin | string | 是 | - | 加密uin |
| num | number | 否 | 10 | 每页数量 |
| page | number | 否 | 1 | 页码 |

**QQ音乐后台调用:**
```
module: "music.concern.RelationList"
method: "GetFansList"
param: { HostUin: euin, From: (page-1)*num, Size: num }
```
返回: `{ total: data.Total, list: data.List }`

#### 2.11.12 关注的用户 `GET/POST /user/follows`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| euin | string | 是 | - | 加密uin |
| num | number | 否 | 10 | 每页数量 |
| page | number | 否 | 1 | 页码 |

**QQ音乐后台调用:**
```
module: "music.concern.RelationList"
method: "GetFollowUserList"
param: { HostUin: euin, From: (page-1)*num, Size: num }
```
返回: `{ total: data.Total, list: data.List }`

#### 2.11.13 好友列表 `GET/POST /user/friends` ⚠需登录

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| num | number | 否 | 10 | 每页数量 |
| page | number | 否 | 1 | 页码 |

**QQ音乐后台调用:**
```
module: "music.homepage.Friendship"
method: "GetFriendList"
param: { PageSize: num, Page: page-1 }
```
返回: `{ total: data.Friends.length, list: data.Friends }`

#### 2.11.14 音乐基因 `GET/POST /user/music/gene`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| euin | string | 是 | 加密uin |

**QQ音乐后台调用:**
```
module: "music.recommend.UserProfileSettingSvr"
method: "GetProfileReport"
param: { VisitAccount: euin }
```

---

### 2.12 登录 (`/login`)

#### 2.12.1 QQ扫码登录 - 获取二维码 `GET/POST /login/qrcode/qq`

无参数。

**实现:** 直接 GET 腾讯 PTLogin 接口
```
GET https://ssl.ptlogin2.qq.com/ptqrshow
  ?appid=716027609&e=2&l=M&s=3&d=72&v=4&t=Math.random()&daid=383&pt_3rd_aid=100497308
Headers: { Referer: "https://xui.ptlogin2.qq.com/" }
ResponseType: arraybuffer
```
从 `set-cookie` 提取 `qrsig`，图片 buffer 转 base64。
返回: `{ type: 'qq', qrcode: 'data:image/png;base64,...', qrsig }`

#### 2.12.2 QQ扫码登录 - 检查状态 `GET/POST /login/qrcode/qq/check`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| qrsig | string | 是 | 上一步获取的qrsig |

**hash33 算法 (ArkTS 需实现):**
```typescript
function hash33(str: string, hash: number = 0): number {
  for (let i = 0; i < str.length; i++) {
    hash += (hash << 5) + str.charCodeAt(i)
  }
  return hash & 0x7fffffff
}
```

```
GET https://ssl.ptlogin2.qq.com/ptqrlogin
  ?u1=https://graph.qq.com/oauth2.0/login_jump
  &ptqrtoken=${hash33(qrsig)}
  &ptredirect=0&h=1&t=1&g=1&from_ui=1&ptlang=2052
  &action=0-0-${Date.now()}
  &js_ver=20102616&js_type=1&pt_uistyle=40
  &aid=716027609&daid=383&pt_3rd_aid=100497308&has_onekey=1
Headers: { Cookie: "qrsig=${qrsig}", Referer: "https://xui.ptlogin2.qq.com/" }
```

响应解析正则: `ptuiCB\('(\d+)','(\d+)','([^']*)','(\d+)','([^']*)','([^']*)'\)`

状态码映射:
| code | 状态 | 含义 |
|------|------|------|
| 0 | success | 登录成功 |
| 66 | waiting | 等待扫码 |
| 67 | scanned | 已扫码待确认 |
| 65 | expired | 二维码过期 |
| 68 | refused | 拒绝登录 |

成功时从 url 提取 `ptsigx` 和 `uin`。

#### 2.12.3 微信扫码登录 - 获取二维码 `GET/POST /login/qrcode/wx`

无参数。

```
GET https://open.weixin.qq.com/connect/qrconnect
  ?appid=wx48db31d50e334801
  &redirect_uri=https://y.qq.com/portal/wx_redirect.html?login_type=2&surl=https://y.qq.com/
  &response_type=code&scope=snsapi_login&state=STATE
  &href=https://y.qq.com/mediastyle/music_v17/src/css/popup_wechat.css#wechat_redirect
```
从响应中正则提取 `uuid`，然后用 uuid 获取二维码图片:
```
GET https://open.weixin.qq.com/connect/qrcode/${uuid}
Headers: { Referer: "https://open.weixin.qq.com/connect/qrconnect" }
```
返回: `{ type: 'wx', qrcode: 'data:image/jpeg;base64,...', uuid }`

#### 2.12.4 微信扫码登录 - 检查状态 `GET/POST /login/qrcode/wx/check`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| uuid | string | 是 | 上一步获取的uuid |

```
GET https://lp.open.weixin.qq.com/connect/l/qrconnect
  ?uuid=${uuid}&_=${Date.now()}
Headers: { Referer: "https://open.weixin.qq.com/" }
```
解析: `window\.wx_errcode=(\d+);window\.wx_code='([^']*)'`

状态码映射:
| errcode | 状态 | 含义 |
|---------|------|------|
| 405 | success | 登录成功 |
| 408 | waiting | 等待扫码 |
| 404 | scanned | 已扫码待确认 |
| 403 | refused | 拒绝登录 |

#### 2.12.5 发送手机验证码 `GET/POST /login/phone/send`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| phone | string | 是 | - | 手机号 |
| countryCode | string | 否 | '86' | 国家代码 |

**QQ音乐后台调用:**
```
module: "music.login.LoginServer"
method: "SendPhoneAuthCode"
param: { tmeAppid: 'qqmusic', phoneNo, areaCode: countryCode }
common: { tmeLoginMethod: '3' }
```
返回码: 0=已发送, 20276=需要滑块验证, 100001=频率过高

#### 2.12.6 手机验证码登录 `GET/POST /login/phone`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| phone | string | 是 | - | 手机号 |
| code | string | 是 | - | 验证码 |
| countryCode | string | 否 | '86' | 国家代码 |

**QQ音乐后台调用:**
```
module: "music.login.LoginServer"
method: "Login"
param: { code, phoneNo: phone, areaCode: countryCode, loginMode: 1 }
common: { tmeLoginMethod: '3', tmeLoginType: '0' }
```
返回: 登录凭证 (含 musicid, musickey)

#### 2.12.7 检查凭证是否过期 `GET/POST /login/check`

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| musicid | string | 是 | 用户ID |
| musickey | string | 是 | 授权密钥 |

**QQ音乐后台调用:**
```
module: "music.UserInfo.userInfoServer"
method: "GetLoginUserInfo"
param: {}
credential: { musicid, musickey }
```
成功返回 `{ expired: false }`，失败返回 `{ expired: true }`

#### 2.12.8 刷新登录凭证 `GET/POST /login/refresh`

| 参数 | 类型 | 必填 | 默认值 | 说明 |
|------|------|------|--------|------|
| musicid | string | 是 | - | 用户ID |
| musickey | string | 是 | - | 授权密钥 |
| refreshKey | string | 否 | '' | 刷新key |
| refreshToken | string | 否 | '' | 刷新token |
| loginType | number | 否 | 1 | 登录类型 |

**QQ音乐后台调用:**
```
module: "music.login.LoginServer"
method: "Login"
param: { refresh_key, refresh_token, musickey, musicid }
common: { tmeLoginType }
credential: { musicid, musickey, login_type: loginType }
```

---

## 三、ArkTS 核心实现参考

### 3.1 请求封装

```typescript
// 需要定义所有接口类型
interface CommParams {
  ct: string
  cv: string
  v: string
  tmeAppID: string
  format: string
  inCharset: string
  outCharset: string
  qq?: string
  authst?: string
  tmeLoginType?: string
  tmeLoginMethod?: string
}

interface Credential {
  musicid: string
  musickey: string
  login_type?: number
}

interface ApiRequestParam {
  module: string
  method: string
  param: Object
}

interface QQMusicRequestBody {
  comm: CommParams
  [key: string]: Object  // key = `${module}.${method}`
}

// 签名函数 (需要 @ohos.security.cryptoFramework 或纯 JS SHA-1)
// 端点: https://u.y.qq.com/cgi-bin/musics.fcg?sign=${sign}
```

### 3.2 关键工具函数

```
GUID: 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx' 随机生成
SearchID: 'search_${Date.now()}_${Math.random().toString(36).substring(2, 15)}'
```

### 3.3 ArkTS 特殊约束提醒

1. 所有对象字面量必须有对应的 `interface` 声明
2. 调用 `@ohos.net.http` 的 `request()` 方法发起 POST
3. 签名算法的 SHA-1 可用 `@ohos.security.cryptoFramework` 或纯 JS 实现
4. base64 编解码可用 `@ohos.util` 或纯 JS `TextEncoder`/`TextDecoder`
5. 二维码图片 arraybuffer → base64 用 `bufferToString` 等工具函数

---

## 四、接口汇总速查表

| 分类 | 路由 | 需登录 | 说明 |
|------|------|--------|------|
| 搜索 | `/search` | | 按类型搜索 |
| 搜索 | `/search/hotkey` | | 热门搜索词 |
| 搜索 | `/search/complete` | | 搜索补全 |
| 搜索 | `/search/general` | | 综合搜索 |
| 歌曲 | `/song/query` | | 批量查询歌曲 |
| 歌曲 | `/song/detail` | | 歌曲详情 |
| 歌曲 | `/song/url` | | 播放URL |
| 歌曲 | `/song/similar` | | 相似歌曲 |
| 歌曲 | `/song/labels` | | 歌曲标签 |
| 歌曲 | `/song/related/songlist` | | 相关歌单 |
| 歌曲 | `/song/related/mv` | | 相关MV |
| 歌曲 | `/song/other/version` | | 其他版本 |
| 歌曲 | `/song/fav/num` | | 收藏数 |
| 歌词 | `/lyric` | | 歌词(含翻译/罗马音) |
| 歌手 | `/singer/detail` | | 歌手详情 |
| 歌手 | `/singer/info` | | 歌手主页 |
| 歌手 | `/singer/songs` | | 歌手歌曲 |
| 歌手 | `/singer/albums` | | 歌手专辑 |
| 歌手 | `/singer/mvs` | | 歌手MV |
| 歌手 | `/singer/similar` | | 相似歌手 |
| 歌手 | `/singer/hot` | | 热门歌手 |
| 歌手 | `/singer/list` | | 歌手分类列表 |
| 歌手 | `/singer/fans/num` | | 歌手粉丝数 |
| 专辑 | `/album/cover` | | 专辑封面URL |
| 专辑 | `/album/detail` | | 专辑详情 |
| 专辑 | `/album/songs` | | 专辑歌曲 |
| 专辑 | `/album/new` | | 新专辑 |
| 歌单 | `/songlist/detail` | | 歌单详情 |
| 歌单 | `/songlist/songs` | | 歌单歌曲 |
| 歌单 | `/songlist/category` | | 歌单分类 |
| 歌单 | `/songlist/list` | | 分类歌单 |
| 歌单 | `/songlist/recommend` | | 推荐歌单 |
| 歌单 | `/songlist/create` | ⚠ | 创建歌单 |
| 歌单 | `/songlist/delete` | ⚠ | 删除歌单 |
| 歌单 | `/songlist/add/songs` | ⚠ | 添加歌曲 |
| 歌单 | `/songlist/del/songs` | ⚠ | 移除歌曲 |
| 排行 | `/top/category` | | 排行榜分类 |
| 排行 | `/top/detail` | | 排行榜详情 |
| 推荐 | `/recommend/home` | | 首页推荐 |
| 推荐 | `/recommend/guess` | | 猜你喜欢 |
| 推荐 | `/recommend/radar` | | 雷达推荐 |
| 推荐 | `/recommend/daily` | ⚠ | 每日推荐 |
| 推荐 | `/recommend/songlist` | | 推荐歌单 |
| 推荐 | `/recommend/new/songs` | | 新歌推荐 |
| 推荐 | `/recommend/radio` | | 电台推荐 |
| MV | `/mv/detail` | | MV详情 |
| MV | `/mv/url` | | MV播放URL |
| MV | `/mv/recommend` | | 推荐MV |
| MV | `/mv/rank` | | MV排行榜 |
| 评论 | `/comment/count` | | 评论数量 |
| 评论 | `/comment/hot` | | 热门评论 |
| 评论 | `/comment/new` | | 最新评论 |
| 评论 | `/comment/recommend` | | 推荐评论 |
| 用户 | `/user/euin` | | musicid→euin |
| 用户 | `/user/musicid` | | euin→musicid |
| 用户 | `/user/homepage` | | 用户主页 |
| 用户 | `/user/vip` | ⚠ | VIP信息 |
| 用户 | `/user/songlist/created` | | 用户创建的歌单 |
| 用户 | `/user/fav/songs` | | 收藏歌曲 |
| 用户 | `/user/fav/songlist` | | 收藏歌单 |
| 用户 | `/user/fav/album` | | 收藏专辑 |
| 用户 | `/user/fav/mv` | | 收藏MV |
| 用户 | `/user/follow/singers` | | 关注歌手 |
| 用户 | `/user/fans` | | 粉丝列表 |
| 用户 | `/user/follows` | | 关注用户 |
| 用户 | `/user/friends` | ⚠ | 好友列表 |
| 用户 | `/user/music/gene` | | 音乐基因 |
| 登录 | `/login/qrcode/qq` | | QQ二维码 |
| 登录 | `/login/qrcode/qq/check` | | QQ扫码状态 |
| 登录 | `/login/qrcode/wx` | | 微信二维码 |
| 登录 | `/login/qrcode/wx/check` | | 微信扫码状态 |
| 登录 | `/login/phone/send` | | 发送验证码 |
| 登录 | `/login/phone` | | 手机登录 |
| 登录 | `/login/check` | | 检查凭证 |
| 登录 | `/login/refresh` | | 刷新凭证 |

**共 56 个接口**，其中 9 个需要登录凭证。
