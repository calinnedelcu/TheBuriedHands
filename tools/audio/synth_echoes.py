#!/usr/bin/env python3
"""Synthesizes the far-off sounds of the others trapped in the tomb (no samples):
fists and tools pounding on stone, a bronze gate struck again and again, and
the mountain settling. Heard after the sealing, from somewhere else in the
dark. Mono WAV, imported with QOA compression.

    python3 tools/audio/synth_echoes.py
"""
import os, random, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "audio", "ambience", "echoes")
SR = 32000


def render(expr, seconds, filters, name):
	path = os.path.join(OUT, name)
	subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-f", "lavfi",
			"-i", "aevalsrc=exprs='%s':s=%d:d=%.2f" % (expr, SR, seconds),
			"-af", filters + ",aformat=channel_layouts=mono:sample_fmts=s16",
			"-c:a", "pcm_s16le", path], check=True)
	print("wrote", path)


def knock(at, weight):
	"""A fist or a stone on rock: a low thud with a little grit."""
	t = "(t-%.3f)" % at
	return ("gte(t,{a})*{w}*(sin(2*PI*68*{t})*exp(-16*{t})+0.5*sin(2*PI*131*{t})*exp(-28*{t})"
			"+0.35*(2*random(0)-1)*exp(-55*{t}))").format(a="%.3f" % at, w="%.2f" % weight, t=t)


def clang(at, weight):
	"""A tool on the bronze gate: inharmonic partials, a long ring."""
	t = "(t-%.3f)" % at
	parts = [(176, 1.0, 2.2), (403, 0.6, 3.1), (689, 0.45, 4.6), (1013, 0.3, 6.5), (1391, 0.18, 9.0)]
	ring = "+".join("%.2f*sin(2*PI*%d*%s)*exp(-%.1f*%s)" % (g, f, t, d, t) for f, g, d in parts)
	return "gte(t,%.3f)*%.2f*(%s+0.4*(2*random(0)-1)*exp(-70*%s))" % (at, weight, ring, t)


def pounding(seed):
	rng = random.Random(seed)
	hits = []
	t = 0.25
	for burst in range(rng.randint(2, 3)):
		for i in range(rng.randint(3, 6)):
			hits.append(knock(t, rng.uniform(0.7, 1.0)))
			t += rng.uniform(0.42, 0.62)
		t += rng.uniform(1.0, 2.2)
	return "+".join(hits), t + 1.5


def striking(seed):
	rng = random.Random(seed)
	hits = []
	t = 0.25
	for i in range(rng.randint(3, 5)):
		hits.append(clang(t, rng.uniform(0.6, 1.0)))
		t += rng.uniform(0.9, 1.6)
	return "+".join(hits), t + 3.0


os.makedirs(OUT, exist_ok=True)
# Far away, through rock: little but the lows, a stone room's echoes.
FAR = "lowpass=f=420,lowpass=f=420,aecho=0.8:0.6:90|170:0.35|0.2,volume=0.9,alimiter=limit=0.6"
FAR_METAL = "lowpass=f=900,lowpass=f=1200,aecho=0.8:0.7:110|230:0.4|0.25,volume=0.5,alimiter=limit=0.6"
for k in range(4):
	expr, seconds = pounding(100 + k)
	render(expr, seconds, FAR, "pounding_%d.wav" % k)
for k in range(2):
	expr, seconds = striking(200 + k)
	render(expr, seconds, FAR_METAL, "gate_struck_%d.wav" % k)
# The mountain settling: a long low groan of stone.
render("0.6*sin(2*PI*(38+6*sin(2*PI*t/5))*t)*sin(PI*t/7)+0.5*(2*random(0)-1)*sin(PI*t/7)", 7.0,
		"lowpass=f=160,lowpass=f=160,aecho=0.8:0.6:120:0.3,volume=1.2,alimiter=limit=0.6", "settling.wav")
