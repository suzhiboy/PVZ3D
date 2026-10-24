/** URL-driven debug flags, a tiny performance overlay, and the automation handle. */
export interface DebugFlags {
  debug: boolean;
  scenario: string | null;
  seed: number;
  speed: number;
  bot: boolean;
  quality: 'low' | 'medium' | 'high';
}

function readFlags(): DebugFlags {
  const q = new URLSearchParams(location.search);
  const qualityParam = q.get('quality');
  const quality: DebugFlags['quality'] =
    qualityParam === 'low' || qualityParam === 'high' ? qualityParam : qualityParam === 'medium' ? 'medium' : 'high';
  return {
    debug: q.has('debug'),
    scenario: q.get('scenario'),
    seed: Number(q.get('seed') ?? 1) || 1,
    speed: Math.max(0.1, Math.min(8, Number(q.get('speed') ?? 1) || 1)),
    bot: q.has('bot'),
    quality,
  };
}

export const flags: DebugFlags = readFlags();

/** Minimal FPS/stat overlay, only created when debug output is requested. */
export class DebugOverlay {
  private el: HTMLDivElement | null = null;
  private acc = 0;

  constructor(private readonly readStats: () => string) {}

  private ensure(): HTMLDivElement {
    if (!this.el) {
      const el = document.createElement('div');
      el.className = 'debug-overlay';
      document.getElementById('app')?.appendChild(el);
      this.el = el;
    }
    return this.el;
  }

  update(dt: number): void {
    if (!flags.debug) return;
    this.acc += dt;
    if (this.acc < 0.2) return;
    this.acc = 0;
    this.ensure().textContent = this.readStats();
  }
}

/** Expose game internals for the headless screenshot/smoke harness. */
export function exposeAutomation(handle: Record<string, unknown>): void {
  (window as unknown as { __GAME__: Record<string, unknown> }).__GAME__ = handle;
}

export function markReady(): void {
  (window as unknown as { __GAME_READY__: boolean }).__GAME_READY__ = true;
}
