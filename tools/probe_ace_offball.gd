extends SceneTree

## On an ace, does anything tell playback to move the other eleven volis?
##
## A leg is drawn `event -> next_contact` and its movement plan is read off the
## *next* contact, so the serve flight's off-ball movement lives on the RECEPTION
## event. If an ace's reception publishes no phase map, nobody moves during the
## serve -- which is what a viewer reported seeing.

const MANAGER := preload("res://scripts/managers/game_manager.gd")

const MAP_KEYS := [
	"home_phase_targets", "opponent_phase_targets",
	"home_phase_intents", "opponent_phase_intents",
]


func _initialize() -> void:
	var aces := 0
	var normal := 0
	var ace_rows := {}
	var normal_rows := {}
	for key in MAP_KEYS:
		ace_rows[key] = 0
		normal_rows[key] = 0
	for side in range(2):
		for index in range(110):
			var manager = MANAGER.new()
			manager.seed_vertical_slice_data()
			manager.match_state.serving_home = side == 0
			var result: Resource = manager.resolve_active_rally(300000 + index)
			if result == null:
				continue
			var is_ace := str(result.terminal_outcome) == "ace"
			var reception: RallyEvent = null
			for raw_event in result.events:
				var event := raw_event as RallyEvent
				if event == null:
					continue
				if int(event.event_type) == RallyEvent.EventType.RECEPTION:
					reception = event
					break
			if reception == null:
				if is_ace:
					aces += 1
					ace_rows["(no reception event at all)"] = int(
						ace_rows.get("(no reception event at all)", 0)
					) + 1
				continue
			var rows: Dictionary = ace_rows if is_ace else normal_rows
			if is_ace:
				aces += 1
			else:
				normal += 1
			for key in MAP_KEYS:
				var map: Dictionary = reception.metadata.get(key, {})
				if not map.is_empty():
					rows[key] = int(rows[key]) + 1
	print("aces %d | ordinary receptions %d" % [aces, normal])
	print("%-30s %8s %10s" % ["key on the RECEPTION event", "on aces", "on others"])
	for key in ace_rows.keys():
		print("%-30s %8d %10d" % [
			str(key), int(ace_rows[key]), int(normal_rows.get(key, 0)),
		])
	quit(0)
