extends SceneTree
## Renders the browser's procedural sound effects (dev/src/js/03-audio.js, sfx()) to WAV files in res://sfx/.
## Run from the repo root:  godot --headless --path godot --script res://tools/render_sfx.gd
## Each recipe is the browser's own list of layers, rebuilt with the Web Audio formulas:
##   envG  exponential attack to peak, then exponential decay to 0.0001
##   osc   oscillator (sine/square/sawtooth/triangle), frequency ramps exponentially f -> fEnd over dur
##   nz    white noise through a biquad (lowpass/highpass with Q in dB, bandpass with plain Q), cutoff ramps the same way

const RATE := 44100
const HEADROOM := 0.5   # stored at half level; PalAudio plays them back x2 (x 0.55 master x volume), as the browser mixes

# ["o", start, dur, type, f, peak, fEnd]   ["n", start, dur, filter, f, q, peak, fEnd]
const RECIPES := {
	"ar": [["n", 0, .07, "highpass", 900, .7, .5, 0], ["o", 0, .08, "triangle", 150, .45, 50]],
	"rifle": [["n", 0, .09, "bandpass", 1300, .8, .5, 0], ["o", 0, .1, "square", 110, .16, 45]],
	"smg": [["n", 0, .05, "highpass", 1400, .7, .35, 0], ["o", 0, .05, "square", 180, .1, 70]],
	"shotgun": [["n", 0, .16, "lowpass", 2600, .6, .95, 300], ["o", 0, .2, "sine", 85, .85, 32], ["n", 0, .05, "highpass", 1600, .8, .45, 0]],
	"hit0": [["n", 0, .08, "lowpass", 520, 1, .7, 0], ["o", 0, .07, "sine", 190, .45, 85]],
	"hit1": [["n", 0, .12, "bandpass", 2300, 1.3, .55, 800]],
	"hit2": [["o", 0, .55, "sine", 1230, .16, 0], ["o", 0, .42, "sine", 1870, .09, 0], ["o", 0, .3, "sine", 2930, .05, 0], ["n", 0, .03, "highpass", 4200, .4, .3, 0]],
	"boom": [["n", 0, .9, "lowpass", 1900, .7, 1, 110], ["o", 0, .65, "sine", 72, .9, 28]],
	"bigboom": [["n", 0, 1.3, "lowpass", 1500, .6, 1, 70], ["o", 0, .9, "sine", 60, 1, 22]],
	"bottle": [["n", 0, .08, "highpass", 4200, 1, .4, 0], ["n", .04, .5, "bandpass", 800, .7, .4, 300]],
	"shieldhit": [["o", 0, .25, "square", 880, .06, 700], ["o", 0, .2, "sine", 1320, .06, 0], ["n", 0, .04, "highpass", 3000, 1, .25, 0]],
	"medpulse": [["o", 0, .3, "sine", 660, .06, 990], ["o", .08, .3, "sine", 880, .04, 1320]],
	"mark": [["o", 0, .08, "square", 2400, .05, 0], ["o", .12, .08, "square", 2400, .05, 0]],
	"collapse": [["n", 0, .55, "lowpass", 950, .6, .75, 140], ["o", 0, .3, "sine", 90, .3, 40]],
	"place0": [["o", 0, .06, "sine", 230, .5, 120], ["o", .09, .06, "sine", 210, .45, 110], ["n", 0, .05, "lowpass", 700, 1, .25, 0]],
	"place1": [["n", 0, .28, "bandpass", 650, 2, .4, 380], ["o", .2, .08, "sine", 140, .3, 70]],
	"place2": [["n", 0, .7, "highpass", 3200, .5, .28, 0], ["o", 0, .7, "sawtooth", 96, .06, 0], ["o", .62, .4, "sine", 1100, .08, 0]],
	"gather": [["o", 0, .05, "triangle", 570, .1, 0]],
	"siren": [["o", 0, 1.8, "sine", 260, .14, 640], ["o", 0, 1.8, "sine", 263, .1, 646]],
	"core": [["o", 0, .32, "sine", 82, .6, 38], ["n", 0, .1, "lowpass", 300, 1, .3, 0]],
	"hurt": [["o", 0, .13, "square", 210, .12, 90]],
	"drop": [["n", 0, .16, "lowpass", 420, 1, .4, 0]],
	"lob": [["o", 0, .12, "triangle", 620, .1, 300]],
	"plant": [["o", 0, .05, "square", 1400, .12, 0], ["o", .12, .05, "square", 1400, .12, 0]],
	"beep": [["o", 0, .04, "square", 1800, .08, 0]],
	"revive": [["o", 0, .15, "triangle", 330, .12, 0], ["o", .07, .15, "triangle", 440, .12, 0], ["o", .14, .15, "triangle", 550, .12, 0]],
	"restock": [["o", 0, .08, "triangle", 700, .12, 0], ["o", .08, .12, "triangle", 940, .12, 0]],
	"deny": [["o", 0, .1, "square", 150, .08, 0]],
	"medic": [["o", 0, .16, "sine", 523, .13, 0], ["o", .05, .16, "sine", 659, .13, 0], ["o", .1, .16, "sine", 784, .13, 0], ["o", .15, .16, "sine", 1046, .13, 0]],
	"horn": [["o", 0, 1.1, "sawtooth", 73, .16, 68], ["o", 0, 1.1, "sawtooth", 110, .1, 104], ["o", .4, .8, "sawtooth", 98, .08, 92], ["n", 0, .9, "lowpass", 300, .5, .25, 0]],
	"rocket": [["n", 0, .5, "bandpass", 900, .7, .6, 300], ["o", 0, .35, "sawtooth", 160, .12, 60], ["n", 0, .08, "lowpass", 1200, .8, .7, 0]],
	"lock": [["o", 0, .06, "square", 1560, .09, 0], ["o", .1, .06, "square", 1560, .09, 0], ["o", .2, .1, "square", 2080, .1, 0]],
	"slash": [["n", 0, .18, "bandpass", 3200, 1.5, .55, 900], ["o", .02, .25, "sine", 1900, .08, 1200]],
	"charge": [["o", 0, .8, "sawtooth", 220, .08, 900], ["o", 0, .8, "sine", 440, .07, 1800]],
	"zap": [["n", 0, .35, "highpass", 2500, .6, .9, 0], ["o", 0, .3, "square", 95, .25, 40], ["n", 0, .04, "bandpass", 4200, 3, .5, 0], ["n", .04, .04, "bandpass", 4200, 3, .5, 0], ["n", .09, .04, "bandpass", 4200, 3, .5, 0], ["n", .15, .04, "bandpass", 4200, 3, .5, 0]],
	"win": [["o", 0, .5, "triangle", 392, .14, 0], ["o", .12, .5, "triangle", 494, .14, 0], ["o", .24, .5, "triangle", 587, .14, 0], ["o", .36, .5, "triangle", 784, .14, 0]],
	"lose": [["o", 0, .6, "sawtooth", 220, .08, 0], ["o", .2, .6, "sawtooth", 196, .08, 0], ["o", .4, .6, "sawtooth", 165, .08, 0]],
}

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 1   # the noise is fixed once rendered; the browser starts each play at a random point in its noise buffer
	var dir := "res://sfx"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	for name in RECIPES:
		var layers: Array = RECIPES[name]
		var end := 0.0
		for L in layers:
			end = maxf(end, L[1] + L[2] + 0.05)
		var n := int(ceil(end * RATE))
		var buf := PackedFloat32Array()
		buf.resize(n)
		for L in layers:
			if L[0] == "o":
				_osc(buf, L[1], L[2], L[3], L[4], L[5], L[6])
			else:
				_nz(buf, L[1], L[2], L[3], L[4], L[5], L[6], L[7])
		var pcm := PackedByteArray()
		pcm.resize(n * 2)
		for i in n:
			pcm.encode_s16(i * 2, int(clampf(buf[i] * HEADROOM, -1.0, 1.0) * 32767.0))
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = RATE
		w.stereo = false
		w.data = pcm
		var path := "%s/%s.wav" % [dir, name]
		w.save_to_wav(ProjectSettings.globalize_path(path))
		print("%-10s %.2f s" % [name, end])
	quit()


## envG: 0.0001 -> peak (exponential, over a) -> 0.0001 (exponential, over d)
func _env(t: float, a: float, d: float, peak: float) -> float:
	var pk := maxf(peak, 0.0002)
	if t < 0:
		return 0.0
	if t < a:
		return 0.0001 * pow(pk / 0.0001, t / a)
	if t < a + d:
		return pk * pow(0.0001 / pk, (t - a) / d)
	return 0.0001


func _freq(t: float, dur: float, f: float, f_end: float) -> float:
	if f_end <= 0 or t >= dur:
		return f if f_end <= 0 else f_end
	return f * pow(f_end / f, t / dur)


func _osc(buf: PackedFloat32Array, t0: float, dur: float, type: String, f: float, peak: float, f_end: float) -> void:
	var i0 := int(t0 * RATE)
	var n := int((dur + 0.05) * RATE)
	var ph := 0.0
	for s in n:
		var t := float(s) / RATE
		ph = fmod(ph + _freq(t, dur, f, f_end) / RATE, 1.0)
		var v: float
		match type:
			"sine":
				v = sin(TAU * ph)
			"square":
				v = 1.0 if ph < 0.5 else -1.0
			"sawtooth":
				v = 2.0 * ph - 1.0
			_:
				v = 1.0 - 4.0 * absf(ph - 0.5)   # triangle
		if i0 + s < buf.size():
			buf[i0 + s] += v * _env(t, 0.004, dur, peak)


func _nz(buf: PackedFloat32Array, t0: float, dur: float, type: String, f: float, q: float, peak: float, f_end: float) -> void:
	var i0 := int(t0 * RATE)
	var n := int((dur + 0.05) * RATE)
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for s in n:
		var t := float(s) / RATE
		var fc := minf(_freq(t, dur, f, f_end), RATE * 0.49)
		var w0 := TAU * fc / RATE
		var cw := cos(w0)
		var b0: float
		var b1: float
		var b2: float
		var alpha: float
		if type == "bandpass":
			alpha = sin(w0) / (2.0 * q)
			b0 = alpha
			b1 = 0.0
			b2 = -alpha
		else:
			alpha = sin(w0) / (2.0 * pow(10.0, q / 20.0))   # Web Audio: lowpass/highpass Q is in dB
			if type == "lowpass":
				b0 = (1.0 - cw) / 2.0
				b1 = 1.0 - cw
			else:
				b0 = (1.0 + cw) / 2.0
				b1 = -(1.0 + cw)
			b2 = b0
		var a0 := 1.0 + alpha
		var a1 := -2.0 * cw
		var a2 := 1.0 - alpha
		var x := rng.randf() * 2.0 - 1.0
		var y := (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		if i0 + s < buf.size():
			buf[i0 + s] += y * _env(t, 0.003, dur, peak)
