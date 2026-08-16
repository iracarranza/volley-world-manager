extends SceneTree

## NODE 1 of the forward walk: given the selected second contact, who is the
## intended attacking option?
##
##     godot --headless --path . --script res://tools/run_choose_hitter_probe.gd
##
## **This is a decision node, not a physical-success predictor.** Whether the
## chosen hitter can actually complete the approach belongs to the later
## movement/approach stage, and this probe deliberately does not ask it to.
##
## `_choose_assignment` is driven directly with a synthetic `OffensivePlay`, six
## volis and a fixed setter, so the only thing varying in each gate is the one
## named. There is one `rng.randf()` in the tail of the function -- the pin-focus
## weighted draw -- but the setter branch returns before it, and every gate here
## supplies a setter, so all four tables are exact.

const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")

const SETTER_ID: int = 302
## Slot -> id. 4 and 2 are the two pins, 3 the middle, 1/5/6 the back row.
const SLOT_IDS := {1: 301, 2: SETTER_ID, 3: 303, 4: 304, 5: 305, 6: 306}
## The three volis a first-ball play can swing: two pins and a middle. The setter
## occupies slot 2, so the right pin here is slot 3's neighbour rather than the
## setter themselves.
const LEFT_PIN: int = 304
const MIDDLE: int = 303
const PIPE: int = 306

const LANES := {LEFT_PIN: "Left Pin", MIDDLE: "Front Quick", PIPE: "Pipe"}
const TEMPOS := {LEFT_PIN: 2, MIDDLE: 1, PIPE: 3}


func _initialize() -> void:
	_gate_a()
	_gate_b()
	_gate_c()
	_gate_d()
	_dead_argument()
	quit()


## ---------------------------------------------------------------- fixtures


func _make_player(player_id: int, role: String) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = player_id
	player.display_name = "Voli %d" % player_id
	player.position_role = role
	for attribute in [
		"attack_power", "attack_accuracy", "approach_timing", "set_accuracy",
		"hand_control", "tempo_control", "decision_making", "court_vision",
		"composure", "set_disguise", "unpredictability", "leadership",
		"acceleration", "lateral_speed", "transition_speed", "stamina",
		"work_rate", "jump_reach", "explosiveness",
	]:
		player.set(attribute, 50)
	player.fatigue = 0.0
	player.match_confidence = 0.0
	return player


func _fixture(overrides: Dictionary = {}) -> Dictionary:
	var lineup := RotationLineup.new()
	lineup.setter_id = SETTER_ID
	var players: Array[VolleyballPlayer] = []
	for slot_number in SLOT_IDS:
		var player_id: int = SLOT_IDS[slot_number]
		var player := _make_player(
			player_id, "Middle Blocker" if player_id == MIDDLE else "Outside Hitter"
		)
		for attribute in Dictionary(overrides.get(player_id, {})):
			player.set(attribute, overrides[player_id][attribute])
		players.append(player)
		lineup.assign_slot(slot_number, player_id)
	var simulator: Object = RallySimulatorScript.new()
	simulator.rally_seed = 8080
	## Every hitter the same distance from nothing in particular: the point of
	## these gates is the decision, and giving three volis three different
	## travel times would make every table a movement measurement instead.
	simulator.live_positions = {
		301: Vector2(0.80, 0.86), 302: Vector2(0.66, 0.60),
		303: Vector2(0.50, 0.62), 304: Vector2(0.20, 0.62),
		305: Vector2(0.18, 0.86), 306: Vector2(0.50, 0.88),
	}
	return {"simulator": simulator, "players": players, "lineup": lineup}


## A play naming all three swingers, with `primary` carrying the manager's call.
func _play(primary: int, decoys: Array = []) -> OffensivePlay:
	var play := OffensivePlay.new()
	play.play_name = "Probe"
	play.primary_hitter_id = primary
	var assignments: Array[HitterAssignment] = []
	for hitter_id in [LEFT_PIN, MIDDLE, PIPE]:
		var assignment := HitterAssignment.new()
		assignment.player_id = hitter_id
		assignment.lane = str(LANES[hitter_id])
		assignment.tempo = int(TEMPOS[hitter_id])
		assignment.is_decoy = hitter_id in decoys
		assignments.append(assignment)
	play.assignments = assignments
	return play


func _choose(
	fixture: Dictionary,
	play: OffensivePlay,
	follow_play: bool,
	excluded_id: int,
	pass_quality: float = 0.55,
) -> int:
	var simulator: Object = fixture.simulator
	var setter: VolleyballPlayer = _by_id(fixture.players, SETTER_ID)
	var assignment: Resource = simulator._choose_assignment(
		play, follow_play, fixture.players, fixture.lineup, excluded_id,
		setter, pass_quality, 0.0,
	)
	return int(assignment.player_id) if assignment != null else -1


func _by_id(players: Array, player_id: int) -> VolleyballPlayer:
	for player in players:
		if player != null and int(player.id) == player_id:
			return player
	return null


func _name(player_id: int) -> String:
	match player_id:
		LEFT_PIN: return "left pin"
		MIDDLE: return "middle"
		PIPE: return "pipe"
		SETTER_ID: return "SETTER"
		-1: return "(none)"
	return str(player_id)


## ------------------------------------------------------------------ gate A
##
## Same roster, same ball, different tactical call. The intended hitter must
## move in the direction of the call -- otherwise the manager's play is
## decoration and the node is choosing on its own terms.
func _gate_a() -> void:
	print("=".repeat(78))
	print("GATE A -- same roster and ball, the CALL moves")
	print("=".repeat(78))
	print("  %-22s %-14s %-14s" % ["called primary", "followed", "abandoned"])
	var followed := {}
	for primary in [LEFT_PIN, MIDDLE, PIPE]:
		var play := _play(primary)
		var with_call := _choose(_fixture(), play, true, SETTER_ID)
		var without := _choose(_fixture(), play, false, SETTER_ID)
		followed[primary] = with_call
		print("  %-22s %-14s %-14s" % [
			_name(primary), _name(with_call), _name(without),
		])
	var honoured := 0
	for primary in followed:
		if int(followed[primary]) == int(primary):
			honoured += 1
	print("  -> the call was honoured in %d of 3 when followed" % honoured)
	print("     (the `abandoned` column is the same play with follow_play false,")
	print("      so a column that never moves means the call does nothing)")

	## And the harder half: a called hitter marked as a decoy must NOT swing,
	## because a decoy is an instruction to draw the block rather than hit.
	var decoy_play := _play(LEFT_PIN, [LEFT_PIN])
	print("  called primary marked decoy -> %s   (must not be the left pin)"
		% _name(_choose(_fixture(), decoy_play, true, SETTER_ID)))


## ------------------------------------------------------------------ gate B
##
## Same call, hitter ratings moved. The question is whether ratings *refine* a
## legitimate choice or *replace* responsibility. Both readings are defensible
## in volleyball -- a setter does go to the hot hand -- so this reports the
## crossing rather than asserting a verdict.
func _gate_b() -> void:
	print("\n" + "=".repeat(78))
	print("GATE B -- same call, the challenger's attacking ratings move")
	print("=".repeat(78))
	print("  call = left pin (primary, instruction_bias +0.20).")
	print("  The middle's attack ratings are swept; everything else held.")
	print("  %-14s %-16s %-16s" % ["middle attack", "followed", "abandoned"])
	for rating in [50, 60, 70, 80, 90, 99]:
		var overrides := {MIDDLE: {
			"attack_power": rating, "attack_accuracy": rating,
			"approach_timing": rating,
		}}
		var play := _play(LEFT_PIN)
		print("  %-14d %-16s %-16s" % [
			rating,
			_name(_choose(_fixture(overrides), play, true, SETTER_ID)),
			_name(_choose(_fixture(overrides), play, false, SETTER_ID)),
		])
	print("  -> `instruction_bias` is +0.20 and the attack terms span ~1.0, so a")
	print("     large enough rating gap is expected to win. What matters is that")
	print("     the FOLLOWED column holds the call for longer than the abandoned")
	print("     one -- that is the call being worth something rather than nothing.")


## ------------------------------------------------------------------ gate C
##
## The voli who just made the second contact cannot make the third. This is a
## rule of volleyball, not a preference, so it must hold at every rating.
func _gate_c() -> void:
	print("\n" + "=".repeat(78))
	print("GATE C -- the second contact cannot also swing")
	print("=".repeat(78))
	## The setter is put *into* the play as a named hitter, spiked to be the best
	## attacker on the floor, and called as the primary. Nothing short of the
	## exclusion should keep them out.
	var play := _play(SETTER_ID)
	var assignments: Array[HitterAssignment] = play.assignments.duplicate()
	var setter_assignment := HitterAssignment.new()
	setter_assignment.player_id = SETTER_ID
	setter_assignment.lane = "Right Pin"
	setter_assignment.tempo = 2
	assignments.append(setter_assignment)
	play.assignments.assign(assignments)
	var overrides := {SETTER_ID: {
		"attack_power": 99, "attack_accuracy": 99, "approach_timing": 99,
	}}
	print("  setter named primary, spiked to 99, and excluded by id:")
	for followed in [true, false]:
		var chosen := _choose(_fixture(overrides), play, followed, SETTER_ID)
		print("      follow_play %-6s -> %-12s %s" % [
			"true" if followed else "false", _name(chosen),
			"ok" if chosen != SETTER_ID else "<- ILLEGAL",
		])
	## And the control: with nobody excluded, the same play does pick them --
	## which is what makes the row above evidence rather than an accident of the
	## fixture.
	print("      no exclusion       -> %-12s (control: must be the setter)"
		% _name(_choose(_fixture(overrides), play, true, -1)))


## ------------------------------------------------------------------ gate D
##
## Identical decision state, only the realized pass displaced. Does the
## assignment respond to where the ball actually is?
##
## Either answer can be right. The intended architecture leaves approach
## feasibility to the later movement stage, so a node that ignores displacement
## is not automatically broken -- but it must be ignoring it *by construction*
## rather than by accident, and the reader deserves to know which.
func _gate_d() -> void:
	print("\n" + "=".repeat(78))
	print("GATE D -- only the realized pass moves")
	print("=".repeat(78))
	print("  `_choose_assignment` takes no pass destination and no pass")
	print("  trajectory. `pass_quality` is the single scalar that crosses, so")
	print("  that is what is swept here -- a displaced pass cannot be expressed")
	print("  to this node at all, which is itself the finding.")
	print("  %-16s %-16s %-16s" % ["pass_quality", "followed", "abandoned"])
	for quality in [0.05, 0.25, 0.45, 0.65, 0.85, 1.0]:
		var play := _play(LEFT_PIN)
		print("  %-16.2f %-16s %-16s" % [
			quality,
			_name(_choose(_fixture(), play, true, SETTER_ID, quality)),
			_name(_choose(_fixture(), play, false, SETTER_ID, quality)),
		])
	print("  -> a flat column means pass quality does not choose the hitter.")
	print("     It still reaches the node: it shapes the provisional set arc")
	print("     used to estimate each option's available time, and it is added")
	print("     to every candidate's score identically -- see below.")


## ------------------------------------------------------ two dead inputs
##
## Found while reading rather than while measuring, and worth stating because
## both look load-bearing.
func _dead_argument() -> void:
	print("\n" + "=".repeat(78))
	print("TWO INPUTS THAT LOOK LOAD-BEARING AND ARE NOT")
	print("=".repeat(78))
	var simulator: Object = RallySimulatorScript.new()
	simulator.rally_seed = 8080
	var setter := _make_player(SETTER_ID, "Setter")
	print("\n  1. `_set_arc`'s `distance_meters`, fed the hardcoded (0.5, 0.60)")
	print("     origin at the call site. With ENABLE_SET_HEIGHT_TIMING the arc")
	print("     comes from `BallFlightModel.duration_for_apex` and the distance")
	print("     is never read:")
	print("      %-16s %-16s" % ["distance_m", "duration_s"])
	for distance in [0.5, 2.0, 5.0, 9.0]:
		var arc: Dictionary = simulator._set_arc(
			setter, 2, 0.55, 2.10, 3.05, distance
		)
		print("      %-16.2f %-16.4f" % [
			distance, float(arc.duration_seconds),
		])
	print("     Flat -> the hardcoded origin is unreachable, not wrong.")

	print("\n  2. `set_quality * 0.10` in `_setter_option_terms`'s score.")
	print("     Added identically to every candidate, so it shifts all scores")
	print("     by the same amount and cannot reorder them. Pass quality")
	print("     reaches the ranking only through the provisional arc.")
