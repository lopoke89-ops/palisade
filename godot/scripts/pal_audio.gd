class_name PalAudio
extends Node
## Sound effects and music, as the browser plays them (dev/src/js/03-audio.js).
## Effects are the browser's synth recipes pre-rendered by tools/render_sfx.gd; music is the browser's tracks in Ogg Vorbis.

const NAMES := ["ar", "rifle", "smg", "shotgun", "hit0", "hit1", "hit2", "boom", "bigboom", "bottle", "shieldhit", "medpulse", "mark",
	"collapse", "place0", "place1", "place2", "gather", "siren", "core", "hurt", "drop", "lob", "plant", "beep", "revive", "restock",
	"deny", "medic", "win", "lose", "horn", "rocket", "lock", "slash", "charge", "zap", "rumble", "drill", "rockfall", "winterwarn", "splash", "sniper", "rack", "pump", "shellin", "dry", "harpoon", "chain", "flood",
	"ts_gold", "ts_plasma", "ts_rainbow", "ts_grad", "ts_aurora", "ts_star", "ts_comet", "ts_neon", "ts_cosmic", "ts_rock", "ts_solar", "ts_glitch", "ts_galaxy", "ts_void", "ts_grainbow", "kx_sparks", "kx_smoke", "kx_confetti", "kx_embers", "kx_glint", "kx_bats", "kx_spider", "kx_souls", "kx_rocketburst", "kx_reticle", "kx_frag", "kx_hellportal", "kx_orbital", "kx_cinder", "kx_tealslash", "kx_ashbrand", "kx_demonclaw", "kx_salvage", "kx_bolt", "kx_skull", "kx_pixel", "kx_frost", "kx_gradburst", "kx_sunburst", "kx_toxic", "kx_supernova", "kx_glitchout", "kx_singularity", "kx_shockwave", "kx_bubbles", "tick_c", "tick_r", "tick_e", "tick_l", "tick_g", "tick_u",
	"cas_card", "cas_reel", "cas_lever", "cas_chip", "cas_peg", "cas_dice", "cas_lose", "cas_bust", "cas_push", "cas_small", "cas_win", "cas_big", "cas_jackpot", "cas_wheel"]
const HEADROOM := 0.5   # matches tools/render_sfx.gd
const MASTER := 0.55
const MUSIC := {"menu": "main_menu", "between": "between_raids", "attitude": "raid_attitude", "cool": "raid_cool", "express": "raid_express", "finale": "final_blitz", "results": "results"}
const CASINO := ["casino_1", "casino_2", "casino_3", "casino_4", "casino_5", "casino_6", "casino_7", "casino_8", "casino_9", "casino_10", "casino_11"]
const CASINO_XF := 5.0   # each casino track crossfades into the next over its last 5 s
const DUCK := {"cas_bust": 2.4, "cas_big": 2.0, "cas_jackpot": 3.4}   # the big result sounds dip the music under them
const POOL := 24

var volume := 0.8   # cfg.volume
var music_vol := 0.7   # cfg.music
var sim: Sim
var main   # demo (the menus' yard) picks the menu track
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
var cas_bag: Array = []   # casinoUp: the shuffled playlist, drawn from the end
var cas_up := ""
var cas_last := ""
var xf_in := 0.0   # > 0: the current track is crossfading in over this many seconds
var duck_until := -9.0
var duck_g := 1.0


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
	for k in CASINO:   # Ogg streams are decoded as they play, so the whole playlist can stay loaded
		var st = load("res://music/%s.ogg" % k)
		if st != null:
			st.loop = false
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
	if DUCK.has(name):
		duck_until = t + DUCK[name]
	var pl := _free_player()
	pl.stream = streams[name]
	pl.bus = bus
	pl.volume_db = linear_to_db(v * MASTER * volume / HEADROOM)
	pl.play()


## a UI sound started part way in (the roulette ball's whir, joined with the spin already under way); at full level
func play_from(name: String, offset: float) -> void:
	if not streams.has(name):
		return
	last_s[name] = _now()
	var pl := _free_player()
	pl.stream = streams[name]
	pl.bus = "Master"
	pl.volume_db = linear_to_db(MASTER * volume / HEADROOM)
	pl.play(maxf(0.0, offset))


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


## musicRoute(): the menus play the menu track, the end screen results, the casino its shuffled playlist; Blitzkrieg,
## the Whiteout Gauntlet and Black Out's final push the finale; Black Out's attacks and every raid cycle attitude / cool /
## express; the build phase plays between. [track, token]: a new token restarts the music.
func music_route() -> Array:
	var g: Dictionary = sim.game
	var demo: bool = main != null and main.demo
	if not demo and g.phase == "over":
		return ["results", "results:" + str(g.get("gid", ""))]
	if demo:
		return ["menu", "menu"]
	var gid := str(g.get("gid", ""))
	if g.mode == "casino":
		return ["casino", "casino:" + gid]
	var raid: String = ["attitude", "cool", "express"][maxi(0, g.wave - 1) % 3]
	if g.mode == "blackout" and sim.pvp() == "" and g.get("bo") != null and g.phase == "raid":
		var st: String = g.bo.stage
		if st == "push" or st == "done":
			return ["finale", "finale:" + gid]
		if st == "attack":
			return [raid, "raid:%s:%d" % [gid, g.wave]]
		return ["between", "quiet:%s:%d" % [gid, g.wave]]
	if (g.mode == "blitz" or (g.get("fb") != null and g.fb.get("gauntlet", false))) and sim.pvp() == "" and g.get("fb") != null:
		return ["finale", "finale:" + gid]
	if g.phase == "raid":
		return [raid, "raid:%s:%d" % [gid, g.wave]]
	return ["between", "build:%s:%d" % [gid, g.wave]]


## casinoUp: the next casino track, from a fresh shuffle once the bag is empty (never the one just played twice in a row)
func casino_up() -> String:
	if cas_up != "":
		return cas_up
	if cas_bag.is_empty():
		var b := CASINO.duplicate()
		b.shuffle()
		if b.size() > 1 and b[b.size() - 1] == cas_last:
			var t = b[0]
			b[0] = b[b.size() - 1]
			b[b.size() - 1] = t
		cas_bag = b
	cas_up = cas_bag.pop_back()
	return cas_up


func _start(k: String, token: String, xf: float = 0.0) -> void:
	mus_cur = AudioStreamPlayer.new()
	add_child(mus_cur)
	mus_cur.stream = tracks[k]
	mus_cur.set_meta("k", k)
	mus_token = token
	mus_env = 0.0001
	xf_in = xf
	mus_cur.play()
	if CASINO.has(k):
		if cas_up == k:
			cas_up = ""
		cas_last = k
		casino_up()


func _process(dt: float) -> void:
	if sim == null:
		return
	var r := music_route()
	var cur_k: String = mus_cur.get_meta("k") if mus_cur != null else ""
	var want: String = r[0]
	if want == "casino":
		want = cur_k if CASINO.has(cur_k) and mus_token == r[1] else casino_up()
	if mus_cur != null and (cur_k != want or r[1] != mus_token or music_vol <= 0):
		fading.append([mus_cur, mus_env, 0.9 if sim.game.phase == "raid" else 1.2])   # musicStop
		mus_cur = null
	if mus_cur != null and CASINO.has(cur_k):   # the playlist: the next track comes in over this one's last seconds
		var left := mus_cur.stream.get_length() - mus_cur.get_playback_position()
		if left <= CASINO_XF + 0.25 or not mus_cur.playing:
			fading.append([mus_cur, mus_env, maxf(0.3, left)])
			mus_cur = null
			if tracks.has(cas_up) and music_vol > 0:
				_start(cas_up, r[1], maxf(0.3, left))
	if mus_cur == null and tracks.has(want) and music_vol > 0:
		_start(want, r[1])
	var now := _now()
	duck_g = lerpf(duck_g, 0.3 if now < duck_until else 1.0, 1.0 - exp(-dt / (0.08 if now < duck_until else 0.3)))
	var bv := 0.5 * music_vol * MASTER * volume * duck_g
	if mus_cur != null:
		if xf_in > 0:
			mus_env = minf(1.0, maxf(mus_env, 0.0) + dt / xf_in)   # a playlist crossfade: in while the last track goes out
		else:
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
