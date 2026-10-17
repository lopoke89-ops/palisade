class_name UiKit
extends RefCounted
## The menus' look, after the browser's desktop layout (dev/src/style.css, the body.desk and #menu.partyMenu /
## #menu.cardMenu rules): its two typefaces (Big Shoulders Stencil Display and IBM Plex Mono), its palette, and the
## buttons, panels, segmented pickers, sliders and toggles every page is built from.
## Every size here is a CSS pixel of the browser's 1600x900 desktop layout; `k` turns it into screen pixels, so the
## whole layout scales with the window (as the browser's desktop layout does) and nothing reflows or overflows.
## Text is laid out at its scaled size (not drawn small and stretched), so it stays sharp at any window size.

# the lobby shell's palette (#menu.partyMenu / .cardMenu override --bone, --dim, --warn and --line)
const BONE := Color("#edf1e9")
const DIM := Color("#9eb1b7")
const WARN := Color("#efd347")
const LINE := Color("#354e59")
const PLINE := Color("#354b56")   # the side panels' border
const PANEL := Color(6 / 255.0, 15 / 255.0, 23 / 255.0, 0.84)
const ROWBG := Color(22 / 255.0, 38 / 255.0, 48 / 255.0, 0.92)
const ROWLINE := Color("#3c5360")
const SUB := Color("#a8bec4")
const KEYC := Color("#b7c9cf")
const NAVSEL := Color("#eaf4ef")
const NAVINK := Color("#142731")
const INKT := Color("#17140f")
const TITLE := Color("#f2f6ef")
const FRAME := Color("#496067")
# the overlays' palette (pause, the after-action screen, the armory, the case opening, the old panel of TABLES)
const OBONE := Color("#dcd2ba")
const ODIM := Color("#9a8f7a")
const OWARN := Color("#e2b436")
const OLINE := Color("#3a3228")
const RUST := Color("#b0512f")
const OPANEL := Color(27 / 255.0, 24 / 255.0, 20 / 255.0, 0.8)

const FACES := {"s6": "res://fonts/big-shoulders-stencil-display-600.woff2", "s8": "res://fonts/big-shoulders-stencil-display-800.woff2",
	"s9": "res://fonts/big-shoulders-stencil-display-900.woff2", "m4": "res://fonts/ibm-plex-mono-400.woff2", "m6": "res://fonts/ibm-plex-mono-600.woff2"}

static var k := 1.0   # screen pixels per CSS pixel
static var mouse_ui := true   # the last input was the mouse: focus rings hide (the browser's :focus-visible)
static var FOCUS: StyleBoxFlat   # the focus ring every button shares; its colour turns off for the mouse
static var _face := {}
static var _var := {}
static var _ls := {}
static var _tex := {}


## the scale for a window: the 1600x900 layout fitted inside it
static func fit(W: float, H: float) -> void:
	var nk := clampf(minf(W / 1600.0, H / 900.0), 0.45, 3.0)
	if not is_equal_approx(nk, k):
		k = nk
		_ls.clear()
		_var.clear()
		_tex.clear()
		FOCUS = null


static func px(v: float) -> float:
	return roundf(v * k)


## a border or line width: never thinner than one pixel
static func bw(v: float) -> int:
	return maxi(1, roundi(v * k)) if v > 0 else 0


static func fs(v: float) -> int:
	return maxi(6, roundi(v * k))


static func face(f: String) -> Font:
	if not _face.has(f):
		_face[f] = load(FACES.get(f, FACES.m4))
	return _face[f]


## a face with CSS letter-spacing (in em of the given size)
static func font(f: String, size: float = 13.0, em: float = 0.0) -> Font:
	var sp := roundi(em * size * k)
	if sp == 0:
		return face(f)
	var key := "%s|%d" % [f, sp]
	if not _var.has(key):
		var v := FontVariation.new()
		v.base_font = face(f)
		v.spacing_glyph = sp
		_var[key] = v
	return _var[key]


## label settings: face, CSS size, colour, letter-spacing (em) and line height (em; 0 = the font's own)
static func ls(f: String, size: float, col: Color, em: float = 0.0, lh: float = 0.0, outline: float = 0.0, ocol: Color = Color.BLACK) -> LabelSettings:
	var key := "%s|%s|%s|%s|%s|%s|%s" % [f, size, col.to_html(), em, lh, outline, ocol.to_html()]
	if _ls.has(key):
		return _ls[key]
	var s := LabelSettings.new()
	s.font = font(f, size, em)
	s.font_size = fs(size)
	s.font_color = col
	s.line_spacing = maxf(0.0, lh * size * k - face(f).get_height(fs(size))) if lh > 0 else 0.0
	if outline > 0:
		s.outline_size = bw(outline)
		s.outline_color = ocol
	_ls[key] = s
	return s


static func lbl(text: String, f: String, size: float, col: Color, em: float = 0.0, lh: float = 0.0, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.label_settings = ls(f, size, col, em, lh)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 1
	return l


## a flat box: background, border (all sides or [t, r, b, l]) and padding in CSS order [t, r, b, l]
static func sb(bg: Color, border: Color = Color(0, 0, 0, 0), widths = 0, pad = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	var w: Array = widths if widths is Array else [widths, widths, widths, widths]
	s.border_width_top = bw(w[0])
	s.border_width_right = bw(w[1])
	s.border_width_bottom = bw(w[2])
	s.border_width_left = bw(w[3])
	var p: Array = pad if pad is Array else [pad, pad, pad, pad]
	if p.size() == 2:
		p = [p[0], p[1], p[0], p[1]]
	s.content_margin_top = px(p[0])
	s.content_margin_right = px(p[1])
	s.content_margin_bottom = px(p[2])
	s.content_margin_left = px(p[3])
	return s


static func focus_box() -> StyleBoxFlat:
	if FOCUS == null:
		FOCUS = StyleBoxFlat.new()
		FOCUS.draw_center = false
		FOCUS.set_border_width_all(bw(2))
		FOCUS.set_expand_margin_all(px(4))
		FOCUS.border_color = Color(WARN, 0.0 if mouse_ui else 1.0)
	return FOCUS


## the browser shows focus rings only for keys and the controller
static func set_mouse_ui(on: bool) -> void:
	mouse_ui = on
	if FOCUS != null:
		FOCUS.border_color = Color(WARN, 0.0 if on else 1.0)


static func panel(bg: Color, border: Color = Color(0, 0, 0, 0), widths = 0, pad = 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", sb(bg, border, widths, pad))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func vbox(sep: float = 0.0) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", int(px(sep)))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func hbox(sep: float = 0.0) -> HBoxContainer:
	var b := HBoxContainer.new()
	b.add_theme_constant_override("separation", int(px(sep)))
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b


static func grid(cols: int, hsep: float, vsep: float = -1.0) -> GridContainer:
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", int(px(hsep)))
	g.add_theme_constant_override("v_separation", int(px(hsep if vsep < 0 else vsep)))
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return g


static func margin(t: float, r: float, b: float, l: float) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_top", int(px(t)))
	m.add_theme_constant_override("margin_right", int(px(r)))
	m.add_theme_constant_override("margin_bottom", int(px(b)))
	m.add_theme_constant_override("margin_left", int(px(l)))
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return m


static func spacer(h: float = 0.0, w: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(px(w), px(h))
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c


static func expand(c: Control, h: bool = true, v: bool = false) -> Control:
	if h:
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if v:
		c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return c


## a one-pixel rule (the .pt underline, the dividers between sections)
static func rule(col: Color = LINE) -> ColorRect:
	var r := ColorRect.new()
	r.color = col
	r.custom_minimum_size = Vector2(0, bw(1))
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


static func ignore_mouse(n: Node) -> void:
	if n is Control and not (n is BaseButton) and not (n is LineEdit) and not (n is Range) and not (n is ScrollContainer):
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in n.get_children():
		ignore_mouse(c)


## a scroller with the browser's thin scrollbar (scrollbar-color #536b72), filling its parent
static func scroller(content: Control) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.follow_focus = true
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(content)
	var vs := s.get_v_scroll_bar()
	vs.add_theme_stylebox_override("scroll", sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, [0, 3, 0, 3]))
	var g := sb(Color("#536b72"))
	g.content_margin_left = px(3)
	g.content_margin_right = px(3)
	for st in ["grabber", "grabber_highlight", "grabber_pressed"]:
		vs.add_theme_stylebox_override(st, g)
	return s


## gradient fills (the frame's vertical wash, the vignette, the case panels)
static func gradient_rect(cols: Array, offs: Array, radial: bool = false, from: Vector2 = Vector2(0.5, 0.0), to: Vector2 = Vector2(0.5, 1.0)) -> TextureRect:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offs)
	g.colors = PackedColorArray(cols)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.width = 64
	t.height = 64
	t.fill = GradientTexture2D.FILL_RADIAL if radial else GradientTexture2D.FILL_LINEAR
	t.fill_from = from
	t.fill_to = to
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


# ---------------------------------------------------------------- buttons

## Every button: a BaseButton that draws its own box for each state and holds any content (a label, or a whole card
## of lines), so a row like the PLAY page's MAP line is one focusable, clickable control.
class Btn extends BaseButton:
	var body: Control
	var styles := {}   # normal, hover, pressed, disabled -> StyleBox
	var tint := {}     # the label's colour per state (normal, hover, pressed, disabled)
	var label: Label   # the text, when the body is just text
	var tinted: Array = []   # more nodes that take the label's colour (an icon beside it)
	var text := ""

	func _init(content: Control, box: Dictionary, colors: Dictionary = {}) -> void:
		body = content
		styles = box
		tint = colors
		focus_mode = Control.FOCUS_ALL
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		add_child(content)
		UiKit.ignore_mouse(content)
		content.minimum_size_changed.connect(update_minimum_size)
		_apply_tint()

	func _get_minimum_size() -> Vector2:
		var s: StyleBox = styles.get("normal")
		return body.get_combined_minimum_size() + (s.get_minimum_size() if s != null else Vector2.ZERO)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_RESIZED or what == NOTIFICATION_READY:
			var s: StyleBox = styles.get("normal")
			body.position = Vector2(s.content_margin_left, s.content_margin_top) if s != null else Vector2.ZERO
			body.size = size - (s.get_minimum_size() if s != null else Vector2.ZERO)
		elif what == NOTIFICATION_DRAW:
			_apply_tint.call_deferred()
		elif what == NOTIFICATION_ENTER_TREE:
			_apply_tint()

	func _state() -> String:
		if disabled:
			return "disabled"
		match get_draw_mode():
			DRAW_PRESSED, DRAW_HOVER_PRESSED:
				return "pressed"
			DRAW_HOVER:
				return "hover"
		return "normal"

	func _apply_tint() -> void:
		if tint.is_empty() or not is_inside_tree():
			return
		var c: Color = tint.get(_state(), tint.get("normal", Color.WHITE))
		for n in ([label] if label != null else []) + tinted:
			if is_instance_valid(n) and n.self_modulate != c:
				n.self_modulate = c

	## swap the look (a picked tab, a selected card) without rebuilding the button
	func restyle(box: Dictionary, colors: Dictionary = {}) -> void:
		styles = box
		if not colors.is_empty():
			tint = colors
		update_minimum_size()
		queue_redraw()

	func _draw() -> void:
		var s: StyleBox = styles.get(_state(), styles.get("normal"))
		if s != null:
			draw_style_box(s, Rect2(Vector2.ZERO, size))
		if has_focus():
			draw_style_box(UiKit.focus_box(), Rect2(Vector2.ZERO, size))


## the browser's button kinds: go (yellow), ghost (outlined), seg (segmented), tab, nav; and the overlays' go and ghost
static func kind(name: String, sel: bool = false) -> Dictionary:
	var clear := Color(0, 0, 0, 0)
	match name:
		"go", "ogo":
			var y := WARN if name == "go" else OWARN
			return {"face": "s9", "em": 0.1, "box": {"normal": sb(y), "hover": sb(y.lightened(0.12)), "pressed": sb(y.darkened(0.1)), "disabled": sb(Color("#3a3228"))},
				"tint": {"normal": INKT, "hover": INKT, "pressed": INKT, "disabled": ODIM if name == "ogo" else DIM}}
		"ghost", "oghost":
			var ln := LINE if name == "ghost" else OLINE
			var fg := BONE if name == "ghost" else OBONE
			return {"face": "s8", "em": 0.1, "box": {"normal": sb(clear, ln, 1), "hover": sb(Color(1, 1, 1, 0.06), ln.lightened(0.25), 1), "pressed": sb(Color(1, 1, 1, 0.1), WARN, 1), "disabled": sb(clear, Color(ln, 0.5), 1)},
				"tint": {"normal": fg, "hover": Color.WHITE, "pressed": Color.WHITE, "disabled": Color(fg, 0.4)}}
		"tab":   # .ssTabs / .fdTabs
			if sel:
				return {"face": "s8", "em": 0.08, "box": {"normal": sb(NAVSEL, NAVSEL, 1), "hover": sb(NAVSEL, NAVSEL, 1), "pressed": sb(NAVSEL, NAVSEL, 1), "disabled": sb(NAVSEL, NAVSEL, 1)},
					"tint": {"normal": NAVINK, "hover": NAVINK, "pressed": NAVINK, "disabled": NAVINK}}
			var bg := Color(22 / 255.0, 40 / 255.0, 50 / 255.0, 0.6)
			return {"face": "s8", "em": 0.08, "box": {"normal": sb(bg, ROWLINE, 1), "hover": sb(Color("#22384a"), Color("#7e98a5"), 1), "pressed": sb(NAVSEL, NAVSEL, 1), "disabled": sb(Color(bg, 0.3), Color(ROWLINE, 0.5), 1)},
				"tint": {"normal": Color("#cfe0e4"), "hover": Color.WHITE, "pressed": NAVINK, "disabled": Color("#cfe0e4", 0.4)}}
		"nav":   # .partyNav
			var on := sb(NAVSEL)
			if sel:
				return {"face": "s8", "em": 0.07, "box": {"normal": on, "hover": on, "pressed": on, "disabled": on}, "tint": {"normal": NAVINK, "hover": NAVINK, "pressed": NAVINK, "disabled": NAVINK}}
			return {"face": "s8", "em": 0.07, "box": {"normal": sb(clear), "hover": on, "pressed": on, "disabled": sb(clear)}, "tint": {"normal": BONE, "hover": NAVINK, "pressed": NAVINK, "disabled": Color(BONE, 0.4)}}
	return kind("ghost")


## a text button. opts: pad [t, r, b, l] (CSS), h (min height), w (min width), align, em, face, sel, palette ("o": the overlays')
static func btn(text: String, kind_name: String, size: float, cb: Callable = Callable(), opts: Dictionary = {}) -> Btn:
	var K := kind(kind_name, opts.get("sel", false))
	if opts.has("box"):
		K.box = opts.box
	if opts.has("tint"):
		K.tint = opts.tint
	var l := lbl(text, opts.get("face", K.face), size, Color.WHITE, opts.get("em", K.em))
	l.horizontal_alignment = opts.get("align", HORIZONTAL_ALIGNMENT_CENTER)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var pad: Array = opts.get("pad", [0, 12, 0, 12])
	var box := {}
	for st in K.box:
		var s: StyleBoxFlat = K.box[st].duplicate()
		s.content_margin_top = px(pad[0])
		s.content_margin_right = px(pad[1])
		s.content_margin_bottom = px(pad[2])
		s.content_margin_left = px(pad[3])
		box[st] = s
	var b := Btn.new(l, box, K.tint)
	b.label = l
	b.text = text
	b.custom_minimum_size = Vector2(px(opts.get("w", 0)), px(opts.get("h", 0)))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## a button around any content (rows, cards, tiles)
static func card_btn(content: Control, box: Dictionary, cb: Callable = Callable()) -> Btn:
	var b := Btn.new(content, box)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


## .seg: options side by side in one outlined strip, the picked one filled. items: [[id, label], ...]
## opts: cols, size, h, palette "o", disabled [ids], face
static func seg(items: Array, cur, cb: Callable, opts: Dictionary = {}) -> PanelContainer:
	var o: bool = opts.get("palette", "") == "o"
	var ln: Color = OLINE if o else LINE
	var fg: Color = ODIM if o else DIM
	var on: Color = OBONE if o else NAVSEL if opts.get("tabs", false) else BONE
	var cols: int = opts.get("cols", items.size())
	var size: float = opts.get("size", 15)
	var wrap := panel(Color(0, 0, 0, 0), ln, 1)
	var g := GridContainer.new()
	g.columns = cols
	g.add_theme_constant_override("h_separation", 0)
	g.add_theme_constant_override("v_separation", 0)
	wrap.add_child(g)
	var dis: Array = opts.get("disabled", [])
	for i in items.size():
		var it: Array = items[i]
		var sel: bool = str(it[0]) == str(cur)
		var edge := [bw(1) if i >= cols else 0, 0, 0, bw(1) if i % cols != 0 else 0]
		var mk := func(bg: Color) -> StyleBoxFlat:
			var s := sb(bg, ln, 0, opts.get("pad", [8, 4, 8, 4]))
			s.border_width_top = edge[0]
			s.border_width_left = edge[3]
			return s
		var box := {"normal": mk.call(on if sel else Color(0, 0, 0, 0)), "hover": mk.call(on if sel else Color(1, 1, 1, 0.05)),
			"pressed": mk.call(on), "disabled": mk.call(Color(on, 0.5) if sel else Color(0, 0, 0, 0))}
		var ink: Color = NAVINK if opts.get("tabs", false) and sel else INKT
		var tint := {"normal": ink if sel else fg, "hover": ink if sel else (OBONE if o else BONE), "pressed": ink, "disabled": Color(ink if sel else fg, 0.5)}
		var l := lbl(str(it[1]), opts.get("face", "s8"), size, Color.WHITE, opts.get("em", 0.1))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var b := Btn.new(l, box, tint)
		b.label = l
		b.text = str(it[1])
		b.set_meta("sel", sel)
		b.custom_minimum_size = Vector2(0, px(opts.get("h", 40)))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.disabled = dis.has(it[0])
		var id = it[0]
		b.pressed.connect(func(): cb.call(id))
		g.add_child(b)
	return wrap


# ---------------------------------------------------------------- fields, sliders, toggles

## an input like the browser's (dark well, the line colour around it, the gold ring when focused)
static func field(value: String = "", hint: String = "", opts: Dictionary = {}) -> LineEdit:
	var e := LineEdit.new()
	e.text = value
	e.placeholder_text = hint
	e.secret = opts.get("secret", false)
	var o: bool = opts.get("palette", "") == "o"
	var size: float = opts.get("size", 16)
	var f: String = opts.get("face", "m6")
	e.add_theme_font_override("font", font(f, size, opts.get("em", 0.0)))
	e.add_theme_font_size_override("font_size", fs(size))
	e.add_theme_color_override("font_color", OBONE if o else BONE)
	e.add_theme_color_override("font_placeholder_color", Color(OBONE if o else BONE, 0.45))
	e.add_theme_color_override("caret_color", WARN)
	e.add_theme_color_override("selection_color", Color(WARN, 0.35))
	var bg: Color = opts.get("bg", Color("#0c0b09"))
	var ln: Color = OLINE if o else LINE
	var pad := [0, 12, 0, 12]
	e.add_theme_stylebox_override("normal", sb(bg, ln, 1, pad))
	e.add_theme_stylebox_override("read_only", sb(bg, ln, 1, pad))
	var fo := sb(bg, WARN, 2, pad)
	e.add_theme_stylebox_override("focus", fo)
	e.custom_minimum_size = Vector2(0, px(opts.get("h", 46)))
	e.alignment = opts.get("align", HORIZONTAL_ALIGNMENT_LEFT)
	return e


## a round thumb, a square check: textures drawn once per size
static func _disc(d: int, col: Color) -> ImageTexture:
	var key := "disc|%d|%s" % [d, col.to_html()]
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var r := d / 2.0
	for y in d:
		for x in d:
			var dd := Vector2(x + 0.5 - r, y + 0.5 - r).length()
			img.set_pixel(x, y, Color(col, clampf(r - dd, 0, 1)))
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


static func _check(d: int, on: bool, o: bool = false) -> ImageTexture:
	var key := "chk|%d|%s|%s" % [d, on, o]
	if _tex.has(key):
		return _tex[key]
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	var y0 := WARN if not o else OWARN
	var rr := maxf(2.0, d * 0.12)
	for y in d:
		for x in d:
			var q := Vector2(absf(x + 0.5 - d / 2.0), absf(y + 0.5 - d / 2.0)) - Vector2(d / 2.0 - rr, d / 2.0 - rr)
			var dist := Vector2(maxf(q.x, 0), maxf(q.y, 0)).length() - rr
			var a := clampf(0.5 - dist, 0, 1)
			if a <= 0:
				continue
			var c: Color
			if on:
				c = y0
			else:
				var edge := clampf(-dist - maxf(1.0, d * 0.07), 0, 1)
				c = Color("#3b3b3b").lerp(Color("#2a2a2a"), edge)
			img.set_pixel(x, y, Color(c, a))
	if on:   # the tick
		var p0 := Vector2(d * 0.24, d * 0.52)
		var p1 := Vector2(d * 0.42, d * 0.70)
		var p2 := Vector2(d * 0.76, d * 0.30)
		var w := maxf(1.2, d * 0.09)
		for y in d:
			for x in d:
				var pt := Vector2(x + 0.5, y + 0.5)
				var dist := minf(Geometry2D.get_closest_point_to_segment(pt, p0, p1).distance_to(pt), Geometry2D.get_closest_point_to_segment(pt, p1, p2).distance_to(pt))
				var a := clampf(w - dist + 0.5, 0, 1)
				if a > 0:
					img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color("#17140f"), a))
	var t := ImageTexture.create_from_image(img)
	_tex[key] = t
	return t


## .set: a range with the gold fill and thumb (the browser's accent-color)
static func slider(val: float, lo: float, hi: float, step: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = val
	s.focus_mode = Control.FOCUS_ALL
	var track := sb(Color("#5b5b5b"))
	track.set_corner_radius_all(int(px(4)))
	track.content_margin_top = px(4)
	track.content_margin_bottom = px(4)
	var fill := sb(WARN)
	fill.set_corner_radius_all(int(px(4)))
	fill.content_margin_top = px(4)
	fill.content_margin_bottom = px(4)
	s.add_theme_stylebox_override("slider", track)
	s.add_theme_stylebox_override("grabber_area", fill)
	s.add_theme_stylebox_override("grabber_area_highlight", fill)
	s.add_theme_icon_override("grabber", _disc(int(px(16)), WARN))
	s.add_theme_icon_override("grabber_highlight", _disc(int(px(16)), WARN.lightened(0.2)))
	var f := focus_box()
	s.add_theme_stylebox_override("focus", f)
	s.custom_minimum_size = Vector2(0, px(28))
	s.value_changed.connect(cb)
	return s


## .tog: a check and its words
static func toggle(text: String, on: bool, cb: Callable, size: float = 14.0, o: bool = false) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.button_pressed = on
	c.focus_mode = Control.FOCUS_ALL
	c.add_theme_font_override("font", face("m4"))
	c.add_theme_font_size_override("font_size", fs(size))
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		c.add_theme_color_override(st, OBONE if o else BONE)
	c.add_theme_icon_override("checked", _check(int(px(22)), true, o))
	c.add_theme_icon_override("unchecked", _check(int(px(22)), false, o))
	c.add_theme_constant_override("h_separation", int(px(12)))
	var clear := sb(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, [4, 0, 4, 2])
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		c.add_theme_stylebox_override(st, clear)
	c.add_theme_stylebox_override("focus", focus_box())
	c.custom_minimum_size = Vector2(0, px(40))
	c.toggled.connect(cb)
	return c


## the progress bars (the next unlock, the supply case): a dark well, the gold run
static func bar(frac: float, h: float = 10.0, marks: int = 0) -> Control:
	var c := Bar.new()
	c.frac = clampf(frac, 0, 1)
	c.marks = marks
	c.custom_minimum_size = Vector2(0, px(h))
	return c


class Bar extends Control:
	var frac := 0.0
	var marks := 0
	var line := Color("#3a3428")

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		draw_rect(r, Color("#0c0b09"))
		var w := (size.x - 2) * frac
		if w > 0:
			var g := Gradient.new()
			g.colors = PackedColorArray([Color("#b98a1c"), Color("#f0d16b")])
			var steps := 16
			for i in steps:
				var x0 := 1 + w * i / steps
				draw_rect(Rect2(x0, 1, w / steps + 0.5, size.y - 2), g.sample((i + 0.5) / steps))
		for k2 in range(1, marks):
			draw_rect(Rect2(size.x * k2 / marks, 0, 1, size.y), line)
		draw_rect(r, UiKit.LINE if line == Color("#3a3428") else line, false, UiKit.bw(1))


## the pips under a skill or an upgrade: filled up to the level
class Pips extends Control:
	var n := 3
	var on := 0
	var w := 18.0
	var h := 6.0
	var gap := 4.0
	var col := Color("#efd347")
	var line := Color("#354e59")

	func _init(count: int, lit: int, pw: float = 18.0, ph: float = 6.0, pgap: float = 4.0) -> void:
		n = count
		on = lit
		w = pw
		h = ph
		gap = pgap
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(UiKit.px(n * w + (n - 1) * gap), UiKit.px(h))

	func _draw() -> void:
		for i in n:
			var r := Rect2(UiKit.px(i * (w + gap)), 0, UiKit.px(w), UiKit.px(h))
			draw_rect(r, col if i < on else Color("#0c0b09"))
			draw_rect(r, col if i < on else line, false, UiKit.bw(1))
