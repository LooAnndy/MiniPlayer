/**
 * Cookie 持久化存储 & 平台集成测试
 * 验证 Cookie 保存/加载、ServiceRegistry Cookie 恢复流程
 * 需要运行在设备/模拟器上（ohosTest）
 */
import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { Platform } from '../main/ets/model/Song';
import { ServiceRegistry, PlatformService, SongUrlResult } from '../main/ets/service/PlatformService';
import { initCookieStorage, saveCookie, loadCookie } from '../main/ets/utils/CookieStorage';
import { common } from '@kit.AbilityKit';

/**
 * 轻量 Mock 服务 —— 记录 setCookie/getCookie 调用
 */
class RecordableMockService implements PlatformService {
  private cookieValue: string = '';
  setCookieCalls: string[] = [];
  getCookieCalls: number = 0;
  testCookieResult: boolean = true;
  searchResult: import('../main/ets/model/Song').Song[] = [];
  songUrlResult: SongUrlResult = { url: '' };
  destroyCalled: boolean = false;

  setCookie(cookie: string): void {
    this.cookieValue = cookie;
    this.setCookieCalls.push(cookie);
  }

  getCookie(): string {
    this.getCookieCalls++;
    return this.cookieValue;
  }

  async testCookie(): Promise<boolean> { return this.testCookieResult; }

  async search(keyword: string, limit: number): Promise<import('../main/ets/model/Song').Song[]> {
    return this.searchResult;
  }

  async getSongUrl(sourceId: string): Promise<SongUrlResult> { return this.songUrlResult; }

  destroy(): void { this.destroyCalled = true; }
}

export default function cookieIntegrationTest(): void {
  describe('CookieIntegration', () => {
    let context: common.Context | null = null;

    beforeAll(async () => {
      const ctx = getContext() as common.Context;
      context = ctx;
      await initCookieStorage(ctx);
    });

    afterAll(() => {
      context = null;
    });

    // ========== Cookie 基础持久化 ==========

    describe('CookieStorage - 基础持久化', () => {
      it('initCookieStorage 完成初始化', 0, async () => {
        // 二次调用应返回同一个 Promise
        if (context) {
          await initCookieStorage(context);
          // 不抛出异常即通过
        }
        expect(true).assertEqual(true);
      });

      it('saveCookie 和 loadCookie 往返正常', 0, async () => {
        const testCookie: string = 'MUSIC_U=abc123; os=pc; appver=8.9.70';
        await saveCookie(Platform.NETEASE, testCookie);
        const loaded: string = await loadCookie(Platform.NETEASE);
        expect(loaded).assertEqual(testCookie);
      });

      it('loadCookie 对未保存的平台返回空字符串', 0, async () => {
        // 先保存再清除，或直接读一个从未保存的平台
        // 使用 LOCAL 平台（未在 UI 中展示）
        const loaded: string = await loadCookie(Platform.LOCAL);
        expect(loaded).assertEqual('');
      });

      it('saveCookie 覆盖旧值', 0, async () => {
        await saveCookie(Platform.NETEASE, 'old_cookie_value');
        await saveCookie(Platform.NETEASE, 'new_cookie_value');
        const loaded: string = await loadCookie(Platform.NETEASE);
        expect(loaded).assertEqual('new_cookie_value');
      });

      it('多平台保存互不干扰', 0, async () => {
        const neteaseCookie: string = 'MUSIC_U=netease_test';
        const qqCookie: string = 'uin=qq_test';
        await saveCookie(Platform.NETEASE, neteaseCookie);
        await saveCookie(Platform.QQ, qqCookie);
        expect(await loadCookie(Platform.NETEASE)).assertEqual(neteaseCookie);
        expect(await loadCookie(Platform.QQ)).assertEqual(qqCookie);
      });
    });

    // ========== ServiceRegistry + Cookie 集成 ==========

    describe('ServiceRegistry - Cookie 集成', () => {
      let registry: ServiceRegistry;
      let neteaseSvc: RecordableMockService;
      let qqSvc: RecordableMockService;
      let bilibiliSvc: RecordableMockService;

      beforeEach(() => {
        registry = new ServiceRegistry();
        neteaseSvc = new RecordableMockService();
        qqSvc = new RecordableMockService();
        bilibiliSvc = new RecordableMockService();
        registry.register(Platform.NETEASE, neteaseSvc);
        registry.register(Platform.QQ, qqSvc);
        registry.register(Platform.BILIBILI, bilibiliSvc);
      });

      it('Cookie保存后通过registry的setCookie同步到服务', async () => {
        const cookie: string = 'MUSIC_U=test_value; os=pc';
        await saveCookie(Platform.NETEASE, cookie);
        // 模拟 MinePage.syncCookieToService
        const svc: PlatformService | undefined = registry.get(Platform.NETEASE);
        if (svc) {
          svc.setCookie(cookie);
        }
        expect(neteaseSvc.getCookie()).assertEqual(cookie);
      });

      it('Cookie恢复流程：loadCookie → setCookie', async () => {
        const cookie: string = 'uin=12345; qm_keyst=secret';
        await saveCookie(Platform.QQ, cookie);

        const loaded: string = await loadCookie(Platform.QQ);
        expect(loaded).assertEqual(cookie);

        if (loaded) {
          const svc: PlatformService | undefined = registry.get(Platform.QQ);
          if (svc) {
            svc.setCookie(loaded);
          }
        }
        expect(qqSvc.getCookie()).assertEqual(cookie);
      });

      it('Cookie为空时不覆盖服务中的cookie', async () => {
        neteaseSvc.setCookie('original_cookie');
        const loaded: string = await loadCookie(Platform.NETEASE);
        // 未保存过cookie，loaded应为空
        if (loaded) {
          neteaseSvc.setCookie(loaded);
        }
        expect(neteaseSvc.getCookie()).assertEqual('original_cookie');
      });

      it('未注册平台的Cookie保存/加载正常工作', async () => {
        const cookie: string = 'test_local_cookie';
        await saveCookie(Platform.LOCAL, cookie);
        const loaded: string = await loadCookie(Platform.LOCAL);
        expect(loaded).assertEqual(cookie);
      });
    });

    // ========== 边界情况 ==========

    describe('CookieStorage - 边界情况', () => {
      it('保存空字符串成功', async () => {
        await saveCookie(Platform.NETEASE, '');
        const loaded: string = await loadCookie(Platform.NETEASE);
        expect(loaded).assertEqual('');
      });

      it('保存包含特殊字符的Cookie', async () => {
        const specialCookie: string = 'token=a+b/c=d; name=test%20value; key==val';
        await saveCookie(Platform.NETEASE, specialCookie);
        const loaded: string = await loadCookie(Platform.NETEASE);
        expect(loaded).assertEqual(specialCookie);
      });

      it('批量保存三个平台Cookie', async () => {
        const cookies: Record<string, string> = {
          'netease': 'MUSIC_U=123; os=pc',
          'qq': 'uin=456; qm_keyst=789',
          'bilibili': 'SESSDATA=abc; bili_jct=def'
        };
        await saveCookie(Platform.NETEASE, cookies['netease']);
        await saveCookie(Platform.QQ, cookies['qq']);
        await saveCookie(Platform.BILIBILI, cookies['bilibili']);

        expect(await loadCookie(Platform.NETEASE)).assertEqual(cookies['netease']);
        expect(await loadCookie(Platform.QQ)).assertEqual(cookies['qq']);
        expect(await loadCookie(Platform.BILIBILI)).assertEqual(cookies['bilibili']);
      });
    });
  });
}
