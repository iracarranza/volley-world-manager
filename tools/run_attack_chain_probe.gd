extends SceneTree

## The forward walk from the generated set: approach, attack, block, defence,
## dig, and back into the same setting loop.
##
##     godot --headless --path . --script res://tools/run_attack_chain_probe.gd
##
## Each section is a checkpoint rather than a project. The question at every node
## is the same one:
##
##     authoritative ball -> responsibility -> decision -> feasibility
##     -> action -> execution -> ONE outgoing ball -> next leg
##
## and specifically whether execution quality anywhere in it creates time, reach,
## movement, responsibility or a different target.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")
const SetPathReadModel := preload("res://scripts/simulation/set_path_read_model.gd")

const FIRST_SEED: int = 83000
const SEED_COUNT: int = 300

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0


func _initialize() -> void:
	_node_hitter_approach()
	_census()
	quit()


func _metres(a: Vector2, b: Vector2) -> float:
	return Vector2(
		(a.x - b.x) * COURT_WIDTH_METERS, (a.y - b.y) * COURT_LENGTH_METERS
	).length()


func _hitter(overrides: Dictionary = {}) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = 601
	player.display_name = "Hitter"
	for attribute in [
		"court_vision", "anticipation", "approach_timing", "composure",
		"attack_accuracy", "ball_control", "improvisation", "attack_power",
		"acceleration", "lateral_speed", "transition_speed", "stamina",
		"work_rate", "jump_reach", "explosiveness",
	]:
		player.set(attribute, 50)
	for attribute in overrides:
		player.set(attribute, overrides[attribute])
	player.fatigue = 0.0
	return player


## ==================================================== NODE -- HITTER APPROACH
##
## The first open boundary after `71cbbe1`: the attacking assignment is chosen
## before the set exists, and `_delivered_point` scatters the ball away from the
## target the assignment was made against.
##
## The four stages that have to stay distinct:
##
##   A  pre-set commitment -- the approach may legitimately be run at the
##      *intended* target, because that is all that exists yet;
##   B  observation -- once the ball is real, the hitter reads it;
##   C  late adjustment -- whatever the remaining flight physically allows;
##   D  contact -- resolved against where the body actually got, versus where the
##      ball actually is.
##
## The failure this looks for is the engine assuming an approach to the intended
## point also reaches the delivered ball.
func _node_hitter_approach() -> void:
	print("=".repeat(78))
	print("NODE -- HITTER APPROACH")
	print("=".repeat(78))
	var hitter := _hitter()
	var intended := Vector2(0.18, 0.56)

	print("\n  A/B -- the read: does the hitter track the ball it can now see?")
	print("  Same hitter, same intended target, same flight. Only the")
	print("  delivered point moves -- which is the scatter the set produced.")
	print("  %-12s %-9s %-11s %-13s %-13s" % [
		"scatter_m", "tracking", "perceived_m", "toward_ball_m", "residual_m",
	])
	for scatter in [0.0, 0.15, 0.35, 0.60, 1.00, 1.60]:
		var delivered := intended + Vector2(
			float(scatter) / COURT_WIDTH_METERS, 0.0
		)
		var read: Dictionary = SetPathReadModel.evaluate(
			hitter, intended, delivered, 1.10, 0.62, 0.5, 4242, "probe", true
		)
		var perceived := Vector2(read.perceived_contact)
		print("  %-12.3f %-9.4f %-11.4f %-13.4f %-13.4f" % [
			float(scatter), float(read.read_quality),
			_metres(perceived, intended),
			_metres(perceived, intended), _metres(perceived, delivered),
		])
	print("  -> perceived sits BETWEEN intended and delivered. A hitter who")
	print("     knew the delivery would show residual 0 at every scatter; one")
	print("     who ignored it would show `toward_ball` 0 instead.")

	print("\n  B -- tracking is bought with flight time and ability, not given")
	print("  %-12s %-13s %-13s %-13s" % [
		"flight_s", "tracking(50)", "tracking(90)", "tracking(15)",
	])
	for flight in [0.20, 0.35, 0.55, 0.80, 1.05, 1.60]:
		var cells: Array[String] = []
		for rating in [50, 90, 15]:
			var reader := _hitter({
				"court_vision": rating, "anticipation": rating,
				"approach_timing": rating, "composure": rating,
			})
			var read: Dictionary = SetPathReadModel.evaluate(
				reader, intended, intended + Vector2(0.08, 0.0),
				float(flight), 0.62, 0.5, 4242, "probe", true
			)
			cells.append("%.4f" % float(read.read_quality))
		print("  %-12.2f %-13s %-13s %-13s" % [
			float(flight), cells[0], cells[1], cells[2],
		])
	print("  -> a ball in the air longer is read better, and a better reader")
	print("     reads it better. Neither is a constant.")

	print("\n  C -- the late adjustment is clamped by the remaining flight")
	print("  `_reachable_contact` pulls the contact back toward the body when")
	print("  the trip cannot be made; it never moves the ball to the hitter.")
	var simulator: Object = RallySimulatorScript.new()
	simulator.rally_seed = 4242
	print("  %-12s %-12s %-13s %-15s" % [
		"budget_s", "trip_s", "reached_m", "short_by_m",
	])
	var body_start := Vector2(0.34, 0.62)
	var wanted := Vector2(0.18, 0.56)
	var trip: float = simulator._movement_time(
		hitter, body_start, wanted, "transition"
	)
	for budget in [0.10, 0.25, 0.40, 0.70, 1.20]:
		var reached: Vector2 = simulator._reachable_contact(
			body_start, wanted, trip, float(budget)
		)
		print("  %-12.2f %-12.4f %-13.4f %-15.4f" % [
			float(budget), trip, _metres(reached, body_start),
			_metres(reached, wanted),
		])
	print("  required trip %.4f m in %.4f s" % [_metres(body_start, wanted), trip])

	print("\n  D -- contact is scored on the gap between body and BALL")
	print("  %-13s %-11s %-11s %-13s" % [
		"body_error_m", "outcome", "quality_x", "whiff?",
	])
	for error in [0.0, 0.10, 0.20, 0.35, 0.55, 0.80, 1.20]:
		var actual := wanted + Vector2(float(error) / COURT_WIDTH_METERS, 0.0)
		var contact: Dictionary = SetPathReadModel.assess_contact(
			hitter, actual, wanted
		)
		print("  %-13.3f %-11s %-11.4f %-13s" % [
			float(error), str(contact.outcome),
			float(contact.quality_multiplier),
			"YES" if bool(contact.whiffed) else "-",
		])
	print("  -> a hitter who cannot reach the delivered ball mishits or whiffs.")
	print("     That is the gap being paid at contact rather than forgiven.")


## ===================================================================== census
##
## The whole remaining chain in situ, reading only published facts.
func _census() -> void:
	print("\n" + "=".repeat(78))
	print("CENSUS -- %d isolated rallies per serving side" % SEED_COUNT)
	print("=".repeat(78))
	var counts := {
		"attacks": 0, "whiffs": 0, "mishits": 0, "strained": 0, "clean": 0,
		"late_hitters": 0, "blocks": 0, "digs": 0, "dig_success": 0,
		"sets": 0,
	}
	var read_error_total := 0.0
	var read_error_n := 0
	var approach_margin_total := 0.0
	var scatter_total := 0.0
	var scatter_n := 0
	var block_outcomes := {}
	var terminal_after_block := 0
	var chain := {
		"set_into_attack": 0, "set_into_attack_ok": 0,
		"attack_into_defence": 0, "attack_into_defence_ok": 0,
		"dig_into_set": 0, "dig_into_set_ok": 0,
	}
	var outcomes := {}
	var home_points := 0
	var rallies := 0
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			rallies += 1
			if rally == null:
				manager.free()
				continue
			var outcome := str(rally.terminal_outcome)
			outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
			if bool(rally.home_team_won):
				home_points += 1
			var last_ball := {}
			var last_set := {}
			var last_attack := {}
			var seen_terminal_block := false
			for event in rally.events:
				var kind := int(event.event_type)
				var metadata: Dictionary = event.metadata
				if kind == RallyEventScript.EventType.SET:
					counts["sets"] = int(counts.sets) + 1
					var intended := Vector2(metadata.get(
						"intended_target", event.end_position
					))
					scatter_total += _metres(intended, event.end_position)
					scatter_n += 1
					if not last_ball.is_empty():
						pass
					last_set = Dictionary(
						metadata.get("outgoing_trajectory", {})
					)
					last_ball = last_set
					continue
				if kind == RallyEventScript.EventType.ATTACK:
					counts["attacks"] = int(counts.attacks) + 1
					var swung_at := Dictionary(
						metadata.get("incoming_trajectory", {})
					)
					if not last_set.is_empty() and not swung_at.is_empty():
						chain["set_into_attack"] = int(chain.set_into_attack) + 1
						if _same_ball(last_set, swung_at):
							chain["set_into_attack_ok"] = \
								int(chain.set_into_attack_ok) + 1
					var path := str(metadata.get("set_path_outcome", "?"))
					if path == "whiff":
						counts["whiffs"] = int(counts.whiffs) + 1
					elif path == "mishit":
						counts["mishits"] = int(counts.mishits) + 1
					elif path == "strained":
						counts["strained"] = int(counts.strained) + 1
					elif path == "clean":
						counts["clean"] = int(counts.clean) + 1
					if metadata.has("set_path_error_meters"):
						read_error_total += float(metadata.set_path_error_meters)
						read_error_n += 1
					var margin := float(metadata.get("arrival_margin", 0.0))
					approach_margin_total += margin
					if margin < 0.0:
						counts["late_hitters"] = int(counts.late_hitters) + 1
					last_attack = Dictionary(
						metadata.get("outgoing_trajectory", {})
					)
					last_ball = last_attack
					continue
				if kind == RallyEventScript.EventType.BLOCK:
					counts["blocks"] = int(counts.blocks) + 1
					var block_outcome := str(metadata.get("outcome", "?"))
					block_outcomes[block_outcome] = int(
						block_outcomes.get(block_outcome, 0)
					) + 1
					var published := Dictionary(
						metadata.get("outgoing_trajectory", {})
					)
					if not published.is_empty():
						last_ball = published
					continue
				if kind == RallyEventScript.EventType.DIG:
					counts["digs"] = int(counts.digs) + 1
					if bool(event.success):
						counts["dig_success"] = int(counts.dig_success) + 1
					if seen_terminal_block:
						terminal_after_block += 1
					var faced := Dictionary(
						metadata.get("incoming_trajectory", {})
					)
					if not last_ball.is_empty() and not faced.is_empty():
						chain["attack_into_defence"] = \
							int(chain.attack_into_defence) + 1
						if _same_ball(last_ball, faced):
							chain["attack_into_defence_ok"] = \
								int(chain.attack_into_defence_ok) + 1
					var published := Dictionary(
						metadata.get("outgoing_trajectory", {})
					)
					if not published.is_empty():
						last_ball = published
					continue
				var any_ball := Dictionary(
					metadata.get("outgoing_trajectory", {})
				)
				if not any_ball.is_empty():
					last_ball = any_ball
			manager.free()

	var attacks := maxf(float(counts.attacks), 1.0)
	print("  rallies %d, sets %d, attacks %d, blocks %d, defensive contacts %d" % [
		rallies, int(counts.sets), int(counts.attacks), int(counts.blocks),
		int(counts.digs),
	])
	print("\n  APPROACH")
	print("      mean set scatter (intent -> delivered) %.4f m"
		% (scatter_total / maxf(float(scatter_n), 1.0)))
	print("      mean body-to-ball error at contact     %.4f m"
		% (read_error_total / maxf(float(read_error_n), 1.0)))
	print("      mean approach margin                   %.4f s"
		% (approach_margin_total / attacks))
	print("      late hitters %d (%.4f)" % [
		int(counts.late_hitters), float(counts.late_hitters) / attacks,
	])
	print("      contact quality: clean %d, strained %d, mishit %d, whiff %d" % [
		int(counts.clean), int(counts.strained), int(counts.mishits),
		int(counts.whiffs),
	])

	print("\n  BLOCK")
	var block_names: Array = block_outcomes.keys()
	block_names.sort()
	for name in block_names:
		print("      %-22s %-6d %.4f" % [
			name, int(block_outcomes[name]),
			float(block_outcomes[name]) / maxf(float(counts.blocks), 1.0),
		])

	print("\n  DEFENCE")
	print("      defensive contacts %d, successful %d (%.4f)" % [
		int(counts.digs), int(counts.dig_success),
		float(counts.dig_success) / maxf(float(counts.digs), 1.0),
	])

	print("\n  ONE BALL")
	print("      set  -> attack   %d / %d" % [
		int(chain.set_into_attack_ok), int(chain.set_into_attack),
	])
	print("      ball -> defence  %d / %d" % [
		int(chain.attack_into_defence_ok), int(chain.attack_into_defence),
	])

	print("\n  RALLY OUTCOMES  (regression observation, never a target)")
	print("      home points %d of %d (%.4f)" % [
		home_points, rallies, float(home_points) / maxf(float(rallies), 1.0),
	])
	var outcome_names: Array = outcomes.keys()
	outcome_names.sort()
	for name in outcome_names:
		print("      %-28s %-5d %.4f" % [
			name, int(outcomes[name]),
			float(outcomes[name]) / maxf(float(rallies), 1.0),
		])


func _same_ball(first: Dictionary, second: Dictionary) -> bool:
	return Vector2(first.get("start_position", Vector2.ZERO)).is_equal_approx(
			Vector2(second.get("start_position", Vector2.ONE))
		) and Vector2(first.get("end_position", Vector2.ZERO)).is_equal_approx(
			Vector2(second.get("end_position", Vector2.ONE))
		) and is_equal_approx(
			float(first.get("duration", -1.0)), float(second.get("duration", -2.0))
		)
