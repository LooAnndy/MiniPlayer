/**
 * Cookie 持久化存储 —— 基于 @ohos.data.preferences
 * 平台配置统一引用 model/Song 中的 Platform / PLATFORM_LIST
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { Platform, PLATFORM_LIST } from '../model/Song';

const STORE_NAME = 'netEaseCookie';

// 平台 → 存储键名（从 PLATFORM_LIST 查找，保证与配置一致）
function storageKey(platform: Platform): string {
  for (let i = 0; i < PLATFORM_LIST.length; i++) {
    if (PLATFORM_LIST[i].platform === platform) {
      return PLATFORM_LIST[i].storageKey;
    }
  }
  return `cookie_${platform}`;
}

let prefInstance: preferences.Preferences | null = null;

export async function initCookieStorage(context: common.Context): Promise<void> {
  prefInstance = await preferences.getPreferences(context, STORE_NAME);
}

export async function saveCookie(platform: Platform, cookie: string): Promise<void> {
  if (!prefInstance) return;
  await prefInstance.put(storageKey(platform), cookie);
  await prefInstance.flush();
}

export async function loadCookie(platform: Platform): Promise<string> {
  if (!prefInstance) return '';
  return await prefInstance.get(storageKey(platform), '') as string;
}
