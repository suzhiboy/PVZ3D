/** Keyboard + pointer-lock mouse input with edge-triggered presses. */
export class Input {
  readonly keys = new Set<string>();
  readonly pressed = new Set<string>();
  dx = 0;
  dy = 0;
  wheel = 0;
  locked = false;
  enabled = true;
  onLockChange: ((locked: boolean) => void) | null = null;
  /** Fired on the first real user gesture (used to unlock audio). */
  onGesture: (() => void) | null = null;

  private gestured = false;

  constructor(private readonly canvas: HTMLCanvasElement) {
    window.addEventListener('keydown', this.onKeyDown, { passive: false });
    window.addEventListener('keyup', this.onKeyUp);
    window.addEventListener('blur', this.onBlur);
    document.addEventListener('pointerlockchange', this.onPointerLockChange);
    canvas.addEventListener('mousedown', this.onMouseDown);
    window.addEventListener('mouseup', this.onMouseUp);
    window.addEventListener('mousemove', this.onMouseMove);
    canvas.addEventListener('wheel', this.onWheel, { passive: false });
    canvas.addEventListener('contextmenu', this.onContextMenu);
  }

  dispose(): void {
    window.removeEventListener('keydown', this.onKeyDown);
    window.removeEventListener('keyup', this.onKeyUp);
    window.removeEventListener('blur', this.onBlur);
    document.removeEventListener('pointerlockchange', this.onPointerLockChange);
    this.canvas.removeEventListener('mousedown', this.onMouseDown);
    window.removeEventListener('mouseup', this.onMouseUp);
    window.removeEventListener('mousemove', this.onMouseMove);
    this.canvas.removeEventListener('wheel', this.onWheel);
    this.canvas.removeEventListener('contextmenu', this.onContextMenu);
  }

  isDown(code: string): boolean {
    return this.keys.has(code);
  }

  wasPressed(code: string): boolean {
    return this.pressed.has(code);
  }

  /** Call once at the end of every update to clear edge state. */
  endFrame(): void {
    this.pressed.clear();
    this.dx = 0;
    this.dy = 0;
    this.wheel = 0;
  }

  requestLock(): void {
    if (this.locked) return;
    const maybe = this.canvas.requestPointerLock() as unknown;
    if (maybe && typeof (maybe as Promise<void>).catch === 'function') {
      (maybe as Promise<void>).catch(() => {});
    }
  }

  releaseLock(): void {
    if (document.pointerLockElement === this.canvas) document.exitPointerLock();
  }

  private gesture(): void {
    if (this.gestured) return;
    this.gestured = true;
    this.onGesture?.();
  }

  private readonly onKeyDown = (e: KeyboardEvent): void => {
    if (e.repeat) return;
    // Let the browser handle devtools/reload; swallow everything else while playing.
    if (e.code === 'F5' || e.code === 'F12') return;
    this.keys.add(e.code);
    this.pressed.add(e.code);
    if (this.enabled) {
      e.preventDefault();
      this.gesture();
    }
  };

  private readonly onKeyUp = (e: KeyboardEvent): void => {
    this.keys.delete(e.code);
  };

  private readonly onBlur = (): void => {
    this.keys.clear();
    this.pressed.clear();
  };

  private readonly onPointerLockChange = (): void => {
    this.locked = document.pointerLockElement === this.canvas;
    this.onLockChange?.(this.locked);
  };

  private readonly onMouseDown = (e: MouseEvent): void => {
    this.gesture();
    if (!this.locked) {
      this.requestLock();
      return;
    }
    this.pressed.add(`Mouse${e.button}`);
  };

  private readonly onMouseUp = (e: MouseEvent): void => {
    if (e.button < 3) this.pressed.add(`MouseUp${e.button}`);
  };

  private readonly onMouseMove = (e: MouseEvent): void => {
    if (!this.locked || !this.enabled) return;
    this.dx += e.movementX;
    this.dy += e.movementY;
  };

  private readonly onWheel = (e: WheelEvent): void => {
    if (!this.enabled) return;
    e.preventDefault();
    this.wheel += Math.sign(e.deltaY);
  };

  private readonly onContextMenu = (e: Event): void => {
    e.preventDefault();
  };
}
