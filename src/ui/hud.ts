/**
 * DOM HUD: sun bank, wave progress, the seed bar, crosshair and the
 * intro / win / lose panels. Styles live in `style.css`.
 */
import { audio } from '../core/audio.ts';
import { PLANT_DEFS, type PlantKind } from '../game/types.ts';
import type { HudData } from '../game/game.ts';

export type PanelKind = 'intro' | 'won' | 'lost' | 'paused' | null;

export interface PanelInfo {
  title: string;
  body: string;
  button: string;
  secondary?: string;
}

export interface LevelEntry {
  id: string;
  name: string;
  subtitle: string;
  done: boolean;
  current: boolean;
}

export class Hud {
  onSelect: ((kind: PlantKind | null) => void) | null = null;
  onPrimary: (() => void) | null = null;
  onSecondary: (() => void) | null = null;
  /** Fires when the player confirms a hand of seeds in the chooser. */
  onSeedsConfirm: ((picked: PlantKind[]) => void) | null = null;

  private readonly sunValue: HTMLElement;
  private readonly levelName: HTMLElement;
  private readonly waveFill: HTMLElement;
  private readonly waveLabel: HTMLElement;
  private readonly seedbar: HTMLElement;
  private readonly hint: HTMLElement;
  private readonly panel: HTMLElement;
  private readonly panelTitle: HTMLElement;
  private readonly panelBody: HTMLElement;
  private readonly levelList: HTMLElement;
  private readonly seedPool: HTMLElement;
  private readonly primaryBtn: HTMLButtonElement;
  private readonly secondaryBtn: HTMLButtonElement;
  private readonly crosshair: HTMLElement;

  private cards: { kind: PlantKind; el: HTMLElement; cool: HTMLElement; cost: HTMLElement }[] = [];
  private seedKey = '';
  private lastSun = -1;
  private lastHint = '';
  private lastWave = '';
  private lastProgress = -1;
  private panelKind: PanelKind = null;
  /** seed chooser state: open flag, the hand being built, and the cap */
  private pickerOpen = false;
  private picked: PlantKind[] = [];
  private pickCap = 6;

  constructor(root: HTMLElement) {
    root.insertAdjacentHTML(
      'beforeend',
      `<div class="hud-top">
         <div class="sun-bank"><span class="sun-orb"></span><b id="sun-value">0</b></div>
         <div class="level-box">
           <div class="level-name" id="level-name"></div>
           <div class="wave-bar"><i id="wave-fill"></i></div>
           <div class="wave-label" id="wave-label"></div>
         </div>
       </div>
       <div class="crosshair" id="crosshair"></div>
       <div class="seedbar" id="seedbar"></div>
       <div class="hint" id="hint"></div>
       <div class="panel hidden" id="panel">
         <h1 id="panel-title"></h1>
         <p id="panel-body"></p>
         <div class="level-list hidden" id="level-list"></div>
         <div class="seed-pool hidden" id="seed-pool"></div>
         <div class="panel-buttons">
           <button id="panel-primary"></button>
           <button id="panel-secondary" class="ghost"></button>
         </div>
       </div>`,
    );

    this.sunValue = root.querySelector('#sun-value') as HTMLElement;
    this.levelName = root.querySelector('#level-name') as HTMLElement;
    this.waveFill = root.querySelector('#wave-fill') as HTMLElement;
    this.waveLabel = root.querySelector('#wave-label') as HTMLElement;
    this.seedbar = root.querySelector('#seedbar') as HTMLElement;
    this.hint = root.querySelector('#hint') as HTMLElement;
    this.panel = root.querySelector('#panel') as HTMLElement;
    this.panelTitle = root.querySelector('#panel-title') as HTMLElement;
    this.panelBody = root.querySelector('#panel-body') as HTMLElement;
    this.levelList = root.querySelector('#level-list') as HTMLElement;
    this.seedPool = root.querySelector('#seed-pool') as HTMLElement;
    this.primaryBtn = root.querySelector('#panel-primary') as HTMLButtonElement;
    this.secondaryBtn = root.querySelector('#panel-secondary') as HTMLButtonElement;
    this.crosshair = root.querySelector('#crosshair') as HTMLElement;

    this.seedbar.addEventListener('click', (ev) => {
      const target = (ev.target as HTMLElement).closest('.seed') as HTMLElement | null;
      if (!target) return;
      const kind = target.dataset.kind as PlantKind | undefined;
      if (!kind) return;
      this.onSelect?.(kind);
    });
    this.primaryBtn.addEventListener('click', () => this.pressPrimary());
    this.secondaryBtn.addEventListener('click', () => this.onSecondary?.());
  }

  buildSeeds(kinds: PlantKind[]): void {
    const key = kinds.join(',');
    if (key === this.seedKey) return;
    this.seedKey = key;
    this.seedbar.innerHTML = '';
    this.cards = kinds.map((kind, i) => {
      const def = PLANT_DEFS[kind];
      const el = document.createElement('button');
      el.className = 'seed';
      el.dataset.kind = kind;
      el.innerHTML =
        `<span class="seed-key">${i + 1}</span>` +
        `<span class="seed-icon">${def.icon}</span>` +
        `<span class="seed-name">${def.name}</span>` +
        `<span class="seed-cost"><i>☀</i>${def.cost}</span>` +
        `<span class="seed-cool"></span>`;
      this.seedbar.appendChild(el);
      const cool = el.querySelector('.seed-cool') as HTMLElement;
      const cost = el.querySelector('.seed-cost') as HTMLElement;
      return { kind, el, cool, cost };
    });
  }

  render(d: HudData): void {
    if (d.sun !== this.lastSun) {
      this.lastSun = d.sun;
      this.sunValue.textContent = String(d.sun);
    }
    if (d.levelName && this.levelName.textContent !== d.levelName) this.levelName.textContent = d.levelName;
    const pct = Math.round(d.progress * 100);
    if (pct !== this.lastProgress) {
      this.lastProgress = pct;
      this.waveFill.style.width = `${Math.max(4, pct)}%`;
    }
    const waveText = d.waveLabel || (d.state === 'playing' ? '准备…' : '');
    if (waveText !== this.lastWave) {
      this.lastWave = waveText;
      this.waveLabel.textContent = waveText;
      if (waveText) {
        this.waveLabel.classList.remove('pop');
        void this.waveLabel.offsetWidth;
        this.waveLabel.classList.add('pop');
      }
    }
    if (d.hint !== this.lastHint) {
      this.lastHint = d.hint;
      this.hint.textContent = d.hint;
    }
    this.crosshair.classList.toggle('hot', d.aimValid && d.hasAim);
    for (const c of this.cards) {
      const slot = d.seeds.find((s) => s.kind === c.kind);
      if (!slot) continue;
      c.el.classList.toggle('selected', slot.selected);
      c.el.classList.toggle('cooling', !slot.ready);
      c.el.classList.toggle('poor', slot.ready && !slot.affordable);
      c.el.classList.toggle('armed', slot.selected && slot.ready && slot.affordable);
      c.cool.style.height = slot.ready ? '0%' : `${Math.round(slot.cooldown01 * 100)}%`;
      c.cost.classList.toggle('poor', !slot.affordable);
    }
  }

  showPanel(kind: PanelKind, info?: PanelInfo): void {
    this.panelKind = kind;
    this.pickerOpen = false;
    this.levelList.innerHTML = '';
    this.levelList.classList.add('hidden');
    this.seedPool.innerHTML = '';
    this.seedPool.classList.add('hidden');
    if (!kind || !info) {
      this.panel.classList.add('hidden');
      return;
    }
    this.panel.classList.remove('hidden');
    this.panel.dataset.kind = kind;
    this.panelTitle.textContent = info.title;
    this.panelBody.textContent = info.body;
    this.primaryBtn.textContent = info.button;
    this.primaryBtn.disabled = false;
    this.secondaryBtn.textContent = info.secondary ?? '';
    this.secondaryBtn.style.display = info.secondary ? '' : 'none';
  }

  /**
   * The pre-battle hand: pick up to `max` plants out of the yard's full pool,
   * the way the original seed chooser works. Picking order becomes the slot
   * order on the seed bar.
   */
  showSeedChooser(pool: PlantKind[], chosen: PlantKind[], max: number): void {
    this.pickerOpen = true;
    this.pickCap = max;
    this.picked = chosen.filter((k) => pool.includes(k)).slice(0, max);
    this.seedPool.innerHTML = '';
    this.seedPool.classList.remove('hidden');

    const count = document.createElement('div');
    count.className = 'pick-count';
    this.seedPool.appendChild(count);

    const grid = document.createElement('div');
    grid.className = 'pick-grid';
    this.seedPool.appendChild(grid);

    const chips = new Map<PlantKind, HTMLElement>();
    const paint = (): void => {
      count.textContent = `已带 ${this.picked.length} / ${max} 张 · 点一下加入，再点取消`;
      for (const [kind, el] of chips) {
        const i = this.picked.indexOf(kind);
        el.classList.toggle('picked', i >= 0);
        const order = el.querySelector('.pick-order') as HTMLElement;
        order.textContent = i >= 0 ? String(i + 1) : '';
      }
      this.primaryBtn.disabled = this.picked.length === 0;
    };

    for (const kind of pool) {
      const def = PLANT_DEFS[kind];
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'seed-pick';
      btn.dataset.kind = kind;
      btn.innerHTML =
        `<span class="pick-order"></span>` +
        `<span class="pick-icon">${def.icon}</span>` +
        `<span class="pick-text"><b>${def.name}</b><i>☀ ${def.cost}</i></span>`;
      btn.addEventListener('click', () => {
        const at = this.picked.indexOf(kind);
        if (at >= 0) this.picked.splice(at, 1);
        else if (this.picked.length < this.pickCap) this.picked.push(kind);
        else audio.play('deny', 0.4);
        paint();
      });
      chips.set(kind, btn);
      grid.appendChild(btn);
    }
    paint();
  }

  /** True while the chooser owns the primary button. */
  get choosingSeeds(): boolean {
    return this.pickerOpen;
  }

  /** Keyboard/click equivalent of the primary button. */
  pressPrimary(): void {
    if (this.pickerOpen) {
      const hand = [...this.picked];
      if (hand.length === 0) return;
      this.pickerOpen = false;
      this.onSeedsConfirm?.(hand);
      return;
    }
    this.onPrimary?.();
  }

  /** Level chooser rendered inside the panel (front yard / backyard). */
  showLevelPicker(entries: LevelEntry[], onPick: (id: string) => void): void {
    this.levelList.innerHTML = '';
    this.levelList.classList.remove('hidden');
    for (const e of entries) {
      const btn = document.createElement('button');
      btn.type = 'button';
      btn.className = 'level-item';
      btn.classList.toggle('done', e.done);
      btn.classList.toggle('current', e.current);
      btn.dataset.level = e.id;
      const name = document.createElement('b');
      name.textContent = e.name;
      const sub = document.createElement('span');
      sub.textContent = e.done ? `${e.subtitle} · 已通关` : e.subtitle;
      btn.append(name, sub);
      btn.addEventListener('click', () => onPick(e.id));
      this.levelList.appendChild(btn);
    }
  }

  get visiblePanel(): PanelKind {
    return this.panelKind;
  }

  setPointerOverUi(over: boolean): void {
    this.seedbar.style.pointerEvents = over ? 'auto' : 'none';
  }
}
