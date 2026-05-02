/**
 * Cookie 持久化存储 —— 基于 @ohos.data.preferences
 * 平台配置统一引用 model/Song 中的 Platform / PLATFORM_LIST
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Platform, PLATFORM_LIST } from '../model/Song';

const STORE_NAME = 'netEaseCookie';

function storageKey(platform: Platform): string {
  for (let i = 0; i < PLATFORM_LIST.length; i++) {
    if (PLATFORM_LIST[i].platform === platform) {
      return PLATFORM_LIST[i].storageKey;
    }
  }
  return `cookie_${platform}`;
}

let prefInstance: preferences.Preferences | null = null;

// 持有 init Promise，确保 save/load 在初始化完成后才执行
let initPromise: Promise<void> | null = null;

export function initCookieStorage(context: common.Context): Promise<void> {
  if (initPromise) return initPromise; // 已初始化，直接返回
  initPromise = preferences.getPreferences(context, STORE_NAME).then((pref) => {
    prefInstance = pref;
  });
  return initPromise;
}

// 确保 prefInstance 已初始化，未初始化时等待 initPromise
async function ensureReady(): Promise<boolean> {
  if (prefInstance) return true;
  if (initPromise) {
    await initPromise;
    return prefInstance !== null;
  }
  return false;
}

export async function saveCookie(platform: Platform, cookie: string): Promise<void> {
  const ready = await ensureReady();
  if (!ready) { console.error('CookieStorage 未初始化'); return; }
  await prefInstance!.put(storageKey(platform), cookie);
  await prefInstance!.flush();
  console.info('Cookie 已持久化');
}

export async function loadCookie(platform: Platform): Promise<string> {
  const ready = await ensureReady();
  if (!ready) { console.error('CookieStorage 未初始化'); return ''; }
  return await prefInstance!.get(storageKey(platform), '') as string;
}
