class_name MatchScreen
extends Control

signal close_requested

const RallyEventModel := preload("res://scripts/models/rally_event.gd")

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
## Legs playback had to draw faster than a body moves. Only the contact leg is
## ever allowed to overspeed -- see `_pace_plan` -- so a growing list here is the
## same symptom as the array above, seen from the other end: the drawn position
## has drifted far enough from the timed one that the touch cannot be reached
## honestly.
var playback_leg_overspeed: Array[Dictionary] = []
## Diagnostic: send everyone but the ball-handler to their own baseline.
## Toggled with M during playback; see `_apply_movement_proof`.
var movement_proof: bool = false
var playback_paused: bool = false
var skip_requested: bool = false
var playback_active: bool = false
var player_names: Dictionary = {}
var player_handedness: Dictionary = {}
var player_physical_profiles: Dictionary = {}
## The solved platform surface per contact, keyed by the event itself.
##
## Cached because the surface is a property of two flights and nothing else, so
## it is the same on every frame of a contact, while `PlatformAim.relative` --
## which needs the body's facing and therefore changes as the passer turns -- is
## not and is recomputed. Building the two drawn flights costs a deep copy each,
## and doing that per posed player per frame to get an answer that cannot have
## changed is the kind of work a replay cannot afford.
var platform_surfaces: Dictionary = {}


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
		KEY_M:
			movement_proof = not movement_proof
			event_label.text = "MOVEMENT PROOF %s" % ["ON" if movement_proof else "OFF"]
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
	## Keyed by event, and these are a new rally's events, so the old entries
	## could never be hit -- but they would hold every event of every rally played
	## this session alive for as long as the screen is open.
	platform_surfaces.clear()
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
	playback_leg_overspeed.clear()
	_previously_placed.clear()
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
	## The rally's own cues, taken off the result rather than recompiled, so a
	## replay shows the thoughts the rally was resolved with.
	match_court_3d.set_cognition_stream(active_result.cognition_cues)
	## How far into the rally's own clock the drawing has already reached. A
	## flight is drawn for its physics duration rather than for the gap to the
	## next event, so the two run on different clocks and the difference is time
	## a later event must not charge for a second time.
	var drawn_until := -INF
	## The ball starts the rally in a server's hand, not on the floor, but no
	## outro is owed before the first flight has been drawn.
	_ball_end_height_meters = BALL_REST_HEIGHT_METERS
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
		var movement_contact: RallyEvent = null
		if next_index >= 0:
			next_contact = events[next_index] as RallyEvent
			## One further ahead, because a block has to be *in the air* by the
			## time the hitter swings -- see `_apply_contact_poses`.
			after_next = _next_contact_event(events, next_index + 1)
			## And the first contact that actually played the ball, which is the
			## one the other ten are moving toward. Usually the same event; it
			## differs exactly when the next contact never touched it.
			movement_contact = next_contact
			var played_index := next_index
			while played_index >= 0 and not events[played_index].success:
				played_index = _next_contact_index(events, played_index + 1)
			if played_index >= 0:
				movement_contact = events[played_index] as RallyEvent
		if not trajectory.is_empty():
			drawn_until = maxf(
				drawn_until,
				float(event.metadata.get("physical_time", 0.0)) + await _play_flight(
					event, next_contact, movement_contact, after_next, trajectory,
					event_index, events.size(), generation
				),
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
			##
			## **And time the flight already spent is not spent twice.**
			##
			## Measured over 200 rallies: 58.8 s of playback had a ball that was
			## not moving, 6.0% of the total, and *every second of it* was a
			## BLOCK the ball flew past -- 122 of them, 0.48 s each and up to
			## 1.72 s. The attack's flight is drawn from the attack's stamp for
			## the trajectory's own duration, which already carries the ball to
			## where it lands; the failed block's window then re-draws the same
			## interval with the ball parked at that landing. That is the ball
			## freezing on the floor, and it is also where a defender finds the
			## time for two or three sets of microadjustments before a dig.
			##
			## So a window has two parts and only the second is this one's to
			## draw: the flight, whose length is physics, and the aftermath,
			## which is what is left over. Where nothing is left over the event
			## costs nothing, which is the same rule the paragraph above already
			## applies to simultaneous contacts.
			var window := _gap_to_next(events, event_index)
			## **The last contact of a rally is not an aftermath window.**
			##
			## Aftermath is the leftover *between two events*. There is no next
			## event here, so there is nothing the flight can have drawn ahead of
			## -- and subtracting it anyway charged the outro to zero and ended
			## playback the instant the final contact resolved. That is the point
			## ending before the ball is drawn hitting the floor, and it is mine:
			## the flight/aftermath split introduced it by applying a
			## between-events rule to the one window that has no "between".
			##
			## Not the whole of what the ball-decides-the-end principle asks for
			## -- see `BACKLOG.md` -- but the outro exists again.
			if event.metadata.has("physical_time") and next_contact != null:
				window = aftermath_seconds(
					float(event.metadata["physical_time"]), window, drawn_until
				)
			elif next_contact == null:
				## **The rally is over when the ball is down.**
				##
				## The last window was a flat 0.38 s whatever the ball was doing,
				## so a point could be called while the ball was still in the
				## air -- reported as tools ending before the ball is drawn
				## hitting the floor. It now lasts at least as long as the ball
				## needs to fall from wherever the final flight left it. Where
				## that is already the floor the outro is unchanged, which is
				## most rallies and is why this had to be measured off the real
				## drawn flight rather than guessed at.
				window = maxf(window, settle_seconds(_ball_end_height_meters))
			if window <= 0.0:
				continue
			await _play_contact_pulse(event, next_contact, window, generation)
	match_court_3d.ball_actor.hold_at_rest()
	match_court_3d.clear_cognition()


## Where the ball rests, and what it falls under. Named here rather than reached
## for through `BallPresentation` so the settle rule reads as one thing.
const BALL_REST_HEIGHT_METERS: float = 0.12
const BALL_GRAVITY_MPS2: float = 9.81

## Where the last drawn flight left the ball, in metres.
var _ball_end_height_meters: float = BALL_REST_HEIGHT_METERS


## How long a ball left at this height takes to reach the floor.
##
## Free fall, because a ball nobody is going to touch again is not doing
## anything else. Zero once it is within a ball's width of resting, so a rally
## that ends on the floor -- which is most of them -- keeps the outro it had and
## does not gain a pause.
##
## Static and pure so the suite can hold it without a court to run it in.
static func settle_seconds(end_height_meters: float) -> float:
	var drop := end_height_meters - BALL_REST_HEIGHT_METERS
	if drop <= 0.05:
		return 0.0
	return sqrt(2.0 * drop / BALL_GRAVITY_MPS2)


## What is left of an event's window once a flight has already drawn part of it.
##
## Static and pure so the suite can hold the rule without a court to run it in.
## Measured over 200 rallies before it existed: 58.8 s of playback, 6.0% of the
## total, drew a ball that was not moving, and every second of it was a block
## the ball flew past -- a window that had already been drawn as flight and was
## then drawn again as stillness. Afterwards, 0.0 s. Not reduced: gone, because
## the overlap was total.
static func aftermath_seconds(
	event_start: float, window_seconds: float, drawn_until: float
) -> float:
	return maxf(
		event_start + window_seconds - maxf(event_start, drawn_until), 0.0
	)


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
	movement_contact: RallyEvent,
	after_next: RallyEvent,
	trajectory: Dictionary,
	event_index: int,
	event_count: int,
	generation: int,
) -> float:
	## Read from the *display* trajectory, not the source one. A flight cut short
	## at an interception carries a shortened duration, and taking the original
	## would spend the full time on the shortened path.
	var display_trajectory := _display_trajectory(event, next_contact, trajectory)
	var duration := clampf(float(display_trajectory.get("duration", 0.5)), 0.08, 3.5)
	## **Where this flight leaves the ball.**
	##
	## The hook, and it is one line because the number was already here.
	## `BallPresentation` writes `end_height_meters` onto every display
	## trajectory; it is computed at playback time rather than stamped on the
	## event, which is why looking for it in event metadata found nothing and why
	## a probe that reconstructed it beside playback -- with empty profiles and
	## the wrong next contact -- produced balls eight metres in the air. This is
	## the real one: the same dictionary the ball is actually drawn from.
	_ball_end_height_meters = float(
		display_trajectory.get("end_height_meters", BALL_REST_HEIGHT_METERS)
	)
	## **Not `next_contact`.**
	##
	## The plan reads its phase targets off the contact it is moving toward, and
	## a block the ball flew past is not a contact anyone moves toward -- the
	## floor is already reading the ball behind it. While the failed block had a
	## window of its own that did not matter, because the defence's approach was
	## drawn in *that* window. Now that the window is charged against the flight
	## that already covered it, the approach has to move here or the defender
	## teleports into the dig, which is the regression this whole seam produced
	## the first time.
	var movement_plan := _build_movement_plan(
		event, movement_contact if movement_contact != null else next_contact,
		duration,
	)
	var elapsed := 0.0
	match_court_3d.ball_actor.reset_flight()
	match_court_3d.begin_ball_flight(display_trajectory, float(event.quality))
	while elapsed < duration:
		if generation != playback_generation or skip_requested:
			break
		if playback_paused:
			await get_tree().process_frame
			continue
		elapsed += get_process_delta_time() * playback_speed
		var progress := clampf(elapsed / duration, 0.0, 1.0)
		match_court_3d.set_ball_trajectory_sample(display_trajectory, progress)
		## Null on the terminal ball -- there is no next contact to hold still.
		match_court_3d.apply_movement_plan(
			movement_plan, progress, duration,
			int(next_contact.actor_id) if next_contact != null else -1,
		)
		_apply_contact_poses(event, next_contact, after_next, progress, duration)
		_sample_cognition(event, next_contact, progress, duration)
		progress_bar.value = (
			(float(event_index) + progress) / maxf(float(event_count), 1.0)
		) * 100.0
		await get_tree().process_frame
	match_court_3d.finish_movement_plan(movement_plan, duration)
	match_court_3d.reset_player_poses()
	## Returned so the caller knows how much of the rally's clock this leg
	## covered. A flight runs on physics and the events run on stamps; without
	## this the next event has no way to tell whether its window is aftermath or
	## a repeat of what was just drawn.
	return duration


## A window the ball spends no time on, but the players do.
##
## **This is where off-ball movement was going.** Everything the resolver
## publishes about where volis should be was read by `_build_movement_plan`, and
## `_build_movement_plan` was only ever called from `_play_flight` -- the branch
## for an event carrying an outgoing trajectory. A contact without one comes here
## instead, and here nobody was placed at all: `reset_player_poses` and a pose
## for the actor, and twelve bodies standing exactly where the previous leg left
## them for the entire gap.
##
## That is not a rare branch. A block that stops the ball dead carries no
## outgoing trajectory and **79.3%** of blocks are that block, so the window
## between an attack being walled and the dig that follows -- the single moment
## in a rally when the defending side most obviously has somewhere to be -- was
## drawn frozen. Then the next flight began with the digger already at the ball,
## because their leg had been planned across a window that no longer existed.
## Reported from a screenshot as "no one moves until the blockers land, then the
## receiver picks up the pass; it teleports into their arms", which is an exact
## description of a plan that is built and never applied.
##
## The gap is a real span of time taken from `physical_time`; there is no reason
## it should be the one span nobody walks during.
func _play_contact_pulse(
	event: RallyEvent, next_contact: RallyEvent, duration: float, generation: int
) -> void:
	var movement_plan := _build_movement_plan(event, next_contact, duration)
	var carry := _carry_trajectory(event, next_contact, duration)
	if not carry.is_empty():
		match_court_3d.ball_actor.reset_flight()
		match_court_3d.begin_ball_flight(carry, float(event.quality))
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
		if not carry.is_empty():
			match_court_3d.set_ball_trajectory_sample(carry, progress)
		## Before the poses, exactly as `_play_flight` orders it: a pose is drawn
		## on a body that has already been placed for this frame.
		## Null on the terminal ball -- there is no next contact to hold still.
		match_court_3d.apply_movement_plan(
			movement_plan, progress, duration,
			int(next_contact.actor_id) if next_contact != null else -1,
		)
		_sample_cognition(event, next_contact, progress, duration)
		var direction := event.end_position - event.start_position
		## A block that stopped the ball dead has no outgoing trajectory, so it
		## arrives here rather than in `_apply_contact_poses` -- and that is
		## **79.3%** of all blocks, measured over 600 rallies. Every one of them was
		## drawn with `phase = progress` running 0 to 1 and elevation
		## `sin(progress * PI)`, which is a whole jump: the wall went up and came
		## down again, having already gone up during the set's flight and held
		## through the attack's. That is the block replaying itself, and the fix
		## that landed in `_apply_contact_poses` never reached this path because
		## this path only draws blocks the *other* 20.7% of the time.
		##
		## Here the wall is already up. This window is the withdraw, so it starts
		## where the hold ended, and both blockers come down together.
		if event.event_type == RallyEventModel.EventType.BLOCK:
			var phase := _block_withdraw_phase(progress, duration)
			var lift := BlockBiomechanics.elevation_at(phase)
			for blocker_id in [
				int(event.actor_id), int(event.metadata.get("assist_id", -1)),
			]:
				if blocker_id < 0:
					continue
				match_court_3d.set_player_pose(
					blocker_id, int(event.event_type),
					_event_elevation(event, blocker_id) * lift,
					phase, direction, true,
					_contact_posture(event),
					_contact_recovery(event),
					_action_context(event, blocker_id),
				)
			await get_tree().process_frame
			continue
		var peak := _event_elevation(event, int(event.actor_id))
		match_court_3d.set_player_pose(
			int(event.actor_id), int(event.event_type),
			peak * sin(progress * PI), progress, direction, true,
			_contact_posture(event),
			_contact_recovery(event),
			_action_context(event, int(event.actor_id)),
		)
		await get_tree().process_frame
	match_court_3d.finish_movement_plan(movement_plan, duration)


## The ball's own journey across a window nobody published a trajectory for.
##
## A block that stops the ball dead publishes no outgoing flight, so during the
## gap between it and the dig that follows the ball was not sampled at all: it
## held the last position the previous flight left it in, and then the next
## flight began somewhere else. That is the reported "the ball is clearly on the
## floor, then the receiver picks up the pass; it teleports into their arms" --
## the deflection off the block was never drawn, only its two endpoints, one of
## them late.
##
## Built from the two endpoints the events already carry: where this contact left
## the ball, and where the next one picks it up. Passed through
## `BallPresentation.display_trajectory` rather than lerped, so it gets the same
## gravity-true height curve as every other drawn flight -- launched from the
## blocker's reach and arriving at the digger's, which is what a ball dropping
## off a wall does. Sampling it also gives the window a moving ball for every
## head on the court to follow, which `_watch_the_ball` could not do while
## nothing was being sampled.
##
## Empty when the rally ends here, when the two endpoints coincide, or when the
## window has no time in it. An empty result leaves the ball exactly as it was,
## which is the previous behaviour.
func _carry_trajectory(
	event: RallyEvent, next_contact: RallyEvent, duration: float
) -> Dictionary:
	if next_contact == null or duration <= 0.0:
		return {}
	## **Only a contact that actually touched the ball moves it.**
	##
	## Without this the carry fired on every block, including the ones the ball
	## went past untouched -- and a block that never touched it has an
	## `end_position` back where the attack was aimed, so the window redrew the
	## whole spike. Reported from a rally as "the spike trajectory resolves almost
	## fully with no floor defense movement, then the block event resolves which
	## repeats the trajectory": one flight, drawn twice, because playback assumed
	## a deflection that had not happened.
	##
	## The resolver already says. `block_contact_kind` is empty for a block the
	## ball passed, and the attack's own flight carries on to the defender exactly
	## as it did before this window learned to draw anything.
	if int(event.event_type) == RallyEventModel.EventType.BLOCK \
			and str(event.metadata.get("block_contact_kind", "")).is_empty():
		return {}
	var from := Vector2(event.end_position)
	var to := Vector2(next_contact.start_position)
	if from.distance_to(to) < 0.002:
		return {}
	return BallPresentation.display_trajectory(
		event, next_contact,
		{
			"start_position": from,
			"end_position": to,
			"control_position": from.lerp(to, 0.5),
			"duration": duration,
		},
		player_physical_profiles,
	)


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


## Step 2: the geometry gets a vote on what the contact looked like.
##
## The resolver classifies a contact from alignment and edge-ratio thresholds and
## owns what it *cost*. Two of its four branches cannot fire: measured over 1447
## contacts, `reaching` is 0.0% of receptions -- the reach margin runs from 3.1 m
## to 4.8 m and the branch needs it below zero -- and `off-axis` is 2.5% of digs,
## against a body-penalty bound of 0.045 on a term the constant's own comment
## records as running 0.01 to 0.04. Both are thresholds outside the distribution
## they cut, and the consequence on screen is that a passer is drawn square to a
## ball arriving over their shoulder.
##
## This does not touch the classification the simulator scores against. It is a
## second, purely geometric opinion about what the contact *looked like*, taken
## only when it is more specific than the one recorded -- a body that had to give
## up more than a degree of platform was not square, whatever the alignment term
## said. The resolver stays the authority on the outcome; the drawing stops
## claiming a squared-up pass that never happened.
func _contact_posture(event: RallyEvent) -> String:
	if event == null:
		return "planted"
	var recorded := str(event.metadata.get("contact_posture", "planted"))
	## **A contact that never happened is not drawn square.**
	##
	## Reported from a rally whose caption read "Wonsik cannot reach the short
	## court attack after moving 1.2m" -- a ball nobody touched -- over a body
	## drawn in the platform pose, so the viewer could not tell a missed ball
	## from a shanked one. Those are different events and the caption and the
	## drawing were describing different ones.
	##
	## Nothing here asked `event.success`. `contact_posture` is on every contact
	## whether or not it was made, so the pose selector treated a whiff exactly
	## like a dig. The extension is the honest shape for it -- the defender did
	## reach, they simply did not arrive -- and it is what the resolver already
	## calls these balls: `reaching` fires on a *negative* margin, which is a
	## ball beyond the range, which is this.
	##
	## Not the whole of 13a. A reach that misses and a reach that digs still
	## share a pose, and telling them apart wants the ball's absence to be
	## visible in the body rather than only in the ball. Logged.
	if not event.success:
		return "reaching"
	## **A ball taken at the edge of the range is a reach.**
	##
	## The resolver reaches for `reaching` when `reach_margin_meters` is
	## *negative* -- a ball outside the defender's range, which is a ball they
	## did not get. Measured over 300 rallies and 447 floor contacts, that fires
	## on exactly the 26.0% of contacts whose margin is below zero, and the two
	## figures matching to a tenth is the tell: the pose is reserved for
	## contacts that by definition failed.
	##
	## A contact made at *full stretch* is the pose's real subject and it lives
	## just the other side of that line: 33 of 447 contacts, 7.4%, land between
	## 0 and 0.5 m of margin. Those are the ones drawn shuffling into a square
	## platform when a body would have gone and got it -- which is the reported
	## defect, a defender adjusting with small steps where a reach belongs.
	##
	## Widened here rather than in the classifier on purpose. `posture` is an
	## input to `_contact_recovery_state`, so moving the resolver's band would
	## move rally outcomes to fix a drawing. This is the same second-opinion
	## seam `posture_for` already occupies, and it changes nothing but the pose.
	if _within_stretch(event, recorded):
		return "reaching"
	return PlatformAim.posture_for(_platform_aim(event), recorded)


## How much margin still counts as being at full stretch, in metres.
const REACH_STRETCH_METERS: float = 0.5


## Whether this contact was taken at the edge of the range.
##
## Only upgrades. A contact the resolver already called `reaching` keeps it, and
## one with no published margin is left to the geometric opinion -- 17 of 464
## contacts carry no margin and guessing on them would be inventing a pose from
## an absence.
func _within_stretch(event: RallyEvent, recorded: String) -> bool:
	return is_full_stretch(
		recorded,
		event.metadata.has("reach_margin_meters"),
		float(event.metadata.get("reach_margin_meters", 0.0)),
	)


## Static and pure so the suite can hold the band without a court to run it in.
static func is_full_stretch(
	recorded: String, has_margin: bool, margin_meters: float
) -> bool:
	if recorded == "reaching":
		return true
	if not has_margin:
		return false
	return margin_meters >= 0.0 and margin_meters < REACH_STRETCH_METERS


## Presentation inputs carried by the resolved event. The actor never looks up
## a live roster and never infers a signature from a caption, so replay remains
## a drawing of what happened even after a lineup or confidence state changes.
func _action_context(event: RallyEvent, actor_id: int) -> Dictionary:
	if event == null:
		return {}
	var context := {}
	if event.event_type in [
		RallyEventModel.EventType.SERVE, RallyEventModel.EventType.ATTACK,
	]:
		context["action_power"] = clampf(float(event.metadata.get(
			"action_power",
			event.metadata.get("attack_effectiveness", event.quality),
		)), 0.0, 1.0)
	## The wall's jump, carried whole rather than per actor: the court indexes it
	## by player id because two blockers in one wall have two different jumps, and
	## slicing it here would hand each body only its own and lose that.
	##
	## Added because the court was already reading this key and nothing put it
	## here -- a plumb that arrives and changes nothing looks exactly like one
	## that works, which is the failure the block-timing gate exists to catch and
	## which had reappeared one layer further up.
	if int(event.event_type) == RallyEventModel.EventType.BLOCK:
		context["block_jump_timing"] = event.metadata.get("block_jump_timing", {})
	## Which of the three second-contact actions the rig should draw. Both keys,
	## because the posture says whether they left the floor and only the reason
	## says whether a grounded set was taken above the head or off the forearms.
	##
	## The plumb the block's jump timing needed one commit and did not get is the
	## warning here: `block_jump_timing` was published by the resolver, read by
	## the court, and never put in this dictionary, so it changed nothing while
	## looking connected. `tools/set_posture_shot.tscn` is what says this one
	## arrived.
	if int(event.event_type) == RallyEventModel.EventType.SET:
		context["set_posture"] = str(event.metadata.get("set_posture", ""))
		context["set_posture_reason"] = str(
			event.metadata.get("set_posture_reason", "")
		)
		## Which side of the setter the ball left on. Playback cannot recover
		## this on its own: it faces the rig at wherever the ball went, so from
		## here a back set and a front set are the same picture.
		context["back_set"] = bool(event.metadata.get("back_set", false))
	var signature_actor := int(event.metadata.get("signature_actor_id", event.actor_id))
	if signature_actor == actor_id:
		var move := str(event.metadata.get("signature_move", ""))
		if not move.is_empty():
			context["signature_move"] = move
			context["signature_charge"] = clampf(float(
				event.metadata.get("signature_charge", 1.0)
			), 0.0, 1.0)
			context["signature_succeeded"] = bool(
				event.metadata.get("signature_succeeded", false)
			)
	return context


## Give every body on the court a stance, including the ten nothing else poses.
##
## `_apply_contact_poses` reaches at most five actors -- the contact, its assist,
## the next contact, its assist, and an early block. The other seven get
## `reset_player_poses()` and a gait, and the gait had exactly one floor pose: a
## defender's crouch. Measured over eight rallies, that crouch was fully on
## screen for 66.5% of the frames within a metre and a half of the net, which is
## a front-row voli waiting to block in a passer's posture.
##
## The side that plays the ball next is the side that might have to play it, so
## that is what "defending" is keyed on rather than possession or rotation. It
## also answers the other half of the report from the opposite direction: the
## *serving* team is not that side, so their back row stands and watches the
## serve go over instead of crouching for a ball they have no part in.
func _apply_ready_stances(event: RallyEvent, next_contact: RallyEvent) -> void:
	## The contact that decides who is about to touch the ball. `next_contact` is
	## null on the rally's last event, and then the current one is the truthful
	## answer -- the ball is still on the side that just played it.
	var deciding := next_contact if next_contact != null else event
	if deciding == null:
		return
	var playing_side_is_home := match_court_3d.home_player_ids.has(
		int(deciding.actor_id)
	)
	for raw_id in match_court_3d.player_actors:
		var player_id := int(raw_id)
		match_court_3d.set_player_stance(player_id, ReadyStance.choose(
			match_court_3d.at_the_net(player_id),
			match_court_3d.home_player_ids.has(player_id) == playing_side_is_home,
		))


func _apply_contact_poses(
	event: RallyEvent,
	next_contact: RallyEvent,
	after_next: RallyEvent,
	progress: float,
	window_seconds: float = 1.0,
) -> void:
	match_court_3d.reset_player_poses()
	_apply_ready_stances(event, next_contact)
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
			_platform_aim(event),
			_action_context(event, event_actor),
		)
	var event_assist := int(event.metadata.get("assist_id", -1))
	if event_assist >= 0 and event.event_type == RallyEventModel.EventType.BLOCK:
		var assist_phase := _block_withdraw_phase(progress, window_seconds)
		match_court_3d.set_player_pose(
			event_assist, int(event.event_type),
			_event_elevation(event, event_assist)
				* BlockBiomechanics.elevation_at(assist_phase),
			assist_phase, event_direction, true,
			"planted", "platform", _action_context(event, event_assist),
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
		var next_phase := _block_hold_phase(progress, window_seconds) \
			if next_is_block else progress - 1.0
		var next_lift := BlockBiomechanics.elevation_at(next_phase) \
			if next_is_block else incoming_weight
		match_court_3d.set_player_pose(
			next_actor, int(next_contact.event_type),
			next_peak * next_lift, next_phase, next_direction, true,
			_contact_posture(next_contact), _contact_recovery(next_contact),
			_action_context(next_contact, next_actor),
		)
	var next_assist := int(next_contact.metadata.get("assist_id", -1))
	if next_assist >= 0 and next_is_block:
		## Through the same helper as the actor above. These were two call sites
		## computing the same phase independently, and when the actor's mapping
		## was corrected this one was not -- so the second blocker went on
		## running the whole hold-and-withdraw during the attack's flight and
		## then started again for the deflection, replaying the wall while the
		## caption still read "block forms".
		var assist_hold := _block_hold_phase(progress, window_seconds)
		match_court_3d.set_player_pose(
			next_assist, int(next_contact.event_type),
			_event_elevation(next_contact, next_assist)
				* BlockBiomechanics.elevation_at(assist_hold),
			assist_hold, next_direction, true,
			"planted", "platform", _action_context(next_contact, next_assist),
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
## **Paced by the body, not by the ball.**
##
## This was `progress * HOLD_END`: the rise stretched across whatever the
## attack's flight happened to last. On a fast swing that is about right; on a
## slow roll shot it is a blocker taking a second and a half to leave the floor
## and then standing up there. A jump is not a duration the ball gets to choose,
## which is `BlockPhaseModel`'s whole argument, and the withdraw below has been
## paced in real seconds all along -- only the rise was still on the ball's
## clock.
##
## Clamped, so past the rise the blocker is at the top rather than still going
## up. Coming *down* before the ball arrives is the rest of the fix and it needs
## the hold window to be able to enter the withdraw, which is a restructure this
## is not; the hover is shortened here rather than removed.
func _block_hold_phase(progress: float, window_seconds: float) -> float:
	var elapsed := progress * maxf(window_seconds, 0.0001)
	var rise := clampf(
		elapsed / (BlockPhaseModel.JUMP_SECONDS * BlockPhaseModel.RISE_SHARE),
		0.0, 1.0,
	)
	return rise * BlockBiomechanics.HOLD_END


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
			"planted", "platform", _action_context(after_next, blocker_id),
		)


func _build_movement_plan(
	event: RallyEvent, next_contact: RallyEvent, window_seconds: float = 0.0
) -> Dictionary:
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
	_apply_cheat_steps(plan, action_target, next_contact)
	_hold_airborne_blocker(plan, event)
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
		## The corner a setter had to turn round somebody standing in the way.
		## The resolver charged the leg for the bend already; without this the
		## drawn run is a straight line at a pace it never explains.
		elif next_contact.metadata.has("navigation_waypoint"):
			plan[next_actor_id]["waypoint"] = Vector2(
				next_contact.metadata["navigation_waypoint"]
			)
	## Who the resolver named this window, remembered for the next one.
	_previously_placed = {}
	for key in ["home_phase_targets", "opponent_phase_targets"]:
		for raw_player_id in Dictionary(next_contact.metadata.get(key, {})):
			_previously_placed[int(raw_player_id)] = true
	_pacing_event_type = int(next_contact.event_type)
	_separate_plan(plan, next_actor_id)
	_pace_plan(plan, window_seconds, next_actor_id)
	## After pacing, not before: `_set_plan_target` writes a fresh entry with no
	## `seconds` key, so a proof leg is deliberately unpaced. See below.
	if movement_proof:
		_apply_movement_proof(plan, next_actor_id)
	return plan


## Send everybody except the player about to touch the ball to their own back
## line, and say so on screen. Toggled with M during playback.
##
## Not a feature -- an instrument, and one asked for by name: *"can you try just
## making them all except setter and hitter move to the back court or something
## very visible to see that it's working?"* The question it answers is narrow and
## worth being able to answer in one keypress: is the plan being **applied**, or
## is it being built and dropped? Every previous attempt to settle that was a
## headless probe measuring something adjacent -- targets published, plan legs
## computed, normalised units mistaken for metres -- and each one said the court
## was alive while the screen said it was not.
##
## A target this large cannot be confused with drift, cannot be hidden by pacing,
## and does not depend on any resolver publishing anything. If the court does not
## visibly empty toward both baselines with this on, playback is not applying
## plans at all and nothing about the resolver is worth investigating yet.
func _apply_movement_proof(plan: Dictionary, contact_actor_id: int) -> void:
	for raw_player_id in match_court_3d.live_positions:
		var player_id := int(raw_player_id)
		if player_id == contact_actor_id:
			continue
		var here := Vector2(match_court_3d.live_positions[raw_player_id])
		## Their own baseline, whichever side of the tape they are standing on.
		## Unpaced on purpose, which is what running after `_pace_plan` buys.
		## Pacing is honest and it is also the thing that would make this
		## diagnostic inconclusive: a nine-metre leg paced at four metres a second
		## inside a third of a second draws about a foot of movement, which is
		## exactly the ambiguous result this exists to avoid.
		_set_plan_target(plan, player_id, Vector2(here.x, 0.06 if here.y < 0.5 else 0.94))


## Two volis cannot stand in the same place.
##
## Nothing anywhere enforced this. A plan is assembled from three independent
## sources -- the resolver's phase maps, playback's return-to-base, and the
## contact's own target -- and not one of them can see the others, so the same
## point can be handed to two people and routinely was. Measured over eight
## rallies: **1487 frames** with two volis on a side inside half a metre, and
## many of them at a gap of exactly 0.00 m, which is not a near miss but the
## identical coordinate. Reported as the whole opposition standing inside each
## other during block follow; it also happens on the home side during every
## other set.
##
## Only 22 of those came from a single map handing one point to two volis. The
## rest are two sources agreeing by accident, which is why this belongs here,
## after everything has had its say, rather than inside any one of them.
##
## A shove rather than a solve. Each overlapping pair is pushed apart along the
## line between them until they clear a shoulder width, twice, which is enough
## to open a stack of two or three and cheap enough to run per leg. It does not
## claim to be collision: bodies can still pass through each other *during* a
## leg, and a real obstruction model -- one where a voli is blocked by a
## teammate rather than merely not ending up inside them -- is a bigger piece of
## work and is in the backlog.
##
## The player about to touch the ball is never moved. They have somewhere they
## must be, and being politely nudged off the ball is worse than standing close
## to a teammate.
const MIN_BODY_SEPARATION_METERS: float = 0.62
const SEPARATION_PASSES: int = 2


func _separate_plan(plan: Dictionary, contact_actor_id: int) -> void:
	## **Worked in metres, and the first version was not.** Court coordinates are
	## normalised and the court is 9 m across by 18 m long, so a push computed as
	## a fraction of the width is only half the push it should be along the
	## length. It cut the overlap and left a residue at a tenth of a metre --
	## which reads on screen exactly like the defect it was supposed to fix.
	##
	## Volis nobody planned a leg for are obstacles too: they are standing
	## somewhere, and a voli sent to that spot arrives inside them. They are in
	## the working set and are never moved.
	var here := {}
	for raw_player_id in match_court_3d.live_positions:
		here[int(raw_player_id)] = _to_metres(
			Vector2(match_court_3d.live_positions[raw_player_id])
		)
	for raw_player_id in plan:
		here[int(raw_player_id)] = _to_metres(
			Vector2(plan[raw_player_id].get("target", Vector2.ZERO))
		)
	var ids: Array = here.keys()
	if ids.size() < 2:
		return
	for _pass_index in range(SEPARATION_PASSES):
		for a_index in range(ids.size()):
			for b_index in range(a_index + 1, ids.size()):
				var a := int(ids[a_index])
				var b := int(ids[b_index])
				## Only teammates crowd each other; the two sides are kept apart
				## by the net and a voli on the far side is not in the way.
				if (a < 100) != (b < 100):
					continue
				var a_movable := plan.has(a) and a != contact_actor_id
				var b_movable := plan.has(b) and b != contact_actor_id
				if not a_movable and not b_movable:
					continue
				var offset: Vector2 = here[b] - here[a]
				var gap := offset.length()
				if gap >= MIN_BODY_SEPARATION_METERS:
					continue
				## Two targets at the identical point have no line to push along,
				## so the pair is opened sideways instead. Derived from the ids so
				## the same stack always opens the same way -- a rally re-resolved
				## from its seed must draw the same court.
				var axis := offset / gap if gap > 0.001 \
					else Vector2(1.0, 0.0).rotated(float((a + b) % 8) * PI * 0.25)
				var overlap := MIN_BODY_SEPARATION_METERS - gap
				## The whole correction goes to whichever of the two can take it.
				var share := 0.5 if a_movable and b_movable else 1.0
				if a_movable:
					here[a] = here[a] - axis * overlap * share
				if b_movable:
					here[b] = here[b] + axis * overlap * share
	for raw_player_id in plan:
		var player_id := int(raw_player_id)
		if player_id == contact_actor_id:
			continue
		plan[raw_player_id]["target"] = _from_metres(here[player_id])


func _to_metres(court_position: Vector2) -> Vector2:
	return Vector2(
		court_position.x * match_court_3d.court_width,
		court_position.y * match_court_3d.court_length,
	)


func _from_metres(metres: Vector2) -> Vector2:
	return Vector2(
		metres.x / maxf(match_court_3d.court_width, 0.001),
		metres.y / maxf(match_court_3d.court_length, 0.001),
	)


## What is drawn as sprinting must be something a body can do.
##
## Playback lerped every planned leg across the ball's flight, whatever the
## distance. Over 600 rallies that printed a median of 0.00 m/s -- most bodies
## are standing still, which is right -- and a p99 of 13.4 m/s, with a worst case
## of 57.1 m/s: a 4.49 m transition drawn inside a 0.079 s attack-to-block
## window. Six of every hundred returns to base posture and fifteen of every
## hundred legs belonging to the player about to touch the ball were over 7 m/s,
## which is roughly the fastest a human covers ground on a volleyball court.
##
## Legs are now paced at the player's own `transition_speed_mps`, published by
## the simulator from the same `LocomotionModel` that times traversals, and a leg
## too long for its window simply is not finished when the window ends. The next
## plan starts from where the body got to, so the walk continues.
##
## The one exception is the leg belonging to the player about to play the ball.
## Pacing that one would draw the contact happening away from the ball, which is
## a worse lie than a fast walk -- the resolver has already decided this player
## makes this touch. It keeps the ball's window and the overspeed is recorded in
## `playback_leg_overspeed` rather than absorbed, because the real cause is
## playback's own accumulated drift and it should stay countable.
const PLAUSIBLE_TOP_SPEED_MPS: float = 7.0


## Which contact the plan currently being paced is aimed at, so an overspeed
## entry can name it. Set immediately before `_pace_plan` rather than threaded
## through its signature, which three other callers would have to carry for a
## field only the diagnostic reads.
var _pacing_event_type: int = -1

## Volis the resolver placed by name on the previous leg. See
## `_apply_base_positions`, which will not overrule them for one window.
var _previously_placed: Dictionary = {}

## How far from their posture a voli has to be before a base return is worth
## drawing, in metres. Under this they are already standing in it.
const BASE_RETURN_DEADBAND_METERS: float = 0.75


func _pace_plan(plan: Dictionary, window_seconds: float, contact_actor_id: int) -> void:
	if window_seconds <= 0.0:
		return
	for raw_player_id in plan:
		var player_id := int(raw_player_id)
		var movement: Dictionary = plan[raw_player_id]
		var metres := _leg_metres(movement)
		if metres <= 0.0001:
			continue
		var speed := _transition_speed(player_id)
		var needed := metres / window_seconds
		if player_id == contact_actor_id:
			if needed > PLAUSIBLE_TOP_SPEED_MPS:
				playback_leg_overspeed.append({
					"player_id": player_id,
					"metres": metres,
					"window_seconds": window_seconds,
					"speed": needed,
					## Which contact this leg was rushing toward. Without it the
					## record says a voli was drawn too fast and cannot say what
					## they were drawn too fast *at*, which is the only thing that
					## distinguishes a hitter over-running their approach mark from
					## a blocker following a ball off their own hands.
					"event_type": _pacing_event_type,
				})
			continue
		movement["seconds"] = maxf(window_seconds, metres / maxf(speed, 0.01))


## The length of the drawn journey in metres, corner included.
func _leg_metres(movement: Dictionary) -> float:
	var start := Vector2(movement.get("start", Vector2.ZERO))
	var target := Vector2(movement.get("target", start))
	var waypoint: Variant = movement.get("waypoint", null)
	if waypoint is Vector2:
		var corner := Vector2(waypoint)
		return _court_metres(start, corner) + _court_metres(corner, target)
	return _court_metres(start, target)


func _court_metres(from_position: Vector2, to_position: Vector2) -> float:
	var delta := to_position - from_position
	return Vector2(
		delta.x * match_court_3d.court_width, delta.y * match_court_3d.court_length
	).length()


func _transition_speed(player_id: int) -> float:
	var profile: Dictionary = player_physical_profiles.get(player_id, {})
	return maxf(float(profile.get("transition_speed_mps", 0.0)), 0.01) \
		if profile.has("transition_speed_mps") else PLAUSIBLE_TOP_SPEED_MPS


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
		## **Not one flight after the resolver put them somewhere.**
		##
		## Measured over eight rallies: 131 legs sent a voli back the way they
		## had just come, and 78 of them were this function and a phase map
		## taking turns -- 49 base-returns immediately after a phase target and
		## 29 phase targets immediately after a base return. Base against base
		## was 3, so the postures themselves are stable; what oscillated was
		## which of the two sources got the last word. About 20 m per rally of
		## drawn travel went into it, against roughly 50 m of travel in total.
		##
		## The comment above this function says a base position is where you go
		## when nothing more specific is being asked of you, and that was true
		## per-leg and false across legs: a voli placed for a phase and then not
		## named in the *next* window was being yanked home from a position the
		## resolver had deliberately chosen, and named again the window after.
		## One window of memory is the whole fix. You reset once the resolver has
		## stopped asking for you, not the instant it goes quiet.
		if _previously_placed.has(player_id):
			continue
		## And nobody jogs home from half a metre away. Small corrections are
		## most of what a base return actually asked for and none of what it is
		## for; below this the voli is already standing in their posture.
		var here := Vector2(match_court_3d.live_positions[player_id])
		if _court_metres(here, Vector2(resting[raw_player_id])) < BASE_RETURN_DEADBAND_METERS:
			continue
		_set_plan_target(plan, player_id, Vector2(resting[raw_player_id]))


## A blocker who is off the floor does not slide along the net.
##
## Reported: the right-side attack goes high, and the blocker shuffles sideways
## *in mid-air* and then executes a rolling receive. The plan was handing the
## block's own actor a target for the next contact -- often a dig they take
## after landing, which is legitimate and common enough that
## `_apply_contact_poses` has a whole paragraph about it -- and then moving them
## there across a window they spend in the air.
##
## `BlockPhaseModel.may_translate` is the rule: a body in the air travels on the
## momentum it left the floor with. Applied to the along-net axis only. The
## other one is free because coming *down* and backing off the net is exactly
## what a landing blocker does; it is the sideways slide that no body can
## perform.
func _hold_airborne_blocker(plan: Dictionary, event: RallyEvent) -> void:
	if event == null or event.event_type != RallyEventModel.EventType.BLOCK:
		return
	if BlockPhaseModel.may_translate("committed"):
		## Defensive: if the rule is ever relaxed, this stops enforcing it
		## rather than silently keeping a stale copy of it.
		return
	var blocker_id := int(event.actor_id)
	if not plan.has(blocker_id) \
			or not match_court_3d.live_positions.has(blocker_id):
		return
	var held := Vector2(match_court_3d.live_positions[blocker_id])
	var target := Vector2(plan[blocker_id]["target"])
	plan[blocker_id]["target"] = Vector2(held.x, target.y)


## How far a voli with no assignment will drift toward the play, in metres.
##
## One step. The bound is the whole point of the entry.
const CHEAT_STEP_METERS: float = 0.55

## How far along the line from their own posture to the ball an unassigned voli
## aims, before the committed teammates push them off it.
##
## Half. A lean is a deviation from your responsibility, not an abandonment of
## it, and a voli who aims at the ball has abandoned it -- that is what the
## previous version did with no coefficient at all, which is the same as this
## sitting at 1.0.
const UNCOVERED_PULL: float = 0.5

## How much floor a committed teammate is treated as already having, in metres.
##
## Wider than a body on purpose: this is not about not colliding -- `_unstack`
## on the court does that -- it is about not *duplicating*. A second voli
## standing two metres from the digger is not in their way and is still not
## helping. Unmeasured, and named as such: nothing has ever published how far
## apart two defenders end up, so this is a starting value and the probe comes
## before the tuning.
const COVERED_GROUND_METERS: float = 2.2


## A voli with no published target cheats a step; they do not hold rigid.
##
## Reported as two back-row volis never moving at all. The comment above
## `_apply_base_positions` explains why they were frozen -- playback used to
## lerp every player toward the action by an invented fraction, twelve volis
## edged toward every contact for a whole rally, and deleting that was right.
##
## **This is not that coming back, and the difference is the cap.** That drift
## was unbounded, unnamed and applied to everyone including players the resolver
## had explicitly placed. This moves only players the resolver said nothing
## about, never past `CHEAT_STEP_METERS`, and never at all once they are already
## closer than that. A voli reading the play leans a step toward it; they do not
## leave their zone, which is exactly the distinction the report drew.
func _apply_cheat_steps(
	plan: Dictionary, action_target: Vector2, next_contact: RallyEvent
) -> void:
	var committed := _committed_ground(next_contact)
	for player_id in match_court_3d.live_positions:
		if plan.has(player_id):
			continue
		var id := int(player_id)
		var start := Vector2(match_court_3d.live_positions[id])
		var step := cheat_step(
			start, action_target, _responsibility_position(id),
			_same_side_ground(committed, id),
		)
		if step == start:
			continue
		_set_plan_target(plan, id, step)


## Where the teammates who *are* participating have committed to stand.
##
## Read from the same two phase maps `_apply_explicit_targets` lays down a few
## lines later, plus the voli about to touch the ball. Those are the volis whose
## ground is spoken for this window; everybody else is deciding what is left.
func _committed_ground(next_contact: RallyEvent) -> Dictionary:
	var ground := {}
	if next_contact == null:
		return ground
	for key in ["home_phase_targets", "opponent_phase_targets"]:
		for raw_player_id in Dictionary(next_contact.metadata.get(key, {})):
			ground[int(raw_player_id)] = Vector2(
				Dictionary(next_contact.metadata[key])[raw_player_id]
			)
	if int(next_contact.actor_id) >= 0:
		ground[int(next_contact.actor_id)] = next_contact.start_position
	return ground


## The committed ground belonging to this voli's own side, as a plain array.
##
## Opponents are not covering for you. Side is the id split the rest of this
## screen uses -- home ids are below 100.
func _same_side_ground(committed: Dictionary, player_id: int) -> Array[Vector2]:
	var mine: Array[Vector2] = []
	for other_id in committed:
		if int(other_id) == player_id:
			continue
		if (int(other_id) < 100) != (player_id < 100):
			continue
		mine.append(Vector2(committed[other_id]))
	return mine


## Where this voli is supposed to stand when nothing specific is asked of them.
##
## `home_base_positions` and `opponent_base_positions` are the resolver's own
## postures, derived from position, rotation and the defensive plan -- the same
## dictionaries `_apply_base_positions` resets to. Falling back to where the
## voli is standing means a missing posture reads as "no opinion" rather than as
## a pull toward the middle of the court.
func _responsibility_position(player_id: int) -> Vector2:
	var here := Vector2(match_court_3d.live_positions.get(player_id, Vector2(0.5, 0.75)))
	if active_result == null:
		return here
	var postures: Dictionary = active_result.home_base_positions if player_id < 100 \
		else active_result.opponent_base_positions
	return Vector2(postures.get(player_id, here))


## One step toward the part of the play nobody else has.
##
## **It used to aim at the ball, and that was the defect.** Every unassigned
## voli leaned along the straight line to the contact point, so a back-row voli
## drifted at the libero already digging cross, and the defensive outside
## drifted at the same ball down the line -- three bodies converging on ground
## one of them was going to cover, and the seam between them left open. A lean
## that duplicates a teammate is worse than standing still, because standing
## still at least keeps the shape.
##
## What a voli actually does is cover what the participants leave. So the target
## here is built from three things rather than one:
##
## - **their own responsibility**, the posture their position, rotation and
##   tactic put them in, which is the thing a lean is a deviation *from*;
## - **the play**, which is what pulls them off it;
## - **the committed teammates**, who cancel the pull along their own bearing --
##   ground somebody else is standing on is not ground worth leaning toward.
##
## The pull is scaled by how much of the line from posture to ball is already
## somebody else's, and what is left is then pushed off the nearest committed
## body so the step lands in the seam rather than on a teammate. The cap is
## unchanged and still the point of the entry: this is a lean, not a rotation.
##
## Static and pure so the suite can hold the cap and the seam without a court to
## run them in.
static func cheat_step(
	start: Vector2,
	action_target: Vector2,
	responsibility: Vector2,
	committed: Array[Vector2] = [],
) -> Vector2:
	## The aim is a point between the posture this voli owes and the ball, not
	## the ball. Half way is the neutral reading of "contributes defensively
	## without leaving your zone"; the covered share below moves it back toward
	## the posture when teammates already have the ball's side of the court.
	var aim := responsibility.lerp(action_target, UNCOVERED_PULL)
	if not committed.is_empty():
		var nearest := committed[0]
		var best := _metres(aim, nearest)
		for candidate in committed:
			var gap := _metres(aim, candidate)
			if gap < best:
				best = gap
				nearest = candidate
		## Somebody already owns this ground. Slide off them rather than stack:
		## the direction is away from the nearest committed body, and the size is
		## how far inside their share of the floor the aim had landed.
		if best < COVERED_GROUND_METERS and best > 0.0001:
			var away := (aim - nearest).normalized()
			var push := (COVERED_GROUND_METERS - best) / CourtConstants.COURT_WIDTH_METERS
			aim += away * push
	var distance := _metres(start, aim)
	## Already there. Nothing to lean toward, and a voli standing on their own
	## share of the play does not shuffle on the spot.
	if distance <= CHEAT_STEP_METERS:
		return start
	return start + (aim - start) * (CHEAT_STEP_METERS / distance)


static func _metres(from_position: Vector2, to_position: Vector2) -> float:
	var delta := to_position - from_position
	return Vector2(
		delta.x * CourtConstants.COURT_WIDTH_METERS,
		delta.y * CourtConstants.COURT_LENGTH_METERS,
	).length()


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


## The drawn flight, from `BallPresentation` so a probe sees the same one.
##
## This function used to *be* the presentation model: a table of per-action
## `rise_scale` and `minimum_lift` constants that manufactured an apex, plus
## floors that guaranteed a serve and a set cleared the net whether or not their
## own flight time could carry them over it. Every one of those numbers has gone.
## Two contact heights and the resolver's own duration determine the parabola,
## and a flight that does not clear the tape now says so instead of being lifted
## until it does.
func _display_trajectory(
	event: RallyEvent,
	next_contact: RallyEvent,
	trajectory: Dictionary,
) -> Dictionary:
	return BallPresentation.display_trajectory(
		event, next_contact, trajectory, player_physical_profiles
	)


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


## Who struck the ball that arrived here, identified by the flight itself.
##
## A trajectory's `start_time` is the instant its contact happened, so the event
## that owns an outgoing flight starting at that instant is the one that sent
## this ball. That is an identity rather than a heuristic, which is what makes it
## safe where "the previous contact" is not -- a blocker who jumped and missed is
## a contact by every structural rule and did not touch the ball.
##
## Falls back to the nearest preceding contact when nothing matches, because a
## slightly wrong launch height is a better answer than no platform at all. The
## fallback did not fire once in 373 contacts and the two rules never disagreed,
## which is the evidence that the identity holds rather than a reason to drop it.
func _sender_of(
	events: Array[Resource], contact_index: int, incoming: Dictionary
) -> RallyEvent:
	var launched_at := float(incoming.get("start_time", NAN))
	var nearest: RallyEvent = null
	for index in range(contact_index - 1, -1, -1):
		var candidate := events[index] as RallyEvent
		if candidate == null or candidate.event_type in [
			RallyEventModel.EventType.SET_DECISION,
			RallyEventModel.EventType.POINT,
		]:
			continue
		if nearest == null:
			nearest = candidate
		var sent: Dictionary = candidate.metadata.get("outgoing_trajectory", {})
		if sent.is_empty() or is_nan(launched_at):
			continue
		if absf(float(sent.get("start_time", -1.0)) - launched_at) < 0.0005:
			return candidate
	return nearest


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
	## The vocabulary's name leads the caption when this contact earned one, the
	## same way it does on the tactical board. Both playback paths name the same
	## moments because both read the same budgeted tag.
	var named := ""
	if bool(event.metadata.get("named_action", false)):
		var outcome := str(event.metadata.get("action_outcome", ""))
		if not outcome.is_empty():
			named = "%s — " % outcome
	caption_label.text = named + (
		event.headline if not event.headline.is_empty() else event.type_name()
	)
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


## Walks the rally's physical clock across one event's window and samples the
## cues on it.
##
## `progress` is the animation's own 0-1 through this leg; the cues live on the
## resolver's seconds. Mapping one onto the other here -- rather than sampling
## on `progress` directly -- is what keeps a thought attached to the moment of
## the rally it belongs to at every playback speed and through a pause.
##
## The window ends at the next contact's stamp when there is one, and at this
## event's own stamp plus the leg's duration when there is not, so the last
## contact of a rally still advances rather than freezing the badge.
func _sample_cognition(
	event: RallyEvent,
	next_contact: RallyEvent,
	progress: float,
	leg_seconds: float,
) -> void:
	var from_time := float(event.metadata.get("physical_time", 0.0))
	var to_time := from_time
	if next_contact != null:
		to_time = float(next_contact.metadata.get("physical_time", from_time))
	if to_time <= from_time:
		to_time = from_time + maxf(leg_seconds, 0.01)
	match_court_3d.sample_cognition(lerpf(from_time, to_time, progress))


## Where this contact's forearms have to point, or nothing.
##
## Solved once per pose from the two flights the event already carries, and only
## for the two contacts that are actually played off a platform. A serve, a set,
## a swing and a block are struck with hands and have no platform to aim; handing
## them a bisector would be pointing arms at a surface that does not exist.
##
## The body yaw is read from the actor rather than from the event, because the
## residual -- the part of the reach the shoulders cannot absorb -- is only
## meaningful against where the voli is actually facing.
func _platform_aim(event: RallyEvent) -> Dictionary:
	if event.event_type != RallyEventModel.EventType.RECEPTION \
			and event.event_type != RallyEventModel.EventType.DEFENSE:
		return {}
	var solved := _platform_surface(event)
	if not bool(solved.get("valid", false)):
		return {}
	var actor := match_court_3d.actor_for(int(event.actor_id))
	var body_yaw := rad_to_deg(actor.facing_yaw) if actor != null else 0.0
	return PlatformAim.relative(solved, body_yaw)


## The surface the two flights require, from the flights as they are **drawn**.
##
## `PlatformAim` is explicit about which of its inputs carries the answer: *"the
## vertical component from the flight's own gravity solve rather than from the
## two endpoint heights"*. Those endpoint heights were being read off the raw
## trajectories on the event, where `start_height_meters` and `end_height_meters`
## are the 1.0 placeholder every trajectory in the game carries -- so its own
## 2.0 / 0.9 defaults never fired and every platform was angled against a ball
## that flew from a metre to a metre.
##
## The cost of that is not subtle and it is not a rate. Measured on 373
## receptions and digs (`tools/run_platform_aim_probe.gd`), the pitch it produced
## ran p10 -0.95, p50 -0.72, p90 -0.59 -- a spread of a third of a degree across
## the whole sample, which is a constant with rounding on it. This file's own
## opening paragraph complains that the arms used to be drawn at an invented
## constant; the constant had come back through a different door. Against the
## drawn ball the same contacts run 1.80 / 3.33 / 8.59 and the sign flips: arms
## angled *up* toward the target, as a platform is. Median error 6.8 degrees of
## pitch and up to 14.2 of yaw.
##
## `posture_for` is unaffected -- 0 of 373 classifications change -- so this is
## a drawing correction and nothing downstream of it moves.
func _platform_surface(event: RallyEvent) -> Dictionary:
	if platform_surfaces.has(event):
		return platform_surfaces[event]
	var surface := {"valid": false}
	var incoming: Dictionary = event.metadata.get("incoming_trajectory", {})
	var outgoing: Dictionary = event.metadata.get("outgoing_trajectory", {})
	var events: Array[Resource] = active_result.events if active_result != null \
		else [] as Array[Resource]
	var index := events.find(event)
	if index >= 0 and not incoming.is_empty() and not outgoing.is_empty():
		## The contact that sent this ball and the one that takes it away. Both
		## are needed because a drawn flight's two ends are the two bodies that
		## touched it -- the arriving ball's far end is *this* passer's own reach,
		## and the leaving ball's is whoever plays it next.
		##
		## The sender is found by matching the flight rather than by stepping back
		## one contact. **The two agree on all 373 sampled contacts**, so this is
		## a guard and not a fix, and it is written down that way rather than
		## claimed as a saving. It is kept because the failure it forecloses is
		## real and silent: a blocker who jumped and missed is a contact by every
		## structural rule and did not touch the ball, so stepping back would
		## launch the arriving flight from hands it never left, and nothing
		## downstream would notice.
		var sender := _sender_of(events, index, incoming)
		var receiver := _next_contact_event(events, index + 1)
		if sender != null:
			surface = PlatformAim.solve(
				BallPresentation.display_trajectory(
					sender, event, incoming, player_physical_profiles
				),
				BallPresentation.display_trajectory(
					event, receiver, outgoing, player_physical_profiles
				),
			)
	platform_surfaces[event] = surface
	return surface
