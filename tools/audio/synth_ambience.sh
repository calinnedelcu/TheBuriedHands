#!/bin/sh
# Synthesizes the ambience beds and tension layer with ffmpeg (no samples):
# seamless 48 s loops (the last 4 s crossfade into the start), mono WAV,
# imported with QOA compression and forward looping.
# Usage: tools/audio/synth_ambience.sh
set -e
cd "$(dirname "$0")/../.."
OUT=audio/ambience
mkdir -p "$OUT"
SR=32000

# loop <input filtergraph label producing 52 s> <out file>
make_loop() {
	ffmpeg -hide_banner -loglevel error -y -filter_complex "$1,asplit=2[a][b];[a]atrim=4:52,asetpts=PTS-STARTPTS[body];[b]atrim=0:4,asetpts=PTS-STARTPTS[head];[body][head]acrossfade=d=4:c1=qsin:c2=qsin,aresample=$SR,aformat=channel_layouts=mono" -c:a pcm_s16le "$2"
}

# The tomb: a deep rumble, slow breaths of air, a faint low tone.
make_loop "anoisesrc=color=brown:amplitude=0.9:d=52:r=$SR,lowpass=f=130,lowpass=f=130,volume='0.75+0.25*sin(2*PI*t/24)':eval=frame[r];\
anoisesrc=color=pink:amplitude=0.35:d=52:r=$SR:seed=7,bandpass=f=650:width_type=h:w=700,volume='0.12+0.1*sin(2*PI*t/16+1.3)':eval=frame[w];\
sine=f=41.2:d=52:r=$SR,volume=0.035[s];\
[r][w][s]amix=inputs=3:normalize=0,highpass=f=22,volume=0.9" "$OUT/tomb_bed.wav"

# The Mercury Hall: a thin metallic shimmer over a cold hiss and a low hum.
make_loop "aevalsrc=exprs='0.018*sin(2*PI*1760*t)*(0.6+0.4*sin(2*PI*t/12))+0.014*sin(2*PI*1767*t)+0.01*sin(2*PI*2637*t)*(0.5+0.5*sin(2*PI*t/8+2))':d=52:s=$SR[sh];\
anoisesrc=color=white:amplitude=0.12:d=52:r=$SR:seed=11,bandpass=f=4200:width_type=h:w=3000,volume='0.35+0.2*sin(2*PI*t/6)':eval=frame[h];\
sine=f=55:d=52:r=$SR,volume=0.05[l];\
anoisesrc=color=brown:amplitude=0.5:d=52:r=$SR:seed=3,lowpass=f=110,volume=0.5[r];\
[sh][h][l][r]amix=inputs=4:normalize=0,highpass=f=22" "$OUT/mercury_hum.wav"

# Being hunted: a heartbeat at 70 bpm (56 beats in 48 s) over two low tones
# that beat against each other.
make_loop "aevalsrc=exprs='0.8*exp(-mod(t,60/70)/0.045)*sin(2*PI*52*mod(t,60/70))+0.5*exp(-mod(t-0.2,60/70)/0.06)*sin(2*PI*44*mod(t-0.2,60/70))':d=52:s=$SR,lowpass=f=180[hb];\
aevalsrc=exprs='0.07*sin(2*PI*73.4*t)+0.06*sin(2*PI*77.8*t)':d=52:s=$SR[dr];\
[hb][dr]amix=inputs=2:normalize=0,highpass=f=25" "$OUT/tension_heartbeat.wav"

# Spotted: a dull drum hit with a falling pitch and a breath of noise (one-shot).
ffmpeg -hide_banner -loglevel error -y -filter_complex "aevalsrc=exprs='0.9*exp(-t/0.35)*sin(2*PI*(110*t-38*t*t))':d=2.2:s=$SR[hit];\
anoisesrc=color=pink:amplitude=0.5:d=2.2:r=$SR,bandpass=f=900:width_type=h:w=1200,afade=t=in:d=0.02,afade=t=out:st=0.05:d=0.9[n];\
[hit][n]amix=inputs=2:normalize=0,aecho=0.6:0.5:180:0.25,highpass=f=30,aformat=channel_layouts=mono" -c:a pcm_s16le "audio/sfx/stingers_spotted.wav"
mkdir -p audio/sfx/stingers && mv audio/sfx/stingers_spotted.wav audio/sfx/stingers/spotted.wav
echo "done"
