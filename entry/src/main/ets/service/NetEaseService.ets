/**
 * 网易云音乐 API 服务 —— 接入 cloudsearch/pc 搜索接口
 * 基于 api-analysis/NetEase/API_ANALYSIS.md §5.4
 *
 * 搜索 API:
 *   POST https://music.163.com/api/cloudsearch/pc
 *   Content-Type: application/x-www-form-urlencoded
 *   Body: s={keyword}&type=1&limit={limit}
 *   Headers: User-Agent (NeteaseMusicDesktop), Referer
 *   Cookie: MUSIC_U=...; os=pc; ...
 */
import { HttpUtils } from '../utils/HttpUtils';
import { Song, Platform, ArtistItem, AlbumItem } from '../model/Song';

// 网易云桌面端 User-Agent（必带，否则 API 拒绝请求）
const USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Safari/537.36 Chrome/91.0.4472.164 NeteaseMusicDesktop/2.10.2.200154';
const REFERER = 'https://music.163.com/';
const SEARCH_URL = 'https://music.163.com/api/cloudsearch/pc';

// 网易云 API 响应结构（所有内联类型提取为显式接口）
interface NetEaseArtistRaw {
  name: string;
}

interface NetEaseAlbumRaw {
  id: number;
  name: string;
  picUrl: string;
}

interface NetEaseSongRaw {
  id: number;
  name: string;
  dt: number;
  ar: NetEaseArtistRaw[];
  al: NetEaseAlbumRaw;
}

interface CloudSearchResult {
  songs?: NetEaseSongRaw[];
  songCount?: number;
}

interface CloudSearchResponse {
  code: number;
  result?: CloudSearchResult;
  message?: string;
}

export class NetEaseService {
  private httpUtils: HttpUtils;
  private cookie: string;

  /**
   * @param cookie 网易云音乐 Cookie 字符串（至少需包含 MUSIC_U）
   *              格式: "MUSIC_U=xxx; os=pc; appver=8.9.70; deviceId=pyncm!"
   */
  constructor(cookie: string = 'os=pc; appver=; osver=; deviceId=pyncm!') {
    this.httpUtils = new HttpUtils();
    this.cookie = cookie;
  }

  /**
   * 更新 Cookie（由 MinePage 填写后调用）
   */
  setCookie(cookie: string): void {
    this.cookie = cookie;
  }

  /**
   * 获取当前 Cookie 字符串
   */
  getCookie(): string {
    return this.cookie;
  }

  /**
   * 是否已配置有效的 MUSIC_U（长度 >= 10）
   */
  hasMusicU(): boolean {
    const match = this.cookie.match(/MUSIC_U=([^;]+)/);
    return match !== null && match[1].length >= 10;
  }

  /**
   * 简单检测 Cookie 是否可用：发起一次 limit=1 的搜索
   */
  async testCookie(): Promise<boolean> {
    const formData: Record<string, string> = { 's': 'test', 'type': '1', 'limit': '1' };
    const reqHeaders: Record<string, string> = {
      'User-Agent': USER_AGENT,
      'Referer': REFERER,
      'Cookie': this.cookie
    };
    try {
      const response = await this.httpUtils.postForm<CloudSearchResponse>(SEARCH_URL, formData, reqHeaders);
      return response.code === 200;
    } catch (e) {
      return false;
    }
  }

  /**
   * 搜索歌曲
   * @param keyword 搜索关键词
   * @param limit 返回数量（默认 30，最大 100）
   * @returns Song[] 转换后的歌曲列表
   */
  async search(keyword: string, limit: number = 30): Promise<Song[]> {
    const formData: Record<string, string> = { 's': keyword, 'type': '1', 'limit': String(limit) };
    const reqHeaders: Record<string, string> = {
      'User-Agent': USER_AGENT,
      'Referer': REFERER,
      'Cookie': this.cookie
    };
    try {
      const response = await this.httpUtils.postForm<CloudSearchResponse>(SEARCH_URL, formData, reqHeaders);

      if (response.code !== 200) {
        console.error(`搜索失败: code=${response.code}, message=${response.message}`);
        return [];
      }

      const songs = response.result?.songs;
      if (!songs || songs.length === 0) {
        return [];
      }

      // 将原始数据转换为 Song 模型
      return songs.map((raw) => this.mapToSong(raw));
    } catch (err) {
      console.error('搜索异常:', JSON.stringify(err));
      return [];
    }
  }

  /**
   * 将网易云 API 原始歌曲数据转换为 Song 模型
   */
  private mapToSong(raw: NetEaseSongRaw): Song {
    const artistName = raw.ar.map((a: NetEaseArtistRaw) => a.name).join('/');
    const artists = raw.ar.map((a: NetEaseArtistRaw) => emptyArtist(a.name));
    return {
      id: raw.id,
      name: raw.name,
      title: raw.name,
      artist: artistName,
      album: raw.al.name,
      duration: raw.dt,
      coverUrl: raw.al.picUrl,
      audioUrl: '',
      platform: Platform.NETEASE,
      artists: artists,
      albumDetail: emptyAlbum(raw.al.id, raw.al.name, raw.al.picUrl, artistName)
    };
  }

  destroy(): void {
    this.httpUtils.destroy();
  }
}

// mapToSong 使用的默认空 ArtistItem 和 AlbumItem
function emptyArtist(name: string): ArtistItem {
  return { id: 0, name: name, picUrl: '', img1v1Url: '', briefDesc: '', albumSize: 0, alias: [], musicSize: 0 };
}

function emptyAlbum(id: number, name: string, picUrl: string, artistName: string): AlbumItem {
  return {
    id: id, name: name, type: '', size: 0, picUrl: picUrl, blurPicUrl: '',
    company: '', description: '', tags: '',
    artist: emptyArtist(artistName), artists: [], songs: [], alias: [],
    subType: '', onSale: false, mark: 0
  };
}

// 全局单例（SearchPage 和 MinePage 共享同一实例）
export const netEaseService = new NetEaseService('os=pc; appver=8.9.70; osver=; deviceId=pyncm!');
