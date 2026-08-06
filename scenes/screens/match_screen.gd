class_name MatchScreen
extends Control

signal close_requested

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const NET_HEIGHT_METERS: float = 2.43

@onready var match_court_3d: MatchCourt3D = %MatchCourt3D
@onready var caption_label: Label = %CaptionLabel
@onready var detail_label: Label = %DetailLabel
@onready var event_label: Label = %EventLabel
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var pause_button: Button = %PauseButton
@onready var replay_button: Button = %ReplayButton
@onready var skip_button: Button = %SkipButton
@onready var camera_button: Button = %CameraButton
@onready var close_button: Button = %CloseButton
@onready var speed_option: OptionButton = %SpeedOption

var playback_speed: float = 1.0
var active_result: RallyResult
var playback_generation: int = 0
## Where playback had a player standing when the resolver said their journey
## started somewhere else. Kept rather than absorbed: each entry is a leg the
## simulator timed from a position playback never walked them to, and the list
## going up is how that gets noticed.
##
## "How that gets noticed" was aspirational until now. This array was declared,
## cleared at the start of every rally, and appended to -- and read by nothing,
## anywhere, ever. It is an instrument recording exactly the "the player
## credited with that touch was never standing there" symptom, and the symptom
## had to be reported by somebody watching a rally because nothing consulted the
## thing built to catch it. `playback_geometry_report()` is the missing half.
var playback_start_mismatches: Array[Dictionary] = []
var playback_paused: bool = false
var skip_requested: bool = false
var playback_active: bool = false
var player_names: Dictionary = {}
var player_handedness: Dictionary = {}
var player_physical_profiles: Dictionary = {}


func _ready() -> void:
	pause_button.pressed.connect(_toggle_pause)
	replay_button.pressed.connect(_replay)
	skip_button.pressed.connect(_skip)
	camera_button.pressed.connect(_cycle_camera)
	close_button.pressed.connect(_close)
	speed_option.item_selected.connect(_speed_changed)
	_populate_speeds()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_SPACE:
			_toggle_pause()
			get_viewport().set_input_as_handled()
		KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
		KEY_C:
			_cycle_camera()
			get_viewport().set_input_as_handled()


func load_and_play_rally(rally_result: RallyResult, requested_speed: float = 1.0) -> void:
	if rally_result == null or rally_result.events.is_empty():
		return
	playback_generation += 1
	var generation := playback_generation
	active_result = rally_result
	playback_speed = clampf(requested_speed, 0.1, 4.0)
	_select_speed(playback_speed)
	playback_paused = false
	skip_requested = false
	playback_active = true
	pause_button.text = "Pause"
	replay_button.disabled = true
	skip_button.disabled = false
	visible = true
	move_to_front()
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_player_names(rally_result.events)
	player_handedness = rally_result.player_handedness.duplicate(true)
	player_physical_profiles = rally_result.player_physical_profiles.duplicate(true)
	var home_positions: Dictionary = rally_result.initial_home_positions
	var opponent_positions: Dictionary = rally_result.initial_opponent_positions
	if home_positions.is_empty() and opponent_positions.is_empty():
		var fallback := _fallback_positions_from_events(rally_result.events)
		home_positions = fallback["home"]
		opponent_positions = fallback["opponent"]
	match_court_3d.setup_players(
		home_positions, opponent_positions, player_names, player_handedness,
		player_physical_profiles,
	)
	match_court_3d.ball_actor.reset_flight()
	playback_start_mismatches.clear()
	progress_bar.value = 0.0
	await _run_rally(generation)
	if generation != playback_generation:
		return
	playback_active = false
	replay_button.disabled = false
	skip_button.disabled = true
	pause_button.disabled = false
	pause_button.text = "Pause"
	match_court_3d.ball_actor.hold_at_rest()
	match_court_3d.reset_player_poses()
	event_label.text = "POINT COMPLETE"
	caption_label.text = rally_result.terminal_outcome.replace("_", " ").to_upper()
	detail_label.text = rally_result.explanation
	progress_bar.value = 100.0


func _run_rally(generation: int) -> void:
	var events := active_result.events
	for event_index in range(events.size()):
		if generation != playback_generation or skip_requested:
			break
		var event := events[event_index] as RallyEvent
		if event == null:
			continue
		_show_event_text(event, event_index, events.size())
		if event.event_type == RallyEventModel.EventType.SET_DECISION:
			## Tactical choice, not a second physical touch. The preceding flight
			## already delivered the setter to this instant; pausing here created a
			## visible hitch immediately before every set.
			continue
		var trajectory: Dictionary = event.metadata.get("outgoing_trajectory", {})
		var next_index := _next_contact_index(events, event_index + 1)
		var next_contact: RallyEvent = null
		var after_next: RallyEvent = null
		if next_index >= 0:
			next_contact = events[next_index] as RallyEvent
			## One further ahead, because a block has to be *in the air* by the
			## time the hitter swings -- see `_apply_contact_poses`.
			after_next = _next_contact_event(events, next_index + 1)
		if not trajectory.is_empty():
			await _play_flight(
				event, next_contact, after_next, trajectory,
				event_index, events.size(), generation
			)
		else:
			## An event the ball spends no time on costs no time.
			##
			## This was a flat 0.38 s for every contact without a trajectory, so
			## a block that never touched the ball, a defender's read step and a
			## dive all bought a beat of their own -- and the rally visibly
			## stopped while nothing happened. The simulator already knows when
			## each contact occurred, so the gap to the next one is the honest
			## answer, and where that gap is zero the two events are genuinely
			## simultaneous and share a beat instead of queueing.
			await _play_contact_pulse(
				event, _gap_to_next(events, event_index), generation
			)
	match_court_3d.ball_actor.hold_at_rest()


## How long the ball actually spends between this event and the next.
##
## Read from `physical_time`, which every event now carries and which the
## timestamp gate holds to 100% coverage with zero causality corrections. A
## quarter of all inter-event gaps are under 5 ms -- `RECEPTION` into the
## setter's decision, `ATTACK` into the `BLOCK` that meets it -- and those are
## not events to draw in sequence, they are one moment.
##
## Falls back to the old flat beat only when a stamp is missing, which the gate
## says should never happen; it is there so a regression degrades to the
## previous behaviour rather than to a zero-length rally.
func _gap_to_next(events: Array, event_index: int) -> float:
	var current := events[event_index] as RallyEvent
	if current == null or not current.metadata.has("physical_time"):
		return 0.38
	var moment := float(current.metadata["physical_time"])
	for later_index in range(event_index + 1, events.size()):
		var later := events[later_index] as RallyEvent
		if later == null or not later.metadata.has("physical_time"):
			continue
		return maxf(float(later.metadata["physical_time"]) - moment, 0.0)
	## The last contact of the rally has nothing after it, so it gets a short
	## outro rather than a gap.
	return 0.38


func _play_flight(
	event: RallyEvent,
	next_contact: RallyEvent,
	after_next: RallyEvent,
	trajectory: Dictionary,
	event_index: int,
	event_count: int,
	generation: int,
) -> void:
	## Read from the *display* trajectory, not the source one. A flight cut short
	## at an interception carries a shortened duration, and taking the original
	## would spend the full time on the shortened path.
	var display_trajectory := _display_trajectory(event, next_contact, trajectory)
	var duration := clampf(float(display_trajectory.get("duration", 0.5)), 0.08, 3.5)
	var movement_plan := _build_movement_plan(event, next_contact)
	var elapsed := 0.0
	match_court_3d.ball_actor.reset_flight()
	while elapsed < duration:
		if generation != playback_generation or skip_requested:
			break
		if playback_paused:
			await get_tree().process_frame
			continue
		elapsed += get_process_delta_time() * playback_speed
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		match_court_3d.set_ball_trajectory_sample(display_trajectory, progress)
		match_court_3d.apply_movement_plan(movement_plan, progress)
		_apply_contact_poses(event, next_contact, after_next, progress, duration)
		progress_bar.value = (
			(float(event_index) + progress) / maxf(float(event_count), 1.0)
		) * 100.0
		await get_tree().process_frame
	match_court_3d.finish_movement_plan(movement_plan)
	match_court_3d.reset_player_poses()


func _play_contact_pulse(event: RallyEvent, duration: float, generation: int) -> void:
	var elapsed := 0.0
	while elapsed < duration:
		if generation != playback_generation or skip_requested:
			break
		if playback_paused:
			await get_tree().process_frame
			continue
		elapsed += get_process_delta_time() * playback_speed
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		match_court_3d.reset_player_poses()
		var peak := _event_elevation(event, int(event.actor_id))
		match_court_3d.set_player_pose(
			int(event.actor_id), int(event.event_type),
			peak * sin(progress * PI), progress,
			event.end_position - event.start_position, true,
			_contact_posture(event),
			_contact_recovery(event),
		)
		await get_tree().process_frame


## How strained this contact was, as the resolver recorded it.
##
## `_reception_pass_result` classifies every reception and dig from the
## defender's reach margin, how deep into the edge of their range the ball was,
## and how well their body could face it, and writes the verdict onto the event.
## Reading it here is what makes a defender dropping to their knees mean
## something rather than being a flourish: the pose says what the simulation
## already decided, and a player forced low really was forced low.
##
## Defaults to `planted` for every other contact type, which is what the pose
## code treats as an ordinary athletic stance.
## What the contact did to the defender. Same source as the posture and read the
## same way -- playback never decides either.
func _contact_recovery(event: RallyEvent) -> String:
	if event == null or event.metadata == null:
		return "platform"
	return str(event.metadata.get("contact_recovery", "platform"))


func _contact_posture(event: RallyEvent) -> String:
	if event == null:
		return "planted"
	return str(event.metadata.get("contact_posture", "planted"))


func _apply_contact_poses(
	event: RallyEvent,
	next_contact: RallyEvent,
	after_next: RallyEvent,
	progress: float,
	window_seconds: float = 1.0,
) -> void:
	match_court_3d.reset_player_poses()
	var event_actor := int(event.actor_id)
	var event_peak := _event_elevation(event, event_actor)
	var event_direction := event.end_position - event.start_position
	var outgoing_weight := 1.0 - smoothstep(0.18, 0.75, progress)
	var incoming_weight := smoothstep(0.48, 1.0, progress)
	## One player can legally contact twice in a row -- a blocker digging their
	## own deflection is the common case, since a block touch is not one of the
	## team's three contacts. Posing both events for them wrote the incoming
	## pose over the outgoing one at every progress value, so the block collapsed
	## to a standing dig the instant the deflection started travelling. That is
	## the "one play reading as several actions" the viewer sees. Whichever pose
	## currently carries more weight is the one drawn, so the block holds until
	## the dig genuinely takes over.
	var same_actor := next_contact != null and int(next_contact.actor_id) == event_actor
	var draw_outgoing := not same_actor or outgoing_weight >= incoming_weight
	if draw_outgoing:
		## A block arrives here already partway through its own phase. The hold
		## ran during the attack's flight, so this window -- the deflection's --
		## is the withdraw and the landing, and starting it at 0 would replay the
		## wall going up for a third time.
		var outgoing_phase := progress
		var outgoing_lift := outgoing_weight
		if event.event_type == RallyEventModel.EventType.BLOCK:
			outgoing_phase = _block_withdraw_phase(progress, window_seconds)
			outgoing_lift = BlockBiomechanics.elevation_at(outgoing_phase)
		match_court_3d.set_player_pose(
			event_actor, int(event.event_type),
			event_peak * outgoing_lift, outgoing_phase, event_direction, true,
			_contact_posture(event),
			_contact_recovery(event),
		)
	var event_assist := int(event.metadata.get("assist_id", -1))
	if event_assist >= 0 and event.event_type == RallyEventModel.EventType.BLOCK:
		var assist_phase := _block_withdraw_phase(progress, window_seconds)
		match_court_3d.set_player_pose(
			event_assist, int(event.event_type),
			_event_elevation(event, event_assist)
				* BlockBiomechanics.elevation_at(assist_phase),
			assist_phase, event_direction, true,
		)
	if next_contact == null:
		return
	var next_actor := int(next_contact.actor_id)
	var next_peak := _event_elevation(next_contact, next_actor)
	var next_direction := next_contact.end_position - next_contact.start_position
	## The wind-up half of the phase, which is why it is `progress - 1`.
	##
	## `set_pose` takes a signed phase with contact at zero, so the approach runs
	## -1 to 0 across the *incoming* ball's flight and the follow-through runs 0
	## to +1 across the outgoing one. Passing bare `progress` here handed the
	## upcoming contact a phase that ran 0 to 1 during its approach and then
	## restarted at 0 the moment it became the current event -- so the swing
	## played out completely, snapped back to fully cocked at the frame of
	## contact, and played again. Elevation was already continuous across that
	## seam, so only the arms jumped.
	var next_is_block := next_contact.event_type == RallyEventModel.EventType.BLOCK
	if not same_actor or not draw_outgoing:
		## A block is the one contact whose pose does *not* wind up across the
		## flight that reaches it.
		##
		## Every other contact is prepared for while the ball is on its way: the
		## phase runs -1 to 0 across the incoming flight and the contact lands at
		## the end of it. A block does not work that way. The wall has to be at
		## full extension **when the hitter swings**, not when the ball arrives at
		## it -- so its wind-up belongs to the *set's* flight, and the attack's
		## flight is the hold.
		##
		## Drawn the old way it was always late, and measurably so: every block in
		## a 120-rally sample was immediately preceded by its attack, and the gap
		## between the two ran to 1.19 s. The blocker therefore started their jump
		## at the moment of the hitter's contact and reached the top of it only
		## when the ball got there. On a fast swing that is a fraction of a
		## second and reads as sloppy timing; on a slow roll shot it is a full
		## second of a blocker standing flat-footed watching the ball come.
		##
		## So the positive half of the phase runs here, and the negative half is
		## drawn one window earlier, below.
		## The positive half of a block's phase is split across *two* windows, not
		## spent entirely in this one.
		##
		## A block spans three flights: the set's, during which the wall goes up;
		## the attack's, during which it holds while the ball crosses to it; and
		## its own deflection's, during which it comes down. Running 0 to 1 here
		## played the hold *and* the withdraw while the ball was still arriving,
		## and then the block's own window started over from 0 -- so the wall went
		## up, came down, and went up again. That is the block replaying itself.
		##
		## This window is the hold, so it ends where the hold ends.
		var next_phase := _block_hold_phase(progress) \
			if next_is_block else progress - 1.0
		var next_lift := BlockBiomechanics.elevation_at(next_phase) \
			if next_is_block else incoming_weight
		match_court_3d.set_player_pose(
			next_actor, int(next_contact.event_type),
			next_peak * next_lift, next_phase, next_direction, true,
		)
	var next_assist := int(next_contact.metadata.get("assist_id", -1))
	if next_assist >= 0 and next_is_block:
		## Through the same helper as the actor above. These were two call sites
		## computing the same phase independently, and when the actor's mapping
		## was corrected this one was not -- so the second blocker went on
		## running the whole hold-and-withdraw during the attack's flight and
		## then started again for the deflection, replaying the wall while the
		## caption still read "block forms".
		var assist_hold := _block_hold_phase(progress)
		match_court_3d.set_player_pose(
			next_assist, int(next_contact.event_type),
			_event_elevation(next_contact, next_assist)
				* BlockBiomechanics.elevation_at(assist_hold),
			assist_hold, next_direction, true,
		)
	_apply_early_block(after_next, next_contact, progress)


## How long a blocker takes to come down and absorb it, in seconds.
##
## A descent is governed by gravity, not by when the next contact happens. The
## block's withdraw was mapped linearly onto its own flight window, so a
## deflection that took a second and a half lowered the blocker over a second and
## a half -- they sank rather than fell. Bounding it in real time means a long
## window leaves them standing on the floor waiting, which is what actually
## happens, and a short one still finishes the motion.
const BLOCK_DESCENT_SECONDS: float = 0.42


## Where the block's phase sits during the attack's flight -- the hold.
##
## One helper for both blockers. These were two call sites doing the same
## arithmetic separately, and correcting one and not the other is exactly how
## the second blocker ended up replaying the wall.
func _block_hold_phase(progress: float) -> float:
	return progress * BlockBiomechanics.HOLD_END


## And where it sits during the block's own flight -- the withdraw and landing,
## paced by `BLOCK_DESCENT_SECONDS` rather than by the length of the window.
func _block_withdraw_phase(progress: float, window_seconds: float) -> float:
	var elapsed := progress * maxf(window_seconds, 0.0001)
	var descent := clampf(elapsed / BLOCK_DESCENT_SECONDS, 0.0, 1.0)
	return lerpf(BlockBiomechanics.HOLD_END, 1.0, descent)


## Put the wall up while the ball is still on its way to the hitter.
##
## Called with the contact *two* ahead: when the current flight is the set and
## the next contact is the attack, `after_next` is the block that attack will
## meet. Posing it here is what lets a blocker be in the air at the swing --
## `progress - 1.0` puts the press exactly at the end of this window, which is
## the instant of the hitter's contact.
##
## Guarded on the middle event being the attack, because "two contacts ahead" is
## only the right anchor when the thing in between is what the block is timed
## against.
func _apply_early_block(
	after_next: RallyEvent, next_contact: RallyEvent, progress: float
) -> void:
	if after_next == null or next_contact == null:
		return
	if after_next.event_type != RallyEventModel.EventType.BLOCK:
		return
	if next_contact.event_type != RallyEventModel.EventType.ATTACK:
		return
	var phase := progress - 1.0
	var lift := BlockBiomechanics.elevation_at(phase)
	var direction := after_next.end_position - after_next.start_position
	for blocker_id in [
		int(after_next.actor_id),
		int(after_next.metadata.get("assist_id", -1)),
	]:
		if blocker_id < 0:
			continue
		match_court_3d.set_player_pose(
			blocker_id, RallyEventModel.EventType.BLOCK,
			_event_elevation(after_next, blocker_id) * lift,
			phase, direction, true,
		)


func _build_movement_plan(event: RallyEvent, next_contact: RallyEvent) -> Dictionary:
	var plan := {}
	if next_contact == null:
		return plan
	## Where the ball will next be played from. The event's own `start_position`,
	## not its `movement_target` -- those disagree by more than 15 cm on 39% of
	## contacts and by up to 5.7 m, and the one the *ball* is drawn to is the
	## contact position. A player driven to the other one stands away from the
	## ball they are supposedly playing.
	var action_target := Vector2(next_contact.start_position)
	## Nobody moves unless something actually says they move.
	##
	## This loop used to hand every player on the court a target, computed by
	## lerping them toward the action by a fixed fraction -- 0.08 if they were
	## front row, 0.15 if not, 0.18 for a block, and so on. Not derived from
	## anything: not whether the player could reach the ball, not whether they
	## had a role in the phase, not what the resolver thought. Twelve volis
	## edged toward every contact for the whole rally because a 2D top-down view
	## once needed the court to look alive.
	##
	## The measurement that settles it: across 60 rallies the resolver publishes
	## explicit positions for 54 of 59 attacks and 36 of 47 defences -- and for
	## **zero** serves and **zero** receptions. So during serve receive, the
	## phase where the drift is most obvious, there was no underlying opinion at
	## all. Every metre of that movement was invented here.
	##
	## What replaces it is nothing. A player moves if the resolver placed them,
	## or if they are the one playing the ball. Otherwise they hold their
	## position and watch it, which is now a thing they can visibly do -- the
	## head tracks the ball and the body turns to travel. Standing still is a
	## legitimate thing for a volleyball player to do, and it is far better than
	## drifting for a reason nobody can name.
	##
	## If serve-receive movement turns out to matter, the fix is for the resolver
	## to publish it, not for playback to make it up.
	_apply_base_positions(plan, event, next_contact)
	_apply_explicit_targets(plan, next_contact.metadata.get("home_phase_targets", {}))
	_apply_explicit_targets(plan, next_contact.metadata.get("opponent_phase_targets", {}))
	## The player who just made this contact goes where their own event said they
	## go afterwards.
	##
	## Only the *next* contact's actor was ever moved, so a `movement_target` on
	## the event being played was published and never read. The server is the
	## visible case: they are staged behind the baseline because that is where a
	## serve is legally struck, the serve event carries the walk-in target, and
	## playback left them standing outside the court until something else
	## happened to move them. With the invented drift gone that became "the
	## server does not move at all until the opposing set".
	var event_actor_id := int(event.actor_id)
	if event_actor_id >= 0 and event.metadata.has("movement_target") \
			and match_court_3d.live_positions.has(event_actor_id):
		_set_plan_target(
			plan, event_actor_id, Vector2(event.metadata["movement_target"])
		)
	var staged_id := int(event.metadata.get("staged_next_actor_id", -1))
	if staged_id >= 0:
		_set_plan_target(
			plan, staged_id, Vector2(event.metadata.get("staged_next_position", action_target))
		)
	var next_actor_id := int(next_contact.actor_id)
	if next_actor_id >= 0:
		var actor_home := _event_is_home(next_contact)
		var actor_start := Vector2(next_contact.metadata.get(
			"movement_start", match_court_3d.live_positions.get(next_actor_id, action_target)
		))
		match_court_3d.ensure_player(
			next_actor_id, actor_start, actor_home,
			str(player_names.get(next_actor_id, next_contact.actor_name)),
			str(player_handedness.get(next_actor_id, "Right")),
			Dictionary(player_physical_profiles.get(next_actor_id, {})),
		)
		_set_plan_target(plan, next_actor_id, action_target)
		## Start the drawn journey where the simulator timed it from, not
		## wherever the previous leg happened to leave this actor standing. The
		## two disagreed most sharply for a blocker who then dug their own
		## deflection: the block phase parked them at the net, the dig was timed
		## from their floor-defence position, and playback drew the whole gap in
		## the 0.24s the deflection was in the air -- about 20 m/s.
		## ...but re-anchoring the journey must not re-anchor the *player*.
		##
		## This used to assign the simulator's start into the plan and then call
		## `set_player_position` with it, which moves the actor there outright
		## before the leg is drawn. Wherever the two disagreed -- which is the
		## entire reason this block exists -- the viewer saw a jump, and the
		## approach is where they disagree most, because a hitter is staged to
		## their approach mark by machinery playback never watched happen.
		##
		## The journey is now drawn from where the player visibly is. The leg
		## still takes the time the simulator gave it, so a disagreement shows up
		## as a slightly different pace rather than as a body arriving somewhere
		## it never travelled to. Pace is a thing the eye forgives; teleporting
		## is not.
		##
		## The gap is recorded rather than absorbed silently: it is a real
		## mismatch between what the resolver timed and what playback can show,
		## and it should stay measurable.
		if next_contact.metadata.has("movement_start") and plan.has(next_actor_id):
			var visible_start := Vector2(match_court_3d.live_positions.get(
				next_actor_id, actor_start
			))
			if visible_start.distance_to(actor_start) > 0.02:
				playback_start_mismatches.append({
					"player_id": next_actor_id,
					"event_type": int(next_contact.event_type),
					"visible_start": visible_start,
					"reported_start": actor_start,
					"distance": visible_start.distance_to(actor_start),
				})
			plan[next_actor_id]["start"] = visible_start
		if next_contact.metadata.has("approach_start_position"):
			plan[next_actor_id]["waypoint"] = Vector2(
				next_contact.metadata["approach_start_position"]
			)
	return plan


## Send the side that is *not* about to play the ball back to its posture.
##
## The one thing playback had no notion of: a position to return to. Every
## player either had an explicit target for the phase or stood exactly where the
## last contact left them, so once the drift was removed a rally went still.
##
## The posture is not invented here. `DefensivePlan.defender_position` and the
## opponent team's `court_position(id, "defense")` already say where each player
## stands on defence, and both already place everybody for the first frame of
## every rally -- the `tactical_court` view has read them all along. Playback
## simply never asked a second time.
##
## Applied first, so anything the resolver said about this specific phase --
## staged blockers, an approach mark, the next contact's own target -- is laid
## over the top rather than fighting it. A base position is where you go when
## nothing more specific is being asked of you.
##
## Only the defending side moves. While the ball is on your own side you are
## setting, approaching or hitting, and the resolver has opinions about all
## three; a floor-defence posture would drag a hitter out of their approach.
## And nobody returns to base during the serve, because the receiving formation
## *is* their posture for that phase and they are already standing in it.
func _apply_base_positions(
	plan: Dictionary, event: RallyEvent, next_contact: RallyEvent
) -> void:
	if active_result == null:
		return
	if event.event_type == RallyEventModel.EventType.SERVE:
		return
	var next_is_home := _event_is_home(next_contact)
	## The side about to play the ball is busy; the other side resets.
	var resting: Dictionary = active_result.opponent_base_positions if next_is_home \
		else active_result.home_base_positions
	for raw_player_id in resting:
		var player_id := int(raw_player_id)
		if not match_court_3d.live_positions.has(player_id):
			continue
		if player_id == int(next_contact.actor_id):
			continue
		_set_plan_target(plan, player_id, Vector2(resting[raw_player_id]))


func _apply_explicit_targets(plan: Dictionary, targets: Dictionary) -> void:
	for raw_player_id in targets:
		_set_plan_target(plan, int(raw_player_id), Vector2(targets[raw_player_id]))


func _set_plan_target(plan: Dictionary, player_id: int, target: Vector2) -> void:
	if not match_court_3d.live_positions.has(player_id):
		return
	var start := Vector2(match_court_3d.live_positions[player_id])
	plan[player_id] = {"start": start, "target": target}


func _event_elevation(event: RallyEvent, player_id: int) -> float:
	if event == null or player_id < 0:
		return 0.0
	var is_actor := int(event.actor_id) == player_id
	match int(event.event_type):
		RallyEventModel.EventType.ATTACK:
			if is_actor:
				return clampf(inverse_lerp(
					0.55, 1.25, float(event.metadata.get("jump_multiplier", 1.0))
				), 0.35, 1.0)
		RallyEventModel.EventType.BLOCK:
			if is_actor or int(event.metadata.get("assist_id", -1)) == player_id:
				return 0.85
		RallyEventModel.EventType.SET:
			if is_actor:
				var capability: Dictionary = event.metadata.get("setter_capability", {})
				match str(capability.get("reach_state", "")):
					"jump":
						return 0.55
					"beyond_reach":
						return 0.70
	return 0.0


func _display_trajectory(
	event: RallyEvent,
	next_contact: RallyEvent,
	trajectory: Dictionary,
) -> Dictionary:
	var display := trajectory.duplicate(true)
	_terminate_at_next_contact(display, next_contact)
	var start_height := _event_contact_height(event)
	var end_height := _event_contact_height(next_contact) \
		if next_contact != null else 0.12
	var rise := maxf(float(trajectory.get(
		"apex_rise_meters", trajectory.get("apex_height_meters", 0.0)
	)), 0.0)
	var rise_scale := 1.0
	var minimum_lift := 0.25
	match int(event.event_type):
		RallyEventModel.EventType.SERVE:
			rise_scale = 1.35
			minimum_lift = 0.42
		RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
			rise_scale = 1.55
			minimum_lift = 0.62
		RallyEventModel.EventType.SET:
			rise_scale = 1.75
			minimum_lift = 0.90
		RallyEventModel.EventType.ATTACK:
			rise_scale = 0.35
			minimum_lift = 0.12
		RallyEventModel.EventType.BLOCK:
			rise_scale = 0.45
			minimum_lift = 0.16
	var apex_height := maxf(start_height, end_height) \
		+ maxf(rise * rise_scale, minimum_lift)
	if event.event_type == RallyEventModel.EventType.SERVE:
		apex_height = maxf(apex_height, NET_HEIGHT_METERS + 0.48)
	elif event.event_type == RallyEventModel.EventType.SET:
		apex_height = maxf(apex_height, NET_HEIGHT_METERS + 1.05)
	elif event.event_type == RallyEventModel.EventType.ATTACK:
		apex_height = maxf(apex_height, start_height + 0.08)
	display["start_height_meters"] = start_height
	display["end_height_meters"] = end_height
	display["apex_height_meters"] = apex_height
	display["height_contract"] = "absolute_3d_presentation"
	return display


## Stop the drawn ball where it was actually next touched.
##
## An event's `end_position` is where its *own* contact was aimed -- for an
## attack, the spot on the far floor the hitter went for. That is real data and
## the simulator is right to keep it. But it is not where the ball got to when
## somebody intercepted it on the way, and playback was drawing the whole aimed
## flight regardless.
##
## Measured across 736 consecutive contact pairs, the damage is confined to
## exactly the two pairs where an interception happens:
##
##     Serve -> Reception     0.00 m
##     Reception -> Set       0.00 m
##     Set -> Attack          0.00 m
##     Attack -> Block        5.68 m mean, 10.76 m worst
##     Block -> Defense       3.29 m mean, 11.16 m worst
##     Defense -> Set         0.11 m
##
## So a blocked spike drew its ball past the block, on to a floor target several
## metres away, and the block then began from the net -- which reads as the ball
## teleporting backward, or as the next contact happening somewhere nobody is
## standing. Twenty-seven per cent of all contact pairs were discontinuous.
##
## Retargeting is a *presentation* decision and belongs here rather than in the
## resolver: the aimed landing point is a fact about the attack, and where the
## ball actually got to is a fact about the rally. Both stay true.
##
## The control point moves with the end. This is a quadratic Bezier, so leaving
## the control where it was would swing the shortened arc wide of both contacts
## -- the ball would finish in the right place having taken a route it never
## took. Rescaling it along the original curve keeps the shape of the flight and
## simply cuts it short, which is what an interception does.
func _terminate_at_next_contact(
	display: Dictionary, next_contact: RallyEvent
) -> void:
	if next_contact == null:
		## Nothing touched it next, so the aimed landing point is the truth: this
		## is a ball hitting the floor.
		return
	if not next_contact.success:
		## And a contact that *failed* is a ball nobody touched. A defender who
		## could not reach the line attack after moving a metre did not stop it;
		## dragging the flight to their feet drew the ball teleporting into
		## somebody who visibly never played it, then bouncing off nothing.
		## The aimed landing point is where it actually went.
		return
	terminate_trajectory(display, Vector2(next_contact.start_position))


## The geometry, on its own so it can be checked without a screen to run it in.
static func terminate_trajectory(display: Dictionary, touched: Vector2) -> void:
	var start := Vector2(display.get("start_position", Vector2(0.5, 0.5)))
	var aimed := Vector2(display.get("end_position", start))
	if aimed.distance_to(touched) < 0.0005:
		return
	var control := Vector2(display.get("control_position", start.lerp(aimed, 0.5)))
	## Where along the aimed flight the interception sits, so the arc is cut at
	## the same fraction its control point is rescaled by.
	var travelled := start.distance_to(aimed)
	var share := clampf(
		start.distance_to(touched) / maxf(travelled, 0.0001), 0.05, 1.0
	)
	display["end_position"] = touched
	display["control_position"] = start.lerp(control, share)
	## The time has to come down with the distance.
	##
	## Cutting the path and keeping the duration was the whole of "the ball
	## freezes in place": a spike intercepted 30% of the way to its floor target
	## still spent the full flight covering that third, so it crawled from the
	## hitter to the block over most of a second and then sat there. The ball is
	## the same ball travelling at the same speed; it simply stops sooner.
	if display.has("duration"):
		display["duration"] = maxf(float(display["duration"]) * share, 0.08)


func _event_contact_height(event: RallyEvent) -> float:
	if event == null or event.actor_id < 0:
		return 0.12
	var profile: Dictionary = player_physical_profiles.get(int(event.actor_id), {})
	var height_meters := float(profile.get("height_cm", 188.0)) / 100.0
	var wingspan_meters := float(profile.get("wingspan_cm", 191.0)) / 100.0
	var standing_reach := float(profile.get(
		"standing_reach_meters",
		height_meters * 1.215 + (wingspan_meters - height_meters) * 0.32,
	))
	var jumping_reach := float(profile.get(
		"jumping_reach_meters", standing_reach + 0.52
	))
	match int(event.event_type):
		RallyEventModel.EventType.SERVE:
			var serve_style := str(event.metadata.get("serve_style", "Standing"))
			return lerpf(standing_reach, jumping_reach, 0.68) \
				if serve_style.contains("Jump") else standing_reach * 0.92
		RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
			return clampf(height_meters * 0.52, 0.72, 1.16)
		RallyEventModel.EventType.SET:
			var capability: Dictionary = event.metadata.get("setter_capability", {})
			var reach_state := str(capability.get("reach_state", "standing"))
			if reach_state in ["jump", "beyond_reach"]:
				return lerpf(standing_reach, jumping_reach, 0.58)
			return standing_reach * 0.97
		RallyEventModel.EventType.ATTACK:
			var jump_effort := clampf(inverse_lerp(
				0.55, 1.25, float(event.metadata.get("jump_multiplier", 1.0))
			), 0.35, 1.0)
			return lerpf(standing_reach, jumping_reach, jump_effort)
		RallyEventModel.EventType.BLOCK:
			return jumping_reach * 0.96
	return float(event.metadata.get("contact_height_meters", 1.0))


## What the last rally's geometry actually looked like, as numbers.
##
## The consumer `playback_start_mismatches` never had. Every entry is a contact
## whose actor was standing somewhere other than where the resolver timed their
## journey from -- so a summary of them is a direct measure of how often a
## player is drawn playing a ball from a position they were never at.
##
## Returned rather than printed so a harness can assert on it and a debug view
## can show it, which is the difference between an instrument and a habit.
func playback_geometry_report() -> Dictionary:
	if playback_start_mismatches.is_empty():
		return {"count": 0, "worst_meters": 0.0, "mean_meters": 0.0, "by_event": {}}
	var total := 0.0
	var worst := 0.0
	var by_event := {}
	for entry in playback_start_mismatches:
		var distance := float(entry.get("distance", 0.0))
		total += distance
		worst = maxf(worst, distance)
		var key := int(entry.get("event_type", -1))
		by_event[key] = int(by_event.get(key, 0)) + 1
	## The stored distance is in normalised court units; metres is what anybody
	## reading this actually wants, and the court is 9 m by 18 m.
	var scale := 13.5
	return {
		"count": playback_start_mismatches.size(),
		"worst_meters": worst * scale,
		"mean_meters": total / float(playback_start_mismatches.size()) * scale,
		"by_event": by_event,
	}


func _event_is_home(event: RallyEvent) -> bool:
	var side := str(event.metadata.get("side", ""))
	if side == "home":
		return true
	if side == "opponent":
		return false
	return match_court_3d.home_player_ids.has(int(event.actor_id))


## Where the next real contact sits, or -1. Split out from
## `_next_contact_event` so a caller that needs the one *after* it can carry on
## scanning from the right place rather than guessing at an offset -- the
## sequence contains `SET_DECISION` and `POINT` entries that are not contacts,
## so "index + 1" is not the next contact and "index + 2" is not the one after.
func _next_contact_index(events: Array[Resource], start_index: int) -> int:
	for index in range(start_index, events.size()):
		var candidate := events[index] as RallyEvent
		if candidate == null:
			continue
		if candidate.event_type in [
			RallyEventModel.EventType.SET_DECISION,
			RallyEventModel.EventType.POINT,
		]:
			continue
		return index
	return -1


func _next_contact_event(events: Array[Resource], start_index: int) -> RallyEvent:
	for index in range(start_index, events.size()):
		var candidate := events[index] as RallyEvent
		if candidate == null:
			continue
		if candidate.event_type in [
			RallyEventModel.EventType.SET_DECISION,
			RallyEventModel.EventType.POINT,
		]:
			continue
		return candidate
	return null


func _show_event_text(event: RallyEvent, event_index: int, event_count: int) -> void:
	event_label.text = "%02d / %02d   %s   t=%.2fs" % [
		event_index + 1, event_count, event.type_name().to_upper(),
		float(event.metadata.get("event_time", 0.0)),
	]
	caption_label.text = event.headline if not event.headline.is_empty() else event.type_name()
	detail_label.text = event.detail


func _build_player_names(events: Array[Resource]) -> void:
	player_names.clear()
	for event_resource in events:
		var event := event_resource as RallyEvent
		if event == null or event.actor_id < 0 or event.actor_name.is_empty():
			continue
		player_names[int(event.actor_id)] = event.actor_name


func _fallback_positions_from_events(events: Array[Resource]) -> Dictionary:
	var home := {}
	var opponent := {}
	for event_resource in events:
		var event := event_resource as RallyEvent
		if event == null or event.actor_id < 0:
			continue
		var target := opponent if str(event.metadata.get("side", "")) == "opponent" else home
		if not target.has(int(event.actor_id)):
			target[int(event.actor_id)] = event.start_position
	return {"home": home, "opponent": opponent}


func _populate_speeds() -> void:
	speed_option.clear()
	for speed in [0.25, 0.5, 1.0, 1.5, 2.0]:
		speed_option.add_item("%s×" % str(speed))
		speed_option.set_item_metadata(speed_option.item_count - 1, speed)
	_select_speed(1.0)


func _select_speed(speed: float) -> void:
	for index in range(speed_option.item_count):
		if is_equal_approx(float(speed_option.get_item_metadata(index)), speed):
			speed_option.select(index)
			return


func _speed_changed(index: int) -> void:
	playback_speed = float(speed_option.get_item_metadata(index))


func _toggle_pause() -> void:
	if not playback_active:
		return
	playback_paused = not playback_paused
	pause_button.text = "Resume" if playback_paused else "Pause"


func _skip() -> void:
	skip_requested = true
	playback_paused = false


func _replay() -> void:
	if active_result != null:
		load_and_play_rally(active_result, playback_speed)


func _cycle_camera() -> void:
	camera_button.text = match_court_3d.cycle_camera()


func _close() -> void:
	playback_generation += 1
	playback_active = false
	playback_paused = false
	skip_requested = true
	match_court_3d.ball_actor.reset_flight()
	match_court_3d.reset_player_poses()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	close_requested.emit()
