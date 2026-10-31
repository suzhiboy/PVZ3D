# 关卡编写说明

关卡数据位于 `godot/scripts/data.gd` 的 `Data.LEVELS`。每个关卡是一个字典，必须包含：

- `id`：唯一、非空字符串；`name`、`subtitle`、`goal`：菜单和结算文案。
- `chapter`：章节编号；`difficulty`：难度等级（用于展示和作者 pacing）。
- `yard`：场地，支持 `front`（前院）和 `back`（后院泳池）。
- `sky`：天空/光照，支持 `dawn`、`noon`、`night`、`pool`。
- `sun`：初始阳光；`sky_sun`：天空随时间产生阳光的速率；`par`：三颗星的目标时间。
- `seeds`：允许玩家携带的植物 ID 数组；`slots`：种子槽数量，范围 1–9。
- `waves`：按时间递增排列的波次数组。战役波次通常采用六波节奏：试探、强化、混合、压力、预备决战、最后一波；教学关可少一波，但每个波次必须有实际生成内容。

波次字段：`at` 是相对关卡开始的秒数，`label` 是提示文案，`big` 标记大波，`spawns` 是生成项数组。生成项至少有 `kind`（见 `Data.ZOMBIES`）；可选 `count`（数量，默认 1）、`gap`（同类间隔秒数）和 `lane`（0 起始的行号）。植物 ID 必须来自 `Data.PLANTS`，僵尸 ID 必须来自 `Data.ZOMBIES`。

章节和难度只表达内容分组与挑战等级，不改变解锁逻辑。战役按 `LEVELS` 数组顺序解锁：完成当前关卡后进入下一项；菜单和继续游戏也使用同一顺序。`ENDLESS` 是独立模式，额外字段 `endless: true` 和 `first_wave`（首次生成波次的时间）控制无尽生成器；其 `waves` 故意为空，由 `ENDLESS_ROSTER` 运行，因此默认不放入战役校验数组。需要检查无尽配置时可调用 `Data.validate_levels(catalog, true)`，它允许空波次但仍检查无尽元数据和通用字段。

运行验证：

```text
godot --path godot --headless -- --test=campaign
```

该测试会校验真实 `Data.LEVELS`，并用一个临时的损坏目录确认校验器能够拒绝空 ID、未知场地、空生成列表、倒序时间和未知僵尸。也可在 Godot 编辑器中运行同一命令行参数；日志中的错误按 `level wave` 路径输出，便于定位。
