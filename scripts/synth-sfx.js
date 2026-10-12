// Procedurally synthesises the app's sound effects as 16-bit mono WAVs.
// Usage: node scripts/synth-sfx.js app/assets/sfx
const fs = require('fs'), path = require('path');
const SR = 44100, out = process.argv[2] || 'app/assets/sfx';
fs.mkdirSync(out, { recursive: true });

const env = (t, a, d) => (t < a ? t / a : Math.exp(-(t - a) / d));
const note = (f, dur, { type = 'sine', a = 0.004, d = dur / 3, vol = 0.6, bend = 0, vib = 0 } = {}) => {
  const n = Math.floor(dur * SR), s = new Float32Array(n);
  let ph = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR, freq = f * Math.pow(2, (bend * t) / dur) * (1 + vib * Math.sin(2 * Math.PI * 6 * t));
    ph += (2 * Math.PI * freq) / SR;
    let v = type === 'sine' ? Math.sin(ph)
      : type === 'tri' ? (2 / Math.PI) * Math.asin(Math.sin(ph))
      : type === 'square' ? Math.sign(Math.sin(ph)) * 0.5
      : Math.random() * 2 - 1;
    // Bright bell partial.
    if (type === 'bell') v = Math.sin(ph) + 0.4 * Math.sin(ph * 2.76) * Math.exp(-t * 9) + 0.2 * Math.sin(ph * 5.4) * Math.exp(-t * 14);
    s[i] = v * env(t, a, d) * vol;
  }
  return s;
};
const mix = (len, parts) => {
  const o = new Float32Array(Math.floor(len * SR));
  for (const [at, buf] of parts) { const st = Math.floor(at * SR); for (let i = 0; i < buf.length && st + i < o.length; i++) o[st + i] += buf[i]; }
  return o;
};
const write = (name, buf) => {
  let peak = 0; for (const v of buf) peak = Math.max(peak, Math.abs(v));
  const g = peak > 0.95 ? 0.95 / peak : 1;
  const data = Buffer.alloc(buf.length * 2);
  buf.forEach((v, i) => data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v * g)) * 32767), i * 2));
  const h = Buffer.alloc(44);
  h.write('RIFF', 0); h.writeUInt32LE(36 + data.length, 4); h.write('WAVE', 8); h.write('fmt ', 12);
  h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(SR, 24);
  h.writeUInt32LE(SR * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34); h.write('data', 36); h.writeUInt32LE(data.length, 40);
  fs.writeFileSync(path.join(out, name + '.wav'), Buffer.concat([h, data]));
};
const N = (m) => 440 * Math.pow(2, (m - 69) / 12);

write('tap', note(1400, 0.05, { type: 'sine', d: 0.012, vol: 0.5, bend: -1 }));
write('pop', mix(0.14, [[0, note(520, 0.14, { d: 0.04, bend: 1.4, vol: 0.7 })], [0, note(1600, 0.03, { type: 'noise', d: 0.006, vol: 0.15 })]]));
write('select', note(N(84), 0.09, { type: 'tri', d: 0.03, vol: 0.55, bend: 0.3 }));
write('wrong', mix(0.32, [[0, note(220, 0.16, { type: 'square', d: 0.08, vol: 0.35, bend: -0.5 })], [0.13, note(165, 0.19, { type: 'square', d: 0.09, vol: 0.35, bend: -0.6 })]]));
write('success', mix(0.5, [[0, note(N(76), 0.2, { type: 'bell', d: 0.1 })], [0.08, note(N(79), 0.2, { type: 'bell', d: 0.1 })], [0.16, note(N(84), 0.34, { type: 'bell', d: 0.16 })]]));
write('star', mix(0.6, [[0, note(N(88), 0.5, { type: 'bell', d: 0.18, vol: 0.55 })], [0.05, note(N(95), 0.45, { type: 'bell', d: 0.15, vol: 0.35 })]]));
write('coin', mix(0.35, [[0, note(N(83), 0.08, { type: 'square', d: 0.05, vol: 0.3 })], [0.07, note(N(88), 0.28, { type: 'square', d: 0.1, vol: 0.3 })]]));
write('win', mix(1.6, [
  [0, note(N(72), 0.18, { type: 'bell', d: 0.1 })], [0.12, note(N(76), 0.18, { type: 'bell', d: 0.1 })],
  [0.24, note(N(79), 0.18, { type: 'bell', d: 0.1 })], [0.36, note(N(84), 0.9, { type: 'bell', d: 0.4, vib: 0.004 })],
  [0.36, note(N(76), 0.9, { type: 'tri', d: 0.4, vol: 0.3 })], [0.36, note(N(60), 0.9, { type: 'tri', d: 0.45, vol: 0.35 })],
]));
write('lose', mix(1.0, [[0, note(N(67), 0.3, { type: 'tri', d: 0.15 })], [0.25, note(N(63), 0.3, { type: 'tri', d: 0.15 })], [0.5, note(N(60), 0.5, { type: 'tri', d: 0.25, bend: -0.2 })]]));
write('whoosh', (() => { const n = note(0, 0.35, { type: 'noise', a: 0.12, d: 0.08, vol: 0.35 }); let y = 0; for (let i = 0; i < n.length; i++) { y += 0.08 * (n[i] - y); n[i] = y * 3; } return n; })());
write('merge', mix(0.22, [[0, note(330, 0.2, { d: 0.06, bend: 1.0, vol: 0.6 })], [0.02, note(660, 0.18, { type: 'tri', d: 0.05, bend: 0.8, vol: 0.3 })]]));
write('unlock', mix(0.9, [[0, note(N(79), 0.25, { type: 'bell', d: 0.1 })], [0.1, note(N(86), 0.25, { type: 'bell', d: 0.1 })], [0.2, note(N(91), 0.6, { type: 'bell', d: 0.25 })]]));
console.log('sfx written to', out);
