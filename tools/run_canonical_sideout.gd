extends SceneTree

## M8 -- one canonical side-out, certified boundary by boundary.
##
##     godot --headless --path . \
##       --script res://tools/run_canonical_sideout.gd
##
## The packet's P5 wants "controlled, hand-authored, neutral rosters. Do not rely
## on career generation/extreme morphology to demonstrate ordinary volleyball."
## `seed_vertical_slice_data()` is exactly that: twelve named volis with written
## attributes, the same twelve every run. So the fixture is that roster plus one
## deterministic seed, chosen for **shape** rather than for outcome -- the first
## seed that walks the whole canonical sequence, whoever ends up winning it.
##
## Two layers, as P5 asks.
##
## **Structural.** At each boundary: where the actor started, how long their
## traversal took, where and when they made contact, the one authoritative ball
## they launched, and whether the next contact received *that* ball by identity.
## Everything printed comes from the resolver's own published state; nothing is
## inferred from a drawing, and where the evidence did not exist the resolver was
## made to publish it rather than the trace made to guess. `body_contact_position`
## on serve, reception, block, dig and coverage arrived that way.
##
## **Volleyball-literate.** The questions P5 says a viewer should be able to
## answer with the captions off -- who is receiving, whose ball it is, where the
## setter releases, which attackers are available, who closed on the block, which
## defensive spaces are owned, whether late volis are visibly late. Those are
## answered here as *numbers a viewer would see the consequence of*, because a
## headless probe cannot look at anything. Where a number cannot stand in for the
## judgement, the trace says so rather than inventing a proxy.
##
## This is a diagnostic first and a gate second. The gates below assert only
## structure -- lineage, causality, one ball, actors that moved before they
## contacted. No rate is asserted.

const GameManagerScript := preload("res://scripts/managers/game_manager.gd")
const RallyEventScript := preload("res://scripts/models/rally_event.gd")

## Searched, not hand-picked, so the fixture is reproducible by rule rather than
## by having liked the answer.
const SEARCH_FROM: int = 76000
const SEARCH_SPAN: int = 400

## The canonical sequence P5 names. A side-out that reaches a transition
## exercises strictly more boundaries than one that ends at the first terminal,
## so the search prefers one.
const WANTED: Array[int] = [
	RallyEventScript.EventType.SERVE,
	RallyEventScript.EventType.RECEPTION,
	RallyEventScript.EventType.SET,
	RallyEventScript.EventType.ATTACK,
]

var failures: int = 0


func _initialize() -> void:
	var found := _find_fixture()
	if found.is_empty():
		push_error("FAIL: no canonical side-out in the searched span")
		quit(1)
		return
	var trace := _trace(found.rally)
	## The fixture's manager is held only long enough to walk its rally, then
	## released. Left dangling it produced a wall of ObjectDB leak warnings at
	## exit -- noise a diagnostic should not add to its own output.
	var keeper: Object = found.get("manager", null)
	found.erase("manager")
	found.erase("rally")
	if keeper != null:
		keeper.free()
	_print(found, trace)
	_gate(int(trace.boundaries) >= 4, "the fixture walks at least four boundaries")
	_gate(int(trace.lineage_breaks) == 0, "every contact receives the ball the last one launched")
	_gate(int(trace.backwards) == 0, "contact times are monotonic")
	_gate(int(trace.multi_ball) == 0, "no contact publishes more than one outgoing ball")
	_gate(int(trace.bodiless) == 0, "every contact says where the body that made it stood")
	_gate(int(trace.moved_before_contact) > 0, "actors travel before the contacts they make")
	_gate(int(trace.reconstructed) == 0, "no boundary needed a fact the resolver did not publish")
	if failures == 0:
		print("\nPASS: canonical side-out certification")
		quit(0)
		return
	push_error("FAIL: %d canonical side-out gates" % failures)
	quit(1)


func _gate(condition: bool, description: String) -> void:
	if condition:
		print("  ok    %s" % description)
		return
	failures += 1
	print("  FAIL  %s" % description)


## The first seed whose rally walks the canonical sequence, preferring one that
## also reaches a transition.
func _find_fixture() -> Dictionary:
	var fallback := {}
	for seed_value in range(SEARCH_FROM, SEARCH_FROM + SEARCH_SPAN):
		var manager: Object = GameManagerScript.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = true
		var rally: Resource = manager.resolve_active_rally(seed_value)
		if rally == null:
			manager.free()
			continue
		var kinds: Array[int] = []
		for event in rally.events:
			kinds.append(int(event.event_type))
		var walks := true
		var at := 0
		for wanted in WANTED:
			at = kinds.find(wanted, at)
			if at < 0:
				walks = false
				break
			at += 1
		if not walks:
			manager.free()
			continue
		var found := {"seed": seed_value, "rally": rally, "manager": manager}
		## A transition means the defence kept it alive and the rally came back
		## the other way -- a second SET after the first ATTACK.
		var attack_at := kinds.find(RallyEventScript.EventType.ATTACK)
		if kinds.find(RallyEventScript.EventType.SET, attack_at) > 0:
			found["transition"] = true
			return found
		if fallback.is_empty():
			fallback = found
		else:
			manager.free()
	return fallback


func _trace(rally: Resource) -> Dictionary:
	var trace := {
		"rows": [],
		"boundaries": 0, "lineage_breaks": 0, "backwards": 0,
		"multi_ball": 0, "bodiless": 0, "moved_before_contact": 0,
		"reconstructed": 0,
	}
	var previous_out := {}
	var previous_name := ""
	var previous_time := -INF
	var previous_map := {}
	var previous_intents := {}
	for event in rally.events:
		var kind := int(event.event_type)
		if kind == RallyEventScript.EventType.POINT \
				or kind == RallyEventScript.EventType.SET_DECISION:
			continue
		var meta: Dictionary = event.metadata
		var actor_id := int(event.actor_id)
		var row := {
			"name": str(RallyEventScript.EventType.keys()[kind]),
			"actor": str(event.actor_name),
			"time": _stamp(meta),
		}
		## Where the body stood. Published on every contact now; if it ever is
		## not, the trace says so rather than substituting the ball's position,
		## which is what "instrument, do not infer" means here.
		if meta.has("body_contact_position"):
			row["contact"] = Vector2(meta["body_contact_position"])
		else:
			trace.bodiless += 1
			trace.reconstructed += 1
		## Where they started this leg.
		##
		## The first version of this trace read the *previous event's published
		## map*, and that map is the leg's **end** state, not its start -- so it
		## reported travel 0.000 for the setter, the blocker and the transition
		## hitter, all of whom had plainly moved. It was measuring "did the
		## resolver move this actor again after publishing them", which is a
		## different and much less interesting question.
		##
		## `actor_leg_start` is published by the resolver now, snapshotted at the
		## previous contact, which is the interval M8 actually asks about.
		if meta.has("actor_leg_start"):
			row["start"] = Vector2(meta["actor_leg_start"])
			if row.has("contact") \
					and Vector2(row["start"]).distance_to(Vector2(row["contact"])) > 0.0001:
				trace.moved_before_contact += 1
		## **A zero travel is not automatically a voli who never moved.**
		##
		## The setter releases during the serve's flight and the blockers close
		## during the set's -- C2 and C4 put their movement in the leg *before*
		## the contact they are preparing for, which is the whole point of M7. So
		## an actor can arrive at their contact having travelled nothing in that
		## leg because they did their travelling in the one before it, and a
		## trace that cannot tell that apart from a voli who was never asked to
		## move will read the correct case as the defect.
		##
		## Asked of the previous contact's own published intents, which is where
		## that leg's traversals live.
		if previous_intents.has(actor_id):
			row["earlier"] = float(
				Dictionary(previous_intents[actor_id]).get("traversal_seconds", 0.0)
			)
		var outgoing: Dictionary = meta.get("outgoing_trajectory", {})
		if not outgoing.is_empty():
			row["ball"] = str(outgoing.get("trajectory_type", "?"))
			row["lineage"] = str(outgoing.get("authoritative_flight_id", ""))
		var incoming: Dictionary = meta.get(
			"incoming_trajectory", meta.get("incoming_pass_trajectory", {})
		)
		if not previous_name.is_empty() and not incoming.is_empty():
			trace.boundaries += 1
			var upstream := str(previous_out.get("authoritative_flight_id", ""))
			var mine := str(incoming.get("authoritative_flight_id", ""))
			row["from"] = previous_name
			if upstream.is_empty() or upstream != mine:
				trace.lineage_breaks += 1
				row["chain"] = "BROKEN"
			else:
				row["chain"] = "same launch"
		var at := _stamp(meta)
		if not is_nan(at):
			if not is_inf(previous_time) and at < previous_time - 0.0001:
				trace.backwards += 1
			previous_time = at
		## One contact, one ball. `outgoing_trajectory` is a single record by
		## construction, so the way this could fail is a family publishing a
		## second under another name; both are checked.
		var extras := 0
		for key in ["authoritative_free_flight", "realised_trajectory"]:
			var other: Dictionary = meta.get(key, {})
			if other.is_empty() or outgoing.is_empty():
				continue
			if str(other.get("authoritative_flight_id", "")) \
					!= str(outgoing.get("authoritative_flight_id", "")):
				extras += 1
		trace.multi_ball += extras
		row["moving"] = _in_motion(meta)
		trace.rows.append(row)
		if not outgoing.is_empty():
			previous_out = outgoing
			previous_name = str(RallyEventScript.EventType.keys()[kind])
		var published := _published_map(meta)
		if not published.is_empty():
			for player_id in published:
				previous_map[int(player_id)] = published[player_id]
		for key in ["home_phase_intents", "opponent_phase_intents"]:
			for player_id in Dictionary(meta.get(key, {})):
				previous_intents[int(player_id)] = Dictionary(meta[key])[player_id]
	return trace


func _published_map(meta: Dictionary) -> Dictionary:
	var merged := {}
	for key in ["home_phase_targets", "opponent_phase_targets"]:
		for player_id in Dictionary(meta.get(key, {})):
			merged[int(player_id)] = Vector2(Dictionary(meta[key])[player_id])
	return merged


func _in_motion(meta: Dictionary) -> int:
	var moving := 0
	for key in ["home_phase_intents", "opponent_phase_intents"]:
		for player_id in Dictionary(meta.get(key, {})):
			var record: Dictionary = Dictionary(meta[key])[player_id]
			if float(record.get("traversal_seconds", 0.0)) > 0.02:
				moving += 1
	return moving


func _stamp(meta: Dictionary) -> float:
	for key in ["contact_time", "event_time", "physical_time"]:
		if meta.has(key):
			return float(meta[key])
	return NAN


func _print(found: Dictionary, trace: Dictionary) -> void:
	print("\n=== canonical side-out: seed %d, home serving, vertical-slice roster ===" % [
		int(found.seed),
	])
	print("    reaches a transition: %s\n" % ("yes" if found.get("transition", false) else "no"))
	print("%-16s %-10s %8s  %-15s %-15s %-8s %-9s %-18s %s" % [
		"contact", "actor", "t", "started at", "contacted at", "travel",
		"prepared", "launched", "chain",
	])
	for row in trace.rows:
		var start := "-"
		var travel := "-"
		if row.has("start"):
			start = "%.3f,%.3f" % [Vector2(row["start"]).x, Vector2(row["start"]).y]
			if row.has("contact"):
				travel = "%.3f" % Vector2(row["start"]).distance_to(
					Vector2(row["contact"])
				)
		var contact := "-"
		if row.has("contact"):
			contact = "%.3f,%.3f" % [
				Vector2(row["contact"]).x, Vector2(row["contact"]).y,
			]
		var earlier := "-"
		if row.has("earlier"):
			earlier = "%.2fs" % float(row["earlier"])
		print("%-16s %-10s %8s  %-15s %-15s %-8s %-9s %-18s %s" % [
			str(row["name"]), str(row["actor"]),
			"-" if is_nan(float(row["time"])) else "%.3f" % float(row["time"]),
			start, contact, travel, earlier,
			str(row.get("ball", "-")), str(row.get("chain", "-- first ball")),
		])
	print("")
	for row in trace.rows:
		if int(row.get("moving", 0)) > 0:
			print("    %-16s %d volis in motion toward the next contact" % [
				str(row["name"]), int(row["moving"]),
			])
	print("")
	print("  boundaries walked                    %d" % int(trace.boundaries))
	print("  lineage breaks                       %d" % int(trace.lineage_breaks))
	print("  contacts out of time order           %d" % int(trace.backwards))
	print("  contacts publishing a second ball    %d" % int(trace.multi_ball))
	print("  contacts with no body position       %d" % int(trace.bodiless))
	print("  contacts whose actor had travelled   %d" % int(trace.moved_before_contact))
	print("  facts the trace had to reconstruct   %d" % int(trace.reconstructed))
	print("")
