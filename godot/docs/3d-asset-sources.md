# 3D 美术资源搜集与导入清单

这份清单用于给《花园防线 3D》挑选外部模型。当前项目的植物和僵尸由 `scripts/art.gd` 运行时生成，因此外部模型应先放进独立的第三方目录，经过许可证、比例、朝向和性能检查后，再通过适配层替换模型。不要直接覆盖现有程序化模型。

## 推荐直接用于项目的资源

这些资源的页面明确给出了 CC0 或公共领域许可，适合先做可发布版本的美术升级。它们不一定是 PVZ 角色，但可以作为统一的植物、僵尸、庭院和环境资产基础。

- [Gobkit Free Minions](https://gobkit.itch.io/gobkit-free-minions)：8 个低多边形、带骨骼和 idle/attack/dead 动画的 GLB 角色，CC0 1.0。适合替换当前僵尸基础模型，再通过材质和头部配件做普通、路障、铁桶等变体。
- [Quaternius Zombie Apocalypse Kit](https://tmhsdigital.github.io/Free-Game-Dev-Assets/entry/quaternius-zombie-apocalypse-kit/)：60 个僵尸、敌人、狗、环境和载具模型，CC0 1.0，提供 glTF、FBX、OBJ 和 Blender 格式。适合挑选僵尸身体、衣物和场景道具。
- [Kenney Nature Kit](https://kenney.nl/assets/nature-kit)：330 个 3D 自然环境模型，CC0。适合升级草地、石头、灌木、花盆和庭院装饰，让当前场景不再完全依赖几何体临时拼装。
- [OpenGameArt 3D Plants](https://opengameart.org/content/plants)：明确标注 CC0 的 3D 植物包，页面提供压缩包和许可文件。适合作为植物叶片、花盆和背景植被的素材来源。
- [Grab3D Alien Plant](https://grab3d.com/models/sci-fi/alien-plant/)：轻量化、风格化、CC0 的 GLB 植物模型，同时提供 FBX、Blend 和 OBJ。适合给火龙草、激光豆等新增植物制作独立外观。
- [Kenney Survival Kit](https://kenney.nl/assets/survival-kit)：CC0 3D 生存场景资源，带动画，适合补充庭院中的木箱、工具、废墟和装饰道具。

## 外观最接近 PVZ，但只建议个人演示

PVZ 同人模型即使在 Sketchfab 上标成免费下载，也不等于拥有原作角色的商业发行权。以下资源适合原型验证、个人学习或非商业展示，正式发布前应分别确认作者许可和原作 IP 风险：

- [Peashooter by Aiden Miranda](https://sketchfab.com/3d-models/plants-vs-zombies-peashooter-a6b5b3a3dce7453d8c769d9c133c9bd3)：24.8k 三角形、带贴图和骨骼，CC BY-NC；需要署名且禁止商业使用。
- [Peashooter by stos f](https://sketchfab.com/3d-models/peashooter-plants-vs-zombies-6a2b7d3a25f74eafb4825dc20221a74e)：32.5k 三角形，CC BY；需要署名，仍要单独评估 PVZ 衍生作品的版权风险。
- [Wall Nut by Nazar Okruzhko](https://sketchfab.com/3d-models/wall-nut-plants-vs-zombies-1-40a887ab62e046d29ccba1de77ae867e)：约 1.1k 三角形、明确标注 Fanmade，CC BY；适合先替换坚果墙做风格验证。
- [Sunflower PVZ3 Pre-Alpha](https://sketchfab.com/3d-models/plants-vs-zombies-3-pre-alpha-sunflower-db157ae94f3d44eaa5b3af267174e0a0)：约 3.2k 三角形，CC BY；页面描述较少，使用前必须保存作者、页面和下载日期记录。
- [Polyart Zombies with Animations](https://sketchfab.com/3d-models/polyart-zombies-with-animations-free-pack-d9bcfdd88f5348549bc947226af7c314)：低多边形僵尸动画包，页面说明真正的 rigs/animations 需要从 FAB 获取；许可证是 Free Standard，必须按原页面条款使用。

### 这次新增的近似度优先候选

- [Polyjo Peashooter on Blockbench Workshop](https://blockbenchworkshop.com/zh-Hans/model/polyjo/peashooter-polyjo)：116 KB `.bbmodel`，4 个动画、11 根骨骼、64×64 贴图；页面明确给出 CC BY-NC 4.0，适合个人非商业项目。相关的 PVZ 列表还包括向日葵、坚果墙、寒冰射手、双发豌豆、窝瓜和其他植物。
- [Wall Nut by Nazar Okruzhko](https://sketchfab.com/3d-models/wall-nut-plants-vs-zombies-1-40a887ab62e046d29ccba1de77ae867e)：约 1.1k 三角形，PVZ1 轮廓很接近，Fanmade，CC BY，需要署名。
- [Plants vs Zombies 3 Pre-Alpha Sunflower](https://sketchfab.com/3d-models/plants-vs-zombies-3-pre-alpha-sunflower-db157ae94f3d44eaa5b3af267174e0a0)：约 3.2k 三角形，CC BY，适合做向日葵外观验证，但页面描述和来源信息较少。
- [Conehead Zombie](https://sketchfab.com/3d-models/conehead-zombie-pvz-garden-warfare-bf0b264669b54150b9f89c111da32301)：约 16.6k 三角形，PVZ 路障僵尸辨识度高，CC BY。
- [BucketHead](https://sketchfab.com/3d-models/buckethead-2b05fb0614144906ad916b0af6bc7cce)：页面明确写为 PVZ 铁桶僵尸，约 252k 三角形，面数过高，必须先在 Blender 中减面后再进 Godot。
- [Backup Dancer](https://sketchfab.com/3d-models/backup-dancer-pvz-gw-c4227ce926fd4a9ea8151f98362dacb0)：约 9k 三角形，适合替换舞王召唤的伴舞僵尸，CC BY。
- [Plants vs Zombies 1 fanart pack](https://sketchfab.com/3d-models/plants-vs-zombies-1-43c2a74dafec4a138d893bb90b2eba35)：同一展示包含豌豆射手、向日葵、樱桃炸弹、坚果墙和土豆雷，适合比较整体风格；页面没有给出清晰下载许可证，暂时只当参考。

不要使用页面自己标注为“stolen from the game”的 Garden Warfare 提取模型，即使页面显示了 Creative Commons 标签，也不能把上传者的标签当作原作权利证明。例如 [这个 Sunflower 页面](https://sketchfab.com/3d-models/plants-vs-zombies-garden-warfare-2-sunflower-6e16fee69c5b45958997504765fd8cf9) 就明确写着 stolen from the game。

## Godot 导入标准

Godot 4 官方文档推荐 glTF 2.0，并支持 `.gltf` 和二进制 `.glb`；`.glb` 可以把网格、材质和贴图打包到一个文件，最适合当前项目的版本管理和导入流程。FBX 可以导入，但应优先在 Blender 中转换成 GLB；OBJ 适合静态道具，不适合带骨骼、动画和材质层的角色。

每个进入项目的资源目录应包含：

```text
godot/assets/third_party/<pack-name>/
├── model.glb
├── LICENSE.txt
├── SOURCE.txt
└── preview.png
```

`SOURCE.txt` 至少记录原始页面、作者、许可证、下载日期和原始文件名。导入前检查：

- 单个角色目标控制在约 1k–20k 三角形；重复出现的僵尸优先使用 1k–8k。
- 贴图优先 1K 或 2K，统一为 Base Color、Normal、Roughness，避免把 4K 贴图复制到每个单位。
- 根节点脚底放在 `Y = 0`，角色朝向统一到当前游戏的前方；植物当前模型面向 `+X`，僵尸由 `ZombieUnit` 控制转向。
- 动画命名统一为 `idle`、`walk`、`attack`、`hit`、`death`，再由适配层映射到现有 `PlantUnit` / `ZombieUnit` 状态。
- 在 Godot 的 Import 面板中检查材质、骨骼、动画和包围盒；不要直接修改导入源文件生成的内部资源。

## 推荐替换顺序

1. 先用 CC0 的 Gobkit 或 Quaternius 角色替换僵尸基础外观，保留现有血量、受击、减速和死亡逻辑。
2. 用 Kenney Nature Kit 和 OpenGameArt 植物资源升级庭院、花盆、草地和背景层。
3. 选择一套许可证清楚的植物模型，只替换向日葵、豌豆射手、坚果墙和新增 PVZ2 植物，验证卡片图、模型比例和战斗特效。
4. 最后再考虑 Sketchfab 同人模型；它们只放在个人演示分支，并保留完整署名和许可证记录。

Godot 官方导入说明：[Available 3D formats](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_3d_scenes/available_formats.html)。
