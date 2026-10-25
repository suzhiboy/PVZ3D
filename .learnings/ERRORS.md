# Errors

Command failures and integration errors.

---

## [ERR-20261024-001] exported_game_sandbox

**Logged**: 2026-10-24T16:32:00+08:00
**Priority**: low
**Status**: resolved
**Area**: infra

### Summary
An exported Godot game inside the workspace reports "Couldn't load project data"
when launched by the command sandbox, although its embedded PCK is valid.

### Error
```
Error: Couldn't load project data at path "D:/PVZ3D/.tmp". Is the .pck file missing?
```

### Context
Executing `build/花园防线3D.exe` or a copy under `D:/PVZ3D` through the sandbox
fails even with the embedded PCK footer present. Copying the exact same exe to
`D:/PVZX` and running it there succeeds.

### Suggested Fix
Smoke-test exported builds from a directory outside the workspace; do not
re-export or alter `embed_pck` in response to this error.

### Metadata
- Reproducible: yes
- Related Files: godot/export_presets.cfg, build/花园防线3D.exe
- Tags: godot, export, sandbox
---
