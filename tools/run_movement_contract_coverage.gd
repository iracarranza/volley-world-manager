extends SceneTree

## What the movement contract actually says, per contact family.
##
##     godot --headless --path . --script res://tools/run_movement_contract_coverage.gd
##
## The handoff's architectural gate asks whether the existing metadata defines
## every physical player journey unambiguously enough that playback only renders
## it. That question is answered by which facts are on the record and which are
## missing, so this counts them rather than arguing about them.
##
## Nine facts describe one leg: where it started, where it ended, how long it
## took, how long there was, when the body could set off, when it did, what speed
## it carried in, where the corner was, and when the contact happened. A family
## with all nine needs nothing inferred. A family missing one has exactly one
## thing playback must guess at, and the column says which.
##
## Reports off-ball phase entries on the same terms, split by whether their
## intent carries `traversal_seconds`.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 61000
const SEED_COUNT: int = 100

## Ordered so the printed row reads start, end, duration, budget, departure.
const LEG_KEYS := [
	"movement_start", "movement_target", "movement_duration",
	"movement_available_seconds", "movement_ready_seconds",
	"movement_delay_seconds", "movement_entry_velocity",
	"body_contact_position", "actor_leg_start", "physical_time",
]


func _initialize() -> void:
	var families := {}
	var offball := {"timed": 0, "untimed": 0, "no_intent": 0}
	for serving_home in [false, true]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + SEED_COUNT):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var result: Resource = manager.resolve_active_rally(seed_value)
			if result == null:
				continue
			for raw_event in result.events:
				var event: Resource = raw_event
				if event == null or int(event.actor_id) < 0:
					continue
				var meta: Dictionary = event.metadata
				var name := str(
					RallyEventScript.EventType.keys()[int(event.event_type)]
				)
				var bucket: Dictionary = families.get(name, {"n": 0})
				bucket["n"] = int(bucket.n) + 1
				for key in LEG_KEYS:
					if meta.has(key):
						bucket[key] = int(bucket.get(key, 0)) + 1
				families[name] = bucket
				for side in ["home", "opponent"]:
					var targets: Dictionary = meta.get(
						"%s_phase_targets" % side, {}
					)
					var intents: Dictionary = meta.get(
						"%s_phase_intents" % side, {}
					)
					for raw_player_id in targets:
						var raw_intent = intents.get(raw_player_id, null)
						if raw_intent == null:
							offball["no_intent"] = int(offball.no_intent) + 1
						elif Dictionary(raw_intent).has("traversal_seconds"):
							offball["timed"] = int(offball.timed) + 1
						else:
							offball["untimed"] = int(offball.untimed) + 1
	print("contact family|n|" + "|".join(LEG_KEYS))
	var keys: Array = families.keys()
	keys.sort()
	for key in keys:
		var b: Dictionary = families[key]
		var cells: Array[String] = [key, str(int(b.n))]
		for leg_key in LEG_KEYS:
			cells.append(str(int(b.get(leg_key, 0))))
		print("|".join(cells))
	print("--- off-ball phase entries")
	print("with traversal_seconds|%d" % int(offball.timed))
	print("intent without traversal_seconds|%d" % int(offball.untimed))
	print("target with no intent entry at all|%d" % int(offball.no_intent))
	quit()
