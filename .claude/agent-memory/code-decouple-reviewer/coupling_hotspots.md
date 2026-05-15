---
name: Coupling Hotspots
description: High-priority coupling issues identified in the MiniPlayer codebase — where to focus refactoring
type: project
---

**SearchPage.ets is the #1 coupling hotspot.** Methods `performSearch()` (line 178) and `playSong()` (line 194) use monolithic if/else chains over Platform enum. Three platform service singletons are imported directly (lines 9-11). `playSong()` also contains Bilibili-specific logic (lines 211-215, hardcoded Referer header). To add a 4th platform: modify this one file at 4 different locations.

**MinePage.ets is the #2 coupling hotspot.** Seven methods use if/else chains on Platform. Three hardcoded @Local fields (stateNetease/stateBilibili/stateQQ at lines 26-31) prevent dynamic N-platform support. `runTest()` (line 180) directly calls service singletons.

**Index.ets** (line 22-25) manually restores cookies for each platform with three separate loadCookie+setCookie calls.

**No shared PlatformService interface exists.** Three services have inconsistent method names (getSongUrl vs getAudioUrl) and inconsistent parameter types (number vs string for track ID).

**Refactoring target**: Introduce PlatformService interface + ServiceRegistry at common/ level. This would reduce new-platform changes from 5 files to 3.

**Why**: Current architecture was built with exactly 3 platforms in mind. Adding a 4th requires touching 5 files with 15+ code changes, which is fragile and error-prone.

**How to apply**: When reviewing any PR that adds a new platform or modifies SearchPage/MinePage, flag if/else chains and suggest registry pattern.
