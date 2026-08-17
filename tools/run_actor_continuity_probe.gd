extends SceneTree

## Does a body's compromised state survive a leg boundary?
##
##     godot --headless --path . --script res://tools/run_actor_continuity_probe.gd
##
## Two certified repairs were latent because it did not:
## `ContactEnvelopeSystem`'s AIRBORNE takeoff exclusion
## (`READINESS_REMOVAL.md` §3) and the claimant's usable-time requirement
## (`SHORT_BALL_RESPONSIBILITY.md` §4). Each was correct, each fired in a
## deliberately constructed fixture, and neither changed a live rally.
##
## The gap was smaller than "carry an actor between legs". `rally_simulator.gd`
## never calls `ContactEnvelopeSystem` at all -- the envelope is reached only
## from the shadow systems, which read `RallyState` actors -- and the resolver
## **rebuilds a fresh `RallyState` per phase**, seeded from `live_positions` and
## `live_velocities` only. `player_recovery` already carried both the debt and a
## *name* for it. Nothing read the name back.
##
## Gates:
##   C1  a phase state is seeded with the recovery a body still owes
##   C2  a block landing survives as AIRBORNE, a floor trip as RECOVERING
##   C3  a body that owes nothing is left exactly as the builder made it
##   C4  no duplicate actor: one state object per player per phase
##   C5  the seeding resets per rally
##   C6  and it reaches the envelope -- an airborne body cannot take off

const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const RallyStateBuilderModel := preload(
	"res://scripts/simulation/rally_state_builder.gd"
)
const ContactEnvelopeModel := preload(
	"res://scripts/simulation/contact_envelope_system.gd"
)
const GameManagerScript := preload("res://scripts/managers/game_manager.gd")

var _pass_count: int = 0
var _fail_count: int = 0
var _failures: Array[String] = []


func _initialize() -> void:
	_gates()
	_summary()
	quit()


func _verdict(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
	else:
		_fail_count += 1
		_failures.append(label)
	print("      %s  %s" % ["PASS" if condition else "FAIL", label])


func _gates() -> void:
	print("=".repeat(78))
	print("ACTOR CONTINUITY -- does a compromised body survive the boundary?")
	print("=".repeat(78))
	var manager: Object = GameManagerScript.new()
	manager.seed_vertical_slice_data()
	var lineup: RotationLineup = manager.current_lineup()
	var simulator: Object = RallySimulatorScript.new()
	simulator.rally_seed = 4242

	var front := lineup.front_row_player_ids()
	var blocker_id := int(front[0])
	var digger_id := int(front[1]) if front.size() > 1 else int(front[0])
	var untouched_id := int(front[2]) if front.size() > 2 else -1

	## The debt the resolver itself writes, through the same field.
	simulator.player_recovery = {
		blocker_id: {"state": "airborne", "ready_at": 1.40, "delay": 0.36},
		digger_id: {"state": "fall", "ready_at": 1.20, "delay": 0.34},
	}

	var state: RallyState = RallyStateBuilderModel.build(
		manager.players, lineup, manager.defensive_plans.get(
			lineup.rotation_number
		), manager.opponent_team, null, true, 4242,
	)
	print("\n  Fresh phase state built. Seeding at t = 0.90 s, so both debts are")
	print("  still owed and any third body is clean.\n")
	print("      %-10s %-14s %-16s %-14s" % [
		"voli", "carried", "body_state", "recovery_until",
	])
	simulator._seed_carried_body_states(state, 0.90)
	for player_id in [blocker_id, digger_id, untouched_id]:
		if player_id < 0:
			continue
		var actor: RallyPlayerState = state.player_state(&"home", player_id)
		if actor == null:
			continue
		print("      %-10d %-14s %-16s %-14.2f" % [
			player_id,
			str(Dictionary(simulator.player_recovery.get(player_id, {})).get(
				"state", "-"
			)),
			RallyPlayerState.BodyState.keys()[actor.body_state],
			actor.recovery_until,
		])

	var blocker: RallyPlayerState = state.player_state(&"home", blocker_id)
	var digger: RallyPlayerState = state.player_state(&"home", digger_id)
	_verdict(
		blocker != null and is_equal_approx(blocker.recovery_until, 1.40)
			and digger != null and is_equal_approx(digger.recovery_until, 1.20),
		"C1: a phase state is seeded with the recovery a body still owes",
	)
	_verdict(
		blocker != null
			and blocker.body_state == RallyPlayerState.BodyState.AIRBORNE
			and digger != null
			and digger.body_state == RallyPlayerState.BodyState.RECOVERING,
		"C2: a block landing survives as AIRBORNE, a floor trip as RECOVERING",
	)
	if untouched_id >= 0:
		var untouched: RallyPlayerState = state.player_state(&"home", untouched_id)
		_verdict(
			untouched != null
				and untouched.body_state == RallyPlayerState.BodyState.BALANCED
				and is_zero_approx(untouched.recovery_until),
			"C3: a body owing nothing is left exactly as the builder made it",
		)

	## C4 -- one actor per player. `player_state` must hand back the same object
	## every time, or a seeded body and the body a system reads are two bodies.
	var again: RallyPlayerState = state.player_state(&"home", blocker_id)
	var seen := {}
	var duplicates := 0
	for actor in state.all_player_states():
		if seen.has(actor.player_id):
			duplicates += 1
		seen[actor.player_id] = true
	_verdict(
		again == blocker and duplicates == 0,
		"C4: one actor per player per phase, and lookups return that same actor",
	)

	## C5 -- and it does not leak between rallies.
	var second: Object = RallySimulatorScript.new()
	second.rally_seed = 4242
	var clean_state: RallyState = RallyStateBuilderModel.build(
		manager.players, lineup, manager.defensive_plans.get(
			lineup.rotation_number
		), manager.opponent_team, null, true, 4242,
	)
	second._seed_carried_body_states(clean_state, 0.90)
	var clean: RallyPlayerState = clean_state.player_state(&"home", blocker_id)
	_verdict(
		clean != null and clean.body_state == RallyPlayerState.BodyState.BALANCED,
		"C5: a new rally starts with nobody carrying anything",
	)

	## C6 -- the consequence. This is the whole point: the seeded state has to
	## reach the contact envelope, which is where the AIRBORNE exclusion lives.
	print("\n  %-16s %-18s %-14s" % ["body", "state", "jump available"])
	var heights := {}
	for label in ["carried airborne", "clean"]:
		var subject: RallyPlayerState = blocker if label.begins_with("carried") \
			else clean
		var envelope: Dictionary = ContactEnvelopeModel.evaluate(
			subject, &"attack", 3.10, 1.20, true,
		)
		var jump := float(envelope.get("maximum_contact_height_meters", 0.0)) \
			- float(envelope.get("standing_reach_meters", 0.0))
		heights[label] = jump
		print("  %-16s %-18s %-14s" % [
			label, RallyPlayerState.BodyState.keys()[subject.body_state],
			"%.4f m" % jump if jump > 0.001 else "NO",
		])
	_verdict(
		is_zero_approx(heights["carried airborne"])
			and heights["clean"] > 0.001,
		"C6: a body carried in airborne cannot take off again; a clean one can",
	)


func _summary() -> void:
	print("\n" + "=".repeat(78))
	print("GATES: %d pass, %d fail" % [_pass_count, _fail_count])
	for failure in _failures:
		print("  FAILED: %s" % failure)
	print("=".repeat(78))
