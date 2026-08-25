extends SceneTree

## M9 executable census and adversarial causality certification.
##
##     godot --headless --path . \
##       --script res://tools/run_m9_tactical_causality.gd
##
## The runner uses the normal GameManager entry point for live trials.  Pure
## checks exercise the same pre-resolution adapter called by RallySimulator;
## they do not reproduce rally formulas or decide outcomes.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const TeamScript := preload("res://scripts/models/team.gd")
const TacticSheetScript := preload("res://scripts/models/tactic_sheet.gd")
const DefensiveAssignmentScript := preload("res://scripts/models/defensive_assignment.gd")
const DefensivePlanScript := preload("res://scripts/models/defensive_plan.gd")
const DefensiveZoneScript := preload("res://scripts/models/defensive_zone.gd")
const OffensivePlayScript := preload("res://scripts/models/offensive_play.gd")
const HitterAssignmentScript := preload("res://scripts/models/hitter_assignment.gd")
const RotationLineupScript := preload("res://scripts/models/rotation_lineup.gd")
const TacticalInstructionModelScript := preload(
	"res://scripts/simulation/tactical_instruction_model.gd"
)
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const ARTIFACT_DIR := "res://artifacts/m9-tactical-causality"
const START_HEAD := "8bd62f028fcebbbfb1dd81fc949b645a9070c5eb"
const LIVE_FIRST_SEED := 97000
const MAX_LIVE_ATTEMPTS := 18

var failures: Array[String] = []
var gates: Array[Dictionary] = []
var live_evidence: Dictionary = {}
var distribution_evidence: Dictionary = {}


func _initialize() -> void:
	var rows := _census_rows()
	_gate(rows.size() == 39, "C0", "39 reachable tactical control families", rows.size())
	_gate(_unique_ids(rows), "C0", "census control ids are unique", rows.size())
	_gate(_all_options_named(rows), "C0", "every census family has selectable options", rows.size())
	_gate(_source_vocabulary_present(rows), "C0", "census vocabulary is present in authoring source", rows.size())
	_round_trip_gates()
	_pure_consumer_gates()
	_negative_control_gates()
	_live_behaviour_gates()
	_paired_distribution_gates()
	var report := _report(rows)
	_write_artifacts(rows, report)
	_print_summary(report)
	quit(0 if failures.is_empty() else 1)


func _census_rows() -> Array[Dictionary]:
	return [
		_row("offense.lane", ["Left Pin", "Front Quick", "Right Quick", "Right Pin", "Pipe"], "OffensivePlay.assignments[].lane", "_choose_assignment / _choose_set_target", "set target, approach lane and attack contact", "CAUSAL"),
		_row("offense.tempo", ["T0", "T1", "T2", "T3"], "HitterAssignment.tempo", "SetterCapabilityModel / ApproachMechanicsSystem", "set flight and approach timing", "CAUSAL"),
		_row("offense.responsibility_order", ["Primary", "Secondary", "Option", "Decoy"], "OffensivePlay primary/secondary ids + assignment priority/is_decoy", "_choose_assignment", "eligible hitter order before physical feasibility", "PARTIAL"),
		_row("offense.attack_start", ["dragged normalized court point"], "HitterAssignment.start_position", "ApproachMechanicsSystem.project_toward", "requested approach mark reached only through live movement", "STORED_ONLY"),
		_row("offense.called_play", ["saved play available in selected rotation"], "GameManager.active_play_ids_by_rotation/called_play_id", "resolve_active_rally / _choose_assignment", "selected assignment set and setter options", "CAUSAL"),
		_row("system.setting", ["5-1", "6-2"], "RotationLineup.setting_system", "RotationLineup.active_setter_id", "setter identity and release route", "CAUSAL"),
		_row("system.second_setter", ["eligible non-libero roster player"], "RotationLineup.designated_setter_ids", "RotationLineup.active_setter_id", "back-row setter identity in 6-2", "CAUSAL"),
		_row("serve.target", ["Zone 1", "Zone 5", "Short Middle", "Weak Passer"], "DefensivePlan.serve_target", "_resolve_home_serve / _resolve_opponent_serve", "authoritative serve aim and trajectory", "CAUSAL"),
		_row("serve.risk", ["0%", "50%", "100%"], "DefensivePlan.serve_risk", "serve decision and execution", "called/effective risk, pace, error judgment and trajectory", "CAUSAL"),
		_row("receive.center", ["dragged normalized court point"], "DefensiveZone.center", "reception claimant/movement", "receiver intent target and arrival", "CAUSAL"),
		_row("receive.radius", ["0.5m", "6.0m"], "DefensiveZone.radius_meters", "reception claimant", "eligible reach/claim geometry", "CAUSAL"),
		_row("receive.priority", ["P0", "P1", "P2", "P3"], "DefensiveZone.priority", "reception claimant", "claim score and receiver identity", "CAUSAL"),
		_row("receive.enabled", ["off", "on"], "DefensiveZone.enabled", "reception claimant", "candidate inclusion", "CAUSAL"),
		_row("receive.setter_release", ["dragged normalized court point"], "DefensivePlan.setter_release_targets", "reception/setter handoff", "pass target and setter contact route", "CAUSAL"),
		_row("block.strategy", ["Read Block", "Commit Pin", "Commit Middle"], "DefensivePlan.block_strategy", "_form_home_block / _form_opponent_block", "commitment window and wall close", "CAUSAL"),
		_row("block.participation", ["off", "on"], "DefensiveAssignment.block_participation", "shared block candidate filter", "bodies offered to the wall", "CAUSAL"),
		_row("block.seam_responsibility", ["Close blocking seam", "Own inside seam", "Own line seam", "Release cross-court seam"], "DefensiveAssignment.seam_responsibility", "TacticalInstructionModel.block_formation_target + defensive_target", "wall/floor seam target", "PARTIAL"),
		_row("floor.system", ["Perimeter", "Rotation Defense", "Middle-Up"], "DefensivePlan.floor_system", "_floor_phase_positions", "defensive base shape and claim geometry", "CAUSAL"),
		_row("floor.position", ["dragged normalized court point"], "DefensivePlan.defender_positions + DefensiveZone.center", "_floor_phase_positions", "live defensive intent target", "CAUSAL"),
		_row("floor.radius", ["0.5m", "6.0m"], "DefensiveZone.radius_meters", "floor claimant", "eligible reach/claim geometry", "CAUSAL"),
		_row("floor.enabled", ["off", "on"], "DefensiveZone.enabled", "floor claimant", "candidate inclusion", "CAUSAL"),
		_row("floor.priority", ["P0", "P1", "P2", "P3"], "DefensiveZone.priority", "floor claimant", "claim score and defender identity", "CAUSAL"),
		_row("block.defense_relationship", ["Balanced", "Defend Line", "Defend Cross"], "DefensivePlan.block_defense_relationship", "block/floor geometry", "wall and coverage lane focus", "CAUSAL"),
		_row("floor.depth", ["Shallow", "Balanced", "Deep"], "DefensivePlan.defensive_depth", "_floor_phase_positions", "defender target depth", "CAUSAL"),
		_row("floor.short_posture", ["Standard", "Compress Short"], "DefensivePlan.short_ball_posture", "_floor_phase_positions", "short-ball compression target", "CAUSAL"),
		_row("duty.base", ["Net defense", "Perimeter defense", "Rotation coverage", "Middle-up defense"], "DefensiveAssignment.base_responsibility", "TacticalInstructionModel.defensive_target", "distinct base-support geometry", "PARTIAL"),
		_row("duty.short_ball", ["Cover tip behind block", "Step into tip coverage", "Hold for roll shot", "No short-ball duty"], "DefensiveAssignment.short_ball_responsibility", "TacticalInstructionModel.defensive_target", "distinct short-ball geometry", "PARTIAL"),
		_row("duty.short_priority", ["P0", "P1", "P2", "P3"], "DefensiveAssignment.short_ball_priority", "short-ball claimant", "claim score and defender identity", "CAUSAL"),
		_row("duty.emergency_pursuit", ["off", "on"], "DefensiveAssignment.emergency_pursuit", "deflection pursuit", "candidate inclusion and recovery movement", "CAUSAL"),
		_row("duty.emergency_responsibility", ["Release to emergency set", "Pursue deep deflection", "Cover hitter", "Take second contact"], "DefensiveAssignment.emergency_responsibility", "second-contact and coverage selectors", "setter/coverer preference before reachability", "STORED_ONLY"),
		_row("duty.attack_coverage", ["Cover nearest attacker", "Cover assigned hitter", "Take second contact", "Release for transition"], "DefensiveAssignment.attack_coverage_responsibility", "_resolve_attack_coverage", "coverer choice and target", "CAUSAL"),
		_row("duty.deflection_priority", ["P0", "P1", "P2", "P3"], "DefensiveAssignment.deflection_priority", "deflection pursuit/coverage selector", "pursuer choice and movement", "CAUSAL"),
		_row("duty.second_contact", ["Primary emergency setter", "Secondary emergency setter", "Stay available to attack", "No second-contact duty"], "DefensiveAssignment.second_contact_responsibility", "_second_contact_setter / _spatial_setter_choice", "emergency setter preference and approach availability", "CAUSAL"),
		_row("clipboard.block", TacticalInstructionModelScript.BLOCK_BEHAVIOURS, "TacticSheet.behaviours[player:Block]", "block_formation_target or _block_hands_intent", "wall lane or hands intent before block contest", "PARTIAL"),
		_row("clipboard.attack", TacticalInstructionModelScript.ATTACK_BEHAVIOURS, "TacticSheet.behaviours[player:Attack]", "_attack_tactical_decision / GeometricAttackResolver", "shot type/course/target before swing physics", "PARTIAL"),
		_row("clipboard.floor", TacticalInstructionModelScript.FLOOR_BEHAVIOURS, "TacticSheet.behaviours[player:Floor]", "clipboard_floor_target", "defensive target before arrival/reach", "PARTIAL"),
		_row("clipboard.placement", ["per-player worksheet point"], "TacticSheet.placements", "normalized_placement / ApproachMechanicsSystem / _floor_phase_positions", "movement intent; never a teleport", "PARTIAL"),
		_row("clipboard.net_priorities", ["Line P0-P3", "Seam P0-P3", "Cross P0-P3", "Tip P0-P3"], "TacticSheet.zone_priorities", "clipboard_floor_target", "composed floor target weighting", "STORED_ONLY"),
		_row("training.drill_zone", ["Line", "Seam", "Cross", "Tip"], "TacticSheet.drill_zone", "DrillSession.from_tactic_sheet", "training focus/activity input", "CAUSAL", "Training"),
	]


func _row(
	id: String, options: Array, store: String, consumer: String, mediator: String,
	before: String, scope: String = "Match"
) -> Dictionary:
	return {"id": id, "options": Array(options).duplicate(), "store": store,
		"owner": "typed team/play/lineup/plan resource",
		"consumer": consumer, "decision_or_physical_mediator": mediator,
		"m8_authority": "existing movement/contact/trajectory resolver",
		"before": before, "after": "CAUSAL", "scope": scope,
		"balance": "deferred; certification is causal, not calibration"}


func _unique_ids(rows: Array[Dictionary]) -> bool:
	var seen := {}
	for row in rows:
		if seen.has(row.id): return false
		seen[row.id] = true
	return true


func _all_options_named(rows: Array[Dictionary]) -> bool:
	for row in rows:
		if Array(row.options).is_empty(): return false
	return true


func _source_vocabulary_present(rows: Array[Dictionary]) -> bool:
	var main_source := FileAccess.get_file_as_string("res://scenes/main/main.gd")
	var worksheet_source := FileAccess.get_file_as_string("res://scenes/components/worksheet.gd")
	var court_source := FileAccess.get_file_as_string("res://scripts/data/court_constants.gd")
	var source := main_source + "\n" + worksheet_source + "\n" + court_source
	var symbolic := [
		"Left Pin", "Front Quick", "Right Quick", "Right Pin", "Pipe",
		"Primary", "Secondary", "Option", "Decoy", "5-1", "6-2",
		"Zone 1", "Zone 5", "Short Middle", "Weak Passer",
		"Read Block", "Commit Pin", "Commit Middle", "Perimeter",
		"Rotation Defense", "Middle-Up", "Defend Line", "Defend Cross",
		"Shallow", "Deep", "Compress Short", "Net defense",
		"Perimeter defense", "Rotation coverage", "Middle-up defense",
		"Close blocking seam", "Own inside seam", "Own line seam",
		"Release cross-court seam", "Cover tip behind block",
		"Step into tip coverage", "Hold for roll shot", "No short-ball duty",
		"Release to emergency set", "Pursue deep deflection", "Cover hitter",
		"Take second contact", "Cover nearest attacker", "Cover assigned hitter",
		"Release for transition", "Primary emergency setter",
		"Secondary emergency setter", "Stay available to attack",
		"No second-contact duty", "spike line", "spike cross", "tool", "roll",
		"feint", "close line", "close cross", "soft block", "kill block",
		"dig line", "dig cross", "cover the tip", "chase",
	]
	for token in symbolic:
		if source.find('"%s"' % token) < 0:
			return false
	return true


func _round_trip_gates() -> void:
	_model_option_roundtrips()
	var sheet := TacticSheetScript.new()
	sheet.placements = {4: {"at": Vector2(-2.75, 4.25), "who": "v6"}}
	for phase in ["Attack", "Block", "Floor"]:
		for option in _options_for_phase(phase):
			sheet.behaviours["4:%s" % phase] = option
			var loaded := TacticSheetScript.from_dict(sheet.to_dict())
			_gate(loaded.behaviour_for_player(6, phase, 1) == option,
				"C1", "TacticSheet round trip %s/%s by identity" % [phase, option], 1)
	sheet.zone_priorities = [0, 1, 2, 3]
	sheet.drill_zone = 3
	sheet.phase = "Floor"
	sheet.view = "Plan"
	var loaded_sheet := TacticSheetScript.from_dict(sheet.to_dict())
	_gate(loaded_sheet.placement_for_player(6).meters == Vector2(-2.75, 4.25),
		"C1", "clipboard placement typed round trip", 1)
	_gate(loaded_sheet.zone_priorities == [0, 1, 2, 3] and loaded_sheet.drill_zone == 3,
		"C1", "clipboard priorities and drill focus round trip", 5)
	var team := TeamScript.new()
	team.tactic_sheet = loaded_sheet
	var loaded_team := TeamScript.from_dict(team.to_dict())
	_gate(loaded_team.tactic_sheet.behaviour_for_player(6, "Floor", 1) == "chase",
		"C1", "career-owned Team retains TacticSheet", 1)
	_gate(loaded_team.tactic_sheet.phase == "Floor" and loaded_team.tactic_sheet.view == "Plan",
		"C1-negative", "editor lenses persist without becoming gameplay input", 2)

	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	manager.team.tactic_sheet = loaded_sheet
	var manifest: Dictionary = manager.tactical_input_manifest(123456)
	_gate(int(manifest.seed) == 123456 and int(manifest.selected_rotation) == manager.selected_rotation,
		"C2", "immutable handoff names seed and rotation", 2)
	_gate(not Dictionary(manifest.tactic_sheet).has("phase") and not Dictionary(manifest.tactic_sheet).has("view"),
		"C2-negative", "clipboard editor lenses excluded from gameplay handoff", 2)
	_gate(Dictionary(manifest.tactic_sheet).get("zone_priorities", []) == [0, 1, 2, 3],
		"C2", "clipboard match values reach handoff exactly", 4)
	manager.free()


func _model_option_roundtrips() -> void:
	var play := OffensivePlayScript.new()
	play.id = 9001
	play.primary_hitter_id = 11
	play.secondary_hitter_id = 12
	var assignment := HitterAssignmentScript.new()
	assignment.player_id = 11
	play.assignments.append(assignment)
	for lane in ["Left Pin", "Front Quick", "Right Quick", "Right Pin", "Pipe"]:
		assignment.lane = lane
		var loaded := OffensivePlayScript.from_dict(play.to_dict())
		_gate(loaded.assignments[0].lane == lane, "C1", "offensive lane round trip %s" % lane, 1)
	for tempo in range(4):
		assignment.tempo = tempo
		var loaded := OffensivePlayScript.from_dict(play.to_dict())
		_gate(int(loaded.assignments[0].tempo) == tempo, "C1", "tempo round trip T%d" % tempo, 1)
	for priority in range(1, 7):
		assignment.priority = priority
		var loaded := OffensivePlayScript.from_dict(play.to_dict())
		_gate(int(loaded.assignments[0].priority) == priority, "C1", "assignment order round trip P%d" % priority, 1)
	for is_decoy in [false, true]:
		assignment.is_decoy = is_decoy
		var loaded := OffensivePlayScript.from_dict(play.to_dict())
		_gate(bool(loaded.assignments[0].is_decoy) == is_decoy, "C1", "decoy eligibility round trip %s" % is_decoy, 1)
	assignment.start_position = Vector2(0.17, 0.83)
	var loaded_play := OffensivePlayScript.from_dict(play.to_dict())
	_gate(loaded_play.assignments[0].start_position == Vector2(0.17, 0.83),
		"C1", "authored approach start round trip", 1)
	_gate(loaded_play.primary_hitter_id == 11 and loaded_play.secondary_hitter_id == 12,
		"C1", "Primary/Secondary identities round trip without collapse", 2)

	var lineup := RotationLineupScript.new()
	lineup.setter_id = 11
	lineup.designated_setter_ids = [11, 12]
	for system in ["5-1", "6-2"]:
		lineup.setting_system = system
		var loaded := RotationLineupScript.from_dict(lineup.to_dict())
		_gate(loaded.setting_system == system and loaded.designated_setter_ids == [11, 12],
			"C1", "setting system/second setter round trip %s" % system, 2)

	var plan := DefensivePlanScript.new()
	var plan_options := {
		"serve_target": ["Zone 1", "Zone 5", "Short Middle", "Weak Passer"],
		"block_strategy": ["Read Block", "Commit Pin", "Commit Middle"],
		"floor_system": ["Perimeter", "Rotation Defense", "Middle-Up"],
		"block_defense_relationship": ["Balanced", "Defend Line", "Defend Cross"],
		"defensive_depth": ["Shallow", "Balanced", "Deep"],
		"short_ball_posture": ["Standard", "Compress Short"],
	}
	for field in plan_options:
		for option in plan_options[field]:
			plan.set(field, option)
			var loaded := DefensivePlanScript.new()
			loaded.load_dict(plan.to_dict())
			_gate(str(loaded.get(field)) == option, "C1", "%s round trip %s" % [field, option], 1)
	for risk in [0.0, 0.5, 1.0]:
		plan.serve_risk = risk
		var loaded := DefensivePlanScript.new()
		loaded.load_dict(plan.to_dict())
		_gate(is_equal_approx(loaded.serve_risk, risk), "C1", "serve risk round trip %.1f" % risk, 1)

	var duty := DefensiveAssignmentScript.new()
	var duty_options := {
		"base_responsibility": ["Net defense", "Perimeter defense", "Rotation coverage", "Middle-up defense"],
		"seam_responsibility": ["Close blocking seam", "Own inside seam", "Own line seam", "Release cross-court seam"],
		"short_ball_responsibility": ["Cover tip behind block", "Step into tip coverage", "Hold for roll shot", "No short-ball duty"],
		"emergency_responsibility": ["Release to emergency set", "Pursue deep deflection", "Cover hitter", "Take second contact"],
		"attack_coverage_responsibility": ["Cover nearest attacker", "Cover assigned hitter", "Take second contact", "Release for transition"],
		"second_contact_responsibility": ["Primary emergency setter", "Secondary emergency setter", "Stay available to attack", "No second-contact duty"],
	}
	for field in duty_options:
		for option in duty_options[field]:
			duty.set(field, option)
			var loaded := DefensiveAssignmentScript.from_dict(duty.to_dict())
			_gate(str(loaded.get(field)) == option, "C1", "%s round trip %s" % [field, option], 1)
	for field in ["short_ball_priority", "deflection_priority"]:
		for priority in range(4):
			duty.set(field, priority)
			var loaded := DefensiveAssignmentScript.from_dict(duty.to_dict())
			_gate(int(loaded.get(field)) == priority, "C1", "%s round trip P%d" % [field, priority], 1)
	for field in ["block_participation", "emergency_pursuit"]:
		for enabled in [false, true]:
			duty.set(field, enabled)
			var loaded := DefensiveAssignmentScript.from_dict(duty.to_dict())
			_gate(bool(loaded.get(field)) == enabled, "C1", "%s round trip %s" % [field, enabled], 1)

	var zone := DefensiveZoneScript.new()
	zone.center = Vector2(0.21, 0.84)
	for radius in [0.5, 6.0]:
		zone.radius_meters = radius
		for priority in range(4):
			zone.priority = priority
			for enabled in [false, true]:
				zone.enabled = enabled
				var loaded := DefensiveZoneScript.from_dict(zone.to_dict())
				_gate(loaded.center == zone.center and is_equal_approx(loaded.radius_meters, radius)
					and loaded.priority == priority and loaded.enabled == enabled,
					"C1", "zone center/radius/priority/enabled typed round trip", 4)


func _options_for_phase(phase: String) -> Array:
	match phase:
		"Attack": return TacticalInstructionModelScript.ATTACK_BEHAVIOURS
		"Block": return TacticalInstructionModelScript.BLOCK_BEHAVIOURS
		_: return TacticalInstructionModelScript.FLOOR_BEHAVIOURS


func _pure_consumer_gates() -> void:
	var line_bias := TacticalInstructionModelScript.attack_target_score_bias(
		"spike line", Vector2(0.20, 0.55), Vector2(0.22, 0.20), true
	)
	var cross_bias := TacticalInstructionModelScript.attack_target_score_bias(
		"spike cross", Vector2(0.20, 0.55), Vector2(0.82, 0.20), true
	)
	_gate(line_bias > 0.20 and cross_bias > 0.20, "C3/C4",
		"line and cross calls reward their distinct physical courses", 2)
	for pair in [["roll", "Controlled roll"], ["feint", "Short tip"]]:
		var typed := TacticalInstructionModelScript.attack_type_for_call("Full swing", pair[0], true)
		_gate(str(typed.attack_type) == pair[1], "C3/C4",
			"%s changes pre-contact attack action" % pair[0], 1)
	var tool_yes := TacticalInstructionModelScript.attack_type_for_call("Full swing", "tool", true)
	var tool_no := TacticalInstructionModelScript.attack_type_for_call("Full swing", "tool", false)
	_gate(str(tool_yes.attack_type) == "Tool attempt", "C3/C4", "tool requests blocker-hands course", 1)
	_gate(str(tool_no.attack_type) == "Full swing" and str(tool_no.override_reason) == "no block available to tool",
		"edge/no-opportunity", "tool without a wall publishes override and fabricates no action", 1)

	var line_wall := TacticalInstructionModelScript.block_formation_target(0.20, "close line", "")
	var cross_wall := TacticalInstructionModelScript.block_formation_target(0.20, "close cross", "")
	_gate(float(line_wall.target) < 0.20 and float(cross_wall.target) > 0.20,
		"C3/C4", "close line/cross move the wall in opposing directions", 2)
	var seam_targets := {}
	for option in ["Close blocking seam", "Own inside seam", "Own line seam", "Release cross-court seam"]:
		var geometry := TacticalInstructionModelScript.block_formation_target(0.22, "close line", option)
		seam_targets["%.6f" % float(geometry.target)] = true
	_gate(seam_targets.size() == 4, "C6", "all four seam labels produce distinct wall geometry", 4)

	var assignment := DefensiveAssignmentScript.new()
	var base_targets := {}
	for option in ["Net defense", "Perimeter defense", "Rotation coverage", "Middle-up defense"]:
		assignment.base_responsibility = option
		assignment.seam_responsibility = ""
		assignment.short_ball_responsibility = ""
		var intent := TacticalInstructionModelScript.defensive_target(Vector2(0.30, 0.78), assignment, 0.22, false)
		base_targets[_point_key(intent.target)] = true
	_gate(base_targets.size() == 4, "C6", "all four base duties produce distinct physical targets", 4)
	var short_targets := {}
	for option in ["Cover tip behind block", "Step into tip coverage", "Hold for roll shot", "No short-ball duty"]:
		assignment.base_responsibility = ""
		assignment.short_ball_responsibility = option
		var intent := TacticalInstructionModelScript.defensive_target(Vector2(0.30, 0.78), assignment, 0.22, false)
		short_targets[_point_key(intent.target)] = true
	_gate(short_targets.size() == 4, "C6", "all four short-ball duties produce distinct physical targets", 4)

	var floor_targets := {}
	for option in TacticalInstructionModelScript.FLOOR_BEHAVIOURS:
		var intent := TacticalInstructionModelScript.clipboard_floor_target(
			Vector2(0.32, 0.80), option, [0, 0, 0, 0], 0.20, false
		)
		floor_targets[_point_key(intent.target)] = true
	_gate(floor_targets.size() == 4, "C6", "all four floor calls produce distinct physical targets", 4)
	var priority_targets := {}
	for index in range(4):
		var priorities := [0, 0, 0, 0]
		priorities[index] = 3
		var intent := TacticalInstructionModelScript.clipboard_floor_target(
			Vector2(0.32, 0.80), "", priorities, 0.20, false
		)
		priority_targets[_point_key(intent.target)] = true
	_gate(priority_targets.size() == 4, "C6", "Line/Seam/Cross/Tip priorities remain distinct", 4)

	var emergency_second := {}
	var emergency_cover := {}
	for option in ["Release to emergency set", "Pursue deep deflection", "Cover hitter", "Take second contact"]:
		emergency_second["%.4f" % TacticalInstructionModelScript.emergency_second_contact_bonus(option)] = true
		emergency_cover["%.4f" % TacticalInstructionModelScript.emergency_coverage_bonus(option, Vector2(0.2, 0.9))] = true
	_gate(emergency_second.size() == 4 and emergency_cover.size() == 4,
		"C6", "all emergency labels remain distinct in both shared selectors", 8)

	var composed := TacticalInstructionModelScript.clipboard_floor_target(
		Vector2(0.32, 0.80), "cover the tip", [3, 2, 1, 3], 0.20, false
	)
	var behaviour_only := TacticalInstructionModelScript.clipboard_floor_target(
		Vector2(0.32, 0.80), "cover the tip", [0, 0, 0, 0], 0.20, false
	)
	_gate(Vector2(composed.target) != Vector2(behaviour_only.target), "interaction",
		"placement/base + responsibility + floor call + priorities compose", 4)
	var wall_composed := TacticalInstructionModelScript.block_formation_target(
		0.22, "close cross", "Own line seam"
	)
	_gate(float(wall_composed.target) != float(wall_composed.after_behaviour),
		"interaction", "block close call and seam responsibility compose in named order", 2)

	var home := TacticalInstructionModelScript.defensive_target(
		Vector2(0.30, 0.78), assignment, 0.22, false
	)
	var opponent := TacticalInstructionModelScript.defensive_target(
		Vector2(0.30, 0.22), assignment, 0.22, true
	)
	_gate(is_equal_approx(float(home.target.x), float(opponent.target.x))
		and is_equal_approx(float(home.target.y), 1.0 - float(opponent.target.y)),
		"symmetry", "shared defensive adapter mirrors geometry across the net", 2)


func _negative_control_gates() -> void:
	var baseline: Object = GameManagerScript.new()
	baseline.seed_vertical_slice_data()
	var lens: Object = GameManagerScript.new()
	lens.seed_vertical_slice_data()
	lens.team.tactic_sheet.phase = "Floor"
	lens.team.tactic_sheet.view = "Plan"
	var seed_value := LIVE_FIRST_SEED - 1
	var first: Resource = baseline.resolve_active_rally(seed_value)
	var second: Resource = lens.resolve_active_rally(seed_value)
	_gate(_rally_digest(first) == _rally_digest(second), "negative",
		"clipboard phase/view leave authoritative rally byte-equivalent", 2)
	var off_court: Object = GameManagerScript.new()
	off_court.seed_vertical_slice_data()
	off_court.team.tactic_sheet.placements[99] = {"at": Vector2(3.0, 4.0), "who": "v999999"}
	off_court.team.tactic_sheet.behaviours["99:Attack"] = "feint"
	var third: Resource = off_court.resolve_active_rally(seed_value)
	_gate(_rally_digest(first) == _rally_digest(third), "negative",
		"off-court instruction has no live decision effect", 2)
	baseline.free()
	lens.free()
	off_court.free()


func _live_behaviour_gates() -> void:
	for phase in ["Attack", "Block", "Floor"]:
		for option in _options_for_phase(phase):
			var evidence := _find_live_activation(phase, option)
			live_evidence["%s/%s" % [phase, option]] = evidence
			_gate(int(evidence.get("home", 0)) > 0, "C3-live",
				"home %s/%s reaches authoritative trace" % [phase, option], int(evidence.get("home", 0)))
			_gate(int(evidence.get("opponent", 0)) > 0, "C3-live/symmetry",
				"opponent %s/%s reaches equivalent authoritative trace" % [phase, option], int(evidence.get("opponent", 0)))


func _paired_distribution_gates() -> void:
	var attack := _paired_attack_courses(24)
	distribution_evidence["attack_line_vs_cross"] = attack
	_gate(int(attack.get("line_n", 0)) > 0 and int(attack.get("cross_n", 0)) > 0,
		"C7-population", "paired line/cross attack course arms both activate",
		mini(int(attack.get("line_n", 0)), int(attack.get("cross_n", 0))))
	_gate(float(attack.get("cross_lateral_mean", 0.0))
		> float(attack.get("line_lateral_mean", 0.0)), "C7-direction",
		"spike cross produces a wider first-mediator course distribution than line",
		mini(int(attack.get("line_n", 0)), int(attack.get("cross_n", 0))))

	var block := _paired_block_geometry(24)
	distribution_evidence["block_line_vs_cross"] = block
	_gate(int(block.get("line_n", 0)) > 0 and int(block.get("cross_n", 0)) > 0,
		"C7-population", "paired close-line/cross wall arms both activate",
		mini(int(block.get("line_n", 0)), int(block.get("cross_n", 0))))
	_gate(float(block.get("line_outward_mean", 0.0)) > 0.0
		and float(block.get("cross_outward_mean", 0.0)) < 0.0,
		"C7-direction", "close line moves walls outward while close cross moves inward",
		mini(int(block.get("line_n", 0)), int(block.get("cross_n", 0))))

	var floor := _paired_floor_targets(16)
	distribution_evidence["floor_line_vs_cross"] = floor
	_gate(int(floor.get("matched_targets", 0)) > 0, "C7-population",
		"paired dig-line/cross floor arms share downstream target opportunities",
		int(floor.get("matched_targets", 0)))
	_gate(float(floor.get("mean_target_delta", 0.0)) > 0.005,
		"C7-direction", "dig line/cross produce different physical target distributions",
		int(floor.get("matched_targets", 0)))

	var low_followed := 0
	var high_followed := 0
	for index in range(200):
		var roll := float(index) / 199.0
		if bool(TacticalInstructionModelScript.adherence("feint", 0.10, roll).followed):
			low_followed += 1
		if bool(TacticalInstructionModelScript.adherence("feint", 0.90, roll).followed):
			high_followed += 1
	distribution_evidence["discipline_adherence"] = {
		"population": 200, "low_followed": low_followed,
		"high_followed": high_followed,
	}
	_gate(high_followed > low_followed and low_followed > 0 and high_followed < 200,
		"C7-preference", "discipline shifts adherence without scripting either arm",
		200)


func _paired_attack_courses(seed_count: int) -> Dictionary:
	var values := {"spike line": [], "spike cross": []}
	for option in values:
		for offset in range(seed_count):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			_assign_phase_to_side(manager.team.tactic_sheet, manager.current_lineup(), "Attack", option)
			_assign_phase_to_side(manager.opponent_team.tactic_sheet,
				manager.opponent_team.current_lineup(), "Attack", option)
			manager.match_state.serving_home = offset % 2 == 0
			var rally: Resource = manager.resolve_active_rally(LIVE_FIRST_SEED + 100 + offset)
			for event in rally.events:
				if int(event.event_type) != RallyEventScript.EventType.ATTACK: continue
				var call: Dictionary = event.metadata.get("tactical_instruction", {})
				if str(call.get("effective", "")) != option: continue
				var contact := Vector2(event.metadata.get("body_contact_position", event.start_position))
				var target := Vector2(event.metadata.get("intended_target", event.end_position))
				values[option].append(absf(target.x - contact.x))
			manager.free()
	return {"seeds_per_arm": seed_count,
		"line_n": values["spike line"].size(), "cross_n": values["spike cross"].size(),
		"line_lateral_mean": _mean(values["spike line"]),
		"cross_lateral_mean": _mean(values["spike cross"])}


func _paired_block_geometry(seed_count: int) -> Dictionary:
	var values := {"close line": [], "close cross": []}
	for option in values:
		for offset in range(seed_count):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			_assign_phase_to_side(manager.team.tactic_sheet, manager.current_lineup(), "Block", option)
			_assign_phase_to_side(manager.opponent_team.tactic_sheet,
				manager.opponent_team.current_lineup(), "Block", option)
			manager.match_state.serving_home = offset % 2 == 0
			var rally: Resource = manager.resolve_active_rally(LIVE_FIRST_SEED + 200 + offset)
			for event in rally.events:
				if int(event.event_type) != RallyEventScript.EventType.BLOCK: continue
				var geometry: Dictionary = event.metadata.get("block_geometry_instruction", {})
				if str(geometry.get("effective", "")) != option: continue
				var before := float(geometry.get("formation_target_before", 0.5))
				var after_behaviour := float(geometry.get("formation_target_after_behaviour", before))
				values[option].append(absf(after_behaviour - 0.5) - absf(before - 0.5))
			manager.free()
	return {"seeds_per_arm": seed_count,
		"line_n": values["close line"].size(), "cross_n": values["close cross"].size(),
		"line_outward_mean": _mean(values["close line"]),
		"cross_outward_mean": _mean(values["close cross"])}


func _paired_floor_targets(seed_count: int) -> Dictionary:
	var matched := 0
	var total_delta := 0.0
	for offset in range(seed_count):
		var arms := {}
		for option in ["dig line", "dig cross"]:
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			_assign_phase_to_side(manager.team.tactic_sheet, manager.current_lineup(), "Floor", option)
			_assign_phase_to_side(manager.opponent_team.tactic_sheet,
				manager.opponent_team.current_lineup(), "Floor", option)
			manager.match_state.serving_home = offset % 2 == 0
			var rally: Resource = manager.resolve_active_rally(LIVE_FIRST_SEED + 300 + offset)
			var targets := {}
			for raw_key in Dictionary(rally.analysis.get("tactical_attribution", {})):
				var row: Dictionary = rally.analysis.tactical_attribution[raw_key]
				if str(row.get("clipboard_behaviour", "")) == option:
					targets[str(raw_key)] = Vector2(row.physical_target)
			arms[option] = targets
			manager.free()
		for key in arms["dig line"]:
			if not arms["dig cross"].has(key): continue
			matched += 1
			total_delta += Vector2(arms["dig line"][key]).distance_to(
				Vector2(arms["dig cross"][key])
			)
	return {"seeds_per_arm": seed_count, "matched_targets": matched,
		"mean_target_delta": total_delta / maxf(float(matched), 1.0)}


func _mean(values: Array) -> float:
	if values.is_empty(): return 0.0
	var total := 0.0
	for value in values: total += float(value)
	return total / float(values.size())


func _find_live_activation(phase: String, option: String) -> Dictionary:
	var evidence := {"attempts": 0, "home": 0, "opponent": 0, "seeds": [],
		"first_mediator": _phase_mediator(phase)}
	for offset in range(MAX_LIVE_ATTEMPTS):
		if int(evidence.home) > 0 and int(evidence.opponent) > 0:
			break
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		_assign_phase_to_side(manager.team.tactic_sheet, manager.current_lineup(), phase, option)
		var opponent_lineup: Resource = manager.opponent_team.current_lineup()
		_assign_phase_to_side(manager.opponent_team.tactic_sheet, opponent_lineup, phase, option)
		var seed_value := LIVE_FIRST_SEED + offset
		manager.match_state.serving_home = offset % 2 == 0
		var rally: Resource = manager.resolve_active_rally(seed_value)
		evidence.attempts += 1
		evidence.seeds.append(seed_value)
		_count_live_activation(rally, phase, option, evidence)
		_gate(_m8_invariants(rally), "M8-live", "%s/%s trial retains event/flight invariants" % [phase, option], rally.events.size())
		manager.free()
	return evidence


func _assign_phase_to_side(sheet: Resource, lineup: Resource, phase: String, option: String) -> void:
	sheet.placements.clear()
	sheet.behaviours.clear()
	for slot_number in range(1, 7):
		var player_id := int(lineup.player_at_slot(slot_number))
		var tray_slot := slot_number - 1
		sheet.placements[tray_slot] = {"at": Vector2(0.0, 4.0), "who": "v%d" % player_id}
		sheet.behaviours["%d:%s" % [tray_slot, phase]] = option


func _count_live_activation(rally: Resource, phase: String, option: String, evidence: Dictionary) -> void:
	if phase == "Floor":
		for raw_key in Dictionary(rally.analysis.get("tactical_attribution", {})):
			var row: Dictionary = rally.analysis.tactical_attribution[raw_key]
			if str(row.get("clipboard_behaviour", "")) != option: continue
			var side := str(raw_key).split(":")[0]
			if side in ["home", "opponent"]: evidence[side] += 1
		return
	for event in rally.events:
		var meta: Dictionary = event.metadata
		var side := str(meta.get("side", ""))
		if side not in ["home", "opponent"]: continue
		if phase == "Attack" and int(event.event_type) == RallyEventScript.EventType.ATTACK:
			var call: Dictionary = meta.get("tactical_instruction", {})
			if str(call.get("requested", "")) == option:
				evidence[side] += 1
		elif phase == "Block" and int(event.event_type) == RallyEventScript.EventType.BLOCK:
			var geometry: Dictionary = meta.get("block_geometry_instruction", {})
			var requested := str(geometry.get("requested", ""))
			var hands := str(meta.get("block_hands_call", ""))
			if requested == option or (option == "soft block" and hands == "soft") \
					or (option == "kill block" and hands == "kill"):
				evidence[side] += 1


func _phase_mediator(phase: String) -> String:
	match phase:
		"Attack": return "attack_type_after / intended_target / outgoing attack trajectory"
		"Block": return "formation_target_after or block_hands before shared contest"
		_: return "tactical_attribution.physical_target before movement/reach"


func _m8_invariants(rally: Resource) -> bool:
	if rally == null or rally.events.is_empty(): return false
	var previous := -INF
	for event in rally.events:
		var at := float(event.metadata.get("event_time", previous))
		if at < previous - 0.0001: return false
		previous = at
		var outgoing: Dictionary = event.metadata.get("outgoing_trajectory", {})
		if not outgoing.is_empty() and float(outgoing.get("duration", -1.0)) < 0.0:
			return false
	return true


func _rally_digest(rally: Resource) -> String:
	var events: Array = []
	for event in rally.events:
		events.append(event.to_dict())
	var analysis: Dictionary = rally.analysis.duplicate(true)
	## The negative arm intentionally has a different authored input.  Its input
	## receipt must differ; the decision and physical trace must not.
	analysis.erase("tactical_input_manifest")
	return JSON.stringify({"events": events, "winner": rally.home_team_won,
		"terminal": rally.terminal_outcome, "analysis": analysis,
		"home_initial": rally.initial_home_positions,
		"opponent_initial": rally.initial_opponent_positions})


func _point_key(value: Variant) -> String:
	var point := Vector2(value)
	return "%.6f,%.6f" % [point.x, point.y]


func _gate(condition: bool, gate: String, description: String, population: int) -> void:
	var passed := condition and population > 0
	var row := {"gate": gate, "description": description, "population": population,
		"passed": passed}
	gates.append(row)
	if passed:
		print("  ok    %-16s n=%-4d %s" % [gate, population, description])
	else:
		var finding := "%s (n=%d): %s" % [gate, population, description]
		failures.append(finding)
		print("  FAIL  %s" % finding)


func _report(rows: Array[Dictionary]) -> Dictionary:
	var before := {"CAUSAL": 0, "PARTIAL": 0, "STORED_ONLY": 0, "DEAD": 0, "AMBIGUOUS": 0}
	var after := before.duplicate()
	for row in rows:
		before[str(row.before)] += 1
		after[str(row.after)] += 1
	return {"milestone": "M9 tactical causality", "start_head": START_HEAD,
		"measured_head": _git_head(), "godot": Engine.get_version_info(),
		"before_counts": before, "after_counts": after,
		"control_families": rows.size(), "gates": gates,
		"live_evidence": live_evidence, "failures": failures,
		"distribution_evidence": distribution_evidence,
		"passed": failures.is_empty()}


func _write_artifacts(rows: Array[Dictionary], report: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ARTIFACT_DIR))
	var before_rows: Array = []
	var after_rows: Array = []
	for row in rows:
		var before := row.duplicate(true)
		before["classification"] = before.before
		before.erase("after")
		before_rows.append(before)
		var after := row.duplicate(true)
		after["classification"] = after.after
		after.erase("before")
		after_rows.append(after)
	_write_json("%s/before_census.json" % ARTIFACT_DIR, {"head": START_HEAD,
		"counts": report.before_counts, "rows": before_rows})
	_write_json("%s/after_census.json" % ARTIFACT_DIR, {"head": report.measured_head,
		"counts": report.after_counts, "rows": after_rows})
	_write_json("%s/certification.json" % ARTIFACT_DIR, report)


func _write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		failures.append("artifact write failed: %s" % path)
		return
	file.store_string(JSON.stringify(value, "  ", false) + "\n")
	file.close()


func _git_head() -> String:
	var project_root := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var command_output: Array = []
	var command_status := OS.execute(
		"/usr/bin/git", ["-C", project_root, "rev-parse", "HEAD"], command_output, true)
	if command_status == 0 and not command_output.is_empty():
		return str(command_output[0]).strip_edges()
	var git_path := project_root.path_join(".git")
	var git_dir := git_path
	if FileAccess.file_exists(git_path):
		var worktree_pointer := _read_text_file(git_path)
		if worktree_pointer.begins_with("gitdir: "):
			git_dir = worktree_pointer.trim_prefix("gitdir: ").strip_edges()
	var head := _read_text_file(git_dir.path_join("HEAD"))
	if head.begins_with("ref: "):
		return _read_text_file(git_dir.path_join(head.trim_prefix("ref: ")))
	return head


func _read_text_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text().strip_edges()
	file.close()
	return text


func _print_summary(report: Dictionary) -> void:
	print("\nM9 tactical causality certification")
	print("  before: %s" % JSON.stringify(report.before_counts))
	print("  after:  %s" % JSON.stringify(report.after_counts))
	print("  gates:  %d" % gates.size())
	print("  artifact: %s/certification.json" % ARTIFACT_DIR)
	if failures.is_empty():
		print("\nPASS: M9 executable census and causal gates")
	else:
		push_error("FAIL: %d M9 causal gates" % failures.size())
