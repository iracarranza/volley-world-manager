class_name VolleyballScoutingScreen
extends Control

## The cork board.
##
## ## Why this stopped being a drawer of folders
##
## It was one, briefly, and on a defensible argument: `TITLE_SCREEN.md` said "the
## folders are card", so `MEDIUM_CARD` was built and scouting was put on it. The
## build was fine and the *assignment* was wrong, and the reason is worth keeping
## because it generalises to every other screen on this desk:
##
## > A folder is a **container for one subject**. A board is a **surface where
## > things accumulate and relate to each other**.
##
## Everything scouting is about is the second thing. Connections between volis,
## clubs, agents and regions; reports arriving unasked; a shortlist you compare
## against itself. A drawer can show you exactly one open folder, because that is
## what a drawer is *for* -- so the folder metaphor did not merely fail to help
## here, it structurally forbade the thing the screen exists to do.
##
## The folder went to housing, where there is one property and every document is
## about it. Card was not wasted; it was pointed at the wrong system.
##
## ## What the board has that a list does not
##
## Three things, and each one is a thing a table cannot express:
##
## **Position means something.** A slip near another slip is related to it. The
## groupings here -- who is out, who is being watched, what came back -- are
## regions of a wall rather than rows under a header, and a manager rearranging
## their own board is doing the reasoning rather than reporting it.
##
## **Everything is visible at once.** `SCOUTING.md`'s whole model is partial
## information widening with observation, and the comparison a manager actually
## makes is *between* partial reports. Behind one click each, they cannot make it.
##
## **Nothing is uniform.** Reports arrive at different sizes because they contain
## different amounts. A row of equal cells says every prospect is the same kind of
## thing and your job is to sort them; a wall of unequal scraps says somebody has
## been finding things out at an uneven rate, which is what happened.
##
## ## Not string and pins
##
## The metaphor is a claim about information, not a puzzle-board aesthetic. There
## is no red yarn. Everything on this board is pinned, tilted a degree and
## clickable, and it is still a management interface you can work quickly.

const ScreenShell := preload("res://scenes/components/screen_shell.gd")
const SlipScript := preload("res://scenes/components/pinned_slip.gd")
const PopupScript := preload("res://scenes/components/desk_popup.gd")
const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const Clippings := preload("res://scripts/data/match_clippings.gd")
const Larder := preload("res://scripts/data/region_larder.gd")
const UIPalette := preload("res://scripts/data/ui_palette.gd")

const MARK_NONE: int = 0
const MARK_SIGN: int = 1
const MARK_WATCH: int = 2
const MARK_PASS: int = 3

## What a mark is called, everywhere it is named. One table, so the word pinned
## to the board and the word on the control that sets it cannot drift apart.
const MARK_WORDS := {
	MARK_SIGN: "sign", MARK_WATCH: "watch", MARK_PASS: "seen enough",
}
const MARK_ORDER := [MARK_SIGN, MARK_WATCH, MARK_PASS]

## The pin colours the marks claim.
##
## The only place on this board where a pin colour means anything, and it is
## stated rather than inferred -- `UIPinnedSlip` deliberately treats a box of pins
## as a box of pins, so a colour key has to be opted into by a caller who has a
## key. Unmarked slips keep the meaningless colours, which is what makes the
## marked ones read.
const MARK_PINS := {
	MARK_SIGN: Color("3f7d52"), MARK_WATCH: Color("d9982f"),
	MARK_PASS: Color("8d8377"),
}

const CARD_SIZE := Vector2(178.0, 116.0)
const NOTE_WIDTH: float = 210.0
## The clippings strip, shut and open.
##
## Shut, it is a single row along the bottom -- enough to read a headline and see
## that there are some. Open, it is a third of the board, because reading a
## cutting is a thing you stop and do rather than something you take in at a
## glance.
const STRIP_SHUT: float = 96.0
const STRIP_OPEN: float = 250.0
const CLIPPING_SIZE := Vector2(190.0, 78.0)

signal back_requested

var _career_manager: Node = null
var _game_manager: Node = null
var _board: HBoxContainer = null
var _shortlist: HFlowContainer = null
var _notes: VBoxContainer = null
var _panel: DeskPopup = null
var _open_id: int = -1
var _strip: HFlowContainer = null
var _strip_scroll: ScrollContainer = null
var _strip_button: Button = null
var _strip_open: bool = false


func bind(career_manager: Node, game_manager: Node) -> void:
	_career_manager = career_manager
	_game_manager = game_manager
	refresh()


func _ready() -> void:
	_build()


func _build() -> void:
	var back_button := ScreenShell.action("Back")
	back_button.pressed.connect(func() -> void: back_requested.emit())
	## `BACKING_BOARD`: the same cork the training clipboard lies on, with the page
	## taken off it. That is the whole structural difference between the two
	## objects, and it is one flag rather than two components because two would
	## drift.
	## `UIPinnedSlip`'s header carries the table that keeps the two objects apart;
	## the short version is that a clipboard is mostly sheet and a board is mostly
	## board.
	var shell := ScreenShell.build(
		self, "Scouting", [back_button] as Array[Button], ScreenShell.BACKING_BOARD
	)

	_board = HBoxContainer.new()
	_board.name = "Board"
	_board.add_theme_constant_override("separation", 18)
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.content.add_child(_board)

	var scroll := ScrollContainer.new()
	scroll.name = "ShortlistScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_board.add_child(scroll)
	## A flow rather than a grid. Cards are pinned where there is room, so a
	## narrower window puts fewer on a row -- which is what happens to a real
	## board and is also the only layout that survives the cards not all being the
	## same size later.
	_shortlist = HFlowContainer.new()
	_shortlist.name = "Shortlist"
	_shortlist.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_shortlist.add_theme_constant_override("h_separation", 16)
	_shortlist.add_theme_constant_override("v_separation", 16)
	scroll.add_child(_shortlist)

	_notes = VBoxContainer.new()
	_notes.name = "Notes"
	_notes.custom_minimum_size = Vector2(NOTE_WIDTH + 20.0, 0.0)
	_notes.add_theme_constant_override("separation", 14)
	_board.add_child(_notes)

	## ## The clippings, along the bottom
	##
	## Along the bottom rather than in the column, because these are a *different
	## kind of thing* from everything above them -- the column is what the board
	## says about itself and the shortlist is who you are tracking, and a clipping
	## is neither. It is what arrived. Giving it its own edge of the board is the
	## cheapest way to say so without a header explaining it.
	var strip_column := VBoxContainer.new()
	strip_column.name = "Clippings"
	strip_column.add_theme_constant_override("separation", 4)
	shell.content.add_child(strip_column)
	_strip_button = Button.new()
	_strip_button.name = "ClippingsButton"
	_strip_button.text = "Cuttings"
	_strip_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_strip_button.pressed.connect(func() -> void:
		_strip_open = not _strip_open
		_refresh_strip_size()
	)
	strip_column.add_child(_strip_button)
	_strip_scroll = ScrollContainer.new()
	_strip_scroll.name = "ClippingsScroll"
	_strip_scroll.custom_minimum_size = Vector2(0.0, STRIP_SHUT)
	_strip_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	strip_column.add_child(_strip_scroll)
	_strip = HFlowContainer.new()
	_strip.name = "ClippingRow"
	_strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_strip.add_theme_constant_override("h_separation", 14)
	_strip.add_theme_constant_override("v_separation", 12)
	_strip_scroll.add_child(_strip)

	_panel = PopupScript.build()
	add_child(_panel)


func _refresh_strip_size() -> void:
	_strip_scroll.custom_minimum_size = Vector2(
		0.0, STRIP_OPEN if _strip_open else STRIP_SHUT
	)


func refresh() -> void:
	if _shortlist == null or _career_manager == null:
		return
	for child in _shortlist.get_children():
		child.queue_free()
	for child in _notes.get_children():
		child.queue_free()
	var prospects := _prospects()
	if prospects.is_empty():
		_notes.add_child(_note_slip(
			"Nothing on the board", "Send somebody to a game.", "empty"
		))
		return
	for prospect in prospects:
		_shortlist.add_child(_card_slip(prospect))
	_refresh_notes(prospects)
	_refresh_clippings()


## ## What arrived
##
## Cuttings are not filtered to the shortlist, and that is the whole point: the
## paper prints who played well, and whether you were watching them is your
## problem. A clipping naming somebody with no polaroid is how `SCOUTING.md`'s
## unsolicited discovery actually reaches a manager.
func _refresh_clippings() -> void:
	if _strip == null:
		return
	for child in _strip.get_children():
		child.queue_free()
	var career = _career_manager.career
	var fixtures: Array = career.fixtures if career != null else []
	var roster: Array = _game_manager.players if _game_manager != null else []
	var cuttings := Clippings.recent(fixtures, roster)
	_strip_button.text = "Cuttings — nothing yet" if cuttings.is_empty() \
		else "Cuttings (%d)" % cuttings.size()
	if cuttings.is_empty():
		return
	for clipping in cuttings:
		_strip.add_child(_clipping_slip(Dictionary(clipping)))


func _clipping_slip(clipping: Dictionary) -> Control:
	var subject_id := int(clipping.get("subject_id", -1))
	var face := Button.new()
	face.name = "Cutting%d" % int(clipping.get("week", 0))
	face.flat = true
	face.custom_minimum_size = CLIPPING_SIZE
	## A cutting about somebody you have a polaroid of opens their profile; one
	## about a stranger opens nothing yet, and says so rather than pretending to
	## be inert.
	if subject_id >= 0 and _prospect_by_id(subject_id) != null:
		face.pressed.connect(func() -> void: _open(subject_id))

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 1)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right"]:
		column.add_theme_constant_override("margin_%s" % side, 10)
	for side in ["top", "bottom"]:
		column.add_theme_constant_override("margin_%s" % side, 9)
	face.add_child(column)

	var week := Label.new()
	week.name = "CuttingEyebrow"
	week.text = "week %d" % int(clipping.get("week", 0))
	week.add_theme_font_size_override("font_size", 9)
	week.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(week)
	var headline := Label.new()
	headline.name = "CuttingTitle"
	headline.text = str(clipping.get("headline", ""))
	headline.add_theme_font_size_override("font_size", 13)
	headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	headline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(headline)
	var body := Label.new()
	body.name = "CuttingSummary"
	body.text = str(clipping.get("body", ""))
	body.add_theme_font_size_override("font_size", 10)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(body)

	var slip := SlipScript.wrap(face, str(clipping.get("headline", "")), false)
	slip.newsprint = true
	slip.custom_minimum_size = CLIPPING_SIZE
	return slip


## Whoever the career is currently looking at. Falls back to the club's own
## roster so the board has something true on it before a scouting pipeline
## exists -- the arrangement is the thing being proven here.
func _prospects() -> Array:
	var career = _career_manager.career
	if career != null and "scouted_players" in career:
		var scouted: Array = career.scouted_players
		if not scouted.is_empty():
			return scouted
	if _game_manager == null:
		return []
	return _game_manager.players


## One voli, as the thing a scout pinned up about them.
##
## A photograph with the particulars written under it, which is what a scouting
## card physically is. What it deliberately does **not** carry is the six-category
## report: that is what opening it is for, and a card that showed everything would
## make the board a table with rounded corners.
func _card_slip(prospect) -> Control:
	var prospect_id := int(prospect.id)
	var mark := _mark_for(prospect_id)

	var face := Button.new()
	face.name = "Card%d" % prospect_id
	face.flat = true
	face.custom_minimum_size = CARD_SIZE
	face.pressed.connect(func() -> void: _open(prospect_id))

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["left", "right", "top", "bottom"]:
		column.add_theme_constant_override("margin_%s" % side, 10)
	face.add_child(column)

	var portrait := _Portrait.new()
	portrait.custom_minimum_size = Vector2(0.0, 44.0)
	portrait.seed_value = prospect_id
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(portrait)

	var name_label := Label.new()
	name_label.name = "Card%dTitle" % prospect_id
	name_label.text = str(prospect.display_name)
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(name_label)

	var line := Label.new()
	line.name = "Card%dDetail" % prospect_id
	line.text = "%s · %d" % [_short_role(str(prospect.position_role)), int(prospect.age)]
	line.add_theme_font_size_override("font_size", 11)
	line.clip_text = true
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(line)

	## What is written on the card, when anything is. A scout writes the mark on
	## the card itself, not on a legend somewhere else.
	if mark != MARK_NONE:
		var written := Label.new()
		written.name = "Card%dStatus" % prospect_id
		written.text = str(MARK_WORDS[mark])
		written.add_theme_font_size_override("font_size", 11)
		written.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(written)

	## **Not a photographic slip.** A scouting card is a card with a photograph on
	## it, not a photograph with writing over it -- and passing `true` here made it
	## the second thing: the print's image area covered the whole slip and the name,
	## the position and the mark were all written across the picture. The print
	## border belongs to `_Portrait`, which is the part that is actually a print.
	var slip := SlipScript.wrap(face, str(prospect.display_name), false)
	slip.custom_minimum_size = CARD_SIZE
	if mark != MARK_NONE:
		slip.tack_colour = MARK_PINS[mark]
	## Seen enough stays on the board and stops asking to be read. It is not
	## removed: a board you have to remember having cleared is worse than one
	## carrying a faded card you can see you already dismissed.
	if mark == MARK_PASS:
		slip.modulate = Color(1.0, 1.0, 1.0, 0.62)
	return slip


## The right-hand column: what the board says about itself.
##
## Counts rather than a list, because these are the facts a manager checks
## *before* reading any one card -- how much is out, how much has come back, how
## much of it they have made a decision about.
func _refresh_notes(prospects: Array) -> void:
	var marked := {MARK_SIGN: 0, MARK_WATCH: 0, MARK_PASS: 0, MARK_NONE: 0}
	var watched := 0
	for prospect in prospects:
		marked[_mark_for(int(prospect.id))] += 1
		if int(prospect.weeks_observed) if "weeks_observed" in prospect else 0:
			watched += 1
	_notes.add_child(_note_slip(
		"On the board",
		"%d pinned up · %d of them watched at least once" % [prospects.size(), watched],
		"count"
	))
	_notes.add_child(_note_slip(
		"Decided",
		"%d to sign · %d worth watching · %d seen enough · %d untouched" % [
			marked[MARK_SIGN], marked[MARK_WATCH],
			marked[MARK_PASS], marked[MARK_NONE],
		],
		"decided"
	))
	_notes.add_child(_note_slip(
		"Where they are from",
		_regions_of(prospects),
		"regions"
	))


func _regions_of(prospects: Array) -> String:
	var counted := {}
	for prospect in prospects:
		var home := str(prospect.home_region) if "home_region" in prospect else ""
		if home.is_empty():
			continue
		counted[home] = int(counted.get(home, 0)) + 1
	if counted.is_empty():
		return "Nobody's origin is written down."
	var names: Array = counted.keys()
	names.sort()
	var parts: Array[String] = []
	for name in names:
		parts.append("%s %d" % [str(name), int(counted[name])])
	return " · ".join(parts)


func _note_slip(heading: String, body: String, key: String) -> Control:
	var panel := Control.new()
	panel.custom_minimum_size = Vector2(NOTE_WIDTH, 0.0)
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.add_theme_constant_override("separation", 2)
	for side in ["left", "right", "top", "bottom"]:
		column.add_theme_constant_override("margin_%s" % side, 12)
	panel.add_child(column)
	var title := Label.new()
	title.name = "%sTitle" % key.capitalize()
	title.text = heading
	column.add_child(title)
	var text := Label.new()
	text.name = "%sSummary" % key.capitalize()
	text.text = body
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", 11)
	column.add_child(text)
	var slip := SlipScript.wrap(panel, key, false)
	slip.custom_minimum_size = Vector2(NOTE_WIDTH, 74.0)
	return slip


## ## The report
##
## Taking the card off the board and reading what is on the back of it. Opened
## rather than always visible, for the reason the card is small: what the board is
## for is comparison, and six categories times a dozen prospects is not a board,
## it is a spreadsheet somebody pinned up.
func _open(prospect_id: int) -> void:
	_open_id = prospect_id
	var prospect = _prospect_by_id(prospect_id)
	if prospect == null:
		return
	_panel.open(str(prospect.display_name), _origin_of(prospect))
	_fill_report(prospect)


## What a report is a report *of*.
##
## **Spelled `Setting / Control` and `Mental / Tactical`, not `&`.** Both
## spellings are load bearing and the reason is at `CATEGORY_ALIASES`; the last
## two things to use the wrong one were `ScoutingSystem.KNOWABILITY` and the first
## draft of this screen, which read *exactly* 50.0 on two of six categories for
## every prospect, 264 of 264, because a `.get(key, 50.0)` was answering for a key
## that was never there.
const REPORT_CATEGORIES := [
	"Attacking", "Defensive", "Setting / Control",
	"Physical", "Serving", "Mental / Tactical",
]

## Where a number stops being worth a word.
##
## Measured, not picked: 1,584 category scores over 24 generated rosters give
## p25 52, p50 63, p75 72. So 72 is the top quarter and 48 the bottom sixth. The
## first draft guessed 68 and 42 from a half-remembered "centred near 50", and 42
## sits below the fifth percentile -- a scout who would have had almost nothing
## bad to say about anybody, silently, which is §0's standing failure.
const REPORT_STRONG: float = 72.0
const REPORT_WEAK: float = 48.0


func _fill_report(prospect) -> void:
	for child in _panel.body.get_children():
		child.queue_free()
	var summary: Dictionary = AttributeProfiles.summary_profile(prospect)
	_report_row("Rated", str(roundi(float(summary.get("Overall", 50.0)))))
	_report_row("Asking", _salary_of(prospect))
	_report_row("Watched", _watched_of(prospect))
	var traits := _traits_of(prospect)
	if not traits.is_empty():
		_report_row("Noted", traits)

	_panel.body.add_child(HSeparator.new())
	for category in REPORT_CATEGORIES:
		## No fallback. A default is what hid the wrong spellings above, and a
		## category that stops being returned should print an obviously broken row
		## rather than a plausible 50.
		if not summary.has(category):
			_report_row(str(category), "missing")
			continue
		var value := float(summary[category])
		_report_row(str(category), "%d — %s" % [roundi(value), _read_of(value)])

	## ## How they live
	##
	## A profile that is only attributes is a spec sheet, and a manager signing
	## somebody is also deciding where to put them and what to feed them. Every
	## line here is a field that has existed on `VolleyballPlayer` since regions
	## and the table were built, and none of them had ever been shown anywhere --
	## which is why a manager could sign a voli and discover their palate weeks
	## later, from a complaint.
	##
	## It sits under the report rather than above it because it is the second
	## question. You find out whether they can play, and then you find out what it
	## takes to keep them.
	_panel.body.add_child(HSeparator.new())
	var living := Label.new()
	living.name = "LivingTitle"
	living.text = "How they live"
	_panel.body.add_child(living)
	_report_row("Raised on", _palate_of(prospect))
	_report_row("Sharing", _sharing_of(prospect))
	_report_row("Build", _build_of(prospect))

	var marks := HBoxContainer.new()
	marks.name = "ReportMarks"
	marks.add_theme_constant_override("separation", 6)
	_panel.body.add_child(marks)
	var current := _mark_for(_open_id)
	for mark in MARK_ORDER:
		var button := Button.new()
		button.name = "Mark%dButton" % int(mark)
		button.text = str(MARK_WORDS[mark])
		button.toggle_mode = true
		button.button_pressed = mark == current
		var value := int(mark)
		## Pressing the mark a card already carries takes it off, which is the only
		## way back to unmarked without a fourth button called "nothing" -- and
		## nothing is the absence of a mark, not a mark somebody made.
		button.pressed.connect(func() -> void: _set_mark(_open_id, value))
		marks.add_child(button)


func _report_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_panel.body.add_child(row)
	var key := Label.new()
	## Wide enough for `Mental / Tactical`, which is the longest thing in this
	## column. Sized against `Watched` it was 84, and the two category names with a
	## slash in them pushed their own figures along.
	key.name = "%sContext" % label_text
	key.text = label_text
	key.custom_minimum_size = Vector2(150.0, 0.0)
	row.add_child(key)
	var value := Label.new()
	value.name = "%sValue" % label_text
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)


## ## Living preferences, from fields that already exist
##
## Nothing here is a new number. Inventing a "sharing preference" attribute and
## then guessing its bands is the §0 failure in its most tempting form -- a knob
## that reads plausibly and cannot be checked against anything. So each of these
## is a *reading* of a field the generator already fills, and the bands are the
## ones that field already uses elsewhere.

## What they grew up eating. `palate_regions` is what `FoodSupply` measures
## comfort against, so this is literally the list the table is scored on -- and
## the first place a manager can see it before signing rather than after.
func _palate_of(prospect) -> String:
	if not "palate_regions" in prospect:
		return "nobody wrote it down"
	var regions: Array = prospect.palate_regions
	if regions.is_empty():
		return "nobody wrote it down"
	var pastes: Array[String] = []
	for region in regions:
		pastes.append(Larder.paste_name(str(region)).trim_suffix(" paste"))
	return ", ".join(pastes)


## Whether they will take a shared room.
##
## Read off `ego`, which is a real generated field on a 1-100 range with a
## documented middle at 50 -- so the bands are thirds of its own stated range
## rather than numbers picked to sound right. High ego wants a door that shuts;
## low ego would rather not be on their own.
##
## Stated as a preference rather than as a number, per the rule that a profile
## says what a scout would say. The manager can still put them anywhere.
const EGO_WANTS_OWN_ROOM: int = 67
const EGO_WANTS_COMPANY: int = 34


func _sharing_of(prospect) -> String:
	if not "ego" in prospect:
		return "no opinion on record"
	var ego := int(prospect.ego)
	if ego >= EGO_WANTS_OWN_ROOM:
		return "wants a room of their own"
	if ego <= EGO_WANTS_COMPANY:
		return "would rather not be on their own"
	return "will share and not mention it"


## What kind of body the housing has to accommodate. `body_type` is generated and
## drives attribute deltas already; here it is the thing that decides whether a
## standard bunk is going to be long enough.
func _build_of(prospect) -> String:
	if not "body_type" in prospect:
		return ""
	var build := str(prospect.body_type)
	var height := int(prospect.height_cm) if "height_cm" in prospect else 0
	if height <= 0:
		return build
	return "%s · %d cm" % [build, height]


## What a scout would say instead of the number.
func _read_of(value: float) -> String:
	if value >= REPORT_STRONG:
		return "worth the trip"
	if value <= REPORT_WEAK:
		return "not there yet"
	return "gets by"


func _prospect_by_id(prospect_id: int):
	for prospect in _prospects():
		if int(prospect.id) == prospect_id:
			return prospect
	return null


## Marks live on the career, not the screen. A note you have to re-make every time
## you open the page is not a note, and a shortlist that forgets itself between
## sessions is worse than none.
func _mark_for(prospect_id: int) -> int:
	if _career_manager == null or _career_manager.career == null:
		return MARK_NONE
	return int(_career_manager.career.scouting_marks.get(prospect_id, MARK_NONE))


func _set_mark(prospect_id: int, mark: int) -> void:
	if _career_manager == null or _career_manager.career == null:
		return
	var marks: Dictionary = _career_manager.career.scouting_marks
	if int(marks.get(prospect_id, MARK_NONE)) == mark:
		marks.erase(prospect_id)
	else:
		marks[prospect_id] = mark
	refresh()
	var prospect = _prospect_by_id(prospect_id)
	if prospect != null and _panel.visible:
		_fill_report(prospect)


## Where they were raised, and where they play now when that is somewhere else.
## Both fields have been on `VolleyballPlayer` since regions were built and this
## is the first screen to read either: a scout's first line about somebody is
## where they are from.
func _origin_of(prospect) -> String:
	var home := str(prospect.home_region) if "home_region" in prospect else ""
	var club := str(prospect.club_region) if "club_region" in prospect else ""
	if home.is_empty() and club.is_empty():
		return "No fixed club"
	if club.is_empty() or club == home:
		return home
	if home.is_empty():
		return "Playing in %s" % club
	return "%s, playing in %s" % [home, club]


## How much of this is worth believing. `weeks_observed` is `SCOUTING.md`'s
## freshness clock. Nobody watched is said as such rather than as "0 weeks",
## which reads as a measurement that came back zero.
func _watched_of(prospect) -> String:
	var weeks := int(prospect.weeks_observed) if "weeks_observed" in prospect else 0
	if weeks <= 0:
		return "not yet"
	return "%d week%s" % [weeks, "" if weeks == 1 else "s"]


func _traits_of(prospect) -> String:
	if not "traits" in prospect:
		return ""
	var words: Array[String] = []
	for entry in Array(prospect.traits):
		words.append(str(entry))
	return ", ".join(words)


func _salary_of(prospect) -> String:
	if "salary" in prospect:
		return "%d/wk" % int(prospect.salary)
	## No salary model yet. Derived from the rating so the row is populated with
	## something monotone rather than a placeholder that sorts randomly -- and
	## stated here so nobody reads it as a real wage bill.
	var summary: Dictionary = AttributeProfiles.summary_profile(prospect)
	return "~%d/wk" % (roundi(float(summary.get("Overall", 50.0))) * 18)


## `Outside Hitter` does not fit on a card that is 178 across, and a clipped
## label is worse than an abbreviation somebody has to learn once.
const SHORT_ROLES := {
	"Outside Hitter": "OH", "Opposite Hitter": "OPP", "Middle Blocker": "MB",
	"Setter": "S", "Libero": "L", "Defensive Specialist": "DS",
}


func _short_role(role: String) -> String:
	return str(SHORT_ROLES.get(role, role))


## A photograph that is not a photograph yet.
##
## `voli_card.gd` can draw a real body and this board will eventually use it. Until
## then a print with nothing recognisable in it is more honest than a placeholder
## that says "photo": what a scout has is a picture, and a picture of somebody you
## have not watched properly is exactly this useless.
class _Portrait extends Control:
	var seed_value: int = 0

	func _ready() -> void:
		set_meta("ui_style_exempt", true)

	## The unexposed margin of the paper the picture was printed on. It is the one
	## mark that says "photograph" rather than "grey box", and it costs a rect.
	const PRINT_BORDER: float = 3.0

	func _draw() -> void:
		var light := UIPalette.control_is_light(self)
		var ink := UIPalette.color(&"ink_faint", light)
		draw_rect(
			Rect2(Vector2.ZERO, size),
			Color(1.0, 0.99, 0.96) if light else Color(0.86, 0.85, 0.81), true
		)
		draw_rect(
			Rect2(
				Vector2(PRINT_BORDER, PRINT_BORDER),
				size - Vector2(PRINT_BORDER, PRINT_BORDER) * 2.0
			),
			Color(ink, 0.30), true
		)
		## A head and shoulders in silhouette, placed off-centre by the voli's own
		## id so no two prints are framed identically -- which is the one thing
		## about a snapshot you notice before you notice the person.
		var drift := (float(seed_value * 37 % 100) / 100.0 - 0.5) * size.x * 0.18
		var centre := Vector2(size.x * 0.5 + drift, size.y * 0.66)
		var head := size.y * 0.24
		draw_circle(centre - Vector2(0.0, head * 1.35), head, Color(ink, 0.55))
		draw_rect(
			Rect2(
				centre - Vector2(head * 1.5, 0.0),
				Vector2(head * 3.0, size.y - centre.y - PRINT_BORDER)
			),
			Color(ink, 0.55), true
		)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_THEME_CHANGED:
			queue_redraw()
