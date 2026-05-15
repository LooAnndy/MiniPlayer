/**
 * 平台服务统一接口与注册中心
 * 消除 SearchPage / MinePage / Index 中所有 Platform if/else 链
 */
import { Platform, Song, PLATFORM_LIST } from '../model/Song';
import { loadCookie } from '../utils/CookieStorage';

// ---- 流地址返回结构 ----
// 部分平台（如 Bilibili）返回的流地址需携带额外 HTTP 请求头才能访问 CDN。
// headers 为可选字段，普通平台（网易云、QQ）不返回此字段。
export interface SongUrlResult {
  url: string;
  headers?: Record<string, string>;
}

// ---- 统一服务平台接口 ----
export interface PlatformService {
  setCookie(cookie: string): void;
  getCookie(): string;
  testCookie(): Promise<boolean>;
  search(keyword: string, limit: number): Promise<Song[]>;
  getSongUrl(sourceId: string): Promise<SongUrlResult>;
  destroy(): void;
}

// ---- 服务注册中心 ----
export class ServiceRegistry {
  private services: Map<Platform, PlatformService> = new Map<Platform, PlatformService>();

  register(platform: Platform, service: PlatformService): void {
    this.services.set(platform, service);
  }

  get(platform: Platform): PlatformService | undefined {
    return this.services.get(platform);
  }

  // 按平台搜索 —— 替代 SearchPage.performSearch() 中的 if/else 链
  async search(platform: Platform, keyword: string, limit: number): Promise<Song[]> {
    const svc: PlatformService | undefined = this.services.get(platform);
    if (!svc) {
      console.error('ServiceRegistry: 未注册平台 ' + String(platform));
      return [];
    }
    return await svc.search(keyword, limit);
  }

  // 按平台获取流地址 —— 替代 SearchPage.playSong() 中的 if/else 链
  async getSongUrl(platform: Platform, sourceId: string): Promise<SongUrlResult> {
    const svc: PlatformService | undefined = this.services.get(platform);
    if (!svc) {
      console.error('ServiceRegistry: 未注册平台 ' + String(platform));
      const empty: SongUrlResult = { url: '' };
      return empty;
    }
    return await svc.getSongUrl(sourceId);
  }

  // 按平台测试 Cookie 可用性 —— 替代 MinePage.runTest() 中的 if/else 链
  async testCookie(platform: Platform): Promise<boolean> {
    const svc: PlatformService | undefined = this.services.get(platform);
    if (!svc) {
      return false;
    }
    return await svc.testCookie();
  }

  // 启动时恢复所有平台 Cookie —— 替代 Index.aboutToAppear() 中的 3 次硬编码调用
  async restoreAllCookies(): Promise<void> {
    for (let i: number = 0; i < PLATFORM_LIST.length; i++) {
      const info = PLATFORM_LIST[i];
      const svc: PlatformService | undefined = this.services.get(info.platform);
      if (!svc) {
        continue;
      }
      try {
        const cookie: string = await loadCookie(info.platform);
        if (cookie) {
          svc.setCookie(cookie);
          console.info('ServiceRegistry: 已恢复 ' + String(info.platform) + ' Cookie');
        }
      } catch (e) {
        console.error('ServiceRegistry: 恢复 ' + String(info.platform) + ' Cookie 失败');
      }
    }
  }
}

// 全局单例注册中心
export const platformServiceRegistry: ServiceRegistry = new ServiceRegistry();
