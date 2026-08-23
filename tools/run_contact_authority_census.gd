extends SceneTree

## M6 / B0 -- one table of who owns each physical fact, per contact family.
##
##     godot --headless --path . \
##       --script res://tools/run_contact_authority_census.gd
##
## The packet's B0 rule is "build one current table before editing any certified
## family", and the temptation is to build it by reading source. That produces a
## table of what the code *looks like it does*, which is the instrument this
## repository keeps getting caught by -- `probe_kit_mark_depth` exists because a
## kit table was reviewed flat and never put on a torso.
##
## So this asks the running engine instead. Every contact publishes its incoming
## and outgoing ball into its own event metadata, and the M5 machinery stamps
## three provenance markers on any trajectory it owns:
##
##     trajectory_role          authoritative_free_flight | realised_segment
##     authoritative_flight_id  the launch's identity
##     launch_source            resolver
##
## A trajectory carrying none of them is not automatically wrong -- serve, set
## and attack have their own certified flight machinery and predate M5. But a
## family that publishes an *unmarked* ball is a family whose one-ball chain
## cannot be certified by identity, and naming those is exactly what B0 is for.
##
## Two things are reported and they answer different questions:
##
##   the family table  -- what each contact publishes about its own outgoing ball
##   the edge table    -- whether the next contact's incoming ball is that one
##
## The edge table is the one that matters. A family can look immaculate on its
## own row and still hand the next contact a different ball, and that is the
## shape every duplicate-authority defect in this engine has had.
##
## **Counts here are observations, not gates.** This tool prints and exits 0. The
## assertions live in B6's certification, where a stated invariant can fail.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

const FIRST_SEED: int = 71000
const RALLIES_PER_SERVER: int = 300

## Which event types are ball contacts. `SET_DECISION` is a decision moment and
## `POINT` is a terminal record; neither touches the ball, and counting them as
## contacts would put two "families" in the table that have no launch to own.
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
	_print_families(census)
	_print_edges(census)
	_print_reading(census)
	quit(0)


func _run() -> Dictionary:
	var census := {
		"rallies": 0,
		"contacts": 0,
		"families": {},
		"edges": {},
		"backwards": 0,
	}
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


func _family(census: Dictionary, name: String) -> Dictionary:
	if not census.families.has(name):
		census.families[name] = {
			"contacts": 0,
			"published": 0,
			"free_flight": 0,
			"realised": 0,
			"unmarked": 0,
			"flight_id": 0,
			"launch_source": 0,
			"incoming_marked": 0,
			"incoming_unmarked": 0,
			"incoming_absent": 0,
		}
	return census.families[name]


## **`different` used to mean two things and the first run proved it.**
##
## It counted 230 of 268 `BLOCK -> DIG` edges as handing over a different ball,
## which read as the worst authority break in the engine. It was not: a block
## that does not touch the ball publishes no outgoing trajectory at all, and 230
## is exactly the number of `BLOCK` events with nothing to publish. The
## comparison was scoring "the previous contact was silent" as "the previous
## contact handed over something else".
##
## So the edge is measured against the **last contact that actually published a
## ball**, not against whichever event happened to be adjacent. That is what the
## one-ball chain means anyway -- a ball survives a no-touch block, and the dig
## after it is receiving the *attack's* ball, correctly.
func _edge(census: Dictionary, name: String) -> Dictionary:
	if not census.edges.has(name):
		census.edges[name] = {
			"seen": 0,
			"same_ball": 0,
			"lineage": 0,
			"different": 0,
			"no_incoming": 0,
			"no_outgoing": 0,
			"backwards": 0,
		}
	return census.edges[name]


func _scan(rally: Resource, census: Dictionary) -> void:
	var previous_name := ""
	var previous_out := {}
	var previous_time := -INF
	for event in rally.events:
		var kind := int(event.event_type)
		if not CONTACT_TYPES.has(kind):
			continue
		var name := str(RallyEventScript.EventType.keys()[kind])
		var meta: Dictionary = event.metadata
		var row := _family(census, name)
		row.contacts += 1
		census.contacts += 1

		var incoming: Dictionary = meta.get(
			"incoming_trajectory", meta.get("incoming_pass_trajectory", {})
		)
		if incoming.is_empty():
			row.incoming_absent += 1
		elif str(incoming.get("trajectory_role", "")).is_empty():
			row.incoming_unmarked += 1
		else:
			row.incoming_marked += 1

		var outgoing: Dictionary = meta.get("outgoing_trajectory", {})
		if not outgoing.is_empty():
			row.published += 1
			match str(outgoing.get("trajectory_role", "")):
				"authoritative_free_flight":
					row.free_flight += 1
				"realised_segment":
					row.realised += 1
				_:
					row.unmarked += 1
			if not str(outgoing.get("authoritative_flight_id", "")).is_empty():
				row.flight_id += 1
			if str(outgoing.get("launch_source", "")) == "resolver":
				row.launch_source += 1

		## The edge is named by what actually followed what, so a rally that
		## skips a family (no block, no coverage) contributes to the edges it
		## really has rather than to a canonical list it did not walk. The
		## *source* of the edge is the last contact that published a ball, which
		## is not always the adjacent one -- see `_edge`.
		if not previous_name.is_empty():
			var edge := _edge(census, "%s -> %s" % [previous_name, name])
			edge.seen += 1
			if previous_out.is_empty():
				edge.no_outgoing += 1
			elif incoming.is_empty():
				edge.no_incoming += 1
			elif _same_ball(previous_out, incoming):
				edge.same_ball += 1
				if _shared_lineage(previous_out, incoming):
					edge.lineage += 1
			else:
				edge.different += 1
		var at := _contact_time(event, meta)
		if not is_nan(at):
			if not is_inf(previous_time) and at < previous_time - 0.0001:
				census.backwards += 1
			previous_time = at
		if not outgoing.is_empty():
			previous_name = name
			previous_out = outgoing


## When the two records are the same physical ball.
##
## Compared by geometry rather than by identity because most families predate the
## flight id, and an edge that is geometrically identical but carries no id is a
## *different finding* from one that hands over a different ball -- the first is
## a marking gap, the second is duplicate authority. Both are counted, separately.
func _same_ball(first: Dictionary, second: Dictionary) -> bool:
	if first.is_empty() or second.is_empty():
		return false
	return Vector2(first.get("start_position", Vector2.ZERO)).is_equal_approx(
			Vector2(second.get("start_position", Vector2.ONE))
		) and Vector2(first.get("end_position", Vector2.ZERO)).is_equal_approx(
			Vector2(second.get("end_position", Vector2.ONE))
		) and is_equal_approx(
			float(first.get("duration", -1.0)), float(second.get("duration", -2.0))
		)


func _shared_lineage(first: Dictionary, second: Dictionary) -> bool:
	var id := str(first.get("authoritative_flight_id", ""))
	return not id.is_empty() and id == str(second.get("authoritative_flight_id", ""))


func _contact_time(event: Resource, meta: Dictionary) -> float:
	for key in ["contact_time", "event_time", "physical_time"]:
		if meta.has(key):
			return float(meta[key])
	return NAN


func _print_families(census: Dictionary) -> void:
	print("\ncontact-authority census -- %d rallies, %d contacts\n" % [
		census.rallies, census.contacts,
	])
	print("%-16s %8s %8s   %8s %8s %8s   %8s %8s" % [
		"family", "contacts", "publish",
		"freeflt", "realised", "unmarked", "flightid", "launchsrc",
	])
	for name in _ordered(census.families.keys()):
		var row: Dictionary = census.families[name]
		print("%-16s %8d %8d   %8d %8d %8d   %8d %8d" % [
			name, row.contacts, row.published,
			row.free_flight, row.realised, row.unmarked,
			row.flight_id, row.launch_source,
		])
	print("\n%-16s %10s %10s %10s" % [
		"family", "in:marked", "in:plain", "in:absent",
	])
	for name in _ordered(census.families.keys()):
		var row: Dictionary = census.families[name]
		print("%-16s %10d %10d %10d" % [
			name, row.incoming_marked, row.incoming_unmarked, row.incoming_absent,
		])


func _print_edges(census: Dictionary) -> void:
	print("\nedges -- is the next contact's incoming ball the previous outgoing one?\n")
	print("%-34s %7s %9s %9s %10s %9s %8s" % [
		"edge", "seen", "same", "lineage", "different", "no in", "no out",
	])
	var names: Array = census.edges.keys()
	names.sort_custom(func(a, b): return census.edges[a].seen > census.edges[b].seen)
	for name in names:
		var edge: Dictionary = census.edges[name]
		print("%-34s %7d %9d %9d %10d %9d %8d" % [
			name, edge.seen, edge.same_ball, edge.lineage,
			edge.different, edge.no_incoming, edge.no_outgoing,
		])


## The reading, printed rather than left to the reader, because a table nobody
## interprets is how a census becomes decoration.
func _print_reading(census: Dictionary) -> void:
	print("\nreading\n")
	## **Identity and role are two different questions and this used to conflate
	## them.** The reading reported "publishes only unmarked balls" off
	## `trajectory_role`, and named serve, set, attack and block -- correctly, but
	## as though the consequence were that their chain could not be certified.
	## The consequence of a missing *id* is that; the consequence of a missing
	## *role* is nothing, and stamping one on those four would be a lie with
	## teeth: `FreeFlightInterceptionModel` gates on that exact string, so a serve
	## arc wearing M5's role could walk into M5's interception search.
	##
	## So identity is the finding and role is a description.
	var identityless: Array[String] = []
	var roleless: Array[String] = []
	for name in _ordered(census.families.keys()):
		var row: Dictionary = census.families[name]
		if int(row.published) == 0:
			continue
		if int(row.flight_id) < int(row.published):
			identityless.append("%s (%d of %d)" % [
				name, int(row.published) - int(row.flight_id), int(row.published),
			])
		if int(row.unmarked) == int(row.published):
			roleless.append(str(name))
	if identityless.is_empty():
		print("  every published ball carries a launch identity")
	else:
		print("  published without a launch identity: %s" % ", ".join(identityless))
		print("    -> the one-ball chain on these edges is shape, not lineage")
	if not roleless.is_empty():
		print("  resolved outside M5, so carrying no M5 role: %s" % ", ".join(roleless))
	var different := 0
	var no_incoming := 0
	for name in census.edges:
		var edge: Dictionary = census.edges[name]
		different += int(edge.different)
		no_incoming += int(edge.no_incoming)
	print("  edges handing over a DIFFERENT ball: %d" % different)
	print("  edges with no incoming ball at all:  %d" % no_incoming)
	print("  contacts ordered backwards in time:  %d" % int(census.backwards))


func _ordered(keys: Array) -> Array:
	var order := [
		"SERVE", "RECEPTION", "SET", "ATTACK", "BLOCK", "DIG", "ATTACK_COVERAGE",
	]
	var sorted: Array = []
	for name in order:
		if keys.has(name):
			sorted.append(name)
	for name in keys:
		if not sorted.has(name):
			sorted.append(name)
	return sorted
