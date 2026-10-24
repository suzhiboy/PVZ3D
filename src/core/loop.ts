/**
 * Fixed-timestep game loop.
 * Simulation runs at a stable 60 Hz (so wave timing and zombie speed are
 * reproducible), rendering happens once per animation frame.
 */
export class Loop {
  readonly step = 1 / 60;
  timeScale = 1;
  running = false;

  private raf = 0;
  private last = 0;
  private acc = 0;
  private elapsed = 0;
  private fpsFrames = 0;
  private fpsTime = 0;
  /** Smoothed frames-per-second for the debug overlay. */
  fps = 0;

  constructor(
    private readonly update: (dt: number, elapsed: number) => void,
    private readonly render: (dt: number) => void,
  ) {}

  start(): void {
    if (this.running) return;
    this.running = true;
    this.last = performance.now();
    this.raf = requestAnimationFrame(this.frame);
  }

  stop(): void {
    this.running = false;
    cancelAnimationFrame(this.raf);
  }

  private readonly frame = (now: number): void => {
    if (!this.running) return;
    this.raf = requestAnimationFrame(this.frame);

    const rawMs = now - this.last;
    this.last = now;
    // Clamp huge gaps (tab switch) instead of catching up hundreds of steps.
    const frameDt = Math.min(rawMs / 1000, 0.25);

    this.fpsFrames++;
    this.fpsTime += frameDt;
    if (this.fpsTime >= 0.5) {
      this.fps = this.fpsFrames / this.fpsTime;
      this.fpsFrames = 0;
      this.fpsTime = 0;
    }

    this.acc += frameDt * this.timeScale;
    let steps = 0;
    while (this.acc >= this.step && steps < 8) {
      this.update(this.step, this.elapsed);
      this.elapsed += this.step;
      this.acc -= this.step;
      steps++;
    }
    if (steps === 8) this.acc = 0;

    this.render(frameDt);
  };
}
