---
name: ArkTS Boundary Risks
description: ArkTS strict mode patterns that currently compile but are at risk of breaking with compiler updates
type: project
---

**SongItem.ets line 9**: `@Param song: Song = { id: 0, name: '', ... }` — inline object literal as @Param default value. While currently allowed because Song is an explicit interface and the variable has type annotation, @Param default values are treated more strictly than regular variables. A future compiler update may reject this pattern. Safer alternative: extract to a module-level constant `const DEFAULT_SONG: Song = { ... }`.

**PlayerStateCenter.ets line 10**: `currentSong: Song = { id: 0, name: '', ... }` — class field default with inline object literal. Same risk profile as above. Extract to `const EMPTY_SONG: Song = { ... }`.

**Overall compliance is good**: All other ArkTS rules (1-8 from CLAUDE.md) are followed throughout the codebase. No @Builder violations, no object spread, no untyped literals, no inline types within interfaces, no object literals passed as function arguments.

**Why**: These are currently compiling but the HarmonyOS ArkTS compiler is known to tighten restrictions between API versions. Being proactive prevents future build breakage.

**How to apply**: When touching SongItem.ets or PlayerStateCenter.ets, extract the inline defaults to named constants.
