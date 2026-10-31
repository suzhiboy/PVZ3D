# 12 关主线扩展 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan.

## Goal

把 Godot 主线从 4 关扩展到 12 关，并让当前石碑菜单在 1600×900 视口内按页显示关卡。保留旧关卡 ID、存档兼容、自由选卡和无尽模式。

## Files and boundaries

- `godot/scripts/data.gd`：关卡元数据、8 个新关卡和波次内容。
- `godot/scripts/ui/menu_tomb.gd`：3 页 × 4 关的石碑菜单、翻页交互、章节信息。
- `godot/scripts/ui/menu.gd`：旧菜单测试入口的分页/布局保护。
- `godot/scripts/main.gd`：流程测试覆盖 12 关，保留顺序推进和继续游戏。
- `godot/scripts/ui/hud.gd`：只在关卡结束或菜单需要时复用现有文本组件，不改变战斗 HUD 结构；若无需修改则保持不动。
- `godot/docs/level-authoring.md`：记录新增关卡字段、波次模板和测试命令。

## Task 1: Add failing coverage for the expanded campaign

1. Extend `godot/scripts/main.gd` flow test to assert 12 unique level IDs, `Data.level_exists()` for every ID, and a full sequence from `front-1` through the final level.
2. Add a menu test path that opens page 0, page 1, and page 2, and verifies each page exposes at most four level entries.
3. Run the targeted headless test before implementation and record the expected failure caused by the current 4-level data and fixed menu rows.

Check: the test fails for the intended missing behavior, with no parser error.

## Task 2: Expand level data

1. Add `chapter`, `difficulty`, and `goal` fields to the four existing level dictionaries without changing their IDs or order.
2. Append `front-4`, `back-2`, `front-5`, `back-3`, `front-6`, `back-4`, `front-7`, and `back-5` to `Data.LEVELS`.
3. Give each new level one of the existing `dawn`, `noon`, `pool`, or `night` skies, a valid yard, 5–6 waves, valid zombie kinds, a seed list, slots, sun budget, sky-sun interval, and par time.
4. Use a six-wave rhythm: introduction, single pressure, first mix, resource pressure, pre-finale, final flag wave. Delay gargantuar until late levels.

Check: a data validation helper reports 12 unique IDs, non-empty waves, valid zombie kinds, and valid plant kinds.

## Task 3: Make the stone menu paged

1. Add page state to `godot/scripts/ui/menu_tomb.gd`: page size 4, current page, page count, and page navigation items.
2. Build only the four level plaques for the current page, or keep a fixed four-item pool and refresh its IDs. Do not create one plaque per level outside the viewport.
3. Add previous/next navigation to the stone face and a compact page label. Navigation must be pickable through the existing physics ray path.
4. Keep lock calculation global: level `i` is unlocked only when the preceding level has stars, regardless of the current page.
5. Keep endless, continue, almanac, store, settings, and quit entries visible and pickable on every page.
6. Show chapter, difficulty, and goal in the plaque text or nearby stone label while keeping text readable from the existing camera.

Check: page changes never alter `Data.LEVELS` order, locked entries reject activation, and all 12 IDs become selectable through the three pages.

## Task 4: Protect the legacy 2D menu and flow entry points

1. Update `godot/scripts/ui/menu.gd` so 12 levels fit through the same page model or a bounded scroll area; avoid y positions beyond the 900-pixel viewport.
2. Keep `_continue()` and `_next_level()` in `godot/scripts/main.gd` driven by `Data.LEVELS` order.
3. Extend `_flow_test()` to open every level, traverse pages, test continue, test next-level at an interior level, and confirm endless remains separate.

Check: the flow test passes for all 12 levels and the final level returns to the menu instead of indexing past the array.

## Task 5: Add authoring documentation and data validation

1. Write `godot/docs/level-authoring.md` with the supported fields, wave recipe, unlock rule, and validation commands.
2. Add a lightweight validation function in `Data` or the existing test harness. It must reject duplicate IDs, unknown yards/skies, unknown plants/zombies, empty wave arrays, and invalid slot counts.
3. Run validation during the `flow` test so future data edits fail close to the source.

Check: malformed temporary test data is rejected by the validator, and the real 12-level catalog passes.

## Task 6: Verify gameplay and regression safety

1. Run built-in tests: `choice`, `flow`, `plants`, `zombies`, `coins`, `store`, `water`, `audio`, and `art`.
2. Run short simulations for all 12 levels with stable seeds; check no invalid spawn, parser, or level lookup output.
3. Run `git diff --check -- . ':(exclude).tmp'`.
4. Run Godot editor/headless parse checks and capture exit codes. Report known shutdown resource warnings separately if they remain.

Check: all required tests exit 0, level catalog count is 12, and no new warnings indicate gameplay failure.

## Suggested commit units

1. `test: cover twelve-level campaign and pagination`
2. `feat: add eight campaign levels and metadata`
3. `feat: paginate stone campaign menu`
4. `docs: document level authoring and validation`
5. `test: verify campaign regression suite`
