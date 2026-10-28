# PVZ3D — 第一人称 3D 植物大战僵尸

> **Godot 版在 [`godot/`](godot/README.md)**：用 Godot 4.7 重做的完整项目（13 植物 / 6 僵尸 / 4 关、可进入的住宅、泳池后院、程序化音效与卡通描边）。本文件描述的是最初的 Three.js 页游版。

把《植物大战僵尸》一代的玩法搬进第一人称 3D：你自己走过院子，走到格子前把植物种下去，再跑去捡阳光、看住每一行草坪。

- **纯程序化美术**：所有贴图（草地、木栅栏、砖墙、泳池水面……）都是运行时用 Canvas 2D 现画的，不依赖任何原版素材或图片文件。
- **无外部资源依赖**：没有模型、贴图、音频文件；音效是 WebAudio 现合成的。`npm install` 之后即可运行。
- **一张连续的地图**：前院（5 行）＋ 美式二层住宅（室内可进入，楼梯上二楼）＋ 后院泳池（6 行，中间两行是水）。

## 快速开始

**只想玩：双击 `dist/pvz3d.html`。** 那是把 JS/CSS 全部内联进一个文件的单文件版，`file://` 下也能直接跑（普通 `npm run build` 的产物是 ES module，浏览器不允许从 `file://` 加载模块，双击会卡在加载页——所以有了这个单文件版）。每次改完代码用 `npm run build:file` 重新生成。

开发时：

```bash
npm install
npm run dev          # http://127.0.0.1:5173
```

其它脚本：

| 命令 | 作用 |
| --- | --- |
| `npm run dev` | 开发服务器（5173） |
| `npm run build` | 类型检查 + 打包到 `dist/`（ES module，需要 http 服务器） |
| `npm run build:file` | 类型检查 + 打包 + 生成可双击的 `dist/pvz3d.html`（单文件版） |
| `npm run preview` | 预览打包结果（4173） |
| `npm run typecheck` | 只做 `tsc --noEmit` |
| `npm test` | 单元测试（`node --test`，27 个用例） |
| `npm run shots` | 用无头浏览器批量截图到 `.shots/`（见下文） |

> 美术风格：角色用 `MeshToonMaterial` 分级着色 + 反面壳描边（`applyInk`），贴图全部 Canvas 现画（草地带有修剪过的方格边缘、blade 笔触与三叶草），植被用多面体 clump 堆出树冠，最后叠一层 CSS 暗角与饱和度。

## 操作

| 按键 | 功能 |
| --- | --- |
| `W A S D` / 方向键 | 移动（`Shift` 冲刺） |
| `Space` | 跳 |
| 鼠标 | 转视角（点一下画面锁定指针，`Esc` 解锁并暂停） |
| `1` – `7` / 滚轮 | 选择植物卡片 |
| `Q` | 铲掉准星对准的植物 |
| `F` / 鼠标左键 | 在准星对准的格子种下当前植物 |
| `E` | 收集准星对准的太阳 |
| `Enter` / `Space` | 开始关卡 / 继续 |

**阳光**：走近到 1.2 m 内的太阳会自动吸入口袋，距离远的需要用准星对准按 `E` 收——所以你得真的跑过去。

## 玩法

和原版一样：种子卡有阳光消耗和冷却，天上定期掉阳光，向日葵定期产阳光；僵尸按波次从远处走进草坪，吃到植物就啃，啃到尽头会被小推车清场，小推车用完后僵尸进屋即失败。清完全部波次即过关。

三关依次串联（`?level=` 记录进度）。开局面板里有**关卡选择**，前院两关和后院泳池关可以随时切换；已通关的关卡会打上 ✓，进度存在 `localStorage` 的 `pvz3d.progress` 里。暂停面板的「选关」也能回到这个菜单。

选好关卡后进入**选种子**（和原版一样的带卡环节）：从植物图鉴里挑最多 6 张（泳池关 7 张，多出来的一张永远是睡莲位），按点选顺序排到种子栏的 1–7 号位，再按「开战」进场。列表来自 `src/game/types.ts` 的 `SEED_POOL` / `seedPoolFor(yard)` / `seedCapFor(yard)`，`?seeds=sunflower,peashooter,...` 可以直接复现一套手牌。

1. **前院 · 清晨** — 教学关，只有普通／路障僵尸。
2. **前院 · 午后** — 铁桶僵尸 + 双发豌豆、寒冰射手、樱桃炸弹。
3. **后院 · 泳池** — 中间两行是水，**必须先种睡莲**才能在那一行放别的植物；三线射手、大嘴花在这里解锁。

植物的差异全部来自 `src/game/types.ts` 的 `PLANT_DEFS`：豌豆射手直线射击、三线射手覆盖三行、寒冰射手附带减速、大嘴花吞一只僵尸、土豆雷埋雷、樱桃炸弹炸 3×3、坚果墙挡路、睡莲提供水面落脚点。

## 地图与尺寸

坐标写在 `src/world/layout.ts`，其它模块只引用，不再各自写魔数：

- 一格 `TILE = 1.6 m`，每行 9 列；前院 9×5，后院 9×6。
- 房子 `x -18.0 … -8.2`、`z -6.5 … 6.5`，一层地面 0.45 m，二层楼板 3.19 m，屋脊 5.90 m。
- 泳池水面 `y = -0.18`，双脚能站的水下地面 `-0.46`，池底 `-1.5`。
- 小推车线、僵尸出生线、进屋判定线同样在这里定义。

## 代码结构

```
src/
  main.ts              启动、UI 状态机、输入分发、截图/自动化钩子
  core/
    mathx.ts           数学与伪随机
    textures.ts        全部 Canvas 程序化贴图
    materials.ts       材质缓存与调色板
    collision.ts       手写碰撞世界（地板 / 斜坡 / 墙体 / 水面）
    audio.ts           WebAudio 合成音效
    debug.ts           调试浮层、自动化接口、ready 标记
  world/
    layout.ts          所有坐标系常量（前院/后院/房子/泳池/街道）
    terrain.ts         草坪格子、铺装、马路、泳池水面着色器
    house.ts           两层住宅、门窗生成、楼梯、家具、点光源
    scenery.ts         栅栏、灌木、树、路灯、邮筒、邻居房子、泳池玩具
    environment.ts     天空穹顶、雾、太阳与补光
    parts.ts           建盒/面/柱/球的薄封装
    world.ts           组装 World（scene + collision + terrain + house）
  player/player.ts     第一人称控制器（走/跑/跳/涉水/台阶/滑墙/镜头晃动）
  game/
    types.ts           植物、僵尸、关卡、波次数据
    models.ts          程序化植物与僵尸模型
    game.ts            核心玩法（网格、种植、僵尸、豌豆、阳光、小推车、波次、胜负）
    fx.ts              粒子特效（种植泥土、僵尸扬灰、阳光闪烁）
  ui/
    hud.ts             阳光栏、关卡进度、种子栏、面板
    style.css          HUD 与样式
tests/                 node:test 单元测试
tools/shots.mjs        无头 Edge 批量截图工具
```

渲染：Three.js（`r186`），PCF 软阴影、`NeutralToneMapping`、程序化天空与雾。所有几何体都是运行时拼的，没有 glTF。

着色器一共四层：

- **卡通分段**（`materials.ts` 的 `toon()`）：4 段 `DataTexture` 渐变图，角色和植物是 `MeshToonMaterial`。
- **描边**（`applyInk()`）：反向外壳，按包围球半径撑开 1.2–2.6 cm，小到瞳孔的零件用 `userData.noInk` 跳过。
- **风摆**（`windify()` / `windToon()`）：顶点位移 = 局部高度平方 × 正弦，相位混入局部 x/z，所以树冠会飘、树干不动、相邻灌木不同步；所有植被共用一个时钟（`tickWind`），每帧只写一次 uniform。
- **屏幕调色**（`src/render/grade.ts`）：渲染到 `HalfFloatType` 目标，再做一次全屏 pass（饱和度/对比/暖冷分离/暗角），末尾手动补 `pow(c, 1/2.2)`——`ShaderMaterial` 不会自动做 sRGB 编码。

## 调试与自动化

URL 参数（都用得上）：

```
?level=back-1          指定关卡（front-1 / front-2 / back-1）
?at=x,z                出生点（y 取最高的可站立地板）
?yaw=deg&pitch=deg     初始朝向
?shot=0                截图模式：去掉开场面板、冻结模拟、画面上叠加 #shotinfo 诊断
?warp=秒数             预演 N 秒模拟（例如 warp=120 直接看第四波）
?plant=c:r:kind,...    预铺植物，如 plant=0:0:sunflower,2:2:lilypad,2:2:peashooter
?seeds=a,b,c           指定手牌（跳过选种子，直接带这几张进场）
?panel=intro           截图模式下也显示开局面板（用来拍关卡选择菜单）
?panel=seeds           截图模式下直接显示选种子面板
?debug=1               调试浮层（fps / 坐标 / 僵尸数）
```

截图工具会自己起一个 5199 端口的 dev server，再用无头 Edge 逐张出图：

```bash
npm run shots             # 全部镜头 → .shots/*.png
npm run shots 14 15       # 只跑名字里含 14 / 15 的镜头
npm run shots -- --dom 16-win   # 只把页面 title 里的快照 JSON 打出来（用它验证模拟结果）
```

`--dom` 模式会读回 `document.title`，里面是 `SHOT 宽x高 px=…` 和 `game.snapshot()`（`state / sun / plants / zombies / queued / time / wave / mowers`），所以“这一关能不能通”可以完全无头验证。例如：

```bash
node tools/shots.mjs --dom 16-win
# title: SHOT … {"state":"won","sun":650,"plants":15,"zombies":0,"queued":0,"time":148.6,"wave":5,"mowers":5} …
```

## 截图（里程碑验收）

`npm run shots` 会把 25 张图渲染到 `.shots/`（960×540，无头 Edge + SwiftShader，每张 3–300 秒）。

| 里程碑 | 镜头 |
| --- | --- |
| M1 场景 | `01-porch` `02-lawn` `03-house` `04-street` `05-backyard` `06-pool` `07-back-house` |
| M1 室内 | `08-living` `09-kitchen` `10-upstairs` |
| M2 前院 | `11-front-play` `12-front-close` `14-plant-close` `15-zombie-close` `16-win` `18-front2-win` |
| M3 后院 | `13-back-play` `17-back-win` `19-pool-water` |
| M3/M4 菜单 | `20-menu` `21-menu-backyard` `24-seed-chooser` |
| 美术近景 | `22-plant-front` `23-zombie-front` |
| 选卡 | `24-seed-chooser` `25-custom-hand` |

![前院·午后通关](.shots/18-front2-win.png)
![后院泳池](.shots/17-back-win.png)
![选种子](.shots/24-seed-chooser.png)

## 测试

```bash
npm test
```

覆盖：碰撞世界（台阶高度、斜坡插值、墙体竖直判定、滑墙不穿模、水面）、草坪坐标（行列与格心互逆、僵尸行进方向、小推车位置、泳池范围）、关卡数据（波次顺序、种子合法性、行号越界、泳池关必须卖睡莲、选种子的池子能凑满且不重复、泳池关多一张卡）、粒子特效（生成/上升/过期回收/并发上限）。

## 已知取舍

- 室内只做了“能进、能上楼、有家具和灯光”的体量，细节比不上室外。
- 美术是几何体 + Canvas 贴图的卡通风，不是手绘贴图；想要更接近原版需要外部素材。
- 僵尸寻路是沿单行直线推进，没有绕路或翻越。
- 水面只有顶点着色器波动 + 高光，没有反射/折射。
- 没有做开花/爆炸的屏幕泛光（bloom）：那需要额外的降采样+模糊 pass，在软件渲染下成本太高，目前用加性精灵光晕代替。
