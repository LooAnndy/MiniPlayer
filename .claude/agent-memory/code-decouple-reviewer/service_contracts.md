---
name: Platform Service Contracts
description: Observed public API signatures of each platform service for consistency checking
type: reference
---

All three services export as module-level singletons and share these capabilities:

| Capability | NetEaseService | QQMusicService | BilibiliService |
|------------|---------------|----------------|-----------------|
| Cookie set | `setCookie(c: string): void` | `setCookie(c: string): void` | `setCookie(c: string): void` |
| Cookie get | `getCookie(): string` | `getCookie(): string` | `getCookie(): string` |
| Search | `search(kw: string, limit=30): Promise<Song[]>` | `search(kw: string, limit=20): Promise<Song[]>` | `search(kw: string, limit=20): Promise<Song[]>` |
| Stream URL | `getSongUrl(songId: number): Promise<string>` | `getSongUrl(songmid: string): Promise<string>` | `getAudioUrl(bvid: string): Promise<string>` |
| Cookie test | `testCookie(): Promise<boolean>` | `testCookie(): Promise<boolean>` | `testCookie(): Promise<boolean>` |
| Cleanup | `destroy(): void` | `destroy(): void` | `destroy(): void` |

**Inconsistencies**:
1. `getAudioUrl` vs `getSongUrl` — different method name for Bilibili
2. `getSongUrl` parameter type differs (number for NetEase, string for QQ)
3. No shared TypeScript interface exists to enforce these signatures
4. Each service has platform-specific extras: NetEase has `hasMusicU()`, QQ has no extras, Bilibili has `getCid()`/`getDashAudio()` (private)

**Why**: A shared interface would enable compiler-checked consistency and allow SearchPage to use polymorphic dispatch instead of if/else.

**How to apply**: When defining PlatformService interface, use `getStreamUrl(id: string | number): Promise<string>` for the stream URL method to accommodate both number and string IDs.
