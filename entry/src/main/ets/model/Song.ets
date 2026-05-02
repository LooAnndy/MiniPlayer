/**
 * 歌曲数据模型 —— 对齐网易云音乐 UI_STRUCTURE.md 的 SongItem 结构
 */

// 歌手信息
export interface ArtistItem {
  id: number;
  name: string;
  picUrl: string;
  img1v1Url: string;
  briefDesc: string;
  albumSize: number;
  alias: string[];
  musicSize: number;
}

// 专辑信息（同时实现 RowEntity 兼容）
export interface AlbumItem {
  id: number;
  name: string;
  type: string;
  size: number;
  picUrl: string;
  blurPicUrl: string;    // 模糊封面（用于播放页背景）
  company: string;       // 发行公司
  description: string;
  tags: string;
  artist: ArtistItem;
  artists: ArtistItem[];
  songs: string[];
  alias: string[];
  subType: string;
  onSale: boolean;
  mark: number;
}

// 歌曲详情（对齐网易云 SongItem）
export interface Song {
  id: number;
  name: string;
  title: string;               // 歌曲标题 → 通常 = name
  artist: string;              // 歌手名 → 通常 = artists[0].name
  album: string;               // 专辑名 → 通常 = albumDetail.name
  duration: number;            // 时长(ms)
  coverUrl?: string;           // 封面URL → 通常 = albumDetail.picUrl
  audioUrl: string;            // 音频流地址
  platform: Platform;          // 来源平台
  artists?: ArtistItem[];      // 歌手列表（可选）
  albumDetail?: AlbumItem;     // 专辑详情（可选）
  popularity?: number;         // 热度
  score?: number;              // 评分
  starredNum?: number;         // 收藏数
  playedNum?: number;          // 播放次数
}

// 音乐平台标识
export enum Platform {
  NETEASE = 'netease',
  BILIBILI = 'bilibili',
  QQ = 'qq',
  LOCAL = 'local'
}

// 平台展示与存储配置（CookieStorage / MinePage 共用）
export interface PlatformInfo {
  platform: Platform;
  name: string;
  color: string;
  icon: string;
  storageKey: string;
  cookieHint: string;
}

// 三平台配置表（唯一数据源）
export const PLATFORM_LIST: PlatformInfo[] = [
  {
    platform: Platform.NETEASE,
    name: '网易云音乐',
    color: '#C20C0C',
    icon: '🎵',
    storageKey: 'cookie_netease',
    cookieHint: 'MUSIC_U=xxx; os=pc; ...'
  },
  {
    platform: Platform.BILIBILI,
    name: 'Bilibili',
    color: '#FB7299',
    icon: '📺',
    storageKey: 'cookie_bilibili',
    cookieHint: 'SESSDATA=xxx; bili_jct=xxx; ...'
  },
  {
    platform: Platform.QQ,
    name: 'QQ 音乐',
    color: '#31C27C',
    icon: '🎶',
    storageKey: 'cookie_qq',
    cookieHint: 'uin=xxx; qm_keyst=xxx; ...'
  }
];

// Tab 栏项（对齐文档 TabBarItem）
export interface TabBarItem {
  id: string;
  name: string;
  color: ResourceColor;
  selectedColor: ResourceColor;
}

// 分段选择器项（对齐文档 SegmentItem）
export interface SegmentItem {
  id: string;
  name: string;
}

// 横向列表基础实体（对齐文档 RowEntity）
export interface RowEntity {
  id: string | number;
  title: string;
  coverImgUrl: string;
  description: string;
}

// 推荐歌单项（对齐文档 RecommendItem）
export interface RecommendItem extends RowEntity {
  type: number;
  canDislike: boolean;
  alg: string;
  song?: Song;
}

// 横幅项（对齐文档 BannerItem）
export interface BannerItem {
  bannerId: string;
  pic: string;
  bannerBizType: string;
  url: string;
}

// 全局播放状态（对齐文档 MusicPlaybackState）
export class MusicPlaybackState {
  cover: string = '';
  name: string = '';
  author: string = '';
  url: string = '';
  time: number = 0;
  duration: number = 0;
  playbackMode: string = '顺序播放';
  isPlaying: boolean = false;
  isPlayed: boolean = false;
  isLoading: boolean = false;
  currentIndex: number = 0;
  playlist: Song[] = [];

  get currentSongId(): number {
    return this.playlist.length > 0 ? this.playlist[this.currentIndex].id : -1;
  }
}
