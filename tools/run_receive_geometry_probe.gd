extends SceneTree

## FD-001 / FD-004 -- is there exactly one receiver geometry before the serve?
##
##     godot --headless --path . \
##       --script res://tools/run_receive_geometry_probe.gd
##
## The defect this certifies closed had a very specific signature, and the
## signature is what makes it testable from outside the resolver.
##
## `_receive_formation_map` published, onto the reception event, where the
## receiving six *stand* to receive. `_initial_home_positions` separately seeded
## `live_positions` from the rotation grid or the plan's zone. The reception
## claim builds `reception_origins` out of `live_positions`, so gameplay read the
## serve from one set of coordinates while a viewer watched the six stand in
## another. `result.initial_home_positions` -- which is literally what
## `match_court_3d` spawns the actors at -- was the gameplay one.
##
## So: **the five volis who do not touch the ball must not move between the
## spawn and the reception.** They were already in formation when the whistle
## went, nothing asks them to go anywhere during the serve's flight, and if the
## published shape were still a separately-computed formation their published
## position would differ from their spawn on every rally by the whole distance
## between a rotation grid and a receive shape. One check catches the entire
## class, and it is exact rather than tolerant: zero, not "small".
##
## The receiver is the control. If *nobody* moved, the shape would be frozen
## rather than unified, so a run where the receiver never travels is a failure
## too.
##
## **Only the first `RECEPTION` of a rally is a serve reception**, and the first
## version of this probe did not know that. It reported two failures on seed
## 75217 -- a receiver missing from the published shape, and a broken serve
## lineage -- and both were the same event: an *overpass*. A reception that
## clears the net becomes the other side's ordinary first contact, which M5
## resolves through `OverpassActionSystem`, and it is emitted as a second
## `RECEPTION`. It legitimately has no receive formation (nobody set up for it)
## and its incoming ball is legitimately not the serve (it is the reception that
## crossed). Counted as a serve reception, a correct overpass reads as two
## authority breaks.
##
## They are counted separately now rather than filtered away, because "the
## engine produced 12 overpass first contacts" is worth seeing and "the engine
## produced 12 broken chains" is worth panicking about, and a probe that cannot
## tell them apart will eventually be believed.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 75000
const RALLIES_PER_SERVER: int = 250

## A court width is 9 m, so this is under a millimetre. It is float noise, not a
## band -- the claim being made is identity.
const EXACT: float = 0.0001

var failures: int = 0


func _initialize() -> void:
	var report := _run()
	_print(report)
	_gate(
		int(report.receptions) > 300,
		"the sample actually contains receptions",
	)
	_gate(
		int(report.bystanders_moved) == 0,
		"a voli who does not touch the serve stands where they were spawned",
	)
	_gate(
		int(report.spawn_missing) == 0,
		"every voli on the receiving side has a spawned position to compare",
	)
	_gate(
		int(report.receiver_travelled) > 0,
		"the receiver actually travels to the ball rather than being frozen",
	)
	_gate(
		int(report.receiver_missing) == 0,
		"the receiver's own position is published on the contact they made",
	)
	_gate(
		int(report.chain_breaks) == 0,
		"the reception consumes the serve's own launch by identity",
	)
	_gate(
		int(report.backwards) == 0,
		"the reception is never stamped before the serve",
	)
	if failures == 0:
		print("\nPASS: receive-geometry gates")
		quit(0)
		return
	push_error("FAIL: %d receive-geometry gates" % failures)
	quit(1)


func _gate(condition: bool, description: String) -> void:
	if condition:
		print("  ok    %s" % description)
		return
	failures += 1
	print("  FAIL  %s" % description)


func _run() -> Dictionary:
	var report := {
		"rallies": 0, "receptions": 0,
		"bystanders": 0, "bystanders_moved": 0, "worst_bystander": 0.0,
		"receiver_travelled": 0, "receiver_missing": 0, "spawn_missing": 0,
		"travel_total": 0.0, "chain_breaks": 0, "backwards": 0, "overpasses": 0,
		## Which seeds tripped which check. A count of one is not a finding until
		## you can reproduce it, and "1 of 423" is exactly the population where a
		## reader is most tempted to call it noise.
		"offenders": {},
	}
	for serving_home in [true, false]:
		for seed_value in range(FIRST_SEED, FIRST_SEED + RALLIES_PER_SERVER):
			var manager: Object = GameManagerScript.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = serving_home
			var rally: Resource = manager.resolve_active_rally(seed_value)
			if rally != null:
				report.rallies += 1
				_scan(rally, report, seed_value, serving_home)
			manager.free()
	return report


func _note(report: Dictionary, what: String, seed_value: int, serving_home: bool) -> void:
	var seeds: Array = report.offenders.get(what, [])
	if seeds.size() < 6:
		seeds.append("%d/%s" % [seed_value, "home" if serving_home else "away"])
	report.offenders[what] = seeds


func _scan(
	rally: Resource, report: Dictionary, seed_value: int, serving_home: bool
) -> void:
	var serve: Resource = null
	var served_ball_received := false
	for event in rally.events:
		var kind := int(event.event_type)
		if kind == RallyEventScript.EventType.SERVE:
			serve = event
			continue
		if kind != RallyEventScript.EventType.RECEPTION:
			continue
		## Everything after the first one is a receiving side's ordinary first
		## contact on an overpass, not a serve reception. See the header.
		if served_ball_received:
			report.overpasses += 1
			continue
		served_ball_received = true
		report.receptions += 1
		var meta: Dictionary = event.metadata
		## The receiving side is the one whose shape is published here; the other
		## side's map on this event is their own serve-transition, a different
		## question.
		var receiving_home := str(meta.get("side", "home")) == "home"
		var published: Dictionary = meta.get(
			"home_phase_targets" if receiving_home else "opponent_phase_targets", {}
		)
		var spawned: Dictionary = rally.initial_home_positions if receiving_home \
			else rally.initial_opponent_positions
		var receiver_id := int(event.actor_id)
		for raw_player_id in published:
			var player_id := int(raw_player_id)
			if not spawned.has(player_id):
				report.spawn_missing += 1
				continue
			var moved := Vector2(spawned[player_id]).distance_to(
				Vector2(published[raw_player_id])
			)
			if player_id == receiver_id:
				if moved > EXACT:
					report.receiver_travelled += 1
					report.travel_total += moved
				continue
			report.bystanders += 1
			if moved > EXACT:
				report.bystanders_moved += 1
				report.worst_bystander = maxf(float(report.worst_bystander), moved)
		if not published.has(receiver_id):
			report.receiver_missing += 1
			_note(report, "receiver not in published shape", seed_value, serving_home)
		if serve == null:
			continue
		var out: Dictionary = serve.metadata.get("outgoing_trajectory", {})
		var incoming: Dictionary = meta.get("incoming_trajectory", {})
		var lineage := str(out.get("authoritative_flight_id", ""))
		if lineage.is_empty() \
				or lineage != str(incoming.get("authoritative_flight_id", "")):
			report.chain_breaks += 1
			_note(report, "serve->reception lineage", seed_value, serving_home)
		var served := float(serve.metadata.get("event_time", NAN))
		var received := float(meta.get("event_time", NAN))
		if not is_nan(served) and not is_nan(received) and received < served - 0.0001:
			report.backwards += 1


func _print(report: Dictionary) -> void:
	print("\nreceive geometry -- %d rallies, %d receptions\n" % [
		report.rallies, report.receptions,
	])
	print("  bystanders checked                  %d" % int(report.bystanders))
	print("  bystanders that moved from spawn    %d" % int(report.bystanders_moved))
	print("    worst displacement                %.6f court units" % float(
		report.worst_bystander
	))
	print("  receivers that travelled to the ball %d" % int(report.receiver_travelled))
	if int(report.receiver_travelled) > 0:
		print("    mean travel                       %.4f court units" % (
			float(report.travel_total) / float(report.receiver_travelled)
		))
	print("  receivers with no published position %d" % int(report.receiver_missing))
	print("  volis with no spawned position       %d" % int(report.spawn_missing))
	print("  serve -> reception lineage breaks    %d" % int(report.chain_breaks))
	print("  overpass first contacts (not scored) %d" % int(report.overpasses))
	print("  receptions stamped before the serve  %d" % int(report.backwards))
	for what in report.offenders:
		print("  %-34s %s" % [what, ", ".join(report.offenders[what])])
	print("")
