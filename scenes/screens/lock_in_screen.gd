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
const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const FatigueModel := preload("res://scripts/simulation/fatigue_model.gd")

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
	_add_fixture_line()
	_add_opponent_panel()
	_add_team_panel()
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
	_heading("Your six")
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
		var grade := AttributeProfiles.grade(mean)
		## Marked only at the ends. A balanced side draws no marks at all, which
		## is how the panel stays quiet most weeks by construction rather than by
		## a tuning pass.
		##
		## Off the *tier*, not off a list of grade letters. The first draft here
		## tested `grade in ["D", "E", "F", "C-"]` -- and `grade()` has never
		## returned E or F, so two thirds of that list were unreachable and would
		## have stayed unreachable silently. `grade_tier` returns exactly five
		## values and every one of them is named below.
		var mark := ""
		match AttributeProfiles.grade_tier(mean):
			"D", "C":
				mark = "!"
			"S", "A":
				mark = "✓"
		grid.add_child(_cell(mark))
		grid.add_child(_cell(str(axis)))
		grid.add_child(_cell("%.1f  %s" % [mean, grade]))
	_note(
		"Averaged across all six starters, which puts a libero in the attack "
		+ "figure. The functional axes that fix that are specified in "
		+ "TEAM_ATTRIBUTE_WHEEL.md and are not built yet."
	)


func _add_starter_cards() -> void:
	var starters := _starters()
	if starters.is_empty():
		return
	_heading("The six")
	for player in starters:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 14)
		_body.add_child(line)
		line.add_child(_cell(str(player.display_name), true))
		line.add_child(_cell(str(player.position_role)))
		line.add_child(_cell("%s · %d" % [str(player.home_region), int(player.age)]))
		var stage := str(FatigueModel.stage_name(float(player.fatigue)))
		line.add_child(_cell("%s %.2f" % [stage.capitalize(), float(player.fatigue)]))
		line.add_child(_cell("form %+.2f" % float(player.current_form)))
		line.add_child(_cell("conf %+.2f" % float(player.match_confidence)))
		var familiarity := int(
			player.position_familiarity.get(player.position_role, 0)
		)
		line.add_child(_cell(
			"slot %d%s" % [familiarity, "  !" if familiarity < 50 else ""]
		))


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


func _heading(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 18)
	_body.add_child(label)


func _note(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.modulate = Color(1.0, 1.0, 1.0, 0.62)
	_body.add_child(label)


func _cell(text: String, emphasised: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	if emphasised:
		label.add_theme_font_size_override("font_size", 15)
	return label
