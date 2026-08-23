extends SceneTree

## `PLATFORM_CONTACT.md` §4b's second traced defect, measured before it is
## repaired.
##
##     godot --headless --path . --script res://tools/run_continuation_dig_arrival.gd
##
## > **The continuation dig passes `arrival = {}`.** Empty, so `reach_margin`
## > defaults to 0.0 and `stretched` computes `(0.25 − 0.0) / 0.85 = 0.294` — a
## > 29% stretch fabricated on every continuation dig.
##
## The design page traced it and stopped there. It is not a design question: the
## arrival exists in scope at that call site and is already read twice on the two
## lines above it. So this measures what the fabrication costs, using the event's
## own published `reach_margin_meters` -- which is the real figure, stamped from
## the same `cont_defense` the resolver declined to pass along.
##
## Run before and after the repair. The `spoil` column is the one that matters:
## it is what the apex band and the drift are both built on.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 23000
const RALLIES_PER_SERVER: int = 300

## `_dig_pass_result`'s own expression, reproduced here so the fabricated and the
## real value can be compared without changing the resolver to report both.
const STRETCH_PIVOT: float = 0.25
const STRETCH_SPAN: float = 0.85


func _initialize() -> void:
	var rows := _sweep()
	_report(rows)
	quit()


## Continuation digs, identified by the caption their site alone writes. The
## alternative -- inferring from exchange number -- would also catch the home
## floor dig, which passes a real arrival and is not the population in question.
func _sweep() -> Array:
	var rows: Array = []
	for serving_home in [true, false]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES_PER_SERVER):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			if rally == null:
				manager.free()
				continue
			for entry in rally.events:
				var event := entry as RallyEvent
				if event == null \
						or event.event_type != RallyEventScript.EventType.DIG:
					continue
				if not event.headline.begins_with("Opponent dig"):
					continue
				## A *resolved* pass, not merely a published key. `pass_apex_meters`
				## defaults to 0.0 when the dig failed and `cont_dig_pass` stayed
				## empty, so filtering on `has("pass_spoil")` alone let 0.0-spoil
				## non-passes into the population -- which showed up immediately as
				## a median spoil and median apex of exactly zero.
				if float(event.metadata.get("pass_apex_meters", 0.0)) <= 0.0:
					continue
				rows.append({
					"margin": float(event.metadata.get(
						"reach_margin_meters", 0.0
					)),
					"spoil": float(event.metadata.get("pass_spoil", 0.0)),
					"apex": float(event.metadata.get("pass_apex_meters", 0.0)),
					"error": float(event.metadata.get(
						"target_error_meters", 0.0
					)),
				})
			manager.free()
	return rows


func _stretch(margin: float) -> float:
	return clampf((STRETCH_PIVOT - margin) / STRETCH_SPAN, 0.0, 1.0)


func _stats(values: Array) -> Dictionary:
	if values.is_empty():
		return {"n": 0, "min": 0.0, "p50": 0.0, "max": 0.0, "mean": 0.0}
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value in sorted:
		total += float(value)
	return {
		"n": sorted.size(),
		"min": float(sorted[0]),
		"p50": float(sorted[sorted.size() / 2]),
		"max": float(sorted[sorted.size() - 1]),
		"mean": total / sorted.size(),
	}


func _report(rows: Array) -> void:
	print("=".repeat(78))
	print("CONTINUATION DIGS -- the arrival that was in scope and not passed")
	print("=".repeat(78))
	print("  %d continuation digs with a resolved pass, over %d rallies.\n" % [
		rows.size(), RALLIES_PER_SERVER * 2,
	])
	if rows.is_empty():
		print("  None in this population; nothing to say.")
		return
	var margins: Array = []
	var real_stretch: Array = []
	var spoils: Array = []
	var apexes: Array = []
	var errors: Array = []
	for row in rows:
		margins.append(float(row["margin"]))
		real_stretch.append(_stretch(float(row["margin"])))
		spoils.append(float(row["spoil"]))
		apexes.append(float(row["apex"]))
		errors.append(float(row["error"]))
	print("  %-30s %-9s %-9s %-9s %-9s" % [
		"quantity", "min", "p50", "max", "mean",
	])
	for entry in [
		["published reach margin m", margins],
		["stretch the margin implies", real_stretch],
		["spoil, as resolved", spoils],
		["pass apex m", apexes],
		["destination error m", errors],
	]:
		var stats := _stats(entry[1])
		print("  %-30s %-9.3f %-9.3f %-9.3f %-9.3f" % [
			str(entry[0]), stats.min, stats.p50, stats.max, stats.mean,
		])
	print("")
	print("  Fabricated stretch, from `arrival = {}`: %.4f on every one of them." % [
		_stretch(0.0),
	])
	var implied := _stats(real_stretch)
	print("  Implied stretch, from the margin the event publishes: p50 %.4f." % [
		implied.p50,
	])
	print("")
	var above := 0
	var below := 0
	for value in real_stretch:
		if float(value) > _stretch(0.0) + 0.0001:
			above += 1
		elif float(value) < _stretch(0.0) - 0.0001:
			below += 1
	print("  %d of %d are more stretched than the fabrication says, %d less." % [
		above, rows.size(), below,
	])
	print("")
	print("  `stretched` carries weight 0.20 in `spoil`, so the error in spoil is")
	print("  0.20 x the stretch error. That is small per contact and it is not the")
	print("  point: the fabricated value is *constant*, so on this path the term")
	print("  that exists to make a scrambling dig worse than a planted one is")
	print("  making every dig identically mediocre. A term that cannot vary is")
	print("  not a weak term, it is an absent one wearing a weight.")
