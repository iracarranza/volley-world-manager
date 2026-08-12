extends SceneTree

## Which beaten blocks were actually *funnels*?
##
##     godot --headless --path . --script res://tools/run_funnel_band_probe.gd
##
## `_contest_block` has four bands and `_geometric_promotion` has three words.
## Every would-be funnel becomes a `miss`, so a wall that squeezed a hitter into
## the one lane the defence was standing in is recorded identically to one that
## was beaten by three metres.
##
## The promotion is the right place to fix it -- the geometry is what knows
## where the ball went past -- but the threshold has to be set **inside** the
## distribution it cuts. This measures that distribution first: how far past the
## hands an in-play swing actually went, in metres, split by how it beat them.
##
## The failure this avoids is the recurring one: a threshold outside its own
## distribution does nothing, and does nothing silently.
func _initialize() -> void:
	var Events := load("res://scripts/models/rally_event.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	manager.seed_vertical_slice_data()

	var by_reason := {}
	var gaps: Array[float] = []
	var in_play := 0
	var attacks := 0
	for rally_seed in range(72000, 72400):
		manager.match_state.serving_home = (rally_seed % 2) == 0
		var result: Resource = manager.resolve_active_rally(rally_seed)
		if result == null:
			continue
		for event in result.events:
			if int(event.event_type) != Events.EventType.BLOCK:
				continue
			attacks += 1
			## Only the blocks the promotion currently calls `miss` -- the bucket
			## a funnel would have to come out of.
			if str(event.metadata.get("outcome", "")) != "miss":
				continue
			var reason := str(event.metadata.get("block_miss_reason", ""))
			if not event.metadata.has("block_edge_miss_meters"):
				continue
			in_play += 1
			## How far *outside* the nearest hand the ball crossed the net, as a
			## negative number closest to zero for the narrowest escape. A swing
			## that had to squeeze past the edge was shaped by the wall; one that
			## crossed two metres outside it was not.
			var value := absf(float(event.metadata["block_edge_miss_meters"]))
			gaps.append(value)
			var row: Array = by_reason.get(reason, [])
			row.append(value)
			by_reason[reason] = row

	print("%d block events, %d beaten with a published edge miss\n"
		% [attacks, in_play])
	print("%-20s %7s %8s %8s %8s %8s %8s" % [
		"beaten", "count", "p10", "p25", "median", "p75", "p90"])
	var keys := by_reason.keys()
	keys.sort()
	for key in keys:
		_report(key if key != "" else "(none)", by_reason[key])
	_report("ALL", gaps)

	## The number a threshold has to sit inside. A funnel is the *narrow* end of
	## this: the ball had to squeeze past the hands rather than sail past them.
	var sorted := gaps.duplicate()
	sorted.sort()
	if sorted.is_empty():
		manager.free()
		quit()
		return
	## Only the blocks with a lateral escape can be funnels at all: a ball hit
	## over the top never went past an edge, and its edge miss is 0.00 for every
	## one of them. Cutting the whole beaten population would put the threshold
	## in a spike at zero and call every over-the-top swing a funnel.
	var lateral: Array[float] = []
	for key in ["around", "over and around"]:
		for value in Array(by_reason.get(key, [])):
			lateral.append(float(value))
	lateral.sort()
	print("\n%d of %d beaten blocks went past an edge at all." % [
		lateral.size(), gaps.size()])
	if lateral.is_empty():
		manager.free()
		quit()
		return
	## The anchor worth testing: a blocker's own half-width. A ball that crossed
	## closer to the hand than the hand is wide had to be squeezed past it, which
	## is a physical statement rather than a number chosen to hit a rate.
	for cut in [0.20, 0.30, 0.45, 0.60]:
		var under := 0
		for value in lateral:
			if value <= cut:
				under += 1
		print("A cut at %.2f m: %d funnels, %.1f%% of lateral escapes, %.1f%% of all blocks."
			% [cut, under, float(under) / float(lateral.size()) * 100.0,
				float(under) / maxf(float(attacks), 1.0) * 100.0])
	manager.free()
	quit()


func _report(label: String, values: Array) -> void:
	if values.is_empty():
		return
	var sorted := values.duplicate()
	sorted.sort()
	var count := sorted.size()
	print("%-20s %7d %8.2f %8.2f %8.2f %8.2f %8.2f" % [
		label, count,
		float(sorted[int(float(count) * 0.10)]),
		float(sorted[int(float(count) * 0.25)]),
		float(sorted[count / 2]),
		float(sorted[mini(int(float(count) * 0.75), count - 1)]),
		float(sorted[mini(int(float(count) * 0.90), count - 1)]),
	])
