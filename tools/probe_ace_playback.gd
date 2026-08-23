extends SceneTree

## What does playback have to draw on an ace?
##
## An ace is a RECEPTION event with `success == false` and nobody touching the
## ball. Playback draws the leg `serve -> reception`, takes the ball to the
## reception's `start_position` and the actor to its `movement_target`, so those
## two are *supposed* to disagree -- that disagreement is the miss. This prints
## the five positions per ace so the drawn discontinuity can be attributed to a
## published fact rather than guessed at from three frames.

const MANAGER := preload("res://scripts/managers/game_manager.gd")


func _initialize() -> void:
	var aces := 0
	var received := 0
	var ace_gap_total := 0.0
	var recv_gap_total := 0.0
	var missing_target := 0
	var printed := 0
	for index in range(120):
		var manager = MANAGER.new()
		manager.seed_vertical_slice_data()
		manager.match_state.serving_home = false
		var result: Resource = manager.resolve_active_rally(300000 + index)
		if result == null:
			continue
		var serve: RallyEvent = null
		for raw_event in result.events:
			var event := raw_event as RallyEvent
			if event == null:
				continue
			if int(event.event_type) == RallyEvent.EventType.SERVE:
				serve = event
				continue
			if int(event.event_type) != RallyEvent.EventType.RECEPTION:
				continue
			var ball := Vector2(event.start_position)
			var body := Vector2(event.metadata.get("body_contact_position", ball))
			var has_target: bool = event.metadata.has("movement_target")
			var target := Vector2(event.metadata.get("movement_target", body))
			## What playback actually drives the actor to, per `_build_movement_plan`.
			var drawn_actor := body
			if not bool(event.success) and has_target:
				drawn_actor = target
			var gap := RallyKinematics.court_delta_meters(drawn_actor, ball).length()
			if bool(event.success):
				received += 1
				recv_gap_total += gap
			else:
				aces += 1
				ace_gap_total += gap
				if not has_target:
					missing_target += 1
				if printed < 6:
					printed += 1
					print(
						"ace  actor %-14s success %s  ball %.3f,%.3f  body %.3f,%.3f"
						% [
							event.actor_name, str(event.success),
							ball.x, ball.y, body.x, body.y,
						]
					)
					print(
						"     movement_target %s %.3f,%.3f   drawn actor->ball gap %.2f m"
						% [
							"yes" if has_target else "NO ",
							target.x, target.y, gap,
						]
					)
			break
	print("")
	print("aces                       %d" % aces)
	print("  mean drawn actor->ball    %.2f m" % (ace_gap_total / maxf(float(aces), 1.0)))
	print("  aces missing movement_target %d" % missing_target)
	print("successful receptions      %d" % received)
	print("  mean drawn actor->ball    %.2f m" % (recv_gap_total / maxf(float(received), 1.0)))
	quit(0)
