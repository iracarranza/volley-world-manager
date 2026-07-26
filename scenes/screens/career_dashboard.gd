class_name VolleyballCareerDashboard
extends Control

signal play_match_requested
signal title_requested

const Training := preload("res://scripts/systems/training_system.gd")
const CareerManagerScript := preload("res://scripts/managers/career_manager.gd")

@onready var CareerManager: CareerManagerScript = get_node("/root/CareerManager")
@onready var organization_label: Label = %OrganizationLabel
@onready var date_label: Label = %DateLabel
@onready var section_title: Label = %SectionTitle
@onready var sections: TabContainer = %Sections
@onready var home_summary: RichTextLabel = %HomeSummary
@onready var roster_list: ItemList = %RosterList
@onready var roster_detail: RichTextLabel = %RosterDetail
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


func _ready() -> void:
	for button in [%HomeNav, %RosterNav, %TeamNav, %TransfersNav, %CompetitionNav]:
		button.pressed.connect(_navigate.bind(button.get_meta("section")))
	%SaveButton.pressed.connect(_save)
	%TitleButton.pressed.connect(func() -> void: title_requested.emit())
	%AdvanceWeekButton.pressed.connect(_advance_week)
	%ApplyTrainingButton.pressed.connect(_apply_training_focus)
	training_option.item_selected.connect(_training_selected)
	roster_list.item_selected.connect(_roster_selected)
	transfer_list.item_selected.connect(_transfer_selected)
	sign_button.pressed.connect(_sign_transfer)
	fixture_list.item_selected.connect(_fixture_selected)
	play_match_button.pressed.connect(_play_fixture)
	CareerManager.career_changed.connect(refresh)
	CareerManager.week_advanced.connect(func(_report: Dictionary) -> void: refresh())
	CareerManager.transfer_pool_changed.connect(refresh)
	for activity_name in Training.activity_names():
		training_option.add_item(activity_name)
	for card in [%RosterCard, %TeamCard, %TransfersCard, %CompetitionCard]:
		card.section_requested.connect(_navigate)
	refresh()
	_navigate("Home")


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


func _refresh_roster() -> void:
	roster_list.clear()
	for player_id in GameManager.team.player_ids:
		var player := GameManager.player_by_id(player_id)
		if player == null:
			continue
		var marker := " · C" if player.id == GameManager.team.captain_id else ""
		roster_list.add_item("%s  %s%s" % [player.position_code, player.display_name, marker])
		roster_list.set_item_metadata(roster_list.item_count - 1, player.id)
	if roster_list.item_count > 0:
		roster_list.select(0)
		_roster_selected(0)


func _roster_selected(index: int) -> void:
	var player := GameManager.player_by_id(int(roster_list.get_item_metadata(index)))
	if player == null:
		return
	var key_attributes := _key_attributes(player)
	roster_detail.text = "[font_size=24][b]%s[/b][/font_size]  %s\n%s · Age %d · %d pro seasons\nAvailability: %s · Morale %d%% · Fatigue %d%%\nPotential: %d/100\n\n[b]Key attributes[/b]\n%s\n\n[b]Physical[/b]\n%.0f cm · %.0f kg · %.0f cm wingspan\n\nCurrent rotation: %s" % [
		player.display_name, player.position_code, player.position_role, player.age,
		player.professional_experience, player.availability,
		roundi(player.morale * 100.0), roundi(player.fatigue * 100.0), player.potential,
		key_attributes, player.height_cm, player.mass_kg, player.wingspan_cm,
		"Slot %d" % GameManager.current_lineup().slot_for_player(player.id) if GameManager.current_lineup().slot_for_player(player.id) >= 1 else "Bench"]


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
	var cost := CareerManager.transfer_cost(player)
	transfer_detail.text = "[font_size=22][b]%s[/b][/font_size] · %s\nAge %d · Potential %d/100\n%s\n\nSigning cost: $%d\nAvailable funds: $%d" % [
		player.display_name, player.position_role, player.age, player.potential,
		_key_attributes(player), cost, CareerManager.career.finances]
	sign_button.disabled = cost > int(CareerManager.career.finances) \
		or GameManager.team.player_ids.size() >= GameManager.team.roster_limit
	sign_button.text = "Sign for $%d" % cost


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
