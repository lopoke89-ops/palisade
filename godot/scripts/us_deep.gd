class_name UsDeep
extends RefCounted
## THE UNDERSTRIP's regions 2 and 3 and their bosses (G3), ported from 10k-understrip-regions.js and 10i-understrip-bosses.js.
## Shelter 7: gas vents that leak on a timer, radiation floors, the Custodian's blast doors. Area 67: acid, low-gravity
## floors (shots and grenades slow over them), specimen tanks, containment alarms that call drone packs, and the drones.
## The bosses: the Custodian (mop arc, live water, doors, gas quarters, a ceiling turret), the Gatekeeper (rockets, a
## shield, a stomp; at half health the pilot ejects and both bodies fight), the Visitor (psychic rings, tank throws; then
## the lights go out: blinks, drone swarms, gravity wells; under 10% everything comes faster).
## Boss states 63-89 are this mode's, as in the browser. Everything here runs on the host, off the sim's own rnd().

const HZ_RAD := 1
const HZ_ACID := 2
const HZ_GRAV := 3
const HZ_GAS := 4
const HZ_BLAST := 5
const HZ := {"rad": 3.0, "acid": 6.0, "gas": 10.0, "lung": 0.5, "vent_every": [13.0, 21.0], "vent_warn": 2.0, "vent_on": 6.0, "tick": 0.25, "grav": 0.6}
const DRONE := {"touch": 4.0, "cd": 0.6, "r": 0.55, "light": 2.0, "litSpeed": 0.5, "pack": [4, 6], "alive": 12, "alarm": 3.0}

const CUS := {"hp": 3556.0, "speed": 1.0, "speed2": 1.2, "mop": {"tell": 0.9, "r": 3.0, "half": 1.1, "dmg": 24.0, "slow": 0.6, "cd": [3.0, 2.5], "strip": 3.0, "dps": 8.0},
	"door": {"every": 8.0, "warn": 1.0, "shut": 3.0, "dmg": 40.0}, "crush": {"tell": 1.0, "shut": 1.5, "dmg": 45.0, "cd": 7.0},
	"gas": {"tell": 2.0, "len": 8.0, "dps": 10.0, "cd": 14.0}, "turret": {"tell": 0.8, "n": 3, "dmg": 9.0, "cd": 6.0}, "transition": 3.0}
const GK := {"hp": 5333.0, "speed": 0.9, "suit2": 0.8, "pilot": 2.4, "pilotHp": 0.2, "rockets": {"tell": 1.1, "r": 1.2, "n": [4, 3], "cd": [5.0, 7.0], "power": 0.56},
	"shield": {"tell": 0.6, "len": 4.0, "cd": 10.0}, "stomp": {"tell": 0.8, "r": 2.5, "dmg": 20.0, "push": 1.5, "cd": 4.0},
	"pound": {"tell": 1.2, "r": 3.0, "dmg": 34.0, "cd": 5.0}, "sidearm": {"tell": 0.6, "n": 3, "dmg": 9.0, "cd": 2.0}, "dive": {"every": 4.0, "len": 0.5, "speed": 7.0}, "transition": 3.0}
const VIS := {"hp": 8000.0, "speed": 1.2, "speed2": 1.4, "pulse": {"tell": 0.8, "speed": 6.0, "max": 9.0, "w": 0.45, "dmg": 24.0, "cd": 4.0},
	"tank": {"tell": 1.2, "r": 1.3, "dmg": 30.0, "acid": 6.0, "acidT": 4.0, "cd": 6.0}, "blink": {"tell": 0.9, "r": 2.0, "dmg": 16.0, "cd": 5.0},
	"swarm": {"n": 6, "cd": 14.0}, "well": {"tell": 1.0, "len": 3.0, "r": 6.0, "core": 1.2, "pull": 1.2, "dps": 12.0, "cd": 12.0}, "desperate": 0.7, "transition": 3.0}

## the bosses as Sim.boss_def gives them (the browser's BOSSES entries)
const DEFS := {
	"custodian": {"name": "THE CUSTODIAN", "hp": 3556.0, "speed": 1.0, "scan": 12.0, "bounty": 50, "col": "#9bbf5a",
		"intro": "A shock mop and the shelter's own doors. Watch the light over each door: amber means it's about to slam."},
	"gatekeeper": {"name": "THE GATEKEEPER", "hp": 5333.0, "speed": 0.9, "scan": 12.0, "bounty": 60, "col": "#cfd8dc",
		"intro": "Rockets fall where the circles are. His shield blocks shots from the front: go round it."},
	"visitor": {"name": "THE VISITOR", "hp": 8000.0, "speed": 1.2, "scan": 14.0, "bounty": 80, "col": "#b8a8ff",
		"intro": "Psychic rings: roll through them. When the lights go out, a flash shows where it will be next."},
}
## v0.12.4 (Big U): each boss 50% more than the one before, the finale 10,000 solo on Normal (8,000 x BOSS_HP 1.25)
const HP := {"pitboss": 2370.0, "custodian": 3556.0, "gatekeeper": 5333.0, "visitor": 8000.0}
const WEAK := {"pitboss": "blast", "custodian": "shock", "gatekeeper": "ap", "visitor": "fire"}
const DOWN := {"pitboss": ["THE PIT BOSS IS DOWN", "The count room's shrine is lit and the lift is running. Rest, then take it down."],
	"custodian": ["THE CUSTODIAN IS DOWN", "The hall's doors stand open, its shrine is lit, and the lift is running."],
	"gatekeeper": ["THE GATEKEEPER IS DOWN", "The lab door is open. Rest at the bay's shrine; the lift goes down to the core."],
	"visitor": ["THE VISITOR IS DOWN", "The field is dark for good. Rest, then take the lift out of Area 67."]}
## the bosses' own drops (work order 8.2-8.5)
const SIG := {"pitboss": {"kind": "perk", "k": "p_tiepin"}, "custodian": {"kind": "weapon", "w": {"id": "w_flare", "r": "e", "mods": ["m_dmg", "m_reload"]}},
	"gatekeeper": {"kind": "weapon", "w": {"id": "w_antigrav", "r": "l", "mods": ["m_dmg", "m_mag"]}}, "visitor": {"kind": "relic", "k": "x_eye"}}

static func region(s) -> int:
	return PalUnderstrip.PLAN[clampi(int(s.game.us.level), 0, 9)][0]

static func boss_of(s) -> String:
	return PalUnderstrip.PLAN[clampi(int(s.game.us.level), 0, 9)][2]

# ---------------------------------------------------------------- the hazard map (usHazLay)

static func walkable(c: String) -> bool:
	return c != "#" and c != "%" and c != "o" and c != "t"

## joined runs of one marker (4-neighbour), each one vent or one door
static func groups(L: Dictionary, ch: String) -> Array:
	var T: int = L.T
	var seen := PackedByteArray()
	seen.resize(T * T)
	var out: Array = []
	for y in T:
		for x in T:
			if L.tiles[y][x] != ch or seen[y * T + x]:
				continue
			var q: Array = [[x, y]]
			seen[y * T + x] = 1
			var h := 0
			while h < q.size():
				var a: int = q[h][0]
				var b: int = q[h][1]
				h += 1
				for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
					var X: int = a + d[0]
					var Y: int = b + d[1]
					if X < 0 or Y < 0 or X >= T or Y >= T or seen[Y * T + X] or L.tiles[Y][X] != ch:
						continue
					seen[Y * T + X] = 1
					q.append([X, Y])
			var cx := 0.0
			var cy := 0.0
			for t in q:
				cx += t[0] + 0.5
				cy += t[1] + 0.5
			out.append({"tiles": q, "cx": cx / q.size(), "cy": cy / q.size()})
	return out

## the level's hazard tiles, vents, blast doors, tanks and lamp timers, added to the layout
static func haz_lay(L: Dictionary, lay: Dictionary) -> void:
	var T: int = L.T
	var haz := PackedByteArray()
	haz.resize(T * T)
	for y in T:
		for x in T:
			var c: String = L.tiles[y][x]
			haz[y * T + x] = HZ_RAD if c == "z" else (HZ_ACID if c == "a" else (HZ_GRAV if c == "v" else (HZ_GAS if c == "g" else (HZ_BLAST if c == "b" else 0))))
	lay.haz = haz
	var r = PalUnderstripGen.Rng.new(PalUnderstripGen.mix([L.seed, 4242]))
	lay.vents = []
	for v in groups(L, "g"):
		v.every = HZ.vent_every[0] + r.next() * (HZ.vent_every[1] - HZ.vent_every[0])
		v.first = 3 + r.next() * 10
		var cloud := {}
		for t in v.tiles:
			for b in range(-1, 2):
				for a in range(-1, 2):
					var X: int = t[0] + a
					var Y: int = t[1] + b
					if X >= 0 and Y >= 0 and X < T and Y < T and walkable(L.tiles[Y][X]):
						cloud[Y * T + X] = true
		v.cloud = cloud
		lay.vents.append(v)
	lay.blast = []
	var n := 0
	for d in groups(L, "b"):
		d.off = n * 2.0
		n += 1
		lay.blast.append(d)
	lay.tanks = []
	for y in T:
		for x in T:
			if L.tiles[y][x] == "t":
				lay.tanks.append([x + 0.5, y + 0.5])
	lay.lampT = []
	for i in lay.lamps.size():
		lay.lampT.append({"on": 4 + r.next() * 6, "off": 0.6 + r.next() * 1.4, "ph": r.next() * 10})

static func haz_at(s, x: float, y: float) -> int:
	var i := int(x)
	var j := int(y)
	if i < 0 or j < 0 or i >= s.N or j >= s.N or not s.lay.has("haz"):
		return 0
	return s.lay.haz[j * s.N + i]

static func grav_at(s, x: float, y: float) -> float:
	return HZ.grav if haz_at(s, x, y) == HZ_GRAV else 1.0

## the vents' and doors' clocks (0 quiet, 1 warning, 2 on / shut)
static func haz_start(u: Dictionary, lay: Dictionary) -> void:
	u.vents = lay.get("vents", []).map(func(v): return {"s": 0, "t": v.first})
	u.blast = lay.get("blast", []).map(func(_d): return 0)
	u.blastT = 0.0
	u.alarms = []
	u.alarmed = []
	u.bfx = []
	u.crush = null

static func haz_tick(s, dt: float) -> void:
	var u: Dictionary = s.game.us
	var L: Dictionary = s.lay
	if not u.has("vents"):
		haz_start(u, L)
	for n in L.vents.size():   # gas vents: quiet, a hiss for 2 s, then the cloud for 6 s
		var v: Dictionary = L.vents[n]
		var S: Dictionary = u.vents[n]
		S.t -= dt
		if S.t > 0:
			continue
		if S.s == 0:
			S.s = 1
			S.t = HZ.vent_warn
			s.sfx("flood", v.cx, v.cy)
		elif S.s == 1:
			S.s = 2
			S.t = HZ.vent_on
		else:
			S.s = 0
			S.t = v.every
	for p in s.players.values():   # the floor: radiation, acid and the clouds
		if not p.alive:
			continue
		var k: int = s.idx(clampi(int(p.x), 0, s.N - 1), clampi(int(p.y), 0, s.N - 1))
		var h: int = L.haz[k] if L.has("haz") else 0
		var lung: float = HZ.lung if UsLoot.has(p, "p_lung") else 1.0
		var dps := 0.0
		if h == HZ_RAD:
			dps += HZ.rad * lung
		elif h == HZ_ACID:
			dps += HZ.acid
		for n in L.vents.size():
			if u.vents[n].s == 2 and L.vents[n].cloud.has(k):
				dps += HZ.gas * lung
		if dps == 0:
			p.hzAcc = 0.0
			continue
		p.hzAcc = p.get("hzAcc", 0.0) + dps * dt
		if p.hzAcc >= dps * HZ.tick:
			s.hurt_player(p, p.hzAcc)
			p.hzAcc = 0.0
			if not p.get("hzSaid", false):
				p.hzSaid = true
				s.toast_to(p, "ACID" if h == HZ_ACID else ("RADIATION" if h == HZ_RAD else "GAS"), "Get off it: it hurts while you stand there.")
	alarm_tick(s, dt)

## the Custodian's blast doors (and his crush lanes): shut ones are wall; anyone under one is pushed out and hurt
static func blast_set(s, n: int, st: int, dmg: float = 40.0) -> void:
	var u: Dictionary = s.game.us
	var D: Dictionary = s.lay.blast[n]
	var was: int = u.blast[n]
	u.blast[n] = st
	if (was == 2) == (st == 2):
		return
	for t in D.tiles:
		s.set_terr(s.idx(t[0], t[1]), PalMaps.T_SHUT if st == 2 else PalMaps.T_GROUND)
	s.flow_dirty = true
	if st == 2:
		var under := func(a) -> bool: return D.tiles.any(func(t): return int(a.x) == t[0] and int(a.y) == t[1])
		for a in s.allies():
			if a.alive and under.call(a):
				s.hurt_ally(a, dmg * s.Df.dmg)
				shove(a, D)
		for e in s.enemies:
			if not e.dead and under.call(e):
				shove(e, D)
		s.sfx("collapse", D.cx, D.cy)
		s.ev({"k": "shake", "x": D.cx, "y": D.cy, "amt": 4.0})

## out from under a door, to the nearer side of it
static func shove(a: Dictionary, D: Dictionary) -> void:
	var xs: Array = D.tiles.map(func(t): return t[0])
	var ys: Array = D.tiles.map(func(t): return t[1])
	if xs.max() - xs.min() >= ys.max() - ys.min():
		var y: int = D.tiles[0][1]
		a.y = y - 0.45 if a.y < y + 0.5 else y + 1.45
	else:
		var x: int = D.tiles[0][0]
		a.x = x - 0.45 if a.x < x + 0.5 else x + 1.45
	if a.has("tp"):
		a.tp += 1

static func blast_open_all(s) -> void:
	var u: Dictionary = s.game.us
	if not u.has("blast"):
		return
	for n in u.blast.size():
		if u.blast[n]:
			blast_set(s, n, 0)

## each door shuts for 3 s every 8 s, out of step, with a 1 s amber warning; a crush lane forces two at once
static func blast_tick(s, dt: float) -> void:
	var u: Dictionary = s.game.us
	var L: Dictionary = s.lay
	if L.blast.is_empty():
		return
	u.blastT += dt
	var D: Dictionary = CUS.door
	var C = u.crush
	if C != null:
		C.t += dt
		if C.t >= CUS.crush.tell + CUS.crush.shut:
			u.crush = null
			C = null
	for n in L.blast.size():
		var st := 0
		var crushed: bool = C != null and n in C.doors
		if crushed:
			st = 1 if C.t < CUS.crush.tell else 2
		else:
			var ph: float = fmod(u.blastT + L.blast[n].off, D.every)
			st = 0 if ph < D.every - D.warn - D.shut else (1 if ph < D.every - D.shut else 2)
		if st != u.blast[n]:
			blast_set(s, n, st, CUS.crush.dmg if crushed else D.dmg)

# ---------------------------------------------------------------- Area 67: alarms and drones

static func room_at(s, x: float, y: float) -> int:
	var R: Array = s.lay.us.rooms
	for n in R.size():
		var q: Dictionary = R[n]
		if x >= q.x and x < q.x + q.w and y >= q.y and y < q.y + q.h:
			return n
	return -1

## the first raider to start hunting in a room of region 3 trips its alarm (once a room until the next rest)
static func alarm(s, e: Dictionary) -> void:
	if region(s) != 3 or not e.has("us") or e.type == "drone":
		return
	var u: Dictionary = s.game.us
	if not u.has("alarms"):
		haz_start(u, s.lay)
	var n := room_at(s, e.us.home[0], e.us.home[1])
	if n < 0 or n in u.alarmed:
		return
	var q: Dictionary = s.lay.us.rooms[n]
	if not q.role in ["room", "junction", "corridor", "cache"]:
		return
	u.alarmed.append(n)
	u.alarms.append({"n": n, "t": DRONE.alarm})
	s.toast("CONTAINMENT ALARM", "A drone pack is coming. Drones die fast in your light.")
	s.sfx("siren", q.x + q.w / 2.0, q.y + q.h / 2.0)

static func alarm_tick(s, dt: float) -> void:
	var u: Dictionary = s.game.us
	if not u.has("alarms"):
		return
	for A in u.alarms:
		A.t -= dt
		if A.t > 0:
			continue
		A.done = true
		var q: Dictionary = s.lay.us.rooms[A.n]
		drone_pack(s, q.x + q.w / 2.0, q.y + q.h / 2.0, mini(DRONE.pack[1], DRONE.pack[0] + s.players.size() - 1))
	u.alarms = u.alarms.filter(func(A): return not A.get("done", false))

static func drone_pack(s, x: float, y: float, n: int, boss: bool = false) -> void:
	var alive: int = s.enemies.filter(func(e): return e.type == "drone" and not e.dead).size()
	for k in n:
		if alive >= DRONE.alive:
			break
		var a := float(k) / n * TAU
		var px := x + cos(a) * 0.8
		var py := y + sin(a) * 0.8
		if s.solid_tile(int(px), int(py)):
			continue
		var e: Dictionary = s.spawn_enemy_at("drone", px, py)
		e.us = {"home": [px, py], "st": "hunt", "sid": -1, "t": 0.0, "look": 0.0, "drone": true, "boss": boss}
		alive += 1

## drones fly their own way: straight at the nearest of you, down your flow field round corners, a sting on touch
static func drone_tick(s, e: Dictionary, dt: float) -> void:
	e.cd = maxf(-1.0, e.cd - dt)
	e.flash = maxf(0.0, e.flash - dt)
	e.walk += dt * 12
	var f = null
	var bd := 1e9
	for a in s.allies():
		if a.alive:
			var d := Vector2(a.x - e.x, a.y - e.y).length()
			if d < bd:
				bd = d
				f = a
	if f == null:
		return
	var tx: float = f.x
	var ty: float = f.y
	if bd > 1.2 and not s.los_clear(e.x, e.y, f.x, f.y):
		var F = s.us.flows.get(f.id)
		if F != null and F.has("f"):
			var i := int(e.x)
			var j := int(e.y)
			var b: float = F.f[s.idx(i, j)]
			var bi := i
			var bj := j
			for c in [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]:
				var I: int = i + c[0]
				var J: int = j + c[1]
				if not s.inb(I, J) or s.solid_tile(I, J):
					continue
				var v: float = F.f[s.idx(I, J)]
				if v < b:
					b = v
					bi = I
					bj = J
			tx = bi + 0.5
			ty = bj + 0.5
	e.litT = e.get("litT", 0.0) - dt
	if e.litT <= 0:   # in your light: half speed (checked five times a second)
		e.litT = 0.2
		e.lit = lit_at(s, e.x, e.y)
	var dx: float = tx - e.x
	var dy: float = ty - e.y
	var l := maxf(0.0001, Vector2(dx, dy).length())
	var step := minf(l, e.speed * dt * s.Df.get("speed", 1.0) * (DRONE.litSpeed if e.get("lit", false) else 1.0))
	e.aim = Vector2(dx / l, dy / l)
	s.move_ent(e, dx / l * step, dy / l * step, false)
	if bd < DRONE.r + 0.2 and e.cd <= 0:
		e.cd = DRONE.cd
		s.hurt_ally(f, DRONE.touch * s.Df.dmg)
		s.sfx("hit2", e.x, e.y)

## is this spot in someone's light (a cone, a flare, a lamp)? Drones there take double damage
static func lit_at(s, x: float, y: float) -> bool:
	for p in s.players.values():
		if not p.alive:
			continue
		var dx: float = x - p.x
		var dy: float = y - p.y
		var d := Vector2(dx, dy).length()
		if d < 1.4:
			return true
		var k: float = UsLoot.cone(p)
		var a: Vector2 = p.aim
		if d < 5.6 * k and (dx * a.x + dy * a.y) / maxf(d, 0.0001) > 0.86:
			return true
	for f in s.game.us.flares:
		if Vector2(x - f.x, y - f.y).length() < f.get("r", 4.0):
			return true
	for p in s.lay.lamps:
		if Vector2(x - p[0], y - p[1]).length() < 2.6:
			return true
	return false

static func drone_mul(s, e: Dictionary) -> float:
	return DRONE.light if lit_at(s, e.x, e.y) else 1.0

## lamps by region: Shelter 7's tubes flicker on timers; Area 67's lab lights fail more on its second level
static func lamp_on(s, n: int) -> float:
	var R := region(s)
	var lt: Array = s.lay.get("lampT", [])
	if R == 1 or n >= lt.size():
		return 1.0
	var T: Dictionary = lt[n]
	var lvl: int = int(s.game.us.level) - 6
	if PalSettings.reduce_motion:
		return 0.7 if R == 3 and lvl >= 1 else 1.0
	var t: float = fmod(s.game.time + T.ph, T.on + T.off)
	if R == 2:
		return 1.0 if t < T.on else (0.3 if t < T.on + 0.12 else 0.0)
	return (0.5 if sin(t * 37) > 0 else 0.0) if lvl >= 1 and t > T.on * 0.6 else 1.0

# ---------------------------------------------------------------- the bosses: wake, tick, down, reset

## the gate is closing: the boss comes in
static func wake(s) -> void:
	var u: Dictionary = s.game.us
	if u.bossSpawned:
		return
	var key := boss_of(s)
	if key == "":
		return
	u.bossSpawned = true
	u.bossStage = 0
	u.bfx = []
	u.blastT = 0.0
	var e: Dictionary = s.spawn_boss(key)
	e.us = {"home": [e.x, e.y], "st": "hunt", "sid": -e.id, "look": 0.0}
	e.hp = HP[key] * Sim.BOSS_HP * s.Df.hp * (1 + 0.35 * maxi(0, s.players.size() - 1)) * s.map_def.hp * (1.1 if s.N > 16 else 1.0)
	e.max = e.hp

## every frame of a boss fight: the doors and the floor effects; the Gatekeeper's two bodies (either one ends it)
static func boss_tick(s, dt: float) -> void:
	var u: Dictionary = s.game.us
	if not u.bossSpawned or u.bossDown:
		return
	var key := boss_of(s)
	if key == "custodian" and u.gate == 2:
		blast_tick(s, dt)
	bfx_tick(s, dt)
	if key == "gatekeeper" and s.enemies.any(func(e): return e.type == "boss" and e.dead and e.get("gk2", false)):
		for e in s.enemies:
			if e.type == "boss" and not e.dead:
				e.dead = true
				e.hp = 0.0

## a boss down: the floor clears, the doors open, the drones drop, the boss's own drop
static func boss_down(s) -> void:
	var u: Dictionary = s.game.us
	u.bfx = []
	u.crush = null
	blast_open_all(s)
	for e in s.enemies:
		if e.type == "drone":
			e.dead = true

## the squad fell: the boss and what he called go, and he starts again
static func boss_reset(s) -> void:
	var u: Dictionary = s.game.us
	s.enemies = s.enemies.filter(func(e): return e.type != "boss" and not (e.has("us") and (e.us.get("call", false) or e.us.get("drone", false) and e.us.get("boss", false))))
	u.bfx = []
	u.crush = null
	blast_open_all(s)

## the stage bar: each stage's own health (the Visitor has a third, desperate stage under 10%; the pilot is his own bar)
static func boss_frac(s, e: Dictionary) -> float:
	var f: float = e.hp / e.max
	var st: int = int(s.game.us.get("bossStage", 0))
	if e.get("pilot", false):
		return clampf(f, 0, 1)
	if e.boss == "visitor":
		return clampf(f / 0.1 if st >= 2 else ((f - 0.1) / 0.4 if st >= 1 else (f - 0.5) / 0.5), 0, 1)
	return clampf(f / 0.5 if st > 0 else (f - 0.5) / 0.5, 0, 1)

# ---------------------------------------------------------------- shared by the three deeper bosses

static func foes(s) -> Array:
	return s.allies().filter(func(a): return a.alive)

static func near_foe(s, e: Dictionary):
	var f = null
	var bd := 1e9
	for a in foes(s):
		var d := Vector2(a.x - e.x, a.y - e.y).length()
		if d < bd:
			bd = d
			f = a
	return f

static func far_foe(s, x: float, y: float):
	var f = null
	var bd := -1.0
	for a in foes(s):
		var d := Vector2(a.x - x, a.y - y).length()
		if d > bd:
			bd = d
			f = a
	return f

static func in_wedge(x: float, y: float, cx: float, cy: float, a0: float, r: float, half: float) -> bool:
	if Vector2(x - cx, y - cy).length() > r:
		return false
	return absf(angle_difference(a0, atan2(y - cy, x - cx))) < half

static func arena_c(s) -> Vector2:
	var A: Dictionary = s.lay.arena
	return Vector2(A.x + A.w / 2.0, A.y + A.h / 2.0)

## what's on the floor from a boss (us.bfx): live water, a gas quarter, a psychic ring, acid, a gravity well, a landing
## circle, the ceiling turret's line, a blink's flash. warn: the telegraph's time before it does anything; T: when it's gone
static func fx(s, k: String, o: Dictionary) -> void:
	var f := {"k": k, "t": 0.0, "warn": 0.0}
	f.merge(o, true)
	s.game.us.bfx.append(f)

static func dot(s, a: Dictionary, dps: float, dt: float) -> void:
	if is_same(a, s.qm):
		s.hurt_ally(a, dps * dt)
		return
	a.bDot = a.get("bDot", 0.0) + dps * dt
	if a.bDot >= dps * 0.25:
		s.hurt_player(a, a.bDot)
		a.bDot = 0.0

static func bfx_tick(s, dt: float) -> void:
	var u: Dictionary = s.game.us
	var Df: Dictionary = s.Df
	for f in u.bfx:
		f.t += dt
		var live: bool = f.t >= f.warn
		var first: bool = live and not f.get("went", false)
		if first:
			f.went = true
		match f.k:
			"water":
				if live:
					for a in foes(s):
						if in_wedge(a.x, a.y, f.x, f.y, f.a, f.r, f.half):
							dot(s, a, CUS.mop.dps, dt)
			"gas":
				if live:
					for a in foes(s):
						if a.x >= f.x and a.x < f.x1 and a.y >= f.y and a.y < f.y1:
							dot(s, a, CUS.gas.dps * (HZ.lung if not is_same(a, s.qm) and UsLoot.has(a, "p_lung") else 1.0), dt)
			"acid":
				if live:
					for a in foes(s):
						if Vector2(a.x - f.x, a.y - f.y).length() < f.r:
							dot(s, a, VIS.tank.acid, dt)
			"ring":
				if live:
					var R: float = (f.t - f.warn) * VIS.pulse.speed
					if not f.has("hit"):
						f.hit = []
					for a in foes(s):
						if a.id in f.hit:
							continue
						if absf(Vector2(a.x - f.x, a.y - f.y).length() - R) < VIS.pulse.w:
							f.hit.append(a.id)
							if not is_same(a, s.qm) and s.roll_safe(a):
								continue
							s.hurt_ally(a, VIS.pulse.dmg * Df.dmg)
							s._knock(a, f.x, f.y, 0.6)
			"well":
				if live:
					for a in foes(s):
						var dx: float = f.x - a.x
						var dy: float = f.y - a.y
						var d := Vector2(dx, dy).length()
						if d > VIS.well.r:
							continue
						if d < VIS.well.core:
							dot(s, a, VIS.well.dps, dt)
						if not (not is_same(a, s.qm) and UsLoot.relic(a, "x_lead")) and d > 0.2:
							s.move_ent(a, dx / d * VIS.well.pull * dt, dy / d * VIS.well.pull * dt, true)
			"circle":
				if first:
					for a in foes(s):
						if Vector2(a.x - f.x, a.y - f.y).length() < f.r:
							s.hurt_ally(a, f.get("dmg", 0.0) * Df.dmg)
							if f.get("push", 0.0) > 0:
								s._knock(a, f.x, f.y, f.push)
					s.ev({"k": "shake", "x": f.x, "y": f.y, "amt": 6.0})
					s.sfx("boom", f.x, f.y)
					s.emit(f.x, f.y, "smoke", 8)
			"turret":
				if first:
					var a0 := atan2(f.y1 - f.y, f.x1 - f.x)
					var src = null
					for e in s.enemies:
						if e.type == "boss" and not e.dead:
							src = e
							break
					if src != null:
						var o: Dictionary = src.duplicate()
						o.x = f.x
						o.y = f.y
						o.aim = Vector2(cos(a0), sin(a0))
						for k in CUS.turret.n:
							s.fire(o, a0 + (k - 1) * 0.035, 1, {"dmg": CUS.turret.dmg * Df.dmg, "speed": 22.0, "range": 34.0}, k * 0.04)
					s.sfx("smg", f.x, f.y)
	u.bfx = u.bfx.filter(func(f): return f.t < f.T)

static func set_st(e: Dictionary, st: int, t: float) -> void:
	e.st = st
	e.stT = t
	e.stM = t

# ---------------------------------------------------------------- 8.3 THE CUSTODIAN · Shelter 7

static func think_custodian(s, e: Dictionary, dt: float) -> Array:
	var u: Dictionary = s.game.us
	var P := CUS
	if not e.has("cu"):
		e.cu = {"stage": 1, "mop": 1.5, "crush": 3.0, "gas": 5.0, "turret": 2.5}
	var S: Dictionary = e.cu
	for k in ["mop", "crush", "gas", "turret"]:
		S[k] -= dt
	if e.get("inv", 0.0) > 0:
		e.inv -= dt
	if S.stage == 1 and e.hp <= e.max * 0.5:
		e.hp = e.max * 0.5
		S.stage = 2
		set_st(e, 64, P.transition)
		e.inv = P.transition
		u.bossStage = 1
		s.toast("THE CUSTODIAN · CASING CRACKED", "Red light. The doors crush in lanes now, gas floods a quarter of the hall, and a ceiling turret finds whoever hangs back.")
		s.sfx("horn", e.x, e.y)
		s.ev({"k": "shake", "x": e.x, "y": e.y, "amt": 8.0})
		return [true, null]
	if e.st == 64:
		e.stT -= dt
		if e.stT <= 0:
			e.st = 0
			e.speed = P.speed2
		return [true, null]
	if e.st == 63:   # the mop arc: a wedge, then the shock, and a strip of live water left where it swept
		e.stT -= dt
		if e.stT <= 0:
			e.st = 0
			var a0 := atan2(e.ly - e.y, e.lx - e.x)
			for a in foes(s):
				if in_wedge(a.x, a.y, e.x, e.y, a0, P.mop.r, P.mop.half):
					s.hurt_ally(a, P.mop.dmg * s.Df.dmg)
					a.stun = maxf(a.get("stun", 0.0), P.mop.slow)
			fx(s, "water", {"x": e.x, "y": e.y, "a": a0, "r": P.mop.r, "half": P.mop.half, "T": P.mop.strip})
			s.sfx("zap", e.x, e.y)
			s.ev({"k": "slash", "x": e.x, "y": e.y, "ax": cos(a0), "ay": sin(a0)})
		return [true, null]
	var f = near_foe(s, e)
	if f == null:
		return [false, null]
	var d := Vector2(f.x - e.x, f.y - e.y).length()
	s._aim_at(e, f.x, f.y)
	if S.stage == 2:
		var c := arena_c(s)
		var A: Dictionary = s.lay.arena
		if S.turret <= 0:
			var far = far_foe(s, c.x, c.y)
			if far != null:
				fx(s, "turret", {"x": c.x, "y": c.y, "x1": far.x, "y1": far.y, "warn": P.turret.tell, "T": P.turret.tell + 0.05})
				S.turret = P.turret.cd
				s.sfx("lock", c.x, c.y)
		if S.gas <= 0:
			var q := floori(s.rnd() * 4)
			var hx: float = A.w / 2.0
			var hy: float = A.h / 2.0
			var x0: float = A.x + 1 + (q & 1) * (hx - 1)
			var y0: float = A.y + 1 + (q >> 1) * (hy - 1)
			fx(s, "gas", {"x": x0, "y": y0, "x1": x0 + hx - 1, "y1": y0 + hy - 1, "warn": P.gas.tell, "T": P.gas.tell + P.gas.len})
			S.gas = P.gas.cd
			s.sfx("flood", x0 + hx / 2, y0 + hy / 2)
		if S.crush <= 0 and s.lay.blast.size() >= 2 and u.crush == null:
			var n: int = s.lay.blast.size()
			var a := floori(s.rnd() * n)
			var b := (a + 1 + floori(s.rnd() * (n - 1))) % n
			u.crush = {"doors": [a, b], "t": 0.0}
			S.crush = P.crush.cd
			s.sfx("siren", e.x, e.y)
	if d < P.mop.r - 0.4 and S.mop <= 0:
		set_st(e, 63, P.mop.tell)
		e.lx = f.x
		e.ly = f.y
		S.mop = P.mop.cd[S.stage - 1]
		s.sfx("lock", e.x, e.y)
		return [true, null]
	var far2 = (far_foe(s, e.x, e.y) if d > 6 else f)
	if far2 == null:
		far2 = f
	return [false, null if d < 1.4 else Vector2(far2.x, far2.y)]

# ---------------------------------------------------------------- 8.4 THE GATEKEEPER · Area 67

static func think_gatekeeper(s, e: Dictionary, dt: float) -> Array:
	if e.get("pilot", false):
		return think_pilot(s, e, dt)
	var u: Dictionary = s.game.us
	var P := GK
	if not e.has("gk"):
		e.gk = {"stage": 1, "rock": 2.0, "shield": 4.0, "stomp": 0.0, "pound": 3.0}
	var S: Dictionary = e.gk
	for k in ["rock", "shield", "stomp", "pound"]:
		S[k] -= dt
	if e.get("inv", 0.0) > 0:
		e.inv -= dt
	if e.get("shT", 0.0) > 0:
		e.shT -= dt
		if e.shT <= 0:
			e.ub = int(e.get("ub", 0)) & ~1
	if S.stage == 1 and e.hp <= e.max * 0.5:   # half health: the pilot ejects; the empty suit fights on, the pilot is a second target
		e.hp = e.max * 0.5
		S.stage = 2
		set_st(e, 72, P.transition)
		e.inv = P.transition
		u.bossStage = 1
		e.shT = 0.0
		e.ub = 0
		e.gk2 = true
		s.toast("THE GATEKEEPER · THE PILOT EJECTS", "The suit fights on empty and the pilot runs with a pistol. Bring down either one to end it.")
		s.sfx("horn", e.x, e.y)
		s.ev({"k": "shake", "x": e.x, "y": e.y, "amt": 8.0})
		return [true, null]
	if e.st == 72:
		e.stT -= dt
		if e.stT <= 0:
			e.st = 0
			e.speed = P.suit2
			spawn_pilot(s, e)
		return [true, null]
	if e.st == 71:
		e.stT -= dt
		if e.stT <= 0:
			e.st = 0
			fx(s, "circle", {"x": e.x, "y": e.y, "r": P.stomp.r, "dmg": P.stomp.dmg, "push": P.stomp.push, "T": 0.3})
		return [true, null]
	if e.st == 76:
		e.stT -= dt
		if e.stT <= 0:
			e.st = 0
			e.shT = P.shield.len
			e.ub = int(e.get("ub", 0)) | 1
			s.sfx("shieldhit", e.x, e.y)
		return [true, null]
	var f = near_foe(s, e)
	if f == null:
		return [false, null]
	var d := Vector2(f.x - e.x, f.y - e.y).length()
	s._aim_at(e, f.x, f.y)
	if S.stage == 1 and d < 2 and S.stomp <= 0:
		set_st(e, 71, P.stomp.tell)
		S.stomp = P.stomp.cd
		s.sfx("lock", e.x, e.y)
		return [true, null]
	if S.stage == 2 and d < 4 and S.pound <= 0:
		fx(s, "circle", {"x": f.x, "y": f.y, "r": P.pound.r, "dmg": P.pound.dmg, "push": 1.0, "warn": P.pound.tell, "T": P.pound.tell + 0.3})
		S.pound = P.pound.cd
		s.sfx("lock", f.x, f.y)
	if S.stage == 1 and S.shield <= 0 and d < 9:
		set_st(e, 76, P.shield.tell)
		S.shield = P.shield.cd
		return [true, null]
	if S.rock <= 0 and d < 12:
		var n: int = P.rockets.n[S.stage - 1]
		for k in n:
			var a: float = float(k) / n * TAU + s.rnd()
			var rr: float = (1.6 + s.rnd() * 0.8) if k else 0.0
			var x1 := clampf(f.x + cos(a) * rr, 0.5, s.N - 0.5)
			var y1 := clampf(f.y + sin(a) * rr, 0.5, s.N - 0.5)
			s.lobs.append({"x0": e.x, "y0": e.y, "x1": x1, "y1": y1, "t": 0.0, "T": maxf(P.rockets.tell, 0.6 + Vector2(x1 - e.x, y1 - e.y).length() * 0.05), "R": P.rockets.r, "power": P.rockets.power * s.Df.dmg, "k": 3, "own": null})
		S.rock = P.rockets.cd[S.stage - 1]
		s.sfx("rocket", e.x, e.y)
		return [true, null]
	return [false, null if d < 2.2 else Vector2(f.x, f.y)]

## the pilot: a second boss body (the same key, so the bar knows it), with 20% of the whole fight's health on top
static func spawn_pilot(s, suit: Dictionary) -> Dictionary:
	var x: float = suit.x + 1
	var y: float = suit.y + 0.5
	if s.solid_tile(int(x), int(y)):
		x = suit.x
		y = suit.y
	var hp: float = suit.max * GK.pilotHp
	var e := {"id": s.next_id, "type": "boss", "boss": "gatekeeper", "big": true, "x": x, "y": y, "hp": hp, "max": hp, "cd": 1.0, "walk": 0.0,
		"aim": Vector2(1, 0), "flash": 0.0, "speed": GK.pilot, "scanT": 0.0, "foe": null, "dead": false, "planted": false, "st": 0, "stT": 0.0,
		"stM": 1.0, "lx": x, "ly": y, "shots": 0, "ab": 3.0, "pilot": true, "gk2": true, "ub": 2, "rage": false, "dbl": false, "burrow": false,
		"sb": false, "fb": false, "us": {"home": [x, y], "st": "hunt", "sid": -s.next_id, "look": 0.0}}
	s.next_id += 1
	s.enemies.append(e)
	s.emit(x, y, "spark", 12)
	s.sfx("rocket", x, y)
	return e

## the pilot: quick, a three-shot sidearm with a line, a dodge roll every 4 s, keeps his distance
static func think_pilot(s, e: Dictionary, dt: float) -> Array:
	var P := GK
	if not e.has("gp"):
		e.gp = {"side": 1.0, "dive": P.dive.every}
	var S: Dictionary = e.gp
	S.side -= dt
	S.dive -= dt
	if e.st == 75:
		e.stT -= dt
		s.move_ent(e, e.cvx * dt, e.cvy * dt, false)
		e.walk += dt * 16
		if e.stT <= 0:
			e.st = 0
		return [true, null]
	if e.st == 74:
		e.stT -= dt
		s._aim_at(e, e.lx, e.ly)
		if e.stT <= 0:
			e.st = 0
			var a0 := atan2(e.ly - e.y, e.lx - e.x)
			for k in P.sidearm.n:
				s.fire(e, a0 + (k - 1) * 0.03, 1, {"dmg": P.sidearm.dmg * s.Df.dmg, "speed": 20.0, "range": 12.0}, k * 0.06)
			s.sfx("rifle", e.x, e.y)
		return [true, null]
	var f = near_foe(s, e)
	if f == null:
		return [false, null]
	var d := Vector2(f.x - e.x, f.y - e.y).length()
	s._aim_at(e, f.x, f.y)
	if S.dive <= 0:
		var a := atan2(e.y - f.y, e.x - f.x) + (1.2 if s.rnd() < 0.5 else -1.2)
		set_st(e, 75, P.dive.len)
		e.cvx = cos(a) * P.dive.speed
		e.cvy = sin(a) * P.dive.speed
		S.dive = P.dive.every
		s.sfx("roll", e.x, e.y)
		return [true, null]
	if S.side <= 0 and d < 10 and s.los_clear(e.x, e.y, f.x, f.y):
		set_st(e, 74, P.sidearm.tell)
		e.lx = f.x
		e.ly = f.y
		S.side = P.sidearm.cd
		return [true, null]
	if d < 4:
		return [false, Vector2(e.x + (e.x - f.x), e.y + (e.y - f.y))]
	return [false, Vector2(f.x, f.y) if d > 7 else null]

# ---------------------------------------------------------------- 8.5 THE VISITOR · the finale

static func think_visitor(s, e: Dictionary, dt: float) -> Array:
	var u: Dictionary = s.game.us
	var P := VIS
	if not e.has("vi"):
		e.vi = {"stage": 1, "pulse": 2.0, "tank": 3.5, "blink": 3.0, "swarm": 4.0, "well": 6.0}
	var S: Dictionary = e.vi
	var k: float = P.desperate if S.stage == 3 else 1.0
	for key in ["pulse", "tank", "blink", "swarm", "well"]:
		S[key] -= dt / k
	if e.get("inv", 0.0) > 0:
		e.inv -= dt
	if S.stage == 1 and e.hp <= e.max * 0.5:   # half health: the containment fails and the lights go out
		e.hp = e.max * 0.5
		S.stage = 2
		set_st(e, 82, P.transition)
		e.inv = P.transition
		u.bossStage = 1
		s.toast("THE VISITOR · THE FIELD FAILS", "The lights are out. A white flash shows where it lands next; light kills its drones.")
		s.sfx("horn", e.x, e.y)
		s.ev({"k": "shake", "x": e.x, "y": e.y, "amt": 10.0})
		return [true, null]
	if S.stage == 2 and e.hp <= e.max * 0.1:   # 10%: desperate, every cooldown x0.7
		S.stage = 3
		u.bossStage = 2
		e.speed = P.speed2 * 1.15
		s.toast("THE VISITOR · DESPERATE", "Everything it does comes faster now. Finish it.")
		s.sfx("siren", e.x, e.y)
	if e.st == 82:
		e.stT -= dt
		if e.stT <= 0:
			e.st = 0
			e.speed = P.speed2
		return [true, null]
	if e.st == 83:
		e.stT -= dt
		if e.stT <= 0:
			e.st = 0
			e.x = e.lx
			e.y = e.ly
			fx(s, "circle", {"x": e.x, "y": e.y, "r": P.blink.r, "dmg": P.blink.dmg, "push": 1.0, "T": 0.3})
			s.sfx("zap", e.x, e.y)
		return [true, null]
	var f = near_foe(s, e)
	if f == null:
		return [false, null]
	var d := Vector2(f.x - e.x, f.y - e.y).length()
	s._aim_at(e, f.x, f.y)
	if S.pulse <= 0 and d < P.pulse.max + 1:
		fx(s, "ring", {"x": e.x, "y": e.y, "warn": P.pulse.tell, "T": P.pulse.tell + P.pulse.max / P.pulse.speed})
		S.pulse = P.pulse.cd
		s.sfx("lock", e.x, e.y)
	if S.stage == 1 and S.tank <= 0:
		fx(s, "circle", {"x": f.x, "y": f.y, "r": P.tank.r, "dmg": P.tank.dmg, "warn": P.tank.tell, "T": P.tank.tell + 0.3, "tank": true})
		fx(s, "acid", {"x": f.x, "y": f.y, "r": P.tank.r, "warn": P.tank.tell, "T": P.tank.tell + P.tank.acidT})
		S.tank = P.tank.cd
		s.sfx("lob", e.x, e.y)
	if S.stage >= 2:
		if S.blink <= 0:
			var A: Dictionary = s.lay.arena
			var spot = null
			for n in 30:
				var x: float = A.x + 2 + s.rnd() * (A.w - 4)
				var y: float = A.y + 2 + s.rnd() * (A.h - 4)
				var dd := Vector2(x - f.x, y - f.y).length()
				if not s.solid_tile(int(x), int(y)) and dd > 2.5 and dd < 8:
					spot = Vector2(x, y)
					break
			if spot != null:
				set_st(e, 83, P.blink.tell)
				e.lx = spot.x
				e.ly = spot.y
				fx(s, "blink", {"x": e.lx, "y": e.ly, "warn": P.blink.tell, "T": P.blink.tell})
				S.blink = P.blink.cd
				s.sfx("mark", e.lx, e.ly)
				return [true, null]
		if S.swarm <= 0:
			drone_pack(s, e.x, e.y, P.swarm.n, true)
			S.swarm = P.swarm.cd
			s.toast("THE DRONES", "A swarm. Light them up: they take double damage in your light.")
			s.sfx("siren", e.x, e.y)
		if S.well <= 0 and d < P.well.r:
			fx(s, "well", {"x": e.x, "y": e.y, "warn": P.well.tell, "T": P.well.tell + P.well.len})
			S.well = P.well.cd
			s.sfx("charge", e.x, e.y)
	return [false, null if d < 3 else Vector2(f.x, f.y)]
