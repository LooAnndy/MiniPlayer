/**
 * QQ 音乐 API 服务 —— 基于 QQ音乐API接口文档.md (Node.js v1.0.0)
 *
 * 所有接口统一 POST https://u.y.qq.com/cgi-bin/musicu.fcg (JSON)
 * 搜索: module=music.search.SearchCgiService, method=DoSearchForQQMusicMobile
 * 播放: module=music.vkey.GetVkey, method=UrlGetVkey
 */
import { HttpUtils } from '../utils/HttpUtils';
import { Song, Platform } from '../model/Song';

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const REFERER = 'https://y.qq.com/';
const API_URL = 'https://u.y.qq.com/cgi-bin/musicu.fcg';

// ---- 公共参数 ----
interface CommParams {
  ct: string;
  cv: string;
  v: string;
  tmeAppID: string;
  format: string;
  inCharset: string;
  outCharset: string;
  uin: string;
}

// ---- 请求信封 ----
interface ReqModule {
  module: string;
  method: string;
  param: Object;
}

interface MusicuRequest {
  comm: CommParams;
  req_0: ReqModule;
}

// ---- 搜索参数 ----
interface SearchParam {
  query: string;
  search_type: number;
  num_per_page: number;
  page_num: number;
  grp: boolean;
  highlight: boolean;
  searchid: string;
}

// ---- 搜索响应 ----
interface QQSinger { name: string; mid: string; id: number; }

interface QQAlbum {
  id: number;
  mid: string;
  name: string;
  title: string;
}

interface QQTrackInfo {
  id: number;
  mid: string;
  name: string;
  title: string;
  singer: QQSinger[];
  album: QQAlbum;
  interval: number;
}

// search_type=0 时返回 body.song.list，其他类型返回不同字段
interface QQSearchSongBlock {
  list: QQTrackInfo[];
}

interface QQSearchBody {
  song: QQSearchSongBlock;
  item_song: QQTrackInfo[];  // 直接数组，不是 { list: [...] }
}

interface QQSearchReqData {
  body: QQSearchBody;
}

interface QQSearchReqResult {
  code: number;
  data: QQSearchReqData;
}

interface QQSearchResult {
  code: number;
  req_0: QQSearchReqResult;
}

// ---- 播放参数 ----
interface VkeyParam {
  guid: string;
  songmid: string[];
  songtype: number[];
  uin: string;
  loginflag: number;
  platform: string;
  filename: string[];
}

// ---- 播放响应 ----
interface QQMidUrlInfo { purl: string; }

interface QQVkeyReqData {
  sip: string[];
  midurlinfo: QQMidUrlInfo[];
}

interface QQVkeyReqResult {
  code: number;
  data: QQVkeyReqData;
}

interface QQVkeyResult {
  code: number;
  req_0: QQVkeyReqResult;
}

// ---- 请求头 ----
interface QQHeaders {
  'User-Agent': string;
  'Referer': string;
  'Origin': string;
  'Cookie': string;
  'Content-Type'?: string;
}

export class QQMusicService {
  private httpUtils: HttpUtils;
  private cookie: string;

  constructor(cookie: string = '') {
    this.httpUtils = new HttpUtils();
    this.cookie = cookie;
  }

  setCookie(cookie: string): void { this.cookie = cookie; }
  getCookie(): string { return this.cookie; }

  /** 搜索歌曲 */
  async search(keyword: string, limit: number = 20): Promise<Song[]> {
    const comm: CommParams = {
      ct: '11', cv: '13.2.5.8', v: '13.2.5.8',
      tmeAppID: 'qqmusic', format: 'json',
      inCharset: 'utf-8', outCharset: 'utf-8', uin: '0'
    };
    const searchParam: SearchParam = {
      query: keyword,
      search_type: 0,
      num_per_page: limit,
      page_num: 1,
      grp: true,
      highlight: true,
      searchid: String(Date.now())
    };
    const body: MusicuRequest = {
      comm: comm,
      req_0: {
        module: 'music.search.SearchCgiService',
        method: 'DoSearchForQQMusicMobile',
        param: searchParam
      }
    };
    const headers: QQHeaders = {
      'User-Agent': USER_AGENT, 'Referer': REFERER,
      'Origin': REFERER, 'Cookie': this.cookie
    };
    try {
      const resp = await this.httpUtils.postJson<QQSearchResult>(API_URL, body, headers);
      console.info('QQ搜索响应: code=' + String(resp.code) + ' req_0.code=' + String(resp.req_0?.code));

      // song.list 或 item_song（直接数组）
      const list: QQTrackInfo[] = resp?.req_0?.data?.body?.song?.list
        || resp?.req_0?.data?.body?.item_song
        || [];
      if (list.length === 0) return [];
      return list.map((item: QQTrackInfo) => this.mapToSong(item));
    } catch (e) {
      console.error('QQ搜索异常:', JSON.stringify(e));
      return [];
    }
  }

  /** 获取播放地址（多音质降级: M800→M500→C400） */
  async getSongUrl(songmid: string): Promise<string> {
    // 音质降级: 320kbps → 128kbps → 96kbps AAC
    const tryQualities: string[] = ['M800', 'M500', 'C400'];
    for (let qi = 0; qi < tryQualities.length; qi++) {
      const url = await this.tryVkey(songmid, tryQualities[qi]);
      if (url) return url;
    }
    return '';
  }

  private async tryVkey(songmid: string, code: string): Promise<string> {
    const comm: CommParams = {
      ct: '19', cv: '13.2.5.8', v: '13.2.5.8',
      tmeAppID: 'qqmusic', format: 'json',
      inCharset: 'utf-8', outCharset: 'utf-8', uin: '0'
    };
    const ext = code === 'C400' ? '.m4a' : '.mp3';
    const vkeyParam: VkeyParam = {
      guid: '10000', songmid: [songmid], songtype: [0],
      uin: '0', loginflag: 1, platform: '20',
      filename: [`${code}${songmid}${songmid}${ext}`]
    };
    const body: MusicuRequest = {
      comm: comm,
      req_0: { module: 'music.vkey.GetVkey', method: 'UrlGetVkey', param: vkeyParam }
    };
    const headers: QQHeaders = {
      'User-Agent': USER_AGENT, 'Referer': REFERER,
      'Origin': REFERER, 'Cookie': this.cookie, 'Content-Type': 'application/json'
    };
    try {
      const resp = await this.httpUtils.postJson<QQVkeyResult>(API_URL, body, headers);
      if (resp?.req_0?.code === 0) {
        const purl = resp.req_0.data?.midurlinfo?.[0]?.purl || '';
        const sipHost = resp.req_0.data?.sip?.[0] || 'https://isure.stream.qqmusic.qq.com/';
        if (purl) {
          const fullUrl = sipHost.replace('http://', 'https://') + purl;
          console.info('QQ播放地址[' + code + ']: ' + fullUrl);
          return fullUrl;
        }
      }
      return '';
    } catch (e) { return ''; }
  }

  /** 检测 Cookie 可用性 */
  async testCookie(): Promise<boolean> {
    const comm: CommParams = {
      ct: '11', cv: '13.2.5.8', v: '13.2.5.8',
      tmeAppID: 'qqmusic', format: 'json',
      inCharset: 'utf-8', outCharset: 'utf-8', uin: '0'
    };
    const searchParam: SearchParam = {
      query: 'test', search_type: 0, num_per_page: 1, page_num: 1,
      grp: true, highlight: false, searchid: String(Date.now())
    };
    const body: MusicuRequest = {
      comm: comm,
      req_0: {
        module: 'music.search.SearchCgiService',
        method: 'DoSearchForQQMusicMobile',
        param: searchParam
      }
    };
    const headers: QQHeaders = {
      'User-Agent': USER_AGENT, 'Referer': REFERER,
      'Origin': REFERER, 'Cookie': this.cookie
    };
    try {
      const resp = await this.httpUtils.postJson<QQSearchResult>(API_URL, body, headers);
      return resp?.code === 0 && resp?.req_0?.code === 0;
    } catch (e) { return false; }
  }

  private mapToSong(item: QQTrackInfo): Song {
    const artistName = item.singer.map((s: QQSinger) => s.name).join('/');
    return {
      id: item.id,
      name: item.name,
      title: item.name,
      artist: artistName,
      album: item.album?.name || '',
      duration: item.interval * 1000,
      coverUrl: item.album?.mid
        ? `https://y.qq.com/music/photo_new/T002R800x800M000${item.album.mid}.jpg`
        : '',
      audioUrl: '',
      platform: Platform.QQ,
      sourceId: item.mid
    };
  }

  destroy(): void { this.httpUtils.destroy(); }
}

export const qqMusicService = new QQMusicService('');
