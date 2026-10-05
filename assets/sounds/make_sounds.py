"""Cuts the gunshot recordings into single shots for the game.

Run:  python3 assets/sounds/make_sounds.py

The CC0 recordings in src/gunshots (OpenGameArt "Gunshot Sounds") hold several shots in a
row. Each shot is found by its sharp start, cut with its natural echo tail, faded out,
normalised and saved as a mono WAV: shots/<gun>_<n>.wav. Plain Python, no extra modules.
"""
import array
import os
import wave

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCES = {  # recording -> name used in the game
    "src/gunshots/sounds/sks.wav": "rifle",
    "src/gunshots/sounds/cz.wav": "pistol",
    "src/gunshots/sounds/mosin.wav": "sniper",
    "src/gunshots/sounds/shotty.wav": "shotgun",
}
MAX_SHOTS = 6
TAIL = 1.1  # seconds kept after each shot at most
GAP = 0.3  # shots closer than this are one shot
FADE = 0.15


def read_mono(path):
    with wave.open(path, "rb") as w:
        channels, width, rate = w.getnchannels(), w.getsampwidth(), w.getframerate()
        assert width == 2, "16-bit WAV expected"
        data = array.array("h", w.readframes(w.getnframes()))
    if channels == 2:
        data = array.array("h", [(data[i] + data[i + 1]) // 2 for i in range(0, len(data) - 1, 2)])
    return data, rate


def find_shots(samples, rate):
    peak = max(abs(s) for s in samples) or 1
    threshold = peak * 0.6  # bolt clicks between shots stay below this
    onsets, last = [], -10 * rate
    for i, s in enumerate(samples):
        if abs(s) >= threshold and i - last > GAP * rate:
            onsets.append(i)
            last = i
        elif abs(s) >= threshold:
            last = i  # still inside the same shot
    return onsets


def cut(samples, rate, start, end):
    start = max(0, start - int(0.004 * rate))
    piece = samples[start:end]
    fade = int(FADE * rate)
    out = array.array("h")
    peak = max((abs(s) for s in piece), default=1) or 1
    gain = 0.95 * 32767 / peak
    for i, s in enumerate(piece):
        k = 1.0
        if i > len(piece) - fade:
            k = (len(piece) - i) / fade
        out.append(int(max(-32767, min(32767, s * gain * k))))
    return out


def main():
    os.makedirs(os.path.join(HERE, "shots"), exist_ok=True)
    for source, name in SOURCES.items():
        samples, rate = read_mono(os.path.join(HERE, source))
        onsets = find_shots(samples, rate)[:MAX_SHOTS]
        for n, onset in enumerate(onsets):
            nxt = onsets[n + 1] if n + 1 < len(onsets) else len(samples)
            end = min(nxt - int(0.02 * rate), onset + int(TAIL * rate))
            shot = cut(samples, rate, onset, end)
            with wave.open(os.path.join(HERE, "shots", "%s_%d.wav" % (name, n)), "wb") as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(rate)
                w.writeframes(shot.tobytes())
        print("%s: %d shots from %s" % (name, len(onsets), source))


if __name__ == "__main__":
    main()
