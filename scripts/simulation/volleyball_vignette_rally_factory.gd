class_name VolleyballVignetteRallyFactory
extends RefCounted

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const DefensivePlanScript := preload("res://scripts/models/defensive_plan.gd")
const OffensivePlayScript := preload("res://scripts/models/offensive_play.gd")
const HitterAssignmentScript := preload("res://scripts/models/hitter_assignment.gd")
const TeamPrinciplesScript := preload("res://scripts/models/team_principles.gd")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const SimulatorScript := preload("res://scripts/simulation/vignette_rally_simulator.gd")

const H1_OUTSIDE := 2
const H2_MIDDLE := 3
const H3_SETTER := 1
const H4_OUTSIDE := 5
const H5_LIBERO := 6
const H6_OPPOSITE := 4

## The visual cast follows the approved script exactly by court job. IDs are the
## vertical-slice bodies behind those jobs; labels are hidden in creation.
const A1_LEFT_FRONT := 104
const A2_MIDDLE := 103
const A3_RIGHT_FRONT := 102
const A4_LEFT_BACK := 105
const A5_MIDDLE_BACK := 106
const A6_RIGHT_BACK := 101

const BASE_SEED := 8300
const SEED_SEARCH := 720

static var _cache: Dictionary = {}


static func q1(mode: String) -> Resource:
	var key := mode.to_lower()
	if _cache.has(key):
		return _cache[key]
	var fixture := _fixture(key)
	if fixture.is_empty():
		return null
	var best: Resource = null
	var best_score := -1
	for offset in range(SEED_SEARCH):
		var simulator := SimulatorScript.new() as VignetteRallySimulator
		simulator.vignette_opponent_plan = fixture.opponent_plan
		var result: Resource = simulator.resolve(
			fixture.players, fixture.lineup, fixture.play,
			fixture.opponent, fixture.home_plan,
			false, BASE_SEED + offset,
			false, false, fixture.principles,
			"Q1 Home", {}, 0.0, false, false,
		)
		## Threat availability and the pre-release information state are the two
		## authored halves of the vignette contract. They are expressed as phase
		## targets on the resolved rally, so MatchScreen still owns how far a body
		## actually travels in the available physical window. Contacts, ball flight,
		## block outcome, legality and continuation remain untouched.
		_apply_script_phase_state(result, key)
		var score := _q1_score(result, key, fixture.opponent_lineup)
		if score > best_score:
			best = result
			best_score = score
		if score >= 100:
			best = result
			best.set_meta("vignette_seed", BASE_SEED + offset)
			break
	if best != null:
		best.set_meta("vignette_mode", key)
		best.set_meta("vignette_acceptance_score", best_score)
		_cache[key] = best
		print("Q1 vignette %s resolved at seed %d (acceptance %d)" % [
			key, int(best.get_meta("vignette_seed", -1)), best_score,
		])
	return best


## ## Q2 to Q5, through the same resolver Q1 uses
##
## Q1 was promoted to real resolved rallies and the other four questions were
## left drawing through the authored path in `volleyball_philosophy_preview` --
## hand-placed bodies and hand-flown balls that cannot be wrong about the
## simulation because they never consult it. That makes them decoration on a
## page whose whole claim is that it shows the player what their volleyball will
## look like, and it makes them useless as diagnostics, which is the second
## reason to move them.
##
## **What varies between questions is small**, which is why this is a table
## rather than four more factories: which side serves, which principle the three
## answers move, and which events the rally has to contain to be about the
## question at all. Everything else -- cast, lineups, opponent, plans -- is the
## Q1 fixture unchanged.
const QUESTION_SPECS := {
	"serve": {
		"home_serving": true,
		"principle": "serve_aggression",
		"modes": {"controlled": 0.24, "target": 0.55, "aggressive": 0.86},
	},
	"defense": {
		"home_serving": true,
		"principle": "block_commitment",
		"modes": {"floor": 0.24, "read": 0.50, "block": 0.86},
	},
	"transition": {
		"home_serving": false,
		"principle": "transition_commitment",
		"modes": {"reset": 0.28, "opportunity": 0.58, "pressure": 0.86},
	},
	"broken": {
		"home_serving": false,
		"principle": "decisiveness",
		"modes": {"structure": 0.28, "available": 0.55, "pressure": 0.86},
	},
}


## A rally for one of the later questions.
##
## **The contract is deliberately weaker than `_q1_score`'s and says so.** Q1
## scores six specific things because it is teaching one distinction between
## three named answers. These four ask only that the rally *be about the
## question*: a serve question needs a home serve, a defence question needs an
## opponent swing that the home side answers, and so on. A contract tighter than
## the understanding behind it would be a number invented to look rigorous, and
## the honest move is to require what is actually known and leave the rest to the
## grid that measures these rallies rather than judging them.
static func question(key: String, mode: String) -> Resource:
	var spec: Dictionary = QUESTION_SPECS.get(key, {})
	if spec.is_empty():
		return null
	var modes: Dictionary = spec["modes"]
	if not modes.has(mode):
		return null
	var cache_key := "%s|%s" % [key, mode]
	if _cache.has(cache_key):
		return _cache[cache_key]
	## The Q1 fixture, borrowed whole. `read` is its most neutral cast, which is
	## what a question that is not about the good-ball decision wants.
	var fixture := _fixture("read")
	if fixture.is_empty():
		return null
	var values := {
		"decisiveness": 0.50,
		"pin_focus": 0.50,
		"tempo_variation": 0.50,
		"emotional_expression": 0.50,
		"serve_aggression": 0.50,
		"transition_commitment": 0.50,
		"block_commitment": 0.50,
	}
	values[str(spec["principle"])] = float(modes[mode])
	var principles: Resource = TeamPrinciplesScript.custom(
		"%s %s" % [key.capitalize(), mode], values
	)
	var best: Resource = null
	var best_score := -1
	for offset in range(SEED_SEARCH):
		var simulator := SimulatorScript.new() as VignetteRallySimulator
		simulator.vignette_opponent_plan = fixture.opponent_plan
		var result: Resource = simulator.resolve(
			fixture.players, fixture.lineup, fixture.play,
			fixture.opponent, fixture.home_plan,
			bool(spec["home_serving"]), BASE_SEED + offset,
			false, false, principles,
			"%s Home" % key.capitalize(), {}, 0.0, false, false,
		)
		var score := _question_score(result, key)
		if score > best_score:
			best = result
			best_score = score
		if score >= 100:
			best = result
			best.set_meta("vignette_seed", BASE_SEED + offset)
			break
	if best != null:
		best.set_meta("vignette_mode", cache_key)
		best.set_meta("vignette_acceptance_score", best_score)
		_cache[cache_key] = best
		print("%s vignette %s resolved at seed %d (acceptance %d)" % [
			key, mode, int(best.get_meta("vignette_seed", -1)), best_score,
		])
	return best


## Is this rally about the question being asked?
##
## Each clause is a thing a viewer would have to see for the answer to mean
## anything, and nothing else is asserted.
static func _question_score(result: Resource, key: String) -> int:
	if result == null:
		return -1
	match key:
		"serve":
			## A home serve that reaches a receiver, so the answer's effect on
			## the reception is visible rather than an ace or a net cord.
			var serve := _first_event(
				result, RallyEventModel.EventType.SERVE, "home"
			)
			if serve == null:
				return 0
			var reception := _first_event(
				result, RallyEventModel.EventType.RECEPTION, "opponent"
			)
			return 100 if reception != null else 50
		"defense":
			## An opponent swing the home side actually answers, at the net or
			## on the floor. Without the answer there is no defence to show.
			var swing := _first_event(
				result, RallyEventModel.EventType.ATTACK, "opponent"
			)
			if swing == null:
				return 0
			var wall := _first_event(
				result, RallyEventModel.EventType.BLOCK, "home"
			)
			var dig := _first_event(result, RallyEventModel.EventType.DIG, "home")
			return 100 if wall != null or dig != null else 40
		"transition":
			## Defence turning into offence: a home dig and then a home swing.
			var dig := _first_event(result, RallyEventModel.EventType.DIG, "home")
			if dig == null:
				return 0
			var swing := _first_event(
				result, RallyEventModel.EventType.ATTACK, "home"
			)
			return 100 if swing != null else 50
		"broken":
			## Out of system: the home side touches the ball more than the three
			## a clean pass-set-hit uses, and still gets a swing away.
			## Contacts only. Counting every home-side event made SET_DECISION a
			## touch, which is a tactical choice rather than a hand on the ball --
			## and it took a three-contact rally past the four-contact bar this
			## clause exists to check. A contract passing on an event that is not
			## the thing it names is the same failure as a threshold measured with
			## the wrong instrument.
			var touches := 0
			for raw_event in result.events:
				var event: Resource = raw_event
				if event == null \
						or str(event.metadata.get("side", "")) != "home":
					continue
				if int(event.event_type) in [
					RallyEventModel.EventType.POINT,
					RallyEventModel.EventType.SET_DECISION,
				]:
					continue
				touches += 1
			var swing := _first_event(
				result, RallyEventModel.EventType.ATTACK, "home"
			)
			if swing == null:
				return 0
			return 100 if touches >= 4 else 60
	return 0


static func _fixture(mode: String) -> Dictionary:
	var gm := GameManagerScript.new()
	gm.seed_vertical_slice_data()
	var players: Array[VolleyballPlayer] = gm.players
	var opponent: OpponentTeam = gm.opponent_team as OpponentTeam
	if opponent == null:
		return {}

	var lineup := _home_lineup()
	var opponent_lineup := _opponent_lineup()
	opponent.rotations.clear()
	opponent.rotations[1] = opponent_lineup
	opponent.setter_id = A6_RIGHT_BACK
	opponent.select_rotation(1)
	opponent.tendencies["serve_target"] = "Short Middle"

	_tune_cast(players, opponent)
	_configure_opponent_information(opponent, mode)
	var home_plan := DefensivePlanScript.new() as DefensivePlan
	home_plan.rotation_number = 1
	home_plan.ensure_defaults(lineup, players)
	var opponent_plan := _opponent_plan(opponent, opponent_lineup, mode)
	var play := _q1_play(mode)
	var values := {
		"decisiveness": 0.48 if mode == "read" else 0.72,
		"pin_focus": 0.38 if mode == "quick" else (0.48 if mode == "read" else 0.72),
		"tempo_variation": 0.68 if mode == "quick" else (0.62 if mode == "read" else 0.42),
		"emotional_expression": 0.50,
		"serve_aggression": 0.50,
		"transition_commitment": 0.50,
		"block_commitment": 0.50,
	}
	return {
		"players": players,
		"lineup": lineup,
		"opponent": opponent,
		"opponent_lineup": opponent_lineup,
		"home_plan": home_plan,
		"opponent_plan": opponent_plan,
		"play": play,
		"principles": TeamPrinciplesScript.custom("Q1 %s" % mode, values),
	}


static func _home_lineup() -> RotationLineup:
	var lineup := RotationLineup.new()
	lineup.rotation_number = 1
	lineup.setter_id = H3_SETTER
	lineup.designated_setter_ids = [H3_SETTER]
	## LF / MF / RF then LB / MB / RB: exactly the approved Q1 cast.
	lineup.assign_slot(4, H1_OUTSIDE)
	lineup.assign_slot(3, H2_MIDDLE)
	lineup.assign_slot(2, H3_SETTER)
	lineup.assign_slot(5, H4_OUTSIDE)
	lineup.assign_slot(6, H5_LIBERO)
	lineup.assign_slot(1, H6_OPPOSITE)
	return lineup


static func _opponent_lineup() -> RotationLineup:
	var lineup := RotationLineup.new()
	lineup.rotation_number = 1
	lineup.setter_id = A6_RIGHT_BACK
	lineup.designated_setter_ids = [A6_RIGHT_BACK]
	## CourtConstants mirrors Y but deliberately keeps global X. Because Away
	## faces toward increasing Y, its volleyball left/right is the inverse of the
	## Home side on screen. Put the named roles at their actual physical sides:
	## A3 (right-front) is across H1, and A6 (right-back) is behind A3.
	lineup.assign_slot(4, A3_RIGHT_FRONT)
	lineup.assign_slot(3, A2_MIDDLE)
	lineup.assign_slot(2, A1_LEFT_FRONT)
	lineup.assign_slot(5, A6_RIGHT_BACK)
	lineup.assign_slot(6, A5_MIDDLE_BACK)
	lineup.assign_slot(1, A4_LEFT_BACK)
	return lineup


static func _tune_cast(players: Array[VolleyballPlayer], opponent: OpponentTeam) -> void:
	var h5 := _home_player(players, H5_LIBERO)
	if h5 != null:
		h5.reception = 97
		h5.reception_balance = 96
		h5.reception_stability = 96
		h5.ball_control = 94
		h5.anticipation = 92
	var h4 := _home_player(players, H4_OUTSIDE)
	if h4 != null:
		h4.reception = 76
	var h6 := _home_player(players, H6_OPPOSITE)
	if h6 != null:
		h6.reception = 66
		h6.approach_timing = 86
	var setter := _home_player(players, H3_SETTER)
	if setter != null:
		setter.set_accuracy = 96
		setter.set_balance = 94
		setter.set_stability = 95
		setter.tempo_control = 97
		setter.set_disguise = 94
		setter.decision_making = 95
	var outside := _home_player(players, H1_OUTSIDE)
	if outside != null:
		outside.attack_accuracy = 91
		outside.attack_power = 82
		outside.approach_timing = 94
		outside.tooling = 100
		outside.court_vision = 92
		outside.composure = 93
	var middle := _home_player(players, H2_MIDDLE)
	if middle != null:
		middle.attack_accuracy = 91
		middle.attack_power = 85
		middle.approach_timing = 97
		middle.explosiveness = 94
		middle.jump_reach = 90

	## The opening is a genuinely good first ball, not a lucky ace/shank lottery.
	## The opponent serves from slot 1; after the physical left/right correction
	## that is A4, not A6.
	var server := opponent.player_by_id(A4_LEFT_BACK) as VolleyballPlayer
	if server != null:
		server.serve_power = 36
		server.serve_accuracy = 95
		server.serve_technique = 94
		server.serve_placement = 94
		server.serve_consistency = 98
		server.serve_aggression = 24
		server.primary_serve_style = "Standing"
	for blocker_id in [A1_LEFT_FRONT, A2_MIDDLE, A3_RIGHT_FRONT]:
		var blocker := opponent.player_by_id(blocker_id) as VolleyballPlayer
		if blocker == null:
			continue
		blocker.block_timing = 82 if blocker_id == A2_MIDDLE else 74
		blocker.lateral_speed = 78
		blocker.acceleration = 76
		blocker.jump_reach = 74
		blocker.anticipation = 80
		blocker.tactical_discipline = 82
	for defender_id in [A4_LEFT_BACK, A5_MIDDLE_BACK, A6_RIGHT_BACK]:
		var defender := opponent.player_by_id(defender_id) as VolleyballPlayer
		if defender != null:
			defender.anticipation = 82
			defender.lateral_speed = 78
			defender.acceleration = 76
			defender.dig_control = 78


static func _configure_opponent_information(opponent: OpponentTeam, mode: String) -> void:
	opponent.observed_attack_lanes.clear()
	opponent.observed_tempos.clear()
	opponent.rallies_observed = 0
	opponent.block_adaptation_strength = 0.0
	opponent.floor_defense_adaptation_strength = 0.0
	if mode == "read":
		## The defense has consumed the quick cue. The real resolver decides how
		## far each body can commit and how much it can repair once the set leaves.
		opponent.observed_attack_lanes["Front Quick"] = 12
		opponent.observed_tempos["T0"] = 12
		opponent.rallies_observed = 12
		opponent.block_adaptation_strength = 0.82
		opponent.floor_defense_adaptation_strength = 0.58
	elif mode == "hitter":
		## Nobody is fooled. They are organised for the pin and the hitter must
		## solve a real wall plus line/deep/cross floor coverage.
		opponent.observed_attack_lanes["Left Pin"] = 12
		opponent.observed_tempos["T2"] = 12
		opponent.rallies_observed = 12
		opponent.block_adaptation_strength = 0.80
		opponent.floor_defense_adaptation_strength = 0.72


static func _opponent_plan(
	opponent: OpponentTeam, lineup: RotationLineup, mode: String
) -> DefensivePlan:
	var plan := DefensivePlanScript.new() as DefensivePlan
	plan.rotation_number = 1
	plan.ensure_defaults(lineup, opponent.players)
	plan.block_intent = "Balanced"
	match mode:
		"quick":
			plan.block_strategy = "Read Block"
			## A4/A6 hold their physical wings while middle-back takes the sharper
			## central read. These coordinates are authored on the home-oriented
			## defensive board and mirrored only in Y by the resolver.
			plan.set_defender_position(A4_LEFT_BACK, Vector2(0.80, 0.85))
			plan.set_defender_position(A5_MIDDLE_BACK, Vector2(0.50, 0.77))
			plan.set_defender_position(A6_RIGHT_BACK, Vector2(0.20, 0.85))
		"read":
			plan.block_strategy = "Commit Middle"
			## A subtle central squeeze follows the credible quick. When the set
			## releases left, these are starting obligations, not teleports.
			plan.set_defender_position(A4_LEFT_BACK, Vector2(0.73, 0.82))
			plan.set_defender_position(A5_MIDDLE_BACK, Vector2(0.48, 0.78))
			plan.set_defender_position(A6_RIGHT_BACK, Vector2(0.27, 0.82))
		_:
			plan.block_strategy = "Commit Pin"
			plan.block_intent = "Seal"
			## Coherent pin defense behind A3+A2: A6 shades the line, A5 owns deep
			## middle, A4 holds crosscourt. The resolver remains free to stop a
			## body short if the flight does not buy the time.
			plan.set_defender_position(A6_RIGHT_BACK, Vector2(0.18, 0.82))
			plan.set_defender_position(A5_MIDDLE_BACK, Vector2(0.50, 0.91))
			plan.set_defender_position(A4_LEFT_BACK, Vector2(0.80, 0.82))
	return plan


static func _q1_play(mode: String) -> OffensivePlay:
	var play := OffensivePlayScript.new() as OffensivePlay
	play.id = 9101
	play.play_name = "Q1 %s" % mode.capitalize()
	play.rotation_number = 1
	play.context = "Serve Receive"
	var outside := _assignment(H1_OUTSIDE, Vector2(0.18, 0.57), "Left Pin", 2, 6, false)
	var quick := _assignment(H2_MIDDLE, Vector2(0.50, 0.56), "Front Quick", 0, 6, mode != "quick")
	var pipe := _assignment(H6_OPPOSITE, Vector2(0.80, 0.84), "Pipe", 2, 4, true)
	if mode == "quick":
		outside.is_decoy = true
		quick.is_decoy = false
		play.primary_hitter_id = H2_MIDDLE
	else:
		outside.is_decoy = false
		play.primary_hitter_id = H1_OUTSIDE
	play.secondary_hitter_id = H6_OPPOSITE
	play.assignments.assign([outside, quick, pipe])
	play.fallback_lane = "Left Pin"
	return play


static func _assignment(
	player_id: int, start: Vector2, lane: String, tempo: int,
	priority: int, decoy: bool
) -> HitterAssignment:
	var assignment := HitterAssignmentScript.new() as HitterAssignment
	assignment.player_id = player_id
	assignment.start_position = start
	assignment.lane = lane
	assignment.tempo = tempo
	assignment.priority = priority
	assignment.is_decoy = decoy
	return assignment


## Add only the authored state the design explicitly permits: which threats stay
## credible before release, and what information the blockers have committed to
## before H3 chooses. Movement between those targets is still paced by the real
## MatchScreen plan; no ball/contact/outcome data is rewritten here.
static func _apply_script_phase_state(result: Resource, mode: String) -> void:
	if result == null:
		return
	var set_event := _first_event(result, RallyEventModel.EventType.SET, "home")
	if set_event == null:
		return
	var home_targets: Dictionary = Dictionary(
		set_event.metadata.get("home_phase_targets", {})
	).duplicate(true)
	var home_intents: Dictionary = Dictionary(
		set_event.metadata.get("home_phase_intents", {})
	).duplicate(true)
	var selected := H2_MIDDLE if mode == "quick" else H1_OUTSIDE
	var threat_targets := {
		H1_OUTSIDE: Vector2(0.16, 0.61),
		H2_MIDDLE: Vector2(0.43, 0.585),
		## H4 releases forward-left and then becomes the first coverage layer.
		H4_OUTSIDE: Vector2(0.27, 0.73),
		## The passer does not become the setter; H5 steps into attack coverage.
		H5_LIBERO: Vector2(0.48, 0.74),
		## A real back-row threat stays behind the attack line while loading its
		## runway. This is the authored "available threat"; legality/contact still
		## belong to the resolver if that player is ever actually selected.
		H6_OPPOSITE: Vector2(0.66, 0.70),
	}
	for raw_id in threat_targets:
		var player_id := int(raw_id)
		if player_id == selected:
			continue
		home_targets[player_id] = threat_targets[raw_id]
		home_intents[player_id] = {
			"intent": &"credible_threat" if player_id in [H1_OUTSIDE, H2_MIDDLE, H6_OPPOSITE] \
				else &"attack_coverage",
			"scripted_vignette": true,
		}
	set_event.metadata["home_phase_targets"] = home_targets
	set_event.metadata["home_phase_intents"] = home_intents

	## The Read answer only works if the commitment exists before H3 releases.
	## Quick keeps all three neutral; Hitter keeps a sound pin wall square. These
	## are information-state targets, not the post-set wall the resolver computes.
	var opponent_targets: Dictionary = Dictionary(
		set_event.metadata.get("opponent_phase_targets", {})
	).duplicate(true)
	var opponent_intents: Dictionary = Dictionary(
		set_event.metadata.get("opponent_phase_intents", {})
	).duplicate(true)
	var pre_release := {
		A1_LEFT_FRONT: Vector2(0.80, 0.445),
		A2_MIDDLE: Vector2(0.50, 0.445),
		A3_RIGHT_FRONT: Vector2(0.20, 0.445),
	}
	if mode == "read":
		## A2 consumes the quick; A3 compresses enough that the outside release
		## asks both of them to repair. A1 stays honest on H6's side.
		pre_release[A2_MIDDLE] = Vector2(0.40, 0.445)
		pre_release[A3_RIGHT_FRONT] = Vector2(0.27, 0.445)
	for raw_id in pre_release:
		var player_id := int(raw_id)
		opponent_targets[player_id] = pre_release[raw_id]
		opponent_intents[player_id] = {
			"intent": &"pre_release_commit" if mode == "read" and player_id in [A2_MIDDLE, A3_RIGHT_FRONT] \
				else &"hold_block_base",
			"scripted_vignette": true,
		}
	set_event.metadata["opponent_phase_targets"] = opponent_targets
	set_event.metadata["opponent_phase_intents"] = opponent_intents


static func _home_player(
	players: Array[VolleyballPlayer], player_id: int
) -> VolleyballPlayer:
	for player in players:
		if player != null and player.id == player_id:
			return player
	return null


static func _first_event(result: Resource, event_type: int, side: String) -> Resource:
	if result == null:
		return null
	for raw_event in result.events:
		var event: Resource = raw_event
		if event != null and int(event.event_type) == event_type \
				and str(event.metadata.get("side", "")) == side:
			return event
	return null


static func _q1_score(
	result: Resource, mode: String, opponent_lineup: RotationLineup
) -> int:
	if result == null:
		return -1
	var reception := _first_event(result, RallyEventModel.EventType.RECEPTION, "home")
	var attack := _first_event(result, RallyEventModel.EventType.ATTACK, "home")
	if reception == null or attack == null:
		return 0
	var score := 0
	if int(reception.actor_id) == H5_LIBERO and bool(reception.success) \
			and float(reception.quality) >= 0.60:
		score += 20
	var expected_hitter := H2_MIDDLE if mode == "quick" else H1_OUTSIDE
	if int(attack.actor_id) == expected_hitter:
		score += 20
	if (mode == "quick" and int(attack.metadata.get("tempo", 3)) <= 1) \
			or (mode != "quick" and str(attack.metadata.get("lane", "")) == "Left Pin"):
		score += 15

	## The Away back row is part of the vignette, not scenery. Require the actual
	## resolver to publish an intention and a reached target for A4/A5/A6 on the
	## same attack that publishes the wall. Then require the three targets to read
	## as three distinct defensive jobs rather than a stack around the ball.
	var targets: Dictionary = attack.metadata.get("opponent_phase_targets", {})
	var intents: Dictionary = attack.metadata.get("opponent_phase_intents", {})
	var back_ids := [A4_LEFT_BACK, A5_MIDDLE_BACK, A6_RIGHT_BACK]
	var back_row_complete := true
	for player_id in back_ids:
		if not targets.has(player_id) or not intents.has(player_id):
			back_row_complete = false
	if back_row_complete:
		score += 10
		var a4 := Vector2(targets[A4_LEFT_BACK])
		var a5 := Vector2(targets[A5_MIDDLE_BACK])
		var a6 := Vector2(targets[A6_RIGHT_BACK])
		var distinct := a4.distance_to(a5) > 0.08 \
			and a5.distance_to(a6) > 0.08 \
			and a4.distance_to(a6) > 0.14
		var named_sides := a4.x > a5.x and a6.x < a5.x
		if distinct and named_sides:
			score += 15

	var wall_size := int(attack.metadata.get("wall_size", 0))
	if mode == "quick":
		## Time has to beat organisation: not a fully formed two-person wall.
		if wall_size < 2:
			score += 20
	elif mode == "read":
		## The committed middle may repair, but the resulting wall must still be
		## weaker than the clean pin wall used by Trust your hitters.
		var block_terms: Dictionary = attack.metadata.get("opponent_block_terms", {})
		var assist_close := float(block_terms.get("assist_close_attempted", 0.0))
		if wall_size < 2 or assist_close < 0.78:
			score += 20
	else:
		var block := _first_event(result, RallyEventModel.EventType.BLOCK, "opponent")
		if wall_size >= 2:
			score += 10
		if block != null and str(block.metadata.get("outcome", "")) == "tool":
			score += 10
	return score
