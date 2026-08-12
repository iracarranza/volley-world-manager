extends SceneTree

const Pair := preload("res://scripts/data/pair_familiarity.gd")

func _initialize() -> void:
	var Events := load("res://scripts/models/rally_event.gd")
	var manager: Object = load("res://scripts/managers/game_manager.gd").new()
	get_root().add_child(manager)
	manager.seed_vertical_slice_data()
	var setter_id := int(manager.current_lineup().active_setter_id())
	var hitters := {}
	for player in manager.players:
		if int(player.id) != setter_id:
			hitters[int(player.id)] = 0
	var favoured: int = int(hitters.keys()[0])

	for label in ["seeded", "one hitter trusted"]:
		if label == "one hitter trusted":
			for other in hitters:
				manager.team.pair_familiarity[Pair.key(setter_id, int(other))] = 20.0
			manager.team.pair_familiarity[Pair.key(setter_id, int(favoured))] = 100.0
		var counts := {}
		for rally_seed in range(31000, 31300):
			manager.match_state.serving_home = false
			var result: Resource = manager.resolve_active_rally(rally_seed)
			if result == null:
				continue
			for event in result.events:
				if int(event.event_type) != Events.EventType.ATTACK:
					continue
				if str(event.metadata.get("side", "")) != "home":
					continue
				counts[int(event.actor_id)] = int(counts.get(int(event.actor_id), 0)) + 1
		var total := 0
		for key in counts:
			total += int(counts[key])
		print("%-20s favoured hitter %d took %.1f%% of %d swings" % [
			label, favoured,
			float(counts.get(favoured, 0)) / maxf(float(total), 1.0) * 100.0, total])
	manager.free()
	quit()
