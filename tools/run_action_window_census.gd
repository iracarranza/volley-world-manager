extends SceneTree

## M7 / C0 -- for each leg of a rally, why is every voli moving or not moving?
##
##     godot --headless --path . \
##       --script res://tools/run_action_window_census.gd
##
## The packet's C0 is done "when the implementation agent can state, for each
## canonical leg, why every on-court player is or is not moving". That is twelve
## volis per contact, and the honest way to answer it is to count how many of
## them the resolver actually said anything about.
##
## Three states per voli per leg, and they are not the same finding:
##
##   **published**  the resolver put this voli in `home_phase_targets` or
##                  `opponent_phase_targets`. Simulation decided where they went.
##
##   **contacting**  this voli is the actor. Their movement is the event.
##
##   **no leg**    this contact has nothing before it, so there is no interval
##                 for anybody to have moved in. Only the serve, and only ever
##                 the serve: playback draws a leg as `event -> next_contact`
##                 and reads its targets off `next_contact`, so a rally's first
##                 contact has no preceding flight to draw. The resolver knows
##                 this -- `_receive_formation_map`'s own note records measuring
##                 400 serves of 400 with no preceding flight -- and publishes
##                 the serve-flight movement of *both* sides on the RECEPTION
##                 event instead, which is where it can be drawn.
##
##   **silent**     nothing was published and they did not touch the ball.
##                  `tactical_court._support_target_for_side` then invents a
##                  target for them from their base position and the action
##                  point -- which is presentation authoring movement the
##                  resolver never decided, the thing `01_TARGET_AUTHORITY_STATE`
##                  section 9 forbids in as many words.
##
## **The `no leg` row is a correction to this file's own first headline.** It
## originally counted the serve's other eleven volis as silent and reported
## 45.9% of voli-legs as presentation's invention. They are not silent: they are
## published on the reception, all twelve of them, because that is the event the
## leg belongs to. Scoring them as a gap measured a leg that does not exist --
## the same shape of error as reading a threshold against the wrong distribution,
## committed by the instrument built to find those.
##
## And one thing that is missing for *every* published voli: **when**. The maps
## publish where a voli got to and how much of the journey they covered. They do
## not publish how long the journey took, so a voli who arrived in 0.3 s of a
## 1.1 s window is indistinguishable from one who took the whole window, and
## playback interpolates them identically. That is C6's defect stated as a
## missing field rather than as a drawing complaint.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 73000
const RALLIES_PER_SERVER: int = 150

## The twelve on court, six a side.
const ON_COURT: int = 12

const CONTACT_TYPES: Array[int] = [
	RallyEventScript.EventType.SERVE,
	RallyEventScript.EventType.RECEPTION,
	RallyEventScript.EventType.SET,
	RallyEventScript.EventType.ATTACK,
	RallyEventScript.EventType.BLOCK,
	RallyEventScript.EventType.DIG,
	RallyEventScript.EventType.ATTACK_COVERAGE,
]


func _initialize() -> void:
	var census := _run()
	_print(census)
	quit(0)


func _run() -> Dictionary:
	var census := {"rallies": 0, "legs": {}}
	for serving_home in [true, false]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES_PER_SERVER):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			if rally != null:
				census.rallies += 1
				_scan(rally, census)
			manager.free()
	return census


func _leg(census: Dictionary, name: String) -> Dictionary:
	if not census.legs.has(name):
		census.legs[name] = {
			"events": 0,
			"published": 0,
			"contacting": 0,
			"silent": 0,
			"no_leg": 0,
			"with_intent": 0,
			"with_timing": 0,
		}
	return census.legs[name]


func _scan(rally: Resource, census: Dictionary) -> void:
	for event in rally.events:
		var kind := int(event.event_type)
		if not CONTACT_TYPES.has(kind):
			continue
		var meta: Dictionary = event.metadata
		var row := _leg(census, str(RallyEventScript.EventType.keys()[kind]))
		row.events += 1
		var named := {}
		## **Which side is silent, not just how many.** Each leg publishes roughly
		## one team of the twelve, and the repair is to publish the other -- but
		## which one differs per leg and reading it out of a 19,000-line resolver
		## is guesswork. Counted here instead.
		if not Dictionary(meta.get("home_phase_targets", {})).is_empty():
			row["home_map"] = int(row.get("home_map", 0)) + 1
		if not Dictionary(meta.get("opponent_phase_targets", {})).is_empty():
			row["opponent_map"] = int(row.get("opponent_map", 0)) + 1
		for key in ["home_phase_targets", "opponent_phase_targets"]:
			for player_id in Dictionary(meta.get(key, {})):
				named[int(player_id)] = true
		var intents := {}
		for key in ["home_phase_intents", "opponent_phase_intents"]:
			for player_id in Dictionary(meta.get(key, {})):
				intents[int(player_id)] = true
		row.published += named.size()
		row.contacting += 1
		## A rally's first contact has no preceding interval; see the header.
		if kind == RallyEventScript.EventType.SERVE:
			row.no_leg += maxi(ON_COURT - 1, 0)
			row.with_intent += intents.size()
			continue
		## The actor is often *also* in the published map -- a receiver is placed
		## by the receive formation and then makes the contact. Counting them in
		## both columns made `silent` undercount, so the accounted set is the
		## union and not the sum.
		named[int(event.actor_id)] = true
		row.silent += maxi(ON_COURT - named.size(), 0)
		row.with_intent += intents.size()
		## No published map carries a per-voli traversal duration or arrival
		## timestamp today. Counted rather than assumed, so the day one does the
		## number moves on its own.
		for player_id in named:
			var travel: Dictionary = _travel_record(meta, int(player_id))
			if travel.has("traversal_seconds") or travel.has("arrival_time"):
				row.with_timing += 1


func _travel_record(meta: Dictionary, player_id: int) -> Dictionary:
	for key in ["home_phase_intents", "opponent_phase_intents"]:
		var map: Dictionary = meta.get(key, {})
		if map.has(player_id):
			return Dictionary(map[player_id])
	return {}


func _print(census: Dictionary) -> void:
	print("\naction-window census -- %d rallies, %d volis on court\n" % [
		census.rallies, ON_COURT,
	])
	print("%-16s %8s %11s %11s %9s %8s %11s %10s" % [
		"leg", "events", "published", "contacting", "silent", "no leg",
		"w/ intent", "w/ timing",
	])
	var order := [
		"SERVE", "RECEPTION", "SET", "ATTACK", "BLOCK", "DIG", "ATTACK_COVERAGE",
	]
	var totals := {
		"published": 0, "contacting": 0, "silent": 0, "no_leg": 0,
		"with_timing": 0,
	}
	for name in order:
		if not census.legs.has(name):
			continue
		var row: Dictionary = census.legs[name]
		print("%-16s %8d %11d %11d %9d %8d %11d %10d" % [
			name + (" [h%d/o%d]" % [
				int(row.get("home_map", 0)), int(row.get("opponent_map", 0)),
			]), row.events, row.published, row.contacting, row.silent,
			row.no_leg, row.with_intent, row.with_timing,
		])
		for key in totals:
			totals[key] += int(row[key])
	var accounted := int(totals.published) + int(totals.contacting)
	var everyone := accounted + int(totals.silent)
	print("")
	print("  voli-legs with no interval to move in: %d  (excluded below)" % int(
		totals.no_leg
	))
	print("  volis the resolver placed:        %d of %d  (%.1f%%)" % [
		accounted, everyone, 100.0 * float(accounted) / maxf(float(everyone), 1.0),
	])
	print("  volis presentation must invent:   %d of %d  (%.1f%%)" % [
		int(totals.silent), everyone,
		100.0 * float(totals.silent) / maxf(float(everyone), 1.0),
	])
	print("  placed volis carrying a duration: %d of %d" % [
		int(totals.with_timing), int(totals.published),
	])
