class_name PalAudio
extends Node
## Sound effects and music, as the browser plays them (dev/src/js/03-audio.js).
## Effects are the browser's synth recipes pre-rendered by tools/render_sfx.gd; music is the browser's tracks in Ogg Vorbis.

const NAMES := ["ar", "rifle", "smg", "shotgun", "hit0", "hit1", "hit2", "boom", "bigboom", "bottle", "shieldhit", "medpulse", "mark",
	"collapse", "place0", "place1", "place2", "gather", "siren", "core", "hurt", "drop", "lob", "plant", "beep", "revive", "restock",
	"deny", "medic", "win", "lose", "horn", "rocket", "lock", "slash", "charge", "zap", "rumble", "drill", "rockfall", "winterwarn", "splash", "sniper", "rack", "pump", "shellin", "dry", "harpoon", "chain", "flood",
	"ts_gold", "ts_plasma", "ts_rainbow", "ts_grad", "ts_aurora", "ts_star", "ts_comet", "ts_neon", "ts_cosmic", "ts_rock", "ts_solar", "ts_glitch", "ts_galaxy", "ts_void", "ts_grainbow", "kx_sparks", "kx_smoke", "kx_confetti", "kx_embers", "kx_glint", "kx_bats", "kx_spider", "kx_souls", "kx_rocketburst", "kx_reticle", "kx_frag", "kx_hellportal", "kx_orbital", "kx_cinder", "kx_tealslash", "kx_ashbrand", "kx_demonclaw", "kx_salvage", "kx_bolt", "kx_skull", "kx_pixel", "kx_frost", "kx_gradburst", "kx_sunburst", "kx_toxic", "kx_supernova", "kx_glitchout", "kx_singularity", "kx_shockwave", "kx_bubbles"]
const HEADROOM := 0.5   # matches tools/render_sfx.gd
const MASTER := 0.55
const MUSIC := {"between": "between_raids", "attitude": "raid_attitude", "cool": "raid_cool", "express": "raid_express", "results": "results"}
const POOL := 24

var volume := 0.8   # cfg.volume
var music_vol := 0.7   # cfg.music
var sim: Sim
var streams := {}
var players: Array = []
var last_s := {}
var voice_t: Array = []
var muffle_bus: Array = ["Master"]
var tracks := {}
var mus_cur: AudioStreamPlayer = null
var mus_token := ""
var mus_env := 0.0
var fading: Array = []   # [player, env, fade seconds]


func _ready() -> void:
	for n in NAMES:
		var st = load("res://sfx/%s.wav" % n)
		if st != null:
			streams[n] = st
	for k in MUSIC:
		var st = load("res://music/%s.ogg" % MUSIC[k])
		if st != null:
			st.loop = true
			tracks[k] = st
	# walls in between muffle a sound: one shared low-pass bus per wall count, as the browser shares one filter
	for wb in range(1, 4):
		var name := "Muffle%d" % wb
		var bi := AudioServer.bus_count
		AudioServer.add_bus(bi)
		AudioServer.set_bus_name(bi, name)
		AudioServer.set_bus_send(bi, "Master")
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = 9000.0 * pow(0.22, wb) + 200.0
		AudioServer.add_bus_effect(bi, lp)
		muffle_bus.append(name)
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func walls_between(x0: float, y0: float, x1: float, y1: float) -> int:
	var n := 0
	var last := -1
	var d := Vector2(x1 - x0, y1 - y0).length()
	var st := maxi(1, ceili(d / 0.3))
	for s in range(1, st):
		var x := x0 + (x1 - x0) * s / st
		var y := y0 + (y1 - y0) * s / st
		var i := int(x)
		var j := int(y)
		if not sim.inb(i, j):
			continue
		var k := sim.idx(i, j)
		var w = sim.walls[k]
		if k != last and w != null and Pal.wall_state(w) < 2:
			n += 1
			last = k
	return n


## x < 0: not placed in the world (heard at full level)
func play(name: String, x: float = -1.0, y: float = -1.0) -> void:
	if not streams.has(name):
		return
	var t := _now()
	if last_s.has(name) and t - last_s[name] < 0.035:
		return
	# at most ~14 sounds start in any 0.12 s window; distant world sounds are the first to be skipped
	while not voice_t.is_empty() and t - voice_t[0] > 0.12:
		voice_t.pop_front()
	if x >= 0 and voice_t.size() >= 14:
		return
	var v := 1.0
	var bus := "Master"
	if x >= 0 and sim != null:
		var p: Dictionary = sim.player
		var d := Vector2(x - p.x, y - p.y).length()
		v = 1.0 / (1.0 + d * 0.2)
		if v < 0.07:
			return   # too far to hear
		var wb := mini(3, walls_between(x, y, p.x, p.y)) if d > 1.2 else 0
		bus = muffle_bus[wb]
	last_s[name] = t
	voice_t.append(t)
	var pl := _free_player()
	pl.stream = streams[name]
	pl.bus = bus
	pl.volume_db = linear_to_db(v * MASTER * volume / HEADROOM)
	pl.play()


func _free_player() -> AudioStreamPlayer:
	for p in players:
		if not p.playing:
			return p
	# all busy: take the one that has played longest
	var best: AudioStreamPlayer = players[0]
	for p in players:
		if p.get_playback_position() > best.get_playback_position():
			best = p
	return best


## musicRoute(): the build phase plays "between", raids cycle attitude / cool / express, the end screen plays results
func music_route() -> Array:
	var g: Dictionary = sim.game
	if g.phase == "over":
		return ["results", "results"]
	if g.phase == "raid":
		return [["attitude", "cool", "express"][maxi(0, g.wave - 1) % 3], "raid:%d" % g.wave]
	return ["between", "build:%d" % g.wave]


func _process(dt: float) -> void:
	if sim == null:
		return
	var r := music_route()
	if mus_cur != null and r[1] != mus_token:
		fading.append([mus_cur, mus_env, 0.9 if sim.game.phase == "raid" else 1.2])   # musicStop
		mus_cur = null
	if mus_cur == null and tracks.has(r[0]) and music_vol > 0:
		mus_cur = AudioStreamPlayer.new()
		add_child(mus_cur)
		mus_cur.stream = tracks[r[0]]
		mus_token = r[1]
		mus_env = 0.0001
		mus_cur.play()
	var bv := 0.5 * music_vol * MASTER * volume
	if mus_cur != null:
		mus_env = minf(1.0, mus_env * pow(1.0 / 0.0001, dt / 1.6))   # exponential fade in over 1.6 s
		mus_cur.volume_db = linear_to_db(maxf(mus_env * bv, 1e-6))
	for f in fading:
		f[1] *= pow(0.0001, dt / f[2])
		f[0].volume_db = linear_to_db(maxf(f[1] * bv, 1e-6))
		if f[1] <= 0.00011:
			f[0].queue_free()
	fading = fading.filter(func(f): return f[1] > 0.00011)


func _exit_tree() -> void:
	if mus_cur != null:
		mus_cur.stop()
		mus_cur.stream = null
	for f in fading:
		f[0].stop()
		f[0].stream = null
	for p in players:
		p.stop()
		p.stream = null
	tracks.clear()
	streams.clear()
