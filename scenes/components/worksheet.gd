class_name UIWorksheet
extends Control

## The workspace: a panel of graph paper on the clipboard, worked in pencil.
##
## Was a whiteboard, and that was the wrong object. **A whiteboard does not get
## clipped to a clipboard** -- the two are alternatives, not a stack, and the
## picture was of one lying on the other. What a coach actually clips down and
## carries is a sheet of squared paper with the court worked out on it in pencil,
## which is also why the squares are useful: the grid is a coordinate system you
## can count along, so "half a square further off the net" is a thing you can
## say and mean.
##
## Pencil rather than marker, and they behave differently in ways that matter
## more than colour:
##
## 1. **Graphite is not opaque and not uniform.** A pencil line is dense where
##    the tooth of the paper caught it and pale where it skipped, so a stroke is
##    broken along its length rather than solid. That break is the whole tell.
## 2. **The side of the tip is a different instrument from the point.** A point
##    draws a line; laid over, the same pencil shades a broad soft band with a
##    hard edge on one side and a feathered one on the other. Fills are shaded
##    that way here rather than hatched, because that is what a hand does when it
##    wants an area rather than a line.
## 3. **It can be erased, not wiped.** Changing the phase or the view lifts the
##    old working with an eraser and leaves the smudge a real eraser leaves, and
##    the grid *survives underneath* -- because the grid is printed and the
##    working is not, which is the same print-versus-hand split the whole
##    clipboard runs on.
##
## Deterministic and seeded, for the same reason the pen and the marker are: a
## wobble redrawn differently every frame is a shimmer, and a wobble shared by
## every stroke is a texture rather than a hand.

const UIPalette := preload("res://scripts/data/ui_palette.gd")
const VoliStickerScript := preload("res://scenes/components/voli_sticker.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const SpikeBiomechanics := preload("res://scripts/data/spike_biomechanics.gd")

## The sticker border, and the shadow that proves it has thickness.
##
## Constant weight is the point. Every other line on this sheet varies with the
## hand -- the tooth, the pressure drift, the wander -- and this one does not,
## because a die cut does not. That single difference is what separates a sticker
## lying *on* the paper from a drawing worked *into* it, and it is why the bodies
## can be bold while the court behind them stays quiet.
## The court, in the units it is actually built in.
##
## Every view drew its own geometry from shares of the panel, so the net was
## whatever fraction of the height that view's author picked -- 0.66 of the panel
## in the along-net view against roughly a third in three quarter, for the same
## 2.43 m of net. Two drawings of one object that disagree about its size are two
## objects.
##
## One scale per view instead, in pixels per metre, fitted to whatever the panel
## has. Then a net is 2.43 m in both because it is 2.43 m, and the check is
## arithmetic rather than eyesight.
## Where each view stands, as a pair of angles.
##
## `theta` swings around the court and `phi` tilts above it -- 0 is standing on
## the floor, 90 is directly overhead. One pair per view drives *both* the
## drawing and the bake camera, so a body can no longer be seen from a different
## angle than the court it is standing on. They disagreed before: three quarter
## drew a shallow oblique and baked its volis at 14 degrees of yaw, which is not
## three quarters of anything.
## One camera, orbiting. Three quarter stands 38 degrees round from square-on and
## 30 above the floor; the along-net view swings to 80 and drops to 12; the plan
## view carries on to 90 and 90. Reading them in that order is the orbit, and
## keeping them in one direction is why the near court stays on the left in all
## three -- a view that flips which end is yours is a view a coach has to
## re-learn every time they toggle.
##
## Twelve degrees of tilt in the along-net view rather than nothing at all. At a
## true zero the two ends of the net sit on one line and the far half of the court
## does not exist, which is geometrically honest and useless: the reason to sight
## down the tape is to measure distances *from* it, and a viewer with no far side
## has nothing to measure them against.
const VIEW_ANGLES := {
	VIEW_TOP_DOWN: Vector2(90.0, 90.0),
	VIEW_THREE_QUARTER: Vector2(38.0, 26.0),
	VIEW_ALONG_NET: Vector2(76.0, 14.0),
}

## And how much of the world each view has to hold, as a box in metres.
##
## This is the other half of the same fix. Angles alone do not fix a scale: the
## drawing still has to decide what is in frame, and every view used to decide
## that separately in shares of the panel. Given a box, the fit is arithmetic --
## project its eight corners, take the extent, divide -- and a metre means the
## same thing everywhere within a view because there is only one number.
##
## The boxes differ because the views are for different questions, not because
## somebody liked a framing. Top down holds the **whole court**, both halves,
## because a plan view that stops at the net cannot show a rally. Three quarter
## keeps the near court and six metres past the net, which is as far as an
## attack's consequences reach. Along the net crops depth hardest, because it is
## a ruler for distances *from* the tape and everything it measures is inside
## seven metres.
const VIEW_BOX := {
	VIEW_TOP_DOWN: [Vector3(-5.1, -9.8, 0.0), Vector3(5.1, 9.8, 0.0)],
	VIEW_THREE_QUARTER: [Vector3(-5.4, -5.0, 0.0), Vector3(5.4, 8.6, 3.3)],
	VIEW_ALONG_NET: [Vector3(-4.9, -3.2, 0.0), Vector3(4.9, 7.2, 3.3)],
}

## And how much *depth* each phase needs of it.
##
## The second axis of the frame, and it exists because the first pass got a real
## trade wrong. Framing the whole eighteen-metre court in every view made every
## metre honest and made the drawing small: a pair of blockers that had filled a
## third of the sheet came out about sixty pixels tall, because the page was
## paying for sixteen metres of floor that the block page has no opinion about.
##
## The fix is not to go back to a net sized off the panel -- that is what made one
## net two different heights. It is to notice that **how much court is in frame is
## a property of what you are planning**, exactly like which adjustments are
## available. Blocking is about the wall and the seam in it, so it holds the net
## and the ground either side of it. Attack has to reach the far endline because
## that is where the ball is going. Floor is your court, plus enough of theirs for
## the swing to come from somewhere.
##
## One scale per view survives untouched. What changes is what is inside the box,
## which is a framing decision, not a measurement.
##
## Cropped tighter than the court's own extent on every page, not just the block
## one. A page that holds eighteen metres so the far endline is present spends its
## whole vertical budget on floor nobody is looking at; a page that holds twelve
## puts the drawing back at a size where the bodies read. What falls outside is
## still *there* -- the marks clamp into frame and the court lines stop at the
## crop rather than pretending the court ends -- it is simply not on this page.
const PHASE_DEPTH := {
	"Attack": Vector2(-7.6, 4.4),
	"Block": Vector2(-1.4, 3.0),
	"Floor": Vector2(-3.0, 7.6),
}

const NET_HEIGHT_M: float = 2.43
const COURT_HALF_M: float = 9.0
const COURT_WIDTH_M: float = 9.0
const HALF_WIDTH_M: float = 4.5
const ATTACK_LINE_M: float = 3.0
## Headroom above the tape for a blocker's hands, and a margin so nothing touches
## the edge of the sheet.
const HEADROOM_M: float = 1.25
const MARGIN_SHARE: float = 0.07
## The band across the top the heading lives in, and the strip along the foot the
## "nothing to set from here" line needs. Taken out of the fit rather than drawn
## over, because a court that runs under its own title is a court nobody sized.
##
## Cut from 0.17 and 0.09 when the drawing turned out to be short of presence.
## The sheet is wide and not tall -- 932 by 421 at the size the clipboard gives it
## -- so the fit is height-bound in every view, and a quarter of the height going
## to two lines of text was the cheapest thing on the page to take back.
const HEAD_SHARE: float = 0.125
const FOOT_SHARE: float = 0.055
## Where the net sits down the usable band. A shade above the middle, because
## every view has more court in front of the net than behind it once the far half
## is cropped, and the drawing balances when the busy half has the room.
const NET_ANCHOR: float = 0.46

## Constant *for a given sticker*, not constant in pixels.
##
## It was a flat 3.4 px, tuned against a blocker who filled a third of the sheet.
## Once a voli was sized off the metres they actually occupy, a plan-view figure
## came out about thirty pixels tall and a 3.4 px cut on each side met in the
## middle -- the body vanished under its own edge and every sticker read as a
## white blob. The render underneath was innocent: measured, its luminance runs
## 0.00 to 0.80 with a median of 0.28, so the posterise was spreading across all
## three tones exactly as intended and none of it was visible.
##
## A share of the sticker's height with a floor and a ceiling. A die cut does not
## vary with what is printed on it, but it also does not scale with a drawing --
## and what is being kept here is the *look* of a cut edge, which is a proportion.
## Whether the sheet draws its own edge round a sticker.
##
## A `static var` so the two candidates can be rendered against each other. The
## die cut was invented when the rig had no line of its own; it does now, and
## drawing both means two edges at slightly different offsets.
static var draw_die_cut: bool = true

const STICKER_BORDER_SHARE: float = 0.022
const STICKER_BORDER_MIN: float = 0.9
const STICKER_BORDER_MAX: float = 3.4
const STICKER_SHADOW_OFFSET := Vector2(3.0, 4.0)
const STICKER_SHADOW_ALPHA: float = 0.26

## The stock the sticker was cut from, and the line that gives that stock an edge.
##
## The cut margin was drawn in `_ink()`, which flips with the theme -- pale on
## Mikasa, graphite on Molten. That is why it read as a die cut on the dark sheet
## and as a heavy outline on the light one: the same border was doing two
## different jobs. **A sticker's margin is the vinyl it was cut from, and vinyl
## does not change colour when you put it on a darker page.** So the stock is one
## warm off-white in both themes, and it keeps the shape reading as an object
## lying on the sheet rather than a shape drawn into it.
##
## Which leaves a white margin on a cream page invisible, hence the keyline: a
## thin dark line around the outside of the cut, thinner than the cut it edges.
## It is what a printed sticker actually has -- the art is trimmed a little
## outside the printed keyline -- and it is what lets the same treatment work on
## both grounds, where a single colour cannot.
const STICKER_STOCK := Color(0.95, 0.94, 0.91)
const STICKER_KEYLINE := Color(0.15, 0.14, 0.16)
## Per side, as a share of the cut's own width. Under a half, so the line reads
## as an edge on the margin rather than as a second border beside it.
const STICKER_KEYLINE_SHARE: float = 0.38

signal phase_changed(phase: String)
signal view_changed(view: String)
signal zone_priority_changed(zone_index: int, priority: int)

## The phases a coach explains one at a time, in the order a rally travels them.
##
## Three, not four. Serve receive was its own page and should not have been: it
## is floor work -- the same six volis in the same plan view deciding where to
## stand -- and it had exactly one cell in the view matrix, which was the tell.
## Serving is the same argument pointed the other way: where you aim a serve is
## an attacking decision, not a phase of its own.
##
## Both survive as **overlays** on the phase that owns them, which is what they
## always were. That also empties two thirds of the matrix's holes, so the
## greying and the auto-switch have less to do.
const PHASES: Array[String] = ["Attack", "Block", "Floor"]

## The overlay each phase can carry. Nothing draws these yet -- the serve marks
## went with the rest of the annotation layer -- but the pairing is a design fact
## worth keeping written down: serve targeting belongs to the attack page and
## serve receive to the floor page, which is why neither is a phase of its own.
const OVERLAYS := {
	"Attack": "Serve target",
	"Floor": "Serve receive",
}

## And the ways of looking at the court. These are a **second, independent axis**
## rather than four more phases: what you can adjust is the intersection of what
## you are planning and where you are standing to look at it.
##
## Each view can only answer the questions its geometry actually contains, which
## is not a limitation to work around but the reason to have more than one:
##
## - **Top down** is a floor-shape view. Positions, lanes, funnels, coverage --
##   anything whose answer is an (x, y) on the court.
## - **Along the net** is an elevation, sighted down the tape. Heights and
##   distances *from* the net: set tightness, how far off the setter releases,
##   how tight a defender plays for the block follow.
## - **Three quarter** is neither, and that is its job. It is the only view where
##   depth and lateral position are both legible at once, so it is what you look
##   at to read a plan the other two authored rather than to author one.
const VIEW_TOP_DOWN: String = "Top down"
const VIEW_THREE_QUARTER: String = "Three quarter"
const VIEW_ALONG_NET: String = "Along the net"
const VIEWS: Array[String] = [VIEW_TOP_DOWN, VIEW_THREE_QUARTER, VIEW_ALONG_NET]

## Which phase can be adjusted from which view, and what the adjustment is.
##
## An empty cell is a **design gap, not a state to handle**. The greying and the
## auto-switch below exist because this table currently has holes in it; every
## hole filled is one fewer piece of interface behaviour that has to explain
## itself to the player. Written out rather than inferred so the holes are
## countable -- see `docs/design/TACTICS_AND_TRAINING.md` §0.10.
## **The holes are gone, and that was the point.** Six of nine cells were empty
## when this was written, and the greying and the auto-switch existed only to cope
## with them. The drill closed them: where a swing comes from and where it is
## aimed is a question every view can answer, because both ends of it are places
## on a court and all three views draw the court. What each view is *better* at is
## still true and is what the wording says.
##
## Kept written out rather than collapsed to a default, because the day a cell
## empties again -- a new phase, a view that cannot express something -- the table
## should say so rather than a fallback quietly covering it.
const ADJUSTMENTS := {
	VIEW_TOP_DOWN: {
		"Attack": "Where the swing lands, and which lane it takes",
		"Block": "Which way the block funnels",
		"Floor": "Where each defender stands",
	},
	VIEW_THREE_QUARTER: {
		"Attack": "The swing, read against the wall it has to beat",
		"Block": "Who takes the seam, and how wide the wall sits",
		"Floor": "The shot course to read, and who covers it",
	},
	VIEW_ALONG_NET: {
		"Attack": "Set tightness, the setter's release, and the shot off it",
		"Block": "How far off the tape the wall sets up",
		"Floor": "How tight the back row plays for the block follow",
	},
}

## The point. Narrow -- a pencil is a fraction of a marker's width, and most of
## why the board read as a board rather than as paper was that every line on it
## was seven pixels wide.
##
## `MARKER_ANGLE_DEGREES` survives as the angle the tip is worn to: a pencil
## sharpened and then used develops a flat, and a stroke along that flat is wider
## than one across it. Weaker than a chisel marker's ratio, because a worn point
## is only slightly directional.
const MARKER_WIDTH: float = 2.6
const MARKER_MIN_RATIO: float = 0.62
const MARKER_ANGLE_DEGREES: float = 31.0
## Graphite is never solid. Kept low so crossings still darken -- two pencil
## lines over each other genuinely are darker -- but low enough that a single
## line reads as grey rather than as ink.
const MARKER_ALPHA: float = 0.62
## How far a hand strays over a run, and how long each drawn segment is. Shorter
## segments than the marker had, because the tooth is sampled per segment.
const MARKER_WANDER: float = 1.05
const MARKER_SEGMENT: float = 6.0

## The tooth of the paper.
##
## A pencil skips. `TOOTH_SKIP` is how much of a stroke's density is modulated by
## the grain, and `TOOTH_PITCH` is how quickly that grain varies along the run --
## fast enough to break the line, slow enough that it is not noise.
const TOOTH_SKIP: float = 0.42
const TOOTH_PITCH: float = 0.9

## Shading with the side of the tip.
##
## `SHADE_WIDTH` is in pixels and not a share of whatever is being filled, which
## is the mistake the first pass made: scaled to the bar it produced 40px slabs,
## and the side of a pencil is about a centimetre wide no matter how big the box
## is. Passes overlap at roughly two-thirds of their width, which is what turns
## separate strokes into a tone.
const SHADE_WIDTH: float = 9.0
const SHADE_STEP: float = 6.0
const SHADE_ALPHA: float = 0.26

## What a wipe leaves behind. Low, and lower than it first read: at 0.085 with
## the alpha bug above in play the previous heading was still legible under the
## new one and the board said "BLOCK RECEIVE".
const GHOST_ALPHA: float = 0.055

## The red pencil. A coach's second instrument, and on paper it is a pencil
## rather than a pen -- the same tooth, the same erasability, so it belongs to
## the sheet in a way a ballpoint would not. Softer and browner than the marker
## red it replaces, which was mixed to sit on white plastic.
const MARKER_RED := Color(0.70, 0.28, 0.24)

## Graph paper.
##
## The squares are printed, so they follow the *form's* rules and not the
## pencil's: fixed pitch in screen pixels, dead straight, and a heavier line every
## fifth square the way squared paper actually comes. They survive an erase,
## because print does.
const GRAPH_PITCH: float = 13.0
const GRAPH_MAJOR_EVERY: int = 5
const GRAPH_ALPHA: float = 0.20
const GRAPH_MAJOR_ALPHA: float = 0.34
const GRAPH_INK_LIGHT := Color(0.42, 0.55, 0.62)
const GRAPH_INK_DARK := Color(0.46, 0.58, 0.68)

## The zone-priority bars. Four zones, each 0 to 3, scrolled to change.
const ZONE_COUNT: int = 4
const ZONE_MAX_PRIORITY: int = 3
const ZONE_LABELS: Array[String] = ["Line", "Seam", "Cross", "Tip"]

## The places along the net a swing comes from, named the way a coach names them.
##
## Four, and the fourth is not a pin. Zones 4, 3 and 2 are the front-row
## positions; the pipe is a back-row attack through the middle, which is a
## different distance from the tape rather than a different place along it. That
## is why these carry a depth as well as a position along the net -- a pin swing
## contacts about half a metre off the tape and a pipe is contacted three metres
## behind it, and the arrow that leaves them starts somewhere different because of
## it.
const NET_ZONES: Array[Dictionary] = [
	{"label": "4", "along": -3.4, "depth": 0.45},
	{"label": "3", "along": 0.0, "depth": 0.45},
	{"label": "2", "along": 3.4, "depth": 0.45},
	{"label": "pipe", "along": 0.0, "depth": 3.2},
]

## Which pin is being planned from, and whose it is.
##
## What is *left* of the drill after the annotation layer came off, and it is the
## half that was never in doubt: a net zone is selected and a voli can be dropped
## on it. Where the ball then goes, and what shot it is, were drawn as a guess and
## are held until they are specified.
signal drill_changed(zone_index: int)

var drill_zone: int = 2
var drill_who: String = ""

var phase: String = "Block"
var view: String = VIEW_THREE_QUARTER
## Where volis have been dropped, in unit court space, keyed by tray slot.
var placements: Dictionary = {}

## Which placement is being drawn, so its shadow can be recorded as a handle.
##
## Read by `_draw_sticker`, which draws every voli on the sheet and does not
## otherwise know whether it is drawing a *placed* one. Set around the placements
## loop and nowhere else, so the blockers, the hitter and the floor marks -- which
## are drawn from the phase rather than dropped by a manager -- cannot pick up a
## handle they should not have.
var _drawing_slot: int = -1

## Every placed voli's shadow, in screen space, exactly as it was drawn.
##
## **The shadow is the handle**, which is not a decoration of the idea but the
## whole of it: a sticker is a flat body standing up out of the floor, and the one
## part of it that is genuinely *on* the floor is its shadow. It is also the only
## part that stays where the voli stands in the plan view, where the body is a
## pair of shoulders seen from above and there is nothing else to take hold of.
##
## Recorded from the draw rather than recomputed, so a handle cannot be somewhere
## the shadow is not. That is the same discipline the ruled paper needed: one
## number feeding both, rather than two things agreeing by construction until one
## of them changes.
var _shadow_handles: Array[Dictionary] = []

## The placement being dragged, and how far the grab was from its own feet.
##
## The offset is in **court metres**, not pixels, for the reason everything else
## on this sheet is: a drag that survives a view change has to be stored in the
## world rather than on the screen. Without it a voli jumps so their feet land
## under the cursor the moment you touch them, which is a lurch on every grab.
var _drag_slot: int = -1
var _drag_offset: Vector2 = Vector2.ZERO
var _drag_live: Vector2 = Vector2.ZERO

## What the sheet has just refused to do, and why.
##
## A note on the page rather than a dialog. A page whose whole argument is that
## the drawing is the interface cannot answer a click with a modal window --
## that is the one thing on it you would have to operate from outside the
## drawing, which is the same reasoning that kept the zoom out.
##
## Cleared on a timer rather than a `_process` loop, and the token is what makes
## a second refusal safe: the first one's timer still fires, sees a token it does
## not own, and leaves the newer note alone.
## Where each behaviour option was drawn, so a click can find it.
var _behaviour_rows: Array[Dictionary] = []

var _notice: String = ""
var _notice_token: int = 0
const NOTICE_SECONDS: float = 2.8
## How close two volis may stand before a drop is refused, in metres. Under a
## metre is two bodies in one place; this is a shade over, so a legal pair can
## still stand shoulder to shoulder at the net.
const PLACEMENT_CLEARANCE_M: float = 0.85

## What a voli can be told to do, per phase.
##
## **This is the thing the sheet did not have.** A voli on it was a body in a
## pose, and the pose came from the *phase* -- `PHASE_POSE` is keyed by phase
## precisely because there was nothing per-voli to key on. So a page could say
## "this is a block" and could not say "this one closes the line and that one
## takes the seam", which is the entire content of a tactical instruction.
##
## The vocabularies are the real ones. An attacker's options are the shots that
## are actually distinct in the air -- two of them by direction, three by *how the
## ball is struck* -- and a blocker's are the two things a block chooses between
## (where to close) crossed with what it is trying to do (deflect or stop).
##
## Floor is provisional and marked as such. The user named the attack and block
## vocabularies; these are the standard terms for the same distinctions on
## defence, but nobody has said they are the ones this game wants.
const BEHAVIOURS := {
	"Attack": ["spike line", "spike cross", "tool", "roll", "feint"],
	"Block": ["close line", "close cross", "soft block", "kill block"],
	"Floor": ["dig line", "dig cross", "cover the tip", "chase"],
}

## What each voli has been told, keyed by slot **and phase**.
##
## Both, because an instruction is about one phase: the same voli closes the line
## when blocking and digs cross when the ball is coming down, and a single value
## per voli would make the second overwrite the first. Keyed as a string rather
## than nested dictionaries so a lookup is one `get` with a default.
var behaviours: Dictionary = {}

## Whose instruction the rail is showing. Set by taking hold of a voli, which is
## also how they are moved -- picking one up is the only thing "select" could
## mean on a sheet you operate by dragging.
var selected_slot: int = -1

signal behaviour_changed(slot: int, for_phase: String, behaviour: String)
signal voli_grabbed(who: String)
signal voli_released()


static func _behaviour_key(slot: int, for_phase: String) -> String:
	return "%d:%s" % [slot, for_phase]


## What this voli is doing in this phase, or "" if nobody has said.
func behaviour_of(slot: int, for_phase: String = "") -> String:
	var stem := for_phase if not for_phase.is_empty() else phase
	return str(behaviours.get(_behaviour_key(slot, stem), ""))


## Tell a voli what to do. Toggling the instruction they already have takes it
## back off them, the same way clicking a held zone lets it go.
func set_behaviour(slot: int, behaviour: String, for_phase: String = "") -> void:
	var stem := for_phase if not for_phase.is_empty() else phase
	if not placements.has(slot):
		return
	var options: Array = BEHAVIOURS.get(stem, [])
	if not behaviour.is_empty() and not behaviour in options:
		return
	var key := _behaviour_key(slot, stem)
	if str(behaviours.get(key, "")) == behaviour:
		behaviours.erase(key)
	else:
		behaviours[key] = behaviour
	behaviour_changed.emit(slot, stem, behaviour_of(slot, stem))
	queue_redraw()


## The name over the sticker, from whoever the sheet was given.
func _display_name_for(who: String) -> String:
	for profile: Dictionary in _squad():
		if str(profile.get("key", "")) == who:
			var shown := str(profile.get("display_name", ""))
			return shown if not shown.is_empty() else who
	return who


## Where a voli is standing, said the way a coach would say it.
func _where_is(on_court: Vector2) -> String:
	var pin := _nearest_net_zone(on_court)
	if pin >= 0:
		return "zone %s" % str(
			(NET_ZONES[pin] as Dictionary).get("label", pin + 1)
		)
	return "back court" if on_court.y > 3.0 else "front court"
var zone_priorities: Array[int] = [3, 2, 1, 2]
var light_mode: bool = true

## The layout being wiped away, and how far the squeegee has got. Nothing is
## drawn from these except the ghost; the board does not animate two live
## layouts at once, because a coach does not either.
var _ghost_phase: String = ""
var _wipe: float = 1.0
var _wipe_tween: Tween = null
var _hovered_zone: int = -1
var _seed: int = 0
var _stickers: UIVoliSticker = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	## The board paints itself from the palette, so it has to be told which
	## theme is up. `UIStyleSystem.apply` walks the tree on every switch but only
	## restyles nodes it recognises, and a hand-painted exempt node is not one --
	## so the board reads the theme off its own ancestry instead, the same way
	## `UIBackdrop` does, and refreshes when the tree tells it to.
	theme_changed.connect(_sync_theme)
	_sync_theme()
	## Painted by hand end to end. The style pass would give the board a drawn
	## paper edge and a halftone wash, which is the wrong material -- a board is
	## smooth, and its edge is a tray rather than a torn sheet.
	set_meta("ui_style_exempt", true)
	## Stickers are baked at 256 by 320 and drawn at a fraction of that, so the
	## sampler has to be told there are mipmaps to sample. Without this the
	## generated chain is never used and the bodies come back chewed.
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	custom_minimum_size = Vector2(420.0, 300.0)
	_seed = int(String(name).hash() & 0x7FFFFFFF)
	resized.connect(queue_redraw)
	## The bake needs frames, so it cannot happen inside `_draw`. Ask for the
	## poses now and redraw when each lands; until then the figures simply are not
	## there, which is honest -- a half-traced body would be worse than none.
	_stickers = VoliStickerScript.new()
	_stickers.name = "VoliStickers"
	add_child(_stickers)
	_stickers.sticker_ready.connect(_on_sticker_ready)
	_stickers.stickers_reset.connect(_request_stickers)
	_stickers.light_mode = light_mode
	_request_stickers()


## Re-emitted so a screen can populate a tray from the same bake queue rather
## than standing up a second one.
signal sticker_baked(key: String)


func _on_sticker_ready(key: String) -> void:
	sticker_baked.emit(key)
	queue_redraw()


func stickers() -> UIVoliSticker:
	return _stickers


## The poses the sheet draws, asked for once.
##
## Two blockers rather than one sticker used twice: they are different volis, and
## the whole reason to trace the rig is that a 201 cm middle and a 186 cm wing
## come out as visibly different people. The profiles are placeholders until the
## sheet is reading a real lineup.
## Where the camera stands for each view, and which way the body is turned under
## it. A sticker baked head-on and dropped into a plan view is a figure standing
## up out of the floor.
##
## **Both derived from the view, and the second one is the fix.** The camera
## angles were already coming off `VIEW_ANGLES`; the *body* was not. It was turned
## by `-theta`, which is the camera's own swing applied to the figure -- so every
## voli rotated with the camera and stayed square to the screen no matter where
## the viewer stood. Two blockers at a net came out chest-on to the reader, which
## is not what a blocker looks like from anywhere on a volleyball court.
##
## A body has a heading in the world. Everyone on this sheet is looking over the
## net, so their heading is -y, which is 180 degrees measured from the near court
## round toward the right sideline. What the bake needs is the angle between that
## heading and the direction the camera is looking, and the camera at azimuth
## `theta` looks along `theta + 180`: **yaw = heading - theta + 180**. At three
## quarter that is -38 degrees -- a blocker seen from behind and to one side,
## shoulders running along the tape -- and square on it is zero, which is what a
## back is.
##
## **The half turn is the second fix and it is the one that was reported.** The
## formula was `heading - theta`, which is the same relative angle read against
## the wrong zero: the rig's own forward at yaw 0 is -z, and -z is *away* from the
## bake camera, so yaw 0 is already a back and 180 is already a face. Reading it
## the other way put every voli on the sheet chest-on to a reader standing behind
## them -- 142 degrees at three quarter, which is a blocker facing their own
## setter. Measured rather than argued: `tools/preview/sheet_strip.gd -- turntable`
## bakes one blocker the whole way round in 45 degree steps, and the passing
## platform, which can only be in front of a body, appears at 180 and is hidden at
## 0.
const FACING_OVER_THE_NET: float = 180.0

## Which way the bake camera is looking, relative to where it stands.
const CAMERA_LOOKS_BACK: float = 180.0


func _bake_angles(for_view: String, facing_degrees: float = FACING_OVER_THE_NET) -> Vector2:
	var angles: Vector2 = VIEW_ANGLES.get(for_view, Vector2(-38.0, 32.0))
	return Vector2(facing_degrees - angles.x + CAMERA_LOOKS_BACK, -angles.y)

## How high the baked blockers are jumping, shared by the bake and the placement
## so the two cannot drift.
const BLOCK_ELEVATION: float = 0.85
## And how high an attacker is, which is higher: a blocker leaves the floor from
## a standing start beside the net and a spiker arrives at it with a run-up.
const ATTACK_ELEVATION: float = 1.00

## What each phase's volis are *doing*, because a page about blocking that draws
## everyone digging is a page nobody trusts.
##
## Keyed by phase rather than by role, which is the honest grain here: this sheet
## is a plan for one phase at a time, and what a voli is doing on it is what that
## phase asks of them. A blocker on the attack page is drawn attacking because the
## page is about the attack.
##
## `phase` is the signed contact phase the rig poses on, and for the attack it is
## **not zero**. Zero is the instant of contact -- the arm already through the
## ball, elbow open at 7 degrees -- which is the least legible frame of a spike:
## a straight arm above a head, indistinguishable from a serve or a reach. What
## reads as a spike is the *load*: `SpikeBiomechanics.COCK_END`, where the elbow
## is folded to 118 degrees, the shoulder is back at -152 and the trunk is arched.
## A drawing picks the frame that names the action, which is why illustrators draw
## the wind-up and photographers shoot the contact.
const PHASE_POSE := {
	"Attack": {
		"event": RallyEventModel.EventType.ATTACK,
		"elevation": ATTACK_ELEVATION, "phase": SpikeBiomechanics.COCK_END,
	},
	"Block": {
		"event": RallyEventModel.EventType.BLOCK,
		"elevation": BLOCK_ELEVATION, "phase": 0.0,
	},
	## And the floor pose is the **platform**, a beat before the ball arrives, not
	## the contact. `PLATFORM_SET_PHASE` is where the rig has the arms joined and
	## the knees folded -- a passer who is set and waiting, which is the posture the
	## page is asking a manager to place. At zero the arms have already passed
	## through and the figure stands up straight, which is a picture of somebody
	## queuing.
	"Floor": {
		"event": RallyEventModel.EventType.DEFENSE,
		"elevation": 0.0, "phase": -0.08,
	},
}

const BLOCKER_PROFILES: Array[Dictionary] = [
	{
		"key": "tall", "height_cm": 201.0, "wingspan_cm": 209.0,
		"stride_length_m": 0.93, "body_type": "Vegi", "dominant_hand": "Right",
		"standing_reach_meters": 2.62, "jumping_reach_meters": 3.42,
	},
	{
		"key": "wing", "height_cm": 186.0, "wingspan_cm": 190.0,
		"stride_length_m": 0.84, "body_type": "Cani", "dominant_hand": "Left",
		"standing_reach_meters": 2.44, "jumping_reach_meters": 3.24,
	},
]


## A sticker is a voli, in a pose, seen from a place -- so all three name it.
##
## The phase went into the key when the sheet stopped drawing everyone blocking.
## Without it a page about floor defence showed six volis with their hands over
## the tape, which is not a picture of anything.
##
## The plan view is the exception and takes a **headshot** whatever the phase. A
## body seen from directly overhead is a pair of shoulders and a scalp: it says
## nothing about what the voli is doing and nothing about who they are, which are
## the only two things a figure on this sheet is for. A face says the second, so
## the plan view spends its pixels on that and lets the marks carry the first.
func _sticker_key(who: String, for_view: String, for_phase: String = "") -> String:
	if for_view == VIEW_TOP_DOWN:
		return "%s_head" % who
	var stem := for_phase if not for_phase.is_empty() else phase
	return "%s_%s_%s" % [who, stem, for_view.replace(" ", "_")]


## The poses the sheet is showing *now*, and only those.
##
## **This used to ask for all of them, and that is the clipboard freeze.** The
## comment here read "a bake is roughly ten milliseconds, so the whole set is a
## blink at startup" -- which is a per-sticker figure used to justify a decision
## about the whole set, and the whole set is seven volis by three phases by two
## views plus a headshot each: **forty-nine bakes**, every one of them two posed
## 3D renders, two full-image readbacks and two contour traces. Ten milliseconds
## times forty-nine is not a blink, and the measured figure is far worse than ten.
##
## The old reasoning was not silly, it was just arguing about the wrong cost.
## Baking lazily "would put that blink in the middle of a view toggle" -- true,
## and a toggle costs **seven** stickers where opening the page cost forty-nine.
## Paying seven when you switch beats paying forty-nine before you have looked at
## anything, and with the disk cache you pay each of them once ever rather than
## once per open.
##
## So: the headshots, which the tray needs whatever is on the sheet, and the
## current phase in the current view. `_request_visible` is called again whenever
## either changes, and `request` already ignores anything it has baked or queued,
## so switching back to a phase you have seen costs nothing.
func _request_stickers() -> void:
	for profile: Dictionary in _squad():
		var who := str(profile.get("key", ""))
		if who.is_empty():
			continue
		## The tray draws all seven faces at once, so these are genuinely all
		## needed up front -- and a headshot does not change with the phase or the
		## view, so it is baked once and never again.
		_stickers.request(
			"%s_head" % who, RallyEventModel.EventType.SERVE, 0.0, -1.0,
			profile, -8.0, -4.0, true
		)
	_request_visible()


## Whatever the sheet is about to draw, asked for now.
##
## Cheap to call repeatedly: `UIVoliSticker.request` returns immediately for a key
## it already holds or already has queued, so this is a no-op on every phase you
## have already looked at.
func _request_visible() -> void:
	if _stickers == null or view == VIEW_TOP_DOWN:
		return
	var angles := _bake_angles(view)
	var pose: Dictionary = PHASE_POSE.get(phase, PHASE_POSE["Block"])
	for profile: Dictionary in _squad():
		var who := str(profile.get("key", ""))
		if who.is_empty():
			continue
		_stickers.request(
			_sticker_key(who, view, phase),
			int(pose["event"]), float(pose["elevation"]),
			float(pose.get("phase", 0.0)), profile, angles.x, angles.y
		)


## Who the sheet has bodies for.
##
## Set by the screen from the real lineup; the placeholder pair is what is drawn
## until it is. Keyed by `key` so a sticker can be asked for by name without the
## drawing knowing anything about rotation slots.
var squad: Array[Dictionary] = []


func _squad() -> Array[Dictionary]:
	return squad if not squad.is_empty() else BLOCKER_PROFILES


## Give the sheet the actual lineup. Rebakes, because a sticker is a photograph
## of a specific voli and these are different volis.
func set_squad(profiles: Array[Dictionary]) -> void:
	## Guarded, and the guard is not an optimisation. Clearing the cache emits
	## `stickers_reset`, and anything that answers that by handing the squad back
	## is a loop -- which is exactly what happened: the screen re-sent the same
	## seven volis on every reset and the two bounced until the stack ran out.
	if profiles == squad:
		return
	squad = profiles
	if _stickers != null:
		_stickers.clear()
		_request_stickers()
	queue_redraw()


## Lay a baked sticker down: shadow, shaded body, then the cut border.
##
## `ground` is the projection of the patch of floor the voli is standing on, and
## `scale` is the view's pixels per metre. **Nothing here picks a size.** The bake
## knows how many metres tall the crop is and how far its bottom edge sits from
## the voli's own ground point, so both the height and the lift are arithmetic.
##
## Two tuned numbers died to get here. The height was a share of the panel, which
## made a blocker about four metres tall in the plan view -- shrink the court and
## the voli grew. The lift was `BLOCK_ELEVATION * 0.82`, the jump written out a
## second time in the drawing, so a pose change silently left the body hanging off
## its own shadow. Both now come off the render that is already being drawn.
func _draw_sticker(key: String, ground: Vector2, scale: float) -> bool:
	if _stickers == null:
		return false
	var built: UIVoliSticker.Sticker = _stickers.sticker(key)
	if built == null or built.contours.is_empty():
		return false
	var height := built.world_height * scale
	var box := Vector2(height * built.aspect, height)
	var origin := Vector2(
		ground.x - box.x * 0.5,
		ground.y + built.ground_offset * scale - box.y
	)

	## 1. The shadow. Without it a sticker is a shape with a thick outline; with
	## it the shape is above the paper.
	for contour in built.contours:
		var shadowed := PackedVector2Array()
		for point in (contour as PackedVector2Array):
			shadowed.append(origin + point * box + STICKER_SHADOW_OFFSET)
		if shadowed.size() >= 3:
			draw_colored_polygon(shadowed, Color(0.0, 0.0, 0.0, STICKER_SHADOW_ALPHA))
			## Kept only for a voli somebody put there. What the phase draws is
			## not a thing anybody may pick up.
			if _drawing_slot >= 0:
				_shadow_handles.append({
					"slot": _drawing_slot, "poly": shadowed,
				})

	## 2. The cut edge: the keyline, then the stock it edges.
	##
	## **Both under the body rather than over it,** which is the ordering fix. A
	## polyline is centred on its path, so a border drawn on the contour puts half
	## its width inside the silhouette -- the cut was eating into the art, and the
	## thicker the sticker the more of the voli it ate. Laid down first and painted
	## over, only the outer half survives, which is where a margin belongs.
	##
	## The keyline is drawn wider than the stock and in the same place, so what is
	## left of it after the stock goes on is a thin ring outside the margin. Two
	## strokes for a border a printer would also make in two passes.
	var cut := clampf(
		height * STICKER_BORDER_SHARE, STICKER_BORDER_MIN, STICKER_BORDER_MAX
	)
	if draw_die_cut:
		for contour in built.contours:
			var edge := PackedVector2Array()
			for point in (contour as PackedVector2Array):
				edge.append(origin + point * box)
			if edge.size() < 3:
				continue
			_stroke_closed(edge, STICKER_KEYLINE, cut * (1.0 + STICKER_KEYLINE_SHARE * 2.0))
			_stroke_closed(edge, STICKER_STOCK, cut)

	## 3. The body, carrying the mesh's own light and shade.
	if built.texture != null:
		draw_texture_rect(built.texture, Rect2(origin, box), false)

	## 4. And the arms, cut separately over the top.
	##
	## A pose is mostly arms, and an arm crossing the torso vanishes into the one
	## outline the silhouette gives -- so a blocker, a spiker at the cock and a
	## passer on their platform came out as one shape three times. Lighter than the
	## body's edge, because these are creases inside the sticker rather than the
	## line it was cut along: a die cut has one edge, and a printed one can have as
	## many lines as the printer put on it.
	for contour in built.arm_contours:
		var crease := PackedVector2Array()
		for point in (contour as PackedVector2Array):
			crease.append(origin + point * box)
		if crease.size() >= 3:
			_stroke_closed(crease, Color(_ink(), 0.80), cut * 0.62)
	return true


## A closed outline, at a width, in a colour.
##
## `draw_polyline` leaves the last point unjoined to the first, so every caller
## was drawing the closing segment itself -- three times over, and one of them
## had drifted. The width is passed rather than derived because the callers use
## different ones for the same contour.
func _stroke_closed(outline: PackedVector2Array, color: Color, width: float) -> void:
	if outline.size() < 3:
		return
	draw_polyline(outline, color, width, true)
	draw_line(outline[outline.size() - 1], outline[0], color, width, true)


func set_light_mode(value: bool) -> void:
	light_mode = value
	queue_redraw()


func _sync_theme() -> void:
	light_mode = UIPalette.control_is_light(self)
	## The stickers carry their palette in the pixels, so a theme switch has to
	## reach them too -- they are the one thing on this sheet that cannot be
	## repainted at draw time.
	if _stickers != null:
		_stickers.set_palette(light_mode)
	queue_redraw()


## Choose a phase: squeegee what is there, then draw the new one.
func set_phase(value: String) -> void:
	if value == phase or not value in PHASES:
		return
	_ghost_phase = phase
	phase = value
	## Before the wipe rather than after it: the sheet is about to be squeegeed
	## and redrawn, and the bake wants to be running during the half second the
	## wipe is across rather than starting when it lands.
	_request_visible()
	phase_changed.emit(phase)
	_start_wipe()


func _start_wipe() -> void:
	if _wipe_tween != null and _wipe_tween.is_valid():
		_wipe_tween.kill()
	_wipe = 0.0
	_wipe_tween = create_tween()
	_wipe_tween.tween_method(_set_wipe, 0.0, 1.0, 0.34)
	_wipe_tween.set_ease(Tween.EASE_OUT)
	_wipe_tween.set_trans(Tween.TRANS_CUBIC)


## Change where the court is being looked at. Wipes and redraws, exactly like a
## phase change -- a coach rubbing out a plan view and drawing the same thing from
## the end of the net is doing one action, not two.
func set_view(value: String) -> void:
	if value == view or not value in VIEWS:
		return
	_ghost_phase = phase
	view = value
	## Same as the phase: a view change is a different camera angle, so every
	## body on the sheet needs re-baking from where the reader now stands.
	_request_visible()
	view_changed.emit(view)
	_start_wipe()


## What this view can say about this phase, or an empty string if it cannot.
static func adjustment_for(for_view: String, for_phase: String) -> String:
	var by_phase: Dictionary = ADJUSTMENTS.get(for_view, {})
	return str(by_phase.get(for_phase, ""))


## The first phase this view has anything to say about, in rally order.
static func first_phase_for(for_view: String) -> String:
	for candidate in PHASES:
		if not adjustment_for(for_view, candidate).is_empty():
			return candidate
	return ""


## The overlay this phase owns, or an empty string.
static func overlay_for(for_phase: String) -> String:
	return str(OVERLAYS.get(for_phase, ""))


## Put a voli where the sheet was clicked, stored as **the place on the court**
## rather than the place on the page.
##
## `at` is local pixels; what is kept is metres. A share of the panel is only the
## same court position while the panel and the camera both hold still, and
## neither does -- a voli dropped in the plan view reappeared somewhere unrelated
## the moment the view changed, because the sheet was remembering the cursor
## instead of the voli.
func place_voli(slot: int, at: Vector2, who: String = "") -> void:
	var frame := _view_frame()
	place_voli_at(slot, _unproject_floor(at, frame["scale"], frame["origin"]), who)


## The same placement, said in metres.
##
## **The drop is the convenience; this is the operation.** A drag is one person
## pointing at one spot, and everything else that will ever want to put a voli
## somewhere arrives holding numbers: a scouting report that says the block was
## beaten down the line at (4.1, 1.2), a rotation preset, a saved formation, a
## plan restored from a career file. If the only way in is a cursor then none of
## those can be honoured without simulating a mouse, which is how a coordinate
## ends up being converted to pixels and back and losing a few centimetres each
## way.
##
## So `place_voli` unprojects and calls this, rather than this being a wrapper
## round the pointer. See `docs/design/TACTICS_AND_TRAINING.md` §0.12.
func place_voli_at(slot: int, on_court: Vector2, who: String = "") -> void:
	## Refused rather than clamped when it lands off the court. A clamp would put
	## a voli on the sideline and say nothing; not placing them says the drop
	## missed, which is what happened.
	if absf(on_court.x) > HALF_WIDTH_M + 1.0 or absf(on_court.y) > COURT_HALF_M + 1.0:
		return
	## **Who**, not just where. The sheet used to alternate two placeholder bodies
	## by slot parity, so dropping the libero drew whichever of the two stand-ins
	## the arithmetic landed on -- a picture of a formation made of the wrong
	## people, which is worse than no picture.
	## Dropped at the net, they are the one swinging.
	##
	## No separate "assign hitter" control, because there is nothing a separate
	## control would say that the drop does not: a voli standing on a pin with a
	## dashed arrow leaving their hand *is* "this voli drills this shot from here".
	## The catch radius is a metre and a half of court rather than a pixel distance,
	## so it means the same thing in all three views.
	## And refused when somebody is already standing there.
	if _crowded(slot, on_court):
		_say("Somebody is already standing there.")
		queue_redraw()
		return
	var pin := _nearest_net_zone(on_court)
	if pin >= 0 and not who.is_empty():
		drill_zone = pin
		drill_who = who
		drill_changed.emit(drill_zone)
	placements[slot] = {"at": on_court, "who": who}
	queue_redraw()


func _nearest_net_zone(on_court: Vector2) -> int:
	var best := -1
	var closest := 1.6
	for index in range(NET_ZONES.size()):
		var zone: Dictionary = NET_ZONES[index]
		var gap := on_court.distance_to(
			Vector2(float(zone["along"]), float(zone["depth"]))
		)
		if gap < closest:
			closest = gap
			best = index
	return best


func _set_wipe(value: float) -> void:
	_wipe = value
	queue_redraw()


## Scrolling over a bar changes that zone's priority.
##
## The control the planner had for this was an `OptionButton` reading "P2 ·
## Seam", which is the value written out as text -- three clicks and a menu to
## change a number whose whole meaning is how it compares to the other three.
## Four bars answer that at a glance, and a wheel changes one without leaving it.
## Three things are draggable or scrollable on this sheet and they are told apart
## by what is under the cursor, not by a mode. A mode would mean a control that
## says which of them you are editing, and the whole argument of the page is that
## the drawing *is* the control.
## Which placed voli's shadow is under this point, or -1.
##
## Topmost first, because the draw order is the stacking order and two volis
## close together overlap: the one drawn last is the one on top, and the one on
## top is the one a hand would take hold of.
func _shadow_at(at: Vector2) -> int:
	for index in range(_shadow_handles.size() - 1, -1, -1):
		var handle: Dictionary = _shadow_handles[index]
		if Geometry2D.is_point_in_polygon(at, handle["poly"]):
			return int(handle["slot"])
	return -1


## Say something on the page, briefly.
func _say(message: String) -> void:
	_notice = message
	_notice_token += 1
	var token := _notice_token
	queue_redraw()
	## A sheet can be built and asked things before it is added to anything --
	## `place_voli_at` is a public method and a career restoring a plan calls it
	## -- and there is no tree to hang a timer on then. The note is still set, so
	## it appears with the first draw and the next refusal replaces it.
	if not is_inside_tree():
		return
	var timer := get_tree().create_timer(NOTICE_SECONDS)
	timer.timeout.connect(func() -> void:
		if token != _notice_token:
			return
		_notice = ""
		queue_redraw()
	)


## Why this phase will not take a voli on that kind of ground, or "" if it will.
##
## Keyed by phase, because that is what the sheet is *about* at the time: a page
## planning a block is a page about the net, and a floor section on it is scenery
## for judging distances against rather than somewhere a blocker can stand. The
## refusal names who cannot go there rather than saying "invalid", because the
## first is a fact about volleyball and the second is a fact about software.
func _refusal(kind: String) -> String:
	match phase:
		"Block":
			if kind == "floor":
				return "No blockers on the floor — a block is made at the net."
		"Floor":
			if kind == "net":
				return "No receivers at the net — this phase is played off it."
		"Attack":
			## Both are legal here and that is not an omission: a hitter starts on
			## the floor and finishes at the net, so an attack page is the one page
			## where the whole court is somewhere a voli can be.
			return ""
	return ""


## Whether a voli may stand here, given who is already standing about.
##
## Two bodies in one place is not a formation, it is a drawing mistake, and it is
## an easy one to make when a drop lands within a few pixels of an existing voli
## in a view that foreshortens depth. Measured in metres so it means the same
## thing in all three views -- a pixel clearance would be twice as strict along
## the net as it is across the court.
func _crowded(slot: int, on_court: Vector2) -> bool:
	for raw_slot: int in placements:
		if int(raw_slot) == slot:
			continue
		var other: Dictionary = placements[raw_slot]
		var spot: Vector2 = other.get("at", Vector2.ZERO)
		if spot.distance_to(on_court) < PLACEMENT_CLEARANCE_M:
			return true
	return false


## Take a voli off the sheet.
func remove_voli(slot: int) -> void:
	if not placements.has(slot):
		return
	placements.erase(slot)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var frame := _view_frame()
	var scale: float = frame["scale"]
	var origin: Vector2 = frame["origin"]

	if event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		## A drag in progress owns the pointer. Written straight to `_drag_live`
		## rather than through `place_voli_at`, because that refuses anything off
		## the court -- which is correct for a drop and wrong for a drag, where
		## leaving the court is how you say "take this one off".
		if _drag_slot >= 0:
			_drag_live = _unproject_floor(motion.position, scale, origin) \
				+ _drag_offset
			queue_redraw()
			accept_event()
			return
		var was_rail := _hovered_zone
		var was_net := _hovered_net
		var was_floor := _hovered_floor
		_hovered_zone = _zone_at(motion.position) if phase == "Block" else -1
		var under := _zone_under(motion.position, scale, origin)
		_hovered_net = int(under[1]) if str(under[0]) == "net" else -1
		_hovered_floor = int(under[1]) if str(under[0]) == "floor" else -1
		if was_rail != _hovered_zone or was_net != _hovered_net \
				or was_floor != _hovered_floor:
			queue_redraw()
		return
	if not (event is InputEventMouseButton):
		return
	var button := event as InputEventMouseButton

	if button.button_index == MOUSE_BUTTON_LEFT:
		if not button.pressed:
			if _drag_slot < 0:
				return
			## Dropped. Off the court is a removal, which is the whole of the
			## remove gesture: there is no bin to aim at and no second control,
			## you take a voli off the sheet by taking them off the sheet.
			var slot := _drag_slot
			var landed := _drag_live
			_drag_slot = -1
			voli_released.emit()
			## The same bound `place_voli_at` refuses on, deliberately. Two
			## different margins leaves a band where a drop is neither placed nor
			## removed and the voli silently springs back -- which reads as the
			## drag having failed rather than as the sheet having a rule.
			if absf(landed.x) > HALF_WIDTH_M + 1.0 \
					or absf(landed.y) > COURT_HALF_M + 1.0:
				remove_voli(slot)
				_say("Taken off the sheet.")
			else:
				place_voli_at(slot, landed, str(
					(placements.get(slot, {}) as Dictionary).get("who", "")
				))
			accept_event()
			queue_redraw()
			return
		## **The shadow is the handle, and it is checked before the zones are.**
		## A voli stands *on* a zone, so the two are always under the cursor
		## together -- and of the two, the one a hand is reaching for is the body
		## it can see, not the ground under it.
		## The rail's options take the click before anything on the court does.
		## They are drawn over the sheet, so they are in front of it in the one
		## sense that matters to a pointer.
		for row: Dictionary in _behaviour_rows:
			if (row["rect"] as Rect2).has_point(button.position):
				set_behaviour(selected_slot, str(row["behaviour"]))
				accept_event()
				return
		var grabbed := _shadow_at(button.position)
		if grabbed >= 0:
			_drag_slot = grabbed
			## Taking hold is also selecting. There is nothing else "select" could
			## mean on a sheet you operate by dragging, and a separate click to
			## select would be a second gesture for a thing the first already said.
			selected_slot = grabbed
			var held: Dictionary = placements[grabbed]
			_drag_live = held.get("at", Vector2.ZERO)
			_drag_offset = _drag_live - _unproject_floor(
				button.position, scale, origin
			)
			voli_grabbed.emit(str(held.get("who", "")))
			accept_event()
			queue_redraw()
			return
		## A zone under the cursor takes the click, and taking it means **moving in
		## on it**. Clicking the one already held lets it go again. That is the whole
		## of the zoom control, and it deliberately is not a control: a page whose
		## argument is that the drawing is the interface should not grow a magnifier
		## you operate from outside the drawing.
		var under := _zone_under(button.position, scale, origin)
		var kind := str(under[0])
		if kind != "":
			var index := int(under[1])
			## Refused before it focuses, so the sheet does not move in on a
			## place this phase has nothing to say about.
			var refused := _refusal(kind)
			if not refused.is_empty():
				_say(refused)
				accept_event()
				return
			if focus_kind == kind and focus_index == index:
				focus_kind = ""
				focus_index = -1
			else:
				focus_kind = kind
				focus_index = index
			## A net zone is also where a swing comes from, so holding one picks it.
			if kind == "net":
				drill_zone = index
				drill_changed.emit(drill_zone)
			accept_event()
			queue_redraw()
			return
		## Nothing under the cursor: pull back out.
		if focus_kind != "":
			focus_kind = ""
			focus_index = -1
			accept_event()
			queue_redraw()
		return

	if not button.pressed:
		return
	var step := 0
	if button.button_index == MOUSE_BUTTON_WHEEL_UP:
		step = 1
	elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		step = -1
	if step == 0:
		return

	## A wheel over the priority rail changes a priority. It used to also cycle the
	## shot type anywhere else on the drawing; the shot was part of the annotation
	## layer that came off, and a wheel that changes something invisible is a
	## control nobody can find the effect of.
	var index := _zone_at(button.position)
	if index < 0 or phase != "Block":
		return
	zone_priorities[index] = clampi(
		zone_priorities[index] + step, 0, ZONE_MAX_PRIORITY
	)
	zone_priority_changed.emit(index, zone_priorities[index])
	accept_event()
	queue_redraw()


## Put a voli on the pin -- the one the drill is about.
func set_drill_voli(who: String) -> void:
	drill_who = who
	queue_redraw()


func _exit_tree() -> void:
	if _wipe_tween != null and _wipe_tween.is_valid():
		_wipe_tween.kill()



# --------------------------------------------------------------------------
# Drawing
# --------------------------------------------------------------------------

func _draw() -> void:
	## Read at draw time rather than trusted from a signal.
	##
	## `theme_changed` is connected and does fire, but the first draft trusted it
	## alone and the board rendered dark inside Molten -- one lookup that was
	## stale by a frame, on the one node whose entire surface is a colour. A
	## theme colour lookup per redraw is nothing next to a few hundred strokes,
	## and it cannot be out of date.
	light_mode = UIPalette.control_is_light(self)
	## And the stickers with it. `theme_changed` does not always fire -- a page
	## built before it is added to its tab container gets its theme by inheritance
	## rather than by signal -- so the board painted itself dark while the bodies
	## stayed in the light palette and read as white blobs. Reading it here is the
	## same fix, and for the same reason, as reading the board colour here.
	if _stickers != null:
		_stickers.set_palette(light_mode)
	draw_rect(Rect2(Vector2.ZERO, size), _board_color())
	_draw_graph()

	## The previous working, still faintly there. An eraser lifts graphite; it
	## does not remove it, and what is left is exactly this.
	if not _ghost_phase.is_empty():
		_draw_phase(_ghost_phase, GHOST_ALPHA * (2.0 - _wipe))

	_draw_phase(phase, 1.0, _wipe)
	if _wipe < 1.0:
		_draw_eraser(_wipe)


## The printed squares.
##
## Fixed pitch in screen pixels rather than as a fraction of the panel, for the
## same reason the form's grid is: a press does not rescale its grid to fit the
## sheet, and two panels sharing one grid is most of what makes it read as
## printed. Every fifth line is heavier, which is what squared paper does and
## what makes it countable -- the whole reason to work a court out on it.
func _draw_graph() -> void:
	var ink := GRAPH_INK_LIGHT if light_mode else GRAPH_INK_DARK
	var index := 1
	var x := GRAPH_PITCH
	while x < size.x:
		var major := index % GRAPH_MAJOR_EVERY == 0
		draw_line(
			Vector2(x, 0.0), Vector2(x, size.y),
			Color(ink, GRAPH_MAJOR_ALPHA if major else GRAPH_ALPHA), 1.0
		)
		x += GRAPH_PITCH
		index += 1
	index = 1
	var y := GRAPH_PITCH
	while y < size.y:
		var major := index % GRAPH_MAJOR_EVERY == 0
		draw_line(
			Vector2(0.0, y), Vector2(size.x, y),
			Color(ink, GRAPH_MAJOR_ALPHA if major else GRAPH_ALPHA), 1.0
		)
		y += GRAPH_PITCH
		index += 1


## The eraser, travelling left to right, lifting the working as it goes.
##
## A squeegee had a bright leading edge because it is wet. An eraser is dry and
## does the opposite: it leaves a band of *smudge* behind it, graphite pushed
## rather than removed, which fades over the following second.
func _draw_eraser(progress: float) -> void:
	var x := size.x * progress
	var rubber := Color(0.94, 0.86, 0.78) if light_mode else Color(0.52, 0.46, 0.42)
	var smudge := Color(_ink(), 0.10)
	draw_rect(Rect2(x - 34.0, 0.0, 34.0, size.y), smudge)
	draw_rect(Rect2(x - 13.0, size.y * 0.32, 13.0, size.y * 0.30), rubber)
	draw_rect(
		Rect2(x - 13.0, size.y * 0.32, 13.0, size.y * 0.30),
		Color(rubber.darkened(0.30), 0.7), false, 1.0
	)


## One routine for all three views.
##
## It used to be three, dispatched on `view`, and that dispatch was the defect:
## each branch built its own court out of shares of the panel, so the same net
## drew at two different heights, the plan view showed half a court, and a voli
## dropped in one view landed somewhere else in another. There is only one court;
## what changes is where you stand.
func _draw_phase(which: String, alpha: float, reveal: float = 1.0) -> void:
	_draw_view(which, alpha, reveal)


## Every view draws the same three things in the same order -- the floor, then
## whatever stands on it, then the phase's own marks -- and differs only in where
## the camera is. The heading and the "nothing to set from here" line are shared
## too, because they are page furniture rather than drawing.
func _draw_view(which: String, alpha: float, reveal: float) -> void:
	var ink := _ink()
	var frame := _view_frame()
	var scale: float = frame["scale"]
	var origin: Vector2 = frame["origin"]

	_marker_text(
		which.to_upper(), Vector2(size.x * 0.05, size.y * 0.12), 24, ink, alpha, reveal
	)
	_marker_text(
		view.to_lower(), Vector2(size.x * 0.05, size.y * 0.155), 12,
		Color(ink, 0.45), alpha, reveal
	)

	_draw_court(scale, origin, ink, alpha, reveal)
	if view == VIEW_TOP_DOWN:
		## From straight above a net is a line, and drawing the mesh would be drawing
		## a wall edge-on -- so the plan view gets the tape and the antennae and
		## nothing else, and spends the space on the zones instead. The rotation
		## numerals used to be drawn here too; the zone regions carry them now, which
		## is where they belong -- a numeral is a name for a region.
		for at: float in [-HALF_WIDTH_M, HALF_WIDTH_M]:
			_marker_circle(
				_floor_at(at, 0.0, scale, origin), 4.0, MARKER_RED, alpha, reveal,
				451 + int(at)
			)
	else:
		_draw_net(scale, origin, ink, alpha, reveal)

	## The zones, which are what the page is operated through.
	##
	## Every phase gets both grids, because every phase is an opinion about the same
	## two places: somewhere along the net a ball leaves, and somewhere on a floor it
	## arrives. What changes by phase is which end you are standing at, not which
	## geometry exists.
	_draw_zone_regions(scale, origin, ink, alpha, reveal)

	## The annotation layer is **deliberately empty**.
	##
	## There was one: a dashed flight from a pin to a landing mark, a shot label, a
	## setter and a lane arrow, a seam ring, a serve overlay, dimension lines. All
	## of it was a first guess at what a coach writes on this sheet, and a first
	## guess drawn confidently is worse than nothing -- it reads as a decision the
	## game has made. Taken off until the marks are specified.
	##
	## What is left is what the sheet *is*: a court, a net, the zones of both, and
	## the volis standing in them. Everything removed was a mark somebody makes on
	## that; nothing removed was part of it.
	match which:
		"Block":
			_draw_blockers(scale, origin, ink, alpha, reveal)
		"Attack":
			_draw_attacker(scale, origin, ink, alpha, reveal)
		"Floor":
			_draw_floor_marks(scale, origin, ink, alpha, reveal)

	## Anything dragged out of the tray, standing where it was dropped -- which is
	## stored in metres, so it is the same place in all three views.
	## Rebuilt every draw, immediately before the volis that fill it. Anything
	## drawn after this loop leaves `_drawing_slot` at -1 and registers nothing.
	_shadow_handles.clear()
	for raw_slot: int in placements:
		var placed: Dictionary = placements[raw_slot]
		var spot: Vector2 = placed.get("at", Vector2.ZERO)
		if raw_slot == _drag_slot:
			spot = _drag_live
		var who := str(placed.get("who", ""))
		if who.is_empty():
			who = "tall" if raw_slot % 2 == 0 else "wing"
		_drawing_slot = raw_slot
		_draw_voli(
			_sticker_key(who, view, which), spot.x, spot.y, scale, origin,
			ink, alpha, reveal, 500 + raw_slot * 7
		)
		_drawing_slot = -1

	for raw_slot: int in placements:
		var told := behaviour_of(int(raw_slot))
		if told.is_empty():
			continue
		var placed_at: Vector2 = (placements[raw_slot] as Dictionary).get(
			"at", Vector2.ZERO
		)
		if int(raw_slot) == _drag_slot:
			placed_at = _drag_live
		_draw_behaviour_arrow(
			told, placed_at, scale, origin, alpha, reveal, 700 + int(raw_slot) * 13
		)

	if not _notice.is_empty():
		_marker_text(
			_notice, Vector2(size.x * 0.06, size.y * 0.075), 15,
			Color(0.78, 0.32, 0.30), alpha, reveal
		)

	## **The rail is an instruction, not a chart.**
	##
	## It held four priority bars -- a frequency reading of where attacks go,
	## which is a fact about the *opponent* on a page about what your own volis
	## should do. Interesting once and never actionable: nothing you could do to
	## the sheet changed it, so it was the one thing on the page you could only
	## read. What a coach wants at the right hand is who they are holding and what
	## that one is being told to do.
	_draw_instruction(_rail_rect(), ink, alpha, reveal)

	if adjustment_for(view, which).is_empty():
		_marker_text(
			"%s — nothing to set from here" % which.to_upper(),
			Vector2(size.x * 0.06, size.y * 0.955), 13, ink, alpha * 0.6, reveal
		)


## Where the floor defence stands. Six real positions in metres, so the shape a
## coach sets here is the shape playback will show.
func _draw_floor_marks(
	scale: float, origin: Vector2, ink: Color, alpha: float, reveal: float
) -> void:
	## The defence, as bodies rather than circles. A page about where five volis
	## stand that draws five rings is a page that has not said who is standing
	## anywhere -- and the whole reason the rig gets traced is that these are
	## different people in a readable posture.
	var spots := [
		Vector2(-3.2, 1.1), Vector2(3.2, 1.2), Vector2(-3.4, 6.4),
		Vector2(0.2, 7.4), Vector2(3.4, 6.0),
	]
	var roster := _squad()
	for index in range(spots.size()):
		var spot: Vector2 = spots[index]
		var who := str(
			(roster[index % roster.size()] as Dictionary).get("key", "")
		)
		if _draw_voli(
			_sticker_key(who, view, "Floor"), spot.x, spot.y, scale, origin,
			ink, alpha, reveal, 121 + index * 13
		):
			continue
		_marker_circle(
			_floor_at(spot.x, spot.y, scale, origin), 9.0, ink, alpha, reveal,
			121 + index * 13
		)


## Cross-hatching: two crossing sets of strokes. One direction is texture; two
## are shadow, and the difference is the whole reason to bother.
func _hatch(
	area: Rect2, color: Color, alpha: float, reveal: float, salt: int
) -> void:
	if area.size.x < 3.0 or area.size.y < 3.0:
		return
	var pitch := 5.5
	var steps := int((area.size.x + area.size.y) / pitch)
	for step in range(steps):
		var offset := float(step) * pitch
		var a := Vector2(area.position.x + offset, area.position.y)
		var b := a + Vector2(-area.size.y, area.size.y)
		_marker_line(
			a.clamp(area.position, area.end), b.clamp(area.position, area.end),
			color, alpha, reveal, salt + step, MARKER_WIDTH * 0.32
		)
	for step in range(0, steps, 2):
		var offset := float(step) * pitch
		var a := Vector2(area.position.x + offset - area.size.y, area.position.y)
		var b := a + Vector2(area.size.y, area.size.y)
		_marker_line(
			a.clamp(area.position, area.end), b.clamp(area.position, area.end),
			Color(color, color.a * 0.7), alpha, reveal, salt + 500 + step,
			MARKER_WIDTH * 0.30
		)


## Projection is deliberately not a camera: an axonometric map with no
## perspective divide, because a drawing has no focal length and a vanishing
## point would make the sheet look rendered rather than drawn.


## One projection for every view: world metres in, pixels out.
##
## `world` is (along the net, depth from the net, height off the floor) in
## metres, with the net at y = 0, the near court at positive y and the far court
## at negative. Rotate by `theta`, tilt by `phi`, drop the third axis.
##
## Everything on the sheet goes through this now. The three views used to build
## their own geometry from shares of the panel, which is why a net could be two
## different heights and a voli could stand on a floor drawn at an angle nobody
## had baked them at.
func _project(world: Vector3, scale: float, origin: Vector2) -> Vector2:
	var angles: Vector2 = VIEW_ANGLES.get(view, Vector2(-38.0, 32.0))
	var theta := deg_to_rad(angles.x)
	var phi := deg_to_rad(angles.y)
	var flat_x := world.x * cos(theta) - world.y * sin(theta)
	var flat_y := world.x * sin(theta) + world.y * cos(theta)
	return origin + Vector2(
		flat_x * scale,
		(flat_y * sin(phi) - world.z * cos(phi)) * scale
	)


## The floor, which is most of what gets projected -- shorthand for z = 0.
func _floor_at(along: float, depth: float, scale: float, origin: Vector2) -> Vector2:
	return _project(Vector3(along, depth, 0.0), scale, origin)


## And back again: a point on the sheet to the place on the floor under it.
##
## Needed because a drop lands in pixels and has to be *stored* in metres. Storing
## the pixel share instead is what let a voli dropped in one view reappear
## somewhere unrelated in another -- the sheet remembered where the cursor was
## rather than where the voli is, so the answer changed when the camera did.
##
## Solvable in closed form because the map is linear and z is known: two equations
## in two unknowns, and `sin(phi)` is never zero for any view that can see a floor
## at all.
func _unproject_floor(at: Vector2, scale: float, origin: Vector2) -> Vector2:
	var angles: Vector2 = VIEW_ANGLES.get(view, Vector2(-38.0, 32.0))
	var theta := deg_to_rad(angles.x)
	var phi := deg_to_rad(angles.y)
	var flat_x := (at.x - origin.x) / maxf(scale, 0.001)
	var flat_y := (at.y - origin.y) / maxf(scale * sin(phi), 0.001)
	return Vector2(
		flat_x * cos(theta) + flat_y * sin(theta),
		-flat_x * sin(theta) + flat_y * cos(theta)
	)


## Where the camera stands and how big a metre is, fitted to the panel.
##
## The whole of the sizing lives here now. Project the box's eight corners at
## unit scale, measure the extent that comes back, divide by what the panel has:
## one number, derived, per view. Nothing downstream is allowed to pick a size --
## a voli is `world_height * scale` pixels tall and a net is 2.43 * scale,
## because those are the metres they are.
##
## The defect this replaces: every view computed its own geometry from shares of
## the panel, so a blocker came out about four metres tall in the plan view and
## the same net drew at two different heights depending on which view you were in.
func _view_frame() -> Dictionary:
	var box := _world_box()
	var low: Vector3 = box[0]
	var high: Vector3 = box[1]
	var least := Vector2(INF, INF)
	var most := Vector2(-INF, -INF)
	for along: float in [low.x, high.x]:
		for depth: float in [low.y, high.y]:
			for height: float in [low.z, high.z]:
				var flat := _project(Vector3(along, depth, height), 1.0, Vector2.ZERO)
				least = Vector2(minf(least.x, flat.x), minf(least.y, flat.y))
				most = Vector2(maxf(most.x, flat.x), maxf(most.y, flat.y))
	var extent := most - least
	var rail := _rail_rect()
	var usable := Vector2(
		rail.position.x - size.x * MARGIN_SHARE * 2.0,
		size.y * (1.0 - HEAD_SHARE - FOOT_SHARE)
	)
	var scale := minf(
		usable.x / maxf(extent.x, 0.001), usable.y / maxf(extent.y, 0.001)
	)
	var frame := Rect2(
		Vector2(size.x * MARGIN_SHARE, size.y * HEAD_SHARE), usable
	)
	## The net lands in the same place whatever the phase is.
	##
	## Centring the *box* meant the net moved: attack holds -7.6 to 4.4 metres of
	## depth and block holds -1.4 to 3.0, so the net -- which is at zero -- sits
	## below the middle of one and above the middle of the other, and switching
	## page slid it down the sheet. Two drawings of one court that disagree about
	## where the court is.
	##
	## Anchor the world origin instead, and let the box fall where it falls. The
	## clamp below only moves it when the box would otherwise leave the sheet, which
	## is the one case where staying put would be worse.
	var anchored := frame.position + Vector2(frame.size.x * 0.46, frame.size.y * NET_ANCHOR)
	var drawn := Rect2(anchored + least * scale, extent * scale)
	var nudge := Vector2.ZERO
	if drawn.size.x <= frame.size.x:
		nudge.x = maxf(frame.position.x - drawn.position.x, 0.0) \
			+ minf(frame.end.x - drawn.end.x, 0.0)
	else:
		nudge.x = frame.position.x + (frame.size.x - drawn.size.x) * 0.5 - drawn.position.x
	if drawn.size.y <= frame.size.y:
		nudge.y = maxf(frame.position.y - drawn.position.y, 0.0) \
			+ minf(frame.end.y - drawn.end.y, 0.0)
	else:
		nudge.y = frame.position.y + (frame.size.y - drawn.size.y) * 0.5 - drawn.position.y
	return {"scale": scale, "origin": anchored + nudge}


## The strip down the right the priority bars live in, and **only on the page
## that has bars**.
##
## It was reserved everywhere so the court would not jump between phases. The net
## anchor does that job properly now, and reserving it everywhere had a cost the
## attack page could not pay: the far court is where an attack lands, the far
## court is on the right in every view, and eighteen percent of the width taken
## out of the right meant the floor being aimed at was the floor you could not
## see. The bars are a block control -- "how much do we prioritise the line" -- so
## they take their strip on the block page and give it back on the other two.
## The slab of world in frame: the view's width and height, the phase's depth.
##
## Asked for in one place because it was read in four and two of them disagreed.
## The frame was fitted to the phase's depth while the court was *drawn* from the
## view's, so the plan view laid a near endline three metres past the edge of the
## sheet -- a court that runs off its own page, which is the same class of defect
## as a net that is two different heights.
func _world_box() -> Array:
	if focus_kind != "" and focus_index >= 0:
		var held := _focus_box()
		if not held.is_empty():
			return held
	var box: Array = VIEW_BOX.get(view, VIEW_BOX[VIEW_THREE_QUARTER])
	var low: Vector3 = box[0]
	var high: Vector3 = box[1]
	var span: Vector2 = PHASE_DEPTH.get(phase, Vector2(low.y, high.y))
	return [Vector3(low.x, span.x, low.z), Vector3(high.x, span.y, high.z)]


## The strip down the right, which every phase has now.
##
## It used to collapse to a zero-width rect on anything but Block, because the
## only thing it ever held was the block page's priority bars. What it holds now
## is the instruction for whichever voli you are holding, and that is a question
## every phase has an answer to.
func _rail_rect() -> Rect2:
	return Rect2(
		size.x * 0.795, size.y * (HEAD_SHARE + 0.10),
		size.x * 0.175, size.y * (1.0 - HEAD_SHARE - FOOT_SHARE - 0.18)
	)


## The court on the floor plane, drawn the same way in every view.
##
## One routine, not three. The sidelines, the endlines, the centre line under the
## tape, the two attack lines and the six rotation zones are the same court seen
## from three places -- what differs is the projection, and that is already one
## function. Drawing them per view is how the plan view ended up showing half a
## court while the three-quarter one showed a strip and neither agreed with the
## net standing on them.
##
## Both halves, always, with the far one lighter. A coach reads a plan by seeing
## where the ball has to end up, and half a court cannot show that -- but the
## half being planned still has to be the one the eye goes to first.
func _draw_court(
	scale: float, origin: Vector2, ink: Color, alpha: float, reveal: float
) -> void:
	var box := _world_box()
	var near: float = minf((box[1] as Vector3).y, COURT_HALF_M)
	var far: float = maxf((box[0] as Vector3).y, -COURT_HALF_M)

	## The centre line, under the tape. Heaviest floor line in the drawing, because
	## it is the one every measurement on this sheet is taken from.
	_marker_line(
		_floor_at(-HALF_WIDTH_M, 0.0, scale, origin),
		_floor_at(HALF_WIDTH_M, 0.0, scale, origin),
		ink, alpha, reveal, 401, MARKER_WIDTH * 0.9
	)
	## Sidelines, running the whole depth the view holds.
	for side: float in [-HALF_WIDTH_M, HALF_WIDTH_M]:
		_marker_line(
			_floor_at(side, far, scale, origin),
			_floor_at(side, near, scale, origin),
			Color(ink, 0.72), alpha, reveal, 405 + int(side), MARKER_WIDTH * 0.7
		)
	## Endlines, but only where the view actually reaches one. Drawing a line at
	## the crop instead would say the court ends there, which is a lie the along-net
	## view in particular cannot afford -- it is cropped at seven metres of an
	## eighteen-metre court.
	for depth: float in [far, near]:
		if absf(absf(depth) - COURT_HALF_M) > 0.05:
			continue
		_marker_line(
			_floor_at(-HALF_WIDTH_M, depth, scale, origin),
			_floor_at(HALF_WIDTH_M, depth, scale, origin),
			Color(ink, 0.72), alpha, reveal, 411 + int(depth), MARKER_WIDTH * 0.7
		)
	## The attack lines, three metres either side.
	for depth: float in [-ATTACK_LINE_M, ATTACK_LINE_M]:
		if depth < far or depth > near:
			continue
		_marker_line(
			_floor_at(-HALF_WIDTH_M, depth, scale, origin),
			_floor_at(HALF_WIDTH_M, depth, scale, origin),
			Color(ink, 0.46 if depth > 0.0 else 0.30), alpha, reveal,
			417 + int(depth), MARKER_WIDTH * 0.5
		)
	## And the two lane divisions that turn the near half into the six zones a
	## rotation is named after. Faint: they are not painted on a real floor, they
	## are the coach's own construction lines, which is exactly what a pencil is for.
	for lane: float in [-1.5, 1.5]:
		_marker_line(
			_floor_at(lane, 0.0, scale, origin),
			_floor_at(lane, minf(near, COURT_HALF_M), scale, origin),
			Color(ink, 0.22), alpha, reveal, 423 + int(lane * 2.0), MARKER_WIDTH * 0.4
		)


## The net, in metres, standing on the floor the court routine just drew.
##
## A net is 2.43 m to the top of the tape and one metre deep, so the mesh hangs
## between 1.43 and 2.33 and the tape occupies the last hundred millimetres. All
## three of those numbers used to be shares of a span, which is why the same net
## could be two different heights in two views of one court.
func _draw_net(
	scale: float, origin: Vector2, ink: Color, alpha: float, reveal: float
) -> void:
	var mesh_low: float = NET_HEIGHT_M - 1.0
	var tape_low: float = NET_HEIGHT_M - 0.10

	var to := func(along: float, height: float) -> Vector2:
		return _project(Vector3(along, 0.0, height), scale, origin)

	## A net tape is a folded band with a cable through it, so it draws as **two**
	## lines a few millimetres apart with the cable's sag between them -- not as one
	## heavy stroke. That doubling is most of what turns a diagram of a net into a
	## drawing of one.
	_marker_line(
		to.call(-HALF_WIDTH_M, NET_HEIGHT_M), to.call(HALF_WIDTH_M, NET_HEIGHT_M),
		ink, alpha, reveal, 11, MARKER_WIDTH * 1.4
	)
	_marker_line(
		to.call(-HALF_WIDTH_M, tape_low), to.call(HALF_WIDTH_M, tape_low),
		ink, alpha, reveal, 12, MARKER_WIDTH * 1.0
	)
	## The cable sags between the posts. Straight, a net reads as a fence. Six
	## centimetres, which is about what a tensioned net actually gives.
	var sag := PackedVector2Array()
	for step in range(13):
		var t := float(step) / 12.0
		var along := lerpf(-HALF_WIDTH_M, HALF_WIDTH_M, t)
		sag.append(to.call(along, NET_HEIGHT_M - 0.05 - sin(t * PI) * 0.06))
	_marker_stroke(sag, Color(ink, 0.55), alpha, reveal, 15, MARKER_WIDTH * 0.5, false)
	_marker_line(
		to.call(-HALF_WIDTH_M, mesh_low), to.call(HALF_WIDTH_M, mesh_low),
		ink, alpha, reveal, 23, MARKER_WIDTH * 1.1
	)

	## The mesh, hung from the sagging cable rather than from a straight line, so
	## the squares stretch at the posts and slacken in the middle the way they do.
	var columns := 15
	for index in range(columns + 1):
		var t := float(index) / float(columns)
		var along := lerpf(-HALF_WIDTH_M, HALF_WIDTH_M, t)
		_marker_line(
			to.call(along, tape_low - sin(t * PI) * 0.06), to.call(along, mesh_low),
			Color(ink, 0.36), alpha, reveal, 40 + index, MARKER_WIDTH * 0.5
		)
	for index in range(1, 4):
		var height := lerpf(mesh_low, tape_low, float(index) / 4.0)
		_marker_line(
			to.call(-HALF_WIDTH_M, height), to.call(HALF_WIDTH_M, height),
			Color(ink, 0.30), alpha, reveal, 60 + index, MARKER_WIDTH * 0.45
		)

	## The posts, half a metre outside the sideline where they belong, and the only
	## strictly vertical reference in a drawing whose every other line is skewed.
	for entry: Array in [[-1.0, 71], [1.0, 79]]:
		var side: float = entry[0]
		var salt: int = entry[1]
		var at: float = side * (HALF_WIDTH_M + 0.5)
		var foot := _project(Vector3(at, 0.0, 0.0), scale, origin)
		var crown := _project(Vector3(at, 0.0, NET_HEIGHT_M + 0.25), scale, origin)
		_marker_line(foot, crown, ink, alpha, reveal, salt, MARKER_WIDTH * 1.2)
		## The padded sleeve over the bottom two metres, drawn as a ladder of short
		## rules across the post rather than as a hatched panel. Hatching a shape ten
		## pixels wide and sixty tall does not read as padding; it reads as a mistake,
		## which is what it looked like when the rect finally had a positive height --
		## the previous version's was negative, so `_hatch` returned early and nobody
		## noticed the fill had never been drawn at all.
		for rung in range(5):
			var mark := _project(
				Vector3(at, 0.0, lerpf(0.10, 2.0, float(rung) / 4.0)), scale, origin
			)
			_marker_line(
				mark + Vector2(-4.0, 0.0), mark + Vector2(4.0, 0.0),
				Color(ink, 0.34 if rung > 0 and rung < 4 else 0.62), alpha, reveal,
				salt + 1 + rung, MARKER_WIDTH * 0.5
			)
		## And the base plate, which is what says the post is standing on the floor
		## rather than growing out of it.
		_marker_ellipse(
			foot, Vector2(0.30 * scale, 0.30 * scale * maxf(sin(_tilt()), 0.10)),
			Color(ink, 0.34), alpha, reveal, salt + 9
		)

	## The antennae, in red, standing on the sideline. Eighty centimetres of them
	## clears the tape, which is the rule and also what makes them read as antennae
	## rather than as two more posts.
	for entry: Array in [[-HALF_WIDTH_M, 91], [HALF_WIDTH_M, 97]]:
		var at: float = entry[0]
		var salt: int = entry[1]
		_marker_line(
			_project(Vector3(at, 0.0, NET_HEIGHT_M + 0.80), scale, origin),
			_project(Vector3(at, 0.0, mesh_low), scale, origin),
			MARKER_RED, alpha, reveal, salt, MARKER_WIDTH * 1.3
		)
		for band in range(1, 5):
			var height := lerpf(mesh_low, NET_HEIGHT_M + 0.80, float(band) / 5.0)
			var mark := _project(Vector3(at, 0.0, height), scale, origin)
			_marker_line(
				mark + Vector2(-3.0, 0.0), mark + Vector2(3.0, 0.0),
				Color(MARKER_RED, 0.5), alpha, reveal, salt + band, MARKER_WIDTH * 0.7
			)


## A voli on the floor: the shadow they cast, then the sticker over it.
##
## `ground` is where they *stand*, in metres, and nothing here decides how big
## they are -- `_draw_sticker` reads that off the bake. That is the fix for a
## blocker who came out roughly four metres tall in the plan view: the size was a
## share of the panel, so shrinking the court grew the voli.
func _draw_voli(
	key: String, along: float, depth: float, scale: float, origin: Vector2,
	ink: Color, alpha: float, reveal: float, salt: int
) -> bool:
	var ground := _floor_at(along, depth, scale, origin)
	## The shadow, drawn *into* the drawing rather than under the sticker: the
	## sticker's own drop shadow says it is a sticker, this one says the voli is
	## standing somewhere. A third of a metre across, so it is a body's footprint
	## and not a puddle.
	##
	## **Projected, not thrown.** It used `_marker_ellipse`, whose whole job is that
	## "a hand-thrown circle is never round and never axis-aligned" -- it tilts by
	## up to fourteen degrees and squashes by up to eight percent, both keyed off the
	## salt. Right for a circle somebody drew round the thing they mean; wrong for a
	## shadow, which is a disc on the floor seen from one camera, so two of them at
	## the same view angle *must* be the same shape. They visibly were not.
	##
	## A real disc through the same projection instead: same shape for everyone,
	## correct for the view, and it changes when the camera does because it is the
	## floor plane rather than a number.
	var disc := PackedVector2Array()
	for step in range(25):
		var turn := TAU * float(step) / 24.0
		disc.append(_floor_at(
			along + cos(turn) * 0.34, depth + sin(turn) * 0.34, scale, origin
		))
	draw_colored_polygon(disc, Color(ink, 0.16))
	draw_polyline(disc, Color(ink, 0.38), 1.1, true)
	if view == VIEW_TOP_DOWN:
		return _draw_token(key, ground)
	return _draw_sticker(key, ground, scale)


## A face on the plan, at a size a face can be read at.
##
## The one place on the sheet where a voli is **not** drawn to scale, and the
## exception is deliberate. Everything else is metres because the sheet is a
## picture of a court; a token is not a picture of a body, it is a label saying
## which voli is standing here. Drawn to scale it would be a nine-pixel scalp,
## which labels nobody.
const TOKEN_DIAMETER: float = 30.0


func _draw_token(key: String, ground: Vector2) -> bool:
	if _stickers == null:
		return false
	var built: UIVoliSticker.Sticker = _stickers.sticker(key)
	if built == null or built.texture == null:
		return false
	var box := Vector2(TOKEN_DIAMETER * built.aspect, TOKEN_DIAMETER)
	## Sitting on the ground mark rather than centred on it, the way a counter on a
	## board sits on its square -- so the point on the floor stays visible and the
	## face does not cover the thing it is labelling.
	var at := ground - Vector2(box.x * 0.5, box.y + 2.0)
	draw_texture_rect(built.texture, Rect2(at, box), false)
	draw_rect(Rect2(at, box), Color(_ink(), 0.55), false, 1.2)
	return true


## The tilt of the current view, in radians above the floor.
func _tilt() -> float:
	return deg_to_rad(float((VIEW_ANGLES.get(view, Vector2(-38.0, 32.0)) as Vector2).y))


## Whoever is working the selected pin, standing on it.
##
## This came off with the drill's dashed arrow and should not have: the arrow was
## a guess about what a coach writes, and a body standing at a pin is not a mark
## at all -- it is the same thing the block page draws two of.
func _draw_attacker(
	scale: float, origin: Vector2, ink: Color, alpha: float, reveal: float
) -> void:
	if drill_who.is_empty():
		return
	var zone: Dictionary = NET_ZONES[clampi(drill_zone, 0, NET_ZONES.size() - 1)]
	_draw_voli(
		_sticker_key(drill_who, view, "Attack"),
		float(zone["along"]), float(zone["depth"]), scale, origin,
		ink, alpha, reveal, 671
	)


## The wall at the net, from whichever side the view is standing on.
##
## Two blockers, 0.35 m off the tape, 0.9 m apart -- the distances they actually
## take up, so the seam between them is the seam a real pair leaves rather than a
## gap somebody drew. They fall back to a drawn arch while the bake is still
## running, because a body that pops in is better than a hole.
func _draw_blockers(
	scale: float, origin: Vector2, ink: Color, alpha: float, reveal: float
) -> void:
	var roster := _squad()
	var wall: Array = [
		[-1.15, str((roster[0] as Dictionary).get("key", "tall"))],
		[-0.25, str((roster[mini(1, roster.size() - 1)] as Dictionary).get("key", "wing"))],
	]
	for index in range(wall.size()):
		var along: float = wall[index][0]
		var key := _sticker_key(str(wall[index][1]), view, "Block")
		var salt := 90 + index * 29
		## Numbered, over their own head. Which blocker is which is the one thing a
		## picture of a wall cannot say by itself -- two bodies at a net are a wall,
		## and "the one on the left takes the seam" needs a name for the one on the
		## left.
		_marker_text(
			"%d" % (index + 1),
			_project(Vector3(along, 0.35, 3.55), scale, origin) + Vector2(-5.0, 0.0),
			16, MARKER_RED, alpha, reveal
		)
		if _draw_voli(key, along, 0.35, scale, origin, ink, alpha, reveal, salt):
			continue
		## The fallback figure, at the reach the pose would have had.
		var head := _project(Vector3(along, 0.35, 2.80), scale, origin)
		_marker_circle(head, 13.0, ink, alpha, reveal, salt)
		_marker_line(
			head + Vector2(0.0, 12.0),
			_project(Vector3(along, 0.35, 1.40), scale, origin),
			ink, alpha, reveal, salt + 3, MARKER_WIDTH * 1.3
		)



## What an instruction looks like on the floor.
##
## Every behaviour is a **dashed arrow**, because a dashed line is what somebody
## draws for a thing that has not happened yet -- the solid marks on this sheet
## are where bodies are, and an intention is not a body. What differs between
## them is the *shape*, and the shape is the meaning rather than a decoration:
##
## - **line** runs straight over the net on the voli's own axis. "Straight
##   forward" from wherever they are standing, so a voli in zone 4 and a voli in
##   zone 2 get different lines on the page and the same instruction.
## - **cross** cuts to the opposite far corner, so its direction comes off the
##   hitter's own x. The one shot whose drawing genuinely depends on where they
##   stand, which is why it cannot be a fixed angle.
## - **tool** is short, flat and level -- no rise at all. It is a ball struck
##   *off the block* rather than over it, and a flat mark is the only one of these
##   that says the ball never went up.
## - **feint** is a low, short arc that lands just past the net.
## - **roll** is the same arc drawn longer and higher, landing deep.
##
## Block's four are marks at the net rather than flights: where the hands close
## and what the wall is trying to do.
const ARROW_STEPS: int = 14


func _draw_behaviour_arrow(
	behaviour: String, from_court: Vector2, scale: float, origin: Vector2,
	alpha: float, reveal: float, salt: int
) -> void:
	## Off the hand rather than off the feet: a shot leaves a body at the height
	## it was struck, and an arrow starting between the shoes reads as a pass.
	var lift := 2.5 if phase == "Attack" else 2.3
	var start := Vector3(from_court.x, from_court.y, lift)
	var over := -1.0 if from_court.y > 0.0 else 1.0
	var points: Array[Vector3] = []
	match behaviour:
		"spike line":
			points = [start, Vector3(from_court.x, from_court.y + over * 7.0, 0.0)]
		"spike cross":
			## Toward the far corner on the other side of the court from the
			## hitter. A hitter on the middle gets the shorter of the two, which
			## is correct: a middle has less angle than a pin.
			var away := -signf(from_court.x) if absf(from_court.x) > 0.2 else 1.0
			points = [
				start,
				Vector3(away * HALF_WIDTH_M * 0.82, from_court.y + over * 6.0, 0.0),
			]
		"tool":
			## Level, and short. Struck off the block and out, so it never rises
			## and it does not travel far before it leaves the court.
			var out := signf(from_court.x) if absf(from_court.x) > 0.2 else 1.0
			points = [
				start,
				Vector3(from_court.x + out * 3.2, from_court.y + over * 1.6, lift),
			]
		"feint", "cover the tip":
			points = _arc(start, Vector3(
				from_court.x * 0.4, from_court.y + over * 2.6, 0.0
			), 0.9)
		"roll", "chase":
			points = _arc(start, Vector3(
				from_court.x * 0.3, from_court.y + over * 7.4, 0.0
			), 2.4)
		"close line":
			points = [start, Vector3(
				from_court.x + signf(from_court.x) * 0.7, from_court.y + over * 0.5,
				lift + 0.5
			)]
		"close cross":
			points = [start, Vector3(
				from_court.x - signf(from_court.x) * 0.9, from_court.y + over * 0.5,
				lift + 0.5
			)]
		"soft block":
			points = _arc(start, Vector3(
				from_court.x, from_court.y - over * 2.4, 0.0
			), 1.1)
		"kill block":
			points = [start, Vector3(
				from_court.x, from_court.y + over * 2.2, 0.0
			)]
		"dig line":
			points = _arc(start, Vector3(from_court.x * 0.2, 2.6, 0.0), 1.6)
		"dig cross":
			points = _arc(start, Vector3(-from_court.x * 0.5, 2.6, 0.0), 1.6)
		_:
			return
	_dashed_flight(points, scale, origin, alpha, reveal, salt)


## A lobbed path from one point to another, `rise` metres over the straight line
## at its highest. Enough points that the dashes follow the curve rather than
## cutting it.
func _arc(from_point: Vector3, to_point: Vector3, rise: float) -> Array[Vector3]:
	var path: Array[Vector3] = []
	for step in range(ARROW_STEPS + 1):
		var t := float(step) / float(ARROW_STEPS)
		var point := from_point.lerp(to_point, t)
		point.z += sin(t * PI) * rise
		path.append(point)
	return path


## Dashes along a path, with a head on the end.
func _dashed_flight(
	points: Array[Vector3], scale: float, origin: Vector2, alpha: float,
	reveal: float, salt: int
) -> void:
	if points.size() < 2:
		return
	var flat: Array[Vector2] = []
	for point in points:
		flat.append(_project(point, scale, origin))
	## Two-thirds mark, one-third gap, walked along the whole path rather than
	## per segment -- dashes reset at every segment boundary look like a chain of
	## short lines, which is what a straight arrow made of two points would give.
	for index in range(flat.size() - 1):
		if index % 3 == 2 and flat.size() > 3:
			continue
		var a: Vector2 = flat[index]
		var b: Vector2 = flat[index + 1]
		if flat.size() == 2:
			## A two-point path has to be dashed by subdivision instead.
			for piece in range(ARROW_STEPS):
				if piece % 3 == 2:
					continue
				_marker_line(
					a.lerp(b, float(piece) / float(ARROW_STEPS)),
					a.lerp(b, float(piece + 1) / float(ARROW_STEPS)),
					MARKER_RED, alpha * 0.85, reveal, salt + piece, MARKER_WIDTH
				)
			break
		_marker_line(a, b, MARKER_RED, alpha * 0.85, reveal, salt + index, MARKER_WIDTH)
	var tip: Vector2 = flat[flat.size() - 1]
	var before: Vector2 = flat[maxi(flat.size() - 2, 0)]
	var heading := (tip - before).normalized()
	if heading == Vector2.ZERO:
		return
	var wing := heading.orthogonal() * 5.0
	_marker_line(
		tip, tip - heading * 11.0 + wing, MARKER_RED, alpha, reveal,
		salt + 91, MARKER_WIDTH
	)
	_marker_line(
		tip, tip - heading * 11.0 - wing, MARKER_RED, alpha, reveal,
		salt + 92, MARKER_WIDTH
	)


## Who is held, where they are, and what they have been told.
##
## Drawn rather than built from Controls, like everything else on this sheet: a
## page whose argument is that the drawing is the interface does not grow a panel
## of buttons down one side. The option rows are hit-tested from the rects they
## were drawn into, the same discipline the shadow handles use -- a control cannot
## be somewhere its mark is not.
const INSTRUCTION_ROW: float = 26.0


func _draw_instruction(
	area: Rect2, ink: Color, alpha: float, reveal: float
) -> void:
	_behaviour_rows.clear()
	if area.size.x < 8.0:
		return
	_marker_text(
		"SELECTED", area.position + Vector2(0.0, -8.0), 15, ink, alpha, reveal
	)
	if selected_slot < 0 or not placements.has(selected_slot):
		_marker_text(
			"nobody — take hold of a voli",
			area.position + Vector2(0.0, 18.0), 13, ink, alpha * 0.6, reveal
		)
		return

	var held: Dictionary = placements[selected_slot]
	var who := str(held.get("who", ""))
	var spot: Vector2 = held.get("at", Vector2.ZERO)
	_marker_text(
		_display_name_for(who), area.position + Vector2(0.0, 20.0),
		16, ink, alpha, reveal
	)
	_marker_text(
		_where_is(spot), area.position + Vector2(0.0, 38.0),
		13, MARKER_RED, alpha, reveal
	)

	var options: Array = BEHAVIOURS.get(phase, [])
	if options.is_empty():
		return
	_marker_text(
		"BEHAVIOUR", area.position + Vector2(0.0, 68.0), 15, ink, alpha, reveal
	)
	var chosen := behaviour_of(selected_slot)
	for index in range(options.size()):
		var label := str(options[index])
		var row := Rect2(
			area.position + Vector2(-4.0, 78.0 + float(index) * INSTRUCTION_ROW),
			Vector2(area.size.x + 8.0, INSTRUCTION_ROW - 3.0)
		)
		_behaviour_rows.append({"rect": row, "behaviour": label})
		var picked := label == chosen
		if picked:
			## The chosen one is struck through with the marker rather than boxed.
			## A box is a control; a line through the words is what somebody with
			## a pen does to the option they have settled on.
			_marker_line(
				row.position + Vector2(2.0, row.size.y * 0.55),
				row.position + Vector2(row.size.x - 6.0, row.size.y * 0.55),
				MARKER_RED, alpha * 0.55, reveal, 300 + index * 11, MARKER_WIDTH
			)
		_marker_text(
			label, row.position + Vector2(4.0, row.size.y * 0.72),
			14, MARKER_RED if picked else ink,
			alpha if picked else alpha * 0.78, reveal
		)


## The priority bars, kept because the block page may still want them somewhere.
## Black for the level, red for the one being pointed at, and a hand-ruled
## baseline under all four.
func _draw_zone_bars(area: Rect2, alpha: float, reveal: float) -> void:
	var ink := _ink()
	_marker_text(
		"PRIORITY", area.position + Vector2(0.0, -8.0), 15, ink, alpha, reveal
	)
	var slot := area.size.x / float(ZONE_COUNT)
	var bar_width := slot * 0.66
	var baseline := area.position.y + area.size.y
	for index in range(ZONE_COUNT):
		var centre := area.position.x + slot * (float(index) + 0.5)
		var level := zone_priorities[index]
		var height := area.size.y * (float(level) / float(ZONE_MAX_PRIORITY))
		var color := MARKER_RED if index == _hovered_zone else ink
		## Filled by hatching rather than by a solid rectangle. A marker fills a
		## shape by going back and forth across it, and the overlaps at the turns
		## are visible -- which is exactly what the translucent ink gives for free.
		## Shaded with the **side** of the tip, not hatched with the point.
		##
		## Hatching was the marker's answer -- a chisel fills a box by going back
		## and forth and the turns show. A pencil laid over does something else
		## entirely: a few broad diagonal passes, each soft, overlapping into a
		## tone. Diagonal because a hand shading a tall box moves across it rather
		## than along it, and the diagonal is what stops the fill reading as more
		## rungs on a ladder.
		var passes := maxi(int(height / SHADE_STEP), 1)
		for step in range(passes):
			var y := baseline - float(step) * SHADE_STEP - SHADE_WIDTH * 0.4
			if y < baseline - height:
				break
			## Each pass leans, because a hand shading a box moves across it at an
			## angle rather than straight along. The lean is what stops the fill
			## reading as more rungs on a ladder.
			_marker_stroke(
				PackedVector2Array([
					Vector2(centre - bar_width * 0.5, y + 3.0),
					Vector2(centre + bar_width * 0.5, y - 3.0),
				]),
				Color(color, SHADE_ALPHA), alpha, reveal,
				200 + index * 17 + step, SHADE_WIDTH, false
			)
		## The outline of the box it was filled into, drawn after, so it reads as
		## the shape rather than as the edge of the hatching.
		if level > 0:
			_marker_rect(
				Rect2(
					centre - bar_width * 0.5, baseline - height,
					bar_width, height
				), color, alpha * 0.85, reveal, 300 + index
			)
		_marker_text(
			ZONE_LABELS[index], Vector2(centre - bar_width * 0.5, baseline + 15.0),
			12, color, alpha, reveal
		)
	_marker_line(
		Vector2(area.position.x - 6.0, baseline),
		Vector2(area.position.x + area.size.x + 6.0, baseline),
		ink, alpha, reveal, 399, 13
	)



# --------------------------------------------------------------------------
# The drill: where the swing comes from, where it goes, and what shot it is
# --------------------------------------------------------------------------

## A net zone is a **volume**, not a mark on the tape.
##
## It was a circle drawn at the tape's height, which is a symbol for a place
## rather than the place, and from straight above it landed on the tape itself --
## where nothing happens. What a net zone actually is depends on what you are
## looking at it for, and the three views want three different slabs of the same
## air:
##
## | view | the zone is | because |
## |---|---|---|
## | three quarter | the panel **above** the tape | that is where a ball crosses |
## | along the net | a slab **around** the tape | the question here is depth off it |
## | top down | the patch of floor **ahead** of it | from above, height is nothing |
##
## Returned as four world corners in order, so the caller can outline it, fill it
## or hit-test it without knowing which of the three it got.
func _net_zone_quad(index: int) -> PackedVector3Array:
	var zone: Dictionary = NET_ZONES[clampi(index, 0, NET_ZONES.size() - 1)]
	var mid := float(zone["along"])
	var half := 1.5
	var depth := float(zone["depth"])
	match view:
		VIEW_TOP_DOWN:
			## A band just past the tape, not a slab. Three and a half metres deep it
			## covered the far court's front row entirely and the two grids fought --
			## a net zone and a floor zone are different questions and must not be the
			## same rectangle.
			return PackedVector3Array([
				Vector3(mid - half, depth - 0.1, 0.0),
				Vector3(mid + half, depth - 0.1, 0.0),
				Vector3(mid + half, depth - 1.5, 0.0),
				Vector3(mid - half, depth - 1.5, 0.0),
			])
		VIEW_ALONG_NET:
			return PackedVector3Array([
				Vector3(mid, depth + 1.3, NET_HEIGHT_M - 0.1),
				Vector3(mid, depth - 1.3, NET_HEIGHT_M - 0.1),
				Vector3(mid, depth - 1.3, NET_HEIGHT_M + 1.3),
				Vector3(mid, depth + 1.3, NET_HEIGHT_M + 1.3),
			])
		_:
			return PackedVector3Array([
				Vector3(mid - half, depth, NET_HEIGHT_M - 0.1),
				Vector3(mid + half, depth, NET_HEIGHT_M - 0.1),
				Vector3(mid + half, depth, NET_HEIGHT_M + 1.3),
				Vector3(mid - half, depth, NET_HEIGHT_M + 1.3),
			])


## The six zones of a half court, in metres, as (along, depth) rectangles.
##
## Which half depends on the phase, and that is the whole of what the phase means
## on the floor: attack and block are opinions about **their** floor -- where the
## ball is going, where it is coming from -- and floor defence is an opinion about
## **yours**. Numbered the way a coach numbers them, so a zone is something you can
## say out loud.
func _floor_zones() -> Array[Dictionary]:
	var side := 1.0 if phase == "Floor" else -1.0
	var out: Array[Dictionary] = []
	var labels := ["4", "3", "2", "5", "6", "1"]
	for row in range(2):
		var near_edge := 0.0 if row == 0 else ATTACK_LINE_M
		var far_edge := ATTACK_LINE_M if row == 0 else COURT_HALF_M
		for column in range(3):
			var left := -HALF_WIDTH_M + float(column) * 3.0
			out.append({
				"label": labels[row * 3 + column],
				"low": Vector2(left, minf(near_edge, far_edge) * side),
				"high": Vector2(left + 3.0, maxf(near_edge, far_edge) * side),
			})
	return out


func _floor_zone_quad(index: int) -> PackedVector3Array:
	var zones := _floor_zones()
	var zone: Dictionary = zones[clampi(index, 0, zones.size() - 1)]
	var low: Vector2 = zone["low"]
	var high: Vector2 = zone["high"]
	return PackedVector3Array([
		Vector3(low.x, low.y, 0.0), Vector3(high.x, low.y, 0.0),
		Vector3(high.x, high.y, 0.0), Vector3(low.x, high.y, 0.0),
	])


## Whether any of a zone's footprint falls inside the slab currently in frame.
func _overlaps_box(quad: PackedVector3Array, box: Array) -> bool:
	if box.size() < 2:
		return true
	var low: Vector3 = box[0]
	var high: Vector3 = box[1]
	for point in quad:
		if point.x >= low.x - 0.2 and point.x <= high.x + 0.2 \
				and point.y >= low.y - 0.2 and point.y <= high.y + 0.2:
			return true
	return false


func _flatten(quad: PackedVector3Array, scale: float, origin: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for point in quad:
		out.append(_project(point, scale, origin))
	return out


## Zones, drawn as the regions they are: outlined always, shaded when pointed at.
##
## Shading only the hovered one is the point -- six shaded zones is a heat map and
## says nothing, one shaded zone says *this* one. The outline stays on every zone
## so there is something to aim at, and it is a printed hairline rather than a
## pencil stroke because a zone is a division of the court, not a mark somebody
## made on it.
func _draw_zone_regions(
	scale: float, origin: Vector2, ink: Color, alpha: float, reveal: float
) -> void:
	if reveal < 0.99:
		return
	var box := _world_box()
	var floor_zones := _floor_zones()
	for index in range(floor_zones.size()):
		## Zones wholly outside the frame are skipped rather than clipped. Drawing
		## them anyway is what stopped a focused view reading as a close-up: the
		## twelve rectangles still spanned the whole court and the crop looked like a
		## slightly larger drawing of the same thing.
		if not _overlaps_box(_floor_zone_quad(index), box):
			continue
		var quad := _flatten(_floor_zone_quad(index), scale, origin)
		var lit := index == _hovered_floor
		var held := focus_kind == "floor" and index == focus_index
		if lit or held:
			draw_colored_polygon(quad, Color(MARKER_RED if held else ink, 0.13))
		## An unpointed-at zone is a **division**, not a box: a hairline so faint it
		## reads as the court being sectioned rather than as twelve rectangles drawn
		## on top of it. Everything the eye is meant to find is the one that lit up.
		draw_polyline(
			quad + PackedVector2Array([quad[0]]),
			Color(ink, 0.34 if (lit or held) else 0.09), 1.0, true
		)
		var zone: Dictionary = floor_zones[index]
		var middle: Vector2 = (Vector2(zone["low"]) + Vector2(zone["high"])) * 0.5
		_marker_text(
			str(zone["label"]),
			_floor_at(middle.x, middle.y, scale, origin) + Vector2(-5.0, 6.0),
			15, Color(ink, 0.60 if (lit or held) else 0.22), alpha, reveal
		)

	for index in range(NET_ZONES.size()):
		if not _overlaps_box(_net_zone_quad(index), box):
			continue
		var quad := _flatten(_net_zone_quad(index), scale, origin)
		var lit := index == _hovered_net
		var held := focus_kind == "net" and index == focus_index
		var chosen := index == drill_zone
		if lit or held:
			draw_colored_polygon(quad, Color(MARKER_RED, 0.15))
		var edge := MARKER_RED if (chosen or lit or held) else Color(ink, 0.30)
		var weight := 0.55 if chosen else (0.70 if (lit or held) else 0.16)
		draw_polyline(
			quad + PackedVector2Array([quad[0]]),
			Color(edge, weight), 1.1, true
		)
		var zone: Dictionary = NET_ZONES[index]
		_marker_text(
			str(zone["label"]),
			_project(quad_label_anchor(index), scale, origin) + Vector2(-5.0, -6.0),
			14, Color(edge, maxf(weight, 0.45)), alpha, reveal
		)


## Where a net zone writes its own name: the top edge of its volume, so the label
## is never inside the region it names and never on the floor numeral underneath.
func quad_label_anchor(index: int) -> Vector3:
	var quad := _net_zone_quad(index)
	return (quad[2] + quad[3]) * 0.5


## What the cursor is over, as a kind and an index. Net first: its volume sits
## above the floor's, so where the two overlap on the page the nearer one wins,
## which is what a viewer expects of anything drawn in front.
func _zone_under(at: Vector2, scale: float, origin: Vector2) -> Array:
	for index in range(NET_ZONES.size()):
		if Geometry2D.is_point_in_polygon(at, _flatten(_net_zone_quad(index), scale, origin)):
			return ["net", index]
	var floor_zones := _floor_zones()
	for index in range(floor_zones.size()):
		if Geometry2D.is_point_in_polygon(at, _flatten(_floor_zone_quad(index), scale, origin)):
			return ["floor", index]
	return ["", -1]


## Hold a zone, and the sheet moves in on it.
##
## The alternative was a zoom control, and a zoom control on a page whose whole
## argument is that the drawing is the interface would be the one thing on it you
## operate from outside the drawing. Clicking the zone you are already pointing at
## is the shortest way to say "this bit", and clicking it again is the shortest
## way to take it back.
var focus_kind: String = ""
var focus_index: int = -1

var _hovered_net: int = -1
var _hovered_floor: int = -1


func _focus_box() -> Array:
	var quad := _net_zone_quad(focus_index) if focus_kind == "net" \
		else _floor_zone_quad(focus_index)
	if quad.is_empty():
		return []
	var low := Vector3(INF, INF, 0.0)
	var high := Vector3(-INF, -INF, 0.0)
	for point in quad:
		low = Vector3(minf(low.x, point.x), minf(low.y, point.y), 0.0)
		high = Vector3(maxf(high.x, point.x), maxf(high.y, point.y), 0.0)
	## Padded, because a zone drawn edge to edge has nothing around it to be a zone
	## *of*. Two and a half metres is about a body either side, which is enough
	## court for the crop to still read as a court.
	var pad := 2.5
	return [
		Vector3(low.x - pad, low.y - pad, 0.0),
		Vector3(high.x + pad, high.y + pad, NET_HEIGHT_M + 1.4),
	]


# --------------------------------------------------------------------------
# The marker itself
# --------------------------------------------------------------------------

## One stroke, chisel-tipped and translucent.
##
## `reveal` is how much of the board the squeegee has uncovered; a stroke past
## that point has not been drawn yet, and one that straddles it is drawn as far
## as the squeegee has got. That is what makes the new layout appear *behind* the
## wipe rather than all at once when it finishes.
func _marker_line(
	from: Vector2, to: Vector2, color: Color, alpha: float,
	reveal: float, salt: int, width: float = MARKER_WIDTH
) -> void:
	_marker_stroke(
		_wandering_path(from, to, salt), color, alpha, reveal, salt, width, false
	)


## A run the hand did not lift for.
##
## The first draft drew every stroke as a chain of short `draw_line` calls with
## an independent offset per segment. Two things came out of that and both were
## wrong. The joins between segments overlap, and since the ink is translucent
## *every join darkened* -- so a plain straight line was a row of dark ticks, and
## the overlap that is supposed to mean "two strokes crossed here" meant nothing
## because it was everywhere. And an independent offset per segment is white
## noise, which reads as a shaky hand rather than a fast one.
##
## So a stroke is now one polygon: a ribbon built along a centreline, filled in a
## single `draw_colored_polygon`. It cannot overlap itself, so a crossing is the
## only thing that darkens. The centreline wanders on two slow sine components
## rather than per-point noise, which bends the run instead of shaking it, and
## the width drifts slowly along it on a third -- the hand leaning in and easing
## off over a run it never lifted from.
func _wandering_path(from: Vector2, to: Vector2, salt: int) -> PackedVector2Array:
	var path := PackedVector2Array()
	var length := from.distance_to(to)
	if length < 0.001:
		return path
	var normal := (to - from).orthogonal().normalized()
	var steps := clampi(int(length / MARKER_SEGMENT), 3, 48)
	## Two components, seeded: one long bow across the whole run and one shorter
	## correction. A hand drawing a straight line produces exactly this -- it
	## leaves true, notices, and comes back.
	var phase_a := _unit(salt * 31 + 3) * TAU
	var phase_b := _unit(salt * 31 + 9) * TAU
	var amplitude := MARKER_WANDER * (0.55 + _unit(salt * 31 + 17) * 0.75)
	for step in range(steps + 1):
		var t := float(step) / float(steps)
		var bow := sin(phase_a + t * PI) * 0.75 + sin(phase_b + t * TAU * 1.7) * 0.25
		## Both ends settle onto true: a hand starts and finishes where it meant
		## to even when the middle of the run drifts.
		path.append(from.lerp(to, t) + normal * bow * amplitude * sin(t * PI))
	return path


## Fill a centreline as one continuous chisel-tipped ribbon.
##
## Emitted as a quad per segment rather than as one polygon down the whole run.
## The single-polygon form works for an open stroke and silently fails for a
## closed one: left-side-forward plus right-side-backward round a circle is a
## *ring*, which is not a simple polygon, and Godot's triangulator drops it --
## which is why a blocker's head vanished while their arms drew fine.
##
## Adjacent quads share an edge exactly, so the run still does not darken against
## itself; where a path genuinely crosses its own tail, the two quads there do
## overlap and it darkens, which is the lap that says a circle was thrown round
## something in a hurry.
func _marker_stroke(
	path: PackedVector2Array, color: Color, alpha: float, reveal: float,
	salt: int, width: float, _closed: bool
) -> void:
	if alpha <= 0.001 or path.size() < 2:
		return
	var limit := size.x * reveal
	var visible := PackedVector2Array()
	for point in path:
		if point.x > limit:
			break
		visible.append(point)
	if visible.size() < 2:
		return

	## One antialiased polyline per stroke.
	##
	## Strokes were quads -- one `draw_colored_polygon` per segment -- to stop the
	## joins double-drawing and darkening, which they did when each segment was
	## its own `draw_line`. That worked and cost the thing nobody wanted to lose:
	## `draw_colored_polygon` has no antialiasing at all, so every line on the
	## sheet was a hard-edged staircase. At two and a half pixels wide that is
	## most of what the eye sees.
	##
	## `draw_polyline` is one primitive rather than N, so it does not double-draw
	## at its own joins *and* it antialiases. What it cannot do is vary width
	## along its length -- so the width is resolved once per stroke, from the
	## chisel angle against the stroke's own dominant direction. At a pencil's
	## width that variation was never visible along a single run anyway; what
	## reads is the difference *between* strokes, and that survives.
	var heading := visible[visible.size() - 1] - visible[0]
	if heading.length_squared() < 0.000001:
		heading = Vector2.RIGHT
	var pressure := 1.0 + sin(_unit(salt * 47 + 5) * TAU) * 0.14
	var drawn := maxf(_tip_width(heading, width) * pressure, 0.6)
	## The tooth, per stroke rather than per segment. Graphite catches unevenly,
	## and with the width now constant this is the only channel left that says so.
	var grain := lerpf(1.0 - TOOTH_SKIP * 0.5, 1.0, _unit(salt * 31 + 17))
	draw_polyline(
		visible, Color(color, color.a * MARKER_ALPHA * alpha * grain), drawn, true
	)


## A stable 0-1 from the board's seed and a salt. Hand-mixed rather than an rng
## object, because these are read a few thousand times a frame.
func _unit(step: int) -> float:
	var accumulated := (_seed * 2654435761) ^ (step * 40503)
	accumulated = accumulated & 0x7FFFFFFF
	accumulated = accumulated ^ (accumulated >> 13)
	accumulated = (accumulated * 1103515245 + 12345) & 0x7FFFFFFF
	return float(accumulated % 65537) / 65537.0


## The chisel: full width across the tip, `MARKER_MIN_RATIO` of it along.
func _tip_width(direction: Vector2, width: float) -> float:
	if direction.length_squared() < 0.0001:
		return width
	var tip := Vector2.RIGHT.rotated(deg_to_rad(MARKER_ANGLE_DEGREES))
	var across := absf(direction.normalized().cross(tip))
	return width * lerpf(MARKER_MIN_RATIO, 1.0, across)


func _marker_rect(
	rect: Rect2, color: Color, alpha: float, reveal: float, salt: int
) -> void:
	var a := rect.position
	var b := rect.position + Vector2(rect.size.x, 0.0)
	var c := rect.position + rect.size
	var d := rect.position + Vector2(0.0, rect.size.y)
	## Overshot corners. A hand drawing a box does not stop exactly on the
	## corner, and the little crossings at four corners are most of what says
	## somebody drew this quickly.
	_marker_line(a + Vector2(-3.0, 0.0), b + Vector2(4.0, 0.0), color, alpha, reveal, salt)
	_marker_line(b + Vector2(0.0, -3.0), c + Vector2(0.0, 4.0), color, alpha, reveal, salt + 1)
	_marker_line(c + Vector2(3.0, 0.0), d + Vector2(-4.0, 0.0), color, alpha, reveal, salt + 2)
	_marker_line(d + Vector2(0.0, 3.0), a + Vector2(0.0, -4.0), color, alpha, reveal, salt + 3)


func _marker_circle(
	centre: Vector2, radius: float, color: Color, alpha: float, reveal: float, salt: int
) -> void:
	_marker_ellipse(centre, Vector2(radius, radius), color, alpha, reveal, salt)


## One lap of the pen, drawn as a single ribbon.
##
## Was a run of separate chords, which meant fifteen overlapping joins round
## every circle and a ring of dark ticks. The overshoot past its own start is
## kept -- that lap over the beginning is the entire tell of a circle thrown
## round something quickly -- but now it is the one place the shape crosses
## itself, so it is the one place that darkens.
func _marker_ellipse(
	centre: Vector2, radii: Vector2, color: Color, alpha: float,
	reveal: float, salt: int
) -> void:
	var segments := 40
	var start := _unit(salt * 13 + 1) * TAU
	var sweep := TAU + 0.25 + _unit(salt * 13 + 7) * 0.30
	## A hand-thrown circle is never round and never axis-aligned.
	var tilt := (_unit(salt * 13 + 21) - 0.5) * 0.5
	var squash := 0.92 + _unit(salt * 13 + 33) * 0.16
	var path := PackedVector2Array()
	for index in range(segments + 1):
		var angle := start + sweep * float(index) / float(segments)
		var local := Vector2(cos(angle), sin(angle) * squash) * radii
		path.append(centre + local.rotated(tilt))
	_marker_stroke(
		path, color, alpha, reveal, salt, MARKER_WIDTH * 1.4, true
	)


func _marker_arrow(
	from: Vector2, to: Vector2, color: Color, alpha: float, reveal: float, salt: int
) -> void:
	_marker_line(from, to, color, alpha, reveal, salt)
	var back := (from - to).normalized()
	for turn in [0.45, -0.45]:
		_marker_line(
			to, to + back.rotated(turn) * 17.0, color, alpha, reveal,
			salt + int(turn * 100.0), MARKER_WIDTH * 0.85
		)


## Marker writing. The heading face is already a fat rounded display -- which is
## what a chisel tip produces -- so the board writes in it rather than in the
## body face, and tilts it a degree or two off true.
func _marker_text(
	text: String, at: Vector2, font_size: int, color: Color,
	alpha: float, reveal: float
) -> void:
	if alpha <= 0.001 or at.x > size.x * reveal:
		return
	var font := _marker_font()
	if font == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed + int(text.hash() & 0xFFFF)
	draw_set_transform(at, rng.randf_range(-0.028, 0.028))
	## Writing takes a boost over stroke work, because a letterform at marker
	## alpha loses its counters and turns to mush -- but only when it is *live*.
	## Boosting a ghost too left the previous phase's heading legible under the
	## new one, so the board read "BLOCK RECEIVE".
	var written := MARKER_ALPHA * alpha
	if alpha > 0.5:
		written = clampf(written + 0.18, 0.0, 1.0)
	draw_string(
		font, Vector2.ZERO, text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		font_size, Color(color, color.a * written)
	)
	draw_set_transform(Vector2.ZERO, 0.0)


func _marker_font() -> Font:
	## `DisplayHeading` is the Cherry Bomb face -- fat, rounded, no thin strokes
	## anywhere, which is what a chisel tip physically cannot produce either. It
	## was chosen as a display face and happens to be the closest thing in the
	## project to marker writing, so the board borrows it rather than shipping a
	## font for one screen.
	var theme_font := get_theme_font(&"font", &"DisplayHeading")
	if theme_font != null:
		return theme_font
	return get_theme_default_font()


func _board_color() -> Color:
	## Graph paper is a *sheet on the sheet*, so it must not be the same colour as
	## the form it lies on -- two surfaces the same colour are one surface. Squared
	## paper is faintly cooler and very slightly greener than plain stock, which is
	## the whole difference and is enough. In Mikasa the same sheet under a desk
	## lamp: still paper, still lighter than the page around it, nowhere near white.
	return Color(0.955, 0.960, 0.950) if light_mode else Color(0.19, 0.21, 0.22)


func _ink() -> Color:
	## Graphite, which is not black -- it is a warm grey with a slight sheen, and
	## drawn at true black a pencil stops being a pencil. On the dark sheet the
	## roles swap, because a grey pencil on a grey page cannot be read; red stays
	## red in both, which is why it carries the emphasis.
	return Color(0.26, 0.25, 0.27) if light_mode else Color(0.82, 0.84, 0.86)


func _zone_at(at: Vector2) -> int:
	## The same rectangle the bars are drawn in, asked for rather than restated --
	## the two were written out separately and drifted, so a wheel over the bottom
	## of a bar changed nothing.
	var area := _rail_rect()
	if not area.grow(10.0).has_point(at):
		return -1
	var slot := area.size.x / float(ZONE_COUNT)
	return clampi(int((at.x - area.position.x) / slot), 0, ZONE_COUNT - 1)
