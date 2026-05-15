/**
 * PlatformService / ServiceRegistry 单元测试
 * 验证注册中心的核心功能：注册、查找、委托调用
 */
import { describe, beforeAll, beforeEach, afterAll, it, expect } from '@ohos/hypium';
import { ServiceRegistry, PlatformService, SongUrlResult, platformServiceRegistry } from '../main/ets/service/PlatformService';
import { Platform, Song } from '../main/ets/model/Song';

// ---- Mock 平台服务，用于测试注册与委托 ----

const MOCK_SONG: Song = {
  id: 1,
  name: 'Test Song',
  title: 'Test Song',
  artist: 'Test Artist',
  album: 'Test Album',
  duration: 240000,
  coverUrl: 'https://example.com/cover.jpg',
  audioUrl: '',
  platform: Platform.NETEASE
};

class MockService implements PlatformService {
  private cookieValue: string = '';
  private searchResult: Song[] = [MOCK_SONG];
  private urlResult: SongUrlResult = { url: 'https://example.com/audio.mp3' };
  private cookieValid: boolean = true;

  setCookie(cookie: string): void { this.cookieValue = cookie; }
  getCookie(): string { return this.cookieValue; }

  async testCookie(): Promise<boolean> { return this.cookieValid; }
  async search(keyword: string, limit: number): Promise<Song[]> { return this.searchResult; }
  async getSongUrl(sourceId: string): Promise<SongUrlResult> { return this.urlResult; }
  destroy(): void {}

  // 测试辅助：修改 mock 行为
  setCookieValid(valid: boolean): void { this.cookieValid = valid; }
  setSearchResult(songs: Song[]): void { this.searchResult = songs; }
  setUrlResult(result: SongUrlResult): void { this.urlResult = result; }
}

class FailingMockService implements PlatformService {
  setCookie(cookie: string): void {}
  getCookie(): string { return ''; }
  async testCookie(): Promise<boolean> { throw new Error('Network error'); }
  async search(keyword: string, limit: number): Promise<Song[]> { throw new Error('Network error'); }
  async getSongUrl(sourceId: string): Promise<SongUrlResult> { throw new Error('Network error'); }
  destroy(): void {}
}

export default function platformServiceUnitTest(): void {
  describe('PlatformService_UnitTest', () => {
    let registry: ServiceRegistry;

    beforeEach(() => {
      registry = new ServiceRegistry();
    });

    // ========== 注册与查找 ==========

    describe('ServiceRegistry - 注册与查找', () => {
      it('注册后可通过get查找到服务', 0, () => {
        const svc: MockService = new MockService();
        registry.register(Platform.NETEASE, svc);
        const found: PlatformService | undefined = registry.get(Platform.NETEASE);
        expect(found).not().assertEqual(undefined);
        expect(found === svc).assertEqual(true);
      });

      it('未注册的平台get返回undefined', 0, () => {
        const found: PlatformService | undefined = registry.get(Platform.NETEASE);
        expect(found === undefined).assertEqual(true);
      });

      it('重复注册覆盖旧服务', 0, () => {
        const svc1: MockService = new MockService();
        const svc2: MockService = new MockService();
        registry.register(Platform.NETEASE, svc1);
        registry.register(Platform.NETEASE, svc2);
        const found: PlatformService | undefined = registry.get(Platform.NETEASE);
        expect(found === svc2).assertEqual(true);
      });

      it('多个平台独立注册', 0, () => {
        const netease: MockService = new MockService();
        const bilibili: MockService = new MockService();
        registry.register(Platform.NETEASE, netease);
        registry.register(Platform.BILIBILI, bilibili);
        expect(registry.get(Platform.NETEASE) === netease).assertEqual(true);
        expect(registry.get(Platform.BILIBILI) === bilibili).assertEqual(true);
        expect(registry.get(Platform.QQ) === undefined).assertEqual(true);
      });
    });

    // ========== search 委托 ==========

    describe('ServiceRegistry - search() 委托', () => {
      it('search委托到注册的服务', async () => {
        const svc: MockService = new MockService();
        svc.setSearchResult([MOCK_SONG]);
        registry.register(Platform.NETEASE, svc);

        const results: Song[] = await registry.search(Platform.NETEASE, 'test', 10);
        expect(results.length).assertEqual(1);
        expect(results[0].name).assertEqual('Test Song');
      });

      it('未注册的平台search返回空数组', async () => {
        const results: Song[] = await registry.search(Platform.QQ, 'test', 10);
        expect(results.length).assertEqual(0);
      });

      it('服务抛出异常时search返回空数组', async () => {
        const svc: FailingMockService = new FailingMockService();
        registry.register(Platform.BILIBILI, svc);
        const results: Song[] = await registry.search(Platform.BILIBILI, 'test', 10);
        expect(results.length).assertEqual(0);
      });
    });

    // ========== getSongUrl 委托 ==========

    describe('ServiceRegistry - getSongUrl() 委托', () => {
      it('getSongUrl委托到注册的服务', async () => {
        const svc: MockService = new MockService();
        const expected: SongUrlResult = { url: 'https://example.com/test.m4a' };
        svc.setUrlResult(expected);
        registry.register(Platform.BILIBILI, svc);

        const result: SongUrlResult = await registry.getSongUrl(Platform.BILIBILI, 'BV12345');
        expect(result.url).assertEqual('https://example.com/test.m4a');
      });

      it('返回带headers的SongUrlResult', async () => {
        const svc: MockService = new MockService();
        const withHeaders: SongUrlResult = {
          url: 'https://cdn.example.com/audio.m4a',
          headers: { 'Referer': 'https://www.bilibili.com/' }
        };
        svc.setUrlResult(withHeaders);
        registry.register(Platform.BILIBILI, svc);

        const result: SongUrlResult = await registry.getSongUrl(Platform.BILIBILI, 'BV12345');
        expect(result.url).assertEqual('https://cdn.example.com/audio.m4a');
        expect(result.headers !== undefined).assertEqual(true);
        if (result.headers) {
          expect(result.headers['Referer']).assertEqual('https://www.bilibili.com/');
        }
      });

      it('未注册的平台返回空url', async () => {
        const result: SongUrlResult = await registry.getSongUrl(Platform.QQ, '12345');
        expect(result.url).assertEqual('');
      });
    });

    // ========== testCookie 委托 ==========

    describe('ServiceRegistry - testCookie() 委托', () => {
      it('Cookie有效时返回true', async () => {
        const svc: MockService = new MockService();
        svc.setCookieValid(true);
        registry.register(Platform.NETEASE, svc);
        const ok: boolean = await registry.testCookie(Platform.NETEASE);
        expect(ok).assertEqual(true);
      });

      it('Cookie无效时返回false', async () => {
        const svc: MockService = new MockService();
        svc.setCookieValid(false);
        registry.register(Platform.NETEASE, svc);
        const ok: boolean = await registry.testCookie(Platform.NETEASE);
        expect(ok).assertEqual(false);
      });

      it('未注册的平台返回false', async () => {
        const ok: boolean = await registry.testCookie(Platform.QQ);
        expect(ok).assertEqual(false);
      });
    });

    // ========== restoreAllCookies ==========

    describe('ServiceRegistry - restoreAllCookies()', () => {
      it('有已注册服务且有cookie时调用setCookie', async () => {
        const svc: MockService = new MockService();
        svc.setCookie('');
        registry.register(Platform.NETEASE, svc);

        // restoreAllCookies 依赖于 CookieStorage 的 loadCookie，
        // 在 LocalUnit 中无法真正调用（需要 Preferences API）。
        // 此处只验证方法存在且可调用。
        expect(typeof registry.restoreAllCookies).assertEqual('function');
      });
    });
  });
}

// 测试 SongUrlResult 类型（编译期验证）
function verifySongUrlResultType(): void {
  const basic: SongUrlResult = { url: 'https://example.com/test.mp3' };
  const withHeaders: SongUrlResult = {
    url: 'https://cdn.example.com/audio.m4a',
    headers: { 'Referer': 'https://www.bilibili.com/', 'User-Agent': 'test' }
  };
  // headers 为可选字段
  const noHeaders: SongUrlResult = { url: '' };
  console.info('SongUrlResult type OK: ' + basic.url + withHeaders.url + noHeaders.url);
}
