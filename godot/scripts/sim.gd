class_name Sim
extends RefCounted
## The host/solo simulation, ported from the browser build (v0.10.9, protocol yard-29).
## Phase 1 slice: the Yard on Normal, one Soldier, Delgado standing guard, riflemen raids.
## Function names follow the browser so the two can be read side by side:
##   06-world.js   pathing, collision, damage, explode
##   09-actions.js build, grenade, shoot/fire
##   10-phases-bosses.js startBuild/startRaid/spawnEnemyAt
##   12-players.js update(), simPlayer
##   14-raiders.js updateEnemies (rifle), updateBullets, updateLobs, updateWalls, updateNodes
## Not ported yet (later phases): the other raider types, bosses, Delgado's AI, perks/armory, mods, other maps, elevation.

const R_ENT := 0.27

var rng := RandomNumberGenerator.new()
var N := 16
var walls: Array = []          # Dictionary or null per tile, idx = j*N+i
var debris := PackedInt32Array()   # 0 = none, else mat+1
var dist := PackedFloat64Array()
var nodes: Array = []
var node_ix := {}
var core := {}
var core_k := 0
var player := {}
var qm := {}
var enemies: Array = []
var bullets: Array = []
var lobs: Array = []
var sacks: Array = []
var flow_dirty := false
var flow_t := 0.0
var next_id := 1
var bullet_seq := 0
var game := {}
var Df: Dictionary = Pal.DIFF.normal
var events: Array = []   # {k:'sfx'|'emit'|'flt'|'toast'|'flash'|'shake', ...}: drained by the client each frame
var charges: Array = []
var fires: Array = []
const ENAMES := {"rifle": ["rifleman", "riflemen"], "gren": ["grenadier", "grenadiers"], "breach": ["breacher", "breachers"], "shield": ["shieldbearer", "shieldbearers"], "medic": ["field medic", "field medics"], "spotter": ["spotter", "spotters"], "fire": ["firebrand", "firebrands"]}
const QM_RESERVE := [16, 8, 8]
const DELL_GUN := {"dmg": 6.0, "cd": 0.8, "spread": 0.2, "range": 6.0, "speed": 24.0, "pellets": 5, "fall": [2.5, 6.0, 0.55]}
const RIOT_SHIELD_HITS := 20


## Delgado's job plan holds callables bound to this sim; drop it so the sim can be freed
func dispose() -> void:
	if not qm.is_empty():
		qm.commandJob = null


func rnd() -> float:
	return rng.randf()


func idx(i: int, j: int) -> int:
	return j * N + i


func inb(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < N and j < N


func hdist(x0: float, y0: float, x1: float, y1: float) -> float:
	return Vector2(x1 - x0, y1 - y0).length()


func d2(a: Dictionary, b: Dictionary) -> float:
	return hdist(a.x, a.y, b.x, b.y)


func ev(e: Dictionary) -> void:
	events.append(e)


func sfx(name: String, x: float = -1.0, y: float = -1.0) -> void:
	ev({"k": "sfx", "name": name, "x": x, "y": y})


func emit(x: float, y: float, kind: String, n: int = 1, mat: int = 0) -> void:
	ev({"k": "emit", "x": x, "y": y, "kind": kind, "n": n, "mat": mat})


func flt(x: float, y: float, text: String, col: String = "#e8dcc0") -> void:
	ev({"k": "flt", "x": x, "y": y, "text": text, "col": col})


func toast(title: String, body: String) -> void:
	ev({"k": "toast", "title": title, "body": body})


# ---------------------------------------------------------------- new game

func new_game(seed_v: int = -1, diff: String = "normal") -> void:
	dispose()
	if seed_v >= 0:
		rng.seed = seed_v
	else:
		rng.randomize()
	Df = Pal.DIFF[diff]
	N = 16
	walls.clear()
	walls.resize(N * N)
	debris = PackedInt32Array()
	debris.resize(N * N)
	dist = PackedFloat64Array()
	dist.resize(N * N)
	enemies.clear()
	bullets.clear()
	lobs.clear()
	sacks.clear()
	charges.clear()
	fires.clear()
	events.clear()
	# THE YARD (06b-maps.js MAPS.yard.lay, offset 0,0)
	core = {"i": 4, "j": 11, "hp": float(Df.core), "max": float(Df.core), "flash": 0.0}
	core_k = idx(core.i, core.j)
	nodes = []
	for t in [[2, 7], [7, 13], [6, 6], [9, 9], [1, 13], [10, 4], [13, 14]]:
		nodes.append({"i": t[0], "j": t[1], "type": 0, "amt": 48, "max": 48, "rt": 0.0, "locked": false, "solid": false})
	nodes.append({"i": 11, "j": 11, "type": 1, "locked": true, "unlock": 2, "solid": true})
	nodes.append({"i": 12, "j": 7, "type": 2, "locked": true, "unlock": 4, "solid": true})
	node_ix.clear()
	for n in nodes:
		node_ix[idx(n.i, n.j)] = n
	for r in [[[[3, 9], [4, 9], [5, 9]], 0, 0.63, 0.25], [[[8, 6], [8, 7], [11, 9]], 1, 0.55, 0.3]]:
		for t in r[0]:
			var w := Pal.make_wall(r[1], false, r[2])
			w.char = r[3]
			walls[idx(t[0], t[1])] = w
	game = {"phase": "build", "timer": 40.0 + Df.build, "wave": 0, "waves": Pal.WAVES, "queue": [], "spawnT": 0.0, "spawnGap": 1.1,
		"time": 0.0, "sel": 0, "piece": "wall", "won": false, "paused": false,
		"stats": {"built": 0, "lost": 0, "dropped": 0, "revives": 0, "repairs": 0}}
	player = make_player(0)
	var sp := [[5.5, 11.5], [5.5, 12.5], [3.5, 12.5], [4.5, 12.5], [5.5, 10.5], [3.5, 10.5]]
	player.x = sp[0][0] + core.i - 4
	player.y = sp[0][1] + core.j - 11
	# 04-state-armory.js newGame; mode '' is the browser default (defend the stake), H switches to follow
	qm = {"id": "dell", "x": 3.5, "y": 11.5, "hp": 180.0, "max": 180.0, "alive": true, "revive": 0.0, "aim": Vector2(1, 0), "face": Vector2(1, 0),
		"cd": 0.0, "sup": 8.0, "gt": 0.0, "work": 0.0, "job": "", "jobKey": "", "next": -1, "pathT": 0.0, "scanT": 0.0, "planT": 0.0, "bcd": 0.0,
		"foe": null, "walk": 0.0, "flash": 0.0, "mats": [24, 0, 0], "hurt": 9.0, "mode": "", "status": "", "completedRaids": 0,
		"commandJob": null, "layout": null, "layoutSize": 4, "C": {"build": 1.0, "repair": 1.0}, "markT": 0.0}
	compute_flow()


func make_player(id: int) -> Dictionary:
	var C: Dictionary = Pal.SOLDIER
	return {"id": id, "name": "YOU", "cls": "soldier", "C": C, "gun": C.gun, "x": 0.0, "y": 0.0, "hp": C.hp, "max": C.hp,
		"alive": true, "downed": false, "revive": 0.0, "rt": 0.0, "mats": [24, 0, 0], "cap": C.cap.duplicate(),
		"nades": C.nades, "maxN": C.nades, "ncd": 0.0, "blast": C.blast, "cd": 0.0, "bcd": 0.0, "gt": 0.0, "bLeft": 0,
		"hurt": 9.0, "flash": 0.0, "walk": 0.0, "face": Vector2(1, 0), "aim": Vector2(1, 0), "fire_in": false,
		"up_d": 0, "sal": 0, "kills": 0, "move_dir": Vector2(1, 0), "markT": 0.0}


# ---------------------------------------------------------------- pathing

func node_at(i: int, j: int):
	if not inb(i, j):
		return null
	return node_ix.get(idx(i, j))


func enter_cost(k: int) -> float:
	if k == core_k:
		return 0.0
	var w = walls[k]
	if w != null:
		return 1.0 + w.hp / 8.0
	var n = node_at(k % N, k / N)
	if n != null and n.solid:
		return 1e6
	return 1.4 if debris[k] != 0 else 1.0


## Dijkstra toward the stake over D4 neighbours: each step costs what it takes to enter the tile being left
## (the browser adds enterCost(u) on relaxing from u; bestStep then adds the neighbour's own cost).
func compute_flow() -> void:
	var n := N * N
	dist.fill(1e9)
	var done := PackedByteArray()
	done.resize(n)
	dist[core_k] = 0.0
	var heap: Array = [[0.0, core_k]]
	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var bv: float = top[0]
		var uk: int = top[1]
		if done[uk] or bv > dist[uk]:
			continue
		done[uk] = 1
		var ui := uk % N
		var uj := uk / N
		var c := enter_cost(uk)
		for d in Pal.D4:
			var i: int = ui + d[0]
			var j: int = uj + d[1]
			if not inb(i, j):
				continue
			var k := idx(i, j)
			var nv := bv + c
			if nv < dist[k]:
				dist[k] = nv
				_heap_push(heap, [nv, k])


func _heap_push(h: Array, item: Array) -> void:
	h.append(item)
	var c := h.size() - 1
	while c > 0:
		var p := (c - 1) >> 1
		if h[p][0] <= item[0]:
			break
		h[c] = h[p]
		c = p
	h[c] = item


func _heap_pop(h: Array) -> Array:
	var top: Array = h[0]
	var last: Array = h.pop_back()
	if h.is_empty():
		return top
	var c := 0
	var n := h.size()
	while true:
		var m := c * 2 + 1
		if m >= n:
			break
		if m + 1 < n and h[m + 1][0] < h[m][0]:
			m += 1
		if h[m][0] >= last[0]:
			break
		h[c] = h[m]
		c = m
	h[c] = last
	return top


func mark_flow() -> void:
	if not flow_dirty:
		flow_dirty = true
		flow_t = 0.3


func best_step(ti: int, tj: int) -> int:
	var best := -1
	var bv := 1e9
	for d in Pal.D4:
		var i: int = ti + d[0]
		var j: int = tj + d[1]
		if not inb(i, j):
			continue
		var k := idx(i, j)
		var v := dist[k] + enter_cost(k)
		if v < bv:
			bv = v
			best = k
	return best


# ---------------------------------------------------------------- collision

## team: false for raiders (doors are walls), true for the crew (doors open)
func solid_tile(i: int, j: int, team: bool) -> bool:
	if not inb(i, j):
		return true
	var k := idx(i, j)
	if k == core_k:
		return true
	var w = walls[k]
	if w != null:
		return not (team and w.door)
	var n = node_at(i, j)
	return n != null and n.solid


func collides(x: float, y: float, r: float, team: bool) -> bool:
	if x - r < 0 or y - r < 0 or x + r > N or y + r > N:
		return true
	for i in range(floori(x - r), floori(x + r) + 1):
		for j in range(floori(y - r), floori(y + r) + 1):
			if solid_tile(i, j, team):
				return true
	return false


func move_ent(e: Dictionary, dx: float, dy: float, team: bool) -> void:
	if not collides(e.x + dx, e.y, R_ENT, team):
		e.x += dx
	if not collides(e.x, e.y + dy, R_ENT, team):
		e.y += dy


func los_clear(x0: float, y0: float, x1: float, y1: float) -> bool:
	var d := hdist(x0, y0, x1, y1)
	var st := ceili(d / 0.2)
	var last := -1
	var skipped := false
	for s in range(1, st):
		var t := float(s) / st
		var x := x0 + (x1 - x0) * t
		var y := y0 + (y1 - y0) * t
		var i := int(x)
		var j := int(y)
		if not inb(i, j):
			return false
		var k := idx(i, j)
		if k == core_k:
			return false
		var n = node_at(i, j)
		if n != null and n.solid:
			return false
		var w = walls[k]
		if w != null and k != last:
			last = k
			if not skipped and d * t < 1.35:
				skipped = true
				continue
			if Pal.wall_state(w) == 0:
				return false
	return true


# ---------------------------------------------------------------- damage

func damage_wall(k: int, amt: float, own = null) -> void:
	var w = walls[k]
	if w == null or w.mat == 3:
		return
	w.hp -= amt
	w.flash = 0.08
	mark_flow()
	if w.hp <= 0:
		walls[k] = null
		debris[k] = w.mat + 1
		game.stats.lost += 1
		var i := k % N
		var j := k / N
		if own is int and own == player.id and not w.crew:   # wallPays: the old ruins pay, your own walls never do
			var v: int = Pal.WALL_SALVAGE[w.mat]
			player.sal += v
			flt(i + 0.5, j + 0.3, "+%d SALVAGE · %s DOWN" % [v, Pal.MAT[w.mat].name], "#e2b436")
		emit(i + 0.5, j + 0.5, "chunk", 14, w.mat)
		emit(i + 0.5, j + 0.5, "dust", 6, w.mat)
		sfx("collapse", i + 0.5, j + 0.5)
		ev({"k": "shake", "x": i + 0.5, "y": j + 0.5, "amt": 5.0})


func any_up(p: Dictionary) -> bool:
	return qm.alive


func hurt_player(p: Dictionary, d: float) -> void:
	if not p.alive:
		return
	p.hp -= d
	p.hurt = 0.0
	p.flash = 0.1
	sfx("hurt")
	emit(p.x, p.y, "blood")
	if p.hp <= 0:
		var help := any_up(p)
		p.alive = false
		p.downed = true
		p.hp = 0.0
		p.revive = 0.0
		p.rt = 10.0 if help else 4.0
		toast("DOWN", "Hang on. Delgado or a teammate can pick you up." if help else "Back at the stake in a few seconds.")


func hurt_qm(d: float) -> void:
	if not qm.alive:
		return
	qm.hp -= d
	qm.hurt = 0.0
	qm.flash = 0.1
	emit(qm.x, qm.y, "blood")
	if qm.hp <= 0:
		qm.alive = false
		qm.hp = 0.0
		qm.revive = 0.0
		flt(qm.x, qm.y, "DELGADO IS DOWN", "#d65a3a")
		toast("DELGADO IS DOWN", "Stand over him to get him back up.")


func hurt_ally(a: Dictionary, d: float) -> void:
	if is_same(a, qm):
		hurt_qm(d)
	else:
		hurt_player(a, d)


func hurt_enemy(e: Dictionary, d: float, own = null) -> void:
	e.hp -= d
	e.flash = 0.08
	emit(e.x, e.y, "blood")
	if e.hp <= 0 and not e.get("dead", false):
		e.dead = true
		game.stats.dropped += 1
		sfx("drop", e.x, e.y)
		emit(e.x, e.y, "blood", 6)
		if own is int and own == player.id:
			player.kills += 1


func hurt_stake(d: float) -> void:
	core.hp -= d
	core.flash = 0.12
	sfx("core", core.i + 0.5, core.j + 0.5)
	emit(core.i + 0.5, core.j + 0.5, "spark")


func explode(x: float, y: float, R: float = 1.65, power: float = 1.0, own = null) -> void:
	sfx("bigboom" if power > 1.2 else "boom", x, y)
	ev({"k": "shake", "x": x, "y": y, "amt": 9.0 * power})
	ev({"k": "flash", "x": x, "y": y, "life": 0.4, "r": R})
	emit(x, y, "fire", int(22 * power))
	emit(x, y, "smoke", int(10 * power))
	var fall := func(dd: float) -> float: return 1.0 if dd < 0.7 else maxf(0.0, 1.0 - (dd - 0.7) / (R - 0.7))
	for i in range(floori(x - R - 1), floori(x + R + 1) + 1):
		for j in range(floori(y - R - 1), floori(y + R + 1) + 1):
			if not inb(i, j):
				continue
			var k := idx(i, j)
			var f: float = fall.call(hdist(x, y, i + 0.5, j + 0.5))
			if f <= 0:
				continue
			var w = walls[k]
			if w != null:
				if w.mat == 0 and f > 0.25:
					w.fire = 6.0
					w.fire_by = own
				damage_wall(k, 80.0 * f * power * Pal.MAT[w.mat].blast, own)
	var fc: float = fall.call(hdist(x, y, core.i + 0.5, core.j + 0.5))
	if fc > 0:
		hurt_stake(48.0 * fc * power)
	for e in enemies:
		var f: float = fall.call(hdist(x, y, e.x, e.y))
		if f > 0:
			hurt_enemy(e, 62.0 * f * power, own)
	for a in allies():
		if not a.alive:
			continue
		var f: float = fall.call(hdist(x, y, a.x, a.y))
		if f > 0:
			hurt_ally(a, 50.0 * f * power * (0.8 if is_same(a, qm) else 1.0))


func allies() -> Array:
	var out: Array = []
	if player.alive:
		out.append(player)
	if qm.alive:
		out.append(qm)
	return out


# ---------------------------------------------------------------- building (09-actions.js)

func build_target(p: Dictionary, sel: int, door: bool) -> Dictionary:
	var f: Vector2 = p.face
	var ox := int(signf(f.x)) if absf(f.x) > 0.38 else 0
	var oy := int(signf(f.y)) if absf(f.y) > 0.38 else 0
	if ox == 0 and oy == 0:
		ox = 1
	return build_eval(p, floori(p.x) + ox, floori(p.y) + oy, sel, door)


func build_eval(p: Dictionary, i: int, j: int, sel: int, door: bool) -> Dictionary:
	var t := {"i": i, "j": j, "ok": false, "act": "PLACE", "mat": sel, "cost": 0, "door": door, "reason": ""}
	if not p.alive:
		t.reason = "You are down"
		return t
	if not inb(i, j):
		t.reason = "That is the fence line"
		return t
	var k := idx(i, j)
	if k == core_k:
		t.reason = "That is the stake"
		return t
	if node_at(i, j) != null:
		t.reason = "Resource in the way"
		return t
	var near := func(o: Dictionary) -> bool: return absf(o.x - (i + 0.5)) < 0.77 and absf(o.y - (j + 0.5)) < 0.77
	for e in enemies:
		if near.call(e):
			t.reason = "Raider in the way"
			return t
	var w = walls[k]
	if not door and w == null:
		if near.call(qm):
			t.reason = "Delgado is standing there"
			return t
	if w == null:
		t.cost = Pal.DOOR_COST if door else Pal.WALL_COST
		t.act = "DOOR" if door else "PLACE"
	elif sel > w.mat:
		t.act = "UPGRADE"
		t.door = w.door
		t.cost = Pal.DOOR_COST if w.door else Pal.WALL_COST
	elif w.hp < w.max - 0.5:
		t.act = "REPAIR"
		t.mat = w.mat
		t.door = w.door
		t.cost = maxi(1, roundi((Pal.DOOR_COST if w.door else Pal.WALL_COST) * (1.0 - w.hp / w.max)))
	elif door != w.door:
		t.act = "MAKE DOOR" if door else "SEAL DOOR"
		t.mat = w.mat
		t.cost = Pal.DOOR_COST - Pal.WALL_COST if door else 0
	else:
		t.act = "SOLID"
		t.mat = w.mat
		t.reason = ("Already " + Pal.MAT[w.mat].name.to_lower()) if sel < w.mat else "At full strength"
		return t
	if p.mats[t.mat] < t.cost:
		t.reason = "Need %d %s" % [t.cost, Pal.MAT[t.mat].name.to_lower()]
		return t
	t.ok = true
	return t


func do_build(p: Dictionary, i: int, j: int, sel: int, door: bool) -> void:
	if p.bcd > 0:
		return
	if hdist(p.x, p.y, i + 0.5, j + 0.5) > 2.1:
		return
	var t := build_eval(p, i, j, clampi(sel, 0, 2), door)
	if not t.ok:
		sfx("deny")
		return
	var k := idx(t.i, t.j)
	var prev = walls[k]
	if t.act == "REPAIR":
		prev.hp = prev.max
		prev.fire = 0.0
	elif t.act == "MAKE DOOR" or t.act == "SEAL DOOR":
		var nw := Pal.make_wall(prev.mat, t.door, prev.hp / prev.max)
		nw.char = prev.char
		walls[k] = nw
	else:
		walls[k] = Pal.make_wall(t.mat, t.door)
		walls[k].flash = 0.1
		debris[k] = 0
	walls[k].crew = true   # a wall a player built on, fixed or changed is theirs now: it won't pay salvage
	if collides(p.x, p.y, R_ENT, true):
		var ok := false
		for s in range(1, 11):
			var nx: float = p.x - p.face.x * 0.1 * s
			var ny: float = p.y - p.face.y * 0.1 * s
			if not collides(nx, ny, R_ENT, true):
				p.x = nx
				p.y = ny
				ok = true
				break
		if not ok:
			walls[k] = prev
			sfx("deny")
			return
	p.mats[t.mat] -= t.cost
	var C: Dictionary = p.C
	p.bcd = Pal.MAT[t.mat].cd * (C.build if t.mat == 0 else (C.build + 1.0) / 2.0)
	if t.act == "PLACE" or t.act == "DOOR":
		game.stats.built += 1
	mark_flow()
	sfx("place%d" % t.mat, t.i + 0.5, t.j + 0.5)
	emit(t.i + 0.5, t.j + 0.5, "spark" if t.mat == 2 else ("dust" if t.mat == 1 else "splinter"), 5, t.mat)


func local_build() -> void:
	var p := player
	if not p.alive or game.phase == "over":
		return
	var t := build_target(p, game.sel, game.piece == "door")
	do_build(p, t.i, t.j, game.sel, game.piece == "door")


func throw_nade(p: Dictionary, tx: float, ty: float) -> void:
	if not p.alive or p.nades <= 0 or p.ncd > 0:
		sfx("deny")
		return
	var dx: float = tx - p.x
	var dy: float = ty - p.y
	var d0 := Vector2(dx, dy).length()
	if d0 == 0:
		d0 = 1.0
	var m := d0 * minf(1.0, 6.5 / maxf(hdist(p.x, p.y, tx, ty), 1e-9))
	tx = clampf(p.x + dx / d0 * m, 0.3, N - 0.3)
	ty = clampf(p.y + dy / d0 * m, 0.3, N - 0.3)
	var d := hdist(p.x, p.y, tx, ty)
	var R := 1.65 * (1.15 if p.C.blast > 1 else 1.0)
	lobs.append({"x0": p.x, "y0": p.y, "x1": tx, "y1": ty, "t": 0.0, "T": 0.5 + d * 0.08, "R": R, "power": p.blast, "own": p.id})
	p.nades -= 1
	p.ncd = p.C.nadeCd
	sfx("lob", p.x, p.y)


# ---------------------------------------------------------------- shooting

func shoot(p: Dictionary, G: Dictionary, late: float) -> void:
	var a := atan2(p.aim.y, p.aim.x)
	fire(p, a + (rnd() - 0.5) * G.spread, 0, G, late)


func fire(from: Dictionary, ang: float, team: int, gun: Dictionary, late: float = 0.0, quiet: bool = false) -> void:
	var ahead: float = 0.33 + gun.speed * clampf(late, 0.0, 0.25)
	var own = from.id if from.has("id") else null
	bullet_seq += 1
	bullets.append({"id": bullet_seq, "x": from.x + cos(ang) * ahead, "y": from.y + sin(ang) * ahead,
		"vx": cos(ang) * gun.speed, "vy": sin(ang) * gun.speed, "team": team, "dmg": gun.dmg, "dist": ahead - 0.33,
		"over": gun.get("over", true), "skipped": false, "last": -1, "range": gun.range, "own": own, "dead": false,
		"fall": gun.get("fall"), "pel": gun.get("pellets", 1) > 1, "shield_contact": -1})
	if not quiet:
		ev({"k": "flash", "x": from.x + cos(ang) * 0.4, "y": from.y + sin(ang) * 0.4, "life": 0.06, "r": 1.3 if gun.get("pellets", 1) > 1 else 0.9, "muzzle": true})


# ---------------------------------------------------------------- the frame (12-players.js update)

## controls: {move: Vector2 (world dir * magnitude 0..1), aim: Vector2 world dir or ZERO, fire: bool}
func update(dt: float, ctl: Dictionary = {}) -> void:
	dt = minf(dt, 0.05)
	if game.phase == "over" or game.paused:
		return
	game.time += dt
	core.flash = maxf(0.0, core.flash - dt)
	if game.phase == "build":
		game.timer -= dt
		if game.timer <= 0:
			start_raid()
	else:
		if not game.queue.is_empty():
			game.spawnT -= dt
			if game.spawnT <= 0:
				spawn_enemy(game.queue.pop_front())
				game.spawnT = game.spawnGap
		elif enemies.is_empty() and charges.is_empty():
			qm.completedRaids = maxi(qm.completedRaids, game.wave)
			if game.wave >= game.waves:
				end_game(true)
				return
			start_build(24.0 + Df.build)
	if flow_dirty:
		flow_t -= dt
		if flow_t <= 0:
			compute_flow()
			flow_dirty = false
	control_local(dt, ctl)
	sim_player(player, dt)
	update_qm(dt)
	update_enemies(dt)
	update_bullets(dt)
	update_lobs(dt)
	update_charges(dt)
	update_fires(dt)
	update_walls(dt)
	update_nodes(dt)
	if core.hp <= 0 and game.phase != "over":
		core.hp = 0.0
		explode(core.i + 0.5, core.j + 0.5, 1.8, 1.3)
		end_game(false)


func control_local(dt: float, ctl: Dictionary) -> void:
	var p := player
	p.fire_in = false
	if not p.alive:
		return
	var mv: Vector2 = ctl.get("move", Vector2.ZERO)
	var mag := minf(1.0, mv.length())
	if mag > 0.12:
		var d := mv.normalized()
		var sp: float = 3.3 * mag * p.C.spd
		move_ent(p, d.x * sp * dt, d.y * sp * dt, true)
		p.walk += dt * mag * 10.0
		p.move_dir = d
	var aim: Vector2 = ctl.get("aim", Vector2.ZERO)
	if aim != Vector2.ZERO:
		p.aim = aim.normalized()
		p.face = p.aim
	elif mag > 0.12:
		p.face = p.move_dir
		p.aim = p.move_dir
	p.fire_in = ctl.get("fire", false)


func sim_player(p: Dictionary, dt: float) -> void:
	p.hurt += dt
	p.cd = maxf(p.cd - dt, -dt)
	p.bcd -= dt
	p.gt = maxf(p.gt - dt, -dt)
	p.ncd -= dt
	p.flash = maxf(0.0, p.flash - dt)
	if not p.alive:
		p.bLeft = 0
		if not p.downed:
			return
		if p.revive >= 2.2:
			revive_player(p)
			return
		p.rt -= dt
		if p.rt <= 0:
			var m: Array = []
			for v in p.mats:
				m.append(v / 2)
			if m.any(func(v): return v > 0):
				sacks.append({"x": p.x, "y": p.y, "mats": m})
			for i in 3:
				p.mats[i] -= m[i]
			var at := respawn_at()
			p.x = at.x
			p.y = at.y
			p.alive = true
			p.downed = false
			p.hp = p.max
			p.hurt = 9.0
			p.revive = 0.0
			toast("BACK AT THE STAKE", "Half your pack is in a sack where you fell." if m.any(func(v): return v > 0) else "")
		return
	var G: Dictionary = p.gun
	var want: bool = p.fire_in
	if want or p.bLeft > 0:
		var n := 0
		while p.cd <= 0 and n < 6:
			if G.get("burst", false):
				if not (p.bLeft > 0):
					if not want:
						break
					p.bLeft = Pal.burst_n(p.up_d)
				p.bLeft -= 1
			shoot(p, G, -p.cd)
			p.cd += Pal.burst_gap(p.up_d) if G.get("burst", false) and p.bLeft == 0 else G.cd
			n += 1
		if n > 0:
			sfx("ar", p.x, p.y)
	else:
		p.cd = maxf(p.cd, 0.0)
	for nd in nodes:
		if nd.locked or (nd.type == 0 and nd.amt <= 0):
			continue
		var d := hdist(p.x, p.y, nd.i + 0.5, nd.j + 0.5)
		if d < (1.3 if nd.solid else 1.05) and p.gt <= 0 and p.mats[nd.type] < p.cap[nd.type]:
			var y: int = mini(Pal.YIELD[nd.type], p.cap[nd.type] - p.mats[nd.type])
			if nd.type == 0:
				y = mini(y, nd.amt)
			p.mats[nd.type] += y
			if nd.type == 0:
				nd.amt -= y
			p.gt += Pal.RATE[nd.type] * p.C.get("gather", 1.0)
			emit(nd.i + 0.5, nd.j + 0.5, "splinter" if nd.type == 0 else ("dust" if nd.type == 1 else "spark"), 1, nd.type)
	for s in range(sacks.size() - 1, -1, -1):
		var sk: Dictionary = sacks[s]
		if hdist(sk.x, sk.y, p.x, p.y) < 0.7:
			for m in 3:
				p.mats[m] = mini(p.cap[m], p.mats[m] + sk.mats[m])
			sacks.remove_at(s)
			flt(p.x, p.y, "PACK RECOVERED")
	if p.hurt > Pal.REGEN_AFTER:
		p.hp = minf(p.max, p.hp + Pal.REGEN * dt)


func revive_player(p: Dictionary) -> void:
	p.alive = true
	p.downed = false
	p.hp = p.max * 0.45
	p.hurt = 0.0
	p.revive = 0.0
	game.stats.revives += 1
	flt(p.x, p.y, "REVIVED", "#a9bccb")


func respawn_at() -> Vector2:
	for s in [[5.5, 11.5], [5.5, 12.5], [3.5, 12.5], [4.5, 12.5], [5.5, 10.5], [3.5, 10.5]]:
		var x: float = s[0] + core.i - 4
		var y: float = s[1] + core.j - 11
		if not collides(x, y, R_ENT, true):
			return Vector2(x, y)
	return Vector2(core.i + 1.5, core.j + 0.5)


## Delgado stands his post at the stake for now; his gathering and repair AI (13-dell.js) is a later phase.
func update_qm(dt: float) -> void:
	var q := qm
	q.cd = maxf(q.cd - dt, -dt)
	q.sup -= dt
	q.pathT -= dt
	q.gt = maxf(q.gt - dt, -dt)
	q.scanT -= dt
	q.hurt += dt
	q.flash = maxf(0.0, q.flash - dt)
	q.bcd = maxf(0.0, q.bcd - dt)
	q.planT -= dt
	for w in walls:
		if w != null and w.get("skip", 0.0) > 0:
			w.skip -= dt
	if not q.alive:
		if player.alive and d2(player, q) < 1.0:
			q.revive += dt
			if q.revive >= 2:
				q.alive = true
				q.hp = q.max * 0.45
				q.revive = 0.0
				game.stats.revives += 1
				flt(q.x, q.y, "DELGADO IS UP", "#a9bccb")
				sfx("revive", q.x, q.y)
		else:
			q.revive = maxf(0.0, q.revive - dt * 0.5)
		return
	if q.hurt > 5:
		q.hp = minf(q.max, q.hp + 3 * dt)
	var DG: Dictionary = DELL_GUN
	if q.scanT <= 0:
		q.scanT = 0.2
		q.foe = null
		var bd := maxf(5.2, DG.range * 0.9)
		for e in enemies:
			var d := d2(e, q)
			if d < bd and los_clear(q.x, q.y, e.x, e.y):
				bd = d
				q.foe = e
	if q.foe != null and q.foe.dead:
		q.foe = null
	if q.planT <= 0 or q.commandJob == null:
		q.commandJob = qm_command_job()
		q.planT = 0.25
	var job: Dictionary = q.commandJob
	var key: String = job.name + ":" + str(job.get("k", job.get("node", {}).get("i", "") if job.has("node") else ""))
	if key != q.jobKey:
		q.job = job.name
		q.jobKey = key
		q.work = 0.0
		q.pathT = 0.0
	var here := tile_of(q)
	var busy := false
	var reached: bool = job.goal.call(here) if job.get("hold", false) else hdist(q.x, q.y, job.pt.x, job.pt.y) <= job.near
	if reached:
		match job.name:
			"revive":
				busy = true
				if job.who.downed:
					job.who.revive += dt
			"construct":
				busy = true
				q.face = q.aim
				var b: Dictionary = job.build
				do_build(q, b.i, b.j, b.mat, b.door)
				q.planT = 0.0
			"repair":
				busy = true
				q.work += dt
				var w = walls[job.k]
				if w != null and q.work >= 0.9:
					q.work = 0.0
					if w.fire > 0:
						w.fire = 0.0
						flt(job.pt.x, job.pt.y, "DOUSED", "#a9bccb")
					else:
						w.hp = minf(w.max, w.hp + w.max * 0.45)
						q.mats[w.mat] -= 2
						game.stats.repairs += 1
						flt(job.pt.x, job.pt.y, "REPAIRED", "#a9bccb")
					mark_flow()
					sfx("place%d" % w.mat, job.pt.x, job.pt.y)
			"gather":
				var n: Dictionary = job.node
				if q.gt <= 0:
					var y: int = Pal.YIELD[n.type]
					if n.type == 0:
						y = mini(y, n.amt)
					q.mats[n.type] += y
					if n.type == 0:
						n.amt -= y
					q.gt += Pal.RATE[n.type] * 1.5
					emit(n.i + 0.5, n.j + 0.5, "splinter" if n.type == 0 else ("dust" if n.type == 1 else "spark"), 1, n.type)
			"handoff":
				var p: Dictionary = job.who
				var got: Array = []
				for m in 3:
					var give: int = maxi(0, mini(q.mats[m] - QM_RESERVE[m], p.cap[m] - p.mats[m]))
					q.mats[m] -= give
					p.mats[m] += give
					if give > 0:
						got.append("+%d %s" % [give, Pal.MAT[m].name])
				if not got.is_empty():
					flt(p.x, p.y, " ".join(got), "#e2b436")
					sfx("restock", p.x, p.y)
	else:
		if q.pathT <= 0:
			q.pathT = 0.25
			q.next = team_path(here % N, here / N, job.goal)
		if q.next >= 0:
			var tgt: Vector2
			if q.next == here and job.goal.call(here):
				tgt = job.get("pt", Vector2(here % N + 0.5, here / N + 0.5))
			else:
				tgt = Vector2(q.next % N + 0.5, q.next / N + 0.5)
			var dx: float = tgt.x - q.x
			var dy: float = tgt.y - q.y
			var l := Vector2(dx, dy).length()
			if l > 0.03:
				var s := minf(l, 2.9 * dt)
				move_ent(q, dx / l * s, dy / l * s, true)
				q.walk += dt * 9.0
				if q.foe == null:
					q.aim = Vector2(dx / l, dy / l)
		elif job.name == "repair":
			var w = walls[job.k]
			if w != null:
				w.skip = 4.0
	if q.foe != null:
		var dx: float = q.foe.x - q.x
		var dy: float = q.foe.y - q.y
		var l := Vector2(dx, dy).length()
		if l == 0:
			l = 1.0
		q.aim = Vector2(dx / l, dy / l)
		if not busy and q.cd <= 0:
			var a := atan2(dy, dx)
			while q.cd <= 0:
				for i in DG.pellets:
					fire(q, a + (float(i) / (DG.pellets - 1) - 0.5) * DG.spread + (rnd() - 0.5) * DG.spread * 0.3, 0, DG, -q.cd, i > 0)
				q.cd += DG.cd
			sfx("shotgun", q.x, q.y)
	if q.sup <= 0:
		var p := player
		if p.alive and d2(p, q) < 1.7 and (p.nades < p.maxN or p.hp < p.max * 0.7):
			p.nades = mini(p.maxN + 1, p.nades + 1)
			p.hp = minf(p.max, p.hp + 35)
			flt(p.x, p.y, "RESTOCK · +1 NADE", "#e2b436")
			sfx("restock", p.x, p.y)
			q.sup = 30.0


# ---------------------------------------------------------------- raid flow (10-phases-bosses.js)

func start_build(dur: float) -> void:
	qm.completedRaids = maxi(qm.completedRaids, game.wave)
	qm.planT = 0.0
	qm.commandJob = null
	game.phase = "build"
	game.timer = dur
	var pay: int = 8 + game.wave
	player.sal += pay
	var p := player
	p.nades = maxi(p.nades, p.maxN)
	if p.downed:
		p.alive = true
		p.downed = false
		p.revive = 0.0
	p.hp = p.max
	if not qm.alive:
		qm.alive = true
		var at := spawn_near_core()
		qm.x = at.x
		qm.y = at.y
		flt(qm.x, qm.y, "DELGADO IS BACK", "#a9bccb")
	qm.hp = qm.max
	var note := "Grenades refilled. Delgado will head out for materials."
	for n in nodes:
		if n.locked and n.unlock == game.wave + 1:
			n.locked = false
			note = "A brick kiln is lit. Brick soaks rifle fire." if n.type == 1 else "Scrap metal is open. It shrugs off bullets."
	if game.wave == 2:
		note += " Breachers join the next raid. Shoot them before they reach a wall."
	toast("RAID %d BROKEN" % game.wave, "+%d salvage each. %s" % [pay, note])


func start_raid() -> void:
	game.wave += 1
	game.phase = "raid"
	var k: int = game.wave
	var W := wave_mix(k, 1, Df.extra)
	var q: Array = []
	for n in W.rifle:
		q.append("rifle")
	for t in ["gren", "fire", "shield", "medic", "spotter", "breach"]:
		for n in W[t]:
			q.insert(1 + floori(rnd() * q.size()), t)
	game.queue = q
	game.spawnT = 0.8
	game.spawnGap = 1.1
	sfx("siren")
	var bits: Array = ["%d riflemen" % W.rifle]
	for t in ["gren", "breach", "shield", "medic", "spotter", "fire"]:
		if W[t] > 0:
			bits.append("%d %s" % [W[t], ENAMES[t][1] if W[t] > 1 else ENAMES[t][0]])
	toast("RAID %d" % k, "%s coming over the east fence." % ", ".join(bits))


func spawn_tile() -> Array:
	var groups: Array = [{"w": 0.6, "tiles": []}, {"w": 0.4, "tiles": []}]
	for s in range(0, mini(N, 12)):
		groups[0].tiles.append([N - 1, s])
	for s in range(6, N):
		groups[1].tiles.append([s, 0])
	var r := rnd()
	var grp: Dictionary = groups[groups.size() - 1]
	for s in groups:
		if r < s.w:
			grp = s
			break
		r -= s.w
	for a in 20:
		var t: Array = grp.tiles[floori(rnd() * grp.tiles.size())]
		if not solid_tile(t[0], t[1], false):
			return t
	for s in groups:
		for t in s.tiles:
			if not solid_tile(t[0], t[1], false):
				return t
	return []


func spawn_enemy(type: String) -> void:
	var t := spawn_tile()
	if t.is_empty():
		return
	spawn_enemy_at(type, t[0] + 0.5, t[1] + 0.5)


func spawn_enemy_at(type: String, x: float, y: float) -> Dictionary:
	var T: Dictionary = Pal.ETYPES.get(type, Pal.ETYPES.rifle)
	var s: float = (1.0 + 0.07 * (game.wave - 1)) * Df.hp
	var e := {"id": next_id, "type": type, "x": x, "y": y, "hp": T.hp * s, "max": T.hp * s, "cd": 1.0 + rnd(), "walk": rnd() * 6.0,
		"aim": Vector2(-1, 0), "flash": 0.0, "speed": T.speed, "scanT": 0.0, "foe": null, "dead": false, "planted": false, "fleeT": 0.0}
	next_id += 1
	if type == "medic":
		e.ab = 1.5
	if type == "spotter":
		e.st = 0
		e.stT = 0.0
		e.stM = 1.0
		e.lx = x
		e.ly = y
	if type == "shield":
		e.shieldHitsMax = RIOT_SHIELD_HITS
		e.shieldHitsLeft = RIOT_SHIELD_HITS
		e.shieldBroken = false
	enemies.append(e)
	return e


func end_game(win: bool) -> void:
	if game.phase == "over":
		return
	game.phase = "over"
	game.won = win
	sfx("win" if win else "lose")
	bullets.clear()
	lobs.clear()
	charges.clear()
	fires.clear()
	toast("VICTORY" if win else "THE STAKE FELL", "Every raid broken." if win else "They got through.")


# ---------------------------------------------------------------- raiders (14-raiders.js)

func update_enemies(dt: float) -> void:
	for a in allies():
		if a.markT > 0:
			a.markT -= dt
	for e in enemies:
		if e.dead:
			continue
		e.cd = maxf(e.cd - dt, -dt)
		e.flash = maxf(0.0, e.flash - dt)
		e.scanT -= dt
		var ti := int(e.x)
		var tj := int(e.y)
		var tgt = null
		var move_to = null
		if absi(ti - core.i) <= 1 and absi(tj - core.j) <= 1:
			tgt = Vector2(core.i + 0.5, core.j + 0.5)
		else:
			var k := best_step(ti, tj)
			if k >= 0:
				var c := Vector2(k % N + 0.5, k / N + 0.5)
				if walls[k] != null:
					tgt = c
				else:
					move_to = c
		if e.scanT <= 0:
			e.scanT = 0.2
			e.foe = null
			var bd: float = {"gren": 6.5, "spotter": 10.0, "medic": 5.0, "fire": 6.5}.get(e.type, 7.0)
			# spotted: riflemen go for the marked soldier first
			if e.type == "rifle":
				for a in allies():
					if a.markT > 0:
						var d := d2(a, e)
						if d < bd + 3 and los_clear(e.x, e.y, a.x, a.y):
							e.foe = a
							bd = -1.0
							break
			if bd >= 0:
				for a in allies():
					var d := d2(a, e)
					if d < bd and los_clear(e.x, e.y, a.x, a.y):
						bd = d
						e.foe = a
		if e.foe != null and not e.foe.alive:
			e.foe = null
		var engaging := false
		match e.type:
			"rifle":
				# a spotter's mark tightens their aim a lot (0.2 rad spread down to 0.06) and adds a little range
				if e.foe != null:
					engaging = true
					var mk: bool = e.foe.markT > 0
					var a := _aim_at(e, e.foe.x, e.foe.y)
					if e.cd <= 0:
						while e.cd <= 0:
							fire(e, a + (rnd() - 0.5) * (0.06 if mk else 0.2), 1, {"dmg": 8.0 * Df.dmg, "speed": 22.0, "range": 13.0 if mk else 11.0}, -e.cd)
							e.cd += 0.65 + rnd() * 0.45
						sfx("rifle", e.x, e.y)
				elif tgt != null:
					var a := _aim_at(e, tgt.x, tgt.y)
					if e.cd <= 0:
						while e.cd <= 0:
							fire(e, a + (rnd() - 0.5) * 0.1, 1, {"dmg": 7.0 * Df.dmg, "speed": 22.0, "range": 11.0, "over": false}, -e.cd)
							e.cd += 0.6 + rnd() * 0.3
						sfx("rifle", e.x, e.y)
			"gren":
				var lt = Vector2(e.foe.x, e.foe.y) if e.foe != null and d2(e.foe, e) < 7.0 else look_ahead(e)
				if lt != null:
					_aim_at(e, lt.x, lt.y)
				if e.cd <= 0 and lt != null:
					var tx := clampf(lt.x + (rnd() - 0.5) * 0.8, 0.3, N - 0.3)
					var ty := clampf(lt.y + (rnd() - 0.5) * 0.8, 0.3, N - 0.3)
					var d := hdist(e.x, e.y, tx, ty)
					lobs.append({"x0": e.x, "y0": e.y, "x1": tx, "y1": ty, "t": 0.0, "T": 0.55 + d * 0.08, "R": 1.65, "power": Df.dmg, "own": null})
					e.cd += 3.1 + rnd() * 1.2
					sfx("lob", e.x, e.y)
				if e.foe != null and d2(e.foe, e) < 3.5:
					engaging = true
			"shield":
				# keeps walking the path with the shield turned to whoever is shooting at him, pistol over the top; at a wall he bashes it
				if e.foe != null:
					var a := _aim_at(e, e.foe.x, e.foe.y)
					if e.cd <= 0 and d2(e.foe, e) < 6.5:
						fire(e, a + (rnd() - 0.5) * 0.22, 1, {"dmg": 6.0 * Df.dmg, "speed": 20.0, "range": 7.0}, 0.0)
						e.cd = 1.1 + rnd() * 0.5
						sfx("rifle", e.x, e.y)
				if tgt != null and hdist(tgt.x, tgt.y, e.x, e.y) < 1.3:
					if e.foe == null:
						_aim_at(e, tgt.x, tgt.y)
					engaging = true
					if e.cd <= 0:
						e.cd = 1.2
						var k := idx(floori(tgt.x), floori(tgt.y))
						if e.shieldBroken:
							var a := _aim_at(e, tgt.x, tgt.y)
							fire(e, a, 1, {"dmg": 6.0 * Df.dmg, "speed": 20.0, "range": 7.0}, 0.0)
							sfx("rifle", e.x, e.y)
						else:
							if walls[k] != null:
								damage_wall(k, 16.0 * Pal.MAT[walls[k].mat].bullet)
							elif k == core_k:
								hurt_stake(6.0 * Df.dmg)
							sfx("hit1", tgt.x, tgt.y)
			"medic":
				# hangs back behind the nearest raider and patches up everyone near him every 1.6 s
				e.ab -= dt
				var buddy = null
				var bb := 1e9
				for o in enemies:
					if not is_same(o, e) and not o.dead and o.type != "medic":
						var d := d2(o, e)
						if d < bb:
							bb = d
							buddy = o
				if e.ab <= 0:
					e.ab = 1.6
					var healed := 0
					for o in enemies:
						if not o.dead and o.hp < o.max and d2(o, e) < 2.6:
							o.hp = minf(o.max, o.hp + o.max * 0.14)
							healed += 1
					if healed > 0:
						ev({"k": "ring", "x": e.x, "y": e.y, "r0": 0.2, "r1": 2.6, "life": 0.5, "c1": "#8fe0a0", "c2": "#2e7a48"})
						sfx("medpulse", e.x, e.y)
				if e.foe != null and d2(e.foe, e) < 5:
					var a := _aim_at(e, e.foe.x, e.foe.y)
					if e.cd <= 0:
						fire(e, a + (rnd() - 0.5) * 0.25, 1, {"dmg": 5.0 * Df.dmg, "speed": 20.0, "range": 6.0}, 0.0)
						e.cd = 1.3 + rnd() * 0.4
						sfx("rifle", e.x, e.y)
				if buddy != null and bb > 1.6 and bb < 8:
					move_to = Vector2(buddy.x, buddy.y)
				elif buddy != null and bb <= 1.6:
					move_to = null
					engaging = true
			"spotter":
				# sits back at 6-9 tiles; after 0.8 s with someone in sight he marks them for as long as he can see them
				var f = e.foe
				if f != null:
					var d := d2(f, e)
					_aim_at(e, f.x, f.y)
					e.lx = f.x
					e.ly = f.y
					if e.st == 0:
						e.st = 1
						e.stT = 0.8
						e.stM = 0.8
						sfx("mark", e.x, e.y)
					elif e.st == 1:
						e.stT -= dt
						if e.stT <= 0:
							e.st = 2
							e.stT = 0.0
							flt(f.x, f.y, "SPOTTED", "#ff5a4a")
					if e.st == 2:
						f.markT = 0.35
					if d < 5.5:
						var l := d if d > 0 else 1.0
						move_to = Vector2(clampf(e.x + (e.x - f.x) / l, 0.5, N - 0.5), clampf(e.y + (e.y - f.y) / l, 0.5, N - 0.5))
					elif d < 9.5:
						move_to = null
						engaging = true
				elif e.st != 0:
					e.st = 0
					e.stT = 0.0
			"fire":
				# lobs fire bottles at the wooden wall in his way (or at people close by)
				var lt = null
				if e.foe != null and d2(e.foe, e) < 6.5:
					lt = Vector2(e.foe.x, e.foe.y)
				else:
					var la = look_ahead(e)
					if la != null:
						var w = walls[idx(floori(la.x), floori(la.y))]
						if w != null and w.mat == 0 and not (w.fire > 0):
							lt = la
				if lt != null:
					_aim_at(e, lt.x, lt.y)
				if e.cd <= 0 and lt != null:
					var tx := clampf(lt.x + (rnd() - 0.5) * 0.6, 0.3, N - 0.3)
					var ty := clampf(lt.y + (rnd() - 0.5) * 0.6, 0.3, N - 0.3)
					var d := hdist(e.x, e.y, tx, ty)
					lobs.append({"x0": e.x, "y0": e.y, "x1": tx, "y1": ty, "t": 0.0, "T": 0.5 + d * 0.08, "R": 1.0, "power": Df.dmg, "k": 1, "own": null})
					e.cd += 3.6 + rnd() * 1.2
					sfx("lob", e.x, e.y)
				if lt != null and hdist(lt.x, lt.y, e.x, e.y) < 5:
					engaging = true
			_:
				# breacher: run the satchel to the wall, then run
				if not e.planted and tgt != null:
					if hdist(tgt.x, tgt.y, e.x, e.y) < 1.35:
						charges.append({"x": e.x + (tgt.x - e.x) * 0.45, "y": e.y + (tgt.y - e.y) * 0.45, "fuse": 2.4, "beep": 0.0})
						e.planted = true
						e.fleeT = 5.0
						sfx("plant", e.x, e.y)
						flt(e.x, e.y, "SATCHEL", "#d65a3a")
					else:
						move_to = tgt
				if e.planted:
					e.fleeT -= dt
					if e.fleeT <= 0:
						e.planted = false
						flt(e.x, e.y, "RE-ARMED", "#d65a3a")
				if e.planted:
					var bk := -1
					var bv := -1.0
					for dd in Pal.D4:
						var i: int = ti + dd[0]
						var j: int = tj + dd[1]
						if not inb(i, j) or solid_tile(i, j, false):
							continue
						var k := idx(i, j)
						if dist[k] > bv:
							bv = dist[k]
							bk = k
					move_to = Vector2(bk % N + 0.5, bk / N + 0.5) if bk >= 0 else null
		if not engaging and move_to != null:
			var dx: float = move_to.x - e.x
			var dy: float = move_to.y - e.y
			var l := Vector2(dx, dy).length()
			if l > 0.02:
				var s := minf(l, e.speed * dt)
				move_ent(e, dx / l * s, dy / l * s, false)
				e.walk += dt * 9.0
				if tgt == null and e.foe == null:
					e.aim = Vector2(dx / l, dy / l)
	for a in enemies.size():
		for b in range(a + 1, enemies.size()):
			var A: Dictionary = enemies[a]
			var B: Dictionary = enemies[b]
			var dx: float = B.x - A.x
			var dy: float = B.y - A.y
			var d := Vector2(dx, dy).length()
			if d < 0.5 and d > 0.001:
				var push := (0.5 - d) * 0.5
				move_ent(A, -dx / d * push, -dy / d * push, false)
				move_ent(B, dx / d * push, dy / d * push, false)
	enemies = enemies.filter(func(e): return not e.dead)


func _aim_at(e: Dictionary, x: float, y: float) -> float:
	var dx: float = x - e.x
	var dy: float = y - e.y
	var l := Vector2(dx, dy).length()
	if l == 0:
		l = 1.0
	e.aim = Vector2(dx / l, dy / l)
	return atan2(dy, dx)


func update_bullets(dt: float) -> void:
	for b in bullets:
		var sp := Vector2(b.vx, b.vy).length()
		var steps := ceili(sp * dt / 0.15)
		for s in steps:
			if b.dead:
				break
			b.x += b.vx * dt / steps
			b.y += b.vy * dt / steps
			b.dist += sp * dt / steps
			var i := floori(b.x)
			var j := floori(b.y)
			if not inb(i, j) or b.dist > b.range:
				b.dead = true
				break
			var k := idx(i, j)
			if k == core_k:
				if b.team == 1:
					hurt_stake(6.0 * Df.dmg)
				else:
					emit(b.x, b.y, "spark")
				b.dead = true
				break
			var n = node_at(i, j)
			if n != null and n.solid:
				emit(b.x, b.y, "spark" if n.type == 2 else "dust", 2, n.type)
				b.dead = true
				break
			var w = walls[k]
			if w != null and k != b.last:
				b.last = k
				if b.over and not b.skipped and b.dist < 1.3:
					b.skipped = true
				else:
					var st := Pal.wall_state(w)
					if rnd() >= (0.0 if st == 0 else (0.35 if st == 1 else 0.65)):
						var mult := 0.25 if b.team == 0 else 1.0
						damage_wall(k, bdmg(b) * Pal.MAT[w.mat].bullet * mult, b.own)
						emit(b.x, b.y, "splinter" if w.mat == 0 else ("dust" if w.mat == 1 else "spark"), 3, w.mat)
						sfx("hit%d" % w.mat, b.x, b.y)
						b.dead = true
						break
			if b.team == 0:
				for e in enemies:
					if not e.dead and Vector2(e.x - b.x, e.y - b.y).length() < 0.34:
						# a shieldbearer's shield covers his front (about 130°): the round sparks off it
						if e.type == "shield" and not e.shieldBroken:
							var l := sp if sp > 0 else 1.0
							if -(b.vx * e.aim.x + b.vy * e.aim.y) / l > 0.42:
								shield_bullet_hit(e, b)
								emit(b.x, b.y, "spark", 2, 2)
								sfx("shieldhit", b.x, b.y)
								b.dead = true
								break
						hurt_enemy(e, bdmg(b), b.own)
						b.dead = true
						break
			else:
				for a in allies():
					if Vector2(a.x - b.x, a.y - b.y).length() < 0.3:
						hurt_ally(a, b.dmg * (0.7 if is_same(a, qm) else 1.0))
						b.dead = true
						break
	bullets = bullets.filter(func(b): return not b.dead)


func update_lobs(dt: float) -> void:
	for l in lobs:
		l.t += dt
		if l.t >= l.T:
			l.dead = true
			if l.get("k", 0) == 1:
				bottle_land(l)
			else:
				explode(l.x1, l.y1, l.R, l.power, l.own)
	lobs = lobs.filter(func(l): return not l.get("dead", false))


func update_walls(dt: float) -> void:
	for k in N * N:
		var w = walls[k]
		if w == null:
			continue
		w.flash = maxf(0.0, w.flash - dt)
		if w.fire > 0:
			w.fire -= dt
			w.char = minf(1.0, w.char + dt * 0.14)
			var i := k % N
			var j := k / N
			if rnd() < dt * 0.45:
				for d in Pal.D4:
					var ni: int = i + d[0]
					var nj: int = j + d[1]
					if not inb(ni, nj):
						continue
					var nw = walls[idx(ni, nj)]
					if nw != null and nw.mat == 0 and nw.fire <= 0 and rnd() < 0.5:
						nw.fire = 6.0
						nw.fire_by = w.fire_by
			damage_wall(k, 9.0 * dt, w.fire_by)


func update_nodes(dt: float) -> void:
	for n in nodes:
		if n.type == 0 and n.amt <= 0:
			n.rt += dt
			if n.rt > 25:
				n.amt = n.max
				n.rt = 0.0



func set_qm_mode(mode: String) -> void:
	if game.phase == "over":
		return
	qm.mode = mode
	qm.job = ""
	qm.jobKey = ""
	qm.pathT = 0.0
	qm.planT = 0.0
	qm.commandJob = null


func bdmg(b: Dictionary) -> float:
	if b.fall == null:
		return b.dmg
	var a: float = b.fall[0]
	var z: float = b.fall[1]
	var m: float = b.fall[2]
	var d: float = b.dist
	return b.dmg * (1.0 if d <= a else (m if d >= z else 1.0 - (1.0 - m) * (d - a) / (z - a)))


func spawn_near_core() -> Vector2:
	for d in [[1, 0], [0, 1], [-1, 0], [0, -1], [1, 1], [-1, -1], [1, -1], [-1, 1], [2, 0], [0, 2], [-2, 0], [0, -2]]:
		var i: int = core.i + d[0]
		var j: int = core.j + d[1]
		if not solid_tile(i, j, true):
			return Vector2(i + 0.5, j + 0.5)
	return Vector2(core.i + 1.5, core.j + 0.5)


func wave_mix(k: int, P: int, extra: int) -> Dictionary:
	var W := {"rifle": maxi(2, 2 + k + extra) + roundi((P - 1) * (1.5 + k * 0.45)),
		"gren": maxi(0, k - 1) + ((P - 1) / 3 if k >= 2 else 0),
		"breach": ((k - 2 + (1 if extra > 0 else 0)) if k >= 3 else 0) + ((P - 1) / 3 if k >= 3 else 0),
		"fire": (1 + (k - 2) / 3 + (1 if P >= 4 else 0)) if k >= 2 else 0,
		"shield": (1 + (k - 3) / 3 + (1 if P >= 4 else 0)) if k >= 3 else 0,
		"medic": (1 + (k - 4) / 4) if k >= 4 else 0,
		"spotter": (1 + (k - 6) / 5 + (1 if P >= 5 else 0)) if k >= 6 else 0}
	W.rifle = maxi(maxi(2, ceili(W.rifle * 0.35)), W.rifle - W.fire - W.shield - W.medic - W.spotter)   # riflemen stay at least a third
	return W


func shield_bullet_hit(e: Dictionary, b: Dictionary) -> bool:
	if e.shieldBroken or b.shield_contact == e.id:
		return false
	b.shield_contact = e.id
	e.shieldHitsLeft = maxi(0, e.shieldHitsLeft - 1)
	if e.shieldHitsLeft == 0:
		e.shieldBroken = true
		emit(e.x, e.y, "spark", 6)
		sfx("collapse", e.x, e.y)
		flt(e.x, e.y, "SHIELD BROKEN", "#d9e9e6")
	return true


func look_ahead(e: Dictionary):
	var ti := int(e.x)
	var tj := int(e.y)
	for s in 8:
		if absi(ti - core.i) <= 1 and absi(tj - core.j) <= 1:
			var d := hdist(e.x, e.y, core.i + 0.5, core.j + 0.5)
			return Vector2(core.i + 0.5, core.j + 0.5) if d < 6.5 else null
		var k := best_step(ti, tj)
		if k < 0:
			return null
		var i := k % N
		var j := k / N
		if walls[k] != null:
			var d := hdist(e.x, e.y, i + 0.5, j + 0.5)
			return Vector2(i + 0.5, j + 0.5) if d < 6.5 else null
		ti = i
		tj = j
	return null


func bottle_land(l: Dictionary) -> void:
	var R := 1.3
	fires.append({"x": l.x1, "y": l.y1, "t": 5.0, "max": 5.0, "tick": 0.3, "r": 0.9})
	sfx("bottle", l.x1, l.y1)
	ev({"k": "flash", "x": l.x1, "y": l.y1, "life": 0.3, "r": 1.0})
	emit(l.x1, l.y1, "fire", 10)
	for i in range(floori(l.x1 - R), floori(l.x1 + R) + 1):
		for j in range(floori(l.y1 - R), floori(l.y1 + R) + 1):
			if not inb(i, j):
				continue
			var w = walls[idx(i, j)]
			if w != null and w.mat == 0 and hdist(i + 0.5, j + 0.5, l.x1, l.y1) < R and not (w.fire > 0):
				w.fire = 6.0
				w.fire_by = null


func update_charges(dt: float) -> void:
	for c in charges:
		c.fuse -= dt
		c.beep -= dt
		if c.beep <= 0:
			c.beep = maxf(0.12, c.fuse * 0.25)
			sfx("beep", c.x, c.y)
		if c.fuse <= 0:
			c.dead = true
			explode(c.x, c.y, 2.1, 1.6)
	charges = charges.filter(func(c): return not c.get("dead", false))


func update_fires(dt: float) -> void:
	for f in fires:
		f.t -= dt
		f.tick -= dt
		if f.tick <= 0:
			f.tick = 0.45
			for a in allies():
				if a.alive and hdist(a.x, a.y, f.x, f.y) < f.r:
					hurt_ally(a, 6.0 * Df.dmg)
			var w = walls[idx(floori(f.x), floori(f.y))]
			if w != null and w.mat == 0 and not (w.fire > 0):
				w.fire = 5.0
	fires = fires.filter(func(f): return f.t > 0)


func tile_of(e: Dictionary) -> int:
	return idx(floori(e.x), floori(e.y))


func adj4(k: int, t: int) -> bool:
	return absi(k % N - t % N) + absi(k / N - t / N) == 1


func team_path(si: int, sj: int, is_goal: Callable) -> int:
	var s := idx(si, sj)
	if is_goal.call(s):
		return s
	var prev := PackedInt32Array()
	prev.resize(N * N)
	prev.fill(-1)
	prev[s] = s
	var q: Array = [s]
	var h := 0
	while h < q.size():
		var k: int = q[h]
		h += 1
		if is_goal.call(k):
			var c := k
			while prev[c] != s:
				c = prev[c]
			return c
		var i := k % N
		var j := k / N
		for d in Pal.D4:
			var ni: int = i + d[0]
			var nj: int = j + d[1]
			if not inb(ni, nj) or solid_tile(ni, nj, true):
				continue
			var nk := idx(ni, nj)
			if prev[nk] != -1:
				continue
			prev[nk] = k
			q.append(nk)
	return -1


func qm_reach(goal: Callable) -> bool:
	var k := tile_of(qm)
	return inb(k % N, k / N) and team_path(k % N, k / N, goal) >= 0


func qm_safe_placement(b: Dictionary) -> bool:
	var k := idx(b.i, b.j)
	if b.door or walls[k] != null:
		return true
	var starts: Array = []
	if player.alive or player.downed:
		starts.append(player)
	starts.append(qm)
	var ci: int = core.i
	var cj: int = core.j
	var goals: Array = [func(t): return maxi(absi(t % N - ci), absi(t / N - cj)) > 2, func(t): return maxi(absi(t % N - ci), absi(t / N - cj)) == 1]
	var reachable := func(p, goal): return team_path(floori(p.x), floori(p.y), goal) >= 0
	var before: Array = []
	for p in starts:
		before.append(goals.map(func(g): return reachable.call(p, g)))
	var prev = walls[k]
	walls[k] = {"door": false}
	var ok := true
	for i in starts.size():
		for j in goals.size():
			if before[i][j] and not reachable.call(starts[i], goals[j]):
				ok = false
	walls[k] = prev
	return ok


func qm_can_revive(p: Dictionary) -> bool:
	if not qm.alive or not p.downed:
		return false
	var px: float = p.x
	var py: float = p.y
	return hdist(qm.x, qm.y, px, py) < 0.9 or qm_reach(func(k): return hdist(k % N + 0.5, k / N + 0.5, px, py) < 0.9)


func qm_layout() -> Array:
	if qm.layout != null:
		return qm.layout
	var make := func(n: int) -> Array:
		var a: Array = []
		for y in n:
			for x in n:
				if x == 0 or y == 0 or x == n - 1 or y == n - 1:
					var i: int = core.i - 1 + x
					var j: int = core.j - 1 + y
					a.append({"i": i, "j": j, "k": idx(i, j), "door": x == 1 or y == 1})
		return a
	var legal := func(t) -> bool: return inb(t.i, t.j) and t.k != core_k and node_at(t.i, t.j) == null
	var four: Array = make.call(4)
	var three: Array = make.call(3)
	qm.layoutSize = 4 if four.all(legal) else 3
	var L: Array = (four if qm.layoutSize == 4 else three).filter(legal)
	L.sort_custom(func(a, b): return (int(a.door) > int(b.door)) or (a.door == b.door and a.k < b.k))
	qm.layout = L
	return L


func qm_gather(mat: int, limit: float = INF):
	var ns: Array = nodes.filter(func(n): return n.type == mat and not n.locked and (mat != 0 or n.amt > 0) and hdist(qm.x, qm.y, n.i + 0.5, n.j + 0.5) <= limit)
	ns.sort_custom(func(a, b): return hdist(a.i + 0.5, a.j + 0.5, qm.x, qm.y) < hdist(b.i + 0.5, b.j + 0.5, qm.x, qm.y))
	for n in ns:
		var nk := idx(n.i, n.j)
		var goal := func(k): return k == nk if mat == 0 else adj4(k, nk)
		if qm_reach(goal):
			return {"name": "gather", "node": n, "goal": goal, "pt": Vector2(n.i + 0.5, n.j + 0.5), "near": 0.9 if mat == 0 else 1.3}
	return null


func qm_command_job() -> Dictionary:
	var q := qm
	var host := player
	var follow: bool = q.mode == "follow"
	if player.downed and qm_can_revive(player):
		var px: float = player.x
		var py: float = player.y
		return {"name": "revive", "who": player, "goal": func(k): return hdist(k % N + 0.5, k / N + 0.5, px, py) < 0.9, "pt": Vector2(px, py), "near": 0.9}
	var layout := qm_layout()
	var allowed := {}
	for t in layout:
		allowed[t.k] = true
	for k in walls.size():
		var w = walls[k]
		if w == null or w.get("skip", 0.0) > 0 or w.mat > 2 or not (w.fire > 0 or w.hp / w.max < 0.7):
			continue
		var c := Vector2(k % N + 0.5, k / N + 0.5)
		var out_of_reach: bool = hdist(host.x, host.y, c.x, c.y) > 3 if follow else not allowed.has(k)
		if out_of_reach:
			continue
		if q.mats[w.mat] < 2 and not (w.fire > 0):
			continue
		var kk := k
		var goal := func(t): return adj4(t, kk)
		if qm_reach(goal):
			return {"name": "repair", "k": k, "goal": goal, "pt": c, "near": 1.35}
	if not follow and game.phase == "build":
		var tier := mini(2, q.completedRaids / 5)
		var need := -1
		var blocked := false
		for t in layout:
			var w = walls[t.k]
			if w != null and w.mat >= tier:
				continue
			var mat: int = mini(tier, w.mat + 1) if w != null else tier
			var tk: int = t.k
			var goal := func(k): return adj4(k, tk)
			var b := build_eval(q, t.i, t.j, mat, w.door if w != null else t.door)
			if not b.ok:
				if b.reason.begins_with("Need"):
					need = mat
				else:
					blocked = true
				continue
			if qm_reach(goal) and qm_safe_placement(b):
				q.status = "Upgrading perimeter" if w != null else "Building perimeter"
				return {"name": "construct", "k": t.k, "goal": goal, "pt": Vector2(t.i + 0.5, t.j + 0.5), "near": 1.35, "build": b}
			blocked = true
		if need >= 0:
			q.status = "Gathering " + Pal.MAT[need].name.to_lower()
			var job = qm_gather(need)
			if job != null:
				return job
			q.status = "Waiting for " + Pal.MAT[need].name.to_lower()
		else:
			q.status = "Perimeter partly blocked" if blocked else "Perimeter ready"
	else:
		q.status = "Following you" if follow else "Defending core"
	if follow:
		if game.phase == "build" and d2(q, host) < 3:
			var needy := false
			for m in 3:
				if q.mats[m] > QM_RESERVE[m] and host.mats[m] < host.cap[m]:
					needy = true
			if host.alive and needy:
				return {"name": "handoff", "who": host, "goal": func(k): return k == tile_of(host), "pt": Vector2(host.x, host.y), "near": 1.3}
			if q.mats[0] < 16:
				var job = qm_gather(0, 3)
				if job != null:
					return job
		return {"name": "follow", "goal": func(k): return hdist(k % N + 0.5, k / N + 0.5, host.x, host.y) <= 1.8 and not solid_tile(k % N, k / N, true), "hold": true, "pt": Vector2(host.x, host.y)}
	var ci: int = core.i
	var cj: int = core.j
	return {"name": "hold", "goal": func(k): return maxi(absi(k % N - ci), absi(k / N - cj)) <= 2 and not solid_tile(k % N, k / N, true), "hold": true}