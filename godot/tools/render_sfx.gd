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
	"sniper": [["n", 0, .2, "bandpass", 700, .6, .8, 200], ["o", 0, .25, "sine", 95, .7, 35], ["n", .05, .4, "lowpass", 400, .5, .2, 0]],
	"rack": [["n", 0, .035, "highpass", 2600, 1.2, .35, 0], ["o", 0, .03, "square", 1250, .07, 700], ["n", .13, .03, "bandpass", 3400, 2, .4, 0], ["o", .13, .04, "square", 1650, .08, 900], ["o", .2, .05, "triangle", 380, .1, 200]],
	"pump": [["n", 0, .06, "bandpass", 1500, 1.4, .4, 700], ["o", 0, .05, "square", 260, .07, 160], ["n", .12, .05, "bandpass", 2100, 1.6, .45, 1100], ["o", .12, .05, "square", 330, .08, 200]],
	"shellin": [["n", 0, .03, "bandpass", 2800, 2, .3, 0], ["o", 0, .035, "triangle", 900, .08, 600]],
	"dry": [["o", 0, .03, "square", 2200, .06, 0]],
	"rumble": [["o", 0, .7, "sine", 42, .35, 36], ["n", 0, .7, "lowpass", 180, 1, .3, 90]],
	"drill": [["o", 0, .6, "sawtooth", 70, .14, 55], ["n", 0, .6, "bandpass", 900, 1.5, .25, 700]],
	"rockfall": [["n", 0, .25, "lowpass", 700, .8, .45, 150], ["n", .07, .25, "lowpass", 640, .8, .45, 150], ["n", .14, .25, "lowpass", 580, .8, .45, 150], ["n", .21, .25, "lowpass", 520, .8, .45, 150], ["n", .28, .25, "lowpass", 460, .8, .45, 150], ["n", .35, .25, "lowpass", 400, .8, .45, 150], ["o", 0, .8, "sine", 55, .4, 30]],
	"winterwarn": [["n", 0, .65, "highpass", 2800, .8, .12, 1100], ["o", 0, .3, "triangle", 880, .09, 633.6], ["o", .17, .3, "triangle", 660, .09, 475.2], ["o", .34, .3, "triangle", 440, .09, 316.8]],
	"splash": [["n", 0, .45, "lowpass", 1400, .7, .55, 250], ["n", .05, .2, "highpass", 2600, .8, .2, 0]],
	"harpoon": [["n", 0, .12, "bandpass", 1800, 1.2, .5, 600], ["o", 0, .18, "sawtooth", 180, .12, 60]],
	"chain": [["n", 0, .03, "bandpass", 3600, 4, .12, 0], ["n", .05, .03, "bandpass", 3800, 4, .12, 0], ["n", .1, .03, "bandpass", 4000, 4, .12, 0], ["n", .15, .03, "bandpass", 4200, 4, .12, 0], ["n", .2, .03, "bandpass", 4400, 4, .12, 0]],
	"flood": [["n", 0, 1.4, "lowpass", 600, .6, .35, 300], ["o", 0, 1.4, "sine", 90, .1, 70]],
	"win": [["o", 0, .5, "triangle", 392, .14, 0], ["o", .12, .5, "triangle", 494, .14, 0], ["o", .24, .5, "triangle", 587, .14, 0], ["o", .36, .5, "triangle", 784, .14, 0]],
	"lose": [["o", 0, .6, "sawtooth", 220, .08, 0], ["o", .2, .6, "sawtooth", 196, .08, 0], ["o", .4, .6, "sawtooth", 165, .08, 0]],
	"ts_gold": [["o", 0, 0.12, "sine", 2350, 0.035, 0], ["o", 0.03, 0.12, "sine", 3140, 0.025, 0]],
	"ts_plasma": [["o", 0, 0.1, "square", 190, 0.035, 95], ["n", 0, 0.08, "bandpass", 3200, 4, 0.08, 0]],
	"ts_rainbow": [["o", 0, 0.06, "sine", 1320, 0.03, 0], ["o", 0.025, 0.06, "sine", 1660, 0.03, 0], ["o", 0.05, 0.06, "sine", 1980, 0.03, 0]],
	"ts_grad": [["o", 0, 0.1, "sine", 620, 0.03, 940]],
	"ts_aurora": [["o", 0, 0.2, "sine", 880, 0.03, 1100], ["o", 0, 0.2, "sine", 886, 0.025, 1108]],
	"ts_star": [["o", 0, 0.08, "sine", 2600, 0.035, 0], ["o", 0.05, 0.08, "sine", 3300, 0.025, 0]],
	"ts_comet": [["n", 0, 0.18, "bandpass", 2400, 2, 0.07, 700]],
	"ts_neon": [["o", 0, 0.06, "square", 880, 0.025, 0], ["o", 0.035, 0.05, "square", 1320, 0.02, 0]],
	"ts_cosmic": [["o", 0, 0.22, "sine", 220, 0.04, 440], ["o", 0, 0.22, "triangle", 330, 0.02, 660]],
	"ts_rock": [["n", 0, 0.07, "lowpass", 500, 1, 0.08, 0], ["o", 0, 0.06, "triangle", 110, 0.04, 70]],
	"ts_solar": [["n", 0, 0.14, "lowpass", 900, 0.7, 0.07, 300], ["o", 0, 0.1, "sawtooth", 140, 0.02, 90]],
	"ts_glitch": [["o", 0, 0.018, "square", 640, 0.03, 0], ["o", 0.02, 0.018, "square", 1600, 0.03, 0], ["o", 0.04, 0.018, "square", 1120, 0.03, 0]],
	"ts_galaxy": [["o", 0, 0.25, "sine", 523, 0.022, 785], ["o", 0, 0.25, "sine", 659, 0.022, 989], ["o", 0, 0.25, "sine", 784, 0.022, 1176]],
	"ts_void": [["o", 0, 0.24, "sine", 320, 0.05, 55], ["n", 0, 0.12, "lowpass", 260, 1, 0.05, 0]],
	"ts_grainbow": [["o", 0, 0.1, "sine", 1568, 0.03, 0], ["o", 0.03, 0.1, "sine", 1976, 0.03, 0], ["o", 0.06, 0.1, "sine", 2349, 0.03, 0], ["o", 0.09, 0.1, "sine", 3136, 0.03, 0], ["n", 0, 0.1, "highpass", 6000, 0.5, 0.03, 0]],
	"kx_sparks": [["n", 0, 0.12, "highpass", 3000, 0.8, 0.12, 0]],
	"kx_smoke": [["n", 0, 0.3, "lowpass", 500, 0.6, 0.1, 200]],
	"kx_confetti": [["n", 0, 0.05, "bandpass", 1800, 1, 0.2, 0], ["o", 0.04, 0.08, "triangle", 1046, 0.05, 0], ["o", 0.09, 0.08, "triangle", 1318, 0.05, 0], ["o", 0.14, 0.08, "triangle", 1568, 0.05, 0]],
	"kx_embers": [["n", 0, 0.35, "bandpass", 700, 0.7, 0.1, 300]],
	"kx_glint": [["o", 0, 0.3, "sine", 2093, 0.05, 0], ["o", 0.06, 0.3, "sine", 2637, 0.04, 0]],
	"kx_bats": [["n", 0, 0.04, "bandpass", 2600, 3, 0.08, 0], ["o", 0, 0.05, "sine", 3200, 0.025, 0], ["n", 0.045, 0.04, "bandpass", 2900, 3, 0.08, 0], ["o", 0.05, 0.05, "sine", 3020, 0.025, 0], ["n", 0.09, 0.04, "bandpass", 3200, 3, 0.08, 0], ["o", 0.1, 0.05, "sine", 2840, 0.025, 0], ["n", 0.135, 0.04, "bandpass", 3500, 3, 0.08, 0], ["o", 0.15, 0.05, "sine", 2660, 0.025, 0], ["n", 0.18, 0.04, "bandpass", 3800, 3, 0.08, 0], ["o", 0.2, 0.05, "sine", 2480, 0.025, 0]],
	"kx_spider": [["o", 0, 0.5, "sawtooth", 220, 0.03, 110], ["n", 0.45, 0.08, "lowpass", 400, 0.7, 0.12, 0]],
	"kx_souls": [["o", 0, 0.9, "sine", 330, 0.05, 660], ["o", 0.08, 0.9, "sine", 392, 0.035, 784], ["n", 0, 0.6, "bandpass", 900, 1.4, 0.05, 1800]],
	"kx_rocketburst": [["n", 0, 0.45, "lowpass", 900, 0.6, 0.16, 120], ["o", 0, 0.3, "sine", 90, 0.1, 40]],
	"kx_reticle": [["o", 0, 0.03, "square", 1200, 0.03, 0], ["o", 0.05, 0.25, "sine", 1760, 0.04, 0], ["o", 0.05, 0.25, "sine", 2640, 0.02, 0]],
	"kx_frag": [["n", 0, 0.1, "highpass", 2500, 0.7, 0.14, 0], ["n", 0, 0.35, "lowpass", 700, 0.7, 0.12, 160], ["n", 0.08, 0.03, "bandpass", 3500, 4, 0.05, 0], ["n", 0.13, 0.03, "bandpass", 3900, 4, 0.05, 0], ["n", 0.18, 0.03, "bandpass", 4300, 4, 0.05, 0], ["n", 0.23, 0.03, "bandpass", 4700, 4, 0.05, 0]],
	"kx_hellportal": [["o", 0, 0.8, "sawtooth", 70, 0.07, 40], ["n", 0, 0.7, "lowpass", 400, 0.8, 0.12, 120], ["n", 0.75, 0.12, "lowpass", 900, 0.6, 0.16, 120]],
	"kx_orbital": [["o", 0, 0.35, "sine", 1400, 0.04, 300], ["n", 0.3, 0.5, "lowpass", 700, 0.7, 0.16, 90], ["o", 0.3, 0.4, "sine", 60, 0.1, 30]],
	"kx_cinder": [["n", 0, 0.03, "bandpass", 3390, 3, 0.07, 0], ["n", 0.04, 0.03, "bandpass", 2074, 3, 0.07, 0], ["n", 0.08, 0.03, "bandpass", 3284, 3, 0.07, 0], ["n", 0.12, 0.03, "bandpass", 2541, 3, 0.07, 0], ["n", 0.16, 0.03, "bandpass", 2080, 3, 0.07, 0], ["n", 0, 0.3, "lowpass", 600, 0.6, 0.06, 0]],
	"kx_tealslash": [["n", 0, 0.16, "bandpass", 3200, 1.4, 0.12, 6000], ["o", 0, 0.2, "sine", 1320, 0.03, 2640]],
	"kx_ashbrand": [["n", 0, 0.5, "highpass", 2800, 0.6, 0.1, 1200], ["o", 0, 0.3, "triangle", 180, 0.04, 90]],
	"kx_demonclaw": [["o", 0, 0.5, "sawtooth", 55, 0.08, 35], ["n", 0.1, 0.3, "bandpass", 900, 1.2, 0.1, 300]],
	"kx_salvage": [["o", 0, 0.09, "triangle", 1318, 0.04, 0], ["o", 0.06, 0.09, "triangle", 1760, 0.04, 0], ["o", 0.12, 0.09, "triangle", 1568, 0.04, 0], ["o", 0.18, 0.09, "triangle", 2093, 0.04, 0]],
	"kx_bolt": [["n", 0, 0.12, "highpass", 3500, 0.6, 0.14, 0], ["o", 0, 0.1, "square", 80, 0.06, 40]],
	"kx_skull": [["o", 0, 0.4, "triangle", 196, 0.06, 147], ["o", 0, 0.4, "triangle", 233, 0.04, 175]],
	"kx_pixel": [["o", 0, 0.05, "square", 523, 0.04, 0], ["o", 0.04, 0.05, "square", 784, 0.04, 0], ["o", 0.08, 0.05, "square", 1046, 0.04, 0], ["o", 0.12, 0.05, "square", 1568, 0.04, 0]],
	"kx_frost": [["n", 0, 0.12, "highpass", 5000, 1, 0.14, 0], ["o", 0, 0.25, "sine", 3520, 0.03, 0]],
	"kx_gradburst": [["o", 0, 0.3, "sine", 400, 0.05, 1200], ["o", 0, 0.3, "triangle", 600, 0.03, 1800]],
	"kx_sunburst": [["o", 0, 0.3, "sine", 500, 0.05, 1400], ["n", 0, 0.1, "bandpass", 1500, 1, 0.08, 0]],
	"kx_toxic": [["o", 0, 0.05, "sine", 321, 0.05, 160], ["o", 0.05, 0.05, "sine", 595, 0.05, 160], ["o", 0.1, 0.05, "sine", 592, 0.05, 160], ["o", 0.15, 0.05, "sine", 459, 0.05, 160]],
	"kx_supernova": [["n", 0, 0.5, "lowpass", 1200, 0.6, 0.18, 150], ["o", 0.05, 0.4, "sine", 784, 0.035, 0], ["o", 0.11, 0.4, "sine", 1175, 0.035, 0], ["o", 0.17, 0.4, "sine", 1568, 0.035, 0]],
	"kx_glitchout": [["o", 0, 0.02, "square", 740, 0.04, 0], ["o", 0.025, 0.02, "square", 920, 0.04, 0], ["o", 0.05, 0.02, "square", 920, 0.04, 0], ["o", 0.075, 0.02, "square", 1280, 0.04, 0], ["o", 0.1, 0.02, "square", 1280, 0.04, 0], ["o", 0.125, 0.02, "square", 740, 0.04, 0]],
	"kx_singularity": [["o", 0, 0.35, "sine", 900, 0.06, 60], ["n", 0.3, 0.15, "lowpass", 800, 0.7, 0.15, 0]],
	"kx_shockwave": [["o", 0, 0.3, "sine", 70, 0.12, 35], ["o", 0, 0.2, "sawtooth", 880, 0.03, 220], ["n", 0, 0.08, "bandpass", 2500, 2, 0.08, 0]],
	"kx_bubbles": [["o", 0, 0.07, "sine", 628, 0.05, 1400], ["o", 0.055, 0.07, "sine", 831, 0.05, 1520], ["o", 0.11, 0.07, "sine", 982, 0.05, 1640], ["o", 0.165, 0.07, "sine", 1169, 0.05, 1760], ["o", 0.22, 0.07, "sine", 1326, 0.05, 1880], ["o", 0.275, 0.07, "sine", 1545, 0.05, 2000], ["o", 0.34, 0.35, "sine", 1568, 0.04, 0], ["o", 0.41, 0.35, "sine", 2093, 0.04, 0], ["o", 0.48, 0.35, "sine", 2637, 0.04, 0]],
	"tick_c": [["n", 0, .012, "highpass", 5200, .8, .14, 0], ["o", 0, .05, "sine", 880, .045, 0]],
	"tick_r": [["n", 0, .012, "highpass", 5200, .8, .14, 0], ["o", 0, .05, "sine", 1040, .045, 0]],
	"tick_e": [["n", 0, .012, "highpass", 5200, .8, .14, 0], ["o", 0, .05, "sine", 1240, .045, 0]],
	"tick_l": [["n", 0, .012, "highpass", 5200, .8, .14, 0], ["o", 0, .05, "sine", 1480, .045, 0]],
	"tick_g": [["n", 0, .012, "highpass", 5200, .8, .14, 0], ["o", 0, .05, "sine", 1760, .045, 0]],
	"tick_u": [["n", 0, .012, "highpass", 5200, .8, .14, 0], ["o", 0, .05, "sine", 2093, .045, 0]],
}

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 1   # the noise is fixed once rendered; the browser starts each play at a random point in its noise buffer
	var dir := "res://sfx"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var all := RECIPES.duplicate()
	all.merge(_casino())   # after the others, so their noise (one stream for every recipe, in order) stays the same
	for name in all:
		var layers: Array = all[name]
		var end := 0.0
		for L in layers:
			end = maxf(end, L[1] + L[2] + (0.25 if L[0] == "b" else 0.05))
		var n := int(ceil(end * RATE))
		var buf := PackedFloat32Array()
		buf.resize(n)
		for L in layers:
			if L[0] == "o":
				_osc(buf, L[1], L[2], L[3], L[4], L[5], L[6])
			elif L[0] == "b":
				_brass(buf, L[1], L[2], L[3], L[4], L[5], L[6])
			elif L[0] == "w":
				_whir(buf, L[1], L[2])
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


# ---------------------------------------------------------------- the casino (v0.10.3 and v0.10.8 cues)
# ["b", start, dur, f, peak, wah, vib]: brass(); ["w", start, dur]: the roulette ball's whir (rlWheelSfx). The browser's chips,
# bells, coins and ringer are layers of the plain kinds; their random pitches and timings are drawn once, from a fixed seed.

var crng := RandomNumberGenerator.new()


func _casino() -> Dictionary:
	crng.seed = 73
	var R := {}
	R.cas_card = [["n", 0, .05, "highpass", 3000, .8, .12, 0], ["o", 0, .04, "triangle", 900, .03, 0]]
	R.cas_reel = [["n", 0, .04, "lowpass", 900, 1, .25, 0], ["o", 0, .06, "square", 220, .06, 140]]
	R.cas_lever = [["n", 0, .18, "bandpass", 600, 1.2, .15, 300], ["o", .12, .08, "triangle", 300, .06, 0]]
	R.cas_chip = [["n", 0, .03, "highpass", 4200, 1, .2, 0], ["o", 0, .05, "sine", 2400, .03, 1800]]
	R.cas_peg = [["o", 0, .05, "sine", 1500 + crng.randf() * 500, .035, 0]]
	# the dice: shaken in the hand, then thrown, tumbling down the felt into the back wall
	var d: Array = []
	for k in 6:
		d.append(["n", k * .045, .02, "bandpass", 2800 + (k % 2) * 600, 3, .1, 0])
	var dt := [.34, .46, .55, .62, .67]
	for k in dt.size():
		d.append(["n", dt[k], .04, "lowpass", 900, 1, .22 - k * .03, 0])
		d.append(["n", dt[k], .015, "bandpass", 2400 + k * 300, 3, .1, 0])
	R.cas_dice = d
	# the result of every round (cgResultSfx picks one): chips raked away; the sad trombone; a push; a small win; a win; the fanfare; the jackpot
	R.cas_lose = [["n", 0, .32, "bandpass", 1400, 1.1, .12, 500], ["o", .12, .3, "triangle", 294, .05, 277], ["o", .36, .5, "triangle", 262, .05, 247]]
	var b: Array = [["n", 0, .32, "bandpass", 1400, 1.1, .12, 500]]
	var tb := [233.08, 220, 207.65]
	for i in 3:
		b.append(["b", .15 + i * .42, .3, tb[i], .07, 1, 0])
	b.append(["b", 1.41, 1.1, 196, .07, 1, 5.5])
	R.cas_bust = b
	R.cas_push = _chip(0, .14) + _chip(.08, .1) + [["o", .05, .3, "sine", 587, .04, 0]]
	R.cas_small = _chip(0, .16) + _chip(.06, .12) + _bell(.08, 1318.5, .06, .5) + _bell(.2, 1568, .065, .7)
	var w: Array = []
	for k in 3:
		w += _chip(k * .05, .15)
	var fs := [1046.5, 1318.5, 1568, 2093]
	for i in 4:
		w += _bell(.1 + i * .08, fs[i], .06, .8)
	R.cas_win = w + _coins(.35, .6, 7, .045)
	var g: Array = []
	for k in 3:
		g.append(["b", k * .12, .08, 392, .085, 0, 0])
	for f in [261.63, 523.25, 659.25, 783.99]:
		g.append(["b", .36, .8, f, .1 if f < 300 else .07, 0, 0])
	g.append(["b", .36, .8, 1046.5, .035, 0, 0])
	for i in 4:
		g += _bell(.4 + i * .06, fs[i], .05, 1.1)
	R.cas_big = g + _coins(.45, 1.1, 16, .045)
	var j: Array = _ringer(0, 2, .028)
	for x in [[392, 0, .09], [392, .12, .09], [392, .24, .09], [523.25, .36, .3], [392, .72, .09]]:
		j.append(["b", x[1], x[2], x[0], .085, 0, 0])
		j.append(["b", x[1], x[2], x[0] / 2.0, .055, 0, 0])
	for f in [130.81, 261.63, 523.25, 659.25, 783.99, 1046.5]:
		j.append(["b", .86, 1.5, f, .085 if f < 300 else .065, 0, 0])
	var fj := [1046.5, 1318.5, 1568, 2093, 2637, 3136]
	for i in fj.size():
		j += _bell(.9 + i * .07, fj[i], .05, 1.3)
	j += _coins(.3, 2.4, 30, .05)
	j.append(["o", 2.2, .7, "sine", 1200, .03, 4200])
	for i in 3:
		j += _bell(2.6 + i * .08, [2093, 2637, 3136][i], .04, 1)
	R.cas_jackpot = j
	# the roulette ball over a whole 6 s spin: it whirs round the rim, slows, rattles over the frets and drops in its pocket
	var dur := 6.0
	var wl: Array = [["w", 0, dur]]
	var c := .35
	while c < dur - .7:
		var p := c / dur
		wl.append(["n", c, .012, "highpass", 3800, .8, .05 * (.4 + p), 0])
		c += .045 + .3 * p * p
	var rt := [0, .11, .2, .27, .32]
	for i in rt.size():
		wl.append(["n", dur - .6 + rt[i], .02, "bandpass", 3000 - i * 250, 2, .12 - i * .015, 0])
		wl.append(["o", dur - .6 + rt[i], .03, "triangle", 1100 - i * 80, .03, 0])
	wl.append(["n", dur - .25, .06, "lowpass", 500, 1, .15, 0])
	R.cas_wheel = wl
	return R


func _chip(t0: float, peak: float) -> Array:   # casChip: a clay chip
	return [["n", t0, .025, "bandpass", 2600 + crng.randf() * 900, 2.2, peak, 0], ["o", t0, .03, "triangle", 1500 + crng.randf() * 400, peak * .2, 900]]


func _bell(t0: float, f: float, peak: float, dur: float = .9) -> Array:   # casBell: the slot machine's bell
	return [["o", t0, dur, "sine", f, peak, 0], ["o", t0, dur * .55, "sine", f * 2.76, peak * .45, 0], ["o", t0, dur * .3, "sine", f * 5.4, peak * .2, 0]]


func _coins(t0: float, span: float, n: int, peak: float) -> Array:   # casCoins: coins landing in the tray
	var o: Array = []
	for i in n:
		var t := t0 + span * pow(crng.randf(), 1.4)
		var pk := peak * (.6 + crng.randf() * .4)
		var f := 2600 + crng.randf() * 1800
		o += [["o", t, .08 + crng.randf() * .1, "sine", f, pk, 0], ["o", t, .06, "sine", f * 1.47, pk * .55, 0], ["o", t, .012, "square", f * .5, pk * .25, 0]]
	return o


func _ringer(t0: float, dur: float, peak: float) -> Array:   # casRinger: the jackpot bell that rings and rings
	var o: Array = []
	var s := 0.0
	while s < dur:
		var p := peak * (1 - .5 * s / dur)
		o += [["o", t0 + s, .1, "sine", 2350, p, 0], ["o", t0 + s, .05, "sine", 5640, p * .35, 0]]
		s += .055
	return o


## brass(): two sawtooths detuned 7 cents either way (vibrato: +-30 cents from a quarter in) through a lowpass that opens
## with the note (wah: a plunger mute, Q 5 dB, opening and closing again); gain up in 30 ms, sagging to 70%, a 150 ms release
func _brass(buf: PackedFloat32Array, t0: float, dur: float, f: float, peak: float, wah: int, vib: float) -> void:
	var i0 := int(t0 * RATE)
	var n := int((dur + 0.2) * RATE)
	var ph := [0.0, 0.0]
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	var qd := 5.0 if wah else 1.0
	var f1 := minf(9000.0, f * 8)
	for s in n:
		var t := float(s) / RATE
		var cents := 30.0 * sin(TAU * vib * (t - dur * .25)) if vib > 0 and t >= dur * .25 else 0.0
		var x := 0.0
		for k in 2:
			ph[k] = fmod(ph[k] + f * pow(2.0, ([-7.0, 7.0][k] + cents) / 1200.0) / RATE, 1.0)
			x += 2.0 * ph[k] - 1.0
		var fc: float
		if wah:
			fc = f * 1.2 * pow(4.5 / 1.2, t / (dur * .35)) if t < dur * .35 else (f * 4.5 * pow(1.3 / 4.5, (t - dur * .35) / (dur * .65)) if t < dur else f * 1.3)
		else:
			fc = f * 2 * pow(f1 / (f * 2), t / .05) if t < .05 else (f1 * pow(f * 4 / f1, (t - .05) / (dur - .05)) if t < dur else f * 4)
		fc = minf(fc, RATE * 0.49)
		var w0 := TAU * fc / RATE
		var cw := cos(w0)
		var alpha := sin(w0) / (2.0 * pow(10.0, qd / 20.0))
		var b0 := (1.0 - cw) / 2.0
		var y := (b0 * x + (1.0 - cw) * x1 + b0 * x2 + 2.0 * cw * y1 - (1.0 - alpha) * y2) / (1.0 + alpha)
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		var g: float
		if t < .03:
			g = 0.0001 * pow(peak / 0.0001, t / .03)
		elif t < dur:
			g = peak + (peak * .7 - peak) * (t - .03) / (dur - .03)
		elif t < dur + .15:
			g = peak * .7 * pow(0.0001 / (peak * .7), (t - dur) / .15)
		else:
			g = 0.0001
		if i0 + s < buf.size():
			buf[i0 + s] += y * g


## rlWheelSfx's whir: looped noise through a bandpass (Q 3) sliding 2600 -> 700 Hz, in over 0.25 s, fading to the drop
func _whir(buf: PackedFloat32Array, t0: float, dur: float) -> void:
	var i0 := int(t0 * RATE)
	var n := int(dur * RATE)
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for s in n:
		var t := float(s) / RATE
		var fc := 2600.0 * pow(700.0 / 2600.0, minf(1.0, t / (dur - .5)))
		var w0 := TAU * fc / RATE
		var cw := cos(w0)
		var alpha := sin(w0) / (2.0 * 3.0)
		var x := rng.randf() * 2.0 - 1.0
		var y := (alpha * x - alpha * x2 + 2.0 * cw * y1 - (1.0 - alpha) * y2) / (1.0 + alpha)
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		var g: float
		if t < .25:
			g = 0.0001 * pow(.06 / 0.0001, t / .25)
		elif t < dur - .6:
			g = .06 + (.015 - .06) * (t - .25) / (dur - .6 - .25)
		elif t < dur - .4:
			g = .015 * pow(0.0001 / .015, (t - (dur - .6)) / .2)
		else:
			g = 0.0001
		if i0 + s < buf.size():
			buf[i0 + s] += y * g
