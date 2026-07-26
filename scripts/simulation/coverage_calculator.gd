class_name CoverageCalculator
extends RefCounted

const COURT_WIDTH_METERS: float = 9.0
const COURT_LENGTH_METERS: float = 18.0


static func court_distance_meters(from: Vector2, to: Vector2) -> float:
	var delta := to - from
	return Vector2(
		delta.x * COURT_WIDTH_METERS,
		delta.y * COURT_LENGTH_METERS,
	).length()


static func evaluate_arrival(
	player: VolleyballPlayer,
	zone: Resource,
	landing_point: Vector2,
	ball_time_seconds: float,
	contact_skill: String,
) -> Dictionary:
	if player == null or zone == null or not bool(zone.enabled):
		return {"reachable": false, "claim_score": -1000.0}
	var distance := court_distance_meters(zone.center, landing_point)
	var anticipation := float(player.anticipation) / 100.0
	var reaction_delay := lerpf(0.56, 0.18, anticipation)
	var available_time := maxf(ball_time_seconds - reaction_delay, 0.0)
	var speed_rating := float(player.lateral_speed) / 100.0
	var acceleration_rating := float(player.acceleration) / 100.0
	var fatigue_multiplier := 1.0 - player.fatigue * 0.30
	var mass_multiplier := lerpf(1.06, 0.90, clampf(
		(player.mass_kg - 55.0) / 60.0, 0.0, 1.0
	))
	var movement_speed := lerpf(1.35, 4.65, speed_rating) \
		* fatigue_multiplier * mass_multiplier
	var acceleration_factor := lerpf(0.62, 1.0, acceleration_rating)
	var travel_distance := movement_speed * available_time * acceleration_factor
	var base_reach := _base_reach_meters(player, contact_skill)
	var physical_reach := base_reach + travel_distance
	var assigned_reach := float(zone.radius_meters)
	var reachable := distance <= minf(physical_reach, assigned_reach)
	var arrival_margin := physical_reach - distance
	var zone_margin := assigned_reach - distance
	var edge_ratio := distance / maxf(assigned_reach, 0.1)
	var skill_rating := float(player.get(contact_skill)) / 100.0
	var claim_score := float(zone.priority) * 0.24 \
		+ clampf(arrival_margin / 3.0, -0.5, 0.5) * 0.34 \
		+ clampf(zone_margin / 3.0, -0.5, 0.5) * 0.16 \
		+ anticipation * 0.14 + skill_rating * 0.12
	return {
		"reachable": reachable,
		"distance_meters": distance,
		"reaction_delay": reaction_delay,
		"available_time": available_time,
		"physical_reach_meters": physical_reach,
		"assigned_reach_meters": assigned_reach,
		"arrival_margin": arrival_margin,
		"edge_ratio": edge_ratio,
		"claim_score": claim_score,
	}


static func choose_claimant(
	players: Array[VolleyballPlayer],
	zones: Dictionary,
	landing_point: Vector2,
	ball_time_seconds: float,
	contact_skill: String,
) -> Dictionary:
	var best := {"player": null, "arrival": {}, "support_count": 0}
	var best_score := -1000.0
	var reachable_evaluations: Array[Dictionary] = []
	for player in players:
		var zone: Resource = zones.get(player.id) as Resource
		var arrival := evaluate_arrival(
			player, zone, landing_point, ball_time_seconds, contact_skill
		)
		if not bool(arrival.get("reachable", false)):
			continue
		reachable_evaluations.append({"player": player, "arrival": arrival})
		var score := float(arrival.get("claim_score", -1000.0))
		if score > best_score:
			best_score = score
			best = {"player": player, "arrival": arrival, "support_count": 0}
	if best.player == null:
		return best
	var support_count := 0
	for evaluation in reachable_evaluations:
		var support_player := evaluation.player as VolleyballPlayer
		if support_player.id != (best.player as VolleyballPlayer).id:
			support_count += 1
	best.support_count = support_count
	return best


static func reception_body_penalty(
	player: VolleyballPlayer,
	arrival: Dictionary,
	ball_force: float,
) -> float:
	if player == null or arrival.is_empty():
		return 0.0
	var edge_ratio := float(arrival.get("edge_ratio", 0.0))
	var edge_exposure := clampf((edge_ratio - 0.52) / 0.48, 0.0, 1.0)
	var balance := float(player.reception_balance) / 100.0
	var stability := float(player.reception_stability) / 100.0
	var movement_penalty := edge_exposure * (1.0 - balance) * 0.20
	var pace_exposure := clampf((ball_force - 0.48) / 0.52, 0.0, 1.0)
	var pace_penalty := pace_exposure * (1.0 - stability) * 0.18
	return movement_penalty + pace_penalty


static func _base_reach_meters(player: VolleyballPlayer, contact_skill: String) -> float:
	var control := float(player.ball_control) / 100.0
	var wingspan_factor := clampf(player.wingspan_cm / 200.0, 0.78, 1.18)
	var role_bonus := 0.12 if player.position_role == "Libero" else 0.0
	var defense_bonus := 0.08 if contact_skill == "reception" else 0.0
	return 0.55 + wingspan_factor * 0.42 + control * 0.25 \
		+ role_bonus + defense_bonus
