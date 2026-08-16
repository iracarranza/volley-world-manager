extends SceneTree

## Who takes the second ball, and what actually decides it?
##
##     godot --headless --path . --script res://tools/run_second_contact_probe.gd
##
## The leg after the realized pass:
##
##     realized pass -> CHOOSE 2ND CONTACT -> choose hitter
##
## Two functions answer that question in sequence and they do not answer it the
## same way, which is the whole reason for this probe:
##
##   * `_second_contact_setter` -- *responsibility only*. Takes no position, no
##     clock and no ball. Returns the designated setter outright unless they
##     played the first contact, and otherwise ranks the plan's nominated cover
##     by set-producing attributes.
##   * `_spatial_setter_choice` -- *everything*. Re-scores all six candidates
##     against the realized pass destination, the pass's own duration, live
##     positions, recovery debt and a head start, then adds the duty weighting
##     back on top. The first function's answer enters this one as a **+0.20
##     preference**, not as a decision.
##
## Both are deterministic -- no `rng` draw anywhere in either -- so every table
## below is exact rather than sampled, and a rate would be a lie. Cases A-E each
## move one thing and hold the rest.
##
## Part B is the same decision in situ, reading published SET metadata over
## isolated rallies, to say how often each case is actually reached.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallySimulatorScript := preload("res://scripts/simulation/rally_simulator.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 63000
const SEED_COUNT: int = 400

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0

## Slot -> id. Slot 2 is the designated setter, which is also the slot
## `DefensivePlan._default_assignment` hands "Primary emergency setter" -- so the
## default plan gives the setter their own emergency duty on top of being the
## setter. That overlap is a finding, not a fixture convenience; §3 of the
## write-up measures what it is worth.
const SLOT_IDS := {1: 101, 2: 102, 3: 103, 4: 104, 5: 105, 6: 106}
const SETTER_ID: int = 102

## A pass landing just right of centre, in front of the net -- the ordinary
## target. Held in every case except the one that moves it.
const PASS_TARGET := Vector2(0.56, 0.68)
## The realized pass's own duration. Held except in case C.
const PASS_WINDOW: float = 0.72


func _initialize() -> void:
	_case_a()
	_case_b()
	_case_c()
	_case_d()
	_case_e()
	_part_b()
	quit()


## ---------------------------------------------------------------- fixtures


func _make_player(player_id: int, slot_number: int) -> VolleyballPlayer:
	var player := VolleyballPlayer.new()
	player.id = player_id
	player.display_name = "Slot %d" % slot_number
	## Every attribute either selector reads, plus the locomotion attributes
	## `_movement_time` reads, pinned to the middle -- so a table that moves has
	## exactly one cause. `fatigue` at zero keeps `_rating` from scaling
	## anything, which would otherwise make the two sides of a comparison differ
	## by a term neither case is about.
	for attribute in [
		"set_accuracy", "ball_control", "decision_making", "ego", "leadership",
		"aggression", "acceleration", "lateral_speed", "transition_speed",
		"stamina", "work_rate", "anticipation", "composure",
	]:
		player.set(attribute, 50)
	player.fatigue = 0.0
	return player


func _fixture(
	positions: Dictionary,
	overrides: Dictionary = {},
	## Which id stands in which slot. Defaults to `SLOT_IDS`; the rotation sweep
	## in §C hands in a rotated map, because the plan's emergency nominations are
	## written **per slot** and the setter does not stay in one.
	slot_map: Dictionary = {},
) -> Dictionary:
	var slots: Dictionary = SLOT_IDS if slot_map.is_empty() else slot_map
	var lineup := RotationLineup.new()
	lineup.setter_id = SETTER_ID
	var players: Array[VolleyballPlayer] = []
	var starts := {}
	for slot_number in slots:
		var player_id: int = slots[slot_number]
		var player := _make_player(player_id, slot_number)
		var tweaks: Dictionary = overrides.get(player_id, {})
		for attribute in tweaks:
			player.set(attribute, tweaks[attribute])
		players.append(player)
		lineup.assign_slot(slot_number, player_id)
		starts[player_id] = Vector2(positions[player_id])
	var plan := DefensivePlan.new()
	plan.rotation_number = 1
	plan.ensure_defaults(lineup, players)
	var simulator: Object = RallySimulatorScript.new()
	simulator.rally_seed = 909
	simulator.live_positions = starts.duplicate(true)
	return {
		"simulator": simulator, "players": players, "starts": starts,
		"plan": plan, "lineup": lineup,
	}


## Everyone in an ordinary transition shape: setter right of centre near the
## net, the rest spread. Distances are what they are; the point is that nobody
## is standing on the pass target and nobody is absurdly far from it.
func _default_positions() -> Dictionary:
	return {
		101: Vector2(0.78, 0.86),   ## slot 1, right back
		102: Vector2(0.66, 0.60),   ## slot 2, the setter, right front
		103: Vector2(0.46, 0.58),   ## slot 3, middle front
		104: Vector2(0.20, 0.60),   ## slot 4, left front
		105: Vector2(0.18, 0.86),   ## slot 5, left back
		106: Vector2(0.48, 0.90),   ## slot 6, middle back
	}


func _run(
	fixture: Dictionary,
	first_contact_id: int,
	target: Vector2 = PASS_TARGET,
	window: float = PASS_WINDOW,
	head_start: float = 0.0,
) -> Dictionary:
	var simulator: Object = fixture.simulator
	var candidates: Array[VolleyballPlayer] = fixture.players
	var responsibility: VolleyballPlayer = simulator._second_contact_setter(
		candidates, fixture.plan, SETTER_ID, first_contact_id
	)
	var choice: Dictionary = simulator._spatial_setter_choice(
		candidates, fixture.starts, fixture.plan, SETTER_ID, first_contact_id,
		responsibility, target, window, head_start,
	)
	var chosen: VolleyballPlayer = choice.player as VolleyballPlayer
	return {
		"responsibility_id": responsibility.id if responsibility != null else -1,
		"chosen_id": chosen.id if chosen != null else -1,
		"overridden": responsibility != null and chosen != null \
			and responsibility.id != chosen.id,
		"travel": float(choice.travel_time),
		"margin": float(choice.get("arrival_margin", 0.0)),
		"reach_margin": float(choice.get("reach_margin_meters", 0.0)),
		"reachable": bool(choice.get("reachable", false)),
		"claimants": int(choice.get("claimant_count", 0)),
		"seam": bool(choice.get("seam_conflict", false)),
	}


func _slot_of(player_id: int) -> int:
	for slot_number in SLOT_IDS:
		if int(SLOT_IDS[slot_number]) == player_id:
			return slot_number
	return -1


func _label(player_id: int) -> String:
	if player_id < 0:
		return "(none)"
	return "%d slot%d%s" % [
		player_id, _slot_of(player_id),
		"*" if player_id == SETTER_ID else " ",
	]


func _header(letter: String, question: String) -> void:
	print("\n" + "=".repeat(78))
	print("CASE %s -- %s" % [letter, question])
	print("=".repeat(78))
	print("  %-26s %-14s %-14s %-6s %-8s %-6s" % [
		"variable", "responsibility", "chosen", "over?", "margin_s", "reach",
	])


func _row(variable: String, verdict: Dictionary) -> void:
	print("  %-26s %-14s %-14s %-6s %-8.4f %-6s" % [
		variable, _label(int(verdict.responsibility_id)),
		_label(int(verdict.chosen_id)),
		"YES" if bool(verdict.overridden) else "-",
		float(verdict.margin),
		"yes" if bool(verdict.reachable) else "NO",
	])


## ------------------------------------------------------------------ case A
##
## The ordinary ball. The designated setter did not touch it and is standing in
## their own zone. Anyone can take a second contact, so the question is whether
## the plan's answer survives a chooser that scores five other people.
func _case_a() -> void:
	_header("A", "designated setter available -- do they get the ball?")
	for first_contact in [101, 105, 106, 103]:
		var fixture := _fixture(_default_positions())
		_row(
			"first contact = %s" % _label(first_contact),
			_run(fixture, first_contact),
		)


## ------------------------------------------------------------------ case B
##
## The setter played the first ball, so somebody has to cover. The plan named
## slot 2 primary and slot 1 secondary -- but slot 2 *is* the setter here, so
## the only nomination left standing is slot 1. Does it hold, and does it hold
## when slot 1 is the worst set producer on the floor?
func _case_b() -> void:
	_header("B", "setter took the first contact -- who covers?")
	var fixture := _fixture(_default_positions())
	_row("plan defaults", _run(fixture, SETTER_ID))
	## The nominated cover made technically hopeless. If responsibility means
	## anything, the nomination survives; if the rating heuristic is really in
	## charge, the ball moves to whoever sets best.
	var weak := _fixture(_default_positions(), {
		101: {"set_accuracy": 10, "ball_control": 10, "decision_making": 10},
	})
	_row("slot1 cover set_acc 10", _run(weak, SETTER_ID))
	## And the mirror: a no-duty voli made the best setter in the building.
	var ringer := _fixture(_default_positions(), {
		106: {"set_accuracy": 99, "ball_control": 99, "decision_making": 99},
	})
	_row("slot6 no-duty set_acc 99", _run(ringer, SETTER_ID))


## ------------------------------------------------------------------ case C
##
## **The decisive one.** The designated setter is available and nominated but
## cannot get to the ball. Responsibility says theirs; legs say no. Only one of
## the two functions can hear the legs.
##
## Two knobs, because one confounds the other: pushing the setter away also
## changes who is nearest, so the window is squeezed as well and the two are
## reported side by side.
func _case_c() -> void:
	_header("C", "designated setter displaced -- responsibility or legs?")
	for displacement in [0.0, 0.10, 0.20, 0.32, 0.44]:
		var positions := _default_positions()
		## Straight back and left, away from the pass target and away from the
		## net, which is where a setter who has just covered a tip ends up.
		positions[SETTER_ID] = Vector2(
			clampf(0.66 - displacement, 0.06, 0.94),
			clampf(0.60 + displacement, 0.53, 0.96),
		)
		var fixture := _fixture(positions)
		_row(
			"setter pushed %.2f" % displacement,
			_run(fixture, 105, PASS_TARGET, PASS_WINDOW),
		)
	print("")
	for window in [1.40, 0.90, 0.62, 0.42, 0.26]:
		var positions := _default_positions()
		positions[SETTER_ID] = Vector2(0.34, 0.92)   ## deep left, worst case
		var fixture := _fixture(positions)
		_row(
			"far setter, window %.2fs" % window,
			_run(fixture, 105, PASS_TARGET, window),
		)
	_case_c_crossing()


## **The crossing search, and it is the finding.**
##
## Everything above holds the challenger still and moves the setter. That can
## only ever show the setter losing ground; it cannot show what it takes for
## somebody else to *win*. So this walks one challenger from the far corner
## onto the ball itself while the setter stands in the opposite corner, and asks
## where -- if anywhere -- the ball changes hands.
##
## Run twice with the only difference being the challenger's duty:
##
##   * slot 1, whom the default plan names "Secondary emergency setter";
##   * slot 6, whom it leaves with "No second-contact duty".
##
## Same geometry, same window, same attributes. If the two columns cross at
## different places, that is the plan doing its job. If one of them never
## crosses at all, the arrival term cannot reach past a constant, which is the
## failure this repository keeps making.
func _case_c_crossing() -> void:
	print("\n  CROSSING -- setter stranded in the far corner (0.10, 0.94);")
	print("  one challenger walks from the far side onto the ball. Window 1.20 s.")
	print("  %-16s %-22s %-22s" % [
		"walk fraction", "challenger slot1", "challenger slot6",
	])
	## The challenger's start, stepped from the opposite corner to the pass
	## target itself. At `1.00` they are standing on the ball with zero travel,
	## which is the most extreme claim a body can make.
	for step in [0.0, 0.25, 0.50, 0.75, 0.90, 1.00]:
		var cells: Array[String] = []
		for challenger in [101, 106]:
			var positions := _default_positions()
			positions[SETTER_ID] = Vector2(0.10, 0.94)
			var far := Vector2(0.92, 0.94)
			positions[challenger] = far.lerp(PASS_TARGET, step)
			## The other four pushed out of contention so the table is a
			## two-body question and nothing else can win it by accident.
			for bystander in [103, 104, 105, 106, 101]:
				if bystander == challenger:
					continue
				positions[bystander] = Vector2(0.50, 0.955)
			var fixture := _fixture(positions)
			var verdict := _run(fixture, 999, PASS_TARGET, 1.20)
			cells.append("%s  margin %+.2f%s" % [
				_label(int(verdict.chosen_id)), float(verdict.margin),
				"  WON" if int(verdict.chosen_id) == challenger else "",
			])
		print("  %-16.2f %-22s %-22s" % [step, cells[0], cells[1]])
	print("  slot1 carries \"Secondary emergency setter\" (+0.18);")
	print("  slot6 carries \"No second-contact duty\" (-0.24).")
	_case_c_ceiling()


## **Is the no-duty ceiling absolute, or only absolute at equal attributes?**
##
## The arithmetic says the first is nearly true and the second is exactly true.
## `duty_bonus` reaches +0.80 for a designated setter standing in slot 2 -- the
## plan's own "Primary emergency setter" (+0.34) plus the designated-setter term
## (+0.46) -- against -0.24 for no duty at all. That spread is **1.04**, and
## `arrival_score` is clamped to [-1, 1] and weighted 0.52, so the whole
## authority the legs have is **also 1.04**. Two knobs of identical span: the
## legs can tie the sheet and never beat it.
##
## So the prediction is specific and falsifiable. A no-duty voli standing on the
## ball with the setter stranded loses by a hair, and the hair is worth roughly
## twenty points of `set_accuracy` at its 0.28 weight. If it flips somewhere in
## the seventies the model is understood; if it never flips, the ceiling is
## harder than the arithmetic says and something else is holding it.
func _case_c_ceiling() -> void:
	print("\n  CEILING -- slot6 (no duty) standing ON the ball at (0.56, 0.68),")
	print("  setter stranded at (0.10, 0.94), window 1.20 s. Only set_accuracy moves.")
	print("  %-18s %-22s" % ["slot6 set_accuracy", "chosen"])
	for accuracy in [50, 60, 65, 70, 75, 90, 99]:
		var positions := _default_positions()
		positions[SETTER_ID] = Vector2(0.10, 0.94)
		positions[106] = PASS_TARGET
		for bystander in [101, 103, 104, 105]:
			positions[bystander] = Vector2(0.50, 0.955)
		var fixture := _fixture(positions, {106: {"set_accuracy": accuracy}})
		var verdict := _run(fixture, 999, PASS_TARGET, 1.20)
		print("  %-18d %-22s" % [
			accuracy,
			"%s%s" % [
				_label(int(verdict.chosen_id)),
				"  WON" if int(verdict.chosen_id) == 106 else "",
			],
		])
	_case_c_rotation()


## **The same stranded setter, rotated.**
##
## `duty_bonus` adds the designated-setter term to whatever the *plan* already
## gave that voli, and the plan writes its emergency nominations per slot: slot 2
## primary, slot 1 secondary, everybody else nothing. So the designated setter's
## total grip on the second ball is not one number -- it is +0.80 when they
## stand in slot 2, +0.64 in slot 1 and +0.22 in the other four, a swing of 0.58
## that nothing in the design asked for.
##
## Identical geometry in every row: the setter stranded in the far corner, one
## no-duty challenger standing on the ball, everyone else parked. Only the
## rotation moves. If the verdict changes, the setter's authority over their own
## second ball is a function of where the rotation happens to have put them.
func _case_c_rotation() -> void:
	print("\n  ROTATION -- identical geometry, setter walked round the six slots.")
	print("  Setter stranded at (0.10, 0.94); challenger standing on the ball.")
	print("  %-14s %-16s %-22s" % ["setter slot", "plan duty", "chosen"])
	var duty_names := {
		1: "secondary", 2: "PRIMARY", 3: "none", 4: "none", 5: "none", 6: "none",
	}
	for setter_slot in range(1, 7):
		## Rotate the six ids so the setter occupies `setter_slot` and the
		## challenger occupies a slot the plan gives no duty to. Slot 3 is always
		## a no-duty slot, so the challenger goes there unless the setter does.
		var challenger_slot := 3 if setter_slot != 3 else 4
		var slot_map := {}
		var spare: Array[int] = [103, 104, 105, 106]
		for slot_number in range(1, 7):
			if slot_number == setter_slot:
				slot_map[slot_number] = SETTER_ID
			elif slot_number == challenger_slot:
				slot_map[slot_number] = 101
			else:
				slot_map[slot_number] = spare.pop_front()
		var positions := {}
		for slot_number in slot_map:
			positions[int(slot_map[slot_number])] = Vector2(0.50, 0.955)
		positions[SETTER_ID] = Vector2(0.10, 0.94)
		positions[101] = PASS_TARGET
		var fixture := _fixture(positions, {}, slot_map)
		var verdict := _run(fixture, 999, PASS_TARGET, 1.20)
		print("  %-14d %-16s %-22s" % [
			setter_slot, str(duty_names[setter_slot]),
			"%s%s" % [
				"setter" if int(verdict.chosen_id) == SETTER_ID \
					else "challenger",
				"" if int(verdict.chosen_id) == SETTER_ID \
					else "  <- legs won",
			],
		])


## ------------------------------------------------------------------ case D
##
## Does the *quality* of the pass change who is chosen? It must not: a scalar
## description of how good the ball was is not a fact about where anybody is
## standing. Neither selector takes `reception_quality` as an argument, so this
## case demonstrates the absence rather than measuring a response -- what it
## moves instead is the two things a poor pass actually changes, the destination
## and the flight time.
func _case_d() -> void:
	_header("D", "a poor pass -- what does the selection actually feel?")
	## A pass shanked progressively further off the setter's zone, with its
	## flight time shortening the way a flat mishit's does.
	var passes := [
		{"name": "clean, on the zone", "target": Vector2(0.56, 0.68), "window": 0.72},
		{"name": "slightly off", "target": Vector2(0.48, 0.72), "window": 0.68},
		{"name": "wide left", "target": Vector2(0.26, 0.74), "window": 0.60},
		{"name": "shanked deep left", "target": Vector2(0.14, 0.88), "window": 0.48},
		{"name": "flat, over the net side", "target": Vector2(0.20, 0.56), "window": 0.34},
	]
	for entry in passes:
		var fixture := _fixture(_default_positions())
		_row(
			str(entry.name),
			_run(fixture, 105, Vector2(entry.target), float(entry.window)),
		)


## ------------------------------------------------------------------ case E
##
## Is a role/rating heuristic quietly picking the best set producer? Spike one
## attribute on one no-duty voli and watch whether the ball migrates. The setter
## is present and available in every row, so any migration is the heuristic
## beating the plan on a ball the plan says is not in question.
func _case_e() -> void:
	_header("E", "spike set_accuracy on a no-duty voli -- does the ball move?")
	for spike in [50, 70, 85, 99]:
		var fixture := _fixture(_default_positions(), {
			106: {"set_accuracy": spike},
		})
		_row("slot6 set_accuracy %d" % spike, _run(fixture, 105))
	print("")
	## Temperament is the other channel that can move a ball without a duty:
	## ego and leadership pull, and the comment sizing them says together they
	## reach 0.09 and "never overrule the sheet". Tested rather than believed.
	for ego in [50, 75, 99]:
		var fixture := _fixture(_default_positions(), {
			106: {"ego": ego, "leadership": ego, "aggression": ego},
		})
		_row("slot6 ego/lead/aggr %d" % ego, _run(fixture, 105))
	print("")
	## And the same spike applied where it is *supposed* to matter -- the
	## emergency search, with the setter out of the picture.
	for spike in [50, 70, 85, 99]:
		var fixture := _fixture(_default_positions(), {
			106: {"set_accuracy": spike},
		})
		_row("(setter passed) slot6 %d" % spike, _run(fixture, SETTER_ID))


## ------------------------------------------------------------------- part B


func _part_b() -> void:
	print("\n" + "=".repeat(78))
	print("PART B -- in situ, %d isolated rallies per serving side" % SEED_COUNT)
	print("=".repeat(78))
	var counts := {
		"rallies": 0, "sets": 0, "home_sets": 0, "opponent_sets": 0,
		"emergency": 0, "seam": 0, "uncontested": 0,
		"first_contact_was_setter": 0,
		"no_reach_margin": 0, "negative_margin": 0,
	}
	var margin_total := 0.0
	var travel_total := 0.0
	var claimant_total := 0
	var by_actor := {}
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			counts["rallies"] = int(counts.rallies) + 1
			if rally != null:
				for event in rally.events:
					if int(event.event_type) != RallyEventScript.EventType.SET:
						continue
					var metadata: Dictionary = event.metadata
					counts["sets"] = int(counts.sets) + 1
					var side := str(metadata.get("side", "home"))
					if side == "home":
						counts["home_sets"] = int(counts.home_sets) + 1
					else:
						counts["opponent_sets"] = int(counts.opponent_sets) + 1
					if bool(metadata.get("emergency_setter", false)):
						counts["emergency"] = int(counts.emergency) + 1
					if bool(metadata.get("seam_conflict", false)):
						counts["seam"] = int(counts.seam) + 1
					var claimants := int(metadata.get("claimant_count", 0))
					claimant_total += claimants
					if claimants <= 1:
						counts["uncontested"] = int(counts.uncontested) + 1
					var margin := float(metadata.get("arrival_margin", 0.0))
					margin_total += margin
					if margin < 0.0:
						counts["negative_margin"] = \
							int(counts.negative_margin) + 1
					travel_total += float(metadata.get("movement_duration", 0.0))
					if is_zero_approx(
						float(metadata.get("reach_margin_meters", 0.0))
					):
						counts["no_reach_margin"] = \
							int(counts.no_reach_margin) + 1
					var actor := int(event.actor_id)
					by_actor[actor] = int(by_actor.get(actor, 0)) + 1
			manager.free()

	var sets := maxf(float(counts.sets), 1.0)
	print("  rallies %d, sets %d (home %d, opponent %d)" % [
		int(counts.rallies), int(counts.sets),
		int(counts.home_sets), int(counts.opponent_sets),
	])
	print("\n  WHO TOOK IT")
	print("      emergency second contact %d (%.4f)" % [
		int(counts.emergency), float(counts.emergency) / sets,
	])
	print("      uncontested (claimant_count <= 1) %d (%.4f)" % [
		int(counts.uncontested), float(counts.uncontested) / sets,
	])
	print("      seam conflicts %d (%.4f)" % [
		int(counts.seam), float(counts.seam) / sets,
	])
	print("      mean claimants %.4f" % (float(claimant_total) / sets))
	print("\n  HOW COMFORTABLY")
	print("      mean arrival margin %.4f s" % (margin_total / sets))
	print("      mean travel %.4f s" % (travel_total / sets))
	print("      late arrivals (margin < 0) %d (%.4f)" % [
		int(counts.negative_margin), float(counts.negative_margin) / sets,
	])
	print("      reach margin absent %d (%.4f)" % [
		int(counts.no_reach_margin), float(counts.no_reach_margin) / sets,
	])
	print("\n  DISTINCT SETTERS  (regression observation, never a target)")
	var actors: Array = by_actor.keys()
	actors.sort()
	for actor in actors:
		print("      actor %-6d %-5d %.4f" % [
			actor, int(by_actor[actor]), float(by_actor[actor]) / sets,
		])
