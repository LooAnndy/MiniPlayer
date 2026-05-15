/**
 * Bilibili API 服务 —— 仅搜索
 * 基于 api-analysis/Bilibili/downloads_and_play_api.md
 *
 * 搜索: GET api.bilibili.com/x/web-interface/wbi/search/type?search_type=video&keyword=kw&tids=3
 *
 * KNOWN-DEBT: 与其他平台服务无统一接口。此外本服务的 getAudioUrl 返回的流地址
 * 需携带 Referer 请求头才能访问 CDN，该 header 目前泄漏到 SearchPage.playSong() 中构造。
 */
import { HttpUtils } from '../utils/HttpUtils';
import { Song, Platform } from '../model/Song';
import { PlatformService, SongUrlResult, platformServiceRegistry } from './PlatformService';

const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const REFERER = 'https://www.bilibili.com/';
const SEARCH_URL = 'https://api.bilibili.com/x/web-interface/wbi/search/type';

// 搜索响应
interface BilibiliVideoItem {
  type: string;
  id: number;
  aid: number;
  bvid: string;
  title: string;
  author: string;
  mid: number;
  pic: string;
  play: number;
  duration: string;
  tag: string;
  pubdate: number;
}

interface BilibiliSearchData {
  result: BilibiliVideoItem[];
  numResults: number;
}

interface BilibiliSearchResponse {
  code: number;
  data: BilibiliSearchData;
  message: string;
}

// view 接口响应（获取 cid）
interface BilibiliViewData {
  cid: number;
  title: string;
}

interface BilibiliViewResponse {
  code: number;
  data: BilibiliViewData;
}

// playurl DASH 响应（fnval=16 → 纯音频 .m4a）
interface BilibiliDashAudioItem {
  id: number;
  baseUrl?: string;
  base_url?: string;
  mimeType?: string;
  codecs?: string;
  bandwidth?: number;
}

interface BilibiliDashData {
  audio: BilibiliDashAudioItem[];
  duration: number;
}

interface BilibiliDashResponseData {
  dash: BilibiliDashData;
  durl?: BilibiliDurlItem[];
}

interface BilibiliDashResponse {
  code: number;
  data: BilibiliDashResponseData;
}

// durl 降级项
interface BilibiliDurlItem {
  url: string;
  backup_url?: string[];
}

interface BilibiliHeaders {
  'User-Agent': string;
  'Referer': string;
  'Cookie': string;
}

export class BilibiliService implements PlatformService {
  private httpUtils: HttpUtils;
  private cookie: string;

  constructor(cookie: string = '') {
    this.httpUtils = new HttpUtils();
    this.cookie = cookie;
  }

  setCookie(cookie: string): void { this.cookie = cookie; }
  getCookie(): string { return this.cookie; }

  /** 搜索音乐分区视频 */
  async search(keyword: string, limit: number = 20): Promise<Song[]> {
    const url = `${SEARCH_URL}?search_type=video&keyword=${encodeURIComponent(keyword)}&tids=3&page=1`;
    const headers: BilibiliHeaders = { 'User-Agent': USER_AGENT, 'Referer': REFERER, 'Cookie': this.cookie };
    try {
      const resp = await this.httpUtils.get<BilibiliSearchResponse>(url, headers);
      if (resp.code !== 0 || !resp.data?.result) return [];
      const list = resp.data.result.slice(0, limit);
      return list.map((item) => this.mapToSong(item));
    } catch (e) {
      console.error('B站搜索异常:', JSON.stringify(e));
      return [];
    }
  }

  /** 检测 Cookie */
  async testCookie(): Promise<boolean> {
    const url = `${SEARCH_URL}?search_type=video&keyword=test&tids=3&page=1`;
    const headers: BilibiliHeaders = { 'User-Agent': USER_AGENT, 'Referer': REFERER, 'Cookie': this.cookie };
    try {
      const resp = await this.httpUtils.get<BilibiliSearchResponse>(url, headers);
      return resp.code === 0;
    } catch (e) { return false; }
  }

  /** 获取纯音频流地址（playurl DASH audio → AVPlayer 兼容的 .m4a） */
  async getSongUrl(sourceId: string): Promise<SongUrlResult> {
    try {
      const cid: number = await this.getCid(sourceId);
      if (!cid) {
        const empty: SongUrlResult = { url: '' };
        return empty;
      }
      const audioUrl: string = await this.getDashAudio(sourceId, cid);
      if (!audioUrl) {
        const empty: SongUrlResult = { url: '' };
        return empty;
      }
      // B站 CDN 要求 Referer 请求头 —— 随 URL 一并返回，页面层无需感知平台细节
      const headers: Record<string, string> = {
        'Referer': 'https://www.bilibili.com/',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
      };
      const result: SongUrlResult = { url: audioUrl, headers: headers };
      return result;
    } catch (e) {
      console.error('B站播放异常: ' + String(e));
      const empty: SongUrlResult = { url: '' };
      return empty;
    }
  }

  /** 获取视频 cid */
  private async getCid(bvid: string): Promise<number> {
    const url = `https://api.bilibili.com/x/web-interface/view?bvid=${bvid}`;
    const headers: BilibiliHeaders = { 'User-Agent': USER_AGENT, 'Referer': REFERER, 'Cookie': this.cookie };
    try {
      const resp = await this.httpUtils.get<BilibiliViewResponse>(url, headers);
      if (resp.code === 0 && resp.data?.cid) return resp.data.cid;
      return 0;
    } catch (e) { return 0; }
  }

  /** 获取 DASH 纯音频流 — fnval=16 返回 .m4a 格式，AVPlayer 原生支持 */
  private async getDashAudio(bvid: string, cid: number): Promise<string> {
    // fnval=16=DASH → data.dash.audio[] 返回纯音频 .m4a URL（无视频轨）
    const apiUrl = `https://api.bilibili.com/x/player/playurl?bvid=${bvid}&cid=${cid}&qn=0&fnval=16&fnver=0&fourk=1`;
    const headers: BilibiliHeaders = { 'User-Agent': USER_AGENT, 'Referer': REFERER, 'Cookie': this.cookie };
    try {
      const resp = await this.httpUtils.get<BilibiliDashResponse>(apiUrl, headers);
      console.info('B站 DASH code=' + String(resp.code));

      const pd = resp.data;
      if (!resp.data) return '';

      // DASH audio[] → 纯音频 .m4a URLs（AVPlayer 直接支持）
      const dash = pd.dash;
      if (dash?.audio && dash.audio.length > 0) {
        const audio = dash.audio[0];
        const audioUrl = audio.baseUrl || audio.base_url || '';
        if (audioUrl) {
          console.info('B站 DASH audio .m4a: ' + audioUrl.substring(0, 80));
          return audioUrl;
        }
      }
      console.warn('B站 DASH: audio[] 为空');
      return '';
    } catch (e) {
      console.error('B站 DASH异常: ' + String(e));
      return '';
    }
  }

  private mapToSong(item: BilibiliVideoItem): Song {
    const seconds = this.parseDuration(item.duration);
    const coverUrl = item.pic.startsWith('//')
      ? 'https:' + item.pic
      : item.pic;
    return {
      id: item.id,
      name: item.title,
      title: item.title.replace(/<[^>]*>/g, ''),
      artist: item.author,
      album: '',
      duration: seconds * 1000,
      coverUrl: coverUrl,
      audioUrl: '',
      platform: Platform.BILIBILI,
      sourceId: item.bvid
    };
  }

  // "04:32" → 272 秒
  private parseDuration(dur: string): number {
    const parts = dur.split(':');
    if (parts.length === 2) {
      return parseInt(parts[0]) * 60 + parseInt(parts[1]);
    }
    return parseInt(dur) || 0;
  }

  destroy(): void { this.httpUtils.destroy(); }
}

export const bilibiliService = new BilibiliService('');
platformServiceRegistry.register(Platform.BILIBILI, bilibiliService);
