class_name LockInScreen
extends Control

## The gate in front of a match, and the things that should change your mind.
##
## `docs/design/CLUBS_REGIONS_AND_THE_ROSTER_DECISION.md` §2 is the argument for
## this screen and this file is the first build of it. The short version: a
## roster becomes worth studying when committing is an act, and there is no
## moment in this game where you say *this is the team* and it becomes true.
## Advancing to a match routes straight to playback.
##
## **It invents nothing.** Every figure below is already computed and already
## saved; what was missing was a moment where any of it is said out loud while
## it can still be acted on. That is what makes the screen cheap relative to its
## effect, and it is why it comes before any new roster mechanics.
##
## ## Figures, not sentences
##
## The board does not editorialise. It does not say a region serves well; it
## prints how many aces they hit and what you managed against them, and lets the
## manager reach the conclusion -- ideally by having lost to it once. Every
## descriptive line in the first draft of this design was replaced for that
## reason, and nothing here should reintroduce one.
##
## ## What is deliberately not here yet
##
## The functional team wheel from `docs/design/TEAM_ATTRIBUTE_WHEEL.md`. That
## spec replaces the six categories with axes that name their contributors --
## Attack, Blocking, Serve, Serve Receive, Floor Defense, Setting -- and until
## those exist this shows the six that do, which average every starter into
## every axis. It is the honest placeholder rather than the intended reading,
## and it is marked as such on screen rather than quietly passing for the real
## thing.

const ScreenShell := preload("res://scenes/components/screen_shell.gd")
const UIStyleSystem := preload("res://scripts/systems/ui_style_system.gd")
const BoardFace := preload("res://Yatra_One/YatraOne-Regular.ttf")
const BoardHand := preload("res://Short_Stack/ShortStack-Regular.ttf")
const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const FatigueModel := preload("res://scripts/simulation/fatigue_model.gd")
const UIPalette := preload("res://scripts/data/ui_palette.gd")
const VoliCardScene := preload("res://scenes/components/voli_card.gd")
const BoardCourtScene := preload("res://scenes/components/board_court.gd")
const BoardTrayScene := preload("res://scenes/components/board_tray.gd")
const RotationStrength := preload("res://scripts/data/rotation_strength.gd")

signal confirmed
signal cancelled

## How many previous meetings the opponent panel prints.
##
## Three is a shape you can read at a glance; ten is a season and wants a
## different object. See the design note under "How far back does the opponent
## table go".
const OPPONENT_ROWS: int = 3

var game_manager: Node
var career_manager: Node

var _body: VBoxContainer


func bind(career: Node, game: Node) -> void:
	career_manager = career
	game_manager = game


func _ready() -> void:
	_build()


## Built on demand rather than only from `_ready`.
##
## `_ready` does not always run when a caller expects it to -- a probe that adds
## this screen to the tree from `SceneTree._initialize` gets a node with zero
## children and no error to say why. Since `refresh` is the only thing anyone
## calls, it is the thing that has to be safe to call first.
func _build() -> void:
	if _body != null:
		return
	## **This is the board, not a page in the journal.**
	##
	## It was built on the shell and left at the default medium, so it arrived as
	## halftone-screened warm cream with a pen edge -- the journal, with a
	## different heading. The object is wrong for what the screen is: the journal
	## is a record you keep, and this is the thing somebody scrawls on the wall in
	## the last minute before you go out.
	##
	## The medium carries substrate, divisions and hand together, so declaring it
	## once here is the whole change; see `UIStyleSystem.MEDIUM_BOARD`, and
	## `docs/design/THE_TACTICAL_WHITEBOARD.md` for why it is a fourth medium
	## rather than the printed form with a different edge.
	set_meta(UIStyleSystem.MEDIUM_META, UIStyleSystem.MEDIUM_BOARD)
	var change_button := ScreenShell.action(
		"Change the lineup", "Go back to the roster without starting the match."
	)
	change_button.pressed.connect(func() -> void: cancelled.emit())
	var confirm_button := ScreenShell.action(
		"Lock in the six", "Write the lineup and start the match."
	)
	confirm_button.pressed.connect(func() -> void: confirmed.emit())
	var shell := ScreenShell.build(
		self, "Before you confirm",
		[change_button, confirm_button] as Array[Button],
	)
	## Yatra One, and deliberately not Cherry Bomb One. The board's display face
	## is its own; `docs/design/THE_TACTICAL_WHITEBOARD.md` names it, and the two
	## are easy to confuse because both are heavy display faces the rest of the
	## interface does not use.
	shell.title.add_theme_font_override("font", BoardFace)
	shell.title.add_theme_font_size_override("font_size", 30)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell.content.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)


## Rebuilt rather than updated in place.
##
## The panel's shape depends on how many volis are on court, how many previous
## meetings exist and whether a lineup is set at all, so incremental updates
## would have to handle every combination of those appearing and disappearing.
## A screen shown once per match can afford to be rebuilt once per match.
func refresh() -> void:
	_build()
	for child in _body.get_children():
		child.queue_free()
	if game_manager == null or career_manager == null:
		return
	_add_tray()
	_add_fixture_line()
	_add_court_and_opponent()
	_add_team_panel()
	_add_rotation_panel()
	_add_starter_cards()


func _add_fixture_line() -> void:
	var opponent: Resource = game_manager.opponent_team
	var fixture := _next_fixture()
	var parts: Array[String] = []
	var region := ""
	if fixture != null:
		parts.append("Week %d" % int(fixture.week))
		parts.append(str(fixture.opponent_name))
		region = str(fixture.opponent_region)
	elif opponent != null:
		parts.append(str(opponent.team_name))
	if region.is_empty() and opponent != null:
		region = str(opponent.region)
	if not region.is_empty():
		parts.append(region)
	if fixture != null and not str(fixture.competition_name).is_empty():
		parts.append(str(fixture.competition_name))
	_heading(" · ".join(parts) if not parts.is_empty() else "Next match")


## What they did, not what they are.
##
## No region is named as an explanation and no adjective appears. The comparison
## row is the whole panel: nine aces against your three is a fact about two
## teams, it does the work a sentence about their identity would have done, and
## it stays true when they are having a bad season.
func _add_opponent_panel() -> void:
	## Named off the fixture, so the heading here and the line above it cannot
	## disagree. They did: `prepare_fixture` used not to tell the game manager
	## which club the calendar had scheduled, so this panel printed the squad
	## actually across the net while the fixture line printed the name on the
	## schedule, and they were different clubs.
	var scheduled := _next_fixture()
	var opponent: Resource = game_manager.opponent_team
	var name := "Them"
	if scheduled != null:
		name = str(scheduled.opponent_name)
	elif opponent != null:
		name = str(opponent.team_name)
	var played := _completed_against(name)
	if played.is_empty():
		_note("No previous meetings with %s." % name)
		return
	_heading("Previous meetings · last %d" % mini(played.size(), OPPONENT_ROWS))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 18)
	_body.add_child(grid)
	## "misplays", not "errors", and the distinction is not pedantry. The other
	## three columns are rally-*terminal* counts -- an ace, a block, a kill each
	## end a rally and each is one point. `MatchStatistics` counts a `*_errors`
	## key for every contact that merely failed, so a shanked pass the team dug
	## out anyway lands in this column too, and a match reads 69 of them beside
	## 15 kills. Printed under "errors" next to three point counts, that number
	## is read as unforced points given away and is wrong by a factor of four.
	for column in ["", "sets", "aces", "blocks", "kills", "misplays"]:
		grid.add_child(_cell(column, true))
	var totals := {"aces": 0, "blocks": 0, "kills": 0, "errors": 0}
	var shown := 0
	for fixture in played:
		if shown >= OPPONENT_ROWS:
			break
		shown += 1
		var theirs: Dictionary = fixture.opponent_statistics
		var mine: Dictionary = fixture.home_statistics
		grid.add_child(_cell("wk %d" % int(fixture.week)))
		grid.add_child(_cell("%d–%d" % [
			int(fixture.opponent_sets), int(fixture.home_sets)
		]))
		for key in ["aces", "blocks", "kills"]:
			grid.add_child(_cell(str(int(theirs.get(key, 0)))))
		grid.add_child(_cell(str(_error_total(theirs))))
		for key in ["aces", "blocks", "kills"]:
			totals[key] = int(totals[key]) + int(mine.get(key, 0))
		totals["errors"] = int(totals["errors"]) + _error_total(mine)
	## Your own row, which is the reason the table is worth printing.
	grid.add_child(_cell("you", true))
	grid.add_child(_cell("—"))
	for key in ["aces", "blocks", "kills", "errors"]:
		grid.add_child(_cell(str(int(totals[key])), true))


func _add_team_panel() -> void:
	var starters := _starters()
	if starters.is_empty():
		_note("No starting lineup set. Assign starters on the Roster tab.")
		return
	_heading("On court")
	var totals := {}
	for player in starters:
		var profile := AttributeProfiles.summary_profile(player)
		for axis in profile:
			## Overall is not an axis, it is `category_score` applied to the other
			## six. Averaging it across starters would fold each voli's own
			## standout bonus and weak-spot penalty in a second time.
			if str(axis) == "Overall":
				continue
			totals[axis] = float(totals.get(axis, 0.0)) + float(profile[axis])
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 18)
	_body.add_child(grid)
	for axis in totals:
		var mean := float(totals[axis]) / float(starters.size())
		## **On the team scale, in this category.** `grade` is one absolute
		## scale shared by a voli's ability, their potential and a six-mean, and
		## measured over 240 chosen sixes it hands the board B 76.5% / C 23.3%,
		## with S, A and D between them reaching 0.3%. Three of five letters
		## unreachable, silently, because B always looks like a plausible answer.
		var grade: String = AttributeProfiles.category_grade(str(axis), mean, true)
		## Marked only at the ends. A balanced side draws no marks at all, which
		## is how the panel stays quiet most weeks by construction rather than by
		## a tuning pass.
		##
		## Marked at D and at A/S only -- not at C. C is the *ordinary* quarter
		## of the distribution by construction now, and marking a fifth of a
		## balanced squad's rows with a warning is how a quiet panel stops being
		## quiet. The earlier draft tested `grade in ["D", "E", "F", "C-"]`,
		## against a function that has never returned E or F: two thirds of that
		## list were unreachable, and unreachable in silence.
		var mark := ""
		match grade:
			"D":
				mark = "!"
			"S", "A":
				mark = "✓"
		grid.add_child(_cell(mark))
		grid.add_child(_cell(str(axis)))
		grid.add_child(_cell("%.1f  %s" % [mean, grade]))
	## **The caveat is not the player's problem.**
	##
	## This panel used to carry a note explaining that the figures average a
	## libero into the attack score, and citing the design document where the
	## fix is specified. That is the game apologising to the manager for its own
	## incompleteness, in the manager's face, every week -- and naming a filename
	## at somebody who is picking a volleyball team.
	##
	## The limitation is real and it is recorded where limitations go. On the
	## board, the rotation rows underneath say the same thing by *being there*:
	## a manager who compares the six-mean to the per-rotation figures finds the
	## discrepancy themselves, which is the only way it teaches anything.


## **Six rotations, and the gap between them.**
##
## The team panel above averages every starter into every category, which is a
## fiction the sport does not contain: three of your six are at the net and
## three are behind the line, and which three changes every point. A wall of two
## middles is a different object from a wall with the setter in it, and a mean
## has already added them together.
##
## The row that matters is **spread** -- best rotation minus worst. A team that
## is excellent in rotation 2 and poor in rotation 5 is not the same team as one
## that is merely good in all six, because the opponent gets to choose: they
## serve to reach the weak rotation and stay there. A mean hides the one thing
## an opponent is looking for.
func _add_rotation_panel() -> void:
	var rotations: Dictionary = game_manager.rotations if game_manager != null else {}
	if rotations.is_empty():
		return
	var players_by_id := {}
	for player in game_manager.players:
		players_by_id[int(player.id)] = player
	var summary: Dictionary = RotationStrength.across(rotations, players_by_id)
	if Dictionary(summary.get("mean", {})).is_empty():
		return
	_heading("By rotation")

	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 3)
	_body.add_child(grid)
	var numbers: Array = rotations.keys()
	numbers.sort()
	grid.add_child(_cell(""))
	for number in numbers:
		grid.add_child(_cell("R%d" % int(number)))
	grid.add_child(_cell("MEAN"))
	grid.add_child(_cell("SPREAD"))

	var light := _light_mode()
	for axis in RotationStrength.ROTATION_AXES:
		if not Dictionary(summary["mean"]).has(axis):
			continue
		grid.add_child(_cell(str(axis)))
		var weakest := int(Dictionary(summary["weakest"]).get(axis, -1))
		for number in numbers:
			var row: Dictionary = Dictionary(summary["rotations"]).get(number, {})
			var cell := _cell("%.0f" % float(row.get(axis, 0.0)))
			## The weakest rotation on each axis is the only thing marked, and it
			## is marked in red because it is the one an opponent will serve at.
			## Marking the strongest too would make every row carry two marks and
			## say nothing about which way to look.
			if int(number) == weakest:
				cell.add_theme_color_override(
					"font_color", UIPalette.board_color(&"marker_red", light)
				)
			grid.add_child(cell)
		grid.add_child(_cell("%.0f" % float(Dictionary(summary["mean"])[axis])))
		var gap := float(Dictionary(summary["spread"]).get(axis, 0.0))
		var spread_cell := _cell("%.0f" % gap)
		if gap >= EXPOSED_SPREAD:
			spread_cell.add_theme_color_override(
				"font_color", UIPalette.board_color(&"amber", light)
			)
		grid.add_child(spread_cell)

	## No note under this table.
	##
	## It had one, defining spread and explaining why two rows read zero. Both
	## facts are already on screen: the column is headed SPREAD and sits beside
	## the six numbers it is the range of, and a row of identical figures is a
	## row of identical figures. A caption telling somebody what the number in
	## front of them means is the game not trusting its own table.


## Above this gap an axis is worth looking at rather than merely uneven.
##
## **A placeholder, and marked as one.** Measured on the seeded six the axes run
## 0.8 to 7.3 and a deliberately lopsided six reaches 11.6, so 6 sits inside the
## observed range rather than outside it -- which is the minimum bar. It is not
## yet a threshold read off a distribution of *managed* lineups, because the
## screen that produces those is the one being built. Same debt as the grade
## bands, written down in the same place.
const EXPOSED_SPREAD: float = 6.0


func _add_starter_cards() -> void:
	var starters := _starters()
	if starters.is_empty():
		return
	## No heading over the rack.
	##
	## The board said "Your six", then "Rotation by rotation", then "The six" --
	## three headings, two of which name the same thing, on a screen whose title
	## is already about confirming a lineup. A term repeated until it is a motif
	## is the writing admiring itself. Six cards under a table of six columns do
	## not need to be announced.
	## **A rack, not a list.** The draft's whole argument for the card: six
	## objects side by side are compared *across*, and six rows are read *down*.
	## The question this screen asks -- is this the team -- is a comparison.
	var rack := HFlowContainer.new()
	rack.add_theme_constant_override("h_separation", 18)
	rack.add_theme_constant_override("v_separation", 18)
	_body.add_child(rack)
	var slot := 0
	for player in starters:
		slot += 1
		rack.add_child(VoliCardScene.build(
			player, _slot_number(slot), _light_mode(), _is_libero(player)
		))


## Which rotation slot the nth starter is standing in.
##
## The lineup array is in order 1..6 and the court numbers them anticlockwise
## from right back, so this is a relabelling and not a rearrangement. Written
## out because the two orders are easy to confuse and a lineup drawn in the
## wrong one looks entirely plausible.
const SLOT_ORDER: Array[int] = [1, 2, 3, 4, 5, 6]


func _slot_number(index: int) -> int:
	return SLOT_ORDER[clampi(index - 1, 0, SLOT_ORDER.size() - 1)]


## **A libero is not a seventh court position.**
##
## The lineup carries seven ids and the first build drew seven cards, two of
## them numbered 6 -- because `_slot_number` clamps and the seventh had nowhere
## to go. That is a drawing of a rotation that cannot exist.
##
## A libero is a *swap* for whoever is in middle back, which is why the draft
## tucks their card under that slot rather than beside it. They keep a card,
## because the question "could this person go on" is exactly what a card
## answers, and they lose the slot number, because they do not have one.
func _is_libero(player: Resource) -> bool:
	var team: Resource = game_manager.team if game_manager != null else null
	if team == null:
		return false
	return int(player.id) in team.libero_ids


## The board's own light state.
##
## Read off the palette's own test rather than tracked here, so the board cannot
## disagree with the theme walk that coloured everything around it.
func _light_mode() -> bool:
	return UIPalette.control_is_light(self)


func _add_tray() -> void:
	var tray := BoardTrayScene.new()
	tray.light_mode = _light_mode()
	tray.caption = "MATCH CENTRE · LOCK-IN"
	tray.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(tray)


## The court and the opponent's figures, side by side.
##
## They belong on one line because they are the two halves of the same question:
## this is who is on court, and this is what the other side did last time. Read
## apart they are a diagram and a table; read together they are the argument for
## changing the lineup.
func _add_court_and_opponent() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 26)
	_body.add_child(row)

	var court := BoardCourtScene.new()
	court.light_mode = _light_mode()
	var slot := 0
	for player in _starters():
		if _is_libero(player):
			continue
		slot += 1
		if slot > SLOT_ORDER.size():
			break
		var number := _slot_number(slot)
		var familiarity := int(
			player.position_familiarity.get(player.position_role, 0)
		)
		var stage := str(FatigueModel.stage_name(float(player.fatigue)))
		## The court says one thing about quality and only one: whether this voli
		## is a problem *in this slot*. Fatigue and familiarity are the two ways
		## that is true, so they share the mark rather than each getting one.
		var alarm := ""
		if stage == "laboured" or familiarity < VoliCardScene.FAMILIARITY_WARNING:
			alarm = "warn"
		if stage == "spent":
			alarm = "bad"
		court.slots[number] = {"label": str(number), "alarm": alarm}
	row.add_child(court)

	var beside := VBoxContainer.new()
	beside.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	beside.add_theme_constant_override("separation", 6)
	row.add_child(beside)
	var held := _body
	_body = beside
	_add_opponent_panel()
	_body = held


## The three-letter tags the board writes categories as.
##
## A card is 262px in the draft and "Setting / Control" is not going on it.
## Spelled here rather than derived, because a truncation rule that happened to
## produce readable tags for these six would produce nonsense for the seventh.
const AXIS_TAGS := {
	"Attacking": "ATK", "Defensive": "DEF", "Setting / Control": "SET",
	"Physical": "PHY", "Serving": "SRV", "Mental / Tactical": "MTL",
}


func _axis_short(axis: String) -> String:
	return str(AXIS_TAGS.get(axis, axis.substr(0, 3).to_upper()))


func _starters() -> Array:
	var team: Resource = game_manager.team if game_manager != null else null
	if team == null:
		return []
	var found: Array = []
	for raw_id in team.starting_player_ids:
		for player in game_manager.players:
			if int(player.id) == int(raw_id):
				found.append(player)
				break
	return found


## The fixture this screen is standing in front of.
##
## The *active* one, not the first uncompleted one. They are usually the same
## and the difference is the whole point of the screen: `prepare_fixture` has
## already run by the time the board is shown, so `active_fixture_id` names the
## match about to be played, while "first uncompleted" is a guess that goes wrong
## the moment a fixture is played out of calendar order.
func _next_fixture() -> Resource:
	if career_manager == null or career_manager.career == null:
		return null
	var active := int(career_manager.career.active_fixture_id)
	if active >= 0:
		var prepared: Resource = career_manager.fixture_by_id(active)
		if prepared != null:
			return prepared
	for fixture in career_manager.career.fixtures:
		if not bool(fixture.completed):
			return fixture
	return null


## Completed meetings with this opponent, most recent first.
func _completed_against(opponent_name: String) -> Array:
	var found: Array = []
	if career_manager == null or career_manager.career == null:
		return found
	for fixture in career_manager.career.fixtures:
		if bool(fixture.completed) and str(fixture.opponent_name) == opponent_name:
			found.append(fixture)
	found.sort_custom(func(a, b): return int(a.week) > int(b.week))
	return found


## Every `*_errors` counter one side accumulated.
##
## `MatchStatistics` keeps one per contact type rather than a total, so the total
## is a sum over whatever types occurred rather than a field to read -- and a
## hardcoded list of contact names here would go stale the moment a new one is
## counted.
func _error_total(side: Dictionary) -> int:
	var total := 0
	for key in side:
		if str(key).ends_with("_errors"):
			total += int(side[key])
	return total


## A heading on a board is written, not typeset.
func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", BoardFace)
	label.add_theme_font_size_override("font_size", 20)
	_body.add_child(label)


func _note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("font", BoardHand)
	label.modulate = Color(1.0, 1.0, 1.0, 0.62)
	_body.add_child(label)


## Every figure on the board is in the same hand as every other figure, because
## one person wrote all of it in one go. Short Stack is that hand; the emphasis
## is size, not a second typeface, for the same reason.
func _cell(text: String, emphasised: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", BoardHand)
	label.add_theme_font_size_override("font_size", 16 if emphasised else 14)
	return label
