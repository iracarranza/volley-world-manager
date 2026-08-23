extends Node

## Can the follow list name a voli without crashing?
##
## `DynamicCourtCamera._refresh_players` reads a name off every spawned actor to
## build "Follow: <voli>". It read `display_name`, which `PlayerActor3D` has
## never had, and a missing property is an error rather than a null -- so the
## "Voli %d" fallback beside it never got the chance to run and the match view
## died as the list was built. This spawns real actors and asks them the same
## question the camera asks.

const COURT := preload("res://scenes/components/match_court_3d.tscn")

func _ready() -> void:
	var court := COURT.instantiate() as MatchCourt3D
	add_child(court)
	await get_tree().process_frame
	court.setup_players(
		{1: Vector2(0.3, 0.8), 2: Vector2(0.5, 0.8)},
		{101: Vector2(0.3, 0.2)},
		{1: "Sabet Kleinbek", 2: "Mira Bojadal", 101: "Sven Kamenar"},
	)
	await get_tree().process_frame
	var failures := 0
	for raw_id in court.player_actors.keys():
		var actor := court.actor_for(int(raw_id))
		if actor == null:
			continue
		var label := str(actor.voli_name).strip_edges()
		print("  id %-4d voli_name %s" % [int(raw_id), "(empty)" if label.is_empty() else label])
		if label.is_empty():
			failures += 1
	print("named actors failing: %d" % failures)
	get_tree().quit(1 if failures > 0 else 0)
