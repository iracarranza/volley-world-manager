class_name VolleyballCareerDashboard
extends Control

signal play_match_requested
signal title_requested

const Training := preload("res://scripts/systems/training_system.gd")
const CareerManagerScript := preload("res://scripts/managers/career_manager.gd")
const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const Familiarity := preload("res://scripts/systems/familiarity_system.gd")
const WHEEL_PROFILES: Array[String] = AttributeProfiles.PROFILE_NAMES
const WHEEL_TOOLTIPS := {
	"Power": "Usable hitting power derived from power transfer, mass, explosiveness, transition speed, arm speed, and approach timing.",
	"Deception": "Selling a full attack before tipping, wiping, or rolling, and deliberately using blockers' hands to score or create an advantageous deflection.",
	"Finesse": "Precise control of placement, depth, angle, and touch.",
	"Approach Timing": "Arriving in a balanced hitting window relative to the set.",
	"Shot Variety": "The number of credible attack solutions available to the player.",
	"Reception Technique": "Platform angle and directional control on ordinary contacts.",
	"Reception Balance": "Maintaining platform quality while moving, reaching, or contacting near the edge of range.",
	"Reception Stability": "Withstanding high ball speed without the platform breaking down.",
	"Defensive Range": "Baseline range derived from movement, anticipation, reach, control, and stamina; actual rally range also depends on ball-flight time and position.",
	"Block Timing": "Matching jump and hand penetration to the attacker's contact.",
	"Dig Control": "Turning a defensive touch into a playable ball rather than merely making contact.",
	"Set Accuracy": "Delivering the ball to the intended contact window.",
	"Set Balance": "Maintaining setting quality while moving or reaching.",
	"Set Stability": "Maintaining clean contact against difficult incoming pace and spin.",
	"Tempo Control": "Controlling release timing and the attacker's contact rhythm.",
	"Set Disguise": "Hiding the intended target and release direction.",
	"Hand Control": "Fine manipulation of height, spin, and touch on overhead contacts.",
	"Acceleration": "How quickly the player reaches useful movement speed.",
	"Lateral Speed": "Side-to-side movement speed used in blocking and floor defense.",
	"Transition Speed": "Speed moving between phases and into an approach.",
	"Explosiveness": "How quickly the player accesses maximum jump capacity.",
	"Jump Capacity": "The player's maximum available jumping reach rating.",
	"Stamina": "Capacity to preserve physical execution through workload and fatigue.",
	"Serve Power": "Maximum velocity and force available on a serve.",
	"Serve Technique": "Contact quality and ability to create the intended spin or float.",
	"Serve Placement": "Precision targeting zones, seams and individual receivers.",
	"Serve Consistency": "Ability to reproduce a legal controlled serve without errors.",
	"Serve Aggression": "Natural willingness and ability to increase pressure at greater risk.",
	"Serve Variation": "Ability to vary trajectory, pace, depth and serve type.",
	"Accuracy": "Precision hitting the intended target rather than merely clearing the block.",
}

@onready var CareerManager: CareerManagerScript = get_node("/root/CareerManager")
@onready var organization_label: Label = %OrganizationLabel
@onready var date_label: Label = %DateLabel
@onready var section_title: Label = %SectionTitle
@onready var sections: TabContainer = %Sections
@onready var home_summary: RichTextLabel = %HomeSummary
@onready var roster_list: ItemList = %RosterList
@onready var roster_detail: RichTextLabel = %RosterDetail
@onready var raw_attributes: RichTextLabel = %RawAttributes
@onready var player_attribute_wheel: Control = %PlayerAttributeWheel
@onready var transfer_player_attribute_wheel: Control = %TransferPlayerAttributeWheel
@onready var wheel_profile_option: OptionButton = %WheelProfileOption
@onready var position_training_option: OptionButton = %PositionTrainingOption
@onready var position_training_summary: Label = %PositionTrainingSummary
@onready var lineup_status_option: OptionButton = %LineupStatusOption
@onready var roster_status_label: Label = %RosterStatusLabel
@onready var team_summary: RichTextLabel = %TeamSummary
@onready var training_option: OptionButton = %TrainingOption
@onready var training_description: Label = %TrainingDescription
@onready var transfer_list: ItemList = %TransferList
@onready var transfer_detail: RichTextLabel = %TransferDetail
@onready var sign_button: Button = %SignButton
@onready var fixture_list: ItemList = %FixtureList
@onready var fixture_detail: RichTextLabel = %FixtureDetail
@onready var play_match_button: Button = %PlayMatchButton
@onready var status_label: Label = %StatusLabel

var selected_transfer_id: int = -1
var selected_fixture_id: int = -1
var selected_roster_id: int = -1


func _ready() -> void:
	for button in [%HomeNav, %RosterNav, %TeamNav, %TransfersNav, %CompetitionNav]:
		button.pressed.connect(_navigate.bind(button.get_meta("section")))
	%SaveButton.pressed.connect(_save)
	%TitleButton.pressed.connect(func() -> void: title_requested.emit())
	%AdvanceWeekButton.pressed.connect(_advance_week)
	%ApplyTrainingButton.pressed.connect(_apply_training_focus)
	training_option.item_selected.connect(_training_selected)
	roster_list.item_selected.connect(_roster_selected)
	wheel_profile_option.item_selected.connect(_wheel_profile_selected)
	%AssignPositionTrainingButton.pressed.connect(_assign_position_training)
	%UsePositionButton.pressed.connect(_use_trained_position)
	%ApplyLineupStatusButton.pressed.connect(_apply_lineup_status)
	%ReturnToPoolButton.pressed.connect(_return_to_pool)
	position_training_option.item_selected.connect(_position_training_preview)
	transfer_list.item_selected.connect(_transfer_selected)
	sign_button.pressed.connect(_sign_transfer)
	fixture_list.item_selected.connect(_fixture_selected)
	play_match_button.pressed.connect(_play_fixture)
	CareerManager.career_changed.connect(refresh)
	CareerManager.week_advanced.connect(func(_report: Dictionary) -> void: refresh())
	CareerManager.transfer_pool_changed.connect(refresh)
	for activity_name in Training.activity_names():
		training_option.add_item(activity_name)
	for profile_name in WHEEL_PROFILES:
		wheel_profile_option.add_item(profile_name)
	position_training_option.add_item("None")
	for position_name in Familiarity.POSITIONS: position_training_option.add_item(position_name)
	for card in [%RosterCard, %TeamCard, %TransfersCard, %CompetitionCard]:
		card.section_requested.connect(_navigate)
	refresh()
	_navigate("Home")


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_R:
			_navigate("Roster")
		KEY_T:
			_navigate("Team")
		KEY_E:
			_navigate("Transfers")
		KEY_V:
			_navigate("Competition")
		KEY_SPACE:
			if sections.current_tab == 0:
				_advance_week()
			else:
				_navigate("Home")
		_:
			return
	get_viewport().set_input_as_handled()


func refresh() -> void:
	if not CareerManager.has_career():
		return
	organization_label.text = "%s · %s" % [CareerManager.career.organization_name,
		CareerManager.career.organization_type]
	date_label.text = CareerManager.date_text()
	_refresh_home()
	_refresh_roster()
	_refresh_team()
	_refresh_transfers()
	_refresh_competition()


func _navigate(section_name: String) -> void:
	var names := ["Home", "Roster", "Team", "Transfers", "Competition"]
	sections.current_tab = maxi(names.find(section_name), 0)
	section_title.text = section_name


func _refresh_home() -> void:
	var fixture := CareerManager.next_fixture()
	var unavailable := 0
	var morale_total := 0.0
	for player in GameManager.players:
		if player.availability != "Available":
			unavailable += 1
		morale_total += player.morale
	var average_morale := morale_total / maxf(float(GameManager.players.size()), 1.0)
	home_summary.text = "[font_size=24][b]%s[/b][/font_size]\n%s · %s\nReputation %d/100 · Funds $%d\n\n[b]Next fixture[/b]\n%s\n\n[b]Weekly plan[/b]\n%s · Team familiarity %d%%\n\n[b]Squad[/b]\n%d registered · %d unavailable · Average morale %d%%" % [
		CareerManager.career.organization_name, CareerManager.career.region,
		CareerManager.career.identity, CareerManager.career.reputation,
		CareerManager.career.finances,
		"Week %d vs %s" % [fixture.week, fixture.opponent_name] if fixture != null else "No scheduled fixture",
		CareerManager.career.training_focus,
		roundi(GameManager.team.tactical_familiarity * 100.0),
		GameManager.team.player_ids.size(), unavailable, roundi(average_morale * 100.0)]
	%RosterCard.set_summary("%d registered players · %d unavailable" % [GameManager.team.player_ids.size(), unavailable])
	%TeamCard.set_summary("%s identity · %s training" % [CareerManager.career.identity, CareerManager.career.training_focus])
	%TransfersCard.set_summary("%d regional candidates · $%d available" % [CareerManager.career.transfer_pool.size(), CareerManager.career.finances])
	%CompetitionCard.set_summary("%s" % ("Week %d vs %s" % [fixture.week, fixture.opponent_name] if fixture != null else "Schedule complete"))


## Live lineup completeness, shown where the edit happens rather than only
## later on the fixture tab. Benching a starter clears their rotation slot
## with no autofill -- deliberately, since silently promoting a bench player
## is its own way to be surprised mid-match -- so the vacancy has to be visible
## immediately or it goes unnoticed until "Run Rally" refuses to start.
func _refresh_roster_status() -> void:
	var errors := GameManager.match_roster_errors()
	if errors.is_empty():
		roster_status_label.text = "Lineup complete: six rotation slots filled, no conflicts."
		roster_status_label.remove_theme_color_override("font_color")
	else:
		roster_status_label.text = "Lineup incomplete -- %s" % "; ".join(errors)
		roster_status_label.add_theme_color_override("font_color", Color(0.95, 0.55, 0.35))


func _refresh_roster() -> void:
	_refresh_roster_status()
	roster_list.clear()
	for player_id in GameManager.team.player_ids:
		var player := GameManager.player_by_id(player_id)
		if player == null:
			continue
		var marker := " · C" if player.id == GameManager.team.captain_id else ""
		roster_list.add_item("%s  %s%s\nAbility %s · Potential %s" % [
			player.position_code, player.display_name, marker,
			AttributeProfiles.grade(float(player.current_ability_score())),
			AttributeProfiles.grade(float(player.potential))])
		roster_list.set_item_metadata(roster_list.item_count - 1, player.id)
	if roster_list.item_count > 0:
		roster_list.select(0)
		_roster_selected(0)


func _roster_selected(index: int) -> void:
	var player := GameManager.player_by_id(int(roster_list.get_item_metadata(index)))
	if player == null:
		return
	selected_roster_id = player.id
	var key_attributes := _key_attributes(player)
	roster_detail.text = "[font_size=24][b]%s[/b][/font_size]  %s\n%s · Age %d · %d pro seasons\nAvailability: %s · Morale %d%% · Fatigue %d%%\n\n[b]Ability[/b]\nCurrent: %s\nPotential: %s\n[color=#8294ad]Current grade is weighted for this player's position. The wheel's outer line shows potential on every axis.[/color]\n\n[b]Key attributes[/b]\n%s\n\n[b]Measurements[/b]\n%.0f cm · %.0f kg · %.0f cm wingspan\n\nCurrent rotation: %s" % [
		player.display_name, player.position_code, player.position_role, player.age,
		player.professional_experience, player.availability,
		roundi(player.morale * 100.0), roundi(player.fatigue * 100.0),
		AttributeProfiles.grade(float(player.current_ability_score())),
		AttributeProfiles.grade(float(player.potential)),
		key_attributes, player.height_cm, player.mass_kg, player.wingspan_cm,
		"Slot %d" % GameManager.current_lineup().slot_for_player(player.id) if GameManager.current_lineup().slot_for_player(player.id) >= 1 else "Bench"]
	roster_detail.text += "\n\n[b]Profile[/b]\n%s-handed · Adaptability %d\nNatural: %s\n\n[b]Serve repertoire[/b]\n%s · %s proficiency" % [
		player.dominant_hand, player.adaptability, ", ".join(player.natural_positions),
		player.primary_serve_style,
		AttributeProfiles.grade(float(player.active_serve_style_score())),
	]
	_refresh_player_wheel(player)
	_refresh_position_training(player)
	lineup_status_option.select(0 if player.id in GameManager.team.starting_player_ids else 1)
	raw_attributes.text = _raw_attribute_text(player)


func _refresh_position_training(player: VolleyballPlayer) -> void:
	var target := player.position_training_target if not player.position_training_target.is_empty() else "None"
	for index in range(position_training_option.item_count):
		if position_training_option.get_item_text(index) == target: position_training_option.select(index)
	_position_training_preview(position_training_option.selected)


func _position_training_preview(_index: int) -> void:
	var player := GameManager.player_by_id(selected_roster_id)
	if player == null: return
	var target := position_training_option.get_item_text(position_training_option.selected)
	if target == "None":
		position_training_summary.text = "No individual position training assigned."
		return
	var familiarity := float(player.position_familiarity.get(target, 0.0))
	position_training_summary.text = "%s: %s (%d%%) · suitability %d%% · adaptability %d" % [target,
		Familiarity.familiarity_label(familiarity), roundi(familiarity),
		Familiarity.suitability(player, target), player.adaptability]


func _assign_position_training() -> void:
	var target := position_training_option.get_item_text(position_training_option.selected)
	var error: String = GameManager.set_position_training(selected_roster_id, target)
	_set_status(error if not error.is_empty() else "Position training assignment saved.", not error.is_empty())

func _use_trained_position() -> void:
	var target := position_training_option.get_item_text(position_training_option.selected)
	var error: String = GameManager.assign_player_position(selected_roster_id, target)
	_set_status(error if not error.is_empty() else "Roster position updated; rotation sheets remain separate.", not error.is_empty())
	refresh()

func _apply_lineup_status() -> void:
	var error: String = GameManager.set_player_starting(selected_roster_id, lineup_status_option.selected == 0)
	_set_status(error if not error.is_empty() else "Testing lineup updated.", not error.is_empty())
	refresh()

func _return_to_pool() -> void:
	var error: String = CareerManager.release_to_pool(selected_roster_id)
	_set_status(error if not error.is_empty() else "Player returned to the testing pool.", not error.is_empty())
	refresh()


func _wheel_profile_selected(_index: int) -> void:
	var player := GameManager.player_by_id(selected_roster_id)
	if player != null:
		_refresh_player_wheel(player)


func _refresh_player_wheel(player: VolleyballPlayer) -> void:
	var profile_name := wheel_profile_option.get_item_text(wheel_profile_option.selected) \
		if wheel_profile_option.selected >= 0 else "Player Profile"
	var profile := AttributeProfiles.summary_profile(player) if profile_name == "Player Profile" \
		else AttributeProfiles.detailed_profile(player, profile_name)
	## Fully accurate today: this reads the player's real generated ceilings,
	## the same data `potential` is scored from. When scouting exists, an
	## unscouted prospect's outer line should come from an estimate derived
	## from this data (a range, a fogged band) rather than this data itself --
	## the ceilings stay real; what changes is whether the viewer is shown them
	## directly.
	var potential_profile := AttributeProfiles.summary_profile(player, true) \
		if profile_name == "Player Profile" \
		else AttributeProfiles.detailed_profile(player, profile_name, true)
	var tooltips := AttributeProfiles.PROFILE_TOOLTIPS if profile_name == "Player Profile" \
		else WHEEL_TOOLTIPS
	player_attribute_wheel.set_profile(profile, tooltips, true, potential_profile)


func _raw_attribute_text(player: VolleyballPlayer) -> String:
	## Reads `AttributeProfiles.CATEGORY_ATTRIBUTES` rather than a second,
	## hand-typed grouping. This table and the wheel used to keep independent
	## category lists with different names and different membership -- this
	## one had a "Reception" bucket the wheel didn't, and neither had
	## attack_accuracy at all. One definition means an attribute added to the
	## player model only needs placing once to appear correctly everywhere.
	var result := "[table=3]"
	for group_name in AttributeProfiles.CATEGORY_ATTRIBUTES:
		var lines: Array[String] = ["[b]%s[/b]" % group_name]
		for attribute_name in AttributeProfiles.CATEGORY_ATTRIBUTES[group_name]:
			var display_name := str(attribute_name).replace("_", " ").capitalize()
			if str(attribute_name) == "reception":
				display_name = "Reception Technique"
			elif str(attribute_name) == "attack_power":
				display_name = "Power Transfer"
			lines.append("%s: %d" % [display_name,
				int(player.get(str(attribute_name)))])
		result += "[cell]%s[/cell]" % "\n".join(lines)
	return result + "[/table]"


func _key_attributes(player: VolleyballPlayer) -> String:
	match player.position_role:
		"Setter": return "Setting %d · Vision %d · Decisions %d · Balance %d" % [player.set_accuracy, player.court_vision, player.decision_making, player.set_balance]
		"Libero": return "Reception %d · Ball control %d · Anticipation %d · Stability %d" % [player.reception, player.ball_control, player.anticipation, player.reception_stability]
		"Middle Blocker": return "Block timing %d · Jump %d · Lateral speed %d · Attack %d" % [player.block_timing, player.jump_reach, player.lateral_speed, player.attack_power]
		_: return "Attack %d · Accuracy %d · Reception %d · Approach %d" % [player.attack_power, player.attack_accuracy, player.reception, player.approach_timing]


func _refresh_team() -> void:
	team_summary.text = "[font_size=22][b]%s Identity[/b][/font_size]\n%s\nTactical familiarity %d%%\nCaptain: %s · Libero: %s\n\n[b]Depth chart[/b]\n%s" % [
		GameManager.team.team_name, GameManager.team.identity,
		roundi(GameManager.team.tactical_familiarity * 100.0),
		_player_name(GameManager.team.captain_id),
		_player_name(GameManager.team.libero_ids[0]) if not GameManager.team.libero_ids.is_empty() else "None",
		_depth_chart_text()]
	for index in range(training_option.item_count):
		if training_option.get_item_text(index) == CareerManager.career.training_focus:
			training_option.select(index)
	_training_selected(training_option.selected)


func _training_selected(index: int) -> void:
	if index < 0:
		return
	var activity_name := training_option.get_item_text(index)
	var activity := Training.description(activity_name)
	training_description.text = "%s\nAttributes: %s · Fatigue %+d%% · Morale %+d%%" % [
		activity.description, ", ".join(activity.attributes),
		roundi(float(activity.fatigue) * 100.0), roundi(float(activity.morale) * 100.0)]


func _apply_training_focus() -> void:
	var error := CareerManager.set_training_focus(training_option.get_item_text(training_option.selected))
	_set_status(error if not error.is_empty() else "Weekly training focus saved.", not error.is_empty())


func _refresh_transfers() -> void:
	transfer_list.clear()
	for player_resource in CareerManager.career.transfer_pool:
		var player := player_resource as VolleyballPlayer
		transfer_list.add_item("%s  %s · Age %d" % [player.position_code, player.display_name, player.age])
		transfer_list.set_item_metadata(transfer_list.item_count - 1, player.id)
	if transfer_list.item_count > 0:
		transfer_list.select(0)
		_transfer_selected(0)
	else:
		transfer_detail.text = "No regional candidates currently available."
		sign_button.disabled = true


func _transfer_selected(index: int) -> void:
	selected_transfer_id = int(transfer_list.get_item_metadata(index))
	var player := _market_player(selected_transfer_id)
	if player == null:
		return
	transfer_detail.text = "[font_size=22][b]%s[/b][/font_size] · %s\nAge %d · Ability %s · Potential %s\n%s\n\nPrototype testing: freely add this player to the roster." % [
		player.display_name, player.position_role, player.age,
		AttributeProfiles.grade(float(player.current_ability_score())),
		AttributeProfiles.grade(float(player.potential)), _key_attributes(player)]
	## Same full-summary view as the roster's "Player Profile" wheel, with the
	## same accurate potential outline -- see the note in
	## `_refresh_player_wheel()` for what changes here once scouting exists.
	transfer_player_attribute_wheel.set_profile(
		AttributeProfiles.summary_profile(player), AttributeProfiles.PROFILE_TOOLTIPS,
		true, AttributeProfiles.summary_profile(player, true),
	)
	sign_button.disabled = false
	sign_button.text = "Add to Testing Roster"


func _sign_transfer() -> void:
	var error := CareerManager.sign_transfer(selected_transfer_id)
	_set_status(error if not error.is_empty() else "Player signed to the active roster.", not error.is_empty())
	refresh()


func _refresh_competition() -> void:
	fixture_list.clear()
	for fixture in CareerManager.career.fixtures:
		fixture_list.add_item("Week %d · %s · %s" % [fixture.week, fixture.opponent_name, fixture.result_text()])
		fixture_list.set_item_metadata(fixture_list.item_count - 1, fixture.id)
	if fixture_list.item_count > 0:
		fixture_list.select(0)
		_fixture_selected(0)


func _fixture_selected(index: int) -> void:
	selected_fixture_id = int(fixture_list.get_item_metadata(index))
	var fixture := CareerManager.fixture_by_id(selected_fixture_id)
	if fixture == null:
		return
	var due := int(fixture.week) <= int(CareerManager.career.absolute_week)
	fixture_detail.text = "[font_size=22][b]%s[/b][/font_size]\n%s · Week %d\nStatus: %s\n\nFormat: Best of %d · Sets to %d · Win by %d\n\nRoster check: %s" % [
		fixture.opponent_name, fixture.competition_name, fixture.week, fixture.result_text(),
		CareerManager.career.match_format.best_of_sets,
		CareerManager.career.match_format.regular_set_target,
		CareerManager.career.match_format.win_by,
		"Ready" if GameManager.match_roster_errors().is_empty() else GameManager.match_roster_errors()[0]]
	play_match_button.disabled = fixture.completed or not due \
		or not GameManager.match_roster_errors().is_empty()


func _play_fixture() -> void:
	var error := CareerManager.prepare_fixture(selected_fixture_id)
	if not error.is_empty():
		_set_status(error, true)
		return
	play_match_requested.emit()


func _advance_week() -> void:
	var error := CareerManager.advance_week()
	_set_status(error if not error.is_empty() else "Week advanced and training applied.", not error.is_empty())


func _save() -> void:
	var error := CareerManager.save_career()
	_set_status(error if not error.is_empty() else "Career saved.", not error.is_empty())


func _depth_chart_text() -> String:
	var lines: Array[String] = []
	for role_name in ["Setter", "Outside Hitter", "Middle Blocker", "Opposite", "Libero"]:
		var names: Array[String] = []
		for player_id in GameManager.team.depth_chart.get(role_name, []):
			names.append(_player_name(int(player_id)))
		lines.append("%s: %s" % [role_name, " → ".join(names)])
	return "\n".join(lines)


func _player_name(player_id: int) -> String:
	var player := GameManager.player_by_id(player_id)
	return player.display_name if player != null else "Unassigned"


func _market_player(player_id: int) -> VolleyballPlayer:
	for resource in CareerManager.career.transfer_pool:
		if int(resource.id) == player_id:
			return resource as VolleyballPlayer
	return null


func _set_status(message: String, error: bool = false) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", Color("ef6461") if error else Color("62b4ff"))
