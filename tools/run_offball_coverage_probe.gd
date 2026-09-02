extends SceneTree

## How many of the twelve the resolver has an opinion about, per drawn flight.
##
##     godot --headless --path . --script res://tools/run_offball_coverage_probe.gd
##
## `docs/design/OFF_BALL_MOVEMENT.md` measures this per *flight* rather than per
## event, for the reason that document records: a target on the RECEPTION event
## moves people during the **serve's** flight, so counting publication per event
## reports a clean result for a dirty system.
##
## The number matters now because it is the same number as the cheat step.
## `match_screen._apply_cheat_steps` hands an invented destination to every voli
## the plan does not already name, so *twelve minus this* is exactly the
## population playback is guessing for -- 1,194 legs of 1,507 and two thirds of
## drawn travel, at `6ae238e`.
##
## Named = in a phase map, the contact actor, or a staged next actor. Nothing
## here reads the screen; it is the record's own coverage of its own court.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 61000
const SEED_COUNT: int = 200


func _initialize() -> void:
	var by_leg := {}
	var unnamed_by_role := {}
	var omitted_by_intent_gap := {}
	var flights := 0
	var named_total := 0
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			var roles: Dictionary = result.player_physical_profiles
			var on_court := {}
			for map_name in ["initial_home_positions", "initial_opponent_positions"]:
				for raw_id in Dictionary(result.get(map_name)):
					on_court[int(raw_id)] = str(map_name).begins_with("initial_home")
			var events: Array = result.events
			for index in range(events.size() - 1):
				var event: Resource = events[index]
				var next_contact: Resource = events[index + 1]
				if event == null or next_contact == null:
					continue
				## The window playback would skip, and therefore not a drawn
				## flight at all.
				var window := float(next_contact.metadata.get("physical_time", 0.0)) \
					- float(event.metadata.get("physical_time", 0.0))
				if window <= 0.0:
					continue
				var named := {}
				for side in ["home", "opponent"]:
					for raw_id in Dictionary(next_contact.metadata.get(
						"%s_phase_targets" % side, {}
					)):
						named[int(raw_id)] = true
				if int(next_contact.actor_id) >= 0:
					named[int(next_contact.actor_id)] = true
				for source in [event, next_contact]:
					var staged := int(source.metadata.get(
						"staged_next_actor_id", -1
					))
					if staged >= 0:
						named[staged] = true
				var key := "%s->%s" % [
					RallyEventScript.EventType.keys()[int(event.event_type)],
					RallyEventScript.EventType.keys()[int(next_contact.event_type)],
				]
				var bucket: Dictionary = by_leg.get(key, {
					"flights": 0, "named": 0, "home_named": 0, "opp_named": 0,
				})
				bucket["flights"] = int(bucket.flights) + 1
				bucket["named"] = int(bucket.named) + named.size()
				for raw_id in named:
					if bool(on_court.get(int(raw_id), false)):
						bucket["home_named"] = int(bucket.home_named) + 1
					else:
						bucket["opp_named"] = int(bucket.opp_named) + 1
				by_leg[key] = bucket
				flights += 1
				named_total += named.size()
				## Which side is being left out, because the answer differs and
				## the fix is a different map for each.
				var home_missing := 0
				var opp_missing := 0
				for raw_id in on_court:
					if named.has(int(raw_id)):
						continue
					if bool(on_court[raw_id]):
						home_missing += 1
					else:
						opp_missing += 1
				## Which *role* is being left out, because "2.98 of six" is not
				## actionable and "the libero and both middles" is.
				for raw_id in on_court:
					if named.has(int(raw_id)):
						continue
					var code := str(Dictionary(
						roles.get(int(raw_id), {})
					).get("position_code", "?"))
					var role_key := "%s|%s" % [key, code]
					unnamed_by_role[role_key] = int(
						unnamed_by_role.get(role_key, 0)
					) + 1
				var gap: Dictionary = omitted_by_intent_gap.get(key, {
					"home": 0, "opponent": 0,
				})
				gap["home"] = int(gap.home) + home_missing
				gap["opponent"] = int(gap.opponent) + opp_missing
				omitted_by_intent_gap[key] = gap
	print("flight|flights|mean_named_of_12|mean_home_of_6|mean_opponent_of_6"
		+ "|mean_home_unnamed|mean_opponent_unnamed")
	var keys: Array = by_leg.keys()
	keys.sort()
	for key in keys:
		var b: Dictionary = by_leg[key]
		var n := maxf(float(b.flights), 1.0)
		var gap: Dictionary = omitted_by_intent_gap[key]
		print("%s|%d|%.2f|%.2f|%.2f|%.2f|%.2f" % [
			key, int(b.flights), float(b.named) / n,
			float(b.home_named) / n, float(b.opp_named) / n,
			float(gap.home) / n, float(gap.opponent) / n,
		])
	print("--- unnamed volis by flight and position, per flight")
	print("flight|position|unnamed_per_flight")
	var role_keys: Array = unnamed_by_role.keys()
	role_keys.sort()
	for role_key in role_keys:
		var parts: PackedStringArray = str(role_key).split("|")
		var flight_count := maxf(float(
			Dictionary(by_leg.get(parts[0], {})).get("flights", 1)
		), 1.0)
		var per := float(unnamed_by_role[role_key]) / flight_count
		if per < 0.25:
			continue
		print("%s|%s|%.2f" % [parts[0], parts[1], per])
	print("--- all drawn flights")
	print("flights|%d" % flights)
	print("mean_named_of_12|%.2f" % (float(named_total) / maxf(float(flights), 1.0)))
	quit()
