class_name CasinoUI
extends CanvasLayer
## THE PALISADE FALLS CASINO's table sheets (21b-tables.js, 21c-casino-games.js): blackjack, Texas hold'em, roulette,
## baccarat, craps, slots and Plinko. The server deals and decides everything (PalTables talks to it); this sheet shows
## what it says, animates exactly what it decided, and sends what you pick. The sheet docks at the right over the casino
## floor (max(360px, 40% of the window); a bottom sheet on narrow windows), scrolls, and is built from Godot controls so
## the mouse, the keys and a controller (focus) all work it. Every round ends in a review the server holds (the receipt:
## what you bet, what came back, the net and why); LAST RESULT shows the last one again, after you stand up too.

signal stood_up   # the player left the seat from the sheet (STAND UP, or the server stood them up)
signal shards_changed(n: int)   # the server reported a new balance

const GOLD := Color("#e2b436")
const PAPER := Color("#e8dcc0")
const DIM := Color("#9a8f7a")
const RED := Color("#d65a3a")
const INK := Color(14 / 255.0, 12 / 255.0, 10 / 255.0, 0.92)
const CREAM := Color("#f3ecdc")
const CARD_RED := Color("#c43a2a")
const WINC := Color("#8fe0a0")
const LOSSC := Color("#ff8a6a")
const PUSHC := Color("#e2d39a")
const AMBER := Color("#ffd88a")
const SKY := Color("#9fd8ff")
const LINE := Color("#4a4030")
const TEXT2 := Color("#dcd2ba")

const SUIT := ["♣", "♦", "♥", "♠"]
const RANK := ["2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K", "A"]
const TABLE_GAME := {1: "bj", 2: "he", 3: "rl", 4: "cr", 5: "ba"}   # the floor's tables (CAS.tables n)
const RL_RED := [1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36]
const RL_WHEELC := [0, 28, 9, 26, 30, 11, 7, 20, 32, 17, 5, 22, 34, 15, 3, 24, 36, 13, 1, 37, 27, 10, 25, 29, 12, 8, 19, 31, 18, 6, 21, 33, 16, 4, 23, 35, 14, 2]
const RL_OUT := [["dz:1", "1st 12"], ["dz:2", "2nd 12"], ["dz:3", "3rd 12"], ["low", "1-18"], ["even", "EVEN"], ["red", "RED"], ["black", "BLACK"], ["odd", "ODD"], ["high", "19-36"]]
const RL_CHIPS := [1, 5, 25, 100, 500, 1000]
const CR_PTS := [4, 5, 6, 8, 9, 10]
const CR_ODDS_D := {4: 1, 5: 2, 6: 5, 8: 5, 9: 2, 10: 1}
const CR_LAY_D := {4: 2, 5: 3, 6: 6, 8: 6, 9: 3, 10: 2}
const CR_MULT_C := {4: 3, 5: 4, 6: 5, 8: 5, 9: 4, 10: 3}
const CR_LABEL := {"pass": "PASS LINE", "dp": "DON'T PASS", "po": "PASS ODDS", "dpo": "DON'T PASS ODDS", "come": "COME", "dc": "DON'T COME", "field": "FIELD", "any7": "ANY SEVEN", "anyc": "ANY CRAPS", "n2": "TWO", "n3": "THREE", "n11": "ELEVEN", "n12": "TWELVE"}
const ITEM_LABEL := {"ins": "INSURANCE", "side": "SIDE BET", "line": "THE LINE", "drop": "THE DROP", "P": "PLAYER", "B": "BANKER", "T": "TIE"}
const CG_SYM := {"P": "PALI", "C": "CORE", "W": "WALL", "H": "HELM", "N": "NADE", "S": "◆", "X": ""}
const CG_SYM_COL := {"P": "#ffd24a", "C": "#3ae0ff", "W": "#e0704a", "H": "#b0c4d4", "N": "#8ae05a", "S": "#9fd8ff", "X": "#2a2a33"}
const CG_STRIPS := ["SWNXHSWNSPWXNSHWCNSX", "SWXNHXWNSPWXNXHWCNSX", "SWXNHXWNXPWXNXHWCNSX"]
const PK_MULT_D := [300, 90, 30, 15, 12, 6, 5, 6, 12, 15, 30, 90, 300]
const SLOT_PAYS := [["PALI PALI PALI", 250], ["CORE CORE CORE", 60], ["WALL WALL WALL", 25], ["HELM HELM HELM", 15], ["NADE NADE NADE", 10], ["◆ ◆ ◆", 6], ["ANY THREE OF WALL / HELM / NADE", 3], ["◆ ◆ on reels 1-2", 2], ["◆ on reel 1 (your stake back)", 1]]
const VOLATILE := ["left", "review", "revealIn", "minBetAt", "_t", "log"]   # change every poll without changing what's on the felt
const SEED_PATH := "user://casino_seed.txt"

## HOW TO PLAY for each game, and HOUSE RULES (TB_HELP, TB_RULES)
const HELP := {
	"bj": "[b]Goal:[/b] finish closer to 21 than the dealer without going over. Number cards count their number, J/Q/K count 10, an ace counts 1 or 11.\n[b]Each hand:[/b] place a bet (60 seconds; the cards come as soon as everyone has bet). You get two cards; the dealer shows one.\n[b]HIT[/b] takes a card. [b]STAND[/b] keeps what you have. [b]DOUBLE[/b] doubles your bet for exactly one more card. [b]SPLIT[/b] turns a pair into two hands (one more bet).\n[b]Pays:[/b] a win pays 1:1, blackjack (ace + a 10 card) pays 3:2, a tie gets your bet back. The dealer stands on 17. If the dealer shows an ace you can buy [b]insurance[/b] (half your bet, pays 2:1 if the dealer has blackjack).\n4 decks, shuffled fresh every hand. No clock while you play.",
	"he": "[b]Goal:[/b] make the best five-card hand from your two cards and the five shared cards, or make everyone else fold.\n[b]Each hand:[/b] two players post blinds (1 and 2 shards). Then four rounds of betting: after your cards, after the flop (3 shared cards), the turn (4th) and the river (5th).\nOn your turn: [b]FOLD[/b] (give up the hand), [b]CHECK[/b] (pass, if nobody has bet), [b]CALL[/b] (match the bet), [b]RAISE / BET[/b] (put in more), [b]ALL IN[/b] (everything at the table).\n[b]Hands, low to high:[/b] high card, pair, two pair, three of a kind, straight, flush, full house, four of a kind, straight flush.\nThe house takes 1.8% of pots that reach the flop (6 shards at most). Between hands there's a 60-second break; it deals as soon as everyone taps READY. No clock while you play.",
	"rl": "[b]Goal:[/b] guess where the ball lands. The wheel has 38 pockets: 1 to 36 (red or black), 0 and 00 (green).\n[b]Each spin:[/b] 60 seconds to bet. Pick a chip, then tap the board: a number, the line between two numbers (split), the bottom edge of a column of three (street), a corner of four, the bottom corner between two streets (six line), or the outside boxes. Tap again to add another chip. The ball goes as soon as everyone with a bet taps SPIN.\n[b]Pays:[/b] a number 35:1, split 17:1, street 11:1, corner 8:1, the top line (0, 00, 1, 2, 3) 6:1, six line 5:1, a dozen or a column 2:1, red/black, odd/even, 1-18/19-36 1:1. 0 and 00 lose every outside bet.\nNo limit: bet anything you have at the table.",
	"ba": "[b]Goal:[/b] bet on which hand ends closer to 9: [b]PLAYER[/b] or [b]BANKER[/b] (or a [b]TIE[/b]). Those are just the hands' names: nobody plays them, the cards are dealt by the rules.\n[b]Counting:[/b] aces 1, 2-9 face value, 10/J/Q/K 0; only the last digit counts (7 + 8 = 15 counts 5). Two cards each; an 8 or 9 is a natural and the hand is over. Otherwise the third-card rules decide (they're in HOUSE RULES); nobody chooses.\n[b]Pays:[/b] Player 1:1. Banker 1:1 less 5% commission, so Banker bets go in 20s: 20 on Banker pays 19 plus your 20 back. Tie 8:1, and a tie gives Player and Banker bets back.\n[b]Each hand:[/b] 30 seconds to bet; DEAL when you're done (the cards come once everyone has, but never in the first 5 seconds). Eight decks in one shoe, burned and cut 16 cards from the end. The ROAD shows what happened, not what will.",
	"cr": "[b]The easy way in:[/b] on the come-out roll put a bet on the [b]PASS LINE[/b]. 7 or 11 wins, 2, 3 or 12 loses; anything else becomes the [b]point[/b]. Then you want the point again before a 7. Pays 1:1.\n[b]Once a point is on[/b] you can add [b]PASS ODDS[/b] (up to 3x on 4/10, 4x on 5/9, 5x on 6/8; true odds, the house keeps nothing), and [b]COME[/b] bets, which work like a Pass bet of their own on the next roll. [b]DON'T PASS / DON'T COME[/b] are the other side (12 on the come-out is a tie).\n[b]PLACE 6 / 8[/b] win 7:6 when that number rolls before a 7 and stay up; [b]FIELD[/b] is one roll. ALL BETS shows Place 4/5/9/10, Hardways and the one-roll bets. Every bet's payout is on its box.\n[b]Rules you can't change:[/b] a Pass bet with a point on can't come down; a Come bet on its number stays until it's decided; Don't bets can come down but not go back up. Place, Hardways and Come odds rest on the come-out unless you turn them on (the toggles). TAKE DOWN, then tap a bet, takes it off.\n[b]The dice:[/b] the shooter's ROLL (or everyone's READY) starts the roll; the dice are the server's, not your timing. The shooter keeps the dice until a seven-out.",
	"sl": "[b]PALISADE RUN:[/b] pick 1 to 100 shards and SPIN. Three reels, one line across the middle. The line pays its single highest award (the PAYTABLE has them all): three crests 250x down to one shard on the first reel, which gives your stake back.\nEvery spin is on its own, one per press: no autoplay, no jackpot. The machine returns 96.03% of what's bet over all its combinations; any one session can be far above or below that.",
	"pk": "[b]PLINKO:[/b] pick a stake (in 10s) and DROP. The ball bounces left or right twelve times, each one 50/50, and lands in one of thirteen pockets: the edges pay 30x, the middle 0.5x.\nThe bounces are decided by the server before the ball moves; the board just shows that path. 1x gives your stake back; under 1x some shards come back but it's a loss. Returns 96.01% over all 4,096 paths.",
}
const RULES := "[color=#e2b436][b]THE HOUSE[/b][/color]\nEvery table is run by the server: it shuffles, deals, spins and pays. Your screen only shows what the server says you may see.\n[color=#e2b436][b]WHAT THE HOUSE KEEPS[/b][/color]\n• [b]Blackjack:[/b] about 0.5% of what's bet with perfect play (4 decks, dealer stands on 17, blackjack pays 3:2).\n• [b]Hold'em:[/b] 1.8% of pots that reach the flop, 6 shards at most. Nothing from pots that end before the flop.\n• [b]Roulette:[/b] the American double-zero wheel keeps 5.26% of every bet (2 pockets in 38); the top line (0, 00, 1, 2, 3) keeps 7.89%.\n• [b]Side bets:[/b] 1 shard a hand.\n• [b]Baccarat[/b] (8 decks): Banker 1.06% (1:1 less 5% commission, so Banker bets go in 20s), Player 1.24%, Tie 14.36% (8:1).\n• [b]Craps:[/b] Pass and Come 1.41%, Don't Pass and Don't Come 1.40% (bar 12), odds 0%, Place 6/8 1.52%, Place 5/9 4.00%, Place 4/10 6.67%, Field 5.56%, Hard 6/8 9.09%, Hard 4/10 11.11%, Any Craps 11.11%, 3 and 11 11.11%, 2 and 12 13.89%, Any Seven 16.67%.\n• [b]Slots[/b] (PALISADE RUN, math sl-1): returns 96.03% of what's bet over every one of its 8,000 stop combinations. The line pays on 37.5% of spins, but only 16.3% pay more than the stake (21.25% just give it back); the top award is 250x, 1 spin in 8,000.\n• [b]Plinko[/b] (math pk-1): returns 96.01% (all 4,096 paths); a ball pays 0.5x to 30x.\nSlots and Plinko are this casino's own games (no real casino's machines or odds). The house's share is a project choice, kept under 100%.\nWhat the house keeps is gone: it isn't paid to anyone. Shards can never be bought or cashed out.\n[color=#e2b436][b]FAIR PLAY[/b][/color]\nBefore every hand, spin, roll or drop the server shows the fingerprint (SHA-256) of its secret seed. Your own seed (set it under FAIR PLAY at the table) and everyone else's are mixed in when the round starts, so nobody, the server included, can pick the cards. After the round the seed is revealed and anyone can rerun the shuffle or the spin: HAND HISTORY does it for you, right in your browser.\nIn Hold'em each card has its own fingerprint, so you can check the cards you saw without anyone seeing a folded hand. The seed and the whole deck show in your history after 24 hours.\nBaccarat deals from one shoe for many hands, so its seed can't be shown until the shoe is finished (it would show the cards still to come). Every card of the shoe has its own fingerprint, all of them fixed when the shoe starts: each hand's cards come with their salts, and CHECK compares them with those fingerprints right away. When the shoe is done (cut card, or the table closes) its seed and every card go to your history, and CHECK reruns the whole shuffle. Your seed is mixed in from the next shoe on.\nCraps: each roll has its own committed seed (shown after the roll; it can't tell you the next one). Slots and Plinko: each spin or drop likewise, and the reels stop and the ball falls exactly where those numbers say.\nWhat CHECK proves: the result came from the committed seed and the players' seeds, so it was fixed before anyone could see it. It doesn't prove anything else about the server; the books check below is a separate audit of the shards.\n[color=#e2b436][b]THE BOOKS[/b][/color]\nEvery day the server checks every table that closed: shards brought in minus shards taken home must equal what the house kept plus what was lost to the bot, to the shard.\n[color=#e2b436][b]AT THE TABLE[/b][/color]\n• The buy-in is 5 shards. Top up between hands. Standing up sends what's in front of you back to your balance.\n• Sit out 3 hands, or close the game for a minute, and you're stood up (your shards go home).\n• Blackjack and Hold'em: up to 5 and 6 players; the first to sit sets the table's limit and side bet and starts it. Roulette, baccarat and craps: up to 6, always no limit, nothing to start. Slots and Plinko: one player per machine.\n• After every round the result stays up: 8 seconds for cards, 6 for dice and roulette, 3 for slots and Plinko, counted from the last card, the dice stopping or the ball landing. Nothing (READY included) skips it. Standing up is never held back by it.\n• Craps: if you leave with a Pass Line bet on a point or a Come bet on its number, those bets stay and the dealer rolls them out; you can't sit elsewhere until they're decided, then your shards go home.\n• A bot sits in at Hold'em when there are only two of you; it never sees anyone's cards."

## the last receipt this session (LAST RESULT): kept when the sheet closes, after you stand up, at the next table
static var last_rcpt := {}

var m   # the main node: account, audio, v (window size), locker
var tables: PalTables
var root: Control
var sheet: PanelContainer
var scroll: ScrollContainer
var col: VBoxContainer
var title_l: Label
var info_l: Label
var hide_b: Button
var stand_b: Button
var status_box: PanelContainer
var status_t: Label
var status_s: Label
var timer_bar: ProgressBar
var review_box: VBoxContainer
var felt: PanelContainer
var felt_col: VBoxContainer
var acts: VBoxContainer
var foot: HBoxContainer
var stack_l: Label
var bal_l: Label
var log_l: Label
var help_b: Button
var help_t: RichTextLabel
var fair_b: Button
var fair_box: VBoxContainer
var fair_t: Label
var seed_in: LineEdit
var last_b: Button
var msg_l: Label
var modal: Control = null
var modal_kind := ""
var theme_: Theme
var bold_font: FontVariation

var seat := 0
var room := ""
var game := ""
var station := ""
var _open := false
var _no := ""   # why this player can't play (shown instead of a table)
var _key_felt := ""
var _key_acts := ""
var _key_review := ""
var _refresh_t := 0.0
var _size := Vector2.ZERO
var persist_seed := true   # tests switch it off
var sync_locker := true   # bring the locker up to date after standing up or taking a prize

# what you're doing at the table (not the server's): the bet stepper, the chips, bets on their way
var amt := 2
var raise_amt := 0
var rl := {"chip": 5, "bets": {}, "sent": "", "dirty": false, "last": {}, "hand": -1, "inflight": false, "at": 0.0, "sentBets": {}, "spun": -1, "send_at": 0.0}
var ba := {"chip": 10, "bets": {}, "sent": "", "dirty": false, "last": {}, "hand": -1, "inflight": false, "at": 0.0, "send_at": 0.0}
var cr := {"chip": 5, "adv": false, "down": false}
var sl_amt := 1
var pk_amt := 10
var _cr_q: Array = []   # craps bets go one at a time, in order
var _cr_running := false
var snd := {"key": "", "n": 0}
var res_key := ""   # the round whose result sound has played
var last_sfx := ""
var wheel := {"spin_at": 0.0, "num": -1, "dur": 6.0}   # the floor's wheel (casWheelState)
var rl_hint: Label


func _init(main = null) -> void:
	m = main
	layer = 4
	tables = PalTables.new(main.account if main != null and "account" in main else null)


func _ready() -> void:
	add_child(tables)
	tables.updated.connect(_on_view)
	tables.message.connect(_on_msg)
	tables.receipt.connect(_on_rcpt)
	tables.left_table.connect(_on_left)
	tables.balance_changed.connect(func(n): shards_changed.emit(n))
	theme_ = _make_theme()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = theme_
	add_child(root)
	_build()
	sheet.visible = false
	if FileAccess.file_exists(SEED_PATH):
		seed_in.text = FileAccess.get_file_as_string(SEED_PATH).strip_edges()


# ---------------------------------------------------------------- the API the floor uses

## the floor's seat code -> {game, k (the server's seat), station}: table n seat k is n*10+k+1, machines are 101-117
static func seat_info(code: int) -> Dictionary:
	if code >= 101 and code <= 117:
		var k := code - 101
		return {"game": "pk" if k == 16 else "sl", "k": 0, "station": "p1" if k == 16 else "s%d" % (k + 1)}
	var n := code / 10
	var k := code % 10 - 1
	if TABLE_GAME.has(n) and k >= 0:
		return {"game": TABLE_GAME[n], "k": k, "station": ""}
	return {}


## sit at that seat in that casino room (or show your table again, if you're already there)
func open(seat_code: int, room_id: String) -> void:
	var q := seat_info(seat_code)
	if tables.account == null and m != null:
		tables.account = m.account
	seat = seat_code
	room = room_id
	game = q.get("game", "")
	station = q.get("station", "")
	_open = true
	sheet.visible = true
	_layout()
	_no = tables.cant_play() if not q.is_empty() else "That isn't a seat."
	if _no != "":
		_show_no()
		return
	if tables.id != 0 and not tables.v.is_empty() and tables.v.get("game") == game and str(tables.v.get("station", "")) == station:
		_redraw_all()
		_focus_main()
		return
	_no = ""
	_keys_reset()
	_show_no("Starting the machine…" if station != "" else "Taking a seat…", "wait")
	await tables.free_old_seat(room, game, station)   # a seat left behind on an earlier visit: stood up first
	var r := await tables.sit(room, game, int(q.k), station, seed_in.text)
	if not (r.get("view") is Dictionary) or int(r.view.get("me", -1)) < 0:
		_no = str(r.get("error", "")) if r.get("error") else "Could not sit down"
		_show_no()
		stood_up.emit()   # the floor takes you off the seat
		return
	_redraw_all()
	_focus_main()


## HIDE: the sheet goes, the seat stays (the poll keeps the table's state)
func close() -> void:
	_open = false
	if sheet != null:
		sheet.visible = false
	_close_modal()


func is_open() -> bool:
	return _open


## LAST RESULT: your last receipt this session
func last_result() -> void:
	var c := _modal("LAST RESULT")
	if last_rcpt.is_empty():
		c.add_child(_lbl("No result yet this session. Every round you played is in HAND HISTORY.", 13, DIM, true))
	else:
		c.add_child(_receipt(last_rcpt.game, last_rcpt.res, {}))
		c.add_child(_lbl(Time.get_time_string_from_unix_time(int(last_rcpt.at) + _tz()) + " · every round is in HAND HISTORY too", 12, DIM, true))
	_modal_focus()


## the latest server view of that game's table this player sees: their own table, or a recent peek (casView)
func view_for(g: String) -> Dictionary:
	return tables.view_of(g, "p1" if g == "pk" else "")


## SLIM (a bot) sits in seat k of that table (casBotAt)
func bot_at(g: String, k: int) -> bool:
	var vv := view_for(g)
	var ss = vv.get("seats")
	return ss is Array and k >= 0 and k < ss.size() and ss[k] is Dictionary and bool(ss[k].get("bot", false))


## the roulette wheel on the floor (casWheelState): an idle turn; a spin that lands on the server's number
func wheel_state() -> Dictionary:
	var now := Time.get_ticks_msec() / 1000.0
	var idle := now * .25
	if wheel.num < 0:
		return {"rot": idle, "ball": null}
	var t := minf(1.0, (now - wheel.spin_at) / wheel.dur)
	var e := 1.0 - pow(1.0 - t, 3)
	var k := RL_WHEELC.find(wheel.num)
	var rot := idle + e * PI * 6
	var land := rot + (k + .5) / 38.0 * TAU
	var ba_ := land + (1.0 - e) * PI * -14   # the ball runs the other way, drops in, settles in the pocket
	var r := .93 - ((t - .7) / .3 * .18 if t > .7 else 0.0)
	return {"rot": rot, "ball": {"a": ba_, "r": r}}


## the Plinko ball on the floor's board (cgPlinkoBall): {path, step (rows fallen)} or null
func plinko_ball() -> Variant:
	var vv := tables.view_of("pk", "p1")
	var r = _last_res(vv)
	if r.is_empty() or not (r.get("path") is Array) or vv.get("phase") != "done":
		return null
	var lf := left(vv)
	return {"path": r.path.map(func(x): return int(x)), "step": 12.5 if lf <= 0 else (3100.0 - lf) / 3100.0 * 12.5}


## the payline of your own slot cabinet (cgSlotLine), or null when that cabinet isn't yours
func slot_line(st: String) -> Variant:
	var vv := tables.v
	if tables.id == 0 or vv.get("game") != "sl" or str(vv.get("station", "")) != st:
		return null
	var w: Array = slot_window(vv, false).win
	return w.map(func(x): return "PCWHNSX".find(x[1]))


# ---------------------------------------------------------------- the look (Menus' theme)

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font = ThemeDB.fallback_font
	t.default_font_size = 15
	t.set_stylebox("normal", "Button", _sb(Color(28 / 255.0, 24 / 255.0, 19 / 255.0, 0.94), LINE, 1))
	t.set_stylebox("hover", "Button", _sb(Color(42 / 255.0, 36 / 255.0, 27 / 255.0, 0.96), GOLD, 1))
	t.set_stylebox("pressed", "Button", _sb(GOLD, GOLD, 1))
	t.set_stylebox("hover_pressed", "Button", _sb(GOLD.lightened(0.1), PAPER, 1))
	t.set_stylebox("focus", "Button", _sb(Color(0, 0, 0, 0), PAPER, 2))
	t.set_stylebox("disabled", "Button", _sb(Color(20 / 255.0, 18 / 255.0, 14 / 255.0, 0.7), Color("#2a251c"), 1))
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color("#17140f"))
	t.set_color("font_hover_pressed_color", "Button", Color("#17140f"))
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("#5a5244"))
	t.set_color("font_color", "Label", PAPER)
	t.set_stylebox("panel", "PanelContainer", _sb(INK, Color("#3a3226"), 1))
	t.set_stylebox("focus", "HSlider", _sb(Color(0, 0, 0, 0), PAPER, 1))
	var track := _sb(Color(243 / 255.0, 236 / 255.0, 220 / 255.0, 0.25), Color(0, 0, 0, 0), 0, 0, 2)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", track)
	var fill := _sb(GOLD, Color(0, 0, 0, 0), 0, 0, 2)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	t.set_stylebox("normal", "LineEdit", _sb(Color("#0f0d0a"), LINE, 1))
	t.set_stylebox("focus", "LineEdit", _sb(Color(0, 0, 0, 0), PAPER, 2))
	t.set_color("font_color", "LineEdit", PAPER)
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(243 / 255.0, 236 / 255.0, 220 / 255.0, 0.12)
	var bar_fg := StyleBoxFlat.new()
	bar_fg.bg_color = WINC
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fg)
	bold_font = FontVariation.new()
	bold_font.base_font = ThemeDB.fallback_font
	bold_font.variation_embolden = 0.7
	t.set_font("bold_font", "RichTextLabel", bold_font)
	t.set_color("default_color", "RichTextLabel", Color("#c9bfa8"))
	t.set_font_size("normal_font_size", "RichTextLabel", 13)
	t.set_font_size("bold_font_size", "RichTextLabel", 13)
	return t


static func _sb(bg: Color, border: Color, bw: int, pad: float = 8, radius: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_content_margin_all(pad)
	s.content_margin_left = maxf(pad, 10) if pad >= 8 else pad
	s.content_margin_right = s.content_margin_left
	s.set_corner_radius_all(radius)
	return s


func _lbl(text: String, size: int = 15, c: Color = PAPER, wrap: bool = false, bold: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c)
	if bold:
		l.add_theme_font_override("font", bold_font)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(60, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


func _row(sep: int = 6) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	return r


func _vbox(sep: int = 4) -> VBoxContainer:
	var b := VBoxContainer.new()
	b.add_theme_constant_override("separation", sep)
	return b


func _panel(bg: Color, border: Color, bw: int = 1, pad: float = 6, radius: int = 0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _sb(bg, border, bw, pad, radius))
	return p


## a sheet button (tbBtn): its action id, a small hint line under the label, "go" / "sel" (lit) and "big" looks.
## Buttons act on press, so a poll that redraws between press and release can't swallow a tap.
func _btn(label: String, a: String, opt: Dictionary = {}) -> Button:
	var b := Button.new()
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	b.focus_mode = Control.FOCUS_ALL
	b.set_meta("fid", a)
	b.disabled = not opt.get("on", true)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lit: bool = opt.get("cl", "").contains("go") or opt.get("cl", "").contains("sel")
	var big: bool = opt.get("cl", "").contains("big")
	if lit:
		b.add_theme_stylebox_override("normal", _sb(PAPER, PAPER, 1))
		b.add_theme_stylebox_override("hover", _sb(CREAM, GOLD, 2))
		b.add_theme_color_override("font_color", Color("#17140f"))
		b.add_theme_color_override("font_hover_color", Color("#17140f"))
		b.add_theme_color_override("font_focus_color", Color("#17140f"))
	var hint: String = opt.get("hint", "")
	if opt.has("w"):   # a fixed square (the bet stepper's - and +)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		b.custom_minimum_size = Vector2(opt.w, opt.w)
		b.text = label
		b.add_theme_font_size_override("font_size", 26)
		b.pressed.connect(func(): _act(a))
		return b
	if hint == "":
		b.text = label
		b.custom_minimum_size = Vector2(0, 54 if big else 40)
		if big:
			b.add_theme_font_size_override("font_size", 18)
	else:
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 0)
		var ink := Color("#17140f") if lit else PAPER
		var l1 := _lbl(label, 18 if big else 15, ink)
		l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var l2 := _lbl(hint, 10, ink.lerp(Color(0.5, 0.5, 0.5), 0.3))
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l2.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vb.add_child(l1)
		vb.add_child(l2)
		b.add_child(vb)
		b.clip_contents = true
		b.custom_minimum_size = Vector2(maxf(60, l1.get_minimum_size().x + 20), 58 if big else 46)
		if b.disabled:
			vb.modulate.a = 0.4
	b.pressed.connect(func(): _act(a))
	return b


# ---------------------------------------------------------------- building the sheet

func _build() -> void:
	sheet = PanelContainer.new()
	var ss := _sb(Color(18 / 255.0, 12 / 255.0, 10 / 255.0, 0.94), Color("#6a4a20"), 1, 10)
	ss.content_margin_left = 12
	ss.content_margin_right = 12
	ss.shadow_color = Color(0, 0, 0, 0.6)
	ss.shadow_size = 20
	sheet.add_theme_stylebox_override("panel", ss)
	root.add_child(sheet)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	sheet.add_child(scroll)
	var gutter := MarginContainer.new()   # room for the scroll bar
	gutter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_theme_constant_override("margin_right", 12)
	scroll.add_child(gutter)
	col = _vbox(6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gutter.add_child(col)
	# the head: what this is, HIDE, STAND UP
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var hl := _vbox(0)
	hl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l = _lbl("", 20, PAPER, false, true)
	title_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_l.custom_minimum_size.x = 40
	info_l = _lbl("", 12, DIM, true)
	hl.add_child(title_l)
	hl.add_child(info_l)
	head.add_child(hl)
	hide_b = _btn("HIDE", "hide")
	hide_b.size_flags_horizontal = Control.SIZE_SHRINK_END
	hide_b.custom_minimum_size = Vector2(0, 34)
	hide_b.tooltip_text = "Hide the table (you keep your seat)"
	stand_b = _btn("STAND UP", "stand")
	stand_b.size_flags_horizontal = Control.SIZE_SHRINK_END
	stand_b.custom_minimum_size = Vector2(0, 34)
	stand_b.add_theme_stylebox_override("normal", _sb(Color(28 / 255.0, 24 / 255.0, 19 / 255.0, 0.94), Color("#e8573a"), 1))
	stand_b.add_theme_color_override("font_color", Color("#ffb39e"))
	head.add_child(hide_b)
	head.add_child(stand_b)
	col.add_child(head)
	# the status line: what's happening, what to do
	status_box = PanelContainer.new()
	var sv := _vbox(2)
	status_t = _lbl("", 22, PAPER, false, true)
	status_t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	status_t.custom_minimum_size.x = 40
	status_s = _lbl("", 13, TEXT2, true)
	status_s.custom_minimum_size.y = 34
	timer_bar = ProgressBar.new()
	timer_bar.show_percentage = false
	timer_bar.custom_minimum_size = Vector2(0, 4)
	timer_bar.max_value = 1.0
	sv.add_child(status_t)
	sv.add_child(status_s)
	sv.add_child(timer_bar)
	status_box.add_child(sv)
	col.add_child(status_box)
	# the felt: the review on top, then the game
	felt = PanelContainer.new()
	var fs := _sb(Color("#173a28"), Color("#3a2a18"), 2, 10, 18)
	fs.shadow_color = Color(0, 0, 0, 0.35)
	felt.add_theme_stylebox_override("panel", fs)
	felt.custom_minimum_size = Vector2(0, 160)
	var fv := _vbox(8)
	review_box = _vbox(0)
	felt_col = _vbox(6)
	fv.add_child(review_box)
	fv.add_child(felt_col)
	felt.add_child(fv)
	col.add_child(felt)
	acts = _vbox(6)
	col.add_child(acts)
	# the foot: at the table, balance, top up
	foot = HBoxContainer.new()
	foot.add_theme_constant_override("separation", 6)
	var f1 := _vbox(0)
	f1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f1.add_child(_lbl("AT THE TABLE", 10, DIM))
	stack_l = _lbl("0", 22, SKY, false, true)
	f1.add_child(stack_l)
	var f2 := _vbox(0)
	f2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	f2.add_child(_lbl("BALANCE", 10, DIM))
	bal_l = _lbl("0", 22, SKY, false, true)
	f2.add_child(bal_l)
	foot.add_child(f1)
	foot.add_child(f2)
	for n in [5, 25, 100]:
		var tb := _btn("+%d" % n, "top:%d" % n)
		tb.size_flags_horizontal = Control.SIZE_SHRINK_END
		tb.custom_minimum_size = Vector2(52, 40)
		foot.add_child(tb)
	col.add_child(foot)
	log_l = _lbl("", 11, DIM, true)
	col.add_child(log_l)
	# HOW TO PLAY and FAIR PLAY open and close in place
	help_b = _btn("HOW TO PLAY  +", "help")
	help_b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(help_b)
	help_t = RichTextLabel.new()
	help_t.bbcode_enabled = true
	help_t.fit_content = true
	help_t.scroll_active = false
	help_t.visible = false
	help_t.add_theme_constant_override("paragraph_separation", 6)
	col.add_child(help_t)
	fair_b = _btn("FAIR PLAY: YOUR SEED AND THE CHECK  +", "fair")
	fair_b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	col.add_child(fair_b)
	fair_box = _vbox(6)
	fair_box.visible = false
	fair_t = _lbl("", 11, DIM)
	fair_t.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	fair_t.custom_minimum_size = Vector2(60, 0)
	fair_box.add_child(fair_t)
	var sr := HBoxContainer.new()
	sr.add_theme_constant_override("separation", 6)
	seed_in = LineEdit.new()
	seed_in.max_length = 64
	seed_in.placeholder_text = "your seed"
	seed_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_in.text_submitted.connect(func(_t): _act("seed"))
	sr.add_child(seed_in)
	var sb2 := _btn("SET SEED", "seed")
	sb2.size_flags_horizontal = Control.SIZE_SHRINK_END
	sr.add_child(sb2)
	fair_box.add_child(sr)
	fair_box.add_child(_btn("CHECK IT IN HAND HISTORY", "hist"))
	col.add_child(fair_box)
	var br := _row()
	last_b = _btn("LAST RESULT", "last")
	br.add_child(last_b)
	br.add_child(_btn("HAND HISTORY", "hist"))
	br.add_child(_btn("HOUSE RULES", "rules"))
	col.add_child(br)
	msg_l = _lbl("", 13, AMBER, true)
	col.add_child(msg_l)


## the sheet's place: docked at the right over the floor (max(360px, 40%)), or along the bottom on a narrow window
func _layout() -> void:
	var W := float(m.v.W) if m != null else 1280.0
	var H := float(m.v.H) if m != null else 720.0
	_size = Vector2(W, H)
	if W < 700:
		var h := roundf(H * 0.64)
		sheet.position = Vector2(0, H - h)
		sheet.size = Vector2(W, h)
	else:
		var w := minf(maxf(360.0, W * 0.4), W - 20)
		var top := minf(84.0, H * 0.1)
		sheet.position = Vector2(W - 10 - w, top)
		sheet.size = Vector2(w, H - top - 10)
	scroll.custom_minimum_size = Vector2.ZERO


func _process(dt: float) -> void:
	if m != null and _size != Vector2(m.v.W, m.v.H) and sheet != null:
		_layout()
	_flushers()
	var v := tables.v
	if not v.is_empty():
		result_sfx(v)
	if not _open or v.is_empty() or _no != "":
		return
	_refresh_t += dt
	if _refresh_t >= (0.1 if left(v) > 0 else 0.25):
		_refresh_t = 0.0
		_redraw_all()


# ---------------------------------------------------------------- the server's answers

func _on_view(v: Dictionary) -> void:
	if v.get("game") == "rl":
		rl_sync(v)
		if v.get("phase") == "spin" and rl.spun != int(v.get("handNo", 0)):   # the ball, heard (it joins a spin already under way)
			rl.spun = int(v.get("handNo", 0))
			var dur := minf(6.0, float(v.get("left", 0)) / 1000.0)
			if dur >= 1.0:
				_sfx_from("cas_wheel", 6.0 - dur)
		if (v.get("phase") == "spin" or v.get("phase") == "done") and v.has("number"):
			_wheel_spin(int(v.number), float(v.get("left", 0)) / 1000.0 if v.phase == "spin" else 0.0)
		elif v.get("phase") == "bet":
			wheel.num = -1
	if v.get("game") == "ba":
		ba_sync(v)
	result_sfx(v)
	_keep(v)
	if _open and _no == "":
		_redraw_all()


func _wheel_spin(num: int, lf: float) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if wheel.num == num and now - wheel.spin_at < wheel.dur + 6:
		return
	wheel.num = num
	wheel.spin_at = now - maxf(0.0, wheel.dur - lf)


func _on_msg(t: String) -> void:
	if msg_l != null:
		msg_l.text = t


func _on_rcpt(rc: Dictionary) -> void:
	if rc.get("result") is Dictionary and not tables.v.is_empty():
		var vv := tables.v.duplicate()
		vv.last = {"no": rc.get("no"), "result": rc.result}
		_keep(vv)


func _on_left(kind: String) -> void:
	_cr_q.clear()
	rl.bets = {}
	rl.sent = ""
	ba.bets = {}
	ba.sent = ""
	ba.hand = -1
	if kind == "left":
		msg_l.text = "RETURNED TO WALLET"
	elif kind == "pending":
		var n: int = tables.mine.pending.bets if tables.mine is Dictionary else 1
		msg_l.text = "BET STILL RESOLVING: %d bet%s working; your shards come home once the dealer has rolled %s out" % [n, "s" if n > 1 else "", "them" if n > 1 else "it"]
	if sync_locker and m != null and m.account != null and kind != "gone":
		m.account.sync_locker()
	if _open and _no == "":
		close()
	stood_up.emit()


# ---------------------------------------------------------------- clocks, sounds

static func _now() -> float:
	return float(Time.get_ticks_msec())


## how much of the reveal is still running: the server's revealIn, less the time since that view arrived (cgLeft)
static func left(v: Dictionary) -> float:
	if v.is_empty() or v.get("phase") != "done":
		return 0.0
	return maxf(0.0, float(v.get("revealIn", 0)) - (_now() - float(v.get("_t", 0))))


static func review_left(v: Dictionary) -> float:
	if v.is_empty() or v.get("phase") != "done":
		return 0.0
	return maxf(0.0, float(v.get("review", 0)) - (_now() - float(v.get("_t", 0))))


static func secs(v: Dictionary) -> int:
	return ceili(float(v.get("left", 0)) / 1000.0)


func _play(n: String) -> void:
	if m != null and m.audio != null:
		m.audio.play(n)


func _sfx_from(n: String, off: float) -> void:
	if m != null and m.audio != null and m.audio.has_method("play_from"):
		m.audio.play_from(n, off)


## a reveal's steps, heard once each (a card turning, a reel stopping, a peg, the dice)
func stage_sfx(v: Dictionary, stage: int, n: String) -> void:
	var k := "%s:%s:%s" % [v.get("game"), v.get("station", ""), _last_no(v)]
	if snd.key != k:
		snd.key = k
		snd.n = 0
	if stage > snd.n:
		snd.n = stage
		_play(n)


## the result, heard: once per round, as the reveal ends, sized by your net against your bet (cgResultSfx)
func result_sfx(v: Dictionary) -> void:
	if v.get("phase") != "done" or _last_res(v).is_empty() or left(v) > 0:
		return
	var k := "%s:%s:%s" % [v.get("game"), v.get("station", ""), _last_no(v)]
	if res_key == k:
		return
	res_key = k
	if _now() - float(v.get("_t", 0)) - float(v.get("revealIn", 0)) > 1500:   # the reveal ended a while ago (you came back to it): stay quiet
		return
	var s := result_kind(mine_of(_last_res(v)))
	last_sfx = s
	if s != "":
		_play(s)
		if s == "cas_jackpot" or s == "cas_big":
			for d in Input.get_connected_joypads():
				Input.start_joy_vibration(d, 0.5, 0.9, 0.4 if s == "cas_big" else 0.8)


## which result sound: net over 4x the bet (or 500) is the fanfare, over 15x (or 2,500) the jackpot; losing 200 or more, the sad trombone
static func result_kind(p) -> String:
	if not (p is Dictionary):
		return ""
	var net := float(p.get("net", 0))
	var bet := float(p.get("bet", 0))
	var x := net / bet if bet > 0 else 0.0
	if net < 0:
		return "cas_bust" if net <= -200 else "cas_lose"
	if net == 0:
		return "cas_push" if bet > 0 or float(p.get("back", 0)) > 0 else ""
	if x >= 15 or net >= 2500:
		return "cas_jackpot"
	if x >= 4 or net >= 500:
		return "cas_big"
	return "cas_win" if x >= 1 else "cas_small"


# ---------------------------------------------------------------- helpers over the view

static func _i(x) -> int:
	return int(x) if (x is float or x is int) else 0


static func _last_res(v: Dictionary) -> Dictionary:
	var L = v.get("last")
	return L.result if L is Dictionary and L.get("result") is Dictionary else {}


static func _last_no(v: Dictionary) -> String:
	var L = v.get("last")
	return PalTables.js(L.get("no")) if L is Dictionary else ""


func _uid() -> String:
	var a = tables.account
	return str(a.uid()) if a != null and a.uid() != null else ""


func mine_of(res: Dictionary):
	for p in res.get("players", []):
		if p is Dictionary and str(p.get("uid", "")) == _uid():
			return p
	return null


static func _me(v: Dictionary) -> Dictionary:
	var ss = v.get("seats", [])
	var i := _i(v.get("me", -1))
	return ss[i] if ss is Array and i >= 0 and i < ss.size() and ss[i] is Dictionary else {}


static func sum(o) -> int:
	var t := 0
	if o is Dictionary:
		for k in o:
			t += _i(o[k])
	return t


static func _ibets(o) -> Dictionary:
	var d := {}
	if o is Dictionary:
		for k in o:
			if _i(o[k]):
				d[str(k)] = _i(o[k])
	return d


static func _js(o) -> String:
	return JSON.stringify(o, "", true)


static func cg_net(n: int) -> String:
	return ("+" if n > 0 else ("−" if n < 0 else "")) + str(absi(n)) + "◆"


static func rl_name(n: int) -> String:
	return PalTables.rl_name(n)


static func rl_color(n: int) -> String:
	return "g" if n == 0 or n == 37 else ("r" if RL_RED.has(n) else "b")


func _tz() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0)) * 60


# ---------------------------------------------------------------- drawing it all

func _keys_reset() -> void:
	_key_felt = ""
	_key_acts = ""
	_key_review = ""


func _redraw_all() -> void:
	var v := tables.v
	if v.is_empty():
		return
	var me := _me(v)
	title_l.text = PalTables.NAME.get(v.game, "THE TABLES") + (" · CABINET " + str(v.station).substr(1) if v.get("station", "") != "" and v.game == "sl" else "")
	info_l.text = _info(v)
	stack_l.text = str(_i(me.get("stack", 0)))
	bal_l.text = str(tables.balance)
	var st := status(v, me)
	_status(st[0], st[1], st[2])
	var tm: bool = float(v.get("left", 0)) > 0 and v.get("phase") != "spin"
	timer_bar.visible = tm
	if tm:
		var full := 30000.0 if v.game == "ba" else (20000.0 if v.game == "cr" else 60000.0)
		timer_bar.value = minf(1.0, float(v.left) / full)
	stand_b.text = "STAND UP"
	foot.visible = true
	# the felt and the moves: rebuilt only when what they show changes (a rebuild mid-press would lose the press)
	var base := v.duplicate()
	for k in VOLATILE:
		base.erase(k)
	var stage := _stage(v)
	var fk := _js([base, stage, left(v) > 0, rl.bets if v.game == "rl" else 0, ba.bets if v.game == "ba" else 0, cr, _size.x])
	var ak := _js([base, left(v) > 0, amt, rl.chip, rl.bets, rl.last, ba.chip, ba.bets, ba.last, cr, sl_amt, pk_amt, float(v.get("minBetAt", 0)) > 0, _size.x])
	var rk := _review_key(v)
	if rk != _key_review:
		_key_review = rk
		_fill(review_box, func(): _review(v))
	if fk != _key_felt:
		_key_felt = fk
		_fill(felt_col, func(): _felt(v, me))
	if ak != _key_acts:
		_key_acts = ak
		_fill(acts, func(): _acts(v, me))
	log_l.text = " · ".join(PackedStringArray(v.get("log", [])))
	help_t.text = HELP.get(v.game, "")
	fair_t.text = _fair_text(v)
	if not seed_in.has_focus() and seed_in.text == "":
		seed_in.text = str(v.get("seed", ""))
	last_b.visible = not last_rcpt.is_empty()
	if _i(v.get("picks", 0)) > 0 and modal_kind != "pick":
		_pick_modal(v)


## the reveal step on screen now (cards turned, reels stopped): the felt redraws when it moves on
func _stage(v: Dictionary) -> int:
	if left(v) <= 0:
		return -1
	match v.game:
		"bj":
			return _i(ceilf(left(v) / 700.0))
		"ba":
			return _i(ceilf((left(v) - 300) / 700.0))
		"sl":
			return slot_window(v, false).stopped
	return 0


## empty a box and fill it again, keeping the keyboard / controller focus on the same action
func _fill(box: Container, build: Callable) -> void:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var fid := ""
	if f != null and box.is_ancestor_of(f) and f.has_meta("fid"):
		fid = f.get_meta("fid")
	for ch in box.get_children():
		box.remove_child(ch)
		ch.queue_free()
	build.call()
	if fid != "":
		var nb := _find_fid(box, fid)
		if nb == null:
			nb = _first_button(box)
		if nb == null:
			nb = _first_button(col)
		if nb != null:
			(func(): if is_instance_valid(nb) and nb.is_inside_tree(): nb.grab_focus()).call_deferred()


func _find_fid(n: Node, fid: String) -> Control:
	for ch in n.get_children():
		if ch is Control and ch.has_meta("fid") and ch.get_meta("fid") == fid and ch.focus_mode != Control.FOCUS_NONE and not (ch is BaseButton and ch.disabled):
			return ch
		var r := _find_fid(ch, fid)
		if r != null:
			return r
	return null


func _first_button(n: Node) -> Control:
	for ch in n.get_children():
		if ch is Control and ch.focus_mode == Control.FOCUS_ALL and ch.is_visible_in_tree() and not (ch is BaseButton and ch.disabled):
			return ch
		var r := _first_button(ch)
		if r != null:
			return r
	return null


## focus where the next move is (the first live action), else HIDE
func _focus_main() -> void:
	await get_tree().process_frame
	if not _open:
		return
	var f := _first_button(acts)
	if f == null:
		f = _first_button(felt_col)
	if f == null:
		f = hide_b
	f.grab_focus()


func _status(t: String, sub: String, kind: String) -> void:
	status_t.text = t
	status_s.text = sub
	var e := StyleBoxFlat.new()   # the coloured edge on the left says whose move it is
	e.bg_color = Color(226 / 255.0, 180 / 255.0, 54 / 255.0, 0.12) if kind == "you" else Color(0, 0, 0, 0.25)
	e.border_color = {"you": GOLD, "done": WINC, "warn": Color("#e8573a")}.get(kind, Color("#6f8a96"))
	e.border_width_left = 5
	e.set_content_margin_all(10)
	e.content_margin_left = 12
	status_box.add_theme_stylebox_override("panel", e)
	status_t.add_theme_color_override("font_color", AMBER if kind == "you" else (LOSSC if kind == "warn" else PAPER))


## the sheet when there's no table to show: why (sign in, can't sit), and a way out
func _show_no(text: String = "", kind: String = "warn") -> void:
	var t := text if text != "" else _no
	title_l.text = PalTables.NAME.get(game, "THE TABLES")
	info_l.text = "THE PALISADE FALLS CASINO"
	_status("CAN'T PLAY HERE" if kind == "warn" else "ONE MOMENT", t, kind)
	timer_bar.visible = false
	for b in [review_box, felt_col, acts]:
		for ch in b.get_children():
			b.remove_child(ch)
			ch.queue_free()
	felt_col.add_child(_lbl(t, 15, PAPER, true))
	_keys_reset()
	foot.visible = false
	stand_b.text = "LEAVE"
	help_t.text = HELP.get(game, "")
	fair_t.text = ""
	log_l.text = ""
	last_b.visible = not last_rcpt.is_empty()
	if kind == "warn":
		_focus_main()


func _info(v: Dictionary) -> String:
	match v.game:
		"ba":
			var sh = v.get("shoe")
			return "8 decks · Banker in 20s (pays 19:20) · Tie 8:1" + (" · shoe #%d, %d cards left" % [_i(sh.no), _i(sh.left)] if sh is Dictionary else "")
		"cr":
			var sh := _i(v.get("shooter", -1))
			var ss: Array = v.get("seats", [])
			return ("point %d" % _i(v.point) if _i(v.get("point", 0)) else "come-out") + " · shooter " + (str(ss[sh].name) if sh >= 0 and sh < ss.size() and ss[sh] is Dictionary else "the dealer") + " · odds 3-4-5x"
		"sl":
			return "PALISADE RUN · 1-100 a spin · one line · returns 96.03%"
		"pk":
			return "12 rows · stakes in 10s · 0.5x to 30x · returns 96.01%"
		"rl":
			return "american wheel · no limit"
	return ("max bet %d" % _i(v.lim) if _i(v.get("lim", 0)) else "no limit") + (" · side bet on" if v.get("side", false) else "") + " · " + str(v.get("hostName", "")) + " started it"


# ---------------------------------------------------------------- the status line (tbStatus)

func status(v: Dictionary, me: Dictionary) -> Array:
	var ph: String = v.get("phase", "")
	var P: Array = v.get("players", []) if v.get("players") is Array else []
	var hum := 0
	for s in v.get("seats", []):
		if s is Dictionary and not s.get("bot", false):
			hum += 1
	match v.game:
		"ba":
			var tot := sum(ba.bets)
			if ph == "bet":
				return ["READY", "%d ready · the cards come when everyone is (at least 5 s after the bets open) or in %ds" % [_i(v.get("readyN", 0)), secs(v)], "wait"] if v.get("readyMe", false) else ["PLACE YOUR BETS", ("%d◆ down · " % tot if tot else "") + "Player, Banker or Tie · %ds" % secs(v), "you"]
			if ph == "done":
				if left(v) > 0:
					return ["DEALING", "Player first, then Banker; third cards by the rules", "wait"]
				var vd = verdict(mine_of(_last_res(v)))
				return [vd if vd != null else "HAND OVER", str(_last_res(v).get("why", "")), "done"]
			return ["WAITING", "The next hand opens in a moment", "wait"]
		"cr":
			if ph == "bet":
				var n := sum(v.get("myBets"))
				var shi := _i(v.get("shooter", -1))
				var ss: Array = v.get("seats", [])
				var sh: String = "You have the dice: ROLL when your bets are down" if v.get("amShooter", false) else (str(ss[shi].name) + " shoots" if shi >= 0 and shi < ss.size() and ss[shi] is Dictionary else "The dealer shoots")
				if v.get("readyMe", false):
					return ["READY", "%d ready · the dice go when everyone is (at least 5 s after betting opens) or in %ds" % [_i(v.get("readyN", 0)), secs(v)], "wait"]
				return ["POINT IS %d" % _i(v.point) if _i(v.get("point", 0)) else "COME-OUT ROLL", sh + " · " + ("%d◆ on the layout · " % n if n else "") + "%ds" % secs(v), "you"]
			if ph == "done":
				if left(v) > 0:
					return ["ROLLING", "The dice are in the air", "wait"]
				var r := _last_res(v)
				var p = mine_of(r)
				var vd = verdict(p) if p != null else null
				return [vd if vd != null and vd != "" else "THE DICE: %d" % _i(r.get("total")), str(r.get("why", "")), "done"]
			return ["WAITING", "Betting opens in a moment", "wait"]
		"sl":
			if ph == "done":
				if left(v) > 0:
					return ["SPINNING", "Reels stop left to right", "wait"]
				var r := _last_res(v)
				return ["WIN" if _i(r.get("mult", 0)) else "LOSS", str(r.get("why", "")), "done"]
			return ["TOP UP", "Add shards to the machine (+5, +25 or +100 below)", "warn"] if _i(me.get("stack", 0)) < 1 else ["PLACE A BET AND SPIN", "%d◆ a spin · the line pays the single highest award" % sl_amt, "you"]
		"pk":
			if ph == "done":
				if left(v) > 0:
					return ["DROPPING", "Twelve bounces, decided before the ball moved", "wait"]
				var r := _last_res(v)
				var p: Dictionary = r.players[0] if r.get("players") is Array and not r.players.is_empty() else {}
				var net := _i(p.get("net", 0))
				return ["WIN" if net > 0 else ("LOSS" if net < 0 else "PUSH"), str(r.get("why", "")) + (" (less than your stake: a loss, though some shards come back)" if float(r.get("mult", 1)) < 1 else ""), "done"]
			return ["TOP UP", "Plinko needs at least 10 shards at the board (+5, +25 or +100 below)", "warn"] if _i(me.get("stack", 0)) < 10 else ["PICK A STAKE AND DROP", "%d◆ · stakes go in 10s so every pocket pays whole shards" % pk_amt, "you"]
		"rl":
			var n := (v.get("myBets", {}) as Dictionary).size() if v.get("myBets") is Dictionary else 0
			var tot := sum(rl.bets)
			if ph == "bet":
				if v.get("readyMe", false):
					return ["READY", "%d ready · the ball goes in %ds at most" % [_i(v.get("readyN", 0)), secs(v)], "wait"]
				if n or tot:
					return ["PLACE YOUR BETS", "%d◆ on the board · tap SPIN when you're done · %ds" % [tot, secs(v)], "you"]
				return ["PLACE YOUR BETS", "Pick a chip and tap the board · %ds" % secs(v), "you"]
			if ph == "spin":
				return ["NO MORE BETS", "The ball is spinning…", "wait"]
			if ph == "done" and not _last_res(v).is_empty():
				return ["IT'S " + rl_name(_i(_last_res(v).get("number"))), result_text(v), "done"]
			return ["WAITING", "", "wait"]
	if not v.get("started", true):
		if v.get("host", false):
			return ["WAITING TO START", "%d seated. Press START when everyone's sat down." % hum + (" With one player, SLIM (the bot) sits in when his wallet allows." if v.game == "he" and hum < 2 else ""), "wait"]
		return ["WAITING FOR " + (str(v.hostName) if str(v.get("hostName", "")) != "" else "THE HOST"), "%s starts the table when everyone's sat down." % str(v.get("hostName", "")), "wait"]
	if _i(me.get("stack", 0)) < (1 if v.game == "bj" else 2) and ph != "play":
		return ["OUT OF SHARDS AT THE TABLE", "Top up (+5 or +25 below) to keep playing, or stand up.", "warn"]
	if v.game == "bj":
		var bets = v.get("bets")
		if ph == "bet":
			return ["BET PLACED", "Waiting for the others · cards in %ds at most" % secs(v), "wait"] if bets is Dictionary and bets.has(str(_i(v.me))) else ["PLACE YOUR BET", "Pick an amount and press BET · %ds left" % secs(v), "you"]
		if ph == "ins":
			return ["DEALER SHOWS AN ACE", "Insurance costs half your bet and pays 2:1 if the dealer has blackjack. Most players say no.", "you"] if v.get("insure", false) else ["INSURANCE", "Waiting for the others to decide.", "wait"]
		if ph == "done" and not _last_res(v).is_empty():
			if left(v) > 0:
				return ["THE DEALER PLAYS", "The hole card turns, then the dealer draws to 17", "wait"]
			var p = mine_of(_last_res(v))
			var rls := ceili(review_left(v) / 1000.0)
			var whys := PackedStringArray()
			if p != null:
				for h in p.get("hands", []):
					whys.append(str(h.get("why", "")))
			return [verdict(p) if p != null else "HAND OVER", (" · ".join(whys) + " · " if p != null else "") + ("next bets in %ds" % rls if rls > 0 else "betting opens now"), "done"]
		if ph == "play":
			var tn = v.get("turn", {})
			var cur = P[_i(tn.p)] if tn is Dictionary and _i(tn.get("p", -1)) >= 0 and _i(tn.p) < P.size() else null
			if v.get("myTurn", false) and cur != null:
				var h: Dictionary = cur.hands[_i(tn.h)]
				return ["YOUR TURN", "You have %d%s · the dealer shows %d" % [_i(h.total), " (soft)" if h.get("soft", false) and _i(h.total) < 21 else "", _i(v.get("dealerTotal", 0))] + (" · hand %d of %d" % [_i(tn.h) + 1, cur.hands.size()] if cur.hands.size() > 1 else ""), "you"]
			return ["WAITING", "%s is playing" % (str(cur.name) if cur != null else "The dealer"), "wait"]
		return ["DEALING", "", "wait"]
	if ph == "wait":
		return ["WAITING FOR PLAYERS", "Hold'em deals with 2 or more players with at least 2 shards (SLIM sits in with one or two people when his wallet allows).", "wait"]
	if ph == "play":
		var cur = null
		for p in P:
			if p.get("turn", false):
				cur = p
		if v.get("myTurn", false):
			var c: Dictionary = v.get("can", {})
			return ["YOUR TURN", ("%d to call" % _i(c.call) if _i(c.get("call", 0)) else "Nobody has bet: check or bet") + " · pot %d" % _i(v.get("pot", 0)), "you"]
		return ["WAITING", ("%s is thinking%s" % [cur.name, " (bot)" if cur.get("bot", false) else ""]) if cur != null else "… is thinking", "wait"]
	if ph == "done":
		return ["HAND OVER", (result_text(v) + " · " if not _last_res(v).is_empty() else "") + ("You're ready · next hand in %ds (or when everyone's ready)" % secs(v) if v.get("readyMe", false) else "Next hand in %ds · tap READY to deal sooner" % secs(v)), "done"]
	return ["", "", "wait"]


## the last round in one line (tbResult)
func result_text(v: Dictionary) -> String:
	var r := _last_res(v)
	var me := _me(v)
	if v.game == "rl":
		var mine = null
		for p in r.get("players", []):
			if _i(p.get("seat", -1)) == _i(v.me):
				mine = p
		return rl_name(_i(r.get("number"))) + ((" · you " + ("won +%d◆" % _i(mine.net) if _i(mine.net) > 0 else ("lost %d◆" % -_i(mine.net) if _i(mine.net) < 0 else "broke even"))) if mine != null else "")
	if v.game == "bj":
		var mine = null
		for p in r.get("players", []):
			if str(p.get("name")) == str(me.get("name")):
				mine = p
		var t := "Dealer %d%s" % [_i(r.get("total")), " (bust)" if _i(r.get("total")) > 21 else ""]
		if mine != null:
			var n := _i(mine.net)
			t += " · you " + ("won +" if n > 0 else ("lost " if n < 0 else "broke even ")) + ("%d◆" % absi(n) if n else "")
		return t
	var ws := PackedStringArray()
	for p in r.get("players", []):
		if _i(p.get("won", 0)) > 0:
			ws.append("%s wins %d◆%s" % [p.name, _i(p.won), " with " + str(p.hand).to_lower() if p.get("hand") else ""])
	return " · ".join(ws) + (" · house %d◆" % _i(r.rake) if _i(r.get("rake", 0)) else "")


# ---------------------------------------------------------------- the receipt (every game)

## WIN, LOSS, PUSH or PARTIAL RESULT, in words (the colour only repeats it)
static func verdict(p):
	if not (p is Dictionary):
		return null
	var it: Array = p.get("items", []) if p.get("items") is Array else []
	var hands: Array = p.get("hands", []) if p.get("hands") is Array else []
	var won := false
	var lost := false
	for x in it:
		var stake := _i(x.get("bet", x.get("stake", 0))) if x.get("bet") != null else _i(x.get("stake", 0))
		if _i(x.get("back", 0)) > stake:
			won = true
		if stake > 0 and not _i(x.get("back", 0)):
			lost = true
	for h in hands:
		var res := str(h.get("result", ""))
		if res.contains("WIN") or res.contains("BLACKJACK"):
			won = true
		if res.contains("LOSE") or res.contains("BUST"):
			lost = true
	var net := _i(p.get("net", 0))
	if net > 0:
		return "PARTIAL RESULT" if lost else "WIN"
	if net < 0:
		return "PARTIAL RESULT" if won else "LOSS"
	if not (_i(p.get("bet", 0)) > 0) and not (_i(p.get("back", 0)) > 0):
		return "NO DECISION"
	return "PARTIAL RESULT" if won and lost else "PUSH"


static func cr_label(k: String) -> String:
	if CR_LABEL.has(k):
		return CR_LABEL[k]
	var re := RegEx.create_from_string("^([cdph])(\\d+)(o?)$")
	var mm := re.search(k)
	if mm == null:
		return k
	return {"c": "COME ", "d": "DON'T COME ", "p": "PLACE ", "h": "HARD "}[mm.get_string(1)] + mm.get_string(2) + (" ODDS" if mm.get_string(3) != "" else "")


static func rl_spot_name(k: String) -> String:
	var re := RegEx.create_from_string("^([a-z]+)(?::([0-9-]+))?$")
	var mm := re.search(k)
	if mm == null:
		return k
	var a := mm.get_string(2).replace("37", "00")
	var t := mm.get_string(1)
	var pre: String = {"n": "NUMBER ", "sp": "SPLIT ", "st": "STREET ", "tr": "TRIO ", "co": "CORNER ", "sl": "SIX LINE ", "dz": "DOZEN ", "col": "COLUMN "}.get(t, t.to_upper())
	return "TOP LINE" if t == "tl" else pre + a   # the browser prints "TLTOP LINE" here


static func item_label(g: String, k: String) -> String:
	if g == "cr":
		return cr_label(k)
	if g == "rl":
		return rl_spot_name(k)
	return ITEM_LABEL.get(k, k)


## the receipt: the verdict, BET / RETURNED / NET, each bet, what decided it (tbReceiptHTML)
func _receipt(g: String, res: Dictionary, opt: Dictionary) -> Control:
	var me = mine_of(res)
	var vd = verdict(me) if me != null else null
	var c: Color = {"WIN": WINC, "LOSS": Color("#e8573a"), "PUSH": PUSHC, "NO DECISION": PUSHC}.get(vd, GOLD) if vd != null else Color("#6f8a96")
	var tc: Color = {"WIN": WINC, "LOSS": LOSSC, "PUSH": PUSHC, "NO DECISION": PUSHC}.get(vd, AMBER) if vd != null else Color.WHITE
	var pc := _panel(Color(0, 0, 0, 0.35), c, 2, 10, 6)
	var b := _vbox(4)
	pc.add_child(b)
	var hr := HBoxContainer.new()
	var vl := _lbl(vd if vd != null else "NOT IN THIS ROUND", 24, tc, false, true)
	vl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(vl)
	hr.add_child(_lbl(PalTables.NAME.get(g, "") + (" · round " + str(res.rid).split(":")[-1] if res.get("rid") else ""), 11, DIM))
	b.add_child(hr)
	if me != null:
		var tr := HBoxContainer.new()
		tr.add_theme_constant_override("separation", 6)
		for x in [["BET", "%d◆" % _i(me.get("bet", 0)), PAPER], ["RETURNED", "%d◆" % _i(me.get("back", 0)), PAPER], ["NET", cg_net(_i(me.get("net", 0))), WINC if _i(me.get("net", 0)) > 0 else (LOSSC if _i(me.get("net", 0)) < 0 else PAPER)]]:
			var cell := _panel(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 0, 4)
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var cv := _vbox(0)
			var l1 := _lbl(x[0], 10, DIM)
			l1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var l2 := _lbl(x[1], 20, x[2], false, true)
			l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			cv.add_child(l1)
			cv.add_child(l2)
			cell.add_child(cv)
			tr.add_child(cell)
		b.add_child(tr)
		if g != "sl" and g != "pk":
			for x in me.get("items", []):
				if str(x.get("res", "")).begins_with("moves"):
					continue
				var ir := HBoxContainer.new()
				var a := _lbl(item_label(g, str(x.k)), 12, PAPER)
				a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				ir.add_child(a)
				var stake = x.get("bet") if x.get("bet") != null else x.get("stake")
				ir.add_child(_lbl("%d◆ → %d◆%s%s" % [_i(stake), _i(x.get("back", 0)), " (commission %s◆)" % PalTables.js(x.commission) if x.get("commission") else "", " · " + str(x.res) if x.get("res") and g == "cr" else ""], 12, TEXT2))
				b.add_child(ir)
		if me.get("commission"):
			b.add_child(_lbl("Banker commission %s◆ (5%% of the Banker win)" % PalTables.js(me.commission), 12, DIM, true))
	_evidence(b, g, res, me)
	if opt.get("wallet"):
		b.add_child(_lbl(opt.wallet, 11, SKY, true))
	if opt.get("next"):
		b.add_child(_lbl(opt.next, 11, DIM, true))
	return pc


## what decided it, game by game: the cards, the dice, the reels, the pocket (cgEvidence)
func _evidence(b: VBoxContainer, g: String, res: Dictionary, me) -> void:
	var row := func(head: String, cards, em: String, p: String = "", dim: bool = false) -> void:
		var r := HFlowContainer.new()
		r.add_theme_constant_override("h_separation", 8)
		r.add_child(_lbl(head, 13, GOLD, false, true))
		if cards is Array:
			r.add_child(_cards(cards, true))
		if em != "":
			r.add_child(_lbl(em, 12, TEXT2))
		if dim:
			r.modulate.a = 0.7
		b.add_child(r)
		if p != "":
			b.add_child(_lbl(p, 12, AMBER, true))
	match g:
		"bj":
			row.call("DEALER", res.get("dealer", []), "%d%s%s" % [_i(res.get("total")), " soft" if res.get("soft", false) else "", " · BUST" if _i(res.get("total")) > 21 else (" · BLACKJACK" if res.get("dbj", false) else "")])
			if me != null:
				var hs: Array = me.get("hands", [])
				for i in hs.size():
					var x: Dictionary = hs[i]
					row.call("HAND %d" % (i + 1) if hs.size() > 1 else "YOU", x.get("cards", []), "%d%s · %s%s" % [_i(x.get("total")), " soft" if x.get("soft", false) else "", str(x.get("result", "")), " (doubled)" if x.get("doubled", false) else ""], str(x.get("why", "")))
		"he":
			row.call("BOARD", res.get("board", []), "")
			var ps: Array = res.get("players", [])
			if res.get("uncontested", false):
				var w = null
				for p in ps:
					if _i(p.get("won", 0)) > 0:
						w = p
				b.add_child(_lbl("%s wins %d◆ uncontested: everyone else folded, so no cards are shown." % [w.name, _i(w.won)] if w != null else "Everyone folded.", 12, TEXT2, true))
			else:
				for pt in res.get("pots", []):
					var ws := PackedStringArray()
					for s in pt.get("winners", []):
						var nm := "?"
						for p in ps:
							if _i(p.get("seat", -1)) == _i(s):
								nm = str(p.name)
						ws.append(nm)
					row.call("%s %d◆" % ["SIDE POT" if _i(pt.get("k", 0)) else "POT", _i(pt.amount)], pt.get("five") if pt.get("five") is Array else null, " + ".join(ws) + " · " + str(pt.get("hand", "") if pt.get("hand") != null else ""))
			for p in ps:
				if p.get("cards") is Array:
					row.call(str(p.name), p.cards, str(p.get("hand", "")) if p.get("hand") != null else "", "", true)
			if _i(res.get("rake", 0)):
				b.add_child(_lbl("House cut %d◆" % _i(res.rake), 12, DIM))
		"rl":
			var n := _i(res.get("number"))
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 8)
			r.add_child(_lbl("THE BALL", 13, GOLD, false, true))
			r.add_child(_lbl(rl_name(n), 13, {"red": Color("#ff6a6a"), "black": CREAM, "green": Color("#6ad08a")}.get(str(res.get("color", "")), PAPER), false, true))
			b.add_child(r)
		"ba":
			row.call("PLAYER %d" % _i(res.get("pt")), res.get("player", []), "")
			row.call("BANKER %d" % _i(res.get("bt")), res.get("banker", []), "")
			b.add_child(_lbl(str(res.get("why", "")), 12, TEXT2, true))
		"cr":
			var r := HBoxContainer.new()
			r.add_theme_constant_override("separation", 8)
			r.add_child(_lbl("THE DICE", 13, GOLD, false, true))
			var dv := DiceView.new(self, 22)
			dv.fixed = (res.get("dice", []) as Array).map(func(x): return int(x))
			r.add_child(dv)
			var t := _i(res.get("total"))
			r.add_child(_lbl("%d%s" % [t, " (hard)" if res.get("hard", false) and [4, 6, 8, 10].has(t) else ""], 13, TEXT2))
			b.add_child(r)
			b.add_child(_lbl("%s · point %s → %s" % [res.get("why", ""), "was %d" % _i(res.point) if _i(res.get("point", 0)) else "off", "now %d" % _i(res.newPoint) if _i(res.get("newPoint", 0)) else "off"], 12, TEXT2, true))
			var w: Array = me.get("working", []) if me != null and me.get("working") is Array else []
			if not w.is_empty():
				b.add_child(_lbl("Still working: " + " · ".join(PackedStringArray(w.map(func(x): return cr_label(str(x.k)) + " %d◆" % _i(x.a)))), 12, DIM, true))
		"sl":
			var rv := Reels.new(self)
			rv.fixed = res.get("window", [])
			rv.small = true
			b.add_child(rv)
			b.add_child(_lbl(str(res.get("why", "")), 12, TEXT2, true))
		"pk":
			b.add_child(_lbl(str(res.get("why", "")), 12, TEXT2, true))


## what's on the felt for you right now (committed, not yet decided); never counted twice with the table stack
func committed(v: Dictionary) -> int:
	var g: String = v.game
	var ph: String = v.get("phase", "")
	if g == "rl" or g == "ba" or g == "cr":
		return sum(v.get("myBets")) if ph == "bet" or g == "cr" or (g == "rl" and ph == "spin") else 0
	if g == "bj":
		if ph == "bet":
			var bets = v.get("bets")
			return _i(bets.get(str(_i(v.me)), 0)) if bets is Dictionary else 0
		if ph == "play" or ph == "ins":
			for p in v.get("players", []):
				if _i(p.seat) == _i(v.me):
					var t := 0
					for h in p.hands:
						t += _i(h.bet)
					return t
		return 0
	if g == "he" and ph == "play":
		for p in v.get("players", []):
			if _i(p.seat) == _i(v.me):
				return _i(p.put)
	return 0


func _review_key(v: Dictionary) -> String:
	if v.get("phase") != "done" or _last_res(v).is_empty():
		return ""
	if left(v) > 0:
		return "live:" + _last_no(v)
	return _js([_last_no(v), ceili(review_left(v) / 1000.0), ceili(maxf(0, float(v.get("left", 0)) - (_now() - float(v.get("_t", 0)))) / 1000.0), tables.balance, _me(v).get("stack"), committed(v), v.get("readyMe", false)])


## the review at the top of the felt: while the reveal runs it says so; then the receipt and its countdown (tbReview)
func _review(v: Dictionary) -> void:
	if v.get("phase") != "done" or _last_res(v).is_empty():
		return
	if left(v) > 0:
		var pc := _panel(Color(0, 0, 0, 0.35), Color("#6f8a96"), 2, 10, 6)
		pc.add_child(_lbl({"cr": "ROLLING…", "sl": "SPINNING…", "pk": "DROPPING…", "rl": "THE BALL HAS LANDED"}.get(v.game, "DEALING…"), 24, PAPER, false, true))
		review_box.add_child(pc)
		return
	var me := _me(v)
	var rls := ceili(review_left(v) / 1000.0)
	var nxt := ceili(maxf(0, float(v.get("left", 0)) - (_now() - float(v.get("_t", 0)))) / 1000.0) if v.game == "he" else rls
	var nx := ("Result on screen for %ds more" % rls if rls > 0 else "Result reviewed")
	if v.game == "he":
		nx += " · next hand in %ds%s" % [nxt, "" if rls > 0 else " (READY deals sooner)"]
	elif v.game != "sl" and v.game != "pk":
		nx += " · then betting opens"
	nx += " · HIDE keeps your seat · STAND UP takes your shards home"
	review_box.add_child(_receipt(v.game, _last_res(v), {"wallet": "Balance %d◆ · at the table %d◆ · on the felt %d◆" % [tables.balance, _i(me.get("stack", 0)), committed(v)], "next": nx}))


## keep your last receipt for LAST RESULT (tbKeep)
func _keep(v: Dictionary) -> void:
	var r := _last_res(v)
	if r.is_empty() or mine_of(r) == null:
		return
	var k := "%s:%s:%s" % [v.get("game"), v.get("station", ""), _last_no(v)]
	if last_rcpt.get("k") == k:
		return
	last_rcpt = {"k": k, "game": v.game, "res": r, "at": Time.get_unix_time_from_system()}
	if last_b != null:
		last_b.visible = true


# ---------------------------------------------------------------- cards

## a card: rank and suit on a cream face, red for hearts and diamonds; null is a card face down
func _card(c, small: bool = false, slot: bool = false) -> Control:
	var p := PanelContainer.new()
	var sz := Vector2(26, 36) if small else Vector2(34, 48)
	p.custom_minimum_size = sz
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if slot:
		p.add_theme_stylebox_override("panel", _sb(Color(0, 0, 0, 0), Color(243 / 255.0, 236 / 255.0, 220 / 255.0, 0.25), 1, 0, 4))
		return p
	if c == null:
		var s := _sb(Color("#7a1f1f"), CREAM, 2, 0, 4)
		p.add_theme_stylebox_override("panel", s)
		var hatch := ColorRect.new()
		hatch.color = Color("#5a1414")
		hatch.custom_minimum_size = sz - Vector2(10, 10)
		hatch.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		hatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		p.add_child(hatch)
		return p
	var ci := _i(c)
	var suit := (ci % 52) / 13
	var ink := CARD_RED if suit == 1 or suit == 2 else Color("#17140f")
	var s2 := _sb(CREAM, Color(0, 0, 0, 0.5), 0, 0, 4)
	s2.shadow_color = Color(0, 0, 0, 0.5)
	s2.shadow_size = 2
	s2.shadow_offset = Vector2(0, 2)
	p.add_theme_stylebox_override("panel", s2)
	var vb := VBoxContainer.new()
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.add_theme_constant_override("separation", -4)
	var a := _lbl(RANK[ci % 52 % 13], 12 if small else 17, ink, false, true)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := _lbl(SUIT[suit], 11 if small else 15, ink)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(a)
	vb.add_child(b)
	p.add_child(vb)
	return p


func _cards(cs: Array, small: bool = false, center: bool = false) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 4)
	if center:
		r.alignment = BoxContainer.ALIGNMENT_CENTER
	for c in cs:
		r.add_child(_card(c, small))
	return r


func _center(c: Control) -> Control:
	if c is Label:
		c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return c


## a seat on the felt: name (YOU, BOT), what's at the table, the hand
func _seat(s: Dictionary, inner: Array, turn: bool, tag: String = "") -> PanelContainer:
	var border := GOLD if s.get("me", false) else Color(243 / 255.0, 236 / 255.0, 220 / 255.0, 0.15)
	if turn:
		border = WINC
	var pc := _panel(Color(0, 0, 0, 0.28), border, 2 if turn or s.get("me", false) else 1, 6, 8)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var b := _vbox(2)
	var n := _lbl(str(s.get("name", "")) + ("  YOU" if s.get("me", false) else "") + tag, 13, Color("#c9b6ff") if s.get("bot", false) else PAPER, false, true)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	n.custom_minimum_size.x = 40
	b.add_child(n)
	b.add_child(_center(_lbl("%d ◆ at the table" % _i(s.get("stack", 0)), 11, SKY)))
	for x in inner:
		b.add_child(x)
	pc.add_child(b)
	return pc


func _seat_grid(items: Array) -> GridContainer:
	var g := GridContainer.new()
	var w := sheet.size.x - 50 if sheet.size.x > 0 else 380.0
	g.columns = clampi(int(w / 130), 1, maxi(1, items.size()))
	g.add_theme_constant_override("h_separation", 8)
	g.add_theme_constant_override("v_separation", 8)
	for x in items:
		g.add_child(x)
	return g


# ---------------------------------------------------------------- the felt, game by game

func _felt(v: Dictionary, me: Dictionary) -> void:
	match v.game:
		"bj":
			_felt_bj(v)
		"he":
			_felt_he(v)
		"rl":
			_felt_rl(v)
		"ba":
			_felt_ba(v)
		"cr":
			_felt_cr(v)
		"sl":
			_felt_sl(v)
		"pk":
			_felt_pk(v)


func _felt_bj(v: Dictionary) -> void:
	var lr := _last_res(v)
	var last_bj: Dictionary = lr if (v.get("phase") == "bet" or v.get("dealer") == null) and lr.get("dealer") is Array else {}
	var dealer = v.get("dealer") if v.get("dealer") is Array else (last_bj.get("dealer") if not last_bj.is_empty() else null)
	var dt = v.get("dealerTotal") if v.get("dealer") is Array else (last_bj.get("total") if not last_bj.is_empty() else null)
	if v.get("phase") == "done" and v.get("dealer") is Array and left(v) > 0:   # the reveal, card by card
		var n: int = v.dealer.size()
		var k := maxi(1, n - ceili(left(v) / 700.0))
		dealer = []
		for i in n:
			dealer.append(v.dealer[i] if i < k else null)
		dt = null
		stage_sfx(v, k, "cas_card")
	var db := _vbox(2)
	db.add_child(_center(_lbl("DEALER" + (" · LAST HAND" if not last_bj.is_empty() else ""), 14, GOLD, false, true)))
	db.add_child(_cards(dealer if dealer is Array else [null, null], false, true))
	db.add_child(_center(_lbl(("%d%s" % [_i(dt), " · BUST" if _i(dt) > 21 else ""]) if dt != null and _i(dt) else "", 12, TEXT2)))
	if not last_bj.is_empty():
		db.modulate.a = 0.55
	felt_col.add_child(db)
	var items: Array = []
	var tn = v.get("turn", {})
	var P: Array = v.get("players", []) if v.get("players") is Array else []
	for s in v.get("seats", []):
		if not (s is Dictionary):
			continue
		var p = null
		for q in P:
			if _i(q.seat) == _i(s.i):
				p = q
		var bets = v.get("bets")
		var bt = bets.get(str(_i(s.i))) if bets is Dictionary else null
		var lp = null
		for x in last_bj.get("players", []):
			if str(x.get("name")) == str(s.name):
				lp = x
		var inner: Array = []
		var turn := false
		if p != null:
			var hs: Array = p.hands
			turn = tn is Dictionary and _i(tn.get("p", -1)) >= 0 and _i(tn.p) < P.size() and P[_i(tn.p)] == p and v.get("phase") == "play"
			for hi in hs.size():
				var h: Dictionary = hs[hi]
				var hv := _vbox(2)
				hv.add_child(_cards(h.get("cards", []), true, true))
				var res := str(h.get("result", "")) if h.get("result") != null else ""
				var line := "%d%s · bet %d◆" % [_i(h.total), " soft" if h.get("soft", false) and _i(h.total) < 21 else "", _i(h.bet)]
				var hr := HBoxContainer.new()
				hr.alignment = BoxContainer.ALIGNMENT_CENTER
				hr.add_child(_lbl(line, 12, TEXT2))
				if res != "":
					hr.add_child(_lbl(" · " + res, 12, WINC if res == "WIN" or res == "BLACKJACK" else (PUSHC if res == "PUSH" else LOSSC), false, true))
				hv.add_child(hr)
				if turn and _i(tn.h) == hi:
					var hp := _panel(Color(0, 0, 0, 0), WINC, 2, 2, 4)
					hp.add_child(hv)
					inner.append(hp)
				else:
					inner.append(hv)
		elif v.get("phase") == "bet":
			inner.append(_center(_lbl("BET %d◆ ✓" % _i(bt) if bt != null else "choosing a bet…", 12, TEXT2)))
			if lp != null:
				var ll := _center(_lbl("last hand: %s%d◆" % ["+" if _i(lp.net) > 0 else "", _i(lp.net)], 12, TEXT2))
				ll.modulate.a = 0.55
				inner.append(ll)
		items.append(_seat(s, inner, turn))
	felt_col.add_child(_seat_grid(items))


func _felt_he(v: Dictionary) -> void:
	var db := _vbox(2)
	db.add_child(_center(_lbl("POT %d ◆" % _i(v.get("pot", 0)), 14, GOLD, false, true)))
	var r := _row(4)
	var board: Array = v.get("board", []) if v.get("board") is Array else []
	for c in board:
		r.add_child(_card(c))
	for i in 5 - board.size():
		r.add_child(_card(null, false, true))
	db.add_child(r)
	var streets := ["BEFORE THE FLOP", "FLOP", "TURN", "RIVER"]
	var sti := _i(v.get("street", 0))
	db.add_child(_center(_lbl((streets[sti] if sti < 4 else "") + (" · bet to match %d◆" % _i(v.toCall) if _i(v.get("toCall", 0)) else ""), 12, TEXT2)))
	felt_col.add_child(db)
	var items: Array = []
	for s in v.get("seats", []):
		if not (s is Dictionary):
			continue
		var p = null
		for q in v.get("players", []) if v.get("players") is Array else []:
			if _i(q.seat) == _i(s.i):
				p = q
		var inner: Array = []
		if p != null:
			inner.append(_cards(p.get("cards", []), true, true))
			inner.append(_center(_lbl(("FOLDED" if p.get("folded", false) else ("ALL IN" if p.get("allin", false) else ("bet %d◆" % _i(p.bet) if _i(p.get("bet", 0)) else "·"))) + (" · in pot %d◆" % _i(p.put) if _i(p.get("put", 0)) else ""), 12, TEXT2)))
		else:
			inner.append(_center(_lbl("not in this hand", 12, TEXT2)))
		items.append(_seat(s, inner, p != null and p.get("turn", false), "  BOT" if s.get("bot", false) else ""))
	felt_col.add_child(_seat_grid(items))


## a row of past results: LAST SPINS, the ROAD, the ROLLS
func _hist_row(title: String, items: Array) -> HFlowContainer:
	var r := HFlowContainer.new()
	r.add_theme_constant_override("h_separation", 3)
	r.add_theme_constant_override("v_separation", 3)
	r.add_child(_lbl(title, 10, DIM))
	if items.is_empty():
		r.add_child(_lbl("none yet", 10, DIM))
	for x in items:   # [text, colour, new]
		var p := _panel(x[1], AMBER if x.size() > 2 and x[2] else Color(0, 0, 0, 0), 2 if x.size() > 2 and x[2] else 0, 0, 3)
		p.custom_minimum_size = Vector2(22, 20)
		var l := _lbl(x[0], 12, Color.WHITE, false, true)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		r.add_child(p)
	return r


const RL_COL := {"r": Color("#b8202c"), "b": Color("#141214"), "g": Color("#0e7a3a")}


func _felt_rl(v: Dictionary) -> void:
	var open: bool = v.get("phase") == "bet" and not v.get("readyMe", false)
	var hist: Array = (v.get("hist", []) as Array).duplicate()
	hist.reverse()
	var hi: Array = []
	for i in hist.size():
		var n := _i(hist[i])
		hi.append(["00" if n == 37 else str(n), RL_COL[rl_color(n)], i == 0 and v.get("phase") == "done"])
	felt_col.add_child(_hist_row("LAST SPINS ", hi))
	if v.get("phase") != "bet" and v.has("number"):
		var n := _i(v.number)
		var nr := _row(10)
		var ball := _panel(Color("#333333") if v.phase == "spin" else RL_COL[rl_color(n)], Color("#d6aa46"), 3, 0, 26)
		ball.custom_minimum_size = Vector2(52, 52)
		var bl := _lbl("…" if v.phase == "spin" else ("00" if n == 37 else str(n)), 26, Color.WHITE, false, true)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		ball.add_child(bl)
		nr.add_child(ball)
		nr.add_child(_lbl("NO MORE BETS" if v.phase == "spin" else rl_name(n), 16, PAPER, false, true))
		felt_col.add_child(nr)
	var mine: Dictionary = rl.bets if open else _ibets(v.get("myBets"))
	var others := {}
	var bets = v.get("bets")
	if bets is Dictionary:
		for si in bets:
			if int(si) != _i(v.me):
				for k in bets[si]:
					others[k] = _i(others.get(k, 0)) + _i(bets[si][k])
	var brow := HBoxContainer.new()
	brow.add_theme_constant_override("separation", 2)
	var board := RlBoard.new(self)
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(0, clampf(_size.x * 0.1, 118, 180) if _size.x >= 700 else 118.0)
	board.open = open
	board.mine = mine
	board.others = others
	board.hit = _i(v.number) if v.get("phase") == "done" and v.has("number") else -1
	board.set_meta("fid", "rlboard")
	brow.add_child(board)
	var cols := VBoxContainer.new()
	cols.add_theme_constant_override("separation", 1)
	for c in [3, 2, 1]:
		var cb := _spot_btn("2:1", "col:%d" % c, open, mine, others, Color("#0f5a34"))
		cb.custom_minimum_size = Vector2(30, 0)
		cb.size_flags_vertical = Control.SIZE_EXPAND_FILL
		cols.add_child(cb)
	brow.add_child(cols)
	if open:   # the controller moves a cursor over the board; this says which bet it's on
		rl_hint = _lbl("", 11, DIM)
		board.hint = rl_hint
	felt_col.add_child(brow)
	var outs := VBoxContainer.new()
	outs.add_theme_constant_override("separation", 2)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 2)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 2)
	for o in RL_OUT:
		var bg := Color("#9a1a24") if o[0] == "red" else (Color("#121012") if o[0] == "black" else Color("#0f5a34"))
		var b := _spot_btn(o[1], o[0], open, mine, others, bg)
		(r1 if str(o[0]).begins_with("dz") else r2).add_child(b)
	outs.add_child(r1)
	outs.add_child(r2)
	var oc := MarginContainer.new()
	oc.add_theme_constant_override("margin_right", 32)
	oc.add_child(outs)
	felt_col.add_child(oc)
	if rl_hint != null and open:
		felt_col.add_child(rl_hint)


## a bet box on the felt (roulette's outside bets and columns, baccarat's spots): your chips on it, the others' too
func _spot_btn(label: String, spot: String, open: bool, mine: Dictionary, others: Dictionary, bg: Color) -> Button:
	var b := Button.new()
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	b.text = label
	b.disabled = not open
	b.set_meta("fid", "spot:" + spot)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 36 if _size.x >= 700 else 30)
	b.add_theme_font_size_override("font_size", 12)
	b.add_theme_stylebox_override("normal", _sb(bg, Color(240 / 255.0, 230 / 255.0, 200 / 255.0, 0.5), 1, 2))
	b.add_theme_stylebox_override("hover", _sb(bg.lightened(0.15), GOLD, 1, 2))
	b.add_theme_stylebox_override("disabled", _sb(bg.darkened(0.2), Color(240 / 255.0, 230 / 255.0, 200 / 255.0, 0.3), 1, 2))
	b.add_theme_stylebox_override("pressed", _sb(bg.lightened(0.3), GOLD, 1, 2))
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.75))
	if _i(mine.get(spot, 0)):
		b.add_child(Chip.new(_i(mine[spot]), false, Vector2(1, 0.5)))
	if _i(others.get(spot, 0)):
		b.add_child(Chip.new(_i(others[spot]), true, Vector2(0, 0.5)))
	b.pressed.connect(func(): rl_add(spot) if game == "rl" else ba_spot(spot))
	return b


func _felt_ba(v: Dictionary) -> void:
	var open: bool = v.get("phase") == "bet" and not v.get("readyMe", false)
	var road: Array = v.get("road", []) if v.get("road") is Array else []
	var ri: Array = []
	for x in road.slice(maxi(0, road.size() - 36)):
		ri.append([str(x), {"P": Color("#2a5ab0"), "B": Color("#b8202c"), "T": Color("#1f8a4a")}.get(str(x), Color.GRAY)])
	felt_col.add_child(_hist_row("ROAD (what happened, not a forecast) ", ri))
	var sh := bac_shown(v, true)
	var lr := _last_res(v)
	var old: bool = v.get("phase") != "done" and lr.get("player") is Array
	var hands := HBoxContainer.new()
	hands.add_theme_constant_override("separation", 8)
	for side in [["PLAYER", lr.get("player", []) if old else sh.P], ["BANKER", lr.get("banker", []) if old else sh.B]]:
		var hb := _vbox(2)
		hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var cs: Array = side[1]
		hb.add_child(_center(_lbl(side[0] + (" %d" % ba_tot(cs) if not cs.is_empty() else ""), 14, GOLD, false, true)))
		hb.add_child(_cards(cs if not cs.is_empty() else [null, null], false, true))
		if old:
			hb.modulate.a = 0.5
		hands.add_child(hb)
	felt_col.add_child(hands)
	var others := {}
	var bets = v.get("bets")
	if bets is Dictionary:
		for si in bets:
			if int(si) != _i(v.me):
				for k in bets[si]:
					others[k] = _i(others.get(k, 0)) + _i(bets[si][k])
	var spots := HBoxContainer.new()
	spots.add_theme_constant_override("separation", 6)
	for s in [["P", "PLAYER", "1:1", Color("#5a8ae0")], ["T", "TIE", "8:1", Color("#5ad08a")], ["B", "BANKER", "19:20 · in 20s", Color("#e05a5a")]]:
		var b := _spot_btn("", s[0], open, ba.bets, {}, Color(0, 0, 0, 0.25))
		b.custom_minimum_size = Vector2(0, 70)
		b.add_theme_stylebox_override("normal", _sb(Color(0, 0, 0, 0.25), s[3], 2, 4))
		b.add_theme_stylebox_override("disabled", _sb(Color(0, 0, 0, 0.25), s[3].darkened(0.4), 2, 4))
		var vb := VBoxContainer.new()
		vb.set_anchors_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_theme_constant_override("separation", 0)
		vb.add_child(_center(_lbl(s[1], 18, PAPER, false, true)))
		vb.add_child(_center(_lbl(s[2], 10, DIM)))
		if _i(others.get(s[0], 0)):
			vb.add_child(_center(_lbl("others %d◆" % _i(others[s[0]]), 10, SKY)))
		if not open:
			vb.modulate.a = 0.55
		b.add_child(vb)
		b.move_child(vb, 0)
		spots.add_child(b)
	felt_col.add_child(spots)
	felt_col.add_child(_lbl("Banker bets go in 20s: 20 on Banker pays 19 plus your 20 back. A tie returns Player and Banker bets.", 12, DIM, true))


## a baccarat hand's count: aces 1, 2-9 face value, 10/J/Q/K 0, the last digit
static func ba_tot(cs: Array) -> int:
	var t := 0
	for c in cs:
		var r := _i(c) % 52 % 13
		t += r + 2 if r <= 7 else (1 if r == 12 else 0)
	return t % 10


## the baccarat cards on show now: dealt in order (Player, Banker, Player, Banker, thirds), one every 0.7 s (cgBacShown)
func bac_shown(v: Dictionary, sound: bool = false) -> Dictionary:
	var o := {"P": [], "B": []}
	if v.is_empty() or not (v.get("P") is Array) or v.get("phase") != "done":
		return o
	var order: Array = v.get("order", [])
	var n := order.size()
	var lf := left(v)
	var k := n if lf <= 0 else maxi(0, mini(n, n - ceili((lf - 300) / 700.0)))
	for i in k:
		var s: String = order[i][0]
		o[s].append((v.P if s == "P" else v.B)[_i(order[i][1])])
	if sound and v == tables.v:
		stage_sfx(v, k, "cas_card")
	return o


func _felt_cr(v: Dictionary) -> void:
	var B: Dictionary = _ibets(v.get("myBets"))
	var P := _i(v.get("point", 0))
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var puck := _panel(CREAM if P else Color("#141214"), CREAM, 2, 0, 23)
	puck.custom_minimum_size = Vector2(46, 46)
	var pl := _lbl("ON\n%d" % P if P else "OFF", 13 if P else 11, Color("#141214") if P else CREAM, false, true)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	puck.add_child(pl)
	top.add_child(puck)
	top.add_child(DiceView.new(self, 30))
	var rolls: Array = v.get("rolls", []) if v.get("rolls") is Array else []
	var ri: Array = []
	var rs := rolls.slice(maxi(0, rolls.size() - 14))
	rs.reverse()
	for d in rs:
		var t := _i(d[0]) + _i(d[1])
		ri.append([str(t), Color("#b8202c") if t == 7 else (Color("#555555") if [2, 3, 12].has(t) else Color(1, 1, 1, 0.12))])
	var hr := _hist_row("ROLLS ", ri)
	hr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(hr)
	felt_col.add_child(top)
	# the numbers: come and don't come bets that have moved there, with their odds
	var pts := HBoxContainer.new()
	pts.add_theme_constant_override("separation", 3)
	for n in CR_PTS:
		var pc := _panel(Color(243 / 255.0, 236 / 255.0, 220 / 255.0, 0.12) if P == n else Color(0, 0, 0, 0), CREAM if P == n else LINE, 1, 3)
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var pv := _vbox(1)
		pv.add_child(_center(_lbl(str(n), 18, PAPER, false, true)))
		if B.has("c%d" % n):
			pv.add_child(_center(_lbl("COME %d◆" % B["c%d" % n], 10, SKY)))
			pv.add_child(_cr_spot(v, "c%do" % n, "+ ODDS", "in %ds" % CR_ODDS_D[n] if CR_ODDS_D[n] > 1 else "2:1", "mini"))
		if B.has("d%d" % n):
			pv.add_child(_center(_lbl("DON'T %d◆" % B["d%d" % n], 10, SKY)))
			pv.add_child(_cr_spot(v, "d%do" % n, "+ LAY", "in %ds" % CR_LAY_D[n] if CR_LAY_D[n] > 1 else "", "mini"))
		pc.add_child(pv)
		pts.add_child(pc)
	felt_col.add_child(pts)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.add_child(_cr_spot(v, "pass", "PASS LINE", "locked while the point is on" if P else "1:1"))
	grid.add_child(_cr_spot(v, "dp", "DON'T PASS", "1:1 · bar 12"))
	if P:
		grid.add_child(_cr_spot(v, "po", "PASS ODDS", "up to %dx · %s" % [CR_MULT_C[P], {4: "2:1", 10: "2:1", 5: "3:2", 9: "3:2", 6: "6:5", 8: "6:5"}[P]]))
		grid.add_child(_cr_spot(v, "dpo", "LAY ODDS", "up to 6x"))
	grid.add_child(_cr_spot(v, "come", "COME", "1:1 · point on"))
	grid.add_child(_cr_spot(v, "dc", "DON'T COME", "1:1 · bar 12"))
	grid.add_child(_cr_spot(v, "field", "FIELD", "2,3,4,9,10,11 1:1 · 2,12 2:1"))
	grid.add_child(_cr_spot(v, "p6", "PLACE 6", "7:6 · in 6s"))
	grid.add_child(_cr_spot(v, "p8", "PLACE 8", "7:6 · in 6s"))
	felt_col.add_child(grid)
	if cr.adv:
		var g2 := GridContainer.new()
		g2.columns = 4 if _size.x >= 700 else 3
		g2.add_theme_constant_override("h_separation", 5)
		g2.add_theme_constant_override("v_separation", 5)
		for n in [4, 5, 9, 10]:
			g2.add_child(_cr_spot(v, "p%d" % n, "PLACE %d" % n, ("9:5" if n == 4 or n == 10 else "7:5") + " · in 5s"))
		for n in [4, 6, 8, 10]:
			g2.add_child(_cr_spot(v, "h%d" % n, "HARD %d" % n, "7:1" if n == 4 or n == 10 else "9:1"))
		for x in [["any7", "ANY 7", "4:1"], ["anyc", "ANY CRAPS", "7:1"], ["n2", "TWO", "30:1"], ["n3", "THREE", "15:1"], ["n11", "ELEVEN", "15:1"], ["n12", "TWELVE", "30:1"]]:
			g2.add_child(_cr_spot(v, x[0], x[1], x[2]))
		felt_col.add_child(g2)
	var F: Dictionary = v.get("flags", {}) if v.get("flags") is Dictionary else {}
	var tg := _row(6)
	for x in [["place", "PLACE"], ["hard", "HARDWAYS"], ["codds", "COME ODDS"]]:
		var on: bool = F.get(x[0], false)
		tg.add_child(_btn(x[1] + ": " + ("ON" if on else "OFF"), "crf:" + x[0], {"cl": "sel" if on else "", "hint": "on the come-out"}))
	felt_col.add_child(tg)
	var oth := PackedStringArray()
	var bets = v.get("bets")
	var gone: Array = v.get("gone", []) if v.get("gone") is Array else []
	if bets is Dictionary:
		for si in bets:
			var i := int(si)
			if i != _i(v.me):
				var ss: Array = v.get("seats", [])
				var nm: String = str(ss[i].name) if i < ss.size() and ss[i] is Dictionary else "?"
				oth.append("%s%s %d◆" % [nm, " (left)" if i < gone.size() and gone[i] else "", sum(bets[si])])
	if not oth.is_empty():
		felt_col.add_child(_lbl("On the layout: " + " · ".join(oth), 12, DIM, true))


## can a craps bet go down (or, taking down, come off) right now
func _cr_can(v: Dictionary, k: String) -> bool:
	var open: bool = v.get("phase") == "bet" and not v.get("readyMe", false)
	var B: Dictionary = _ibets(v.get("myBets"))
	var P := _i(v.get("point", 0))
	if cr.down:
		return _i(B.get(k, 0)) > 0 and not (v.get("locked", []) as Array).has(k) and not (k == "pass" and P)
	if not open:
		return false
	if k == "pass":
		return not P
	if k == "come" or k == "dc":
		return P != 0
	if k == "po":
		return P != 0 and _i(B.get("pass", 0)) > 0
	if k == "dpo":
		return P != 0 and _i(B.get("dp", 0)) > 0
	var re := RegEx.create_from_string("^([cd])(\\d+)(o?)$")
	var mm := re.search(k)
	if mm != null:
		if mm.get_string(3) == "":
			return false
		return _i(B.get(mm.get_string(1) + mm.get_string(2), 0)) > 0
	return true


func _cr_spot(v: Dictionary, k: String, nm: String, pay: String, cls: String = "") -> Button:
	var B: Dictionary = _ibets(v.get("myBets"))
	var a := _i(B.get(k, 0))
	var b := Button.new()
	b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
	b.set_meta("fid", "cr:" + k)
	b.disabled = not _cr_can(v, k)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(0, 26 if cls == "mini" else 46)
	b.clip_contents = true
	var bg := Color(15 / 255.0, 90 / 255.0, 52 / 255.0, 0.35)
	b.add_theme_stylebox_override("normal", _sb(bg, GOLD if a else LINE, 1, 2))
	b.add_theme_stylebox_override("hover", _sb(bg.lightened(0.1), GOLD, 1, 2))
	b.add_theme_stylebox_override("disabled", _sb(bg.darkened(0.3), GOLD.darkened(0.4) if a else Color("#2a251c"), 1, 2))
	b.add_theme_stylebox_override("pressed", _sb(bg.lightened(0.3), GOLD, 1, 2))
	var vb := VBoxContainer.new()
	vb.set_anchors_preset(Control.PRESET_FULL_RECT)
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_theme_constant_override("separation", 0)
	vb.add_child(_center(_lbl(nm, 10 if cls == "mini" else 14, PAPER, false, true)))
	if pay != "" and cls != "mini":
		var pl := _center(_lbl(pay, 9, DIM))
		pl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		vb.add_child(pl)
	if b.disabled:
		vb.modulate.a = 0.45
	b.add_child(vb)
	if a:
		b.add_child(Chip.new(a, false, Vector2(1, 1)))
	if (v.get("locked", []) as Array).has(k) and a:
		var lk := _lbl("LOCKED", 8, AMBER)
		lk.position = Vector2(4, 2)
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lk)
	b.pressed.connect(func(): cr_spot(k))
	return b


func _felt_sl(v: Dictionary) -> void:
	var cab := _panel(Color("#212026"), Color("#d6aa46"), 2, 10, 10)
	var cv := _vbox(6)
	cv.add_child(Reels.new(self))
	var r := _last_res(v)
	var done: bool = not r.is_empty() and v.get("phase") == "done" and left(v) <= 0
	var pay := ""
	var pc := WINC
	if done:
		if _i(r.get("mult", 0)):
			var back := _i(r.players[0].get("back", 0)) if r.get("players") is Array and not r.players.is_empty() else 0
			pay = "%s · %dx · +%d◆" % [r.get("combo", ""), _i(r.mult), back]
		else:
			pay = "NO WIN"
			pc = DIM
	cv.add_child(_center(_lbl(pay, 15, pc, false, true)))
	cab.add_child(cv)
	felt_col.add_child(cab)
	var pt := _btn("PAYTABLE (gross, your stake included)  +", "paytable")
	pt.alignment = HORIZONTAL_ALIGNMENT_LEFT
	felt_col.add_child(pt)
	var box := _vbox(2)
	box.visible = bool(get_meta("paytable", false))
	for x in SLOT_PAYS:
		var row := HBoxContainer.new()
		var a := _lbl(x[0], 12, PAPER)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(a)
		row.add_child(_lbl("%dx" % x[1], 12, AMBER))
		box.add_child(row)
	box.add_child(_lbl("20 stops a reel, each one as likely as the next: 8,000 combinations. The line pays on 37.5% of them, more than your stake on 16.3% (the rest of the 37.5% give the stake back); return 96.03% (math sl-1). Every spin is on its own: past spins, your balance and your account change nothing. The reels stop where the server's numbers say; the symbols above and below are the real reel.", 12, DIM, true))
	felt_col.add_child(box)


## what the cabinet shows now: reels turning until each one's stop at 1.4, 2.0 and 2.6 s (cgSlotWindow)
func slot_window(v: Dictionary, sound: bool = true) -> Dictionary:
	var r := _last_res(v)
	if r.is_empty() or not (r.get("window") is Array):
		return {"win": [["S", "P", "W"], ["W", "P", "N"], ["N", "P", "S"]], "stopped": 3}
	var lf := left(v)
	var el := 2600.0 - lf
	var stopped := 3
	if lf > 0:
		stopped = 0
		for t in [1400.0, 2000.0, 2600.0]:
			if el >= t:
				stopped += 1
	if sound and v == tables.v:
		stage_sfx(v, stopped, "cas_reel")
	var t := int(_now() / 70.0)
	var win: Array = []
	for i in 3:
		if i < stopped:
			win.append(r.window[i])
		else:
			win.append([0, 1, 2].map(func(q): return CG_STRIPS[i][(t + q + i * 7) % 20]))
	return {"win": win, "stopped": stopped}


func _felt_pk(v: Dictionary) -> void:
	var pb := Plinko.new(self)
	felt_col.add_child(pb)
	var r := _last_res(v)
	var done: bool = v.get("phase") == "done" and left(v) <= 0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 2)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for k in 13:
		var mlt: int = PK_MULT_D[k]
		var bg := Color("#ff4a6a") if mlt >= 90 else (Color("#ffb43a") if mlt >= 30 else (Color("#4aff9a") if mlt >= 10 else Color("#3a8aff")))
		var hit: bool = done and not r.is_empty() and _i(r.get("pocket", -1)) == k
		var p := _panel(bg, Color.WHITE if hit else Color(0, 0, 0, 0), 2 if hit else 0, 0, 3)
		p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		p.custom_minimum_size = Vector2(0, 22 if hit else 18)
		var l := _lbl(PalTables.js(mlt / 10.0) + "x", 9, Color.WHITE if mlt < 10 else Color("#17140f"))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		p.add_child(l)
		row.add_child(p)
	var mc := MarginContainer.new()
	mc.add_child(row)
	felt_col.add_child(mc)
	felt_col.add_child(_lbl("Each bounce is 50/50, so the middle pockets are the likeliest (pocket 7: 22.6%) and the edges the rarest (1 in 4,096 each). 1x returns your stake; under 1x some shards come back but it's a loss. Returns 96.01% (math pk-1).", 12, DIM, true))


# ---------------------------------------------------------------- the moves, game by game (tbActions)

func _chip_row(chips: Array, cur: int, avail: int) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	for a in chips:
		var b := Button.new()
		b.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		b.set_meta("fid", "chip:%d" % a)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(40, 44)
		b.disabled = avail >= 0 and a > avail
		if a == cur:
			b.add_theme_stylebox_override("normal", _sb(Color(226 / 255.0, 180 / 255.0, 54 / 255.0, 0.25), GOLD, 1))
		var ch := Chip.new(a, false, Vector2(0.5, 0.5))
		ch.radius = 16
		if b.disabled:
			ch.modulate.a = 0.35
		b.add_child(ch)
		var aa: int = a
		b.pressed.connect(func(): _act("chip:%d" % aa))
		r.add_child(b)
	return r


func _hint(t: String) -> Label:
	return _lbl(t, 12, DIM, true)


func _acts(v: Dictionary, me: Dictionary) -> void:
	var c: Dictionary = v.get("can", {}) if v.get("can") is Dictionary else {}
	var ph: String = v.get("phase", "")
	var stack := _i(me.get("stack", 0))
	match v.game:
		"rl":
			if ph != "bet":
				acts.add_child(_hint("The ball is spinning." if ph == "spin" else "Next spin's betting opens in a moment."))
				return
			if v.get("readyMe", false):
				acts.add_child(_hint("You're in with %d◆. The ball goes when everyone's ready, or in %ds." % [sum(v.get("myBets")), secs(v)]))
				return
			var tot := sum(rl.bets)
			var last_t := sum(rl.last)
			acts.add_child(_chip_row(RL_CHIPS, rl.chip, stack + tot))
			var r := _row()
			r.add_child(_btn("CLEAR", "rlclear", {"on": tot > 0}))
			r.add_child(_btn("REBET", "rlrebet", {"on": last_t > 0 and last_t <= stack + tot, "hint": "%d◆" % last_t if last_t else ""}))
			r.add_child(_btn("DOUBLE", "rldouble", {"on": tot > 0 and tot <= stack, "hint": "to %d◆" % (tot * 2) if tot else ""}))
			acts.add_child(r)
			acts.add_child(_btn("SPIN", "rlspin", {"cl": "go big", "on": tot > 0, "hint": "%d◆ on the board" % tot if tot else "place a bet first"}))
			return
		"ba":
			var tot := sum(ba.bets)
			var last_t := sum(ba.last)
			if ph != "bet":
				acts.add_child(_hint("Next bets open after the result." if ph == "done" else "Betting opens in a moment."))
				return
			if v.get("readyMe", false):
				acts.add_child(_hint("You're in with %d◆. Cards when everyone's ready, or in %ds." % [sum(v.get("myBets")), secs(v)]))
				return
			acts.add_child(_chip_row([5, 10, 20, 50, 100, 500], ba.chip, stack + tot))
			var r := _row()
			r.add_child(_btn("CLEAR", "baclear", {"on": tot > 0}))
			r.add_child(_btn("REBET", "barebet", {"on": last_t > 0 and last_t <= stack + tot, "hint": "%d◆" % last_t if last_t else ""}))
			acts.add_child(r)
			var mb := float(v.get("minBetAt", 0))
			acts.add_child(_btn("DEAL", "baready", {"cl": "go big", "on": tot > 0, "hint": ("%d◆ down" % tot + (" · cards no sooner than %ds" % ceili(mb / 1000.0) if mb > 0 else "")) if tot else "place a bet first"}))
			return
		"cr":
			if ph != "bet":
				acts.add_child(_hint("Betting opens after the result." if ph == "done" else "Betting opens in a moment."))
				return
			var tot := sum(v.get("myBets"))
			acts.add_child(_chip_row([1, 5, 10, 25, 100], cr.chip, -1))
			var r := _row()
			r.add_child(_btn("TAKING DOWN: ON" if cr.down else "TAKE DOWN", "crdown", {"cl": "sel" if cr.down else "", "hint": "tap a bet to take it off"}))
			r.add_child(_btn("SIMPLE LAYOUT" if cr.adv else "ALL BETS", "cradv", {"hint": "line, field, place 6/8" if cr.adv else "place, hardways, props"}))
			acts.add_child(r)
			if v.get("readyMe", false):
				acts.add_child(_hint("Ready. The dice go when everyone is, or in %ds." % secs(v)))
			else:
				var mb := float(v.get("minBetAt", 0))
				acts.add_child(_btn("ROLL" if v.get("amShooter", false) else "READY", "crready", {"cl": "go big", "on": tot > 0 or v.get("amShooter", false), "hint": ("you have the dice" if v.get("amShooter", false) else "done betting") + (" · no sooner than %ds" % ceili(mb / 1000.0) if mb > 0 else "")}))
			return
		"sl":
			var busy := ph != "idle"
			var bt := _row(10)
			bt.add_child(_btn("−", "slamt-", {"on": sl_amt > 1, "w": 54}))
			bt.add_child(_amt_box(sl_amt, "shards a spin"))
			bt.add_child(_btn("+", "slamt+", {"on": sl_amt < 100, "w": 54}))
			acts.add_child(bt)
			var r := _row()
			for a in [1, 5, 10, 25, 50, 100]:
				r.add_child(_btn(str(a), "slset:%d" % a, {"cl": "sel" if sl_amt == a else ""}))
			acts.add_child(r)
			acts.add_child(_btn("…" if busy else "SPIN %d◆" % sl_amt, "slspin", {"cl": "go big", "on": not busy and stack >= sl_amt, "hint": "the result stays up 3 s after the last reel" if busy else ("top up to spin" if stack < sl_amt else "one spin per press")}))
			return
		"pk":
			var busy := ph != "idle"
			var r := _row()
			for a in [10, 20, 50, 100, 250, 500]:
				r.add_child(_btn(str(a), "pkset:%d" % a, {"cl": "sel" if pk_amt == a else ""}))
			acts.add_child(r)
			acts.add_child(_btn("…" if busy else "DROP %d◆" % pk_amt, "pkdrop", {"cl": "go big", "on": not busy and stack >= pk_amt, "hint": "the result stays up 3 s after the ball lands" if busy else ("top up to drop" if stack < pk_amt else "one ball per press")}))
			return
	# blackjack and hold'em: the host's START and table rules, the side bet
	var humans := 0
	for s in v.get("seats", []):
		if s is Dictionary and not s.get("bot", false):
			humans += 1
	if not v.get("started", true) and v.get("host", false):
		acts.add_child(_btn("START THE TABLE", "start", {"on": humans >= 1, "cl": "go big", "hint": "%d seated" % humans if humans >= 1 else "nobody seated"}))
		acts.add_child(_hint("Table rules (you can change these until you start):"))
		var r := _row()
		for l in [100, 250, 0]:
			r.add_child(_btn("MAX BET %d" % l if l else "NO LIMIT", "lim:%d" % l, {"cl": "sel" if _i(v.get("lim", 0)) == l else ""}))
		acts.add_child(r)
		acts.add_child(_btn("SIDE BET " + ("ON" if v.get("side", false) else "OFF"), "tside", {"cl": "sel" if v.get("side", false) else "", "hint": "players opt in, 1◆ a hand"}))
	var bets = v.get("bets")
	var my_bet = bets.get(str(_i(v.me))) if bets is Dictionary else null
	var between: bool = (ph == "bet" and my_bet == null) if v.game == "bj" else ph != "play"
	if v.get("side", false) and v.get("started", true) and between:
		acts.add_child(_btn("MY SIDE BET: " + ("ON" if me.get("side", false) else "OFF"), "myside", {"cl": "sel" if me.get("side", false) else "", "hint": "1◆ a hand · double aces" + (" or a full house" if v.game == "he" else "") + " wins 10 Hybrid / 15 Flag Cases"}))
	if v.game == "bj":
		if ph == "bet" and my_bet == null and stack >= 1:
			var mx := mini(_i(v.lim), stack) if _i(v.get("lim", 0)) else stack
			amt = maxi(1, mini(amt, mx))
			var bt := _row(10)
			bt.add_child(_btn("−", "amt-", {"w": 54}))
			bt.add_child(_amt_box(amt, "shards"))
			bt.add_child(_btn("+", "amt+", {"w": 54}))
			acts.add_child(bt)
			var r := _row()
			for x in [1, 5, 10, 25]:
				if x <= mx:
					r.add_child(_btn(str(x), "set:%d" % x, {"cl": "sel" if amt == x else ""}))
			r.add_child(_btn("MAX %d" % mx, "set:%d" % mx, {"cl": "sel" if amt == mx else ""}))
			acts.add_child(r)
			acts.add_child(_btn("BET %d◆" % amt, "bet", {"cl": "go big"}))
		if v.get("insure", false):
			var cost := 0
			for p in v.get("players", []):
				if _i(p.seat) == _i(v.me):
					cost = _i(p.hands[0].bet) / 2
			var r := _row()
			r.add_child(_btn("TAKE INSURANCE", "ins:1", {"hint": "costs %d◆" % cost}))
			r.add_child(_btn("NO INSURANCE", "ins:0", {"cl": "go"}))
			acts.add_child(r)
		if v.get("myTurn", false):
			var bet := 0
			for p in v.get("players", []):
				if _i(p.seat) == _i(v.me):
					bet = _i(p.hands[_i(v.turn.h)].bet)
			var r := _row()
			r.add_child(_btn("HIT", "hit", {"cl": "go big", "hint": "take a card"}))
			r.add_child(_btn("STAND", "stand", {"cl": "go big", "hint": "keep your total"}))
			acts.add_child(r)
			var r2 := _row()
			r2.add_child(_btn("DOUBLE", "double", {"on": c.get("double", false), "hint": "+%d◆, one more card" % bet}))
			r2.add_child(_btn("SPLIT", "split", {"on": c.get("split", false), "hint": "+%d◆, two hands" % bet if c.get("split", false) else "needs a pair"}))
			acts.add_child(r2)
		return
	if v.get("myTurn", false):
		var mn := _i(c.get("minPut", 0))
		var mxp := _i(c.get("maxPut", 0))
		raise_amt = maxi(mn, mini(raise_amt if raise_amt else mn, mxp))
		var r := _row()
		r.add_child(_btn("FOLD", "fold", {"hint": "give up this hand"}))
		if c.get("check", false):
			r.add_child(_btn("CHECK", "check", {"cl": "go big", "hint": "pass"}))
		else:
			r.add_child(_btn("CALL %d◆" % _i(c.get("call", 0)), "call", {"cl": "go big", "hint": "match the bet"}))
		acts.add_child(r)
		if c.get("raise", false):
			var sl := HSlider.new()
			sl.min_value = mn
			sl.max_value = mxp
			sl.step = 1
			sl.value = raise_amt
			sl.set_meta("fid", "raise_slider")
			sl.focus_mode = Control.FOCUS_ALL
			sl.custom_minimum_size = Vector2(0, 24)
			acts.add_child(sl)
			var r2 := _row()
			var rb := _btn(("RAISE " if _i(c.get("call", 0)) else "BET ") + "%d◆" % raise_amt, "raise", {"cl": "go", "hint": "put in %d-%d" % [mn, mxp]})
			r2.add_child(rb)
			if c.get("allin", false):
				r2.add_child(_btn("ALL IN %d◆" % _i(c.get("stack", 0)), "allin", {"hint": "everything at the table"}))
			acts.add_child(r2)
			sl.value_changed.connect(func(x):
				raise_amt = int(x)
				var l := rb.get_child(0).get_child(0) as Label
				l.text = ("RAISE " if _i(c.get("call", 0)) else "BET ") + "%d◆" % raise_amt)
		elif c.get("allin", false) and _i(c.get("stack", 0)) > _i(c.get("call", 0)):
			acts.add_child(_btn("ALL IN %d◆" % _i(c.get("stack", 0)), "allin"))
	if ph == "done" and not v.get("readyMe", false) and stack >= 2:
		acts.add_child(_btn("READY FOR THE NEXT HAND", "ready", {"cl": "go big"}))


func _amt_box(n: int, what: String) -> VBoxContainer:
	var b := _vbox(0)
	b.custom_minimum_size = Vector2(110, 0)
	b.add_child(_center(_lbl(str(n), 38, AMBER, false, true)))
	b.add_child(_center(_lbl(what, 11, DIM)))
	return b


## every button on the sheet comes here (the browser's tbActs click handler and CG[game].act)
func _act(a: String) -> void:
	match a:
		"hide":
			close()
			return
		"stand":
			_stand()
			return
		"help":
			help_t.visible = not help_t.visible
			help_b.text = "HOW TO PLAY  " + ("−" if help_t.visible else "+")
			return
		"fair":
			fair_box.visible = not fair_box.visible
			fair_b.text = "FAIR PLAY: YOUR SEED AND THE CHECK  " + ("−" if fair_box.visible else "+")
			return
		"paytable":
			set_meta("paytable", not bool(get_meta("paytable", false)))
			_key_felt = ""
			_redraw_all()
			return
		"last":
			last_result()
			return
		"hist":
			show_history()
			return
		"rules":
			_rules()
			return
		"seed":
			_set_seed()
			return
	var v := tables.v
	if v.is_empty():
		return
	var me := _me(v)
	if a.begins_with("top:"):
		tables.send({"op": "topup", "id": tables.id, "amt": int(a.substr(4))})
		return
	if a.begins_with("chip:"):
		var n := int(a.substr(5))
		if v.game == "rl":
			rl.chip = n
		elif v.game == "ba":
			ba.chip = n
		elif v.game == "cr":
			cr.chip = n
		_redraw_all()
		return
	match a:
		"rlclear":
			rl.bets = {}
			rl_queue()
		"rlrebet":
			rl.bets = rl.last.duplicate()
			rl_queue()
		"rldouble":
			for k in rl.bets:
				rl.bets[k] *= 2
			rl_queue()
		"rlspin":
			rl.send_at = 0.0
			if rl.dirty:
				await rl_flush()
			tables.send({"op": "rlready", "id": tables.id})
		"baclear":
			ba.bets = {}
			ba_queue()
		"barebet":
			ba.bets = ba.last.duplicate()
			ba_queue()
		"baready":
			ba.send_at = 0.0
			if ba.dirty:
				await ba_flush()
			tables.send({"op": "baready", "id": tables.id})
		"crdown":
			cr.down = not cr.down
			_redraw_all()
		"cradv":
			cr.adv = not cr.adv
			_redraw_all()
		"crready":
			_cr_send({"op": "crready", "id": tables.id})
		"slamt-", "slamt+":
			sl_amt = clampi(sl_amt + (1 if a == "slamt+" else -1), 1, 100)
			_redraw_all()
		"slspin":
			if v.get("phase") == "idle":
				_play("cas_lever")
				tables.send({"op": "spin", "id": tables.id, "amt": sl_amt})
		"pkdrop":
			if v.get("phase") == "idle":
				_play("cas_chip")
				tables.send({"op": "drop", "id": tables.id, "amt": pk_amt})
		"start":
			tables.send({"op": "start", "id": tables.id})
		"tside":
			tables.send({"op": "settings", "id": tables.id, "side": not v.get("side", false)})
		"myside":
			tables.send({"op": "side", "id": tables.id, "on": not me.get("side", false)})
		"amt-", "amt+":
			amt = maxi(1, amt + (1 if a == "amt+" else -1))
			_redraw_all()
		"bet":
			tables.send({"op": "bet", "id": tables.id, "amt": amt, "side": bool(me.get("side", false))})
		"ins:1", "ins:0":
			tables.send({"op": "insure", "id": tables.id, "yes": a == "ins:1"})
		"ready":
			tables.send({"op": "ready", "id": tables.id})
		"raise":
			tables.send({"op": "move", "id": tables.id, "a": "raise", "amt": raise_amt})
		"hit", "stand", "double", "split", "fold", "check", "call", "allin":
			tables.send({"op": "move", "id": tables.id, "a": a})
		_:
			if a.begins_with("slset:"):
				sl_amt = int(a.substr(6))
				_redraw_all()
			elif a.begins_with("pkset:"):
				pk_amt = int(a.substr(6))
				_redraw_all()
			elif a.begins_with("set:"):
				amt = int(a.substr(4))
				_redraw_all()
			elif a.begins_with("lim:"):
				tables.send({"op": "settings", "id": tables.id, "lim": int(a.substr(4))})
			elif a.begins_with("crf:"):
				var F: Dictionary = (v.get("flags", {}) as Dictionary).duplicate()
				var k := a.substr(4)
				F[k] = not F.get(k, false)
				tables.send({"op": "crflags", "id": tables.id, "flags": F}, true)


## STAND UP: off the seat at once (the floor), the leave goes to the server (casStand)
## STAND UP: give the seat back to the server (the floor's Esc, and leaving the casino)
func stand() -> void:
	await _stand()


func _stand() -> void:
	if tables.id == 0:
		close()
		stood_up.emit()
		return
	close()
	await tables.leave()


func _set_seed() -> void:
	var re := RegEx.create_from_string("[^0-9A-Za-z_-]")
	var s := re.sub(seed_in.text, "", true).substr(0, 64)
	if s == "":
		msg_l.text = "Pick a seed (letters and numbers)"
		return
	seed_in.text = s
	if persist_seed:
		var f := FileAccess.open(SEED_PATH, FileAccess.WRITE)
		if f != null:
			f.store_string(s)
	if tables.id == 0:
		return
	var r := await tables.send({"op": "seed", "id": tables.id, "seed": s})
	if not r.get("error"):
		msg_l.text = "Your seed is in from the next round."


# ---------------------------------------------------------------- roulette: bets on the board

## which spot a tap on the numbers lands on: col 0-11, row 0 (top: 3, 6, …) to 2 (bottom), fx/fy where in the cell (rlHit)
static func rl_hit(c: int, row: int, fx: float, fy: float) -> String:
	const E := .24
	var L := fx < E
	var R := fx > 1 - E
	var T := fy < E
	var Bm := fy > 1 - E
	if L and c > 0:
		return rl_hit(c - 1, row, 1, fy)
	if T and row > 0:
		return rl_hit(c, row - 1, fx, 1)
	var n := c * 3 + (3 - row)
	if L:   # the edge next to 0 and 00 (col 0): 00 is the top half, 0 the bottom half
		if row == 2:
			return "tl" if Bm else ("tr:0-1-2" if T else "sp:0-1")
		if row == 1:
			return "tr:0-1-2" if Bm else ("tr:0-2-37" if absf(fy - .5) < .2 else ("sp:2-37" if fy < .5 else "sp:0-2"))
		return "tr:2-3-37" if Bm else "sp:3-37"
	if row == 2 and Bm:
		return "sl:%d" % n if R and c < 11 else "st:%d" % n
	if Bm and R and c < 11:
		return "co:%d" % (n - 1)
	if Bm:
		return "sp:%d-%d" % [n - 1, n]
	if R and c < 11:
		return "sp:%d-%d" % [n, n + 3]
	return "n:%d" % n


## a tap on the numbers in board units (x: -1 to 12 with 0 and 00 in -1..0, y: 0 to 3)
func rl_tap(x: float, y: float) -> void:
	var k := rl_spot_at(x, y)
	if k != "":
		rl_add(k)


static func rl_spot_at(x: float, y: float) -> String:
	if x < -1 or x > 12 or y < 0 or y > 3:
		return ""
	if x < 0:
		return "sp:0-37" if absf(y - 1.5) < .25 else ("n:37" if y < 1.5 else "n:0")
	var c := mini(11, floori(x))
	var row := clampi(floori(y), 0, 2)
	return rl_hit(c, row, x - c, y - row)


## where a spot's chips sit, in board units (rlPos)
static func rl_pos(k: String) -> Variant:
	var re := RegEx.create_from_string("^([a-z]+)(?::([0-9-]+))?$")
	var mm := re.search(k)
	if mm == null:
		return null
	var t := mm.get_string(1)
	var ns: Array = []
	if mm.get_string(2) != "":
		for x in mm.get_string(2).split("-"):
			ns.append(int(x))
	var at := func(n: int) -> Vector2:
		return Vector2(-.5, 2.25) if n == 0 else (Vector2(-.5, .75) if n == 37 else Vector2(floori((n - 1) / 3.0) + .5, 2 - (n - 1) % 3 + .5))
	if t == "n":
		return at.call(ns[0])
	if t == "tl":
		return Vector2(0, 3)
	if t == "st":
		return Vector2(floori((ns[0] - 1) / 3.0) + .5, 3)
	if t == "sl":
		return Vector2(floori((ns[0] - 1) / 3.0) + 1, 3)
	if t == "co":
		var p: Vector2 = at.call(ns[0])
		return Vector2(p.x + .5, p.y - .5)
	if t == "sp" or t == "tr":
		if ns.has(0) and ns.has(37) and ns.size() == 2:
			return Vector2(-.5, 1.5)
		var z := ns.has(0) or ns.has(37)
		var ps: Array = []
		for n in ns:
			if not z or (n != 0 and n != 37):
				ps.append(at.call(n))
		var y := 0.0
		var x := 0.0
		for p in ps:
			y += p.y
			x += p.x
		y /= ps.size()
		x /= ps.size()
		if z:
			return Vector2(0, (2.0 if ns.has(1) else (1.0 if ns.has(3) else 1.5)) if t == "tr" else y)
		return Vector2(x, y)
	return null


## keep your board in step with the server's: it adopts what the server holds only when you haven't touched the board for
## 2 s and nothing is on its way (a poll answered from before your last tap would otherwise wipe that tap) (rlSync)
func rl_sync(v: Dictionary) -> void:
	var hn := _i(v.get("handNo", 0))
	if hn != rl.hand:
		if rl.hand >= 0 and sum(rl.sentBets):
			rl.last = rl.sentBets.duplicate()
		rl.hand = hn
		rl.bets = {}
		rl.sent = ""
		rl.sentBets = {}
	if v.get("phase") != "bet":
		rl.bets = _ibets(v.get("myBets"))
		return
	var mb := _ibets(v.get("myBets"))
	if not rl.dirty and not rl.inflight and _now() - rl.at > 2000 and _js(mb) != rl.sent:
		rl.bets = mb
		rl.sent = _js(mb)
		rl.sentBets = mb.duplicate()


func rl_add(k: String) -> void:
	var v := tables.v
	if v.is_empty() or v.get("game") != "rl" or v.get("phase") != "bet" or v.get("readyMe", false):
		return
	var free := _i(_me(v).get("stack", 0)) + sum(v.get("myBets")) - sum(rl.bets)
	if free < 1:
		msg_l.text = "Not enough shards at the table: top up (+5 or +25)"
		return
	rl.bets[k] = _i(rl.bets.get(k, 0)) + mini(rl.chip, free)
	_play("cas_chip")
	rl_queue()


func rl_queue() -> void:
	rl.dirty = true
	rl.at = _now()
	rl.send_at = _now() + 260
	_redraw_all()


func rl_flush() -> void:
	if tables.id == 0 or not rl.dirty:
		return
	var want: Dictionary = rl.bets.duplicate()
	rl.dirty = false
	rl.inflight = true
	var r := await tables.send({"op": "rlbets", "id": tables.id, "bets": want}, true)
	rl.inflight = false
	rl.at = _now()
	if r.get("error"):
		msg_l.text = str(r.error)
		rl.sent = ""
		if not tables.v.is_empty():
			rl.at = 0.0
			rl_sync(tables.v)
	else:
		rl.sent = _js(want)
		rl.sentBets = want
	_redraw_all()


## bets wait 260 ms after the last tap, then go as one (roulette and baccarat)
func _flushers() -> void:
	if rl.dirty and rl.send_at > 0 and _now() >= rl.send_at and not rl.inflight:
		rl.send_at = 0.0
		rl_flush()
	if ba.dirty and ba.send_at > 0 and _now() >= ba.send_at and not ba.inflight:
		ba.send_at = 0.0
		ba_flush()


# ---------------------------------------------------------------- baccarat bets

func ba_sync(v: Dictionary) -> void:
	var hn := _i(v.get("handNo", 0))
	if hn != ba.hand and v.get("phase") == "bet":
		if ba.hand >= 0 and sum(ba.bets):
			ba.last = ba.bets.duplicate()
		ba.hand = hn
		ba.bets = {}
		ba.sent = ""
	if v.get("phase") != "bet":
		ba.bets = _ibets(v.get("myBets"))
		return
	if not ba.dirty and not ba.inflight and _now() - ba.at > 2000:
		ba.bets = _ibets(v.get("myBets"))


func ba_spot(k: String) -> void:
	var v := tables.v
	if v.is_empty() or v.get("game") != "ba" or v.get("phase") != "bet" or v.get("readyMe", false):
		return
	var free := _i(_me(v).get("stack", 0)) + sum(v.get("myBets")) - sum(ba.bets)
	var add: int = ba.chip
	if k == "B":
		add = maxi(20, ceili(add / 20.0) * 20)
	if add > free:
		msg_l.text = "Banker bets go in 20s: top up for 20" if k == "B" and free >= 1 else "Not enough shards at the table: top up"
		return
	ba.bets[k] = _i(ba.bets.get(k, 0)) + add
	_play("cas_chip")
	ba_queue()


func ba_queue() -> void:
	ba.dirty = true
	ba.at = _now()
	ba.send_at = _now() + 260
	_redraw_all()


func ba_flush() -> void:
	if tables.id == 0 or not ba.dirty:
		return
	ba.dirty = false
	ba.inflight = true
	var want: Dictionary = ba.bets.duplicate()
	var r := await tables.send({"op": "babets", "id": tables.id, "bets": want}, true)
	ba.inflight = false
	ba.at = _now()
	if r.get("error"):
		msg_l.text = str(r.error)
		if not tables.v.is_empty():
			ba.bets = _ibets(tables.v.get("myBets"))
	_redraw_all()


# ---------------------------------------------------------------- craps bets

## the smallest step a craps bet moves by, so its payout is whole shards (crDen)
static func cr_den(k: String, point: int) -> int:
	if ["p5", "p9", "p4", "p10"].has(k):
		return 5
	if k == "p6" or k == "p8":
		return 6
	if k == "po":
		return CR_ODDS_D.get(point, 1)
	if k == "dpo":
		return CR_LAY_D.get(point, 1)
	var re := RegEx.create_from_string("^([cd])(\\d+)o$")
	var mm := re.search(k)
	if mm != null:
		return (CR_ODDS_D if mm.get_string(1) == "c" else CR_LAY_D).get(int(mm.get_string(2)), 1)
	return 1


## a tap on a craps bet: a chip more (in its step, up to its odds limit), or off when taking down
func cr_spot(k: String) -> void:
	var v := tables.v
	if v.is_empty() or v.get("phase") != "bet":
		return
	var B: Dictionary = _ibets(v.get("myBets"))
	var cur := _i(B.get(k, 0))
	var P := _i(v.get("point", 0))
	var dn := cr_den(k, P)
	var a: int
	if cr.down:
		a = 0
	else:
		a = cur + maxi(dn, ceili(float(cr.chip) / dn) * dn)
		if k == "po":
			a = mini(a, CR_MULT_C.get(P, 0) * _i(B.get("pass", 0)))
		if k == "dpo":
			a = mini(a, 6 * _i(B.get("dp", 0)))
		var re := RegEx.create_from_string("^([cd])(\\d+)o$")
		var mm := re.search(k)
		if mm != null:
			a = mini(a, (CR_MULT_C.get(int(mm.get_string(2)), 0) if mm.get_string(1) == "c" else 6) * _i(B.get(mm.get_string(1) + mm.get_string(2), 0)))
		a -= a % dn
		if a <= cur:
			msg_l.text = "That bet is at its limit"
			return
	_play("cas_chip")
	_cr_send({"op": "crbet", "id": tables.id, "k": k, "amt": a})


## craps moves go one at a time, in the order you made them
func _cr_send(body: Dictionary) -> void:
	_cr_q.append(body)
	if _cr_running:
		return
	_cr_running = true
	while not _cr_q.is_empty():
		var b: Dictionary = _cr_q.pop_front()
		var r := await tables.send(b, true)
		if r.get("error"):
			msg_l.text = str(r.error)
	_cr_running = false


# ---------------------------------------------------------------- the fair play text, history, rules, prizes

func _fair_text(v: Dictionary) -> String:
	var o := PackedStringArray()
	var what := "spin" if v.game == "rl" else "hand"
	if v.get("next"):
		o.append("The server's seed for the next %s is locked in. Its fingerprint (SHA-256): %s" % [what, v.next])
	if v.get("fair") and v.fair != v.get("next"):
		o.append("This %s's fingerprint: %s" % [what, v.fair])
	o.append("Your seed %s is mixed into every %s from the next one on. Change it whenever you like." % [v.get("seed", ""), "spin" if v.game == "rl" else "deal"])
	var L = v.get("last")
	if L is Dictionary and L.get("result") is Dictionary and L.result.get("seeds") is Array:
		o.append("Last %s #%s: %splayers' seeds %s." % [what, PalTables.js(L.get("no")), "seed " + str(L.seed) + ", " if L.get("seed") else "", ", ".join(PackedStringArray(L.result.seeds))])
	return "\n\n".join(o)


func _modal(title: String) -> VBoxContainer:
	_close_modal()
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e): if e is InputEventMouseButton and e.pressed: _close_modal())
	modal.add_child(dim)
	var W := float(m.v.W) if m != null else 1280.0
	var H := float(m.v.H) if m != null else 720.0
	var pc := _panel(Color("#14110d"), Color("#6a4a20"), 1, 12)
	var w := minf(620, W - 24)
	pc.position = Vector2((W - w) / 2, maxf(12, H * 0.06))
	pc.size = Vector2(w, H * 0.88)
	modal.add_child(pc)
	var vb := _vbox(8)
	pc.add_child(vb)
	var head := HBoxContainer.new()
	var tl := _lbl(title, 22, GOLD, false, true)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tl)
	var cb := Button.new()
	cb.text = "CLOSE"
	cb.set_meta("fid", "close")
	cb.pressed.connect(_close_modal)
	head.add_child(cb)
	vb.add_child(head)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.follow_focus = true
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)
	var c := _vbox(8)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(c)
	modal_kind = title
	return c


func _modal_focus() -> void:
	await get_tree().process_frame
	if modal != null and is_instance_valid(modal):
		var f := _first_button(modal)
		if f != null:
			f.grab_focus()


func _close_modal() -> void:
	if modal != null and is_instance_valid(modal):
		modal.queue_free()
	modal = null
	modal_kind = ""
	if _open and sheet != null and sheet.visible:
		var f := _first_button(acts)
		if f == null:
			f = hide_b
		f.grab_focus.call_deferred()


func modal_open() -> bool:
	return modal != null and is_instance_valid(modal)


func _rules() -> void:
	var c := _modal("HOUSE RULES")
	var t := RichTextLabel.new()
	t.bbcode_enabled = true
	t.fit_content = true
	t.scroll_active = false
	t.text = RULES
	t.add_theme_constant_override("paragraph_separation", 6)
	t.add_theme_color_override("default_color", TEXT2)
	c.add_child(t)
	_modal_focus()


## HAND HISTORY: your last rounds; CHECK reruns the shuffle or the spin here, from what the server revealed
func show_history() -> void:
	var c := _modal("HAND HISTORY")
	var wait := _lbl("Loading…", 12, DIM)
	c.add_child(wait)
	_modal_focus()
	var r := await tables.history()
	if not is_instance_valid(c):
		return
	wait.queue_free()
	if r.get("error"):
		c.add_child(_lbl(str(r.error), 12, DIM, true))
		return
	if tables.hist.is_empty():
		c.add_child(_lbl("No hands yet. Sit down at a table in the casino.", 12, DIM, true))
		return
	c.add_child(_lbl("Your last %d hands and spins. CHECK reruns the shuffle or the spin here, from what the server revealed." % tables.hist.size(), 12, DIM, true))
	for i in tables.hist.size():
		c.add_child(_hist_item(tables.hist[i], i))


func _hist_item(h: Dictionary, i: int) -> Control:
	var r: Dictionary = h.result if h.get("result") is Dictionary else {}
	var me = mine_of(r)
	var net = null
	if me != null:
		net = _i(me.net) if me.get("net") != null else _i(me.get("won", 0)) - _i(me.get("put", me.get("bet", 0)))
	var pc := _panel(Color(0, 0, 0, 0.25), LINE, 1, 8)
	var b := _vbox(4)
	pc.add_child(b)
	var hr := HBoxContainer.new()
	hr.add_theme_constant_override("separation", 8)
	hr.add_child(_lbl(PalTables.NAME.get(h.get("game"), "") + (" SHOE #" + PalTables.js(r.shoeEnd) if r.get("shoeEnd") else " #" + PalTables.js(h.get("no"))), 14, PAPER, false, true))
	var dl := _lbl(_date(str(h.get("at", ""))), 11, DIM)
	dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hr.add_child(dl)
	if net != null:
		hr.add_child(_lbl(("+" if net > 0 else "") + "%d◆" % net, 13, WINC if net > 0 else (LOSSC if net < 0 else PAPER), false, true))
	b.add_child(hr)
	var what := HFlowContainer.new()
	what.add_theme_constant_override("h_separation", 4)
	match str(h.get("game")):
		"rl":
			what.add_child(_lbl(rl_name(_i(r.get("number"))), 12, PAPER))
		"bj":
			what.add_child(_lbl("Dealer " + (str(_i(r.total)) if r.get("total") != null else "?"), 12, PAPER))
		"ba":
			what.add_child(_lbl("Shoe #%s finished (%s cards dealt)" % [PalTables.js(r.shoeEnd), PalTables.js(r.get("dealt"))] if r.get("shoeEnd") else "Player %d · Banker %d" % [_i(r.get("pt")), _i(r.get("bt"))], 12, PAPER))
		"cr":
			what.add_child(_lbl("%s = %d" % [" + ".join(PackedStringArray((r.get("dice", []) as Array).map(func(x): return str(_i(x))))), _i(r.get("total"))], 12, PAPER))
		"sl":
			what.add_child(_lbl(" ".join(PackedStringArray((r.get("line", []) as Array).map(func(x): return CG_SYM.get(x, "—") if CG_SYM.get(x, "") != "" else "—"))), 12, PAPER))
		"pk":
			what.add_child(_lbl("pocket %d · %sx" % [_i(r.get("pocket")) + 1, PalTables.js(r.get("mult"))], 12, PAPER))
		_:
			if r.get("board") is Array:
				what.add_child(_cards(r.board, true))
	if h.get("mine") is Array:
		what.add_child(_lbl(" · your cards", 12, PAPER))
		what.add_child(_cards(h.mine, true))
	b.add_child(what)
	var out := _lbl("", 12, PAPER, true)
	var cb := Button.new()
	cb.text = "CHECK"
	cb.set_meta("fid", "check:%d" % i)
	cb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	cb.pressed.connect(func():
		out.text = "Checking…"
		out.add_theme_color_override("font_color", PAPER)
		var res: Array = await tables.verify(h)
		if not is_instance_valid(out):
			return
		out.add_theme_color_override("font_color", WINC if res[0] == true else (LOSSC if res[0] == false else PAPER))
		out.text = ("✓ FAIR. " if res[0] == true else ("✗ " if res[0] == false else "")) + str(res[1]))
	b.add_child(cb)
	b.add_child(out)
	return pc


func _date(iso: String) -> String:
	if iso == "":
		return ""
	var t := Time.get_unix_time_from_datetime_string(iso.substr(0, 19))
	return Time.get_datetime_string_from_unix_time(t + _tz(), true)


## a side bet hit: pick the prize (10 Hybrid Theory Cases or 15 Flag Cases)
func _pick_modal(v: Dictionary) -> void:
	var c := _modal("SIDE BET HIT!")
	var why := ""
	var L = v.get("last")
	if L is Dictionary and L.get("sideHits") is Array:
		for x in L.sideHits:
			if x is Dictionary:
				why = str(x.get("why", "")) + "! "
				break
	c.add_child(_lbl(why + "Pick your prize.", 15, PAPER, true))
	for p in [["hybrid", "10 HYBRID THEORY CASES"], ["flags", "15 FLAG CASES"]]:
		var kind: String = p[0]
		var b := _btn(p[1], "pick:" + kind, {"cl": "go"})
		b.pressed.connect(func():
			_close_modal()
			await tables.send({"op": "pick", "id": tables.id, "kind": kind})
			if sync_locker and m != null and m.account != null:
				m.account.sync_locker())
		c.add_child(b)
	modal_kind = "pick"
	_modal_focus()


func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("ui_cancel"):
		if modal_open():
			_close_modal()
			get_viewport().set_input_as_handled()
		elif _open:
			var f := get_viewport().gui_get_focus_owner()
			if f != null and sheet.is_ancestor_of(f):   # Esc / B with the sheet in hand: HIDE
				close()
				get_viewport().set_input_as_handled()


# ---------------------------------------------------------------- drawn pieces: chips, the roulette board, dice, reels, Plinko

static func chip_col(a: int) -> Color:
	return Color("#d6aa46") if a >= 1000 else (Color("#8a4ad0") if a >= 500 else (Color("#141214") if a >= 100 else (Color("#1f8a4a") if a >= 25 else (Color("#c02030") if a >= 5 else Color("#e8e4dc")))))


static func chip_text(a: int) -> String:
	if a >= 1000:
		return ("%.1fK" % (a / 1000.0)) if a % 1000 else "%dK" % (a / 1000)
	return str(a)


static func draw_chip(ci: CanvasItem, at: Vector2, a: int, r: float, other: bool) -> void:
	var c := chip_col(a)
	ci.draw_circle(at + Vector2(0, 1), r, Color(0, 0, 0, 0.5))
	ci.draw_circle(at, r, Color(c, 0.7 if other else 1.0))
	ci.draw_arc(at, r - 1.5, 0, TAU, 24, Color(1, 1, 1, 0.5 if other else 0.75), 1.5)
	var f := ThemeDB.fallback_font
	var fs := maxi(8, int(r * 0.85))
	var t := chip_text(a)
	var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var ink := Color("#17140f") if a < 5 else Color.WHITE
	ci.draw_string(f, at + Vector2(-w / 2, fs * 0.35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)


class Chip extends Control:
	var amt := 0
	var other := false
	var anchor_at := Vector2(1, 0.5)
	var radius := 10.0

	func _init(a: int, o: bool, at: Vector2) -> void:
		amt = a
		other = o
		anchor_at = at
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var r := radius * (0.8 if other else 1.0)
		var p := Vector2(clampf(size.x * anchor_at.x, r + 2, size.x - r - 2), clampf(size.y * anchor_at.y, r + 2, size.y - r - 2))
		CasinoUI.draw_chip(self, p, amt, r, other)


## the roulette numbers: 0 and 00 on the left, 12 columns of three (3 on top). Tap anywhere on it (a number, a line, a
## corner, the bottom edge for a street or six line); a controller moves a cursor over the same spots.
class RlBoard extends Control:
	var ui
	var open := true
	var mine := {}
	var others := {}
	var hit := -1
	var hint: Label = null
	var cx := 13
	var cy := 0
	var xs: Array = [-0.5]
	const YS := [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]

	func _init(u) -> void:
		ui = u
		focus_mode = Control.FOCUS_ALL
		mouse_filter = Control.MOUSE_FILTER_STOP
		for i in 24:
			xs.append(i * 0.5)
		focus_entered.connect(_say)
		focus_exited.connect(func():
			if hint != null and is_instance_valid(hint):
				hint.text = ""
			queue_redraw())

	func _px(p: Vector2) -> Vector2:
		return Vector2((p.x + 1) / 13.0 * size.x, p.y / 3.0 * size.y)

	func _draw() -> void:
		var W := size.x
		var H := size.y
		var cw := W / 13.0
		var rh := H / 3.0
		draw_rect(Rect2(0, 0, W, H), Color(240 / 255.0, 230 / 255.0, 200 / 255.0, 0.5))
		var f := ThemeDB.fallback_font
		var fs := clampi(int(cw * 0.42), 11, 16)
		for row in 3:
			for c in 12:
				var n: int = c * 3 + (3 - row)
				var r := Rect2((c + 1) * cw + 0.5, row * rh + 0.5, cw - 1, rh - 1)
				draw_rect(r, Color("#9a1a24") if CasinoUI.RL_RED.has(n) else Color("#121012"))
				if n == hit:
					draw_rect(r.grow(-1.5), Color("#ffd88a"), false, 3)
				_text(f, str(n), r.get_center(), fs)
		for z in [[37, Rect2(0.5, 0.5, cw - 1, H / 2 - 1)], [0, Rect2(0.5, H / 2 + 0.5, cw - 1, H / 2 - 1)]]:
			draw_rect(z[1], Color("#0b6a32"))
			if z[0] == hit:
				draw_rect((z[1] as Rect2).grow(-1.5), Color("#ffd88a"), false, 3)
			_text(f, "00" if z[0] == 37 else "0", (z[1] as Rect2).get_center(), fs)
		for k in others:
			var p = CasinoUI.rl_pos(k)
			if p != null:
				CasinoUI.draw_chip(self, _px(p), int(others[k]), 8, true)
		for k in mine:
			var p = CasinoUI.rl_pos(k)
			if p != null:
				CasinoUI.draw_chip(self, _px(p), int(mine[k]), 10, false)
		if not open:
			draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.2))
		if has_focus() and open:
			var c := _px(Vector2(xs[cx], YS[cy]))
			draw_arc(c, 9, 0, TAU, 20, Color("#ffd88a"), 2.5)
			draw_arc(c, 12, 0, TAU, 20, Color(0, 0, 0, 0.6), 1.5)
		elif has_focus():
			draw_rect(Rect2(0, 0, W, H), Color("#e8dcc0"), false, 2)

	func _text(f: Font, t: String, c: Vector2, fs: int) -> void:
		var w := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, c + Vector2(-w / 2, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)

	func _say() -> void:
		if hint != null and is_instance_valid(hint):
			var k := CasinoUI.rl_spot_at(xs[cx], YS[cy])
			hint.text = "ON THE BOARD: " + CasinoUI.rl_spot_name(k) + " · A / Enter puts a chip on it" if open else ""
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			if open:
				ui.rl_tap(e.position.x / size.x * 13 - 1, e.position.y / size.y * 3)
			accept_event()
			return
		if not open:
			return
		var moved := false
		if e.is_action_pressed("ui_left") and cx > 0:
			cx -= 1
			moved = true
		elif e.is_action_pressed("ui_right") and cx < xs.size() - 1:
			cx += 1
			moved = true
		elif e.is_action_pressed("ui_up") and cy > 0:
			cy -= 1
			moved = true
		elif e.is_action_pressed("ui_down") and cy < YS.size() - 1:
			cy += 1
			moved = true
		elif e.is_action_pressed("ui_accept"):
			ui.rl_tap(xs[cx], YS[cy])
			accept_event()
			return
		if moved:   # at an edge the move isn't taken, so focus goes on to the next control
			_say()
			accept_event()


## two dice: tumbling while the roll's reveal runs, then the server's dice (cgDiceNow); fixed: a receipt's dice
class DiceView extends Control:
	var ui
	var s := 30.0
	var fixed: Array = []
	const PIPS := {1: [[.5, .5]], 2: [[.25, .25], [.75, .75]], 3: [[.25, .25], [.5, .5], [.75, .75]], 4: [[.25, .25], [.75, .25], [.25, .75], [.75, .75]],
		5: [[.25, .25], [.75, .25], [.5, .5], [.25, .75], [.75, .75]], 6: [[.25, .2], [.75, .2], [.25, .5], [.75, .5], [.25, .8], [.75, .8]]}

	func _init(u, sz: float) -> void:
		ui = u
		s = sz
		custom_minimum_size = Vector2(sz * 2 + 6, sz + 3)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_dt: float) -> void:
		if fixed.is_empty():
			queue_redraw()

	func _draw() -> void:
		var d: Array = fixed
		if d.is_empty():
			d = ui.dice_now(ui.tables.v, true)
		if d.is_empty():
			draw_string(ThemeDB.fallback_font, Vector2(0, s * 0.6), "no roll yet", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, CasinoUI.DIM)
			return
		for q in d.size():
			var o := Vector2(q * (s + 6), 0)
			draw_rect(Rect2(o + Vector2(0, 2), Vector2(s, s)), Color("#b8b0a0"))
			draw_rect(Rect2(o, Vector2(s, s)), Color("#f4f0e6"))
			for p in PIPS.get(int(d[q]), []):
				draw_circle(o + Vector2(p[0], p[1]) * s, s * 0.1, Color("#b8202c"))


## the dice on show: tumbling (a new face every 90 ms) while the reveal runs, then the server's (cgDiceNow)
func dice_now(v: Dictionary, sound: bool = false) -> Array:
	if v.is_empty() or not (v.get("dice") is Array):
		return []
	if left(v) > 0:
		if sound and v == tables.v:
			stage_sfx(v, 1, "cas_dice")
		var t := int(_now() / 90.0)
		return [1 + t % 6, 1 + (t * 7 + 3) % 6]
	return v.dice.map(func(x): return int(x))


## the three reels: turning until each one's stop, the payline lit when they've all stopped
class Reels extends Control:
	var ui
	var fixed: Array = []
	var small := false

	func _init(u) -> void:
		ui = u
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ready() -> void:
		custom_minimum_size = Vector2(0, (26 * 3 + 20) if small else (40 * 3 + 20))
		if small:
			custom_minimum_size.x = 240

	func _process(_dt: float) -> void:
		if fixed.is_empty():
			queue_redraw()

	func _draw() -> void:
		var win: Array = fixed
		var stopped := 3
		var v: Dictionary = ui.tables.v
		if win.is_empty():
			var w: Dictionary = ui.slot_window(v, true)
			win = w.win
			stopped = w.stopped
		var W := minf(size.x, 240.0) if small else size.x
		draw_rect(Rect2(0, 0, W, size.y), Color("#0a0a10"))
		var gap := 6.0
		var cw := (W - 12 - gap * 2) / 3.0
		var ch := (size.y - 12 - 8) / 3.0
		var f := ThemeDB.fallback_font
		var won: bool = stopped == 3 and fixed.is_empty() and v.get("phase") == "done" and CasinoUI.left(v) <= 0 and CasinoUI._i(CasinoUI._last_res(v).get("mult", 0)) > 0
		for i in 3:
			for r in 3:
				var rect := Rect2(6 + i * (cw + gap), 6 + r * (ch + 4), cw, ch)
				draw_rect(rect, Color("#17161c"))
				var sym: String = str(win[i][r]) if i < win.size() else "X"
				var t: String = CasinoUI.CG_SYM.get(sym, "")
				var fs := (22 if sym == "S" else 16) if not small else (16 if sym == "S" else 12)
				var col := Color(CasinoUI.CG_SYM_COL.get(sym, "#f3ecdc"))
				if i >= stopped:
					col.a = 0.6
				var tw := f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				draw_string(f, rect.get_center() + Vector2(-tw / 2, fs * 0.36), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
				if r == 1 and stopped == 3:
					draw_rect(rect.grow(-1), Color("#ffd24a"), false, 2)
		if won:
			draw_rect(Rect2(0, 0, W, size.y), Color("#ffd24a"), false, 3)


## the Plinko board: twelve rows of pegs; the ball falls along the server's exact path, drawn from the latest view
class Plinko extends Control:
	var ui

	func _init(u) -> void:
		ui = u
		custom_minimum_size = Vector2(0, 300)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(_dt: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var W := minf(size.x, 360.0)
		var H := size.y
		var ox := (size.x - W) / 2
		draw_rect(Rect2(ox, 0, W, H), Color("#121018"))
		draw_rect(Rect2(ox, 0, W, H), Color("#d6aa46"), false, 2)
		var rows := 12
		var top := 24.0
		var dy := (H - 70) / rows
		var px := func(r: float, k: float) -> float: return ox + W / 2 + (k - r / 2) * (W * .84 / 12)
		var py := func(r: float) -> float: return top + r * dy
		for r in rows + 1:
			for k in r + 1:
				draw_circle(Vector2(px.call(r, k), py.call(r)), 2.4, Color("#e8e0cf"))
		var v: Dictionary = ui.tables.v
		if v.get("game") != "pk":
			return
		var r0 := CasinoUI._last_res(v)
		if r0.is_empty() or not (r0.get("path") is Array):
			return
		var path: Array = r0.path
		var lf := CasinoUI.left(v)
		var fr_all: float = (rows if lf <= 0 else (3100 - lf) / 3100.0 * rows) if v.get("phase") == "done" else rows
		var rr := mini(rows, floori(fr_all))
		var fr := fr_all - rr
		var col := 0
		for i in rr:
			col += int(path[i])
		var nx := col + (int(path[rr]) if rr < path.size() else 0)
		if v == ui.tables.v:
			ui.stage_sfx(v, rr, "cas_peg")
		var bx: float
		var by: float
		if rr >= rows:
			bx = px.call(rows, col)
			by = py.call(rows) + 10
		else:
			bx = px.call(rr, col) + (px.call(rr + 1, nx) - px.call(rr, col)) * fr
			by = py.call(rr) + (py.call(rr + 1) - py.call(rr)) * fr - dy * .35 * sin(fr * PI)
		draw_circle(Vector2(bx, by - 6), 6, Color("#ffd24a"))
