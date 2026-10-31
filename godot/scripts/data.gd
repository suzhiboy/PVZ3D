class_name Data
extends RefCounted

## Static tables: yard geometry, plant/zombie stats, level recipes.
## Nothing here touches the scene tree.

const TILE := 1.6
const COLS := 9
const PLANT_Y := 0.03

const FRONT := {
	"id": "front",
	"name": "前院",
	"cols": 9,
	"rows": 5,
	"x0": -7.2,
	"x1": 7.2,
	"z0": -4.0,
	"z1": 4.0,
	"water_rows": [],
	"house_side": -1,
	"mower_x": -7.05,
	"spawn_x": 15.5,
	"goal_x": -7.9,
}

const BACK := {
	"id": "back",
	"name": "后院",
	"cols": 9,
	"rows": 6,
	"x0": -34.8,
	"x1": -20.4,
	"z0": -4.8,
	"z1": 4.8,
	"water_rows": [2, 3],
	"house_side": 1,
	"mower_x": -20.55,
	"spawn_x": -37.5,
	"goal_x": -20.05,
}

const HOUSE := {
	"x0": -18.0,
	"x1": -8.2,
	"z0": -6.5,
	"z1": 6.5,
	"wall": 0.28,
	"floor_y": 0.45,
	"storey": 2.95,
	"porch": {"x0": -8.2, "x1": -7.15, "z0": -2.3, "z1": 1.1},
	"deck": {"x0": -19.5, "x1": -18.0, "z0": -1.4, "z1": 3.6},
	"front_door_z": -0.55,
	"back_door_z": 3.35,
}

const POOL := {
	"surface_y": -0.16,
	"wade_y": -0.44,
	"floor_y": -1.5,
}

## Plant stat table. cost / recharge / hp are the numbers the player feels.
const PLANTS := {
	"sunflower": {
		"name": "向日葵", "cost": 50, "recharge": 7.0, "hp": 300,
		"hint": "每隔一段时间产出 25 阳光", "tags": "产阳光",
	},
	"peashooter": {
		"name": "豌豆射手", "cost": 100, "recharge": 7.0, "hp": 300,
		"shot": 25, "cadence": 1.35,
		"hint": "向本行前方的僵尸发射豌豆", "tags": "单体输出",
	},
	"wallnut": {
		"name": "坚果墙", "cost": 50, "recharge": 20.0, "hp": 1200,
		"hint": "厚实的坚果，替植物挡下僵尸", "tags": "防御",
	},
	"snowpea": {
		"name": "寒冰射手", "cost": 175, "recharge": 8.0, "hp": 300,
		"shot": 25, "cadence": 1.5, "freeze": 3.2,
		"hint": "冰冻豌豆可以减速僵尸", "tags": "控制",
	},
	"repeater": {
		"name": "双发豌豆", "cost": 200, "recharge": 8.0, "hp": 300,
		"shot": 25, "cadence": 1.5, "shots": 2,
		"hint": "一次射出两颗豌豆", "tags": "输出",
	},
	"cherrybomb": {
		"name": "樱桃炸弹", "cost": 150, "recharge": 24.0, "hp": 400,
		"hint": "炸飞身边一圈的僵尸", "tags": "范围爆发",
	},
	"potatomine": {
		"name": "土豆雷", "cost": 25, "recharge": 12.0, "hp": 300,
		"hint": "埋下后需要一点时间，踩上就炸", "tags": "陷阱",
	},
	"threepeater": {
		"name": "三线射手", "cost": 325, "recharge": 9.0, "hp": 300,
		"shot": 25, "cadence": 1.5, "rows": 3,
		"hint": "同时向三条行发射豌豆", "tags": "多行输出",
	},
	"chomper": {
		"name": "大嘴花", "cost": 150, "recharge": 10.0, "hp": 300,
		"hint": "一口吞掉面前的僵尸，然后慢慢咀嚼", "tags": "单杀",
	},
	"lilypad": {
		"name": "睡莲", "cost": 25, "recharge": 6.0, "hp": 400, "water": true,
		"hint": "种在水面上，让陆生植物站上去", "tags": "水上底座",
	},
	"tallnut": {
		"name": "高坚果", "cost": 125, "recharge": 22.0, "hp": 2400,
		"hint": "更高的坚果墙，撑得更久", "tags": "防御",
	},
	"jalapeno": {
		"name": "火爆辣椒", "cost": 125, "recharge": 22.0, "hp": 400,
		"hint": "烧干净整整一行僵尸", "tags": "整行爆发",
	},
	"squash": {
		"name": "窝瓜", "cost": 50, "recharge": 18.0, "hp": 400,
		"hint": "跳起来压扁靠近的僵尸", "tags": "单杀",
	},
	"pumpkin": {
		"name": "南瓜头", "cost": 125, "recharge": 30.0, "hp": 4000,
		"hint": "罩住同一格的植物，僵尸先啃南瓜", "tags": "护罩",
	},
	"kernelpult": {
		"name": "玉米投手", "cost": 100, "recharge": 8.0, "hp": 300,
		"lob": 20, "cadence": 3.0, "butter": 0.25,
		"hint": "抛玉米粒，偶尔一块黄油把僵尸定住", "tags": "抛射 · 控制",
	},
	"melonpult": {
		"name": "西瓜投手", "cost": 300, "recharge": 12.0, "hp": 300,
		"lob": 80, "cadence": 3.2, "splash": 40, "splash_radius": 1.5,
		"hint": "抛出西瓜，砸中后溅伤周围僵尸", "tags": "抛射 · 范围",
	},
	"puffshroom": {
		"name": "小喷菇", "cost": 0, "recharge": 7.5, "hp": 250,
		"shot": 25, "cadence": 1.3, "range": 3.4,
		"hint": "免费的短程射手，打得近但不要钱", "tags": "夜行 · 短程",
	},
	"bonkchoy": {
		"name": "菜问", "cost": 150, "recharge": 7.5, "hp": 450,
		"melee": 65, "cadence": 0.85, "range": 1.9,
		"hint": "近距离连续挥拳，专门处理贴脸的僵尸", "tags": "近战 · 高爆发",
	},
	"snapdragon": {
		"name": "火龙草", "cost": 125, "recharge": 9.0, "hp": 300,
		"flame": 36, "cadence": 1.8, "range": 3.3,
		"hint": "喷出短程扇形火焰，同时灼烧本行和相邻两行", "tags": "多行 · 近程",
	},
	"laserbean": {
		"name": "激光豆", "cost": 200, "recharge": 10.0, "hp": 300,
		"beam": 72, "cadence": 2.4,
		"hint": "发射贯穿整行的激光，后排僵尸也无处可躲", "tags": "贯穿 · 输出",
	},
	"blover": {
		"name": "三叶草", "cost": 50, "recharge": 15.0, "hp": 250,
		"one_shot": true,
		"hint": "强风吹散全场气球僵尸，使用后立即消失", "tags": "一次性 · 反制气球",
	},
	"sunshroom": {
		"name": "阳光菇", "cost": 25, "recharge": 8.0, "hp": 300,
		"hint": "先产小阳光，长大以后产出更多", "tags": "夜行 · 产阳光",
	},
	"fumeshroom": {
		"name": "大喷菇", "cost": 75, "recharge": 8.0, "hp": 300,
		"fume": 25, "cadence": 1.4, "range": 4.0,
		"hint": "喷出孢子雾，穿透整段近处的僵尸", "tags": "夜行 · 穿透",
	},
	"hypnoshroom": {
		"name": "魅惑菇", "cost": 75, "recharge": 30.0, "hp": 300,
		"hint": "被啃掉时，吃掉它的僵尸会替你作战", "tags": "夜行 · 策反",
	},
	"iceshroom": {
		"name": "寒冰菇", "cost": 75, "recharge": 30.0, "hp": 300,
		"freeze_all": 5.0,
		"hint": "一次冻住全场僵尸，用完就消失", "tags": "夜行 · 全场控制",
	},
	"doomshroom": {
		"name": "毁灭菇", "cost": 125, "recharge": 45.0, "hp": 300,
		"blast": 5.2,
		"hint": "炸出一个大坑，坑里一段时间不能种", "tags": "夜行 · 核爆",
	},
	"magnetshroom": {
		"name": "磁力菇", "cost": 100, "recharge": 20.0, "hp": 300,
		"magnet": 4.6,
		"hint": "吸走铁桶和头盔，让僵尸露出脑袋", "tags": "夜行 · 破甲",
	},
}

const ZOMBIES := {
	"basic": {
		"name": "普通僵尸", "hp": 200.0, "speed": 0.44, "dps": 60.0,
	},
	"cone": {
		"name": "路障僵尸", "hp": 470.0, "speed": 0.44, "dps": 60.0,
	},
	"bucket": {
		"name": "铁桶僵尸", "hp": 450.0, "speed": 0.42, "dps": 60.0, "armor": 500.0,
	},
	"flag": {
		"name": "旗帜僵尸", "hp": 200.0, "speed": 0.56, "dps": 60.0,
	},
	"newspaper": {
		"name": "报纸僵尸", "hp": 190.0, "speed": 0.40, "dps": 65.0,
		"armor": 170.0, "rage_speed": 1.15,
	},
	"football": {
		"name": "橄榄球僵尸", "hp": 700.0, "speed": 0.62, "dps": 80.0, "armor": 800.0,
	},
	"pole": {
		"name": "撑杆僵尸", "hp": 500.0, "speed": 0.70, "dps": 60.0, "vault": 1,
	},
	"screendoor": {
		"name": "铁门僵尸", "hp": 280.0, "speed": 0.38, "dps": 60.0, "armor": 420.0,
	},
	"balloon": {
		"name": "气球僵尸", "hp": 240.0, "speed": 0.52, "dps": 60.0, "fly": 2.05,
	},
	"dancer": {
		"name": "舞王僵尸", "hp": 380.0, "speed": 0.50, "dps": 60.0, "summon": 4,
	},
	"backup": {
		"name": "伴舞僵尸", "hp": 240.0, "speed": 0.52, "dps": 60.0, "hidden": true,
	},
	"gargantuar": {
		"name": "巨人僵尸", "hp": 3400.0, "speed": 0.22, "dps": 0.0, "smash": true, "scale": 1.85,
	},
}

## Canonical order of the seed bank, grouped: economy → shooters → defence →
## control → water. The chooser renders this order so the cards never move.
const SEED_ORDER := [
	"sunflower", "sunshroom",
	"peashooter", "repeater", "threepeater", "snowpea", "puffshroom", "fumeshroom",
	"bonkchoy", "snapdragon", "laserbean", "blover",
	"kernelpult", "melonpult",
	"wallnut", "tallnut", "pumpkin",
	"potatomine", "squash", "chomper", "hypnoshroom", "magnetshroom", "iceshroom",
	"cherrybomb", "jalapeno", "doomshroom",
	"lilypad",
]

const LEVELS := [
	{
		"id": "front-1",
		"name": "前院 · 清晨",
		"subtitle": "第一波僵尸正在靠近，先种点向日葵吧",
		"chapter": 1,
		"difficulty": 1,
		"goal": "建立阳光经济并守住前院",
		"yard": "front",
		"sky": "dawn",
		"sun": 150,
		"sky_sun": 11.0,
		"par": 165.0,
		"seeds": ["sunflower", "peashooter", "wallnut", "potatomine"],
		"slots": 5,
		"waves": [
			{"at": 18.0, "label": "僵尸出现了", "spawns": [{"kind": "basic"}]},
			{"at": 45.0, "label": "第二只", "spawns": [{"kind": "basic", "count": 2, "gap": 4.0}]},
			{"at": 75.0, "label": "路障僵尸", "spawns": [{"kind": "cone"}, {"kind": "basic"}]},
			{"at": 105.0, "label": "更多僵尸", "spawns": [{"kind": "basic", "count": 3, "gap": 3.0}, {"kind": "cone"}]},
			{"at": 140.0, "label": "一大波僵尸正在接近", "big": true, "spawns": [
				{"kind": "flag"}, {"kind": "basic", "count": 3, "gap": 2.0}, {"kind": "cone", "count": 2, "gap": 3.0},
			]},
		],
	},
	{
		"id": "front-2",
		"name": "前院 · 午后",
		"subtitle": "铁桶僵尸来了，准备双发豌豆和樱桃炸弹",
		"chapter": 1,
		"difficulty": 2,
		"goal": "用爆发火力击破装甲僵尸",
		"yard": "front",
		"sky": "noon",
		"sun": 150,
		"sky_sun": 10.0,
		"par": 195.0,
		"seeds": ["sunflower", "peashooter", "wallnut", "snowpea", "repeater", "kernelpult", "cherrybomb", "jalapeno", "bonkchoy", "snapdragon"],
		"slots": 9,
		"waves": [
			{"at": 14.0, "label": "僵尸出现了", "spawns": [{"kind": "basic", "count": 2, "gap": 5.0}]},
			{"at": 40.0, "label": "路障僵尸", "spawns": [{"kind": "cone", "count": 2, "gap": 5.0}]},
			{"at": 70.0, "label": "撑杆僵尸", "spawns": [{"kind": "pole"}, {"kind": "newspaper"}, {"kind": "basic", "count": 2, "gap": 3.0}]},
			{"at": 100.0, "label": "铁桶僵尸", "spawns": [{"kind": "bucket"}, {"kind": "screendoor"}, {"kind": "cone", "count": 2, "gap": 4.0}]},
			{"at": 135.0, "label": "一大波僵尸正在接近", "big": true, "spawns": [
				{"kind": "flag"}, {"kind": "bucket", "count": 2, "gap": 5.0}, {"kind": "cone", "count": 2, "gap": 3.0},
			]},
			{"at": 170.0, "label": "最后一波", "big": true, "spawns": [
				{"kind": "bucket", "count": 2, "gap": 4.0}, {"kind": "screendoor"}, {"kind": "pole"},
				{"kind": "cone", "count": 2, "gap": 3.0}, {"kind": "basic", "count": 3, "gap": 2.0},
			]},
		],
	},
	{
		"id": "back-1",
		"name": "后院 · 泳池",
		"subtitle": "泳池两行必须先用睡莲铺出落脚点",
		"chapter": 1,
		"difficulty": 2,
		"goal": "铺设睡莲并守住泳池两行",
		"yard": "back",
		"sky": "pool",
		"sun": 175,
		"sky_sun": 9.0,
		"par": 210.0,
		"seeds": ["sunflower", "peashooter", "lilypad", "threepeater", "laserbean", "snapdragon", "chomper", "snowpea", "pumpkin", "melonpult", "wallnut", "blover"],
		"slots": 9,
		"waves": [
			{"at": 18.0, "label": "僵尸出现了", "spawns": [{"kind": "basic", "count": 2, "gap": 6.0}]},
			{"at": 48.0, "label": "路障僵尸", "spawns": [{"kind": "cone"}, {"kind": "basic"}]},
			{"at": 80.0, "label": "泳池也挡不住", "spawns": [
				{"kind": "basic", "lane": 2}, {"kind": "cone", "lane": 3}, {"kind": "balloon", "lane": 2},
				{"kind": "basic", "count": 2, "gap": 4.0},
			]},
			{"at": 112.0, "label": "铁桶僵尸", "spawns": [{"kind": "bucket"}, {"kind": "screendoor"}, {"kind": "cone", "count": 2, "gap": 4.0}]},
			{"at": 148.0, "label": "一大波僵尸正在接近", "big": true, "spawns": [
				{"kind": "flag"}, {"kind": "bucket", "count": 2, "gap": 5.0}, {"kind": "basic", "count": 4, "gap": 2.0},
			]},
			{"at": 185.0, "label": "最后一波", "big": true, "spawns": [
				{"kind": "bucket", "count": 3, "gap": 4.0}, {"kind": "cone", "count": 3, "gap": 3.0},
				{"kind": "balloon", "count": 2, "gap": 4.0},
			]},
		],
	},
	{
		"id": "front-3",
		"name": "前院 · 深夜",
		"subtitle": "天黑了，阳光稀少，橄榄球僵尸也来了",
		"chapter": 1,
		"difficulty": 3,
		"goal": "在低光环境下击退重装僵尸",
		"yard": "front",
		"sky": "night",
		"sun": 125,
		"sky_sun": 6.5,
		"par": 230.0,
		"seeds": ["sunflower", "sunshroom", "peashooter", "laserbean", "snapdragon", "magnetshroom", "wallnut", "iceshroom", "doomshroom", "blover"],
		"slots": 9,
		"waves": [
			{"at": 20.0, "label": "僵尸出现了", "spawns": [{"kind": "basic", "count": 2, "gap": 4.0}]},
			{"at": 50.0, "label": "路障僵尸", "spawns": [{"kind": "cone", "count": 2, "gap": 3.0}]},
			{"at": 82.0, "label": "报纸僵尸", "spawns": [{"kind": "newspaper", "count": 2, "gap": 5.0}, {"kind": "basic"}]},
			{"at": 115.0, "label": "舞王僵尸", "spawns": [{"kind": "dancer"}, {"kind": "bucket", "count": 2, "gap": 4.0}]},
			{"at": 150.0, "label": "一大波僵尸正在接近", "big": true, "spawns": [
				{"kind": "flag"}, {"kind": "football"}, {"kind": "bucket", "count": 2, "gap": 4.0},
			]},
			{"at": 190.0, "label": "最后一波", "big": true, "spawns": [
				{"kind": "football"}, {"kind": "screendoor"}, {"kind": "bucket", "count": 3, "gap": 3.0},
				{"kind": "balloon", "count": 2, "gap": 3.0}, {"kind": "cone", "count": 3, "gap": 2.0},
			]},
		],
	},

	{
		"id": "front-4", "name": "前院 · 报纸风暴", "subtitle": "阳光紧张，报纸和撑杆僵尸会逼你快速应变", "chapter": 2, "difficulty": 3,
		"goal": "用有限阳光守住报纸与撑杆的突袭", "yard": "front", "sky": "noon", "sun": 100, "sky_sun": 7.0, "par": 220.0,
		"seeds": ["sunflower", "peashooter", "wallnut", "potatomine", "snowpea", "cherrybomb", "squash"], "slots": 7,
		"waves": [
			{"at": 16.0, "label": "试探攻势", "spawns": [{"kind": "basic", "count": 2, "gap": 4.0}]},
			{"at": 46.0, "label": "报纸僵尸", "spawns": [{"kind": "newspaper"}, {"kind": "basic", "count": 2, "gap": 4.0}]},
			{"at": 78.0, "label": "撑杆突袭", "spawns": [{"kind": "pole"}, {"kind": "newspaper"}]},
			{"at": 112.0, "label": "低光压力", "spawns": [{"kind": "pole", "count": 2, "gap": 4.0}, {"kind": "cone", "count": 2, "gap": 3.0}]},
			{"at": 148.0, "label": "预备决战", "spawns": [{"kind": "flag"}, {"kind": "newspaper", "count": 3, "gap": 3.0}, {"kind": "pole", "count": 2, "gap": 4.0}]},
			{"at": 188.0, "label": "最后一波", "big": true, "spawns": [{"kind": "flag"}, {"kind": "pole", "count": 3, "gap": 3.0}, {"kind": "newspaper", "count": 3, "gap": 2.0}, {"kind": "cone", "count": 2, "gap": 3.0}]}
		]
	},
	{
		"id": "back-2", "name": "后院 · 气球泳池", "subtitle": "气球僵尸越过水面，铁桶僵尸紧随其后", "chapter": 2, "difficulty": 3,
		"goal": "用三叶草清空气球并稳住泳池", "yard": "back", "sky": "pool", "sun": 175, "sky_sun": 8.5, "par": 225.0,
		"seeds": ["sunflower", "peashooter", "lilypad", "blover", "snowpea", "wallnut", "tallnut", "melonpult"], "slots": 8,
		"waves": [
			{"at": 18.0, "label": "水面试探", "spawns": [{"kind": "basic", "count": 2, "gap": 5.0}]},
			{"at": 50.0, "label": "气球出现", "spawns": [{"kind": "balloon", "lane": 2}, {"kind": "basic", "count": 2, "gap": 4.0}]},
			{"at": 84.0, "label": "铁桶压境", "spawns": [{"kind": "bucket", "lane": 3}, {"kind": "balloon", "lane": 2}, {"kind": "cone"}]},
			{"at": 118.0, "label": "双线水压", "spawns": [{"kind": "balloon", "count": 2, "gap": 4.0}, {"kind": "bucket", "count": 2, "gap": 5.0}]},
			{"at": 154.0, "label": "预备决战", "spawns": [{"kind": "flag"}, {"kind": "screendoor"}, {"kind": "balloon", "count": 3, "gap": 3.0}]},
			{"at": 194.0, "label": "最后一波", "big": true, "spawns": [{"kind": "flag"}, {"kind": "bucket", "count": 3, "gap": 4.0}, {"kind": "balloon", "count": 3, "gap": 3.0}, {"kind": "cone", "count": 2, "gap": 3.0}]}
		]
	},
	{
		"id": "front-5", "name": "前院 · 重装混战", "subtitle": "铁门、铁桶和橄榄球僵尸组成厚重防线", "chapter": 2, "difficulty": 4,
		"goal": "集中火力拆穿多层装甲", "yard": "front", "sky": "noon", "sun": 200, "sky_sun": 8.0, "par": 240.0,
		"seeds": ["sunflower", "peashooter", "repeater", "magnetshroom", "kernelpult", "melonpult", "wallnut", "cherrybomb", "jalapeno"], "slots": 9,
		"waves": [
			{"at": 18.0, "label": "装甲试探", "spawns": [{"kind": "cone", "count": 2, "gap": 4.0}]},
			{"at": 50.0, "label": "铁桶僵尸", "spawns": [{"kind": "bucket"}, {"kind": "screendoor"}]},
			{"at": 84.0, "label": "重装混合", "spawns": [{"kind": "football"}, {"kind": "bucket"}, {"kind": "cone", "count": 2, "gap": 3.0}]},
			{"at": 120.0, "label": "装甲洪流", "spawns": [{"kind": "screendoor", "count": 2, "gap": 4.0}, {"kind": "football"}, {"kind": "bucket", "count": 2, "gap": 4.0}]},
			{"at": 158.0, "label": "预备决战", "spawns": [{"kind": "flag"}, {"kind": "football", "count": 2, "gap": 5.0}, {"kind": "screendoor", "count": 2, "gap": 3.0}]},
			{"at": 200.0, "label": "最后一波", "big": true, "spawns": [{"kind": "flag"}, {"kind": "football", "count": 2, "gap": 4.0}, {"kind": "bucket", "count": 3, "gap": 3.0}, {"kind": "screendoor", "count": 2, "gap": 3.0}]}
		]
	},
	{
		"id": "back-3", "name": "后院 · 潮汐交替", "subtitle": "陆地与水路轮番施压，别让阵线断开", "chapter": 2, "difficulty": 4,
		"goal": "在陆地与泳池之间轮换防线", "yard": "back", "sky": "pool", "sun": 200, "sky_sun": 8.5, "par": 245.0,
		"seeds": ["sunflower", "peashooter", "lilypad", "threepeater", "snapdragon", "wallnut", "pumpkin", "blover", "squash"], "slots": 9,
		"waves": [
			{"at": 18.0, "label": "陆路试探", "spawns": [{"kind": "basic", "lane": 0, "count": 2, "gap": 4.0}]},
			{"at": 50.0, "label": "水路推进", "spawns": [{"kind": "basic", "lane": 2}, {"kind": "cone", "lane": 3}]},
			{"at": 84.0, "label": "交替混合", "spawns": [{"kind": "pole", "lane": 1}, {"kind": "balloon", "lane": 2}, {"kind": "cone", "lane": 4}]},
			{"at": 120.0, "label": "两面夹击", "spawns": [{"kind": "bucket", "lane": 0}, {"kind": "screendoor", "lane": 3}, {"kind": "balloon", "count": 2, "gap": 4.0}]},
			{"at": 160.0, "label": "预备决战", "spawns": [{"kind": "flag"}, {"kind": "pole", "count": 2, "gap": 4.0}, {"kind": "bucket", "lane": 2}, {"kind": "cone", "lane": 4}]},
			{"at": 202.0, "label": "最后一波", "big": true, "spawns": [{"kind": "flag"}, {"kind": "bucket", "count": 2, "gap": 4.0}, {"kind": "balloon", "count": 3, "gap": 3.0}, {"kind": "screendoor", "count": 2, "gap": 3.0}]}
		]
	},
	{
		"id": "front-6", "name": "前院 · 月下舞会", "subtitle": "夜色压低收入，舞王会在空隙中召来伴舞", "chapter": 3, "difficulty": 4,
		"goal": "维持夜间经济并破解舞王节奏", "yard": "front", "sky": "night", "sun": 100, "sky_sun": 5.0, "par": 250.0,
		"seeds": ["sunshroom", "puffshroom", "fumeshroom", "magnetshroom", "wallnut", "iceshroom", "hypnoshroom", "cherrybomb", "doomshroom"], "slots": 9,
		"waves": [
			{"at": 20.0, "label": "夜行试探", "spawns": [{"kind": "basic", "count": 2, "gap": 5.0}]},
			{"at": 54.0, "label": "短程压力", "spawns": [{"kind": "cone", "count": 2, "gap": 4.0}, {"kind": "newspaper"}]},
			{"at": 90.0, "label": "舞王登场", "spawns": [{"kind": "dancer"}, {"kind": "basic", "count": 2, "gap": 4.0}]},
			{"at": 126.0, "label": "黑夜经济", "spawns": [{"kind": "bucket"}, {"kind": "dancer"}, {"kind": "newspaper", "count": 2, "gap": 3.0}]},
			{"at": 166.0, "label": "预备决战", "spawns": [{"kind": "flag"}, {"kind": "dancer", "count": 2, "gap": 6.0}, {"kind": "bucket", "count": 2, "gap": 4.0}]},
			{"at": 210.0, "label": "最后一波", "big": true, "spawns": [{"kind": "flag"}, {"kind": "dancer", "count": 2, "gap": 5.0}, {"kind": "football"}, {"kind": "bucket", "count": 3, "gap": 3.0}]}
		]
	},
	{
		"id": "back-4", "name": "后院 · 深水重压", "subtitle": "陆空混合的密集攻势会同时挤满泳池", "chapter": 3, "difficulty": 5,
		"goal": "在密集泳池战中保持每条通道畅通", "yard": "back", "sky": "pool", "sun": 225, "sky_sun": 8.0, "par": 265.0,
		"seeds": ["sunflower", "peashooter", "lilypad", "threepeater", "melonpult", "tallnut", "pumpkin", "blover", "jalapeno"], "slots": 9,
		"waves": [
			{"at": 18.0, "label": "密集试探", "spawns": [{"kind": "basic", "count": 3, "gap": 3.0}]},
			{"at": 52.0, "label": "水面混合", "spawns": [{"kind": "cone", "lane": 2}, {"kind": "balloon", "lane": 3}, {"kind": "basic", "count": 2, "gap": 3.0}]},
			{"at": 88.0, "label": "铁桶推进", "spawns": [{"kind": "bucket", "count": 2, "gap": 4.0}, {"kind": "screendoor"}]},
			{"at": 126.0, "label": "全线拥挤", "spawns": [{"kind": "balloon", "count": 3, "gap": 3.0}, {"kind": "bucket", "count": 2, "gap": 4.0}, {"kind": "pole"}]},
			{"at": 166.0, "label": "预备决战", "spawns": [{"kind": "flag"}, {"kind": "screendoor", "count": 2, "gap": 3.0}, {"kind": "balloon", "count": 2, "gap": 4.0}, {"kind": "bucket"}]},
			{"at": 212.0, "label": "最后一波", "big": true, "spawns": [{"kind": "flag"}, {"kind": "bucket", "count": 3, "gap": 3.0}, {"kind": "balloon", "count": 3, "gap": 3.0}, {"kind": "screendoor", "count": 2, "gap": 3.0}, {"kind": "pole"}]}
		]
	},
	{
		"id": "front-7", "name": "前院 · 巨人警报", "subtitle": "警报拉响，巨人僵尸终于踏入前院", "chapter": 3, "difficulty": 5,
		"goal": "为巨人僵尸准备足够的爆发与控制", "yard": "front", "sky": "noon", "sun": 250, "sky_sun": 8.5, "par": 275.0,
		"seeds": ["sunflower", "repeater", "threepeater", "melonpult", "wallnut", "tallnut", "pumpkin", "cherrybomb", "jalapeno"], "slots": 9,
		"waves": [
			{"at": 20.0, "label": "警戒试探", "spawns": [{"kind": "cone", "count": 2, "gap": 4.0}]},
			{"at": 56.0, "label": "重装信号", "spawns": [{"kind": "bucket"}, {"kind": "football"}]},
			{"at": 94.0, "label": "多线混战", "spawns": [{"kind": "pole"}, {"kind": "screendoor"}, {"kind": "bucket", "count": 2, "gap": 4.0}]},
			{"at": 134.0, "label": "巨人预兆", "spawns": [{"kind": "football", "count": 2, "gap": 5.0}, {"kind": "screendoor", "count": 2, "gap": 3.0}]},
			{"at": 176.0, "label": "预备决战", "spawns": [{"kind": "flag"}, {"kind": "bucket", "count": 3, "gap": 3.0}, {"kind": "football"}]},
			{"at": 220.0, "label": "最后一波", "big": true, "spawns": [{"kind": "flag"}, {"kind": "gargantuar"}, {"kind": "football", "count": 2, "gap": 4.0}, {"kind": "bucket", "count": 3, "gap": 3.0}]}
		]
	},
	{
		"id": "back-5", "name": "后院 · 最终泳池", "subtitle": "最后的泳池战役，所有路线同时告急", "chapter": 3, "difficulty": 5,
		"goal": "守住泳池并完成最终旗帜波", "yard": "back", "sky": "pool", "sun": 250, "sky_sun": 8.0, "par": 290.0,
		"seeds": ["sunflower", "lilypad", "threepeater", "melonpult", "tallnut", "pumpkin", "blover", "cherrybomb", "jalapeno"], "slots": 9,
		"waves": [
			{"at": 20.0, "label": "最终试探", "spawns": [{"kind": "basic", "count": 3, "gap": 3.0}]},
			{"at": 58.0, "label": "水陆齐进", "spawns": [{"kind": "cone", "lane": 0}, {"kind": "balloon", "lane": 2}, {"kind": "pole", "lane": 4}]},
			{"at": 98.0, "label": "第一轮混战", "spawns": [{"kind": "bucket", "count": 2, "gap": 4.0}, {"kind": "screendoor"}, {"kind": "balloon", "count": 2, "gap": 3.0}]},
			{"at": 140.0, "label": "资源压力", "spawns": [{"kind": "football"}, {"kind": "bucket", "count": 3, "gap": 3.0}, {"kind": "balloon", "count": 3, "gap": 3.0}]},
			{"at": 184.0, "label": "预备决战", "spawns": [{"kind": "flag"}, {"kind": "screendoor", "count": 2, "gap": 3.0}, {"kind": "football", "count": 2, "gap": 4.0}]},
			{"at": 230.0, "label": "最后一波", "big": true, "spawns": [{"kind": "flag"}, {"kind": "gargantuar"}, {"kind": "bucket", "count": 3, "gap": 3.0}, {"kind": "balloon", "count": 3, "gap": 3.0}, {"kind": "screendoor", "count": 2, "gap": 3.0}]}
		]
	},
]


## Endless mode. `waves` is deliberately empty: Match generates them from
## ENDLESS_ROSTER, so a run never runs out of content.
const ENDLESS := {
	"id": "endless",
	"name": "无尽模式",
	"subtitle": "没有终点，只有下一波",
	"yard": "front",
	"sky": "noon",
	"sun": 250,
	"sky_sun": 8.0,
	"par": 0.0,
	"seeds": ["sunflower", "peashooter", "bonkchoy", "snapdragon", "laserbean", "blover", "wallnut", "repeater", "snowpea", "kernelpult",
		"melonpult", "pumpkin", "cherrybomb", "jalapeno", "threepeater", "tallnut"],
	"slots": 9,
	"waves": [],
	"endless": true,
	"first_wave": 18.0,
}

## Per-wave budget buys from this table. `from` is the first wave the kind may
## appear in, `weight` biases the random pick, `cost` is charged to the budget.
const ENDLESS_ROSTER := [
	{"kind": "basic", "cost": 1.0, "from": 1, "weight": 3.0},
	{"kind": "cone", "cost": 2.0, "from": 2, "weight": 2.4},
	{"kind": "pole", "cost": 2.5, "from": 3, "weight": 1.5},
	{"kind": "newspaper", "cost": 2.0, "from": 4, "weight": 1.2},
	{"kind": "bucket", "cost": 3.0, "from": 5, "weight": 1.8},
	{"kind": "screendoor", "cost": 3.2, "from": 6, "weight": 1.3},
	{"kind": "balloon", "cost": 2.6, "from": 7, "weight": 1.1},
	{"kind": "football", "cost": 4.0, "from": 9, "weight": 1.0},
	{"kind": "dancer", "cost": 5.0, "from": 11, "weight": 0.9},
	{"kind": "gargantuar", "cost": 10.0, "from": 14, "weight": 0.55},
]


## Roster entries legal on `wave` (1-based).
static func endless_roster(wave: int) -> Array:
	var out: Array = []
	for e in ENDLESS_ROSTER:
		if int(e["from"]) <= wave:
			out.append(e)
	return out if out.size() > 0 else [ENDLESS_ROSTER[0]]


## Kinds that can actually appear as a wave (backup dancers are summoned).
static func zombie_kinds() -> Array:
	var out: Array = []
	for k in ZOMBIES.keys():
		if not bool(ZOMBIES[k].get("hidden", false)):
			out.append(k)
	return out


## 金币掉落表：击杀时的掉率与枚数。越硬的僵尸赏金越高；
## 伴舞掉率低（它自己没出场费）。金币目前只进钱袋，用途待定。
const COIN_TABLE := {
	"basic": {"chance": 0.32, "n": 1},
	"cone": {"chance": 0.36, "n": 1},
	"flag": {"chance": 0.40, "n": 1},
	"newspaper": {"chance": 0.36, "n": 1},
	"pole": {"chance": 0.45, "n": 1},
	"bucket": {"chance": 0.50, "n": 1},
	"screendoor": {"chance": 0.50, "n": 1},
	"balloon": {"chance": 0.45, "n": 1},
	"backup": {"chance": 0.25, "n": 1},
	"dancer": {"chance": 0.60, "n": 2},
	"football": {"chance": 0.65, "n": 2},
	"gargantuar": {"chance": 1.0, "n": 5},
}


static func coin_drop(kind: String) -> Dictionary:
	return COIN_TABLE.get(kind, {"chance": 0.3, "n": 1})


static func plant(kind: String) -> Dictionary:
	return PLANTS.get(kind, PLANTS["sunflower"])


static func zombie(kind: String) -> Dictionary:
	return ZOMBIES.get(kind, ZOMBIES["basic"])


static func level(id: String) -> Dictionary:
	if id == "endless":
		return ENDLESS
	for l in LEVELS:
		if l["id"] == id:
			return l
	return LEVELS[0]


static func level_exists(id: String) -> bool:
	if id == "endless":
		return true
	for l in LEVELS:
		if str(l.get("id", "")) == id:
			return true
	return false


## Validate authored campaign data without mutating the source catalog.
## Returns {ok: bool, errors: Array[String]} so tools can print concise logs.
static func validate_levels(levels: Array, include_endless: bool = false) -> Dictionary:
	var errors: Array[String] = []
	var ids := {}
	var skies := {"dawn": true, "noon": true, "night": true, "pool": true}
	var yards := {"front": true, "back": true}
	for index in range(levels.size()):
		var level = levels[index]
		var prefix := "level[%d]" % index
		if typeof(level) != TYPE_DICTIONARY:
			errors.append("%s must be object" % prefix)
			continue
		var id := str(level.get("id", "")).strip_edges()
		if id == "":
			errors.append("%s empty id" % prefix)
		elif ids.has(id):
			errors.append("duplicate id: %s" % id)
		else:
			ids[id] = true
		var is_endless := bool(level.get("endless", false))
		# Endless owns a separate generated wave source; skip it in campaign mode.
		if is_endless and not include_endless:
			continue
		var required := ["name", "subtitle", "chapter", "difficulty", "goal", "yard", "sky", "sun", "sky_sun", "par", "seeds", "slots", "waves"]
		if is_endless:
			required = ["name", "subtitle", "yard", "sky", "sun", "sky_sun", "par", "seeds", "slots", "waves", "endless", "first_wave"]
		for field in required:
			if not level.has(field):
				errors.append("%s missing %s" % [id if id != "" else prefix, field])
		if is_endless:
			if not bool(level.get("endless", false)):
				errors.append("%s endless must be true" % (id if id != "" else prefix))
			if float(level.get("first_wave", 0.0)) <= 0.0:
				errors.append("%s invalid first_wave" % (id if id != "" else prefix))
		if not yards.has(str(level.get("yard", ""))):
			errors.append("%s unknown yard" % (id if id != "" else prefix))
		if not skies.has(str(level.get("sky", ""))):
			errors.append("%s unknown sky" % (id if id != "" else prefix))
		var slots := int(level.get("slots", 0))
		if slots < 1 or slots > 9:
			errors.append("%s invalid slots" % (id if id != "" else prefix))
		var seeds = level.get("seeds", [])
		if typeof(seeds) != TYPE_ARRAY:
			errors.append("%s seeds not array" % (id if id != "" else prefix))
		else:
			if seeds.size() == 0:
				errors.append("%s empty seeds" % (id if id != "" else prefix))
			for plant_id in seeds:
				if not PLANTS.has(str(plant_id)):
					errors.append("%s unknown plant: %s" % [id if id != "" else prefix, str(plant_id)])
		var waves = level.get("waves", [])
		if typeof(waves) != TYPE_ARRAY or (waves.is_empty() and not is_endless):
			errors.append("%s empty waves" % (id if id != "" else prefix))
			continue
		var previous_at := -1.0
		for wave_index in range(waves.size()):
			var wave = waves[wave_index]
			var wave_prefix := "%s wave[%d]" % [id if id != "" else prefix, wave_index]
			if typeof(wave) != TYPE_DICTIONARY:
				errors.append("%s must be object" % wave_prefix)
				continue
			var at := float(wave.get("at", -1.0))
			if at < 0.0 or at <= previous_at:
				errors.append("%s non-monotonic time" % wave_prefix)
			previous_at = at
			var spawns = wave.get("spawns", [])
			if typeof(spawns) != TYPE_ARRAY or spawns.is_empty():
				errors.append("%s empty spawns" % wave_prefix)
				continue
			for spawn in spawns:
				if typeof(spawn) != TYPE_DICTIONARY:
					errors.append("%s invalid spawn" % wave_prefix)
					continue
				var kind := str(spawn.get("kind", ""))
				if not ZOMBIES.has(kind):
					errors.append("%s unknown zombie: %s" % [wave_prefix, kind])
	return {"ok": errors.is_empty(), "errors": errors}


static func yard(name: String) -> Dictionary:
	return BACK if name == "back" else FRONT


static func is_water(yard: Dictionary, row: int) -> bool:
	return yard["water_rows"].has(row)


static func col_x(yard: Dictionary, c: int) -> float:
	# column 0 is always the one closest to the house
	if int(yard.get("house_side", -1)) < 0:
		return yard["x0"] + (c + 0.5) * TILE
	return yard["x1"] - (c + 0.5) * TILE


static func row_z(yard: Dictionary, r: int) -> float:
	return yard["z0"] + (r + 0.5) * TILE


static func col_at(yard: Dictionary, x: float) -> int:
	if int(yard.get("house_side", -1)) < 0:
		return int(floor((x - yard["x0"]) / TILE))
	return int(floor((yard["x1"] - x) / TILE))


static func row_at(yard: Dictionary, z: float) -> int:
	return int(floor((z - yard["z0"]) / TILE))


static func inside(yard: Dictionary, x: float, z: float, pad := 0.0) -> bool:
	return (
		x >= yard["x0"] + pad and x <= yard["x1"] - pad
		and z >= yard["z0"] + pad and z <= yard["z1"] - pad
	)


## +1 if zombies walk toward +X, -1 if they walk toward -X.
static func zombie_dir(yard: Dictionary) -> int:
	return 1 if yard["goal_x"] > yard["spawn_x"] else -1
