extends SceneTree

## A4 — where each body's destination comes from, and how often two sources
## want the same body in one event.
##
##     godot --headless --path . --script res://tools/audit_target_sources.gd
##
## `tactical_court._authoritative_phase_path` reads four publishers in a fixed
## priority order and takes the first that answers. That order only matters when
## more than one answers, and nothing has ever counted how often that happens --
## so this counts it, per event and per body, and reports which source wins and
## which is silently discarded.
##
## A contested body is not automatically a defect: the contract says a site's own
## stated leg beats `_add_event`'s reconstruction on purpose. What the contract
## does not say is how often the loser was a *different journey* rather than the
## same one restated, so the divergence between the winner's and loser's
## endpoints is measured too.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 61000
const SEED_COUNT: int = 120

## `_authoritative_phase_path`'s own order, highest first.
const PRIORITY: Array[String] = [
	"movement_path", "phase_intent", "phase_hold", "staged_next",
]


func _initialize() -> void:
	var supplied := {}
	var winners := {}
	var contested := 0
	var uncontested := 0
	var bodies := 0
	var divergences: Array[float] = []
	var by_action := {}

	for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = (seed_value % 2) == 0
		var result: Resource = manager.resolve_active_rally(seed_value)
		if result == null:
			continue
		for event in result.events:
			if event == null:
				continue
			var sources := _sources_on(event)
			for player_id in sources:
				bodies += 1
				var offered: Dictionary = sources[player_id]
				for name in offered:
					supplied[name] = int(supplied.get(name, 0)) + 1
				if offered.size() <= 1:
					uncontested += 1
					continue
				contested += 1
				var action := str(RallyEventScript.EventType.keys()[
					int(event.event_type)
				])
				var key := "%s|%s" % [action, _ranked(offered).slice(0, 2)]
				by_action[key] = int(by_action.get(key, 0)) + 1
				var ranked := _ranked(offered)
				winners[ranked[0]] = int(winners.get(ranked[0], 0)) + 1
				## How different was the answer that lost?
				var best: RallyMovementPath = offered[ranked[0]]
				var next: RallyMovementPath = offered[ranked[1]]
				divergences.append(RallyKinematics.court_distance_meters(
					best.landing_position(), next.landing_position()
				))

	print("=== A4 target sources, %d rallies ===" % SEED_COUNT)
	print("body-events examined|%d" % bodies)
	print("single source|%d" % uncontested)
	print("two or more sources|%d" % contested)
	print("--- how often each publisher answers at all")
	for name in PRIORITY:
		print("  %s|%d" % [name, int(supplied.get(name, 0))])
	print("--- which publisher wins a contest")
	for name in PRIORITY:
		if winners.has(name):
			print("  %s|%d" % [name, int(winners[name])])
	divergences.sort()
	if not divergences.is_empty():
		print("--- distance between the winning and losing endpoint, metres")
		print("  same_answer_under_1cm|%d of %d" % [
			divergences.filter(func(d): return d < 0.01).size(),
			divergences.size(),
		])
		print("  median|%.3f" % divergences[divergences.size() / 2])
		print("  p90|%.3f" % divergences[int(divergences.size() * 0.9)])
		print("  worst|%.3f" % divergences[divergences.size() - 1])
	print("--- contested pairs by action, top 10")
	var keys: Array = by_action.keys()
	keys.sort_custom(func(a, b): return int(by_action[a]) > int(by_action[b]))
	for index in range(mini(10, keys.size())):
		print("  %s|%d" % [str(keys[index]), int(by_action[keys[index]])])
	quit()


## Every publisher that offers this body a journey on this event.
func _sources_on(event: Resource) -> Dictionary:
	var found := {}
	var metadata: Dictionary = event.metadata
	var actor_id := int(event.actor_id)
	var own := metadata.get("movement_path", null) as RallyMovementPath
	if actor_id >= 0 and own != null and own.is_valid():
		_note(found, actor_id, "movement_path", own)
	var staged := int(metadata.get("staged_next_actor_id", -1))
	var staged_path := metadata.get("staged_next_path", null) as RallyMovementPath
	if staged >= 0 and staged_path != null and staged_path.is_valid():
		_note(found, staged, "staged_next", staged_path)
	for side in ["home", "opponent"]:
		var intents: Variant = metadata.get("%s_phase_intents" % side, {})
		if intents is Dictionary:
			for raw_id in Dictionary(intents):
				var entry: Variant = Dictionary(intents)[raw_id]
				if not (entry is Dictionary):
					continue
				var path := entry.get("path", null) as RallyMovementPath
				if path != null and path.is_valid():
					_note(found, int(raw_id), "phase_intent", path)
		var holds: Variant = metadata.get("%s_phase_hold_paths" % side, {})
		if holds is Dictionary:
			for raw_id in Dictionary(holds):
				var held := Dictionary(holds)[raw_id] as RallyMovementPath
				if held != null and held.is_valid():
					_note(found, int(raw_id), "phase_hold", held)
	return found


func _note(
	found: Dictionary, player_id: int, source: String, path: RallyMovementPath
) -> void:
	if not found.has(player_id):
		found[player_id] = {}
	Dictionary(found[player_id])[source] = path


func _ranked(offered: Dictionary) -> Array:
	var ordered: Array = []
	for name in PRIORITY:
		if offered.has(name):
			ordered.append(name)
	return ordered
