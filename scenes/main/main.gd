extends Control

const LIGHT_THEME := preload("res://scenes/themes/light_theme.tres")
const DARK_THEME := preload("res://scenes/themes/dark_theme.tres")
const ExplanationText := preload("res://scripts/data/rally_explanations.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")

@onready var background: ColorRect = %Background
@onready var theme_toggle: CheckButton = %ThemeToggle
@onready var rotation_option: OptionButton = %RotationOption
@onready var match_score_label: Label = %MatchScoreLabel
@onready var tactical_court: TacticalCourt = %TacticalCourt
@onready var court_instructions: Label = %CourtInstructions
@onready var selected_hitter_label: Label = %SelectedHitterLabel
@onready var lane_option: OptionButton = %LaneOption
@onready var tempo_option: OptionButton = %TempoOption
@onready var responsibility_option: OptionButton = %ResponsibilityOption
@onready var assign_button: Button = %AssignButton
@onready var demand_label: Label = %DemandLabel
@onready var play_name_edit: LineEdit = %PlayNameEdit
@onready var save_play_button: Button = %SavePlayButton
@onready var saved_play_option: OptionButton = %SavedPlayOption
@onready var call_play_button: Button = %CallPlayButton
@onready var called_play_label: Label = %CalledPlayLabel
@onready var resolve_rally_button: Button = %ResolveRallyButton
@onready var playback_speed_option: OptionButton = %PlaybackSpeedOption
@onready var skip_playback_button: Button = %SkipPlaybackButton
@onready var reset_positions_button: Button = %ResetPositionsButton
@onready var auto_rallies_toggle: CheckButton = %AutoRalliesToggle
@onready var pause_key_moments_toggle: CheckButton = %PauseKeyMomentsToggle
@onready var rally_event_label: Label = %RallyEventLabel
@onready var rally_result_title: Label = %RallyResultTitle
@onready var rally_result_explanation: Label = %RallyResultExplanation
@onready var rally_result_factors: Label = %RallyResultFactors
@onready var status_label: Label = %StatusLabel
@onready var assignment_popup: PopupPanel = %AssignmentPopup
@onready var popup_assignment_label: Label = %PopupAssignmentLabel
@onready var popup_tempo_option: OptionButton = %PopupTempoOption
@onready var popup_responsibility_option: OptionButton = %PopupResponsibilityOption
@onready var popup_apply_button: Button = %PopupApplyButton
@onready var court_mode_option: OptionButton = %CourtModeOption
@onready var physical_debug_label: Label = %PhysicalDebugLabel
@onready var defense_controls: VBoxContainer = %DefenseControls
@onready var defense_section_option: OptionButton = %DefenseSectionOption
@onready var setting_system_option: OptionButton = %SettingSystemOption
@onready var second_setter_option: OptionButton = %SecondSetterOption
@onready var block_strategy_option: OptionButton = %BlockStrategyOption
@onready var floor_system_option: OptionButton = %FloorSystemOption
@onready var block_defense_relationship_option: OptionButton = %BlockDefenseRelationshipOption
@onready var defensive_depth_option: OptionButton = %DefensiveDepthOption
@onready var short_ball_posture_option: OptionButton = %ShortBallPostureOption
@onready var floor_section_option: OptionButton = %FloorSectionOption
@onready var serve_target_option: OptionButton = %ServeTargetOption
@onready var serve_risk_slider: HSlider = %ServeRiskSlider
@onready var selected_defender_label: Label = %SelectedDefenderLabel
@onready var base_responsibility_option: OptionButton = %BaseResponsibilityOption
@onready var seam_responsibility_option: OptionButton = %SeamResponsibilityOption
@onready var short_ball_responsibility_option: OptionButton = %ShortBallResponsibilityOption
@onready var emergency_responsibility_option: OptionButton = %EmergencyResponsibilityOption
@onready var attack_coverage_option: OptionButton = %AttackCoverageOption
@onready var second_contact_option: OptionButton = %SecondContactOption
@onready var apply_defender_assignment_button: Button = %ApplyDefenderAssignmentButton
@onready var zone_type_option: OptionButton = %ZoneTypeOption
@onready var zone_formation_summary_label: Label = %ZoneFormationSummaryLabel
@onready var selected_zone_label: Label = %SelectedZoneLabel
@onready var zone_radius_value_label: Label = %ZoneRadiusValueLabel
@onready var zone_radius_slider: HSlider = %ZoneRadiusSlider
@onready var zone_priority_option: OptionButton = %ZonePriorityOption
@onready var zone_enabled_check: CheckButton = %ZoneEnabledCheck
@onready var apply_zone_button: Button = %ApplyZoneButton
@onready var defense_summary_label: Label = %DefenseSummaryLabel
@onready var opponent_scouting_label: Label = %OpponentScoutingLabel
@onready var opponent_adaptation_rate_slider: HSlider = %OpponentAdaptationRateSlider
@onready var save_defense_button: Button = %SaveDefenseButton
@onready var timeout_button: Button = %TimeoutButton
@onready var substitute_out_option: OptionButton = %SubstituteOutOption
@onready var substitute_in_option: OptionButton = %SubstituteInOption
@onready var apply_substitution_button: Button = %ApplySubstitutionButton
@onready var match_overview_label: Label = %MatchOverviewLabel
@onready var rally_history_label: Label = %RallyHistoryLabel
@onready var workspace: HSplitContainer = %Workspace
@onready var tactical_workspace_popup: PopupPanel = %TacticalWorkspacePopup
@onready var tactical_workspace_host: MarginContainer = %TacticalWorkspaceHost
@onready var open_tactical_workspace_button: Button = %OpenTacticalWorkspaceButton
@onready var close_tactical_workspace_button: Button = %CloseTacticalWorkspaceButton
@onready var match_preview_court: TacticalCourt = %MatchPreviewCourt
@onready var dashboard_event_label: Label = %DashboardEventLabel
@onready var dashboard_explanation_label: Label = %DashboardExplanationLabel
@onready var substitution_confirmation: ConfirmationDialog = %SubstitutionConfirmation
@onready var undo_substitution_button: Button = %UndoSubstitutionButton
@onready var tactical_modal_underlay: ColorRect = %TacticalModalUnderlay
@onready var defender_popup: PanelContainer = %DefenderPopup
@onready var defender_popup_content: VBoxContainer = %DefenderPopupContent
@onready var defender_popup_title: Label = %DefenderPopupTitle
@onready var block_participation_check: CheckButton = %BlockParticipationCheck
@onready var emergency_pursuit_check: CheckButton = %EmergencyPursuitCheck
@onready var short_ball_priority_option: OptionButton = %ShortBallPriorityOption
@onready var deflection_priority_option: OptionButton = %DeflectionPriorityOption
@onready var setter_release_help: Label = %SetterReleaseHelp

var selected_player_id: int = -1
var draft_play: OffensivePlay
var light_mode_enabled: bool = false
var status_is_error: bool = false
var rally_seed: int = 1001
var rally_playback_active: bool = false
var skip_rally_playback: bool = false
var base_theme_scale: float = 1.0
var pending_drag_lane: String = ""
var pending_substitution_out_id: int = -1
var pending_substitution_in_id: int = -1
var selected_defensive_zone_type: int = DefensiveZoneModel.ZoneType.SERVE_RECEIVE


func _ready() -> void:
	get_viewport().size_changed.connect(_update_interface_scale)
	_populate_static_options()
	theme_toggle.toggled.connect(_apply_light_mode)
	rotation_option.item_selected.connect(_select_rotation)
	tactical_court.player_selected.connect(_select_hitter)
	tactical_court.player_instruction_requested.connect(_open_player_instructions)
	tactical_court.player_drag_started.connect(_player_drag_started)
	tactical_court.assignment_dragged.connect(_open_assignment_popup)
	lane_option.item_selected.connect(_preview_demand)
	tempo_option.item_selected.connect(_preview_demand)
	responsibility_option.item_selected.connect(_preview_demand)
	assign_button.pressed.connect(_assign_selected_hitter)
	save_play_button.pressed.connect(_save_play)
	call_play_button.pressed.connect(_call_selected_play)
	resolve_rally_button.pressed.connect(_resolve_rally)
	skip_playback_button.pressed.connect(_skip_rally_playback)
	reset_positions_button.pressed.connect(_reset_tactical_positions)
	popup_apply_button.pressed.connect(_apply_popup_assignment)
	court_mode_option.item_selected.connect(_court_mode_changed)
	tactical_court.coverage_zone_position_changed.connect(_coverage_zone_position_changed)
	tactical_court.setter_release_position_changed.connect(_setter_release_position_changed)
	save_defense_button.pressed.connect(_save_defensive_plan)
	apply_defender_assignment_button.pressed.connect(_apply_defender_assignment)
	defense_section_option.item_selected.connect(_defense_section_changed)
	floor_system_option.item_selected.connect(_floor_preset_changed)
	setting_system_option.item_selected.connect(_setting_system_changed)
	second_setter_option.item_selected.connect(_setting_system_changed)
	floor_section_option.item_selected.connect(_floor_section_changed)
	zone_type_option.item_selected.connect(_defensive_zone_type_changed)
	zone_radius_slider.value_changed.connect(_zone_radius_changed)
	apply_zone_button.pressed.connect(_apply_selected_zone)
	opponent_adaptation_rate_slider.value_changed.connect(_opponent_adaptation_rate_changed)
	timeout_button.pressed.connect(_call_timeout)
	apply_substitution_button.pressed.connect(_apply_substitution)
	undo_substitution_button.pressed.connect(_undo_substitution)
	substitution_confirmation.confirmed.connect(_confirm_substitution)
	assignment_popup.popup_hide.connect(_assignment_popup_closed)
	tactical_workspace_popup.popup_hide.connect(_tactical_workspace_hidden)
	open_tactical_workspace_button.pressed.connect(_open_tactical_workspace)
	close_tactical_workspace_button.pressed.connect(_close_tactical_workspace)
	GameManager.playbook_changed.connect(_refresh_saved_plays)
	GameManager.rotation_changed.connect(_rotation_changed)
	rotation_option.select(GameManager.selected_rotation - 1)
	_setup_tactical_workspace()
	_setup_defender_popup()
	_apply_light_mode(false)
	_begin_draft()
	_refresh_rotation()
	_refresh_saved_plays()
	_refresh_match_header()
	_refresh_match_controls()
	_update_interface_scale()


func _update_interface_scale() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var width_scale: float = viewport_size.x / 1280.0
	var height_scale: float = viewport_size.y / 720.0
	base_theme_scale = clampf(minf(width_scale, height_scale), 1.0, 1.55)
	if theme != null:
		theme.default_base_scale = base_theme_scale


func _populate_static_options() -> void:
	rotation_option.clear()
	for rotation_number in range(1, 7):
		rotation_option.add_item("Rotation %d" % rotation_number)
		rotation_option.set_item_metadata(rotation_option.item_count - 1, rotation_number)
	tempo_option.clear()
	for tempo in CourtConstants.TEMPOS:
		tempo_option.add_item("T%d" % tempo)
		tempo_option.set_item_metadata(tempo_option.item_count - 1, tempo)
	responsibility_option.clear()
	popup_responsibility_option.clear()
	for responsibility in ["Primary", "Secondary", "Option", "Decoy"]:
		responsibility_option.add_item(responsibility)
		responsibility_option.set_item_metadata(
			responsibility_option.item_count - 1, responsibility
		)
		popup_responsibility_option.add_item(responsibility)
		popup_responsibility_option.set_item_metadata(
			popup_responsibility_option.item_count - 1, responsibility
		)
	popup_tempo_option.clear()
	for tempo in CourtConstants.TEMPOS:
		popup_tempo_option.add_item("T%d" % tempo)
		popup_tempo_option.set_item_metadata(popup_tempo_option.item_count - 1, tempo)
	playback_speed_option.clear()
	for speed_data in [["0.5×", 0.5], ["1×", 1.0], ["2×", 2.0]]:
		playback_speed_option.add_item(str(speed_data[0]))
		playback_speed_option.set_item_metadata(
			playback_speed_option.item_count - 1, float(speed_data[1])
		)
	playback_speed_option.select(1)
	court_mode_option.clear()
	court_mode_option.add_item("Offensive Play")
	court_mode_option.add_item("Defensive Plan")
	_populate_text_options(block_strategy_option, [
		"Read Block", "Commit Pin", "Commit Middle",
	])
	_populate_text_options(floor_system_option, [
		"Perimeter", "Rotation Defense", "Middle-Up",
	])
	_populate_text_options(block_defense_relationship_option, [
		"Balanced", "Defend Line", "Defend Cross",
	])
	_populate_text_options(defensive_depth_option, ["Shallow", "Balanced", "Deep"])
	_populate_text_options(short_ball_posture_option, ["Standard", "Compress Short"])
	_populate_text_options(setting_system_option, ["5-1", "6-2"])
	second_setter_option.clear()
	for player in GameManager.players:
		if player.position_role == "Libero" or player.id == 1:
			continue
		second_setter_option.add_item("%s · %s" % [player.position_code, player.display_name])
		second_setter_option.set_item_metadata(second_setter_option.item_count - 1, player.id)
	_populate_text_options(serve_target_option, [
		"Zone 1", "Zone 5", "Short Middle", "Weak Passer",
	])
	_populate_text_options(base_responsibility_option, [
		"Net defense", "Perimeter defense", "Rotation coverage", "Middle-up defense",
	])
	_populate_text_options(seam_responsibility_option, [
		"Close blocking seam", "Own inside seam", "Own line seam", "Release cross-court seam",
	])
	_populate_text_options(short_ball_responsibility_option, [
		"Cover tip behind block", "Step into tip coverage", "Hold for roll shot", "No short-ball duty",
	])
	_populate_text_options(emergency_responsibility_option, [
		"Release to emergency set", "Pursue deep deflection", "Cover hitter", "Take second contact",
	])
	_populate_text_options(attack_coverage_option, [
		"Cover nearest attacker", "Cover assigned hitter",
		"Take second contact", "Release for transition",
	])
	_populate_text_options(second_contact_option, [
		"Primary emergency setter", "Secondary emergency setter",
		"Stay available to attack", "No second-contact duty",
	])
	defense_section_option.clear()
	for section_name in ["Serve Receive", "Blocking", "Floor Defense", "Attack Coverage / Transition"]:
		defense_section_option.add_item(section_name)
	defense_section_option.select(0)
	floor_section_option.clear()
	floor_section_option.add_item("Positioning & Zones")
	floor_section_option.add_item("Player Duties")
	floor_section_option.select(0)
	zone_type_option.clear()
	zone_type_option.add_item("Floor Defense")
	zone_type_option.set_item_metadata(
		0, DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
	)
	zone_type_option.add_item("Serve Receive")
	zone_type_option.set_item_metadata(
		1, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
	)
	zone_priority_option.clear()
	for priority in range(4):
		zone_priority_option.add_item("P%d · %s" % [
			priority, "primary claim" if priority == 3 else (
				"secondary claim" if priority == 2 else (
					"support" if priority == 1 else "emergency only"
				)
			)
		])
		zone_priority_option.set_item_metadata(priority, priority)
	for option in [short_ball_priority_option, deflection_priority_option]:
		option.clear()
		for priority in range(4):
			option.add_item("P%d · %s" % [priority, ["Emergency", "Support", "Secondary", "Primary"][priority]])
			option.set_item_metadata(priority, priority)
	zone_type_option.visible = false
	_update_defense_section_visibility(0)


func _apply_light_mode(light_mode: bool) -> void:
	light_mode_enabled = light_mode
	theme = LIGHT_THEME if light_mode else DARK_THEME
	background.color = Color("e8f0eb") if light_mode else Color("070b13")
	tactical_court.set_theme_mode(light_mode)
	match_preview_court.set_theme_mode(light_mode)
	theme_toggle.text = "Theme: Molten Light" if light_mode else "Theme: Mikasa Dark"
	_update_interface_scale()
	var secondary_text := Color("315f4b") if light_mode else Color("b9cce0")
	court_instructions.add_theme_color_override("font_color", secondary_text)
	demand_label.add_theme_color_override("font_color", secondary_text)
	physical_debug_label.add_theme_color_override("font_color", secondary_text)
	_update_status_color()


func _select_rotation(index: int) -> void:
	if rally_playback_active:
		rotation_option.select(GameManager.selected_rotation - 1)
		_set_status("Finish or skip the active rally before changing rotation.", true)
		return
	var rotation_number := int(rotation_option.get_item_metadata(index))
	var error := GameManager.select_rotation(rotation_number)
	if not error.is_empty():
		_set_status(error, true)


func _rotation_changed(_rotation_number: int) -> void:
	selected_player_id = -1
	physical_debug_label.text = "PHYSICAL DEBUG · Select a player marker."
	_begin_draft()
	_refresh_rotation()
	_refresh_saved_plays()


func _begin_draft() -> void:
	draft_play = OffensivePlay.new()
	draft_play.rotation_number = GameManager.selected_rotation
	draft_play.play_name = "Rotation %d Attack" % GameManager.selected_rotation
	play_name_edit.text = draft_play.play_name
	selected_hitter_label.text = "Select a hitter marker on the court."
	demand_label.text = "Demand preview appears after selecting a hitter."
	assign_button.disabled = true


func _refresh_rotation() -> void:
	_reset_tactical_positions(false)
	var lineup := GameManager.current_lineup()
	tactical_court.set_lineup(lineup, GameManager.players)
	match_preview_court.set_lineup(lineup, GameManager.players)
	_update_court_preview()
	_refresh_defensive_plan()
	_refresh_match_controls()


func _select_hitter(player_id: int) -> void:
	selected_player_id = player_id
	var player := GameManager.player_by_id(player_id)
	var lineup := GameManager.current_lineup()
	var slot_number := lineup.slot_for_player(player_id)
	_refresh_physical_debug(player)
	if court_mode_option.selected == 1:
		_load_defender_assignment(player_id)
		return
	var eligible := player != null and player.position_role != "Libero" \
		and lineup.is_attack_eligible(player_id)
	selected_hitter_label.text = "%s · %s · slot %d (%s row)" % [
		player.display_name if player != null else "Unknown",
		player.position_role if player != null else "",
		slot_number,
		"front" if CourtConstants.is_front_row_slot(slot_number) else "back",
	]
	assign_button.disabled = not eligible
	_refresh_lane_options(slot_number)
	_load_assignment_controls(draft_play.assignment_for_player(player_id))
	_preview_demand(0)
	if not eligible:
		_set_status("The libero and active setter cannot receive attack assignments.", true)


func _refresh_physical_debug(player: VolleyballPlayer) -> void:
	if player == null:
		physical_debug_label.text = "PHYSICAL DEBUG · Player unavailable."
		return
	physical_debug_label.text = (
		"PHYSICAL DEBUG · %s (%s)\n"
		+ "Height %.1f cm · Mass %.1f kg · Wingspan %.1f cm · Standing reach %.1f cm\n"
		+ "Acceleration %d · Lateral %d · Transition %d · Explosiveness %d · Jump %d · Stamina %d\n"
		+ "Reception balance %d · Reception stability %d"
	) % [
		player.display_name, player.position_code,
		player.height_cm, player.mass_kg, player.wingspan_cm, player.standing_reach_cm(),
		player.acceleration, player.lateral_speed, player.transition_speed,
		player.explosiveness, player.jump_reach, player.stamina,
		player.reception_balance, player.reception_stability,
	]


func _load_defender_assignment(player_id: int) -> void:
	var player := GameManager.player_by_id(player_id)
	var plan: Resource = GameManager.current_defensive_plan()
	var assignment: Resource = plan.assignment_for(player_id) if plan != null else null
	if player == null or assignment == null:
		selected_defender_label.text = "No defensive assignment is available."
		apply_defender_assignment_button.disabled = true
		return
	selected_defender_label.visible = false
	selected_zone_label.visible = false
	defender_popup_title.text = [
		"Serve Receive", "Blocking", "Floor Defense", "Attack Coverage & Transition",
	][defense_section_option.selected]
	var slot_number := GameManager.current_lineup().slot_for_player(player_id)
	var front_row := CourtConstants.is_front_row_slot(slot_number)
	var blocking_phase := defense_section_option.selected == 1
	block_participation_check.visible = blocking_phase and front_row
	seam_responsibility_option.visible = blocking_phase and front_row
	block_participation_check.button_pressed = bool(assignment.block_participation)
	emergency_pursuit_check.button_pressed = bool(assignment.emergency_pursuit)
	short_ball_priority_option.select(clampi(int(assignment.short_ball_priority), 0, 3))
	deflection_priority_option.select(clampi(int(assignment.deflection_priority), 0, 3))
	setter_release_help.visible = defense_section_option.selected == 0 \
		and player_id == GameManager.current_lineup().active_setter_id()
	if blocking_phase and not front_row:
		selected_defender_label.text = "%s is back row · no blocking instructions" % player.position_code
	_select_option_text(base_responsibility_option, str(assignment.base_responsibility))
	_select_option_text(seam_responsibility_option, str(assignment.seam_responsibility))
	_select_option_text(
		short_ball_responsibility_option, str(assignment.short_ball_responsibility)
	)
	_select_option_text(
		emergency_responsibility_option, str(assignment.emergency_responsibility)
	)
	_select_option_text(
		attack_coverage_option, str(assignment.attack_coverage_responsibility)
	)
	_select_option_text(
		second_contact_option, str(assignment.second_contact_responsibility)
	)
	_load_selected_zone()
	apply_defender_assignment_button.disabled = blocking_phase and not front_row
	_set_status("Editing %s's defensive responsibilities." % player.display_name)


func _apply_defender_assignment() -> void:
	if selected_player_id < 0:
		return
	var plan: Resource = GameManager.current_defensive_plan()
	var assignment: Resource = plan.assignment_for(selected_player_id) if plan != null else null
	if assignment == null:
		return
	assignment.base_responsibility = base_responsibility_option.get_item_text(
		base_responsibility_option.selected
	)
	assignment.seam_responsibility = seam_responsibility_option.get_item_text(
		seam_responsibility_option.selected
	)
	assignment.short_ball_responsibility = short_ball_responsibility_option.get_item_text(
		short_ball_responsibility_option.selected
	)
	assignment.emergency_responsibility = emergency_responsibility_option.get_item_text(
		emergency_responsibility_option.selected
	)
	assignment.attack_coverage_responsibility = attack_coverage_option.get_item_text(
		attack_coverage_option.selected
	)
	assignment.second_contact_responsibility = second_contact_option.get_item_text(
		second_contact_option.selected
	)
	assignment.block_participation = block_participation_check.button_pressed \
		and CourtConstants.is_front_row_slot(
			GameManager.current_lineup().slot_for_player(selected_player_id)
		)
	assignment.emergency_pursuit = emergency_pursuit_check.button_pressed
	assignment.short_ball_priority = short_ball_priority_option.selected
	assignment.deflection_priority = deflection_priority_option.selected
	plan.set_assignment(selected_player_id, assignment)
	_refresh_defensive_plan()
	tactical_court.queue_redraw()
	match_preview_court.queue_redraw()
	_set_status("Applied individual defensive responsibilities.")


func _refresh_lane_options(slot_number: int) -> void:
	var previous_lane: String = ""
	var previous_metadata: Variant = _selected_metadata(lane_option)
	if previous_metadata != null:
		previous_lane = str(previous_metadata)
	lane_option.clear()
	var available_lanes: Array[String] = CourtConstants.LANES.duplicate()
	if not CourtConstants.is_front_row_slot(slot_number):
		available_lanes.clear()
		available_lanes.append("Pipe")
	for lane_name in available_lanes:
		lane_option.add_item(lane_name)
		lane_option.set_item_metadata(lane_option.item_count - 1, lane_name)
		if lane_name == previous_lane:
			lane_option.select(lane_option.item_count - 1)


func _load_assignment_controls(assignment: HitterAssignment) -> void:
	if assignment == null:
		return
	_select_option_metadata(lane_option, assignment.lane)
	_select_option_metadata(tempo_option, assignment.tempo)
	var responsibility := "Option"
	if assignment.player_id == draft_play.primary_hitter_id:
		responsibility = "Primary"
	elif assignment.player_id == draft_play.secondary_hitter_id:
		responsibility = "Secondary"
	elif assignment.is_decoy:
		responsibility = "Decoy"
	_select_option_metadata(responsibility_option, responsibility)


func _assign_selected_hitter() -> void:
	if selected_player_id < 0 or lane_option.item_count == 0:
		return
	var lineup := GameManager.current_lineup()
	var assignment := draft_play.assignment_for_player(selected_player_id)
	if assignment == null:
		assignment = HitterAssignment.new()
		assignment.player_id = selected_player_id
		assignment.start_position = CourtConstants.slot_position(
			lineup.slot_for_player(selected_player_id)
		)
		draft_play.assignments.append(assignment)
	assignment.lane = str(_selected_metadata(lane_option))
	assignment.tempo = int(_selected_metadata(tempo_option))
	var responsibility := str(_selected_metadata(responsibility_option))
	assignment.is_decoy = responsibility == "Decoy"
	if draft_play.primary_hitter_id == selected_player_id:
		draft_play.primary_hitter_id = -1
	if draft_play.secondary_hitter_id == selected_player_id:
		draft_play.secondary_hitter_id = -1
	if responsibility == "Primary":
		draft_play.primary_hitter_id = selected_player_id
	elif responsibility == "Secondary":
		draft_play.secondary_hitter_id = selected_player_id
	_normalize_priorities()
	_update_court_preview()
	_preview_demand(0)
	_set_status("Assigned %s to %s at T%d." % [
		GameManager.player_by_id(selected_player_id).display_name,
		assignment.lane, assignment.tempo,
	])


func _open_assignment_popup(
	player_id: int,
	lane_name: String,
	marker_position: Vector2,
) -> void:
	_select_hitter(player_id)
	if assign_button.disabled:
		return
	pending_drag_lane = lane_name
	var player := GameManager.player_by_id(player_id)
	popup_assignment_label.text = "%s → %s" % [player.position_code, lane_name]
	var existing := draft_play.assignment_for_player(player_id)
	if existing != null:
		_select_option_metadata(popup_tempo_option, existing.tempo)
		var existing_responsibility := "Option"
		if draft_play.primary_hitter_id == player_id:
			existing_responsibility = "Primary"
		elif draft_play.secondary_hitter_id == player_id:
			existing_responsibility = "Secondary"
		elif existing.is_decoy:
			existing_responsibility = "Decoy"
		_select_option_metadata(popup_responsibility_option, existing_responsibility)
	else:
		_select_option_metadata(popup_tempo_option, 2)
		_select_option_metadata(popup_responsibility_option, "Option")
	var screen_position := tactical_court.get_screen_position() + marker_position + Vector2(18, -34)
	assignment_popup.position = Vector2i(screen_position)
	assignment_popup.popup()


func _apply_popup_assignment() -> void:
	if pending_drag_lane.is_empty():
		return
	_select_option_metadata(lane_option, pending_drag_lane)
	_select_option_metadata(tempo_option, _selected_metadata(popup_tempo_option))
	_select_option_metadata(
		responsibility_option, _selected_metadata(popup_responsibility_option)
	)
	_assign_selected_hitter()
	assignment_popup.hide()
	pending_drag_lane = ""


func _normalize_priorities() -> void:
	var next_option_priority := 3
	for assignment in draft_play.assignments:
		if assignment.player_id == draft_play.primary_hitter_id:
			assignment.priority = 1
			assignment.is_decoy = false
		elif assignment.player_id == draft_play.secondary_hitter_id:
			assignment.priority = 2
			assignment.is_decoy = false
		else:
			assignment.priority = next_option_priority
			next_option_priority += 1


func _preview_demand(_index: int = -1) -> void:
	if selected_player_id < 0 or lane_option.item_count == 0:
		return
	var player := GameManager.player_by_id(selected_player_id)
	if player == null or player.position_role == "Libero" \
			or not GameManager.current_lineup().is_attack_eligible(selected_player_id):
		return
	var preview := HitterAssignment.new()
	preview.player_id = selected_player_id
	preview.start_position = CourtConstants.slot_position(
		GameManager.current_lineup().slot_for_player(selected_player_id)
	)
	preview.lane = str(_selected_metadata(lane_option))
	preview.tempo = int(_selected_metadata(tempo_option))
	var setter := GameManager.player_by_id(GameManager.current_lineup().active_setter_id())
	var demand := TacticalDemand.evaluate(player, preview, setter)
	demand_label.text = (
		"Technical: %s · Physical: %s\nMental: %s · Synchronization: %s\nPrimary risk: %s"
		% [demand["technical"], demand["physical"], demand["mental"],
			demand["synchronization"], demand["risk"]]
	)


func _save_play() -> void:
	draft_play.play_name = play_name_edit.text.strip_edges()
	var result := GameManager.save_offensive_play(draft_play)
	if not result.get("success", false):
		var errors: Array = result.get("errors", [])
		_set_status("Cannot save: %s" % " ".join(errors), true)
		return
	var saved := result.get("play") as OffensivePlay
	draft_play = OffensivePlay.from_dict(saved.to_dict())
	_refresh_saved_plays(saved.id)
	_update_court_preview()
	_set_status("Saved offensive play: %s." % saved.play_name)


func _refresh_saved_plays(preferred_id: int = -1) -> void:
	var selected_id := preferred_id
	if selected_id < 0 and saved_play_option.selected >= 0:
		selected_id = int(_selected_metadata(saved_play_option))
	saved_play_option.clear()
	for play in GameManager.saved_plays:
		if play.rotation_number != GameManager.selected_rotation:
			continue
		saved_play_option.add_item(play.play_name)
		saved_play_option.set_item_metadata(saved_play_option.item_count - 1, play.id)
		if play.id == selected_id:
			saved_play_option.select(saved_play_option.item_count - 1)
	call_play_button.disabled = saved_play_option.item_count == 0
	resolve_rally_button.disabled = rally_playback_active \
		or bool(GameManager.match_state.match_complete)
	_refresh_called_play_label()


func _call_selected_play() -> void:
	if saved_play_option.selected < 0:
		return
	var play_id := int(_selected_metadata(saved_play_option))
	var error := GameManager.call_play(play_id)
	if not error.is_empty():
		_set_status(error, true)
		return
	_refresh_called_play_label()
	resolve_rally_button.disabled = false
	_set_status("Active play set. It remains active until you choose another.")


func _refresh_called_play_label() -> void:
	var called := GameManager.called_play()
	called_play_label.text = (
		"Active play: %s" % called.play_name
		if called != null else "Active play: Default T3 Outside"
	)
	_refresh_match_preview()


func _update_court_preview() -> void:
	if draft_play == null:
		return
	tactical_court.set_play_preview(
		draft_play.assignments,
		draft_play.primary_hitter_id,
		draft_play.secondary_hitter_id,
	)
	_refresh_match_preview()


func _refresh_match_preview() -> void:
	var active_play := GameManager.called_play()
	if active_play != null:
		match_preview_court.set_play_preview(
			active_play.assignments,
			active_play.primary_hitter_id,
			active_play.secondary_hitter_id,
		)
	else:
		var no_assignments: Array[HitterAssignment] = []
		match_preview_court.set_play_preview(no_assignments, -1, -1)
	match_preview_court.set_defensive_view(
		court_mode_option.selected == 1,
		GameManager.current_defensive_plan(),
		selected_defensive_zone_type,
		defense_section_option.selected,
	)


func _setup_tactical_workspace() -> void:
	tactical_court.set_landscape_orientation(true)
	match_preview_court.set_landscape_orientation(true)
	workspace.reparent(tactical_workspace_host)
	workspace.visible = true


func _setup_defender_popup() -> void:
	# Team structure stays in the side panel; player-specific controls travel with
	# the selected marker in this contextual popup.
	for control in [
		selected_defender_label, base_responsibility_option,
		seam_responsibility_option, short_ball_responsibility_option,
		emergency_responsibility_option, attack_coverage_option,
		second_contact_option, apply_defender_assignment_button,
		selected_zone_label, zone_radius_value_label, zone_radius_slider,
		zone_priority_option, zone_enabled_check, apply_zone_button,
	]:
		control.reparent(defender_popup_content)


func _open_player_instructions(player_id: int, marker_screen_position: Vector2) -> void:
	selected_player_id = player_id
	_load_defender_assignment(player_id)
	var phase := defense_section_option.selected
	var popup_size := Vector2(270.0, [265.0, 210.0, 315.0, 300.0][phase])
	var court_origin := tactical_court.get_screen_position()
	var court_end := court_origin + tactical_court.size
	var popup_screen_position := marker_screen_position + Vector2(28.0, -popup_size.y * 0.52)
	if popup_screen_position.x + popup_size.x > court_end.x - 8.0:
		popup_screen_position.x = marker_screen_position.x - popup_size.x - 28.0
	popup_screen_position.x = clampf(
		popup_screen_position.x, court_origin.x + 8.0, court_end.x - popup_size.x - 8.0
	)
	popup_screen_position.y = clampf(
		popup_screen_position.y, court_origin.y + 8.0, court_end.y - popup_size.y - 8.0
	)
	var popup_position := popup_screen_position - Vector2(tactical_workspace_popup.position)
	defender_popup.position = Vector2i(popup_position)
	defender_popup.size = Vector2i(popup_size)
	defender_popup.show()
	defender_popup.move_to_front()


func _player_drag_started(_player_id: int) -> void:
	# A press may become either a click or a drag. Hide the old panel immediately;
	# a true click release reopens it at the marker's current position.
	defender_popup.hide()


func _open_tactical_workspace() -> void:
	if rally_playback_active:
		auto_rallies_toggle.button_pressed = false
	var viewport_size := get_viewport_rect().size
	var popup_rect := Rect2i(
		24, 20,
		maxi(roundi(viewport_size.x) - 48, 900),
		maxi(roundi(viewport_size.y) - 40, 620),
	)
	tactical_modal_underlay.visible = true
	tactical_workspace_popup.popup(popup_rect)
	_set_status("Tactical playback paused while the full board is open.")


func _close_tactical_workspace() -> void:
	tactical_workspace_popup.hide()
	tactical_modal_underlay.visible = false
	_refresh_match_preview()
	_set_status("Tactical changes applied. Returned to match view.")


func _tactical_workspace_hidden() -> void:
	tactical_modal_underlay.visible = false
	assignment_popup.hide()
	defender_popup.hide()
	pending_drag_lane = ""


func _assignment_popup_closed() -> void:
	pending_drag_lane = ""


func _court_mode_changed(index: int) -> void:
	var defense_enabled := index == 1
	defense_controls.visible = defense_enabled
	_set_offensive_editor_visible(not defense_enabled)
	tactical_court.set_defensive_view(
		defense_enabled, GameManager.current_defensive_plan(),
		selected_defensive_zone_type,
		defense_section_option.selected,
	)
	court_instructions.text = (
		"Drag defenders anywhere on the home court, then save block, floor and serve intent."
		if defense_enabled else
		"Drag a player marker to an attack lane, then finalize tempo and responsibility beside the marker."
	)
	_refresh_match_preview()
	if defense_enabled and selected_player_id >= 0:
		_load_defender_assignment(selected_player_id)
	if defense_enabled:
		_update_defense_section_visibility(defense_section_option.selected)


func _set_offensive_editor_visible(show_controls: bool) -> void:
	var editor := court_mode_option.get_parent()
	for node_name in [
		"EditorTitle", "SelectedHitterLabel", "LaneLabel", "LaneOption",
		"TempoLabel", "TempoOption", "ResponsibilityLabel",
		"ResponsibilityOption", "AssignButton", "DemandLabel",
		"PlaySeparator", "PlayTitle", "PlayNameEdit", "SavePlayButton",
		"SavedPlayLabel", "SavedPlayOption", "CallPlayButton",
		"CalledPlayLabel",
	]:
		var control := editor.get_node_or_null(str(node_name)) as Control
		if control != null:
			control.visible = show_controls


func _refresh_defensive_plan() -> void:
	var plan: Resource = GameManager.current_defensive_plan()
	if plan == null:
		return
	_select_option_text(block_strategy_option, str(plan.block_strategy))
	_select_option_text(floor_system_option, str(plan.floor_system))
	_select_option_text(block_defense_relationship_option, str(plan.block_defense_relationship))
	_select_option_text(defensive_depth_option, str(plan.defensive_depth))
	_select_option_text(short_ball_posture_option, str(plan.short_ball_posture))
	_select_option_text(setting_system_option, GameManager.current_lineup().setting_system)
	second_setter_option.visible = GameManager.current_lineup().setting_system == "6-2"
	_select_option_text(serve_target_option, str(plan.serve_target))
	serve_risk_slider.value = float(plan.serve_risk) * 100.0
	defense_summary_label.text = "%s · %s%s · serve %s at %d%% risk" % [
		plan.block_strategy, plan.floor_system,
		" · Modified" if bool(plan.preset_modified) else "", plan.serve_target,
		roundi(float(plan.serve_risk) * 100.0),
	]
	var responsibility_lines: Array[String] = []
	var lineup := GameManager.current_lineup()
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		var player := GameManager.player_by_id(player_id)
		var assignment: Resource = plan.assignment_for(player_id)
		if player != null and assignment != null:
			responsibility_lines.append("%s — %s; %s" % [
				player.position_code,
				assignment.base_responsibility,
				assignment.short_ball_responsibility,
			])
	defense_summary_label.text += "\n" + "\n".join(responsibility_lines)
	opponent_scouting_label.text = "%s\n%s\n%s" % [
		GameManager.opponent_team.team_name,
		GameManager.opponent_team.scouting_summary(),
		GameManager.opponent_team.adaptation_summary(),
	]
	opponent_adaptation_rate_slider.set_value_no_signal(
		float(GameManager.opponent_team.adaptation_rate) * 100.0
	)
	if court_mode_option.selected == 1:
		tactical_court.set_defensive_view(
			true, plan, selected_defensive_zone_type, defense_section_option.selected
		)
	_refresh_zone_formation_summary()


func _defender_position_changed(player_id: int, court_position: Vector2) -> void:
	GameManager.set_defender_position(player_id, court_position)
	_refresh_defensive_plan()
	tactical_court.queue_redraw()
	match_preview_court.queue_redraw()
	_set_status("Defensive position updated; save the plan when ready.")


func _defensive_zone_type_changed(index: int) -> void:
	var metadata: Variant = zone_type_option.get_item_metadata(index)
	selected_defensive_zone_type = int(metadata)
	tactical_court.set_defensive_view(
		true, GameManager.current_defensive_plan(), selected_defensive_zone_type,
		defense_section_option.selected
	)
	_load_selected_zone()
	_refresh_zone_formation_summary()
	_refresh_match_preview()


func _defense_section_changed(index: int) -> void:
	defender_popup.hide()
	selected_defensive_zone_type = (
		DefensiveZoneModel.ZoneType.SERVE_RECEIVE
		if index == 0 else DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
	)
	_update_defense_section_visibility(index)
	tactical_court.set_defensive_view(
		true, GameManager.current_defensive_plan(), selected_defensive_zone_type, index
	)
	_load_selected_zone()
	_refresh_zone_formation_summary()
	_refresh_match_preview()
	if selected_player_id >= 0:
		_load_defender_assignment(selected_player_id)


func _floor_section_changed(_index: int) -> void:
	_update_defense_section_visibility(defense_section_option.selected)
	if selected_player_id >= 0:
		_load_defender_assignment(selected_player_id)


func _update_defense_section_visibility(index: int) -> void:
	var serve_receive := index == 0
	var blocking := index == 1
	var floor_defense := index == 2
	var transition := index == 3
	var floor_positioning := floor_defense and floor_section_option.selected == 0
	var floor_duties := floor_defense and floor_section_option.selected == 1
	serve_target_option.visible = serve_receive
	serve_risk_slider.visible = serve_receive
	%ServeRiskLabel.visible = serve_receive
	block_strategy_option.visible = blocking
	floor_system_option.visible = floor_defense
	block_defense_relationship_option.visible = floor_defense
	defensive_depth_option.visible = floor_defense
	short_ball_posture_option.visible = floor_defense
	floor_section_option.visible = floor_defense
	selected_defender_label.visible = false
	base_responsibility_option.visible = false
	seam_responsibility_option.visible = blocking
	short_ball_responsibility_option.visible = floor_duties
	short_ball_priority_option.visible = floor_duties
	emergency_responsibility_option.visible = transition
	attack_coverage_option.visible = transition
	deflection_priority_option.visible = transition
	second_contact_option.visible = transition
	emergency_pursuit_check.visible = floor_duties
	apply_defender_assignment_button.visible = blocking or floor_duties or transition
	zone_formation_summary_label.visible = serve_receive or floor_positioning
	selected_zone_label.visible = false
	zone_radius_value_label.visible = serve_receive or floor_positioning
	zone_radius_slider.visible = serve_receive or floor_positioning
	zone_priority_option.visible = serve_receive or floor_positioning
	zone_enabled_check.visible = serve_receive or floor_positioning
	apply_zone_button.visible = serve_receive or floor_positioning
	defense_summary_label.visible = false
	opponent_scouting_label.visible = blocking
	%OpponentAdaptationRateLabel.visible = blocking
	opponent_adaptation_rate_slider.visible = blocking
	court_instructions.text = (
		"Drag passer zones and the independent S→ release target; click a marker for priorities."
		if serve_receive else (
			"Select a blocker to set read and seam responsibility."
			if blocking else (
			("Drag floor zones and tune each player's coverage radius."
			if floor_positioning else
			("Set floor pursuit priorities." if floor_duties else
			"Edit attack coverage and drag the active setter's release target."))
			)
		)
	)


func _floor_preset_changed(_index: int) -> void:
	var plan: Resource = GameManager.current_defensive_plan()
	if plan == null:
		return
	plan.apply_floor_preset(floor_system_option.get_item_text(floor_system_option.selected), GameManager.current_lineup())
	_refresh_defensive_plan()
	tactical_court.queue_redraw()
	match_preview_court.queue_redraw()
	_set_status("Applied floor-defense preset; individual positions remain editable.")


func _setting_system_changed(_index: int) -> void:
	var system_name := setting_system_option.get_item_text(setting_system_option.selected)
	var second_id := -1
	if second_setter_option.selected >= 0:
		second_id = int(second_setter_option.get_item_metadata(second_setter_option.selected))
	var error := GameManager.configure_setting_system(system_name, second_id)
	if not error.is_empty():
		_set_status(error, true)
		return
	_refresh_rotation()
	_set_status("%s setting system applied across all rotations." % system_name)


func _setter_release_position_changed(player_id: int, court_position: Vector2) -> void:
	var plan: Resource = GameManager.current_defensive_plan()
	if plan == null or player_id != GameManager.current_lineup().active_setter_id():
		return
	plan.set_setter_release_target(player_id, court_position)
	tactical_court.queue_redraw()
	match_preview_court.queue_redraw()
	_set_status("Setter release target updated; reception will aim for this route.")


func _zone_radius_changed(value: float) -> void:
	zone_radius_value_label.text = "Coverage radius · %.1f m" % value


func _load_selected_zone() -> void:
	var plan: Resource = GameManager.current_defensive_plan()
	var zone: Resource = plan.zone_for(
		selected_player_id, selected_defensive_zone_type
	) if plan != null and selected_player_id >= 0 else null
	if zone == null:
		selected_zone_label.text = "Select a player to edit zone size and priority."
		apply_zone_button.disabled = true
		return
	var player := GameManager.player_by_id(selected_player_id)
	var zone_name := "serve-reception" \
		if selected_defensive_zone_type == DefensiveZoneModel.ZoneType.SERVE_RECEIVE \
		else "floor-defense"
	selected_zone_label.text = "%s · %s zone" % [
		player.position_code if player != null else "?", zone_name,
	]
	zone_radius_slider.set_value_no_signal(float(zone.radius_meters))
	_zone_radius_changed(float(zone.radius_meters))
	zone_priority_option.select(clampi(int(zone.priority), 0, 3))
	zone_enabled_check.button_pressed = bool(zone.enabled)
	apply_zone_button.disabled = false


func _apply_selected_zone() -> void:
	if selected_player_id < 0:
		return
	var priority := int(zone_priority_option.get_item_metadata(
		zone_priority_option.selected
	))
	GameManager.set_coverage_zone(
		selected_player_id, selected_defensive_zone_type,
		zone_radius_slider.value, priority, zone_enabled_check.button_pressed,
	)
	_refresh_defensive_plan()
	tactical_court.queue_redraw()
	match_preview_court.queue_redraw()
	_set_status("Coverage zone applied to the current rotation.")


func _coverage_zone_position_changed(
	player_id: int, zone_type: int, court_position: Vector2
) -> void:
	GameManager.set_coverage_zone_center(player_id, zone_type, court_position)
	_refresh_defensive_plan()
	tactical_court.queue_redraw()
	match_preview_court.queue_redraw()
	_set_status("Coverage-zone center moved; save the rotation defense when ready.")


func _refresh_zone_formation_summary() -> void:
	var plan: Resource = GameManager.current_defensive_plan()
	if plan == null:
		return
	var zones: Dictionary = plan.zones_for(selected_defensive_zone_type)
	var enabled_codes: Array[String] = []
	var hidden_codes: Array[String] = []
	for raw_player_id in zones:
		var player_id := int(raw_player_id)
		var zone: Resource = zones[raw_player_id] as Resource
		var player := GameManager.player_by_id(player_id)
		var code := player.position_code if player != null else "?"
		if zone != null and bool(zone.enabled):
			enabled_codes.append(code)
		else:
			hidden_codes.append(code)
	if selected_defensive_zone_type == DefensiveZoneModel.ZoneType.SERVE_RECEIVE:
		zone_formation_summary_label.text = "%d-passer reception · active %s · hidden %s" % [
			enabled_codes.size(), ", ".join(enabled_codes),
			", ".join(hidden_codes) if not hidden_codes.is_empty() else "none",
		]
	else:
		zone_formation_summary_label.text = "Floor defense · %d active zones · %s" % [
			enabled_codes.size(), ", ".join(enabled_codes),
		]


func _save_defensive_plan() -> void:
	GameManager.save_defensive_plan(
		block_strategy_option.get_item_text(block_strategy_option.selected),
		floor_system_option.get_item_text(floor_system_option.selected),
		serve_target_option.get_item_text(serve_target_option.selected),
		serve_risk_slider.value / 100.0,
	)
	var plan: Resource = GameManager.current_defensive_plan()
	plan.block_defense_relationship = block_defense_relationship_option.get_item_text(
		block_defense_relationship_option.selected
	)
	plan.defensive_depth = defensive_depth_option.get_item_text(defensive_depth_option.selected)
	plan.short_ball_posture = short_ball_posture_option.get_item_text(
		short_ball_posture_option.selected
	)
	_refresh_defensive_plan()
	_set_status("Defensive plan saved for rotation %d." % GameManager.selected_rotation)


func _opponent_adaptation_rate_changed(value: float) -> void:
	GameManager.opponent_team.adaptation_rate = clampf(value / 100.0, 0.0, 0.40)
	_refresh_defensive_plan()
	_set_status("Opponent adaptation rate set to %d%%." % roundi(value))


func _populate_text_options(option: OptionButton, values: Array[String]) -> void:
	option.clear()
	for value in values:
		option.add_item(value)


func _select_option_text(option: OptionButton, value: String) -> void:
	for item_index in range(option.item_count):
		if option.get_item_text(item_index) == value:
			option.select(item_index)
			return


func _resolve_rally() -> void:
	if rally_playback_active:
		return
	var result: Resource = GameManager.resolve_active_rally(rally_seed)
	rally_seed += 1
	await _play_rally(result)


func _play_rally(result: Resource) -> void:
	rally_playback_active = true
	_reset_tactical_positions(false)
	skip_rally_playback = false
	resolve_rally_button.disabled = true
	skip_playback_button.disabled = false
	reset_positions_button.disabled = true
	rotation_option.disabled = true
	rally_result_title.text = "Rally in progress…"
	rally_result_explanation.text = ""
	rally_result_factors.text = ""
	var playback_speed := float(_selected_metadata(playback_speed_option))
	for event_index in range(result.events.size()):
		var event: Resource = result.events[event_index]
		if skip_rally_playback:
			break
		_set_playback_caption("t=%.2fs · %s · %s\n%s" % [
			float(event.metadata.get("event_time", 0.0)),
			event.type_name(), event.headline, event.detail,
		])
		if event.event_type == RallyEvent.EventType.SET_DECISION:
			continue
		var outgoing_trajectory: Dictionary = event.metadata.get(
			"outgoing_trajectory", {}
		)
		var next_contact := _next_contact_event(result.events, event_index + 1)
		if not outgoing_trajectory.is_empty() and next_contact != null:
			var trajectory_duration := clampf(
				float(outgoing_trajectory.get("duration", 0.5)), 0.20, 2.20
			) / maxf(playback_speed, 0.1)
			tactical_court.animate_spatial_transition(
				event, next_contact, trajectory_duration
			)
			match_preview_court.animate_spatial_transition(
				event, next_contact, trajectory_duration
			)
			await _wait_for_playback_phase(trajectory_duration)
			tactical_court.finish_event_animation()
			match_preview_court.finish_event_animation()
			continue
		var has_movement := tactical_court.has_player_movement(event)
		var simulated_movement := float(event.metadata.get("movement_duration", 0.0))
		var simulated_flight := float(event.metadata.get("flight_time",
			event.metadata.get("set_flight_time", 0.0)))
		var simulated_duration := float(event.metadata.get(
			"event_duration",
			maxf(0.46, simulated_movement + simulated_flight * 0.55),
		))
		var event_duration := clampf(simulated_duration, 0.42, 2.20) \
			/ maxf(playback_speed, 0.1)
		var pre_targets: Array[Vector2] = tactical_court.movement_phase_targets(event)
		var post_targets: Array[Vector2] = tactical_court.movement_phase_targets(event, true)
		var movement_share := clampf(
			simulated_movement / maxf(simulated_duration, 0.1), 0.30, 0.72
		)
		var pre_budget := event_duration * movement_share if has_movement else 0.0
		var contact_pause := event_duration * 0.07 if has_movement else 0.0
		var post_budget := event_duration * 0.18 if has_movement else 0.0
		var ball_duration := event_duration - pre_budget - contact_pause - post_budget
		if has_movement:
			var pre_phase_duration := pre_budget / maxf(float(pre_targets.size()), 1.0)
			for phase_index in range(pre_targets.size()):
				var caption := tactical_court.movement_phase_caption_for(
					event, phase_index, false
				)
				_set_playback_caption("t=%.2fs · %s · %s\n%s" % [
					float(event.metadata.get("event_time", 0.0)),
					caption, event.headline, event.detail,
				])
				tactical_court.animate_player_to(
					event, pre_targets[phase_index], pre_phase_duration, caption
				)
				match_preview_court.animate_player_to(
					event, pre_targets[phase_index], pre_phase_duration, caption
				)
				await _wait_for_playback_phase(pre_phase_duration)
				tactical_court.finish_event_animation()
				match_preview_court.finish_event_animation()
			if not skip_rally_playback:
				_set_playback_caption("t=%.2fs · Contact window · %s\n%s" % [
					float(event.metadata.get("event_time", 0.0)),
					event.headline, event.detail,
				])
				await _wait_for_playback_phase(contact_pause)
		if skip_rally_playback:
			break
		tactical_court.animate_event(event, ball_duration)
		match_preview_court.animate_event(event, ball_duration)
		await _wait_for_playback_phase(ball_duration)
		tactical_court.finish_event_animation()
		match_preview_court.finish_event_animation()
		if skip_rally_playback:
			break
		if has_movement and not post_targets.is_empty():
			var post_phase_duration := post_budget / float(post_targets.size())
			for phase_index in range(post_targets.size()):
				var caption := tactical_court.movement_phase_caption_for(
					event, phase_index, true
				)
				tactical_court.animate_player_to(
					event, post_targets[phase_index], post_phase_duration, caption
				)
				match_preview_court.animate_player_to(
					event, post_targets[phase_index], post_phase_duration, caption
				)
				await _wait_for_playback_phase(post_phase_duration)
				tactical_court.finish_event_animation()
				match_preview_court.finish_event_animation()
	tactical_court.finish_event_animation()
	match_preview_court.finish_event_animation()
	_show_rally_result(result)
	var match_update: Dictionary = GameManager.record_rally(result)
	_refresh_match_header()
	_refresh_match_controls()
	_refresh_defensive_plan()
	_reset_tactical_positions(false)
	rally_playback_active = false
	resolve_rally_button.disabled = bool(GameManager.match_state.match_complete)
	skip_playback_button.disabled = true
	reset_positions_button.disabled = false
	rotation_option.disabled = false
	var key_moment: bool = str(result.terminal_outcome) in [
		"ace", "blocked", "counter_block",
	] or bool(match_update.get("set_complete", false))
	if auto_rallies_toggle.button_pressed \
			and not (pause_key_moments_toggle.button_pressed and key_moment) \
			and not resolve_rally_button.disabled:
		await get_tree().create_timer(0.65).timeout
		_resolve_rally.call_deferred()
	elif bool(GameManager.match_state.match_complete):
		rally_result_title.text = "MATCH COMPLETE · %s" % (
			"HOME WIN" if GameManager.match_state.home_sets > \
			GameManager.match_state.opponent_sets else "OPPONENT WIN"
		)


func _next_contact_event(events: Array, start_index: int) -> Resource:
	for event_index in range(start_index, events.size()):
		var candidate: Resource = events[event_index]
		if candidate.event_type not in [
			RallyEvent.EventType.SET_DECISION,
			RallyEvent.EventType.POINT,
		]:
			return candidate
	return null


func _wait_for_playback_phase(duration: float) -> void:
	var elapsed := 0.0
	while elapsed < duration and not skip_rally_playback:
		await get_tree().process_frame
		elapsed += get_process_delta_time()


func _skip_rally_playback() -> void:
	if not rally_playback_active:
		return
	skip_rally_playback = true
	tactical_court.finish_event_animation()
	match_preview_court.finish_event_animation()


func _set_playback_caption(value: String) -> void:
	rally_event_label.text = value
	dashboard_event_label.text = value


func _reset_tactical_positions(show_status: bool = true) -> void:
	if rally_playback_active and show_status:
		return
	tactical_court.clear_rally_playback()
	match_preview_court.clear_rally_playback()
	if show_status:
		_set_status("Tactical markers returned to saved rotation positions.")


func _show_rally_result(result: Resource) -> void:
	rally_event_label.text = "Rally complete · %d discrete events" % result.events.size()
	rally_result_title.text = "%s · %s" % [
		"HOME POINT" if result.home_team_won else "OPPONENT POINT",
		ExplanationText.headline(result.terminal_outcome),
	]
	rally_result_explanation.text = result.explanation
	dashboard_event_label.text = rally_result_title.text
	dashboard_explanation_label.text = result.explanation
	var factor_lines: Array[String] = []
	for factor in result.key_factors:
		factor_lines.append("• %s" % factor)
	factor_lines.append("Reception %d%% · Set %d%% · Attack %d%%" % [
		roundi(result.reception_quality * 100.0),
		roundi(result.set_quality * 100.0),
		roundi(result.attack_quality * 100.0),
	])
	rally_result_factors.text = "\n".join(factor_lines)
	dashboard_explanation_label.text = result.explanation + "\n\n" \
		+ "\n".join(factor_lines)
	_set_status("Rally resolved from seed %d." % (rally_seed - 1))


func _refresh_match_header() -> void:
	if GameManager.match_state == null:
		match_score_label.text = "Match not started"
		return
	match_score_label.text = GameManager.match_state.score_text()


func _refresh_match_controls() -> void:
	if GameManager.match_state == null:
		return
	timeout_button.text = "Timeout (%d left)" % \
		int(GameManager.match_state.home_timeouts_remaining)
	timeout_button.disabled = GameManager.match_state.home_timeouts_remaining <= 0 \
		or GameManager.match_state.match_complete
	substitute_out_option.clear()
	var lineup := GameManager.current_lineup()
	for slot_number in range(1, 7):
		var player := GameManager.player_by_id(lineup.player_at_slot(slot_number))
		if player != null:
			substitute_out_option.add_item("%s · %s" % [
				player.position_code, player.display_name,
			])
			substitute_out_option.set_item_metadata(
				substitute_out_option.item_count - 1, player.id
			)
	substitute_in_option.clear()
	for player_id in GameManager.bench_player_ids():
		var player := GameManager.player_by_id(player_id)
		substitute_in_option.add_item("%s · %s" % [
			player.position_code, player.display_name,
		])
		substitute_in_option.set_item_metadata(
			substitute_in_option.item_count - 1, player.id
		)
	apply_substitution_button.disabled = substitute_in_option.item_count == 0 \
		or GameManager.match_state.match_complete
	undo_substitution_button.disabled = GameManager.match_state.substitution_history.is_empty()
	var fatigue_values: Array[float] = []
	for slot_number in range(1, 7):
		var player := GameManager.player_by_id(lineup.player_at_slot(slot_number))
		if player != null:
			fatigue_values.append(player.fatigue)
	var average_fatigue := 0.0
	for fatigue_value in fatigue_values:
		average_fatigue += fatigue_value
	if not fatigue_values.is_empty():
		average_fatigue /= fatigue_values.size()
	var next_rotation_number := posmod(GameManager.selected_rotation, 6) + 1
	var next_lineup := GameManager.rotations[next_rotation_number] as RotationLineup
	var next_codes: Array[String] = []
	for slot_number in range(1, 7):
		var next_player := GameManager.player_by_id(next_lineup.player_at_slot(slot_number))
		if next_player != null:
			next_codes.append(next_player.position_code)
	match_overview_label.text = "Serving: %s · Rotation %d · Subs %d · Fatigue %d%%\nNext rotation: %s" % [
		"Home" if GameManager.match_state.serving_home else "Opponent",
		GameManager.selected_rotation,
		GameManager.match_state.home_substitutions_used,
		roundi(average_fatigue * 100.0),
		" · ".join(next_codes),
	]
	var history_lines: Array[String] = []
	var history: Array = GameManager.match_state.rally_history
	var start_index := maxi(history.size() - 4, 0)
	for history_index in range(start_index, history.size()):
		var entry: Dictionary = history[history_index]
		history_lines.append("%d–%d · %s" % [
			entry.get("home_score", 0), entry.get("opponent_score", 0),
			str(entry.get("outcome", "point")).replace("_", " ").capitalize(),
		])
	rally_history_label.text = "Recent rallies\n%s" % (
		"\n".join(history_lines) if not history_lines.is_empty() else "No rallies yet."
	)


func _call_timeout() -> void:
	var error := GameManager.call_timeout()
	if not error.is_empty():
		_set_status(error, true)
		return
	_refresh_match_controls()
	_set_status("Timeout taken. On-court fatigue reduced.")


func _apply_substitution() -> void:
	if substitute_out_option.selected < 0 or substitute_in_option.selected < 0:
		return
	pending_substitution_out_id = int(_selected_metadata(substitute_out_option))
	pending_substitution_in_id = int(_selected_metadata(substitute_in_option))
	var player_out := GameManager.player_by_id(pending_substitution_out_id)
	var player_in := GameManager.player_by_id(pending_substitution_in_id)
	substitution_confirmation.dialog_text = "Replace %s (%s) with %s (%s)?\nRegular substitutions apply across all six rotation sheets." % [
		player_out.display_name, player_out.position_code,
		player_in.display_name, player_in.position_code,
	]
	substitution_confirmation.popup_centered()


func _confirm_substitution() -> void:
	var error := GameManager.substitute_current_rotation(
		pending_substitution_out_id, pending_substitution_in_id
	)
	if not error.is_empty():
		_set_status(error, true)
		return
	_refresh_rotation()
	_set_status("Substitution applied to all legal rotation sheets.")


func _undo_substitution() -> void:
	var error := GameManager.undo_last_substitution()
	if not error.is_empty():
		_set_status(error, true)
		return
	_refresh_rotation()
	_set_status("Last substitution undone.")


func _selected_metadata(option: OptionButton) -> Variant:
	if option.selected < 0 or option.item_count == 0:
		return null
	return option.get_item_metadata(option.selected)


func _select_option_metadata(option: OptionButton, value: Variant) -> void:
	for item_index in range(option.item_count):
		if option.get_item_metadata(item_index) == value:
			option.select(item_index)
			return


func _set_status(message: String, is_error: bool = false) -> void:
	status_label.text = message
	status_is_error = is_error
	_update_status_color()


func _update_status_color() -> void:
	if status_is_error:
		status_label.modulate = Color("a92121") if light_mode_enabled else Color("ff7777")
	else:
		status_label.modulate = Color("176b45") if light_mode_enabled else Color("8ee5aa")
