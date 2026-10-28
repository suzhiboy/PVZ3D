/**
 * Game data: plant and zombie definitions, wave tables and level recipes.
 * Everything the simulation needs to know about a unit lives here.
 */

export type PlantKind =
  | 'sunflower'
  | 'peashooter'
  | 'wallnut'
  | 'snowpea'
  | 'repeater'
  | 'cherrybomb'
  | 'potatomine'
  | 'threepeater'
  | 'chomper'
  | 'lilypad'
  | 'tallnut';

export type ZombieKind = 'basic' | 'cone' | 'bucket' | 'flag';

export interface PlantDef {
  kind: PlantKind;
  /** Shown in the seed bar. */
  name: string;
  icon: string;
  cost: number;
  /** Seconds before the packet can be used again. */
  recharge: number;
  hp: number;
  /** Only plantable on water (pool rows). */
  water?: boolean;
  /** Pea damage per shot, 0 for support plants. */
  shot?: number;
  /** Seconds between shots. */
  cadence?: number;
  /** One-line hint shown while the packet is selected. */
  hint: string;
}

export const PLANT_DEFS: Record<PlantKind, PlantDef> = {
  sunflower: {
    kind: 'sunflower',
    name: '向日葵',
    icon: '🌻',
    cost: 50,
    recharge: 7,
    hp: 300,
    hint: '每隔一段时间产出 25 阳光',
  },
  peashooter: {
    kind: 'peashooter',
    name: '豌豆射手',
    icon: '🫛',
    cost: 100,
    recharge: 7,
    hp: 300,
    shot: 25,
    cadence: 1.35,
    hint: '向本行前方的僵尸发射豌豆',
  },
  wallnut: {
    kind: 'wallnut',
    name: '坚果墙',
    icon: '🥜',
    cost: 50,
    recharge: 20,
    hp: 1200,
    hint: '厚实的坚果，替植物挡下僵尸',
  },
  snowpea: {
    kind: 'snowpea',
    name: '寒冰射手',
    icon: '❄️',
    cost: 175,
    recharge: 8,
    hp: 300,
    shot: 25,
    cadence: 1.5,
    hint: '冰冻豌豆可以减速僵尸',
  },
  repeater: {
    kind: 'repeater',
    name: '双发豌豆',
    icon: '🌱',
    cost: 200,
    recharge: 8,
    hp: 300,
    shot: 25,
    cadence: 1.5,
    hint: '一次射出两颗豌豆',
  },
  cherrybomb: {
    kind: 'cherrybomb',
    name: '樱桃炸弹',
    icon: '🍒',
    cost: 150,
    recharge: 24,
    hp: 400,
    hint: '爆炸炸飞身边一圈的僵尸',
  },
  potatomine: {
    kind: 'potatomine',
    name: '土豆雷',
    icon: '🥔',
    cost: 25,
    recharge: 12,
    hp: 300,
    hint: '埋下后需要一点时间，踩上就炸',
  },
  threepeater: {
    kind: 'threepeater',
    name: '三线射手',
    icon: '🌿',
    cost: 325,
    recharge: 9,
    hp: 300,
    shot: 25,
    cadence: 1.5,
    hint: '同时向三条行发射豌豆',
  },
  chomper: {
    kind: 'chomper',
    name: '大嘴花',
    icon: '😮',
    cost: 150,
    recharge: 10,
    hp: 300,
    hint: '一口吞掉面前的僵尸，然后慢慢咀嚼',
  },
  lilypad: {
    kind: 'lilypad',
    name: '睡莲',
    icon: '🍃',
    cost: 25,
    recharge: 6,
    hp: 400,
    water: true,
    hint: '种在水面上，让陆生植物站上去',
  },
  tallnut: {
    kind: 'tallnut',
    name: '高坚果',
    icon: '🌰',
    cost: 125,
    recharge: 22,
    hp: 2400,
    hint: '更高的坚果墙，撑得更久',
  },
};

export interface ZombieDef {
  kind: ZombieKind;
  name: string;
  hp: number;
  /** metres per second */
  speed: number;
  /** hit points per second while eating */
  dps: number;
}

export const ZOMBIE_DEFS: Record<ZombieKind, ZombieDef> = {
  basic: { kind: 'basic', name: '普通僵尸', hp: 200, speed: 0.44, dps: 60 },
  cone: { kind: 'cone', name: '路障僵尸', hp: 470, speed: 0.44, dps: 60 },
  bucket: { kind: 'bucket', name: '铁桶僵尸', hp: 950, speed: 0.42, dps: 60 },
  flag: { kind: 'flag', name: '旗帜僵尸', hp: 200, speed: 0.52, dps: 60 },
};

export interface SpawnDef {
  kind: ZombieKind;
  /** Restrict to one lane (0 based); omitted = random lane. */
  lane?: number;
  count?: number;
  gap?: number;
}

export interface WaveDef {
  /** seconds after the level starts */
  at: number;
  label: string;
  big?: boolean;
  spawns: SpawnDef[];
}

export interface LevelDef {
  id: string;
  name: string;
  subtitle: string;
  yard: 'front' | 'back';
  sunStart: number;
  skySun: number;
  seeds: PlantKind[];
  waves: WaveDef[];
}

const wave = (at: number, label: string, spawns: SpawnDef[], big = false): WaveDef => ({ at, label, spawns, big });

export const LEVELS: LevelDef[] = [
  {
    id: 'front-1',
    name: '前院 · 清晨',
    subtitle: '第一波僵尸正在靠近，先种点向日葵吧',
    yard: 'front',
    sunStart: 150,
    skySun: 11,
    seeds: ['sunflower', 'peashooter', 'wallnut', 'potatomine'],
    waves: [
      wave(14, '僵尸出现了', [{ kind: 'basic' }]),
      wave(38, '第二只', [{ kind: 'basic', count: 2, gap: 4 }]),
      wave(64, '路障僵尸', [{ kind: 'cone' }, { kind: 'basic' }]),
      wave(92, '更多僵尸', [{ kind: 'basic', count: 3, gap: 3 }, { kind: 'cone' }]),
      wave(120, '一大波僵尸', [{ kind: 'flag' }, { kind: 'basic', count: 3, gap: 2 }, { kind: 'cone', count: 2, gap: 3 }], true),
    ],
  },
  {
    id: 'front-2',
    name: '前院 · 午后',
    subtitle: '铁桶僵尸来了，准备双发豌豆',
    yard: 'front',
    sunStart: 150,
    skySun: 10,
    seeds: ['sunflower', 'peashooter', 'wallnut', 'snowpea', 'repeater', 'cherrybomb'],
    waves: [
      wave(12, '僵尸出现了', [{ kind: 'basic', count: 2, gap: 5 }]),
      wave(34, '路障僵尸', [{ kind: 'cone', count: 2, gap: 5 }]),
      wave(58, '铁桶僵尸', [{ kind: 'bucket' }, { kind: 'basic', count: 2, gap: 3 }]),
      wave(84, '更多僵尸', [{ kind: 'cone', count: 3, gap: 4 }, { kind: 'basic' }]),
      wave(110, '一大波僵尸', [{ kind: 'flag' }, { kind: 'bucket', count: 2, gap: 5 }, { kind: 'cone', count: 2, gap: 3 }], true),
      wave(142, '最后一波', [{ kind: 'bucket', count: 2, gap: 4 }, { kind: 'cone', count: 2, gap: 3 }, { kind: 'basic', count: 3, gap: 2 }], true),
    ],
  },
  {
    id: 'back-1',
    name: '后院 · 泳池',
    subtitle: '泳池两行必须先用睡莲铺出落脚点',
    yard: 'back',
    sunStart: 175,
    skySun: 9,
    seeds: ['sunflower', 'peashooter', 'wallnut', 'lilypad', 'threepeater', 'chomper', 'cherrybomb'],
    waves: [
      wave(16, '僵尸出现了', [{ kind: 'basic', count: 2, gap: 6 }]),
      wave(44, '路障僵尸', [{ kind: 'cone' }, { kind: 'basic' }]),
      wave(72, '泳池也挡不住', [{ kind: 'basic', lane: 2 }, { kind: 'cone', lane: 3 }, { kind: 'basic', count: 2, gap: 4 }]),
      wave(102, '铁桶僵尸', [{ kind: 'bucket' }, { kind: 'cone', count: 2, gap: 4 }]),
      wave(132, '一大波僵尸', [{ kind: 'flag' }, { kind: 'bucket', count: 2, gap: 5 }, { kind: 'basic', count: 4, gap: 2 }], true),
      wave(165, '最后一波', [{ kind: 'bucket', count: 3, gap: 4 }, { kind: 'cone', count: 3, gap: 3 }], true),
    ],
  },
];

export function levelById(id: string): LevelDef {
  return LEVELS.find((l) => l.id === id) ?? LEVELS[0];
}

/**
 * The full almanac of plants a player owns. The pre-battle chooser draws its
 * cards from here; a level's own `seeds` list is only the suggested hand.
 */
export const SEED_POOL: PlantKind[] = [
  'sunflower',
  'peashooter',
  'wallnut',
  'potatomine',
  'snowpea',
  'repeater',
  'cherrybomb',
  'chomper',
  'threepeater',
  'tallnut',
];

/** Plants available in a yard: the pool yard also hands out lily pads. */
export function seedPoolFor(yard: 'front' | 'back'): PlantKind[] {
  return yard === 'back' ? [...SEED_POOL, 'lilypad'] : [...SEED_POOL];
}

/** Slots on the seed bar; the pool yard needs one extra for the lily pads. */
export function seedCapFor(yard: 'front' | 'back'): number {
  return yard === 'back' ? 7 : 6;
}
