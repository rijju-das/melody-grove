const assert=require('node:assert/strict');
const {detectPitch}=require('../docs/voice-input.js');
for(const rate of [44100,48000])for(const hz of [130.81,146.83,164.81,261.63,293.66,329.63]){
  const data=Float32Array.from({length:4096},(_,i)=>.004*Math.sin(2*Math.PI*hz*i/rate)+.002*Math.sin(4*Math.PI*hz*i/rate)+.001*Math.sin(6*Math.PI*hz*i/rate));
  const detected=detectPitch(data,rate).hz;
  assert(Math.abs(1200*Math.log2(detected/hz))<8,`${hz}: ${detected}`);
}
assert.equal(detectPitch(new Float32Array(4096),48000).hz,0);
let seed=42;const noise=Float32Array.from({length:4096},()=>{seed=(1664525*seed+1013904223)>>>0;return (seed/4294967296-.5)*.3;});
assert.equal(detectPitch(noise,48000).hz,0);
console.log('PITCH PASS: two voice ranges, harmonic voices, 44.1/48 kHz, silence and noise rejection');
