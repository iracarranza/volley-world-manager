class_name VolleyballScoutingScreen
extends Control

## The scouting folders, on the one medium they were always documented as.
##
## `TITLE_SCREEN.md` has said since the medium rule was written that the objects
## on the desk are made of different things -- *"the clipboard is paper somebody
## drew on, the folders are card"* -- and until now there was no `card` medium to
## be made of. So this screen fell through to `drawn`, which is the default, and
## rendered as the planner with different words on it.
##
## ## What was here, and what it got wrong
##
## A list of names on ruled paper, columnar and unruled, on the argument that a
## scout keeps a page and ticks it. The argument is fine and the object is wrong:
## a page of names is *paper*, and paper is the clipboard. Two objects on one desk
## cannot be the same material and still be two objects, which is the failure
## `UIPrintedRule`'s header documents at length and this is the third instance of.
##
## A folder is also a better fit for what scouting *is*. A page of names says
## every prospect is a row and your job is to sort them. A drawer of folders says
## each one is a thing you have collected material about, that you open one at a
## time, and that most of what you know about them is inside rather than on the
## front -- which is exactly `SCOUTING.md`'s model, where a report is partial and
## widens with observation.
##
## ## The drawer, and why the tabs are staggered
##
## Folders in a drawer are cut so that no two adjacent tabs are in the same
## position -- third-cut stock alternates left, centre, right -- because a column
## of tabs at one position is a column you cannot read past the first one. The
## stagger here is that, not decoration, and it is what makes a vertical list of
## folders read as a drawer seen from above rather than as a list of buttons.
##
## ## The mark is on the tab, and setting it is not
##
## What was here cycled the mark by clicking the name, and needed a line of hint
## text to say so -- which is the tell that the interaction was invisible. A tab
## click now opens the folder, which is what a tab is for, and the three marks
## are three named things inside it. The mark still shows on the tab, because the
## whole point of writing on a tab is reading it with the folder shut.

const ScreenShell := preload("res://scenes/components/screen_shell.gd")
const UIStyleSystemScript := preload("res://scripts/systems/ui_style_system.gd")
const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")

const MARK_NONE: int = 0
const MARK_SIGN: int = 1
const MARK_WATCH: int = 2
const MARK_PASS: int = 3

## What a mark is called on the tab, and on the button that sets it.
##
## One table, so the word on the tab and the word on the control can never drift
## apart -- a folder that says "watch" and a button that says "keep an eye on"
## is two names for one state, and a manager has to work out that they are the
## same thing.
const MARK_WORDS := {
	MARK_SIGN: "sign", MARK_WATCH: "watch", MARK_PASS: "pass",
}
const MARK_ORDER := [MARK_SIGN, MARK_WATCH, MARK_PASS]

## Third-cut stock: three tab positions, and the drawer cycles through them.
const TAB_CUTS: int = 3
const TAB_STAGGER: float = 26.0
const DRAWER_WIDTH: float = 300.0
const TAB_HEIGHT: float = 34.0
## How far the folder you are reading stands out of the drawer.
const TAB_LIFT: float = 12.0

## What a report is a report *of*.
##
## `AttributeProfiles.summary_profile` returns these six and an `Overall` derived
## from them. The six are what goes in the folder and the Overall goes on the
## front, which is the split the wheel already makes -- a rating is what you say
## about somebody in one number and the categories are what you actually watched.
##
## **Spelled `Setting / Control` and `Mental / Tactical`, not `&`.** The two
## spellings and why both exist are documented at `CATEGORY_ALIASES`, along with
## the last thing that used the wrong one: `ScoutingSystem.KNOWABILITY`, whose
## whole entry for the least observable category silently did nothing. This list
## was written with `&` and made the same mistake, and the measurement is what
## found it -- every player's Setting and Mental read *exactly* 50.0, 264 of 264,
## because a `.get(category, 50.0)` was answering for a key that was never there.
const REPORT_CATEGORIES := [
	"Attacking", "Defensive", "Setting / Control",
	"Physical", "Serving", "Mental / Tactical",
]

## Where a number stops being worth a word.
##
## Measured, not picked, because §0's standing failure is a threshold outside the
## distribution it acts on -- and it fails *silently*, which is the part that
## costs the time. 1,584 category scores off 24 generated rosters, half founded
## and half established:
##
##     p05 40 · p25 52 · p50 63 · p75 72 · p95 85   (min 26, max 99)
##
## So 72 is the top quarter (27.8% at or above) and 48 is the bottom sixth (17.2%
## at or below). The first draft of these was 68 and 42, guessed at from a
## remembered "centred near 50" -- 42 would have fired on well under a tenth of
## reads and a scout would have had almost nothing bad to say about anybody.
const REPORT_STRONG: float = 72.0
const REPORT_WEAK: float = 48.0

signal back_requested

var _career_manager: Node = null
var _game_manager: Node = null
var _drawer: VBoxContainer = null
var _face: VBoxContainer = null
var _open_id: int = -1


func bind(career_manager: Node, game_manager: Node) -> void:
	_career_manager = career_manager
	_game_manager = game_manager
	refresh()


func _ready() -> void:
	_build()


func _build() -> void:
	## Declared before anything is added, so every node built below inherits it on
	## the first style pass rather than on whichever one happens to run second.
	set_meta(UIStyleSystemScript.MEDIUM_META, UIStyleSystemScript.MEDIUM_CARD)

	var back_button := ScreenShell.action("Back")
	back_button.pressed.connect(func() -> void: back_requested.emit())
	var shell := ScreenShell.build(self, "Scouting", [back_button] as Array[Button])
	var column := shell.content

	var body := HBoxContainer.new()
	body.name = "ScoutingBody"
	body.add_theme_constant_override("separation", 14)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(body)

	## The drawer scrolls and the open folder does not, which is the right way
	## round: you push folders back and forth to find one, and then the one in
	## your hands is the whole of what you are looking at.
	var scroll := ScrollContainer.new()
	scroll.name = "DrawerScroll"
	scroll.custom_minimum_size = Vector2(DRAWER_WIDTH, 0.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)

	_drawer = VBoxContainer.new()
	_drawer.name = "Drawer"
	_drawer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	## Tabs touch. Folders in a drawer are packed against each other, and a gap
	## between them would say each one is sitting on its own shelf.
	_drawer.add_theme_constant_override("separation", 0)
	scroll.add_child(_drawer)

	var face_panel := PanelContainer.new()
	face_panel.name = "OpenFolder"
	face_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	face_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(face_panel)
	var face_margin := MarginContainer.new()
	for side in ["left", "right"]:
		face_margin.add_theme_constant_override("margin_%s" % side, 20)
	for side in ["top", "bottom"]:
		face_margin.add_theme_constant_override("margin_%s" % side, 16)
	face_panel.add_child(face_margin)
	_face = VBoxContainer.new()
	_face.name = "FolderFace"
	_face.add_theme_constant_override("separation", 8)
	face_margin.add_child(_face)


func refresh() -> void:
	if _drawer == null:
		return
	for child in _drawer.get_children():
		child.queue_free()
	if _career_manager == null:
		return
	var prospects := _prospects()
	if prospects.is_empty():
		var empty := Label.new()
		empty.name = "DrawerEmptySummary"
		empty.text = "The drawer is empty."
		_drawer.add_child(empty)
		_fill_face(null)
		return
	## The open folder survives a refresh, and only falls back to the first when
	## whoever was open has left the drawer -- a mark that closed the folder you
	## just marked would make marking three of them three separate journeys.
	var open: Variant = _prospect_by_id(prospects, _open_id)
	if open == null:
		open = prospects[0]
		_open_id = int(open.id)
	for index in range(prospects.size()):
		_drawer.add_child(_tab_for(prospects[index], index))
	_fill_face(open)


## Whoever the career is currently looking at. Falls back to the club's own
## roster so the screen has something true to draw before a scouting pipeline
## exists -- the layout is the thing being proven here.
func _prospects() -> Array:
	var career = _career_manager.career
	if career != null and "scouted_players" in career:
		var scouted: Array = career.scouted_players
		if not scouted.is_empty():
			return scouted
	if _game_manager == null:
		return []
	return _game_manager.players


func _prospect_by_id(prospects: Array, prospect_id: int):
	if prospect_id < 0:
		return null
	for prospect in prospects:
		if int(prospect.id) == prospect_id:
			return prospect
	return null


## One folder, seen edge-on in the drawer: its tab and nothing else.
func _tab_for(prospect, index: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	## The cut. A spacer rather than a margin, because the amount is per-folder
	## and a theme constant is per-container.
	var cut := Control.new()
	cut.custom_minimum_size = Vector2(float(index % TAB_CUTS) * TAB_STAGGER, 0.0)
	cut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(cut)

	var prospect_id := int(prospect.id)
	var open := prospect_id == _open_id
	var tab := Button.new()
	tab.name = "FolderTab%d" % prospect_id
	## **The open folder is taller, not coloured.**
	##
	## It was a toggle first, which meant the theme's pressed state -- accent red
	## on the chip -- said *this one is open*. On a screen where one of the three
	## marks is literally called "sign" and gets the same red when set, that is two
	## different facts in one colour, and the first render had a red tab labelled
	## "sign" sitting above a red button labelled "sign" meaning something else.
	##
	## So the open folder is the one standing proud of the drawer, which is what
	## you do to a folder you are reading and needs no colour at all.
	tab.custom_minimum_size = Vector2(0.0, TAB_HEIGHT + (TAB_LIFT if open else 0.0))
	tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tab.text = str(prospect.display_name)
	tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
	## What is written on the tab, when anything is. An unmarked folder says
	## nothing, which is the state most folders in a drawer are in.
	var mark := _mark_for(prospect_id)
	if mark != MARK_NONE:
		tab.text = "%s — %s" % [tab.text, MARK_WORDS[mark]]
	## A folder you have seen enough of stays in the drawer and stops asking to be
	## read. Alpha rather than a strike-through: pencil comes off card, so the
	## honest way to say "done with this" is a mark that faded, not a damaged tab.
	if mark == MARK_PASS:
		tab.modulate = Color(1.0, 1.0, 1.0, 0.55)
	elif not open:
		## Everything not in your hand is a little further away. Small enough that
		## nobody reads it as disabled, and enough that the lifted tab is the one
		## the eye lands on.
		tab.modulate = Color(1.0, 1.0, 1.0, 0.88)
	tab.pressed.connect(func() -> void:
		_open_id = prospect_id
		refresh()
	)
	row.add_child(tab)
	return row


## What is inside the folder.
func _fill_face(prospect) -> void:
	if _face == null:
		return
	for child in _face.get_children():
		child.queue_free()
	if prospect == null:
		var empty := Label.new()
		empty.name = "FolderEmptySummary"
		empty.text = "Nobody has been watched yet. Send somebody to a game."
		_face.add_child(empty)
		return

	var name_label := Label.new()
	name_label.name = "FolderTitle"
	name_label.text = str(prospect.display_name)
	_face.add_child(name_label)

	var particulars := Label.new()
	particulars.name = "FolderDetail"
	particulars.text = "%s · %d · %s" % [
		str(prospect.position_role), int(prospect.age), _origin_of(prospect),
	]
	_face.add_child(particulars)

	var summary: Dictionary = AttributeProfiles.summary_profile(prospect)
	_stat_row("Rated", str(roundi(float(summary.get("Overall", 50.0)))))
	_stat_row("Asking", _salary_of(prospect))
	_stat_row("Watched", _watched_of(prospect))

	var traits := _traits_of(prospect)
	if not traits.is_empty():
		_stat_row("Noted", traits)

	## The report itself, which is most of what a folder holds.
	##
	## Six rows and a word beside each, rather than six numbers. A number is what
	## the club's own profile page gives you; a folder is somebody's *account* of
	## watching them, and "quick off the floor" and "62" are not the same claim
	## even when they come from the same figure.
	var rule := HSeparator.new()
	rule.name = "ReportRule"
	_face.add_child(rule)
	for category in REPORT_CATEGORIES:
		## No fallback. A default here is what hid the wrong spellings above, and
		## a category that has stopped being returned should print an obviously
		## broken row rather than a plausible 50.
		if not summary.has(category):
			_stat_row(str(category), "missing")
			continue
		var value := float(summary[category])
		_stat_row(str(category), "%d — %s" % [roundi(value), _read_of(value)])

	## The marks, as three named things rather than a state you cycle blindly.
	##
	## Pressing the mark a folder already carries takes it off, which is the only
	## way to get back to unmarked without a fourth button called "nothing" --
	## and "nothing" is not a mark somebody makes, it is the absence of one.
	var marks := HBoxContainer.new()
	marks.name = "FolderMarks"
	marks.add_theme_constant_override("separation", 6)
	_face.add_child(marks)
	var prospect_id := int(prospect.id)
	var current := _mark_for(prospect_id)
	for mark in MARK_ORDER:
		var button := Button.new()
		button.name = "Mark%sButton" % str(MARK_WORDS[mark]).capitalize()
		button.text = str(MARK_WORDS[mark])
		button.toggle_mode = true
		button.button_pressed = mark == current
		var value := int(mark)
		button.pressed.connect(func() -> void: _set_mark(prospect_id, value))
		marks.add_child(button)


## What a scout would say instead of the number.
func _read_of(value: float) -> String:
	if value >= REPORT_STRONG:
		return "worth the trip"
	if value <= REPORT_WEAK:
		return "not there yet"
	return "gets by"


func _stat_row(label_text: String, value_text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_face.add_child(row)
	var key := Label.new()
	key.name = "%sContext" % label_text
	key.text = label_text
	## Wide enough for `Mental / Tactical`, which is the longest thing that goes in
	## this column. It was 84, sized against `Watched`, so the two category names
	## with a slash in them pushed their own values along and the column of figures
	## the folder is read down stopped being a column.
	key.custom_minimum_size = Vector2(150.0, 0.0)
	row.add_child(key)
	var value := Label.new()
	value.name = "%sValue" % label_text
	value.text = value_text
	value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(value)


## Marks live on the career, not the screen. A note you have to re-make every
## time you open the page is not a note, and a shortlist that forgets itself
## between sessions is worse than none.
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


## Where they were raised, and where they play now if that is somewhere else.
##
## Both fields have been on `VolleyballPlayer` since regions were built and this
## is the first screen to read them. A scout's first line about somebody is where
## they are from; it is not a decoration here.
func _origin_of(prospect) -> String:
	var home := str(prospect.home_region) if "home_region" in prospect else ""
	var club := str(prospect.club_region) if "club_region" in prospect else ""
	if home.is_empty() and club.is_empty():
		return "no fixed club"
	if club.is_empty() or club == home:
		return home
	if home.is_empty():
		return "playing in %s" % club
	return "%s, playing in %s" % [home, club]


## How much of this is worth believing.
##
## `weeks_observed` is `SCOUTING.md`'s freshness clock and it decides how much a
## report is worth, so it belongs on the face of the folder rather than behind a
## report screen. Nobody watched is stated as such rather than as "0 weeks",
## which reads as a measurement that came back zero.
func _watched_of(prospect) -> String:
	var weeks := int(prospect.weeks_observed) if "weeks_observed" in prospect else 0
	if weeks <= 0:
		return "not yet"
	return "%d week%s" % [weeks, "" if weeks == 1 else "s"]


func _traits_of(prospect) -> String:
	if not "traits" in prospect:
		return ""
	var traits: Array = prospect.traits
	if traits.is_empty():
		return ""
	var words: Array[String] = []
	for entry in traits:
		words.append(str(entry))
	return ", ".join(words)


func _rating_of(prospect) -> int:
	## Whatever the club's own summary says they are worth, so the number in this
	## folder is the number on their profile page rather than a second opinion.
	var summary: Dictionary = AttributeProfiles.summary_profile(prospect)
	return roundi(float(summary.get("Overall", 50.0)))


func _salary_of(prospect) -> String:
	if "salary" in prospect:
		return "%d/wk" % int(prospect.salary)
	## No salary model yet. Derived from the rating so the row is populated with
	## something monotone rather than a placeholder that sorts randomly -- and
	## stated here so nobody reads it as a real wage bill.
	return "~%d/wk" % (_rating_of(prospect) * 18)
