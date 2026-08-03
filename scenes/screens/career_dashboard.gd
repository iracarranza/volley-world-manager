class_name VolleyballCareerDashboard
extends Control

signal play_match_requested
signal title_requested

const Training := preload("res://scripts/systems/training_system.gd")
const CareerManagerScript := preload("res://scripts/managers/career_manager.gd")
const AttributeProfiles := preload("res://scripts/systems/attribute_profile_system.gd")
const Familiarity := preload("res://scripts/systems/familiarity_system.gd")
const SixnetLeague := preload("res://scripts/systems/sixnet_league.gd")
const Regions := preload("res://scripts/data/regions.gd")
const WHEEL_PROFILES: Array[String] = AttributeProfiles.PROFILE_NAMES
const ROSTER_RAIL_COLLAPSED_WIDTH: float = 42.0
const ROSTER_RAIL_EXPANDED_WIDTH: float = 440.0
const RAW_ATTRIBUTE_LABELS := {
	"attack_power": "Power Transfer",
	"attack_accuracy": "Attack Accuracy",
	"reception": "Reception Tech",
	"reception_stability": "Pace Resistance",
	"ball_control": "Touch Control",
	"dig_control": "Dig Placement",
	"decision_making": "Decisions",
}
const WHEEL_TOOLTIPS := {
	"Power": "Usable hitting power derived from power transfer, mass, explosiveness, transition speed, arm speed, and approach timing.",
	"Tooling": "Deliberately using a blocker's hands to score or create an advantageous deflection.",
	"Feinting": "Selling a full attack before tipping, wiping, or rolling to disguise a soft shot.",
	"Finesse": "Precise control of placement, depth, angle, and touch.",
	"Approach Timing": "Arriving in a balanced hitting window relative to the set.",
	"Shot Variety": "The number of credible attack solutions available to the player.",
	"Reception Technique": "Platform angle and directional control on ordinary contacts.",
	"Reception Balance": "Maintaining platform quality while moving, reaching, or contacting near the edge of range.",
	"Pace Resistance": "Withstanding high ball speed without the platform breaking down.",
	"Defensive Range": "Baseline range derived purely from movement, reach, and stamina; actual rally range also depends on ball-flight time, position, hands (see Touch Control) and reading the play (see Anticipation).",
	"Touch Control": "Cushioning a hard-driven touch so the ball remains playable.",
	"Block Timing": "Matching jump and hand penetration to the attacker's contact.",
	"Dig Placement": "Directing a successful floor-defense contact toward a useful target.",
	"Set Accuracy": "Delivering the ball to the intended contact window.",
	"Set Balance": "Maintaining setting quality while moving or reaching.",
	"Set Stability": "Maintaining clean contact against difficult incoming pace and spin.",
	"Tempo Control": "Controlling release timing and the attacker's contact rhythm.",
	"Set Disguise": "Hiding the intended target and release direction.",
	"Hand Control": "Fine manipulation of height, spin, and touch on overhead contacts.",
	"Unpredictability": "Varying tempo and target selection across a match rather than falling into readable distribution patterns.",
	"Acceleration": "How quickly the player reaches useful movement speed.",
	"Lateral Speed": "Side-to-side movement speed used in blocking and floor defense.",
	"Transition Speed": "Speed moving between phases and into an approach.",
	"Explosiveness": "How quickly the player accesses maximum jump capacity.",
	"Jump Capacity": "The player's maximum available jumping reach rating.",
	"Engine": "The combination of physical stamina and willingness to repeat high-effort actions.",
	"Reach": "Standing reach rating derived from height and wingspan; a fixed physical trait, not a trainable skill.",
	"Serve Power": "Maximum velocity and force available on a serve.",
	"Serve Technique": "Contact quality and ability to create the intended spin or float.",
	"Serve Placement": "Precision targeting zones, seams and individual receivers.",
	"Serve Consistency": "Ability to reproduce a legal controlled serve without errors.",
	"Serve Aggression": "Natural willingness and ability to increase pressure at greater risk.",
	"Serve Variation": "Ability to vary trajectory, pace, depth and serve type.",
	"Repertoire": "Breadth of competent serve styles rather than reliance on a single signature serve.",
	"Accuracy": "Precision hitting the intended target rather than merely clearing the block.",
	"Court Vision": "Spatial awareness of teammates, opponents, and open court.",
	"Anticipation": "Predicting a specific opponent's next action before contact.",
	"Decision Making": "Choosing the right option under time pressure.",
	"Composure": "Maintaining execution quality under pressure or after a mistake.",
	"Tactical Discipline": "Sticking to assignment and system rather than improvising off-plan.",
	"Creativity": "Generating effective improvised solutions and adapting them to changing conditions.",
	"Leadership": "Stabilizing teammates and setting the emotional standard under pressure.",
	"Overall": "Aggregate across all six category scores, weighted toward the average with a bonus for a standout strength and a small penalty for a weak spot.",
}

@onready var CareerManager: CareerManagerScript = get_node("/root/CareerManager")
@onready var organization_label: Label = %OrganizationLabel
@onready var date_label: Label = %DateLabel
@onready var section_title: Label = %SectionTitle
@onready var sections: TabContainer = %Sections
@onready var current_section_button: Button = %CurrentSectionButton
@onready var nav_dropdown: Control = %NavDropdown
@onready var dropdown_panel: PanelContainer = %DropdownPanel
@onready var click_catcher: Control = %ClickCatcher
@onready var home_summary: RichTextLabel = %HomeSummary
@onready var news_panel: RichTextLabel = %NewsPanel
@onready var roster_split: HSplitContainer = %Roster
@onready var roster_rail: VBoxContainer = %RosterRail
@onready var roster_list_toggle: Button = %RosterListToggle
@onready var roster_list: ItemList = %RosterList
@onready var roster_identity_panel: VBoxContainer = %IdentityPanel
@onready var roster_detail: RichTextLabel = %RosterDetail
@onready var player_dossier_button: Button = %PlayerDossierButton
@onready var raw_attributes: RichTextLabel = %RawAttributes
@onready var raw_title: Label = %RawTitle
@onready var player_attribute_wheel: VolleyballPlayerAttributeWheel = %PlayerAttributeWheel
@onready var transfer_player_attribute_wheel: VolleyballPlayerAttributeWheel = %TransferPlayerAttributeWheel
@onready var team_attribute_wheel: VolleyballPlayerAttributeWheel = %TeamAttributeWheel
@onready var team_wheel_caption: Label = %TeamWheelCaption
@onready var attribute_wheel_underlay: ColorRect = %AttributeWheelUnderlay
@onready var attribute_wheel_popup: PopupPanel = %AttributeWheelPopup
@onready var expanded_attribute_wheel: VolleyballPlayerAttributeWheel = %ExpandedAttributeWheel
@onready var expanded_wheel_title: Label = %ExpandedWheelTitle
@onready var expanded_wheel_context: Label = %ExpandedWheelContext
@onready var expanded_wheel_profile_label: Label = %ExpandedWheelProfileLabel
@onready var expanded_wheel_profile_option: OptionButton = %ExpandedWheelProfileOption
@onready var close_attribute_wheel_button: Button = %CloseAttributeWheelButton
@onready var player_dossier_popup: PopupPanel = %PlayerDossierPopup
@onready var player_dossier_title: Label = %PlayerDossierTitle
@onready var player_dossier_context: Label = %PlayerDossierContext
@onready var player_dossier_content: RichTextLabel = %PlayerDossierContent
@onready var close_player_dossier_button: Button = %ClosePlayerDossierButton
@onready var individual_training_roster_list: ItemList = %IndividualTrainingRosterList
@onready var position_training_option: OptionButton = %PositionTrainingOption
@onready var position_training_summary: Label = %PositionTrainingSummary
@onready var lineup_status_option: OptionButton = %LineupStatusOption
@onready var roster_status_label: Label = %RosterStatusLabel
@onready var team_summary: RichTextLabel = %TeamSummary
@onready var identity_finance_panel: RichTextLabel = %IdentityFinancePanel
@onready var training_option: OptionButton = %TrainingOption
@onready var training_description: Label = %TrainingDescription
@onready var transfer_list: ItemList = %TransferList
@onready var transfer_detail: RichTextLabel = %TransferDetail
@onready var sign_button: Button = %SignButton
@onready var fixture_list: ItemList = %FixtureList
@onready var fixture_detail: RichTextLabel = %FixtureDetail
@onready var play_match_button: Button = %PlayMatchButton
@onready var simulate_match_button: Button = %SimulateMatchButton
@onready var status_label: Label = %StatusLabel
@onready var sixnet_summary: RichTextLabel = %SixnetSummary

var selected_transfer_id: int = -1
var selected_fixture_id: int = -1
var selected_roster_id: int = -1
## The individual-training tab carries its own selection rather than sharing
## `selected_roster_id`: it is a separate list on a separate tab, and letting
## one drive the other means clicking a name on Roster silently retargets the
## Assign button somewhere the player can't see.
var selected_individual_training_id: int = -1

var _nav_buttons: Array[Button] = []
var _nav_dropdown_open: bool = false
var _nav_tween: Tween
var _roster_list_expanded: bool = false


func _ready() -> void:
	for button in [%HomeNav, %RosterNav, %TeamNav, %TransfersNav, %CompetitionNav, %SixnetNav]:
		button.pressed.connect(_navigate.bind(button.get_meta("section")))
		_nav_buttons.append(button)
	current_section_button.pressed.connect(_toggle_nav_dropdown)
	click_catcher.gui_input.connect(_click_catcher_input)
	nav_dropdown.visible = false
	dropdown_panel.modulate.a = 0.0
	%SaveButton.pressed.connect(_save)
	%TitleButton.pressed.connect(func() -> void: title_requested.emit())
	%AdvanceWeekButton.pressed.connect(_advance_week)
	%ApplyTrainingButton.pressed.connect(_apply_training_focus)
	training_option.item_selected.connect(_training_selected)
	roster_list_toggle.pressed.connect(_toggle_roster_list)
	roster_list.item_selected.connect(_roster_selected)
	player_dossier_button.pressed.connect(_open_player_dossier)
	individual_training_roster_list.item_selected.connect(_individual_training_selected)
	player_attribute_wheel.expand_requested.connect(_open_player_attribute_lab)
	team_attribute_wheel.expand_requested.connect(_open_team_attribute_lab)
	transfer_player_attribute_wheel.expand_requested.connect(_open_transfer_attribute_lab)
	expanded_wheel_profile_option.item_selected.connect(_expanded_wheel_profile_selected)
	close_attribute_wheel_button.pressed.connect(_close_attribute_lab)
	attribute_wheel_popup.close_requested.connect(_close_attribute_lab)
	attribute_wheel_popup.popup_hide.connect(_attribute_lab_hidden)
	close_player_dossier_button.pressed.connect(_close_player_dossier)
	player_dossier_popup.close_requested.connect(_close_player_dossier)
	player_dossier_popup.popup_hide.connect(_modal_hidden)
	expanded_attribute_wheel.set_expanded_presentation(true)
	expanded_attribute_wheel.set_inline_axis_labels(true)
	player_attribute_wheel.set_inline_axis_labels(true)
	%AssignPositionTrainingButton.pressed.connect(_assign_position_training)
	%UsePositionButton.pressed.connect(_use_trained_position)
	%ApplyLineupStatusButton.pressed.connect(_apply_lineup_status)
	%ReturnToPoolButton.pressed.connect(_return_to_pool)
	position_training_option.item_selected.connect(_position_training_preview)
	transfer_list.item_selected.connect(_transfer_selected)
	sign_button.pressed.connect(_sign_transfer)
	fixture_list.item_selected.connect(_fixture_selected)
	play_match_button.pressed.connect(_play_fixture)
	simulate_match_button.pressed.connect(_simulate_fixture)
	CareerManager.career_changed.connect(refresh)
	CareerManager.week_advanced.connect(func(_report: Dictionary) -> void: refresh())
	CareerManager.transfer_pool_changed.connect(refresh)
	for activity_name in Training.activity_names():
		training_option.add_item(activity_name)
	for profile_name in WHEEL_PROFILES:
		expanded_wheel_profile_option.add_item(profile_name)
	position_training_option.add_item("None")
	for position_name in Familiarity.POSITIONS: position_training_option.add_item(position_name)
	for card in [%RosterCard, %TeamCard, %TransfersCard, %CompetitionCard, %SixnetCard]:
		card.section_requested.connect(_navigate)
	refresh()
	_navigate("Home")
	_set_roster_list_expanded(false)


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if attribute_wheel_popup.visible or player_dossier_popup.visible:
		return
	var key_event := event as InputEventKey
	match key_event.keycode:
		KEY_TAB:
			## Shift+Tab keeps Godot's native reverse focus traversal -- keycode
			## alone can't tell the two apart, so the modifier is checked here
			## rather than claiming every Tab-shaped event.
			if key_event.shift_pressed:
				return
			_toggle_nav_dropdown()
		KEY_R:
			_navigate("Roster")
		KEY_T:
			_navigate("Team")
		KEY_E:
			_navigate("Transfers")
		KEY_V:
			_navigate("Competition")
		KEY_X:
			_navigate("Sixnet")
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
	_refresh_sixnet()


## The navigation menu lives in a floating overlay rather than a permanent
## 190px column, which is where the content area's extra width came from. It
## is parented directly to this Control (not to any Container) on purpose: a
## Control inside a Container has its position rewritten on every layout pass,
## which would fight the tween below and snap the panel back mid-slide.
func _toggle_nav_dropdown() -> void:
	if _nav_dropdown_open:
		_close_nav_dropdown()
	else:
		_open_nav_dropdown()


func _open_nav_dropdown() -> void:
	if _nav_dropdown_open:
		return
	_nav_dropdown_open = true
	var origin := current_section_button.global_position \
		+ Vector2(0.0, current_section_button.size.y + 4.0)
	nav_dropdown.visible = true
	## The catcher only swallows clicks while the menu is actually open,
	## otherwise it would sit invisibly over the whole dashboard eating every
	## button press underneath it.
	click_catcher.mouse_filter = Control.MOUSE_FILTER_STOP
	dropdown_panel.position = origin - Vector2(0.0, 12.0)
	dropdown_panel.modulate.a = 0.0
	if _nav_tween != null:
		_nav_tween.kill()
	_nav_tween = create_tween().set_parallel(true) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_nav_tween.tween_property(dropdown_panel, "position", origin, 0.18)
	_nav_tween.tween_property(dropdown_panel, "modulate:a", 1.0, 0.18)


func _close_nav_dropdown() -> void:
	if not _nav_dropdown_open:
		return
	_nav_dropdown_open = false
	click_catcher.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _nav_tween != null:
		_nav_tween.kill()
	_nav_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_nav_tween.tween_property(dropdown_panel, "modulate:a", 0.0, 0.12)
	_nav_tween.tween_callback(func() -> void: nav_dropdown.visible = false)


func _click_catcher_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_close_nav_dropdown()


func _navigate(section_name: String) -> void:
	var names := ["Home", "Roster", "Team", "Transfers", "Competition", "Sixnet"]
	sections.current_tab = maxi(names.find(section_name), 0)
	current_section_button.text = "%s   ▾   [Tab]" % section_name
	## Every nav button and every keyboard shortcut routes through here, so
	## highlighting and dismissal both only need saying once.
	for button in _nav_buttons:
		button.button_pressed = str(button.get_meta("section")) == section_name
	_close_nav_dropdown()
	section_title.text = section_name


func _refresh_home() -> void:
	var fixture := CareerManager.next_fixture()
	var unavailable := 0
	var satisfaction_total := 0.0
	for player in GameManager.players:
		if player.availability != "Available":
			unavailable += 1
		satisfaction_total += player.satisfaction
	var average_satisfaction := satisfaction_total \
		/ maxf(float(GameManager.players.size()), 1.0)
	home_summary.text = "[font_size=24][b]%s[/b][/font_size]\n%s · %s\nReputation %d/100 · Funds $%d\n\n[b]Next fixture[/b]\n%s\n\n[b]Weekly plan[/b]\n%s · Familiarity %d%% · Cohesion %d%%\n\n[b]Squad[/b]\n%d registered · %d unavailable · Average satisfaction %d%%" % [
		CareerManager.career.organization_name, CareerManager.career.region,
		CareerManager.career.identity, CareerManager.career.reputation,
		CareerManager.career.finances,
		"Week %d vs %s" % [fixture.week, fixture.opponent_name] if fixture != null else "No scheduled fixture",
		CareerManager.career.training_focus,
		roundi(GameManager.team.tactical_familiarity * 100.0),
		roundi(GameManager.team.cohesion * 100.0),
		GameManager.team.player_ids.size(), unavailable,
		roundi(average_satisfaction * 100.0)]
	%RosterCard.set_summary("%d registered players · %d unavailable" % [GameManager.team.player_ids.size(), unavailable])
	%TeamCard.set_summary("%s identity · %s training" % [CareerManager.career.identity, CareerManager.career.training_focus])
	%TransfersCard.set_summary("%d regional candidates · $%d available" % [CareerManager.career.transfer_pool.size(), CareerManager.career.finances])
	%CompetitionCard.set_summary("%s" % ("Week %d vs %s" % [fixture.week, fixture.opponent_name] if fixture != null else "Schedule complete"))
	%SixnetCard.set_summary(
		"Champion: %s" % CareerManager.career.sixnet_champion_region
		if not CareerManager.career.sixnet_champion_region.is_empty()
		else "%s tops regional power" % _sixnet_top_region()
	)
	_refresh_news()


## The panel flavor events will eventually feed. Until they exist it carries
## results that are already real -- completed fixtures and the reigning Sixnet
## champion -- rather than sitting empty, so the layout is exercised by live
## data and flavor events later become extra entries in the same feed instead
## of the thing that makes it work at all.
func _refresh_news() -> void:
	var entries: Array[String] = []
	if not str(CareerManager.career.sixnet_champion_region).is_empty():
		entries.append("[b]Sixnet Championship[/b]\n%s are crowned champions of the Sixnet."
			% CareerManager.career.sixnet_champion_region)
	var completed: Array[Resource] = []
	for fixture in CareerManager.career.fixtures:
		if bool(fixture.completed):
			completed.append(fixture)
	completed.sort_custom(func(a: Resource, b: Resource) -> bool: return int(a.week) > int(b.week))
	for fixture in completed.slice(0, 8):
		var won := int(fixture.home_sets) > int(fixture.opponent_sets)
		entries.append("[b]Week %d · %s[/b]\n[color=%s]%s[/color] %s vs %s" % [
			int(fixture.week), fixture.competition_name,
			"#7fd18a" if won else "#e0785c", "WIN" if won else "LOSS",
			fixture.result_text(), fixture.opponent_name])
	news_panel.text = "\n\n".join(entries) if not entries.is_empty() \
		else "[color=#8294ad]No news yet. Match results and world events will appear here as the season plays out.[/color]"


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
	_populate_roster_list(roster_list)
	if roster_list.item_count > 0:
		roster_list.select(0)
		_roster_selected(0)


func _toggle_roster_list() -> void:
	_set_roster_list_expanded(not _roster_list_expanded)


func _set_roster_list_expanded(expanded: bool) -> void:
	_roster_list_expanded = expanded
	var rail_width := ROSTER_RAIL_EXPANDED_WIDTH \
		if expanded else ROSTER_RAIL_COLLAPSED_WIDTH
	roster_rail.custom_minimum_size = Vector2(rail_width, 0.0)
	roster_split.split_offset = roundi(rail_width)
	roster_list.visible = expanded
	## The main profile uses all recovered width when the rail is minimized. In
	## expanded-list mode, only its basic identity block contracts; secondary
	## information remains in the separate dossier rather than a competing column.
	roster_identity_panel.custom_minimum_size.x = 188.0 if expanded else 310.0
	roster_list_toggle.text = "<  Collapse roster" if expanded else ">"
	roster_list_toggle.tooltip_text = (
		"Collapse the roster list" if expanded else "Expand the roster list"
	)
	_refresh_roster_profile_layout()


## Shared by the Roster tab and the individual-training tab, which show the
## same squad with the same summary line. One writer means the two lists can't
## drift apart as the line changes.
func _populate_roster_list(list: ItemList) -> void:
	list.clear()
	for player_id in GameManager.team.player_ids:
		var player := GameManager.player_by_id(player_id)
		if player == null:
			continue
		var marker := " · C" if player.id == GameManager.team.captain_id else ""
		list.add_item("%s  %s%s\nAbility %s · Potential %s" % [
			player.position_code, player.display_name, marker,
			AttributeProfiles.grade(float(player.current_ability_score())),
			AttributeProfiles.grade(float(player.potential))])
		list.set_item_metadata(list.item_count - 1, player.id)


func _roster_selected(index: int) -> void:
	var player := GameManager.player_by_id(int(roster_list.get_item_metadata(index)))
	if player == null:
		return
	selected_roster_id = player.id
	roster_detail.text = "[font_size=24][b]%s[/b][/font_size]\n[color=#91a5bd]%s / %s  |  Age %d[/color]\n[b]CA[/b] %s -> [b]PA[/b] %s  |  %s-handed\n%.0f cm  |  %.0f kg  |  %.0f cm span" % [
		player.display_name, player.position_code, player.position_role, player.age,
		AttributeProfiles.grade(float(player.current_ability_score())),
		AttributeProfiles.grade(float(player.potential)), player.dominant_hand,
		player.height_cm, player.mass_kg, player.wingspan_cm,
	]
	_refresh_player_wheel(player)
	lineup_status_option.select(0 if player.id in GameManager.team.starting_player_ids else 1)
	_refresh_roster_profile_layout()


func _refresh_roster_profile_layout() -> void:
	var player := GameManager.player_by_id(selected_roster_id)
	if player == null:
		return
	raw_title.text = "Complete Attribute Profile  |  %s  |  %s  |  %d  |  %s -> %s" % [
		player.display_name, player.position_code, player.age,
		AttributeProfiles.grade(float(player.current_ability_score())),
		AttributeProfiles.grade(float(player.potential)),
	] if _roster_list_expanded else "Complete Attribute Profile"
	raw_attributes.text = _raw_attribute_text(player, _roster_list_expanded)


func _individual_training_selected(index: int) -> void:
	var player := GameManager.player_by_id(
		int(individual_training_roster_list.get_item_metadata(index)))
	if player == null:
		return
	selected_individual_training_id = player.id
	_refresh_position_training(player)


func _refresh_position_training(player: VolleyballPlayer) -> void:
	var target := player.position_training_target if not player.position_training_target.is_empty() else "None"
	for index in range(position_training_option.item_count):
		if position_training_option.get_item_text(index) == target: position_training_option.select(index)
	_position_training_preview(position_training_option.selected)


func _position_training_preview(_index: int) -> void:
	var player := GameManager.player_by_id(selected_individual_training_id)
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
	var error: String = GameManager.set_position_training(selected_individual_training_id, target)
	_set_status(error if not error.is_empty() else "Position training assignment saved.", not error.is_empty())

func _use_trained_position() -> void:
	var target := position_training_option.get_item_text(position_training_option.selected)
	var error: String = GameManager.assign_player_position(selected_individual_training_id, target)
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


func _open_player_attribute_lab() -> void:
	var player := GameManager.player_by_id(selected_roster_id)
	if player == null:
		return
	expanded_wheel_profile_option.select(0)
	_open_attribute_lab(
		player_attribute_wheel,
		"%s / PLAYER PROFILE" % player.display_name.to_upper(),
		"ROSTER | %s | Age %d | Current %s | Potential %s" % [
			player.position_role, player.age,
			AttributeProfiles.grade(float(player.current_ability_score())),
			AttributeProfiles.grade(float(player.potential)),
		],
		true,
	)


func _open_team_attribute_lab() -> void:
	_open_attribute_lab(
		team_attribute_wheel,
		"%s / STARTING LINEUP" % GameManager.team.team_name.to_upper(),
		"TEAM OVERVIEW | Aggregate of the selected starting six",
		false,
	)


func _open_transfer_attribute_lab() -> void:
	var player := _market_player(selected_transfer_id)
	if player == null:
		return
	_open_attribute_lab(
		transfer_player_attribute_wheel,
		"%s / RECRUITMENT PROFILE" % player.display_name.to_upper(),
		"TRANSFER TARGET | %s | Age %d | Current %s | Potential %s" % [
			player.position_role, player.age,
			AttributeProfiles.grade(float(player.current_ability_score())),
			AttributeProfiles.grade(float(player.potential)),
		],
		false,
	)


func _open_attribute_lab(
	source: VolleyballPlayerAttributeWheel,
	title: String,
	context: String,
	profile_selectable: bool,
) -> void:
	if source.axes.size() < 3:
		return
	expanded_wheel_title.text = title
	expanded_wheel_context.text = context
	expanded_wheel_profile_label.visible = profile_selectable
	expanded_wheel_profile_option.visible = profile_selectable
	_copy_wheel_profile(source, expanded_attribute_wheel)
	var viewport_size := get_viewport_rect().size
	var popup_rect := Rect2i(
		20, 16,
		maxi(roundi(viewport_size.x) - 40, 760),
		maxi(roundi(viewport_size.y) - 32, 520),
	)
	attribute_wheel_underlay.visible = true
	attribute_wheel_popup.popup(popup_rect)


func _copy_wheel_profile(
	source: VolleyballPlayerAttributeWheel,
	target: VolleyballPlayerAttributeWheel,
) -> void:
	target.set_profile(
		source.profile, source.axis_tooltips, source.show_grades, source.potential_profile
	)


func _expanded_wheel_profile_selected(index: int) -> void:
	if not attribute_wheel_popup.visible or not expanded_wheel_profile_option.visible:
		return
	var player := GameManager.player_by_id(selected_roster_id)
	if player == null:
		return
	var profile_name := expanded_wheel_profile_option.get_item_text(index)
	var profile := AttributeProfiles.summary_profile(player) \
		if profile_name == "Player Profile" \
		else AttributeProfiles.detailed_profile(player, profile_name)
	var potential_profile := AttributeProfiles.summary_profile(player, true) \
		if profile_name == "Player Profile" \
		else AttributeProfiles.detailed_profile(player, profile_name, true)
	var tooltips := AttributeProfiles.PROFILE_TOOLTIPS \
		if profile_name == "Player Profile" else WHEEL_TOOLTIPS
	expanded_wheel_title.text = "%s / %s" % [
		player.display_name.to_upper(), profile_name.to_upper(),
	]
	expanded_attribute_wheel.set_profile(profile, tooltips, true, potential_profile)


func _close_attribute_lab() -> void:
	attribute_wheel_popup.hide()


func _attribute_lab_hidden() -> void:
	_modal_hidden()


func _open_player_dossier() -> void:
	var player := GameManager.player_by_id(selected_roster_id)
	if player == null:
		return
	player_dossier_title.text = player.display_name.to_upper()
	player_dossier_context.text = "%s  /  %s  /  AGE %d  /  %s -> %s" % [
		player.position_code, player.position_role.to_upper(), player.age,
		AttributeProfiles.grade(float(player.current_ability_score())),
		AttributeProfiles.grade(float(player.potential)),
	]
	player_dossier_content.text = _player_dossier_text(player)
	var viewport_size := get_viewport_rect().size
	attribute_wheel_underlay.visible = true
	player_dossier_popup.popup(Rect2i(
		28, 22, maxi(roundi(viewport_size.x) - 56, 760),
		maxi(roundi(viewport_size.y) - 44, 520),
	))


func _close_player_dossier() -> void:
	player_dossier_popup.hide()


func _modal_hidden() -> void:
	attribute_wheel_underlay.visible = \
		attribute_wheel_popup.visible or player_dossier_popup.visible


func _player_dossier_text(player: VolleyballPlayer) -> String:
	var lineup_slot := GameManager.current_lineup().slot_for_player(player.id)
	var rotation_text := "Slot %d" % lineup_slot if lineup_slot >= 1 else "Bench"
	var status := "[font_size=18][b]STATUS & DYNAMICS[/b][/font_size]\n\n"
	status += "[b]Availability[/b]  %s\n[b]Rotation[/b]  %s\n" % [
		player.availability, rotation_text,
	]
	status += "[b]Reputation[/b]  %d\n[b]Recent form[/b]  %+d%%\n" % [
		player.reputation, roundi(player.current_form * 100.0),
	]
	status += "[b]Satisfaction[/b]  %d%%\n[b]Match confidence[/b]  %+d%%\n" % [
		roundi(player.satisfaction * 100.0),
		roundi(player.match_confidence * 100.0),
	]
	status += "[b]Fatigue[/b]  %d%%\n\n[b]Natural positions[/b]\n%s" % [
		roundi(player.fatigue * 100.0), ", ".join(player.natural_positions),
	]

	var serve_lines: Array[String] = []
	var style_names: Array = player.serve_style_proficiencies.keys()
	style_names.sort()
	for style_name in style_names:
		var score := float(player.serve_style_proficiencies[style_name])
		var marker := "  [color=#f4c95d][b]PRIMARY[/b][/color]" \
			if str(style_name) == player.primary_serve_style else ""
		serve_lines.append("%s  %s%s" % [
			style_name, AttributeProfiles.grade(score), marker,
		])
	var volleyball := "[font_size=18][b]   VOLLEYBALL PROFILE[/b][/font_size]\n\n"
	volleyball += "[b]Key attributes[/b]\n%s\n\n[b]Serve repertoire[/b]\n%s" % [
		_key_attributes(player), "\n".join(serve_lines),
	]

	var raised := str(player.home_region)
	var plays := str(player.club_region)
	var trait_text := "\n".join(player.traits) if not player.traits.is_empty() \
		else "[color=#8294ad]None recorded[/color]"
	var biography := "[font_size=18][b]   TRAITS & BIOGRAPHY[/b][/font_size]\n\n"
	biography += "[b]Traits[/b]\n%s\n\n[b]Raised[/b]  %s\n" % [
		trait_text, raised if not raised.is_empty() else "Unrecorded",
	]
	if not plays.is_empty() and plays != raised:
		biography += "[b]Plays in[/b]  %s\n" % plays
	biography += "[b]Professional experience[/b]  %d seasons\n" % player.professional_experience
	biography += "[b]Adaptability[/b]  %d\n[b]Hand[/b]  %s-handed" % [
		player.adaptability, player.dominant_hand,
	]
	return "[table=3][cell]%s[/cell][cell]%s[/cell][cell]%s[/cell][/table]" % [
		status, volleyball, biography,
	]


func _refresh_player_wheel(player: VolleyballPlayer) -> void:
	## Fully accurate today: this reads the player's real generated ceilings,
	## the same data `potential` is scored from. When scouting exists, an
	## unscouted prospect's outer line should come from an estimate derived
	## from this data (a range, a fogged band) rather than this data itself --
	## the ceilings stay real; what changes is whether the viewer is shown them
	## directly.
	player_attribute_wheel.set_profile(
		AttributeProfiles.summary_profile(player), AttributeProfiles.PROFILE_TOOLTIPS,
		true, AttributeProfiles.summary_profile(player, true),
	)


func _raw_attribute_text(player: VolleyballPlayer, compressed: bool = false) -> String:
	## Reads `AttributeProfiles.CATEGORY_ATTRIBUTES` rather than a second,
	## hand-typed grouping. This table and the wheel used to keep independent
	## category lists with different names and different membership -- this
	## one had a "Reception" bucket the wheel didn't, and neither had
	## attack_accuracy at all. One definition means an attribute added to the
	## player model only needs placing once to appear correctly everywhere.
	## One category per column keeps every attribute visible in a single compact
	## band. The old three-column table wrapped to a second row and forced the
	## entire Roster tab below the 720px baseline viewport.
	var result := "[table=6]"
	var group_font_size := 12 if compressed else 15
	var attribute_font_size := 11 if compressed else 14
	var position_keys: Array = Array(VolleyballPlayer.POSITION_WEIGHTS.get(
		player.position_role, []
	))
	for group_name in AttributeProfiles.CATEGORY_ATTRIBUTES:
		var display_group := "Setting / Control" \
			if group_name == "Setting & Ball Control" else str(group_name)
		var lines: Array[String] = ["[font_size=%d][b]%s[/b][/font_size]" % [
			group_font_size, display_group,
		]]
		for attribute_name in AttributeProfiles.CATEGORY_ATTRIBUTES[group_name]:
			var attribute_key := str(attribute_name)
			var display_name := str(RAW_ATTRIBUTE_LABELS.get(
				attribute_key, attribute_key.replace("_", " ").capitalize()
			))
			var label_markup := "[color=#aab9cc]%s[/color]" % display_name
			if attribute_key in position_keys:
				label_markup = "[color=#f4c95d][u][b]%s[/b][/u][/color]" % display_name
			var score := int(player.get(attribute_key))
			lines.append("%s  [color=#%s][b]%d[/b][/color]" % [
				label_markup, AttributeProfiles.grade_color_hex(float(score)), score,
			])
		result += "[cell][font_size=%d]%s[/font_size][/cell]" % [
			attribute_font_size, "\n".join(lines),
		]
	return result + "[/table]"


func _key_attributes(player: VolleyballPlayer) -> String:
	match player.position_role:
		"Setter": return "Setting %d · Vision %d · Decisions %d · Balance %d" % [player.set_accuracy, player.court_vision, player.decision_making, player.set_balance]
		"Libero": return "Reception %d · Ball control %d · Anticipation %d · Stability %d" % [player.reception, player.ball_control, player.anticipation, player.reception_stability]
		"Middle Blocker": return "Block timing %d · Jump %d · Lateral speed %d · Attack %d" % [player.block_timing, player.jump_reach, player.lateral_speed, player.attack_power]
		_: return "Attack %d · Accuracy %d · Reception %d · Approach %d" % [player.attack_power, player.attack_accuracy, player.reception, player.approach_timing]


func _refresh_team() -> void:
	team_summary.text = "[font_size=22][b]%s Identity[/b][/font_size]\n%s\nRegional alignment %d%% · Opponent adaptation %d%%\nTactical familiarity %d%% · Cohesion %d%%\nCaptain: %s · Libero: %s\n\n[b]Depth chart[/b]\n%s" % [
		GameManager.team.team_name, GameManager.team.identity,
		roundi(GameManager.team.regional_alignment * 100.0),
		roundi(lerpf(0.09, 0.18, GameManager.team.regional_alignment) * 100.0),
		roundi(GameManager.team.tactical_familiarity * 100.0),
		roundi(GameManager.team.cohesion * 100.0),
		_player_name(GameManager.team.captain_id),
		_player_name(GameManager.team.libero_ids[0]) if not GameManager.team.libero_ids.is_empty() else "None",
		_depth_chart_text()]
	identity_finance_panel.text = "[b]Identity[/b]\n%s\n\n[b]Reputation[/b]\n%d/100\n\n[b]Funds[/b]\n$%d\n\n[b]Region[/b]\n%s" % [
		CareerManager.career.identity, CareerManager.career.reputation,
		CareerManager.career.finances, CareerManager.career.region]
	_refresh_team_wheel()
	_populate_roster_list(individual_training_roster_list)
	if individual_training_roster_list.item_count > 0:
		var target_index := 0
		for index in range(individual_training_roster_list.item_count):
			if int(individual_training_roster_list.get_item_metadata(index)) \
					== selected_individual_training_id:
				target_index = index
		individual_training_roster_list.select(target_index)
		_individual_training_selected(target_index)
	for index in range(training_option.item_count):
		if training_option.get_item_text(index) == CareerManager.career.training_focus:
			training_option.select(index)
	_training_selected(training_option.selected)


## The starting six as one profile. Each axis is the lineup's mean category
## score, then pushed away from the lineup's own overall mean by
## `TEAM_WHEEL_AMPLIFICATION` so a real identity is visible at a glance.
##
## "Overall" is rebuilt from the six amplified categories via the same
## `category_score()` weighting `summary_profile()` uses one level down, rather
## than averaging each player's already-derived Overall -- averaging an
## aggregate of an aggregate double-counts the standout/weak-spot adjustment
## baked into every player's own figure.
func _refresh_team_wheel() -> void:
	var starters: Array[VolleyballPlayer] = []
	for player_id in GameManager.team.starting_player_ids:
		var player := GameManager.player_by_id(int(player_id))
		if player != null:
			starters.append(player)
	if starters.is_empty():
		team_attribute_wheel.visible = false
		team_wheel_caption.text = "No starting lineup set. Assign starters on the Roster tab to see the squad's aggregate profile."
		return
	team_attribute_wheel.visible = true
	team_wheel_caption.text = "Starting lineup average across %d players. Differences between axes are amplified so real strengths and weaknesses read clearly; a balanced squad still shows as balanced." % starters.size()

	var totals := {}
	for player in starters:
		var profile := AttributeProfiles.summary_profile(player)
		for axis_name in profile:
			if str(axis_name) == "Overall":
				continue
			totals[axis_name] = float(totals.get(axis_name, 0.0)) + float(profile[axis_name])
	for axis_name in totals:
		totals[axis_name] = float(totals[axis_name]) / float(starters.size())
	team_attribute_wheel.set_profile(
		AttributeProfiles.amplify_team_profile(totals), AttributeProfiles.PROFILE_TOOLTIPS, true)


func _training_selected(index: int) -> void:
	if index < 0:
		return
	var activity_name := training_option.get_item_text(index)
	var activity := Training.description(activity_name)
	training_description.text = "%s\nAttributes: %s · Fatigue %+d%% · Satisfaction %+d%% · Cohesion %+d%%" % [
		activity.description, ", ".join(activity.attributes),
		roundi(float(activity.fatigue) * 100.0),
		roundi(float(activity.satisfaction) * 100.0),
		roundi(float(activity.cohesion) * 100.0)]


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
	var fixture_ready: bool = not bool(fixture.completed) and due \
		and GameManager.match_roster_errors().is_empty()
	play_match_button.disabled = not fixture_ready
	simulate_match_button.disabled = not fixture_ready


func _play_fixture() -> void:
	var error := CareerManager.prepare_fixture(selected_fixture_id)
	if not error.is_empty():
		_set_status(error, true)
		return
	play_match_requested.emit()


func _simulate_fixture() -> void:
	var error := CareerManager.simulate_fixture(selected_fixture_id)
	_set_status(error if not error.is_empty() else "Match simulated.", not error.is_empty())
	refresh()


## Read-only world state -- no selection, no actions, just what's happening
## in the background league the player's own career sits alongside.
func _refresh_sixnet() -> void:
	var career := CareerManager.career
	var lines: Array[String] = []
	lines.append("[font_size=24][b]Sixnet World League[/b][/font_size]")
	lines.append("Champion: %s" % (career.sixnet_champion_region
		if not career.sixnet_champion_region.is_empty() else "Season in progress"))
	lines.append("")
	lines.append("[b]Championship Stage[/b] -- seeded upper bracket plus the qualifier's top two")
	for slot_id in SixnetLeague.UPPER_SLOT_IDS:
		lines.append(_sixnet_slot_line(career, slot_id, career.sixnet_championship_standings))
	for slot_id in career.sixnet_qualified_slots:
		lines.append(_sixnet_slot_line(career, slot_id, career.sixnet_championship_standings, true))
	lines.append("")
	lines.append("[b]Qualifier Stage[/b] -- lower bracket, top two advance")
	for slot_id in SixnetLeague.LOWER_SLOT_IDS:
		lines.append(_sixnet_slot_line(
			career, slot_id, career.sixnet_qualifier_standings,
			slot_id in career.sixnet_qualified_slots,
		))
	lines.append("")
	lines.append("[b]Regional Strength / Sixnet Form[/b]")
	var ranked_regions: Array = Regions.SIXNET_PARTICIPANTS.duplicate()
	ranked_regions.sort_custom(func(a, b) -> bool:
		return float(career.region_strength.get(a, 50.0)) \
			> float(career.region_strength.get(b, 50.0))
	)
	for region_name in ranked_regions:
		lines.append("%s: %d strength / %d form" % [
			region_name,
			roundi(float(career.region_strength.get(region_name, 50.0))),
			roundi(float(career.sixnet_form.get(region_name, 50.0))),
		])
	sixnet_summary.text = "\n".join(lines)


func _sixnet_slot_line(
	career: Resource, slot_id: String, standings: Dictionary, advanced: bool = false,
) -> String:
	var region_name := str(career.sixnet_slots.get(slot_id, "?"))
	var record: Dictionary = standings.get(slot_id, {})
	var record_text := "%d-%d (sets %d-%d)" % [
		record.get("wins", 0), record.get("losses", 0),
		record.get("sets_won", 0), record.get("sets_lost", 0),
	] if not record.is_empty() else "not yet played"
	var marker := "  [color=#62ffb4]-> advanced[/color]" if advanced else ""
	return "%s -- %s: %s%s" % [
		slot_id.replace("_", " ").capitalize(), region_name, record_text, marker,
	]


func _sixnet_top_region() -> String:
	var top_region := ""
	var top_power := -1.0
	for region_name in Regions.SIXNET_PARTICIPANTS:
		var power := float(CareerManager.career.sixnet_form.get(region_name, 50.0))
		if power > top_power:
			top_power = power
			top_region = region_name
	return top_region


func _advance_week() -> void:
	## Advance Week sits inside the dropdown but doesn't route through
	## `_navigate()`, so it dismisses the menu itself.
	_close_nav_dropdown()
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
