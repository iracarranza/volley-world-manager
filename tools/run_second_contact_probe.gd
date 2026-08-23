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

## The far corner a setter ends up in after covering a tip, and the spot the
## four uninvolved bodies are parked in so a gate is a two-body question. Shared
## by the gates so "identical geometry" means the same numbers, not similar ones.
const STRANDED := Vector2(0.10, 0.94)
const PARKED := Vector2(0.50, 0.955)


func _initialize() -> void:
	_case_a()
	_case_b()
	_case_c()
	_case_d()
	_case_e()
	_gates()
	_head_start_symmetry()
	_part_b()
	quit()


## ================================================================== the gates
##
## Cases A-E describe the selector. These six **judge** it, against the policy
## decided after the `767faf7` audit:
##
##     The designated setter has strong first responsibility for the second
##     contact, but that responsibility is not absolute. If the realized ball
##     and the existing movement model show the setter cannot realistically
##     fulfil it while another responsible voli can, the contact may transfer.
##
## Not "nearest wins" and not "best setter wins". Every gate below is run with
## the setter walked through all six rotation slots on **identical geometry**,
## because the defect being corrected is that one rotation answered differently
## from the other five.
func _gates() -> void:
	print("\n" + "=".repeat(78))
	print("GATES -- six rotations, identical geometry in every row")
	print("=".repeat(78))
	_gate_1_normal_reachable()
	_gate_2_stranded_responsible()
	_gate_2b_transfer_point()
	_gate_3_stranded_no_duty()
	_gate_4_rating_control()
	_gate_5_setter_made_first_contact()
	_gate_6_rotation_invariance()


## Walk `SETTER_ID` through every slot while `challenger` takes `challenger_slot`
## (or the first free slot that is not the setter's). Only the duty *strings*
## change; bodies, ball and window are handed in and held.
##
## Returns one row per rotation so a gate can assert uniformity rather than
## eyeball it.
func _rotation_sweep(
	positions: Dictionary,
	challenger: int,
	target: Vector2,
	window: float,
	first_contact_id: int,
	preferred_challenger_slot: int = 2,
	overrides: Dictionary = {},
	head_start: float = 0.0,
) -> Array:
	var rows: Array = []
	for setter_slot in range(1, 7):
		var challenger_slot := preferred_challenger_slot
		if challenger_slot == setter_slot:
			## The setter is standing where the challenger's duty lives, so the
			## challenger takes the *other* nominated slot. Which duty they end
			## up holding is reported, because it is a real confound: slots 1 and
			## 2 are the only two the plan nominates at all.
			challenger_slot = 1 if setter_slot == 2 else 2
		var slot_map := {}
		var spare: Array[int] = []
		for spare_id in [101, 103, 104, 105, 106]:
			if spare_id != challenger:
				spare.append(spare_id)
		for slot_number in range(1, 7):
			if slot_number == setter_slot:
				slot_map[slot_number] = SETTER_ID
			elif slot_number == challenger_slot:
				slot_map[slot_number] = challenger
			else:
				slot_map[slot_number] = spare.pop_front()
		var fixture := _fixture(positions, overrides, slot_map)
		var verdict := _run(fixture, first_contact_id, target, window, head_start)
		var plan: Resource = fixture.plan
		rows.append({
			"setter_slot": setter_slot,
			"challenger_slot": challenger_slot,
			## **The rotated map, not `SLOT_IDS`.** `_slot_of` reads the constant
			## layout and is therefore wrong under rotation -- it labelled a
			## challenger standing in the plan's nominated slot 2 as "slot6",
			## which made gate 5 report 0 of 6 nominated when the answer was 6.
			"slot_map": slot_map,
			"setter_duty": str(plan.assignment_for(SETTER_ID)
				.second_contact_responsibility),
			"challenger_duty": str(plan.assignment_for(challenger)
				.second_contact_responsibility),
			"chosen_id": int(verdict.chosen_id),
			"margin": float(verdict.margin),
		})
	return rows


func _short_duty(duty: String) -> String:
	match duty:
		"Primary emergency setter": return "primary"
		"Secondary emergency setter": return "secondary"
		"Stay available to attack": return "stay-avail"
	return "none"


## Prints the sweep and states the uniformity verdict, which is the gate.
func _report_sweep(rows: Array, expect_id: int, expectation: String) -> void:
	print("      %-7s %-11s %-12s %-13s %-9s" % [
		"rot", "setter duty", "chall. duty", "chosen", "margin",
	])
	var chosen := {}
	for row in rows:
		chosen[int(row.chosen_id)] = true
		print("      %-7d %-11s %-12s %-13s %+.3f" % [
			int(row.setter_slot), _short_duty(str(row.setter_duty)),
			_short_duty(str(row.challenger_duty)),
			_label(int(row.chosen_id)), float(row.margin),
		])
	var uniform := chosen.size() == 1
	var correct := uniform and chosen.has(expect_id)
	print("      -> %s  (expected %s in all six)" % [
		"PASS" if correct else ("SPLIT -- rotation decides" if not uniform
			else "UNIFORM but not the expected voli"),
		expectation,
	])


## ---------------------------------------------------------------- gate 1
##
## The ordinary ball. Setter reachable, everyone reachable. The setter must keep
## it in every rotation -- strong first responsibility -- and the *rotation* must
## not be part of the answer.
func _gate_1_normal_reachable() -> void:
	print("\n  GATE 1 -- normal setter, reachable. Responsibility must hold.")
	var positions := _default_positions()
	_report_sweep(
		_rotation_sweep(positions, 106, PASS_TARGET, PASS_WINDOW, 999),
		SETTER_ID, "the setter",
	)


## ---------------------------------------------------------------- gate 2
##
## The setter is stranded in the far corner and a voli the plan **nominated** is
## standing on the ball. Policy says the contact may transfer. Slot 2 must not
## uniquely protect the setter.
func _gate_2_stranded_responsible() -> void:
	print("\n  GATE 2 -- stranded setter, NOMINATED team-mate on the ball.")
	var positions := _default_positions()
	positions[SETTER_ID] = STRANDED
	positions[106] = PASS_TARGET
	for bystander in [101, 103, 104, 105]:
		positions[bystander] = PARKED
	_report_sweep(
		## 106 takes slot 2 (or slot 1 when the setter is there), so the
		## challenger always carries a nominated emergency duty.
		_rotation_sweep(positions, 106, PASS_TARGET, 1.20, 999, 2),
		106, "the team-mate on the ball",
	)


## ------------------------------------------------------------- gate 2b
##
## **Where exactly does the ball change hands, and is the setter still able to
## reach it when it does?**
##
## Gates 1 and 2 are the two endpoints; this is the line between them, and it is
## the one that says whether the policy was implemented or merely approximated.
## "Strong first responsibility, not absolute" means the transfer should happen
## when the setter's claim becomes *impossible*, not merely when somebody else is
## better placed. So the challenger is parked on the ball -- the strongest claim
## a body can make -- and the setter is walked out from beside it.
##
## The column that matters is `setter reachable`. If the ball transfers while the
## setter is still comfortably arriving, responsibility is too weak whatever the
## verdict column says.
func _gate_2b_transfer_point() -> void:
	print("\n  GATE 2b -- the crossing. Challenger (nominated) parked ON the ball;")
	print("  the setter walks out from beside it. Window 1.20 s.")
	print("      %-12s %-11s %-11s %-13s" % [
		"setter dist", "margin_s", "reachable", "chosen",
	])
	## Concentrated at the near end. The whole question lives in the first metre
	## or so -- past that the setter is plainly gone and the table is just
	## confirming it, which is a waste of rows.
	for step in [0.0, 0.02, 0.04, 0.06, 0.08, 0.12, 0.20, 0.50, 1.0]:
		var positions := _default_positions()
		positions[SETTER_ID] = PASS_TARGET.lerp(STRANDED, step)
		positions[106] = PASS_TARGET
		for bystander in [101, 103, 104, 105]:
			positions[bystander] = PARKED
		var slot_map := {1: 101, 2: 106, 3: SETTER_ID, 4: 103, 5: 104, 6: 105}
		var fixture := _fixture(positions, {}, slot_map)
		## Measured without the challenger, so the reported margin and
		## reachability are the *setter's own*, not the winner's.
		var solo := _fixture(positions, {}, slot_map)
		var solo_verdict := _run(solo, 106, PASS_TARGET, 1.20)
		var verdict := _run(fixture, 999, PASS_TARGET, 1.20)
		print("      %-12.4f %-11.3f %-11s %-13s" % [
			_metres(Vector2(positions[SETTER_ID]), PASS_TARGET),
			float(solo_verdict.margin),
			"yes" if bool(solo_verdict.reachable) else "NO",
			_label(int(verdict.chosen_id)),
		])
	print("      -> a transfer while the setter is still 'yes' is the policy")
	print("         being approximated rather than implemented")


func _metres(a: Vector2, b: Vector2) -> float:
	return Vector2(
		(a.x - b.x) * COURT_WIDTH_METERS, (a.y - b.y) * COURT_LENGTH_METERS
	).length()


## ---------------------------------------------------------------- gate 3
##
## The same impossible claim, but the voli on the ball has **no duty at all**.
## Measured separately and deliberately: the policy permits physical
## impossibility to override responsibility, and it does *not* license inventing
## a hierarchy to force this case. Whatever the existing score does once the
## double count is gone is the answer, and it is reported as found.
func _gate_3_stranded_no_duty() -> void:
	print("\n  GATE 3 -- stranded setter, NO-DUTY team-mate on the ball.")
	print("  (reported as found -- no coefficient invented to force it)")
	var positions := _default_positions()
	positions[SETTER_ID] = STRANDED
	positions[106] = PASS_TARGET
	for bystander in [101, 103, 104, 105]:
		positions[bystander] = PARKED
	## Slot 4 is never nominated, so the challenger holds no duty in any rotation
	## -- except the one where the setter stands in slot 4, which is why the
	## table prints the duty it actually resolved to.
	_report_sweep(
		_rotation_sweep(positions, 106, PASS_TARGET, 1.20, 999, 4),
		106, "the team-mate on the ball",
	)


## ---------------------------------------------------------------- gate 4
##
## **The control, and the one this change could plausibly break.** Geometry
## normal and unchanged, duties unchanged; only a non-setter's `set_accuracy`
## moves. Technical quality must not become the reason responsibility transfers.
## Lowering the setter's term narrows their lead, so this is where that shows up
## if it is going to.
func _gate_4_rating_control() -> void:
	print("\n  GATE 4 -- rating control. Geometry fixed; only set_accuracy moves.")
	print("      %-10s %-46s" % ["set_acc", "chosen, rotations 1..6"])
	for accuracy in [50, 70, 85, 99]:
		var rows := _rotation_sweep(
			_default_positions(), 106, PASS_TARGET, PASS_WINDOW, 999, 2,
			{106: {"set_accuracy": accuracy}},
		)
		var cells: Array[String] = []
		var chosen := {}
		for row in rows:
			chosen[int(row.chosen_id)] = true
			cells.append("slot%d" % _slot_of(int(row.chosen_id)) \
				if int(row.chosen_id) != SETTER_ID else "SETTER")
		print("      %-10d %-46s %s" % [
			accuracy, " ".join(cells),
			"ok" if chosen.size() == 1 and chosen.has(SETTER_ID) else "<- MOVED",
		])
	print("      -> responsibility must not be bought with set_accuracy")


## ---------------------------------------------------------------- gate 5
##
## The setter played the first ball, so they are excluded from the candidate
## list outright. The plan's fallback hierarchy is all that is left, and giving
## the *active* setter a flat term must not have touched it.
func _gate_5_setter_made_first_contact() -> void:
	print("\n  GATE 5 -- setter made first contact. Fallback must be intact.")
	var rows := _rotation_sweep(
		_default_positions(), 106, PASS_TARGET, PASS_WINDOW, SETTER_ID, 2
	)
	print("      %-7s %-13s %-13s %-13s" % [
		"rot", "chall. slot", "chall. duty", "chosen",
	])
	var nominated := 0
	for row in rows:
		var chosen_slot := _slot_in(Dictionary(row.slot_map), int(row.chosen_id))
		if chosen_slot == 1 or chosen_slot == 2:
			nominated += 1
		print("      %-7d %-13d %-13s slot %-8d" % [
			int(row.setter_slot), int(row.challenger_slot),
			_short_duty(str(row.challenger_duty)), chosen_slot,
		])
	print("      -> %d of 6 went to a NOMINATED slot (1 or 2)%s" % [
		nominated, "" if nominated == 6 else "   <- fallback hierarchy broken",
	])


## Which slot an id occupies in a *rotated* layout.
func _slot_in(slot_map: Dictionary, player_id: int) -> int:
	for slot_number in slot_map:
		if int(slot_map[slot_number]) == player_id:
			return int(slot_number)
	return -1


## ---------------------------------------------------------------- gate 6
##
## The pathological fixture from the `767faf7` audit, unchanged, rotated. This
## is the regression the whole pass exists for: identical bodies, identical
## ball, identical assignments-that-matter, and a rotation that must not create
## a unique outcome.
func _gate_6_rotation_invariance() -> void:
	print("\n  GATE 6 -- the 767faf7 pathological fixture, rotated.")
	var positions := _default_positions()
	positions[SETTER_ID] = STRANDED
	positions[101] = PASS_TARGET
	for bystander in [103, 104, 105, 106]:
		positions[bystander] = PARKED
	var rows := _rotation_sweep(positions, 101, PASS_TARGET, 1.20, 999, 3)
	var chosen := {}
	print("      %-7s %-13s %-13s" % ["rot", "chall. duty", "chosen"])
	for row in rows:
		chosen[int(row.chosen_id)] = true
		print("      %-7d %-13s %-13s" % [
			int(row.setter_slot), _short_duty(str(row.challenger_duty)),
			_label(int(row.chosen_id)),
		])
	print("      -> %s" % ("PASS -- no rotation-specific accident"
		if chosen.size() == 1 else
		"FAIL -- %d different answers across six rotations" % chosen.size()))


## ============================================ home/opponent head-start symmetry
##
## The audit found the home path passes the serve's own flight as
## `head_start_seconds` and `_opponent_reception` passes nothing. The question
## for **this** node is narrow and answerable: does the missing head start change
## *who is selected*, or only how their arrival is reported?
##
## One geometry, one ball, one duty layout. Only the head start moves -- which is
## exactly the difference between the two call sites, so this is the asymmetry
## itself rather than a model of it.
func _head_start_symmetry() -> void:
	print("\n" + "=".repeat(78))
	print("HOME/OPPONENT SYMMETRY -- only `head_start_seconds` differs")
	print("=".repeat(78))
	print("  Home passes the serve's flight here; `_opponent_reception` passes 0.")
	print("  %-22s %-14s %-14s %-10s" % [
		"fixture", "opponent (0 s)", "home (1.34 s)", "same?",
	])
	var fixtures := {
		"normal": {"setter": Vector2(0.66, 0.60), "challenger": Vector2(0.48, 0.90)},
		"setter mid-far": {"setter": Vector2(0.30, 0.86), "challenger": Vector2(0.52, 0.72)},
		"setter stranded": {"setter": STRANDED, "challenger": PASS_TARGET},
	}
	for fixture_name in fixtures:
		var entry: Dictionary = fixtures[fixture_name]
		var verdicts: Array[int] = []
		for head_start in [0.0, 1.34]:
			var positions := _default_positions()
			positions[SETTER_ID] = Vector2(entry.setter)
			positions[106] = Vector2(entry.challenger)
			for bystander in [101, 103, 104, 105]:
				positions[bystander] = PARKED
			var fixture := _fixture(positions)
			verdicts.append(int(
				_run(fixture, 999, PASS_TARGET, 1.20, head_start).chosen_id
			))
		print("  %-22s %-14s %-14s %-10s" % [
			fixture_name, _label(verdicts[0]), _label(verdicts[1]),
			"yes" if verdicts[0] == verdicts[1] else "**NO**",
		])
	print("  A row reading NO is an authority defect in THIS node: the two sides")
	print("  answer an identical physical situation differently.")
	print("")
	print("  **This section characterises the parameter, it does not gate the")
	print("  call site.** It drives `_spatial_setter_choice` directly with both")
	print("  values, so a NO here means the head start is capable of deciding a")
	print("  transfer -- which is the reason the two call sites had to agree, not")
	print("  evidence about whether they now do. Part B's per-side split is where")
	print("  the wiring is actually visible.")


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
		"no_reach_margin": 0, "negative_margin": 0, "home_points": 0,
	}
	var margin_total := 0.0
	var travel_total := 0.0
	var claimant_total := 0
	var by_actor := {}
	## Regression observation only. A second-contact change that moves the
	## scoreboard is worth *seeing*; it is emphatically not worth steering, and
	## the old 5% emergency rate is a measurement rather than a target.
	var outcomes := {}
	## **Per side, because the head start is a per-side argument.** The home path
	## has always passed the feeding ball's flight and the opponent path passed
	## nothing, so if that asymmetry is real it shows up here as the opponent
	## arriving later, from further, with fewer team-mates able to reach the ball
	## at all. `claimant_count` is the sharpest of the three: it counts how many
	## volis `CoverageModel.evaluate_arrival` called reachable, and a side running
	## from a standing start has fewer.
	var sides := {
		"home": {"sets": 0, "margin": 0.0, "travel": 0.0, "claimants": 0,
			"late": 0, "uncontested": 0, "emergency": 0},
		"opponent": {"sets": 0, "margin": 0.0, "travel": 0.0, "claimants": 0,
			"late": 0, "uncontested": 0, "emergency": 0},
	}
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			counts["rallies"] = int(counts.rallies) + 1
			if rally != null:
				var outcome := str(rally.terminal_outcome)
				outcomes[outcome] = int(outcomes.get(outcome, 0)) + 1
				if bool(rally.home_team_won):
					counts["home_points"] = int(counts.home_points) + 1
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
					var cell: Dictionary = sides.get(side, sides["home"])
					cell["sets"] = int(cell.sets) + 1
					cell["margin"] = float(cell.margin) + margin
					cell["travel"] = float(cell.travel) \
						+ float(metadata.get("movement_duration", 0.0))
					cell["claimants"] = int(cell.claimants) + claimants
					if margin < 0.0:
						cell["late"] = int(cell.late) + 1
					if claimants <= 1:
						cell["uncontested"] = int(cell.uncontested) + 1
					if bool(metadata.get("emergency_setter", false)):
						cell["emergency"] = int(cell.emergency) + 1
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
	print("\n  PER SIDE -- is the head start reaching both call sites?")
	print("      %-10s %-6s %-9s %-9s %-10s %-8s %-9s" % [
		"side", "sets", "margin_s", "travel_s", "claimants", "late", "emerg.",
	])
	for side_name in ["home", "opponent"]:
		var cell: Dictionary = sides[side_name]
		var count := maxf(float(cell.sets), 1.0)
		print("      %-10s %-6d %-9.4f %-9.4f %-10.4f %-8.4f %-9.4f" % [
			side_name, int(cell.sets), float(cell.margin) / count,
			float(cell.travel) / count, float(cell.claimants) / count,
			float(cell.late) / count, float(cell.emergency) / count,
		])
	print("      a side timed from a standing start shows fewer reachable")
	print("      claimants and a thinner arrival margin than the other")

	print("\n  RALLY OUTCOMES  (regression observation, never a target)")
	print("      home points %d of %d (%.4f)" % [
		int(counts.home_points), int(counts.rallies),
		float(counts.home_points) / maxf(float(counts.rallies), 1.0),
	])
	var outcome_names: Array = outcomes.keys()
	outcome_names.sort()
	for outcome_name in outcome_names:
		print("      %-28s %-5d %.4f" % [
			outcome_name, int(outcomes[outcome_name]),
			float(outcomes[outcome_name]) / maxf(float(counts.rallies), 1.0),
		])

	print("\n  DISTINCT SETTERS  (regression observation, never a target)")
	var actors: Array = by_actor.keys()
	actors.sort()
	for actor in actors:
		print("      actor %-6d %-5d %.4f" % [
			actor, int(by_actor[actor]), float(by_actor[actor]) / sets,
		])
