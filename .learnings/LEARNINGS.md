# Learnings

Corrections, insights, and knowledge gaps captured during development.

**Categories**: correction | insight | knowledge_gap | best_practice

---

## [LRN-20261024-001] best_practice

**Logged**: 2026-10-24T16:32:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: config

### Summary
Adding a member to a globally registered GDScript class requires refreshing the
class cache before another script can resolve `world.new_member`.

### Details
`WorldBuilder.water_fx` was added and `main.gd` reported
`Could not resolve external class member "water_fx"` until `--import` rebuilt
`.godot/global_script_class_cache.cfg`. Clearing the error by using `get()`
would hide a real static type mismatch.

### Suggested Action
After changing public surface of a `class_name` script, run Godot `--import`
before headless smoke tests.

### Metadata
- Source: error
- Related Files: godot/scripts/world.gd, godot/scripts/main.gd
- Tags: godot, gdscript, class-cache
---

## [LRN-20261024-002] best_practice

**Logged**: 2026-10-24T16:32:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: tests

### Summary
Run multiple Godot test modes sequentially when they share `user://garden.cfg`.

### Details
Parallel `--test=flow` and pool tests raced on saved seed picks, producing
`picks=7` for an 8-slot level. A sequential rerun returned the expected 8.
The game logic was fine; only the test harness was racing.

### Suggested Action
Do not parallelise Godot logic tests that load or persist App settings.

### Metadata
- Source: error
- Related Files: godot/scripts/app.gd, godot/scripts/main.gd
- Tags: godot, tests, save-data
---

## [LRN-20261024-003] best_practice

**Logged**: 2026-10-24T17:23:00+08:00
**Priority**: medium
**Status**: resolved
**Area**: frontend

### Summary
For a stylised large water plane, procedural glints are more controllable than
PBR specular; a screen-space grade must sit below HUD CanvasLayers.

### Details
PBR specular on the subdivided pool produced broad white patches that read as
plastic. Removing mirror specular, reducing interior foam mixing and authoring
small noise-driven glints fixed it. The full-screen grade uses
`CanvasLayer.layer = 2`, below menu (4) and HUD (5), so text stays crisp while
only the 3D view is toned.

### Suggested Action
Treat water highlights as an art-direction problem in stylised scenes; do not
assume physically based reflections will match the look. Keep post-process
grades on a layer lower than all UI.

### Metadata
- Source: conversation
- Related Files: godot/shaders/water.gdshader, godot/shaders/grade.gdshader,
  godot/scripts/main.gd
- Tags: godot, shader, water, post-processing, art-direction
---
