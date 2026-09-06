extends SceneTree

## Wall-clock cost of resolving one rally, for the contract's performance control.
##
##     godot --headless --path . --script res://tools/probe_resolve_cost.gd
##
## `AUTHORITATIVE_RALLY_MOVEMENT.md` records 62.8 ms/rally at `8bb09ca` and no
## tool in the repo produces that number, so re-measuring it meant re-deriving
## the instrument. This one times `resolve_active_rally` alone -- world setup and
## the manager's own construction are outside the clock, because they are paid
## once per session and the figure is per rally.
##
## Report the median, not the mean. A rally that goes twenty contacts costs
## several times one that ends on an ace, so the mean tracks the outcome mix and
## moves when balance moves; the median tracks the resolver.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")

const FIRST_SEED: int = 61000
const SEED_COUNT: int = 200
## Thrown away before timing starts -- the first resolves pay for lazy statics.
const WARMUP: int = 10


func _initialize() -> void:
	var samples: Array[float] = []
	var contacts: Array[int] = []
	for index in range(-WARMUP, SEED_COUNT):
		var seed_value := FIRST_SEED + maxi(index, 0)
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = (seed_value % 2) == 0
		var started := Time.get_ticks_usec()
		var result: Resource = manager.resolve_active_rally(seed_value)
		var elapsed := float(Time.get_ticks_usec() - started) / 1000.0
		if index < 0 or result == null:
			continue
		samples.append(elapsed)
		contacts.append(result.events.size())

	samples.sort()
	var total := 0.0
	for value: float in samples:
		total += value
	var contact_total := 0
	for count: int in contacts:
		contact_total += count

	print("=== resolve cost, %d rallies, %d warm-up discarded ===" % [
		samples.size(), WARMUP,
	])
	print("median_ms|%.1f" % samples[samples.size() / 2])
	print("mean_ms|%.1f" % (total / float(samples.size())))
	print("p10_ms|%.1f" % samples[int(samples.size() * 0.1)])
	print("p90_ms|%.1f" % samples[int(samples.size() * 0.9)])
	print("worst_ms|%.1f" % samples[samples.size() - 1])
	print("mean_events_per_rally|%.2f" % (
		float(contact_total) / float(contacts.size())
	))
	quit()
