/**
 * Tiny procedurally synthesised sound engine. No audio files are shipped —
 * every effect is built from oscillators and noise buffers at runtime.
 */
export type SoundName =
  | 'select'
  | 'deny'
  | 'shoot'
  | 'hit'
  | 'plant'
  | 'sun'
  | 'chomp'
  | 'explode'
  | 'mower'
  | 'win'
  | 'lose'
  | 'splash'
  | 'step'
  | 'groan'
  | 'click';

export class AudioEngine {
  private ctx: AudioContext | null = null;
  private master: GainNode | null = null;
  private noise: AudioBuffer | null = null;
  volume = 0.7;
  muted = false;

  /** Must be called from a user gesture (browser autoplay policy). */
  unlock(): void {
    if (this.ctx) {
      if (this.ctx.state === 'suspended') void this.ctx.resume();
      return;
    }
    const Ctor = window.AudioContext ?? (window as unknown as { webkitAudioContext?: typeof AudioContext }).webkitAudioContext;
    if (!Ctor) return;
    this.ctx = new Ctor();
    this.master = this.ctx.createGain();
    this.master.gain.value = this.volume;
    this.master.connect(this.ctx.destination);

    const len = Math.floor(this.ctx.sampleRate * 1.2);
    const buf = this.ctx.createBuffer(1, len, this.ctx.sampleRate);
    const data = buf.getChannelData(0);
    for (let i = 0; i < len; i++) data[i] = Math.random() * 2 - 1;
    this.noise = buf;
  }

  setVolume(v: number): void {
    this.volume = v;
    if (this.master) this.master.gain.value = this.muted ? 0 : v;
  }

  setMuted(m: boolean): void {
    this.muted = m;
    if (this.master) this.master.gain.value = m ? 0 : this.volume;
  }

  play(name: SoundName, gain = 1): void {
    if (!this.ctx || !this.master || this.muted) return;
    const t = this.ctx.currentTime;
    switch (name) {
      case 'shoot':
        this.tone(520, 300, 0.09, 'square', 0.07 * gain, t);
        break;
      case 'hit':
        this.tone(240, 120, 0.08, 'square', 0.05 * gain, t);
        break;
      case 'plant':
        this.noiseBurst(0.16, 340, 0.22 * gain, t);
        this.tone(180, 90, 0.12, 'sine', 0.1 * gain, t);
        break;
      case 'sun':
        this.tone(660, 990, 0.16, 'sine', 0.12 * gain, t);
        this.tone(990, 1320, 0.2, 'sine', 0.06 * gain, t + 0.05);
        break;
      case 'select':
        this.tone(440, 520, 0.06, 'triangle', 0.09 * gain, t);
        break;
      case 'click':
        this.tone(300, 260, 0.05, 'triangle', 0.08 * gain, t);
        break;
      case 'deny':
        this.tone(180, 110, 0.16, 'sawtooth', 0.08 * gain, t);
        break;
      case 'chomp':
        this.noiseBurst(0.1, 900, 0.16 * gain, t);
        this.tone(120, 70, 0.1, 'square', 0.07 * gain, t);
        break;
      case 'explode':
        this.noiseBurst(0.55, 180, 0.5 * gain, t);
        this.tone(90, 30, 0.5, 'sine', 0.22 * gain, t);
        break;
      case 'mower':
        this.noiseBurst(0.9, 420, 0.35 * gain, t);
        this.tone(140, 90, 0.9, 'sawtooth', 0.12 * gain, t);
        break;
      case 'splash':
        this.noiseBurst(0.35, 1200, 0.24 * gain, t);
        break;
      case 'step':
        this.noiseBurst(0.075, 700 + Math.random() * 500, 0.1 * gain, t);
        this.tone(120 + Math.random() * 40, 70, 0.06, 'sine', 0.035 * gain, t);
        break;
      case 'groan':
        this.tone(110, 70, 0.6, 'sawtooth', 0.055 * gain, t);
        this.tone(96, 62, 0.7, 'triangle', 0.04 * gain, t + 0.08);
        break;
      case 'win': {
        const notes = [523, 659, 784, 1046];
        notes.forEach((n, i) => this.tone(n, n, 0.28, 'triangle', 0.12 * gain, t + i * 0.14));
        break;
      }
      case 'lose': {
        const notes = [392, 330, 262, 196];
        notes.forEach((n, i) => this.tone(n, n * 0.98, 0.34, 'sawtooth', 0.1 * gain, t + i * 0.18));
        break;
      }
    }
  }

  private tone(f0: number, f1: number, dur: number, type: OscillatorType, gain: number, at: number): void {
    if (!this.ctx || !this.master) return;
    const osc = this.ctx.createOscillator();
    const env = this.ctx.createGain();
    osc.type = type;
    osc.frequency.setValueAtTime(f0, at);
    osc.frequency.exponentialRampToValueAtTime(Math.max(20, f1), at + dur);
    env.gain.setValueAtTime(0.0001, at);
    env.gain.exponentialRampToValueAtTime(gain, at + 0.012);
    env.gain.exponentialRampToValueAtTime(0.0001, at + dur);
    osc.connect(env).connect(this.master);
    osc.start(at);
    osc.stop(at + dur + 0.02);
  }

  private noiseBurst(dur: number, cutoff: number, gain: number, at: number): void {
    if (!this.ctx || !this.master || !this.noise) return;
    const src = this.ctx.createBufferSource();
    src.buffer = this.noise;
    const filter = this.ctx.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(cutoff, at);
    filter.frequency.exponentialRampToValueAtTime(Math.max(120, cutoff * 0.35), at + dur);
    const env = this.ctx.createGain();
    env.gain.setValueAtTime(gain, at);
    env.gain.exponentialRampToValueAtTime(0.0001, at + dur);
    src.connect(filter).connect(env).connect(this.master);
    src.start(at);
    src.stop(at + dur + 0.02);
  }
}

export const audio = new AudioEngine();
