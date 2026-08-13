extends Node

## The wall's aggregate strength, so a geometry change can be seen to move it.
##
##     xvfb-run -a godot --path . res://tools/block_rate_probe.tscn
##
## Gate D calibrated two figures and `block_jump_model.gd` records them: a stuff
## rate of 12.2% and block involvement of 43.3%. Any change to where the wall
## *stands* moves both, and a change that moved them without saying so would be
## two changes wearing one name -- the thing that file already warns about twice.
##
## Definitions are stated rather than assumed, because the calibrated numbers
## were produced by some definition and matching it exactly matters less than
## measuring the same thing before and after.
const RALLIES: int = 1200


func _ready() -> void:
	await get_tree().process_frame
	_probe()
	get_tree().quit()


func _probe() -> void:
	var career_manager: Node = get_node("/root/CareerManager")
	var game_manager: Node = get_node("/root/GameManager")
	var error: String = career_manager.create_career(
		"Block Rate Probe", "Probe VC", "Landavol", "Established", "Balanced"
	)
	if not error.is_empty():
		print("could not start a career: %s" % error)
		return

	var rallies := 0
	var with_attack := 0
	var with_block_event := 0
	var stuffed := 0
	var block_touches := 0
	for index in range(RALLIES):
		var result: Resource = game_manager.resolve_active_rally(
			hash("blockrate|%d" % index)
		)
		if result == null or result.events.is_empty():
			continue
		rallies += 1
		var saw_attack := false
		var saw_block := false
		for raw in result.events:
			var event: Resource = raw
			if event == null:
				continue
			match int(event.event_type):
				RallyEvent.EventType.ATTACK:
					saw_attack = true
				RallyEvent.EventType.BLOCK:
					saw_block = true
					## `success` on a block means the wall got a hand on it.
					block_touches += int(bool(event.success))
		with_attack += int(saw_attack)
		with_block_event += int(saw_block)
		stuffed += int(str(result.terminal_outcome) == "blocked")

	print("=== block rate probe: %d rallies" % rallies)
	print("rallies with an attack: %d" % with_attack)
	print("stuff rate (terminal 'blocked' / rallies with an attack): %.2f%%"
		% (100.0 * float(stuffed) / maxf(float(with_attack), 1.0)))
	print("block involvement (a block event / rallies with an attack): %.2f%%"
		% (100.0 * float(with_block_event) / maxf(float(with_attack), 1.0)))
	print("block touch rate (block events that touched / rallies with an attack): %.2f%%"
		% (100.0 * float(block_touches) / maxf(float(with_attack), 1.0)))
