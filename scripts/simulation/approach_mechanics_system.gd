class_name ApproachMechanicsSystem
extends RefCounted

const RallyKinematicsModel := preload("res://scripts/simulation/rally_kinematics.gd")
const RallyMovementModel := preload("res://scripts/simulation/rally_movement_system.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const CourtConstants := preload("res://scripts/data/court_constants.gd")

## What a run-up has to deliver before a hitter can swing at full power, and
## before the whole shot menu is open to them. Named because the requirement
## table below has to agree with the profile that reports them; two copies of
## `0.48` in one file is how the block ended up with three contests.
const POWER_ACCESS_QUALITY_IN_SYSTEM: float = 0.48
const POWER_ACCESS_QUALITY_OUT_OF_SYSTEM: float = 0.52
const POWER_ACCESS_SPEED_FRACTION: float = 0.42
const POWER_ACCESS_LATERAL_CONTROL: float = 0.42
const FULL_MENU_QUALITY_IN_SYSTEM: float = 0.61
const FULL_MENU_QUALITY_OUT_OF_SYSTEM: float = 0.66
const FULL_MENU_LATERAL_CONTROL: float = 0.56

## What each attack family demands of the hitter and of the approach they got
## into it.
##
## **Capability is not permission.** `available_attack_families()` reports what
## a hitter can do cleanly; `attack_family_deficit()` reports how far outside
## that an attempt sits. Nothing here removes a swing from a hitter -- a player
## may attempt anything, and their attributes decide how it goes, not whether
## they are allowed. The second contact learned this first; this is the third
## contact's version of the same rule.
const ATTACK_FAMILY_REQUIREMENTS := {
	## Always available. A hitter with nothing left can always roll one over.
	"controlled_roll": {},
	"tip": {"rating": "finesse", "rating_floor": 45.0},
	"placed_attack": {
		"rating": "attack_accuracy", "rating_floor": 48.0,
		"lateral_control": 0.36, "arrival_margin": -0.12,
	},
	"power_attack": {
		"rating": "attack_power", "rating_floor": 52.0,
		"power_access": true, "arrival_margin": -0.06,
	},
	"tool_block": {
		"rating": "tooling", "rating_floor": 58.0,
		"runup_quality": 0.46, "lateral_control": 0.48,
	},
}

## Which family a named hit type belongs to, so the simulator's shot vocabulary
## and this system's capability vocabulary stay in one mapping rather than in a
## membership test written out at each call site.
const HIT_TYPE_FAMILY := {
	"Quick attack": "power_attack",
	"Power swing": "power_attack",
	"Tempo swing": "power_attack",
	"Pipe attack": "power_attack",
	"High-ball swing": "power_attack",
	"Controlled roll": "controlled_roll",
	"Emergency tip": "tip",
	"Short tip": "tip",
}

## Seconds of lateness that count as one full unit of shortfall, so a timing
## deficit is comparable with a rating or run-up deficit.
const ARRIVAL_DEFICIT_SCALE: float = 0.50


## Creates a decision-safe transition snapshot. A hitter releases only after
## recognizing that their current ball responsibility is finished; tactical
## duties can deliberately keep them available longer.
static func prepare_for_attack(
	state: RallyState,
	actor: RallyPlayerState,
	assignment: Dictionary,
	first_contact_player_id: int,
	set_contact_time: float,
	side: StringName = &"home",
) -> Dictionary:
	if state == null or actor == null or actor.player == null:
		return {"available": false}
	var reading := _reading_quality(actor.player)
	var recognition_delay := lerpf(0.30, 0.07, reading)
	var duty_delay := 0.0
	var release_reason := "recognized teammate ownership"
	var assignment_duty := ""
	var zone_priority := 0
	## `home_plan` is keyed by player id, and only home players appear in it.
	## Consulting it for an opponent works today only because the two id ranges
	## happen not to overlap, which is an assumption nothing enforces. Gate the
	## lookup on side so the coincidence can never become a duty leak.
	if side == &"home" and state.home_plan != null:
		var duty: Resource = state.home_plan.assignment_for(actor.player_id)
		if duty != null:
			assignment_duty = str(duty.attack_coverage_responsibility)
			var second_duty := str(duty.second_contact_responsibility)
			if "emergency setter" in second_duty.to_lower():
				duty_delay += 0.12
				release_reason = "held for emergency second contact"
			if bool(duty.emergency_pursuit):
				duty_delay += 0.05
			if assignment_duty == "Release for transition":
				duty_delay -= 0.08
				release_reason = "explicit transition release"
		var zone: Resource = state.home_plan.zone_for(
			actor.player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
		)
		if zone != null and bool(zone.enabled):
			zone_priority = int(zone.priority)
			duty_delay += float(zone_priority) * 0.025
	if actor.player_id == first_contact_player_id:
		duty_delay += 0.18
		release_reason = "completed first contact"
	var release_time := state.simulation_time + maxf(
		recognition_delay + duty_delay, 0.02
	)
	var target := Vector2(assignment.get("target", Vector2(0.5, 0.53)))
	var start := approach_start_position(
		target, str(assignment.get("lane", "Left Pin")), side
	)
	var preparation_time := maxf(set_contact_time - release_time, 0.0)
	## Run *through* the approach mark, not to it. This is the leg that ends
	## where the run-up begins, so stopping dead on arrival makes every hitter
	## re-accelerate from rest into their own swing -- which is exactly what was
	## happening, and why 83% of attack contacts were placed beyond reach.
	var projection := RallyMovementModel.project_toward(
		actor, start, preparation_time, RallyPlayerState.MovementMode.TRANSITION,
		true,
	)
	var prepared := projection.get("actor") as RallyPlayerState
	if prepared != null:
		prepared.intent = &"prepare_attack"
		prepared.intent_target = start
	return {
		"available": prepared != null,
		"actor": prepared,
		"release_time": release_time,
		"release_reason": release_reason,
		"recognition_delay_seconds": recognition_delay,
		"duty_delay_seconds": duty_delay,
		"defensive_duty": assignment_duty,
		"zone_priority": zone_priority,
		## Playback must render where the hitter physically ended up, not where
		## they were trying to get to. When preparation time is short (tight
		## tempo, contested duty) these two positions diverge, and showing the
		## aspirational mark would draw a run-up the player never actually made.
		"approach_start_position": prepared.position if prepared != null else start,
		## The ideal mark this player was working toward. Kept separately for
		## scouting/debug overlays ("missed their spot by 0.4m") without ever
		## feeding it into anything that draws a court position.
		"approach_target_position": start,
		"preparation_time_seconds": preparation_time,
		"preparation_distance_meters": float(projection.get("distance_meters", 0.0)),
		"reached_approach_start": bool(projection.get("reached_target", false)),
		"prepared_position": prepared.position if prepared != null else actor.position,
		"prepared_velocity_mps": prepared.velocity if prepared != null else actor.velocity,
		"decision_uses_authoritative_truth": false,
	}


## Resolves the run-up that is physically possible from the actor's current
## state. This profile is consumed by the contact envelope and action menu.
static func evaluate_takeoff(
	actor: RallyPlayerState,
	target: Vector2,
	available_time: float,
) -> Dictionary:
	if actor == null or actor.player == null:
		return {}
	var delta := RallyKinematicsModel.court_delta_meters(actor.position, target)
	var distance := delta.length()
	var direction := delta.normalized() if distance > 0.001 else actor.facing
	var lateral_share := absf(direction.x)
	var speed_rating := lerpf(
		float(actor.player.transition_speed),
		float(actor.player.lateral_speed), lateral_share * 0.65
	) / 100.0
	var fatigue_factor := LocomotionModel.fatigue_factor(actor.player)
	var maximum_speed := LocomotionModel.legacy_maximum_speed(
		actor.player, speed_rating, LocomotionModel.LEGACY_APPROACH_CEILING_MPS
	)
	var acceleration := lerpf(2.2, 6.8, float(actor.player.acceleration) / 100.0) \
		* fatigue_factor
	var alignment := 1.0
	if actor.facing.length_squared() > 0.001 and direction.length_squared() > 0.001:
		alignment = clampf((actor.facing.normalized().dot(direction) + 1.0) * 0.5, 0.0, 1.0)
	var turn_delay := lerpf(0.20, 0.02, alignment)
	var run_time := maxf(available_time - turn_delay, 0.0)
	var start_speed := maxf(actor.velocity.dot(direction), 0.0)
	var ending_speed := minf(start_speed + acceleration * run_time, maximum_speed)
	var capacity := (start_speed + ending_speed) * 0.5 * run_time
	## Approach distance is scored against this player's own preferred run-up
	## rather than a league-wide constant. Middles want a compact approach, tall
	## long-strided outsides want a full runway, and both are correct.
	var approach_profile := actor.player.system_fit(
		VolleyballPlayer.SYSTEM_FIT_APPROACH_DISTANCE
	)
	var tolerance_scale := actor.player.system_fit_tolerance_scale()
	var distance_evaluation := {}
	if approach_profile != null:
		distance_evaluation = approach_profile.evaluate(distance, tolerance_scale)
	var distance_fit := float(distance_evaluation.get("fit", 0.0))
	var in_system := bool(distance_evaluation.get("in_system", false))
	var system_bonus := float(distance_evaluation.get("bonus_multiplier", 1.0))
	var speed_fraction := ending_speed / maxf(maximum_speed, 0.1)
	var timing := float(actor.player.approach_timing) / 100.0
	var lateral_control := clampf(
		lerpf(1.0, float(actor.player.lateral_speed) / 100.0, lateral_share)
		* lerpf(0.72, 1.0, alignment), 0.0, 1.0
	)
	var runway_completion := 1.0 if distance <= 0.05 else clampf(capacity / distance, 0.0, 1.0)
	## Distance fit carries real weight now (0.19, up from a token 0.09) because
	## it is player-specific: missing your own mark is a genuine execution error.
	var quality := clampf(
		speed_fraction * 0.24 + timing * 0.22 + alignment * 0.15
		+ lateral_control * 0.12 + distance_fit * 0.19
		+ actor.balance * 0.08, 0.0, 1.0
	) * lerpf(0.62, 1.0, runway_completion)
	## Landing inside the tight rhythm band is a discrete reward on top of the
	## continuous curve, and it eases the shot-menu gates: being in system can be
	## the difference between having the full menu available and not.
	quality = clampf(quality * system_bonus, 0.0, 1.0)
	var power_threshold := POWER_ACCESS_QUALITY_IN_SYSTEM if in_system \
		else POWER_ACCESS_QUALITY_OUT_OF_SYSTEM
	var menu_threshold := FULL_MENU_QUALITY_IN_SYSTEM if in_system \
		else FULL_MENU_QUALITY_OUT_OF_SYSTEM
	return {
		"approach_distance_meters": distance,
		"ideal_approach_distance_meters": approach_profile.ideal_value \
			if approach_profile != null else 0.0,
		"approach_distance_tolerance_meters": float(
			distance_evaluation.get("tolerance", 0.0)
		),
		"approach_distance_deviation_meters": float(
			distance_evaluation.get("signed_deviation", 0.0)
		),
		"approach_distance_fit": distance_fit,
		"approach_in_system": in_system,
		"approach_undershot": bool(distance_evaluation.get("undershot", false)),
		"approach_overshot": bool(distance_evaluation.get("overshot", false)),
		"system_fit_bonus": system_bonus,
		"available_run_time_seconds": run_time,
		"approach_speed_mps": ending_speed,
		"maximum_approach_speed_mps": maximum_speed,
		"approach_speed_fraction": speed_fraction,
		"approach_alignment": alignment,
		"lateral_share": lateral_share,
		"lateral_control": lateral_control,
		"runway_completion": runway_completion,
		"runup_quality": quality,
		## A compromised approach reduces how much of the player's rated jump is
		## available; it does not erase their standing two-foot jump.
		"jump_multiplier": lerpf(0.90, 1.08, quality),
		"balance_multiplier": lerpf(0.58, 1.04, quality * lateral_control),
		"power_access": quality >= power_threshold \
			and speed_fraction >= POWER_ACCESS_SPEED_FRACTION \
			and lateral_control >= POWER_ACCESS_LATERAL_CONTROL,
		"full_shot_menu": quality >= menu_threshold \
			and lateral_control >= FULL_MENU_LATERAL_CONTROL,
	}


## Where a hitter starts their run-up for a ball at `target`.
##
## The depth offset is signed by side and must be: a hitter approaches the net
## from behind it, and "behind" is +y for the home side and -y for the opponent.
## Taking the home offset for an opponent would place their approach mark across
## the net, inside home territory.
## Where a hitter starts their run-up, and therefore how diagonally they arrive.
##
## Single source of truth. `rally_simulator.gd` carried a second derivation of
## this and the two disagreed in *sign*: this one sent `Left Pin` to
## `target.x + 0.07`, which is *inward* of the contact, so pins ran inside-out.
## The simulator's copy sent them outward. This one is what
## `prepare_for_attack()` calls, so inside-out is what the engine actually did --
## backwards from the sport, where an outside hitter starts wide and runs in.
##
## The lateral offset is now derived from an explicit **angle** rather than
## stated as a fixed distance, so that changing the run-up's depth cannot
## silently change its direction. The old ±0.07 against a 0.11 depth was about
## seventeen degrees, pointed the wrong way; a real outside approach is around
## thirty, pointed outward.
##
## This direction is load-bearing beyond appearance. `evaluate_takeoff()` reads
## it: `lateral_share` blends transition speed toward lateral speed, alignment
## drives the turn delay, and carried momentum only counts along it. A hitter's
## available swing is centred on it too.
const APPROACH_ANGLE_MIDDLE_DEGREES: float = 8.0
const APPROACH_ANGLE_PIN_DEGREES: float = 30.0
const APPROACH_DEPTH: float = 0.11
## Wide enough to begin outside the sideline, because that is where an outside
## hitter's approach actually begins. Holding them on court capped the angle at
## exactly the pins that need it most.
const APPROACH_START_MIN_X: float = -0.10
const APPROACH_START_MAX_X: float = 1.10
## How much of the hitter's current position survives, so a player out of
## position is not teleported across the court to draw a textbook run-up.
## Applied to the base rather than to the finished offset -- folding it over the
## sum shrank every textbook approach by 22% even for a hitter already standing
## in the right place, which was never the point.
const APPROACH_ROUTE_BLEND: float = 0.78


static func approach_start_position(
	target: Vector2,
	_lane: String = "",
	side: StringName = &"home",
	current_position: Variant = null,
	depth: float = APPROACH_DEPTH,
) -> Vector2:
	var pin_distance := absf(target.x - 0.50)
	var wideness := clampf(pin_distance / 0.38, 0.0, 1.0)
	var angle := lerpf(
		APPROACH_ANGLE_MIDDLE_DEGREES, APPROACH_ANGLE_PIN_DEGREES, wideness
	)
	var forward_meters := absf(depth) * CourtConstants.COURT_LENGTH_METERS
	var lateral_meters := forward_meters * tan(deg_to_rad(angle))
	var outward := signf(target.x - 0.50) * lateral_meters \
		/ CourtConstants.COURT_WIDTH_METERS
	var base_x := target.x
	if current_position is Vector2:
		base_x = lerpf(
			(current_position as Vector2).x, target.x, APPROACH_ROUTE_BLEND
		)
	var start_x := clampf(
		base_x + outward, APPROACH_START_MIN_X, APPROACH_START_MAX_X
	)
	if side == &"opponent":
		return Vector2(start_x, clampf(target.y - depth, 0.04, 0.46))
	return Vector2(start_x, clampf(target.y + depth, 0.54, 0.96))


## The families this hitter can execute cleanly off this approach. A family is
## available exactly when it carries no deficit, so this and
## `attack_family_deficit()` can never disagree about where the line is.
static func available_attack_families(
	player: VolleyballPlayer,
	profile: Dictionary,
	arrival_margin: float,
) -> Array[String]:
	var actions: Array[String] = []
	if player == null:
		return ["controlled_roll"]
	for family in ATTACK_FAMILY_REQUIREMENTS:
		if attack_family_deficit(player, profile, arrival_margin, str(family)) <= 0.0:
			actions.append(str(family))
	return actions


## The family a named hit type belongs to. Unknown names fall back to the roll
## shot, which demands nothing and therefore never invents a penalty.
static func attack_family_for_hit_type(hit_type: String) -> String:
	return str(HIT_TYPE_FAMILY.get(hit_type, "controlled_roll"))


## How far outside this hitter's clean capability an attempt at `family` sits,
## as a sum of normalised shortfalls. Zero means they can execute it; larger
## means they are reaching further past what the approach gave them.
##
## This never says no. It is the magnitude a caller feeds to
## `AttemptJudgment.backs_off()` and, if the hitter swings anyway, to the
## quality penalty the attempt carries.
static func attack_family_deficit(
	player: VolleyballPlayer,
	profile: Dictionary,
	arrival_margin: float,
	family: String,
) -> float:
	if player == null:
		return 0.0
	var requirement: Dictionary = ATTACK_FAMILY_REQUIREMENTS.get(family, {})
	if requirement.is_empty():
		return 0.0
	var deficit := 0.0
	if requirement.has("rating"):
		deficit += maxf(
			float(requirement["rating_floor"])
			- float(player.get(str(requirement["rating"]))),
			0.0,
		) / 100.0
	if requirement.has("lateral_control"):
		deficit += maxf(
			float(requirement["lateral_control"])
			- float(profile.get("lateral_control", 0.0)), 0.0
		)
	if requirement.has("runup_quality"):
		deficit += maxf(
			float(requirement["runup_quality"])
			- float(profile.get("runup_quality", 0.0)), 0.0
		)
	if requirement.has("arrival_margin"):
		deficit += maxf(
			float(requirement["arrival_margin"]) - arrival_margin, 0.0
		) / ARRIVAL_DEFICIT_SCALE
	if bool(requirement.get("power_access", false)):
		deficit += _power_access_deficit(profile)
	return deficit


## The run-up shortfall behind a failed `power_access`. The profile reports the
## verdict as a single boolean; an overreach needs to know by how much.
static func _power_access_deficit(profile: Dictionary) -> float:
	var quality_floor := POWER_ACCESS_QUALITY_IN_SYSTEM \
		if bool(profile.get("approach_in_system", false)) \
		else POWER_ACCESS_QUALITY_OUT_OF_SYSTEM
	return maxf(
		quality_floor - float(profile.get("runup_quality", 0.0)), 0.0
	) + maxf(
		POWER_ACCESS_SPEED_FRACTION
		- float(profile.get("approach_speed_fraction", 0.0)), 0.0
	) + maxf(
		POWER_ACCESS_LATERAL_CONTROL
		- float(profile.get("lateral_control", 0.0)), 0.0
	)


static func _reading_quality(player: VolleyballPlayer) -> float:
	return clampf((
		float(player.anticipation) * 0.38
		+ float(player.court_vision) * 0.32
		+ float(player.decision_making) * 0.20
		+ float(player.composure) * 0.10
	) / 100.0, 0.0, 1.0)
