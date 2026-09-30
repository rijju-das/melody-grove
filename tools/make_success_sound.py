"""Create an original short C-major victory jingle with synthesized applause."""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
samples = [0.0] * int(RATE * 3.2)
rng = random.Random(42)

def bell(start, midi, duration, gain):
    frequency = 440 * 2 ** ((midi - 69) / 12)
    for i in range(int(duration * RATE)):
        t = i / RATE
        envelope = min(1, t / .006) * math.exp(-4.5 * t / duration) * min(1, (duration - t) / .06)
        phase = 2 * math.pi * frequency * t
        tone = math.sin(phase) + .22 * math.sin(2 * phase) + .07 * math.sin(3 * phase)
        index = int(start * RATE) + i
        if index < len(samples): samples[index] += gain * envelope * tone

for start, note in [(0, 72), (.16, 76), (.32, 79), (.52, 84)]:
    bell(start, note, .8, .19)
for note in [60, 64, 67, 72, 79, 84]:
    bell(.85, note, 1.65, .075)
bell(1.48, 88, 1.1, .075)

# Several staggered hands: short noise bursts with a soft room tail.
for _ in range(36):
    start = rng.uniform(.95, 2.55)
    gain = rng.uniform(.026, .052)
    previous = 0.0
    for i in range(int(.12 * RATE)):
        t = i / RATE
        noise = rng.uniform(-1, 1)
        bright = noise - .7 * previous
        previous = noise
        attack = math.exp(-t * 75) + .45 * math.exp(-abs(t - .014) * 180)
        index = int(start * RATE) + i
        samples[index] += gain * bright * attack

peak = max(abs(value) for value in samples)
output = Path(__file__).resolve().parent.parent / 'game-source' / 'success.wav'
with wave.open(str(output), 'wb') as sound:
    sound.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
    sound.writeframes(b''.join(struct.pack('<h', round(value / peak * .75 * 32767)) for value in samples))
print(f'Created {output.name}: 3.2 seconds, original jingle and applause, peak -2.5 dBFS')
