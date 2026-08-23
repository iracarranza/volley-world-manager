extends SceneTree

## Constructed M5 certification. Natural overpass incidence is deliberately not
## an acceptance condition; these fixtures place the shared T1--T3 launch on the
## exact policy boundary and ask what the ordinary first-contact action contest
## does with it.

const PlatformContact := preload(
	"res://scripts/simulation/platform_contact_model.gd"
)
const FreeFlight := preload(
	"res://scripts/simulation/free_flight_interception_system.gd"
)
const OverpassAction := preload(
	"res://scripts/simulation/overpass_action_system.gd"
)

var failures: int = 0


func _initialize() -> void:
	var incoming := _overpass_flight()
	_gate(not incoming.is_empty(), "shared platform fixture produces a flight")
	var frozen := incoming.duplicate(true)

	var attack_fixture := _fixture(true)
	var attack_choice := OverpassAction.choose(
		incoming, attack_fixture.actors, attack_fixture.lineup,
		&"opponent", attack_fixture.principles,
	)
	_print_choice("obvious attack", attack_choice)
	_gate(
		str(attack_choice.get("action", "")) == "attack",
		"obvious overpass attack opportunity can win the ordinary contest",
	)
	var attack_execution := OverpassAction.execute_attack(
		attack_choice, [], [],
		float(attack_fixture.principles.decisiveness), 0.0, 92117,
	)
	_gate(
		bool(attack_execution.get("available", false))
			and not Dictionary(attack_execution.get(
				"outgoing_trajectory", {}
			)).is_empty(),
		"selected attack executes exactly one outgoing physical ball",
	)
	_gate(
		str(Dictionary(attack_execution.get("swing", {})).get(
			"outcome", ""
		)) == "in",
		"open-net attack fixture creates an in-court kill opportunity",
	)

	var unavailable_fixture := _fixture(true)
	var unavailable_attacker := unavailable_fixture.actors[0] as RallyPlayerState
	unavailable_attacker.recovery_until = float(incoming.end_time) + 1.0
	unavailable_attacker.committed_until = unavailable_attacker.recovery_until
	unavailable_attacker.body_state = RallyPlayerState.BodyState.RECOVERING
	var unavailable_choice := OverpassAction.choose(
		incoming, unavailable_fixture.actors, unavailable_fixture.lineup,
		&"opponent", unavailable_fixture.principles,
	)
	_print_choice("attacker unavailable", unavailable_choice)
	_gate(
		int(unavailable_choice.get("player_id", -1))
			!= unavailable_attacker.player_id,
		"a physically unavailable attacker cannot win",
	)

	var control_fixture := _fixture(false)
	var control_choice := OverpassAction.choose(
		incoming, control_fixture.actors, control_fixture.lineup,
		&"opponent", control_fixture.principles,
	)
	_print_choice("control identity", control_choice)
	_gate(
		str(control_choice.get("action", "")) in [
			"controlled_first_contact", "emergency_first_contact",
		],
		"attributes and tactics can move a viable contest from attack to control",
	)
	_gate(
		_has_candidate(attack_choice, "attack")
			and _has_control_candidate(attack_choice)
			and _has_candidate(control_choice, "attack")
			and _has_control_candidate(control_choice),
		"both attack and control remain feasible before attributes/tactics choose",
	)

	var only_control_fixture := _fixture(false)
	var only_attacker := only_control_fixture.actors[0] as RallyPlayerState
	only_attacker.player.position_role = "Libero"
	only_attacker.player.position_code = "L"
	var only_controller := only_control_fixture.actors[1] as RallyPlayerState
	only_controller.player.position_role = "Libero"
	only_controller.player.position_code = "L"
	var only_control := OverpassAction.choose(
		incoming, only_control_fixture.actors, only_control_fixture.lineup,
		&"opponent", only_control_fixture.principles,
	)
	_print_choice("only control legal", only_control)
	_gate(
		str(only_control.get("action", "")) in [
			"controlled_first_contact", "emergency_first_contact",
		] and not _has_candidate(only_control, "attack"),
		"when only control is legal the first contact is control",
	)

	var control_execution := OverpassAction.execute_control(
		control_choice,
		{
			"target_anchor": Vector2(0.50, 0.43),
			"height_anchor_meters": 2.35,
			"arrival_floor_seconds": 0.0,
		},
		92119,
	)
	_gate(
		bool(control_execution.get("available", false))
			and not Dictionary(control_execution.get(
				"outgoing_trajectory", {}
			)).is_empty(),
		"selected platform control executes exactly one shared outgoing ball",
	)

	_gate(
		incoming == frozen,
		"later actor/action choice never mutates the incoming authoritative launch",
	)
	_gate(
		_same_launch(
			incoming, Dictionary(attack_choice.get("realised_trajectory", {}))
		) and _same_launch(
			incoming, Dictionary(control_choice.get("realised_trajectory", {}))
		),
		"every realised incoming segment is a prefix of the unchanged free flight",
	)

	var attack_apply := _apply_fixture(
		attack_fixture, incoming, attack_choice, attack_execution
	)
	var control_apply := _apply_fixture(
		control_fixture, incoming, control_choice, control_execution
	)
	_gate(
		int(attack_apply.get("team_contact_number", -1)) == 1
			and int(attack_apply.get("ball_contact_count", -1)) == 1,
		"an overpass attack is the receiving team's first contact",
	)
	_gate(
		int(control_apply.get("team_contact_number", -1)) == 1
			and int(control_apply.get("ball_contact_count", -1)) == 1,
		"controlled/emergency overpass play is the receiving team's first contact",
	)
	_gate(
		StringName(attack_apply.get("ball_last_touch_side", &"")) == &"opponent"
			and StringName(control_apply.get(
				"ball_last_touch_side", &""
			)) == &"opponent",
		"possession changes to the team that actually made the overpass contact",
	)

	if failures == 0:
		print("\nPASS: overpass ordinary-first-contact policy gates")
	quit(0 if failures == 0 else 1)


func _overpass_flight() -> Dictionary:
	var contact := Vector2(0.50, 0.62)
	var resolved := PlatformContact.evaluate({
		"incoming_velocity_mps": Vector3(0.0, -20.0, 14.0),
		"contact_position": contact,
		"contact_height_meters": 0.95,
		"body_velocity_mps": Vector2.ZERO,
		"circumstance_severity": 0.8,
		"stability_ability": 1.0,
		"technique_ability": 0.8,
		"intent_target_anchor": Vector2(0.50, 0.52),
		"intent_height_anchor_meters": 2.35,
		"intent_arrival_floor_seconds": 0.45,
		"seed": 88421,
	})
	if not resolved.has("realised_velocity_mps"):
		return {}
	return FreeFlight.from_launch(
		"dig", contact, 0.95, Vector3(resolved.realised_velocity_mps),
		0.0, "constructed-overpass",
	)


func _fixture(attack_identity: bool) -> Dictionary:
	var hitter := _player(201, "Tape attacker", "Outside Hitter", "OH1")
	var controller := _player(202, "First-ball controller", "Setter", "S")
	if attack_identity:
		_set_attack(hitter, 94)
		_set_control(hitter, 42)
		_set_attack(controller, 38)
		_set_control(controller, 66)
	else:
		_set_attack(hitter, 58)
		_set_control(hitter, 45)
		_set_attack(controller, 44)
		_set_control(controller, 96)
	var hitter_actor := RallyPlayerState.create(
		hitter, &"opponent", 3, Vector2(0.50, 0.43)
	)
	var controller_actor := RallyPlayerState.create(
		controller, &"opponent", 6, Vector2(0.50, 0.30)
	)
	var actors: Array[RallyPlayerState] = [hitter_actor, controller_actor]
	var lineup := RotationLineup.new()
	lineup.setter_id = controller.id
	lineup.designated_setter_ids = [controller.id]
	lineup.assign_slot(3, hitter.id)
	lineup.assign_slot(6, controller.id)
	var principles := TeamPrinciples.new()
	principles.decisiveness = 0.95 if attack_identity else 0.05
	principles.transition_commitment = 0.95 if attack_identity else 0.20
	return {
		"actors": actors,
		"lineup": lineup,
		"principles": principles,
	}


func _player(
	player_id: int, player_name: String, role: String, code: String
) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = player_id
	player.display_name = player_name
	player.position_role = role
	player.position_code = code
	player.height_cm = 190
	player.wingspan_cm = 198
	player.jump_reach = 72
	player.explosiveness = 72
	player.acceleration = 72
	player.lateral_speed = 72
	player.transition_speed = 72
	player.composure = 75
	player.decision_making = 75
	player.anticipation = 75
	player.court_vision = 75
	player.tactical_discipline = 75
	return player


func _set_attack(player: VolleyballPlayer, value: int) -> void:
	player.attack_power = value
	player.attack_accuracy = value
	player.approach_timing = value
	player.shot_variety = value
	player.finesse = value


func _set_control(player: VolleyballPlayer, value: int) -> void:
	player.reception = value
	player.ball_control = value
	player.dig_control = value
	player.reception_balance = value
	player.reception_stability = value


func _apply_fixture(
	fixture: Dictionary,
	incoming: Dictionary,
	choice: Dictionary,
	execution: Dictionary,
) -> Dictionary:
	var state := RallyState.new()
	state.opponent_lineup = fixture.lineup
	for actor in fixture.actors:
		state.opponent_players[actor.player_id] = actor.snapshot()
	state.possession = &"home"
	state.contact_number = 1
	state.ball.last_touch_side = &"home"
	state.ball.last_touch_player_id = 101
	state.ball.contact_count = 1
	state.ball.trajectory = BallTrajectory.from_dict(incoming)
	return OverpassAction.apply_first_contact(
		state, &"opponent", choice, execution
	)


func _has_candidate(choice: Dictionary, action: String) -> bool:
	for raw_candidate in choice.get("candidates", []):
		if str(Dictionary(raw_candidate).get("action", "")) == action:
			return true
	return false


func _has_control_candidate(choice: Dictionary) -> bool:
	return _has_candidate(choice, "controlled_first_contact") \
		or _has_candidate(choice, "emergency_first_contact")


func _same_launch(free_flight: Dictionary, realised: Dictionary) -> bool:
	return not realised.is_empty() \
		and str(realised.get("authoritative_flight_id", "")) \
			== str(free_flight.get("authoritative_flight_id", "")) \
		and Vector3(realised.get("launch_velocity_mps", Vector3.ZERO)).is_equal_approx(
			Vector3(free_flight.get("launch_velocity_mps", Vector3.ZERO))
		) \
		and float(realised.get("end_time", INF)) \
			<= float(free_flight.get("end_time", -INF)) + 0.000001


func _print_choice(label: String, choice: Dictionary) -> void:
	print("\n%s: action=%s actor=%s score=%.4f" % [
		label, str(choice.get("action", "missing")),
		str(choice.get("player_id", -1)), float(choice.get("score", 0.0)),
	])
	for raw_candidate in choice.get("candidates", []):
		var candidate: Dictionary = raw_candidate
		print("  %s actor=%d score=%.4f terms=%s" % [
			str(candidate.get("action", "")),
			int(candidate.get("player_id", -1)),
			float(candidate.get("score", 0.0)),
			str(candidate.get("score_terms", {})),
		])


func _gate(condition: bool, description: String) -> void:
	if condition:
		print("  PASS  %s" % description)
	else:
		failures += 1
		push_error("  FAIL  %s" % description)
