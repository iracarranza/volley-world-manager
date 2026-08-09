class_name TacticalCourt
extends Control

const HitterPlacementModel := preload(
	"res://scripts/simulation/hitter_placement_model.gd"
)

const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const DefensiveZoneModel := preload("res://scripts/models/defensive_zone.gd")
const RotationLegalityModel := preload("res://scripts/simulation/rotation_legality.gd")

signal player_selected(player_id: int)
signal player_instruction_requested(player_id: int, marker_screen_position: Vector2)
signal player_drag_started(player_id: int)
signal court_background_clicked()
signal assignment_dragged(player_id: int, lane_name: String, marker_position: Vector2)
signal defender_position_changed(player_id: int, court_position: Vector2)
signal coverage_zone_position_changed(
	player_id: int, zone_type: int, court_position: Vector2
)
signal setter_release_position_changed(player_id: int, court_position: Vector2)

const LIGHT_PALETTE := {
	"outside": Color("eaf2ed"),
	"court": Color("ffffff"),
	"court_alt": Color("e7f0e9"),
	"line": Color("176b45"),
	"net": Color("d94343"),
	"marker": Color("176b45"),
	"marker_selected": Color("d94343"),
	"opponent_marker": Color("d94343"),
	"opponent_text": Color("ffffff"),
	"text": Color("10281d"),
	"path": Color("d94343"),
	"secondary_path": Color("c77b28"),
	"serve": Color("8B0000"),
	"reception": Color("00008B"),
	"set": Color("6495ED"),
	"attack": Color("228B22"),
	"block_stuff": Color("8B0000"),
	"block_deflect": Color("FF8C00"),
	"block_miss": Color("32CD32"),
	"defense": Color("FFBF00"),
}

const DARK_PALETTE := {
	"outside": Color("090d16"),
	"court": Color("102d63"),
	"court_alt": Color("0b214a"),
	"line": Color("f4d329"),
	"net": Color("f4d329"),
	"marker": Color("2368bf"),
	"marker_selected": Color("f4d329"),
	"opponent_marker": Color("f4d329"),
	"opponent_text": Color("090d16"),
	"text": Color("f6f3d4"),
	"path": Color("f4d329"),
	"secondary_path": Color("62b4ff"),
	"serve": Color("FF6B6B"),
	"reception": Color("4ECDC4"),
	"set": Color("95E1D3"),
	"attack": Color("90EE90"),
	"block_stuff": Color("FF6B6B"),
	"block_deflect": Color("FFB366"),
	"block_miss": Color("7FFF7F"),
	"defense": Color("FFFF99"),
}

const SHADOW_LAYER_CORE: int = 1
const SHADOW_LAYER_INTENT: int = 2
const SHADOW_LAYER_READS: int = 4
const SHADOW_LAYER_OPPORTUNITIES: int = 8
const SHADOW_LAYER_LABELS: int = 16
const SHADOW_LAYER_ENVELOPES: int = 32
## Gate 51: the continuously-sampled reachability traversal, drawn beside the
## discrete windows it is compared against. On by default in the shadow
## fixture -- the point of building it was to be able to look at it.
const SHADOW_LAYER_CONTINUOUS: int = 64
const SHADOW_LAYER_DEFAULT: int = \
	SHADOW_LAYER_CORE | SHADOW_LAYER_INTENT | SHADOW_LAYER_LABELS \
	| SHADOW_LAYER_ENVELOPES | SHADOW_LAYER_CONTINUOUS
const SHADOW_LAYER_ALL: int = SHADOW_LAYER_DEFAULT \
	| SHADOW_LAYER_READS | SHADOW_LAYER_OPPORTUNITIES
const VISUAL_BALL_PATH: int = 1
const VISUAL_PLAYER_PATHS: int = 2
const VISUAL_TACTICAL_GUIDES: int = 4
const VISUAL_COVERAGE_ZONES: int = 8
const VISUAL_CONTACT_OVERLAYS: int = 16
## What each voli is attending to, deciding and feeling. On by default: the
## board is a coaching instrument and this is the layer that says *why* a player
## went where they went, which no other overlay carries.
const VISUAL_COGNITION: int = 32
const VISUAL_ALL: int = VISUAL_BALL_PATH | VISUAL_PLAYER_PATHS \
	| VISUAL_TACTICAL_GUIDES | VISUAL_COVERAGE_ZONES \
	| VISUAL_CONTACT_OVERLAYS | VISUAL_COGNITION
## Generous window for integrating a traversal. The result is renormalised to
## the phase, so this only has to be long enough for a player to finish; it
## never sets how fast the drawing runs.
const MOVEMENT_SAMPLE_WINDOW_SECONDS: float = 5.0

var lineup: RotationLineup
var players_by_id: Dictionary = {}
var opponent_team: Resource
var opponent_players_by_id: Dictionary = {}
var show_opponents: bool = false
var assignments: Array[HitterAssignment] = []
## A fixed seed for the board's preview of where hitters want the ball. The
## tactical view is not a rally, so it shows each hitter's settled spot rather
## than a particular swing's jitter.
const LANE_PREVIEW_SEED: int = 0
var primary_hitter_id: int = -1
var secondary_hitter_id: int = -1
var selected_player_id: int = -1
var palette: Dictionary = DARK_PALETTE
var playback_event: Resource
var pending_contact_event: Resource
var contact_overlay_event: Resource
var playback_progress: float = 1.0
var playback_tween: Tween
var dragging_player_id: int = -1
var drag_position: Vector2 = Vector2.ZERO
var drag_start_position: Vector2 = Vector2.ZERO
var dragging_release_target: bool = false
var defensive_mode: bool = false
var defensive_plan: Resource
var defensive_zone_type: int = DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
var defensive_phase: int = 0
## The smallest this court can usefully be drawn, in each orientation.
##
## It has to follow the orientation, and it did not: the scene declared a flat
## `custom_minimum_size` of 400x500 -- portrait, matching the portrait default of
## the flag below -- while every host that actually instantiates it calls
## `set_landscape_orientation(true)` and parents it to an `AspectRatioContainer`
## with `ratio = 2.0`. A container cannot shrink a child below its minimum, so
## the court stayed 400x500 and the container centred the overflow: it laid out
## at y = -155, a third of it above the panel, with the lane labels cut off
## mid-word. It looked correct only in the workspace popup, which happened to be
## wide enough to hide the problem.
##
## Both ratios are 2:1 the same way the container is, so the two declarations
## agree instead of fighting. A full court is 9m by 18m and `_court_rect` keeps a
## 34px margin, so the landscape minimum is a 372px-wide court plus its margins.
const MINIMUM_PORTRAIT := Vector2(220.0, 440.0)
const MINIMUM_LANDSCAPE := Vector2(440.0, 220.0)

var landscape_orientation: bool = false
var live_player_positions: Dictionary = {}
var opponent_live_player_positions: Dictionary = {}
var movement_player_id: int = -1
var movement_start: Vector2 = Vector2.ZERO
var movement_target: Vector2 = Vector2.ZERO
var playback_ball_visible: bool = true
var coverage_zones_visible: bool = true
var movement_trails: Dictionary = {}
var movement_phase_caption: String = ""
var unit_movement_starts: Dictionary = {}
var unit_movement_targets: Dictionary = {}
var unit_movement_waypoints: Dictionary = {}
var playback_continuity_mismatches: Array[Dictionary] = []
## Per-player sampled traversals for the current phase, built from the engine's
## own movement model instead of interpolated by this script. See
## `_build_movement_paths`.
var movement_paths: Dictionary = {}
var shadow_reception_trace: Dictionary = {}
var shadow_overlay_layers: int = SHADOW_LAYER_DEFAULT
var visualization_layers: int = VISUAL_ALL

## The cognition stream carried by the rally being replayed, and where playback
## currently sits on the rally's own physical clock.
##
## The clock is separate from `playback_progress` on purpose. That value is a
## 0-1 ratio through whichever movement phase is running -- a UI beat -- and the
## handoff is explicit that cues sample physical time instead, because a cue's
## interval was computed against the resolver's seconds and a phase-relative
## sampler would stretch a thought to fit an animation.
var cognition_cues: Array = []
var cognition_time: float = 0.0
var cognition_tween: Tween


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func set_theme_mode(light_mode: bool) -> void:
	palette = LIGHT_PALETTE if light_mode else DARK_PALETTE
	queue_redraw()


func set_lineup(p_lineup: RotationLineup, players: Array[VolleyballPlayer]) -> void:
	clear_rally_playback()
	shadow_reception_trace.clear()
	lineup = p_lineup
	players_by_id.clear()
	for player in players:
		players_by_id[player.id] = player
	selected_player_id = -1
	queue_redraw()


func set_opponent_team(team: Resource, visible: bool = true) -> void:
	opponent_team = team
	show_opponents = visible and team != null
	opponent_players_by_id.clear()
	if team != null:
		for player_resource in team.on_court_players():
			var player: VolleyballPlayer = player_resource as VolleyballPlayer
			if player != null:
				opponent_players_by_id[player.id] = player
	queue_redraw()


func set_play_preview(
	p_assignments: Array[HitterAssignment],
	p_primary_hitter_id: int,
	p_secondary_hitter_id: int,
) -> void:
	assignments = p_assignments
	primary_hitter_id = p_primary_hitter_id
	secondary_hitter_id = p_secondary_hitter_id
	queue_redraw()


func set_defensive_view(
	enabled: bool,
	plan: Resource = null,
	zone_type: int = DefensiveZoneModel.ZoneType.FLOOR_DEFENSE,
	phase: int = 0,
) -> void:
	defensive_mode = enabled
	defensive_plan = plan
	defensive_zone_type = zone_type
	defensive_phase = phase
	queue_redraw()


func set_coverage_zones_visible(visible: bool) -> void:
	coverage_zones_visible = visible
	queue_redraw()


func set_shadow_reception_trace(trace: Dictionary) -> void:
	shadow_reception_trace = trace.duplicate(true)
	queue_redraw()


func clear_shadow_reception_trace() -> void:
	shadow_reception_trace.clear()
	queue_redraw()


func set_shadow_overlay_layers(layers: int) -> void:
	shadow_overlay_layers = layers
	queue_redraw()


func set_visualization_layers(layers: int) -> void:
	visualization_layers = layers & VISUAL_ALL
	queue_redraw()


func set_landscape_orientation(enabled: bool) -> void:
	landscape_orientation = enabled
	custom_minimum_size = MINIMUM_LANDSCAPE if enabled else MINIMUM_PORTRAIT
	queue_redraw()


func select_player(player_id: int) -> void:
	selected_player_id = player_id
	queue_redraw()


func player_marker_screen_position(player_id: int) -> Vector2:
	if lineup == null:
		return get_screen_position()
	var slot_number := lineup.slot_for_player(player_id)
	if slot_number < 0:
		return get_screen_position()
	return get_screen_position() + _court_to_local(
		_player_court_position(player_id, slot_number)
	)


func animate_event(event: Resource, duration: float) -> void:
	playback_event = event
	pending_contact_event = null
	contact_overlay_event = null
	playback_ball_visible = true
	movement_player_id = -1
	unit_movement_starts.clear()
	unit_movement_targets.clear()
	unit_movement_waypoints.clear()
	_start_playback_tween(duration)


func animate_spatial_transition(
	ball_event: Resource,
	next_contact_event: Resource,
	duration: float,
) -> void:
	playback_event = ball_event
	## The upcoming contact, kept so a jumping player can be drawn rising during
	## the ball flight that precedes it rather than popping up for the single
	## frame of the contact itself.
	pending_contact_event = next_contact_event
	contact_overlay_event = next_contact_event \
		if int(next_contact_event.event_type) == RallyEventModel.EventType.BLOCK else null
	playback_ball_visible = true
	_prepare_player_movement(next_contact_event)
	unit_movement_starts.clear()
	unit_movement_waypoints.clear()
	## The whole unit reads and adjusts while the ball travels. Targets are
	## phase-aware visual intentions, but their starts always come from the
	## previous resolved playback position so support movement never becomes a
	## hidden reset or a later teleport.
	unit_movement_targets = _unit_support_targets(
		next_contact_event, _movement_action_target(next_contact_event)
	)
	if movement_player_id >= 0:
		unit_movement_targets[movement_player_id] = _movement_action_target(
			next_contact_event
		)
		if int(next_contact_event.event_type) == RallyEventModel.EventType.ATTACK \
				and next_contact_event.metadata.has("approach_start_position"):
			unit_movement_waypoints[movement_player_id] = Vector2(
				next_contact_event.metadata["approach_start_position"]
			)
	for raw_player_id in unit_movement_targets:
		var player_id := int(raw_player_id)
		var start := _live_playback_position(player_id)
		if player_id == movement_player_id \
				and next_contact_event.metadata.has("movement_start"):
			var reported_start := Vector2(next_contact_event.metadata["movement_start"])
			if not _has_live_playback_position(player_id):
				start = reported_start
				_set_live_playback_position(player_id, start)
			elif start.distance_to(reported_start) > 0.015:
				playback_continuity_mismatches.append({
					"player_id": player_id,
					"event_type": int(next_contact_event.event_type),
					"visible_start": start,
					"reported_start": reported_start,
					"distance": start.distance_to(reported_start),
				})
		unit_movement_starts[player_id] = start
		_append_movement_trail(player_id, start)
		if unit_movement_waypoints.has(player_id):
			_append_movement_trail(player_id, unit_movement_waypoints[player_id])
		_append_movement_trail(player_id, unit_movement_targets[player_id])
	movement_phase_caption = "Tracking live ball"
	_start_playback_tween(duration)


func animate_player_movement(event: Resource, duration: float) -> void:
	playback_event = event
	contact_overlay_event = null
	playback_ball_visible = false
	_prepare_player_movement(event)
	_start_playback_tween(duration)


func animate_player_to(
	event: Resource,
	target: Vector2,
	duration: float,
	phase_caption: String,
) -> void:
	playback_event = event
	contact_overlay_event = null
	playback_ball_visible = false
	_prepare_player_movement(event)
	unit_movement_starts.clear()
	unit_movement_waypoints.clear()
	unit_movement_targets = _unit_support_targets(event, target)
	if movement_player_id >= 0:
		movement_target = target
		unit_movement_targets[movement_player_id] = target
	movement_phase_caption = phase_caption
	for raw_player_id in unit_movement_targets:
		var player_id := int(raw_player_id)
		var start := _live_playback_position(player_id)
		unit_movement_starts[player_id] = start
		_append_movement_trail(player_id, start)
		_append_movement_trail(player_id, unit_movement_targets[player_id])
	_start_playback_tween(duration)


func movement_phase_targets(event: Resource, after_contact: bool = false) -> Array[Vector2]:
	var targets: Array[Vector2] = []
	if not has_player_movement(event):
		return targets
	var player_id := int(event.actor_id)
	var opponent_actor := _is_opponent_player(player_id)
	var actor_lineup: RotationLineup = opponent_team.current_lineup() \
		if opponent_actor and opponent_team != null else lineup
	var slot_number := actor_lineup.slot_for_player(player_id) \
		if actor_lineup != null else -1
	if slot_number < 0:
		if not after_contact:
			targets.append(event.end_position)
		return targets
	var current := _live_playback_position(player_id)
	var action_target := _movement_action_target(event)
	var base_target := _playback_base_position(player_id, slot_number)
	if not after_contact:
		if opponent_actor:
			targets.append(current.lerp(action_target, 0.35))
			targets.append(action_target)
			return targets
		match int(event.event_type):
			RallyEventModel.EventType.ATTACK:
				var approach_start: Vector2 = event.metadata.get(
					"approach_start_position", current.lerp(action_target, 0.42)
				)
				targets.append(approach_start)
				targets.append(action_target)
			RallyEventModel.EventType.BLOCK:
				targets.append(_defensive_read_position(
					player_id, current, action_target, true
				))
				targets.append(action_target)
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
				targets.append(_defensive_read_position(
					player_id, current, action_target, false
				))
				targets.append(action_target)
			RallyEventModel.EventType.SET:
				targets.append(current.lerp(action_target, 0.35))
				targets.append(action_target)
	else:
		if opponent_actor:
			match int(event.event_type):
				RallyEventModel.EventType.ATTACK, RallyEventModel.EventType.BLOCK:
					var landing := action_target + Vector2(0.0, -0.045)
					targets.append(landing)
					targets.append(landing.lerp(base_target, 0.38))
				RallyEventModel.EventType.DEFENSE:
					var recovery_weight := 0.18 \
						if action_target.distance_to(current) > 0.20 else 0.32
					targets.append(action_target.lerp(base_target, recovery_weight))
				RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.SET:
					targets.append(action_target.lerp(base_target, 0.16))
			return targets
		match int(event.event_type):
			RallyEventModel.EventType.ATTACK, RallyEventModel.EventType.BLOCK:
				var landing := action_target + Vector2(0.0, 0.045)
				targets.append(landing)
				targets.append(landing.lerp(base_target, 0.38))
			RallyEventModel.EventType.DEFENSE:
				var recovery_weight := 0.18 if action_target.distance_to(current) > 0.20 else 0.32
				targets.append(action_target.lerp(base_target, recovery_weight))
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.SET:
				targets.append(action_target.lerp(base_target, 0.16))
	return targets


func _defensive_read_position(
	player_id: int,
	base_position: Vector2,
	action_target: Vector2,
	blocking: bool,
) -> Vector2:
	var player := players_by_id.get(player_id) as VolleyballPlayer
	var read_quality := 0.5
	if player != null:
		read_quality = (
			float(player.anticipation)
			+ float(player.decision_making)
			+ float(player.tactical_discipline)
		) / 300.0
	var read_weight := lerpf(0.10, 0.31, clampf(read_quality, 0.0, 1.0))
	var read_position := base_position.lerp(action_target, read_weight)
	if blocking:
		read_position.y = lerpf(base_position.y, 0.54, 0.42)
	else:
		read_position.y = clampf(read_position.y, 0.56, 0.94)
	return Vector2(
		clampf(read_position.x, 0.06, 0.94),
		clampf(read_position.y, 0.53, 0.96),
	)


func movement_phase_caption_for(
	event: Resource,
	phase_index: int,
	after_contact: bool,
) -> String:
	if after_contact:
		if int(event.event_type) in [
			RallyEventModel.EventType.ATTACK,
			RallyEventModel.EventType.BLOCK,
		]:
			return "Landing" if phase_index == 0 else "Recovery"
		return "Recovery"
	var actor_id := int(event.actor_id)
	if lineup == null or (
		lineup.slot_for_player(actor_id) < 0 and not _is_opponent_player(actor_id)
	):
		return "Unit defensive read"
	match int(event.event_type):
		RallyEventModel.EventType.ATTACK:
			return "Approach setup" if phase_index == 0 else "Approach run"
		RallyEventModel.EventType.BLOCK:
			return "Read step" if phase_index == 0 else "Block close"
		RallyEventModel.EventType.RECEPTION:
			return "Read step" if phase_index == 0 else "Receive move"
		RallyEventModel.EventType.DEFENSE:
			return "Read step" if phase_index == 0 else (
				"Dive" if not bool(event.success) else "Defensive move"
			)
		RallyEventModel.EventType.SET:
			return "Setter transition" if phase_index == 0 else "Set position"
	return "Movement"


func has_player_movement(event: Resource) -> bool:
	if lineup == null or event.actor_id < 0:
		return false
	var actor_id := int(event.actor_id)
	if lineup.slot_for_player(actor_id) < 0 and not _is_opponent_player(actor_id):
		return false
	return int(event.event_type) in [
		RallyEventModel.EventType.RECEPTION,
		RallyEventModel.EventType.SET,
		RallyEventModel.EventType.ATTACK,
		RallyEventModel.EventType.BLOCK,
		RallyEventModel.EventType.DEFENSE,
	]


func _start_playback_tween(duration: float) -> void:
	if playback_tween != null and playback_tween.is_valid():
		playback_tween.kill()
	playback_progress = 0.0
	_build_movement_paths()
	queue_redraw()
	playback_tween = create_tween()
	## Linear, deliberately. The acceleration a player shows now comes from the
	## sampled traversal built by the engine's movement model; easing the
	## progress value on top of it would warp physical timing with a curve
	## nothing in the simulation chose. Ball flight is likewise a function of
	## time, so it should advance at a constant rate through the phase too.
	playback_tween.set_trans(Tween.TRANS_LINEAR)
	playback_tween.tween_method(_set_playback_progress, 0.0, 1.0, duration)


func finish_event_animation() -> void:
	if playback_tween != null and playback_tween.is_valid():
		playback_tween.kill()
	playback_progress = 1.0
	for player_id in unit_movement_targets:
		_set_live_playback_position(player_id, unit_movement_targets[player_id])
	queue_redraw()


func clear_rally_playback() -> void:
	if playback_tween != null and playback_tween.is_valid():
		playback_tween.kill()
	playback_event = null
	pending_contact_event = null
	contact_overlay_event = null
	playback_ball_visible = true
	movement_phase_caption = ""
	live_player_positions.clear()
	opponent_live_player_positions.clear()
	movement_trails.clear()
	unit_movement_starts.clear()
	unit_movement_targets.clear()
	unit_movement_waypoints.clear()
	movement_player_id = -1
	movement_paths.clear()
	playback_continuity_mismatches.clear()
	playback_progress = 1.0
	queue_redraw()


## Starts playback from the simulator's t=0 player snapshot. This deliberately
## ignores the editor's current tactical view, which may show another phase or
## a release target rather than the rally's actual starting locations.
func begin_rally_playback(
	initial_positions: Dictionary,
	initial_opponent_positions: Dictionary = {},
) -> void:
	live_player_positions.clear()
	opponent_live_player_positions.clear()
	movement_trails.clear()
	unit_movement_starts.clear()
	unit_movement_targets.clear()
	unit_movement_waypoints.clear()
	playback_continuity_mismatches.clear()
	if lineup == null:
		queue_redraw()
		return
	for raw_player_id in initial_positions:
		var player_id := int(raw_player_id)
		if lineup.slot_for_player(player_id) < 0:
			continue
		var position := Vector2(initial_positions[raw_player_id])
		live_player_positions[player_id] = position
		_append_movement_trail(player_id, position)
	for raw_player_id in initial_opponent_positions:
		var player_id := int(raw_player_id)
		if not opponent_players_by_id.has(player_id):
			continue
		var position := Vector2(initial_opponent_positions[raw_player_id])
		opponent_live_player_positions[player_id] = position
		_append_movement_trail(player_id, position)
	queue_redraw()


func _set_playback_progress(value: float) -> void:
	playback_progress = value
	for player_id in unit_movement_targets:
		if movement_paths.has(player_id):
			_set_live_playback_position(
				player_id, _sample_movement_path(movement_paths[player_id], value)
			)
			continue
		## Fallback for a player whose profile could not be resolved. Straight
		## interpolation, no waypoint staging -- the old fixed-share split is
		## gone rather than preserved here, because there is no defensible
		## constant to split at.
		var start: Vector2 = unit_movement_starts[player_id]
		var target: Vector2 = unit_movement_targets[player_id]
		_set_live_playback_position(player_id, start.lerp(target, value))
	queue_redraw()


## Builds each moving player's traversal for this phase from the engine's own
## movement model, so drawing samples resolved motion instead of inventing it.
##
## The rate is normalised to the phase: the resolver allots a duration from
## `RallySimulator._movement_time()`, which is a different code path from
## `RallyMovementSystem.project_toward()`, so the two disagree on how long a
## traversal naturally takes. Playback must honour the resolved endpoints and
## the resolved duration exactly or it would contradict the event it is drawing.
## The shape between them -- acceleration, the corner, the speed carried through
## it -- is the model's. Reconciling the two timing paths is step 4's job.
func _build_movement_paths() -> void:
	movement_paths.clear()
	for raw_player_id in unit_movement_targets:
		var player_id := int(raw_player_id)
		var profile := _playback_player_profile(player_id)
		if profile == null:
			continue
		var start: Vector2 = unit_movement_starts.get(
			player_id, _live_playback_position(player_id)
		)
		var target: Vector2 = unit_movement_targets[player_id]
		var waypoint: Variant = unit_movement_waypoints.get(player_id, null)
		var path := _integrate_phase_path(profile, player_id, start, target, waypoint)
		if not path.is_empty():
			movement_paths[player_id] = path


func _integrate_phase_path(
	profile: VolleyballPlayer,
	player_id: int,
	start: Vector2,
	target: Vector2,
	waypoint: Variant,
) -> Dictionary:
	if start.distance_to(target) <= 0.0005 and waypoint == null:
		return {}
	## ApproachMechanicsSystem.prepare_for_attack() reports approach_start_position
	## as wherever the hitter's staging run actually left them -- deliberately the
	## same point this leg's own start, not an aspirational mark the player never
	## reached. Fed through as a distinct leg, the stepper's first direction is
	## zero-length and it aborts before moving at all, silently falling back to a
	## raw lerp for the whole approach. A waypoint already coincident with start
	## is not a corner; treat it as absent so the model steps toward the real
	## target from the first sample.
	var effective_waypoint: Variant = waypoint
	if waypoint != null and start.distance_to(Vector2(waypoint)) <= 0.0005:
		effective_waypoint = null
	var side: StringName = &"opponent" if _is_opponent_player(player_id) else &"home"
	var actor := RallyPlayerState.create(profile, side, -1, start)
	var first_leg: Vector2 = Vector2(effective_waypoint) if effective_waypoint != null else target
	var opening := RallyKinematics.court_delta_meters(start, first_leg)
	if opening.length() > 0.0001:
		## Facing the route keeps the model's turn charge at its floor. The
		## resolver already spent movement time deciding this traversal was
		## possible; re-charging a full turn here would make the player miss the
		## endpoint the event says they reached.
		actor.facing = opening.normalized()
	var mode := RallyPlayerState.MovementMode.APPROACH if effective_waypoint != null \
		else RallyPlayerState.MovementMode.TRANSITION
	var integration: Dictionary = ShadowMovementSystem.integrate(
		actor, target, MOVEMENT_SAMPLE_WINDOW_SECONDS, mode,
		ShadowMovementSystem.DEFAULT_STEP_SECONDS, effective_waypoint,
	)
	if not bool(integration.get("available", false)):
		return {}
	var points: Array = integration.get("trail", [])
	var times: Array = integration.get("sample_times", [])
	if points.size() < 2 or times.size() != points.size():
		return {}
	var arrival := points.size() - 1
	for index in range(points.size()):
		if Vector2(points[index]).distance_to(target) <= 0.002:
			arrival = index
			break
	var span := float(times[arrival])
	if span <= 0.0001 or arrival < 1:
		return {}
	var trimmed: Array[Vector2] = []
	var normalized: Array[float] = []
	for index in range(arrival + 1):
		trimmed.append(Vector2(points[index]))
		normalized.append(clampf(float(times[index]) / span, 0.0, 1.0))
	## The event's endpoint is authoritative; end exactly on it.
	trimmed[trimmed.size() - 1] = target
	normalized[normalized.size() - 1] = 1.0
	return {"points": trimmed, "times": normalized}


func _sample_movement_path(path: Dictionary, progress: float) -> Vector2:
	var points: Array = path.get("points", [])
	var times: Array = path.get("times", [])
	if points.is_empty():
		return Vector2.ZERO
	if points.size() < 2:
		return Vector2(points[0])
	var clamped := clampf(progress, 0.0, 1.0)
	for index in range(1, times.size()):
		var upper := float(times[index])
		if clamped <= upper:
			var lower := float(times[index - 1])
			var span := maxf(upper - lower, 0.00001)
			return Vector2(points[index - 1]).lerp(
				Vector2(points[index]), (clamped - lower) / span
			)
	return Vector2(points[points.size() - 1])


func _playback_player_profile(player_id: int) -> VolleyballPlayer:
	if players_by_id.has(player_id):
		return players_by_id[player_id] as VolleyballPlayer
	if opponent_players_by_id.has(player_id):
		return opponent_players_by_id[player_id] as VolleyballPlayer
	return null


func reset_live_positions() -> void:
	live_player_positions.clear()
	opponent_live_player_positions.clear()
	movement_trails.clear()
	movement_phase_caption = ""
	movement_player_id = -1
	unit_movement_starts.clear()
	unit_movement_targets.clear()
	unit_movement_waypoints.clear()
	movement_paths.clear()
	queue_redraw()


func _prepare_player_movement(event: Resource) -> void:
	movement_player_id = -1
	if lineup == null or event.actor_id < 0:
		return
	var player_id := int(event.actor_id)
	var opponent_actor := _is_opponent_player(player_id)
	var actor_lineup: RotationLineup = opponent_team.current_lineup() \
		if opponent_actor and opponent_team != null else lineup
	var slot_number := actor_lineup.slot_for_player(player_id) \
		if actor_lineup != null else -1
	if slot_number < 0:
		return
	movement_player_id = player_id
	movement_start = _live_playback_position(movement_player_id)
	if event.metadata.has("movement_start") \
			and not _has_live_playback_position(movement_player_id):
		movement_start = Vector2(event.metadata["movement_start"])
		_set_live_playback_position(movement_player_id, movement_start)
	match int(event.event_type):
		RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
			movement_target = event.start_position
		RallyEventModel.EventType.SET:
			movement_target = event.start_position
		RallyEventModel.EventType.ATTACK:
			movement_target = event.start_position
		RallyEventModel.EventType.BLOCK:
			movement_target = event.start_position
		_:
			movement_player_id = -1


func _movement_action_target(event: Resource) -> Vector2:
	if event.metadata.has("movement_target"):
		return Vector2(event.metadata["movement_target"])
	match int(event.event_type):
		RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
			return event.start_position
		RallyEventModel.EventType.SET, RallyEventModel.EventType.ATTACK:
			return event.start_position
		RallyEventModel.EventType.BLOCK:
			return event.start_position
	return event.start_position


func _base_or_defensive_position(player_id: int, slot_number: int) -> Vector2:
	var fallback := CourtConstants.slot_position(slot_number)
	if defensive_plan != null:
		return defensive_plan.defender_position(player_id, fallback)
	return fallback


func _is_opponent_player(player_id: int) -> bool:
	return opponent_players_by_id.has(player_id)


func _has_live_playback_position(player_id: int) -> bool:
	return opponent_live_player_positions.has(player_id) \
		if _is_opponent_player(player_id) else live_player_positions.has(player_id)


func _live_playback_position(player_id: int) -> Vector2:
	if _is_opponent_player(player_id):
		return opponent_live_player_positions.get(
			player_id, opponent_team.court_position(player_id, "defense")
		)
	var slot_number := lineup.slot_for_player(player_id) if lineup != null else -1
	return live_player_positions.get(
		player_id, _player_court_position(player_id, slot_number)
	)


func _set_live_playback_position(player_id: int, position: Vector2) -> void:
	if _is_opponent_player(player_id):
		opponent_live_player_positions[player_id] = position
	else:
		live_player_positions[player_id] = position


func _playback_base_position(player_id: int, slot_number: int) -> Vector2:
	if _is_opponent_player(player_id):
		return opponent_team.court_position(player_id, "defense")
	return _base_or_defensive_position(player_id, slot_number)


func _append_movement_trail(player_id: int, point: Vector2) -> void:
	var trail: Array = movement_trails.get(player_id, [])
	var should_append := trail.is_empty()
	if not trail.is_empty():
		var last_point: Vector2 = trail[-1]
		should_append = last_point.distance_to(point) > 0.005
	if should_append:
		trail.append(point)
	while trail.size() > 5:
		trail.pop_front()
	movement_trails[player_id] = trail


func _unit_support_targets(event: Resource, action_target: Vector2) -> Dictionary:
	var targets := {}
	if lineup == null:
		return targets
	var event_type := int(event.event_type)
	var event_side_opponent := str(event.metadata.get("side", "")) == "opponent"
	## The resolver stages the setter and hitter for their own upcoming contact
	## one leg ahead (setter_start during the serve's flight, the hitter's
	## approach mark during the set's flight). Without honoring that hint here,
	## this leg draws them with the generic side lerp below, and the next leg
	## has to visibly correct onto the real line instead of already being there.
	var staged_actor_id := int(event.metadata.get("staged_next_actor_id", -1))
	var staged_position := Vector2(event.metadata.get(
		"staged_next_position", Vector2.ZERO
	))
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		if player_id == movement_player_id:
			continue
		if player_id == staged_actor_id:
			targets[player_id] = staged_position
			continue
		var base := _base_or_defensive_position(player_id, slot_number)
		targets[player_id] = _support_target_for_side(
			base, action_target, event_type, slot_number,
			false, event_side_opponent,
		)
	if opponent_team != null:
		var opponent_lineup: RotationLineup = opponent_team.current_lineup()
		if opponent_lineup != null:
			for slot_number in range(1, 7):
				var player_id := opponent_lineup.player_at_slot(slot_number)
				if player_id == movement_player_id:
					continue
				var base: Vector2 = opponent_live_player_positions.get(
					player_id, opponent_team.court_position(player_id, "defense")
				)
				targets[player_id] = _support_target_for_side(
					base, action_target, event_type, slot_number,
					true, event_side_opponent,
				)
	var home_phase_targets: Dictionary = event.metadata.get("home_phase_targets", {})
	for raw_player_id in home_phase_targets:
		var player_id := int(raw_player_id)
		if player_id != movement_player_id and players_by_id.has(player_id):
			targets[player_id] = Vector2(home_phase_targets[raw_player_id])
	var opponent_phase_targets: Dictionary = event.metadata.get(
		"opponent_phase_targets", {}
	)
	for raw_player_id in opponent_phase_targets:
		var player_id := int(raw_player_id)
		if player_id != movement_player_id and opponent_players_by_id.has(player_id):
			targets[player_id] = Vector2(opponent_phase_targets[raw_player_id])
	return targets


func _support_target_for_side(
	base: Vector2,
	action_target: Vector2,
	event_type: int,
	slot_number: int,
	team_is_opponent: bool,
	event_side_opponent: bool,
) -> Vector2:
	## Work in a shared orientation where each team's net is toward decreasing
	## Y, then mirror the opponent result back into whole-court coordinates.
	var local_base := Vector2(base.x, 1.0 - base.y) if team_is_opponent else base
	var local_action := Vector2(action_target.x, 1.0 - action_target.y) \
		if team_is_opponent else action_target
	var target := local_base
	var own_phase := team_is_opponent == event_side_opponent
	var front_row := CourtConstants.is_front_row_slot(slot_number)
	if own_phase:
		match event_type:
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
				target = local_base.lerp(local_action, 0.10 if front_row else 0.18)
			RallyEventModel.EventType.SET:
				target = local_base.lerp(Vector2(
					local_action.x, maxf(local_base.y - 0.05, 0.56)
				), 0.22)
			RallyEventModel.EventType.ATTACK:
				var distance := 0.10 + float(slot_number % 3) * 0.035
				target = local_action.lerp(local_base, 0.52) + Vector2(
					-distance if slot_number % 2 == 0 else distance, 0.08
				)
			RallyEventModel.EventType.BLOCK:
				target = local_base.lerp(Vector2(local_action.x, local_base.y), 0.22)
	else:
		match event_type:
			RallyEventModel.EventType.SET, RallyEventModel.EventType.ATTACK:
				if front_row:
					target.x = lerpf(local_base.x, local_action.x, 0.30)
					target.y = lerpf(local_base.y, 0.54, 0.55)
				else:
					target.x = lerpf(local_base.x, local_action.x, 0.16)
					target.y = clampf(local_base.y, 0.70, 0.92)
			RallyEventModel.EventType.RECEPTION, RallyEventModel.EventType.DEFENSE:
				target = local_base.lerp(Vector2(local_action.x, local_base.y), 0.05)
			RallyEventModel.EventType.BLOCK:
				target = local_base.lerp(local_action, 0.10)
	target = Vector2(
		clampf(target.x, 0.06, 0.94), clampf(target.y, 0.53, 0.96)
	)
	return Vector2(target.x, 1.0 - target.y) if team_is_opponent else target


func _gui_input(event: InputEvent) -> void:
	if lineup == null:
		return
	if event is InputEventMouseMotion and (dragging_player_id >= 0 or dragging_release_target):
		drag_position = (event as InputEventMouseMotion).position
		queue_redraw()
		accept_event()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		if _release_target_at_local_position(mouse_event.position):
			dragging_release_target = true
			drag_start_position = mouse_event.position
			drag_position = mouse_event.position
			accept_event()
			return
		dragging_player_id = _player_at_local_position(mouse_event.position)
		if dragging_player_id >= 0:
			drag_start_position = mouse_event.position
			drag_position = mouse_event.position
			select_player(dragging_player_id)
			player_selected.emit(dragging_player_id)
			player_drag_started.emit(dragging_player_id)
			accept_event()
			return
		court_background_clicked.emit()
		accept_event()
		return
	if dragging_release_target:
		dragging_release_target = false
		var release_position := _local_to_court(mouse_event.position)
		setter_release_position_changed.emit(lineup.active_setter_id(), release_position)
		queue_redraw()
		accept_event()
		return
	if dragging_player_id >= 0:
		var released_player_id := dragging_player_id
		var was_dragged := drag_start_position.distance_to(mouse_event.position) >= 7.0
		dragging_player_id = -1
		queue_redraw()
		if defensive_mode and not was_dragged:
			var marker_local := _court_to_local(_player_court_position(
				released_player_id, lineup.slot_for_player(released_player_id)
			))
			player_instruction_requested.emit(
				released_player_id, get_screen_position() + marker_local
			)
		elif defensive_mode:
			var court_position := _local_to_court(mouse_event.position)
			if court_position.y >= CourtConstants.NET_Y:
				coverage_zone_position_changed.emit(
					released_player_id, defensive_zone_type, court_position
				)
		elif was_dragged:
			var lane_name := _nearest_lane(mouse_event.position, released_player_id)
			if not lane_name.is_empty():
				assignment_dragged.emit(released_player_id, lane_name, mouse_event.position)
		accept_event()


func _release_target_at_local_position(local_position: Vector2) -> bool:
	if not defensive_mode or defensive_phase != 0 or defensive_plan == null or lineup == null:
		return false
	var target: Vector2 = defensive_plan.setter_release_target(lineup.active_setter_id())
	return local_position.distance_to(_court_to_local(target)) <= 22.0


func _player_at_local_position(local_position: Vector2) -> int:
	var best_player_id := -1
	var best_distance := 30.0
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		var marker_position := _player_court_position(player_id, slot_number)
		marker_position = _court_to_local(marker_position)
		var distance := local_position.distance_to(marker_position)
		if distance < best_distance:
			best_distance = distance
			best_player_id = player_id
	return best_player_id


func _nearest_lane(local_position: Vector2, player_id: int) -> String:
	var nearest := ""
	var nearest_distance := 90.0
	var lane_names: Array[String] = CourtConstants.LANES
	var slot_number := lineup.slot_for_player(player_id)
	if not CourtConstants.is_front_row_slot(slot_number):
		lane_names = ["Pipe"]
	for lane_name in lane_names:
		var target := _court_to_local(CourtConstants.lane_target(lane_name))
		var distance := local_position.distance_to(target)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = lane_name
	return nearest


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), palette["outside"])
	var court_rect := _court_rect()
	draw_rect(court_rect, palette["court"])
	draw_rect(
		Rect2(court_rect.position, Vector2(court_rect.size.x, court_rect.size.y * 0.5)),
		palette["court_alt"],
	)
	draw_rect(court_rect, palette["line"], false, 3.0)
	var net_start := _court_to_local(Vector2(0.0, CourtConstants.NET_Y))
	var net_end := _court_to_local(Vector2(1.0, CourtConstants.NET_Y))
	# White is the neutral net state; block events paint only occupied sections.
	draw_line(net_start, net_end, Color("f4f4f4"), 5.0)
	for attack_y in [
		CourtConstants.OPPONENT_ATTACK_LINE_Y,
		CourtConstants.HOME_ATTACK_LINE_Y,
	]:
		draw_line(
			_court_to_local(Vector2(0.0, attack_y)),
			_court_to_local(Vector2(1.0, attack_y)),
			palette["line"], 2.0,
		)
	if bool(visualization_layers & VISUAL_TACTICAL_GUIDES):
		_draw_lane_guides()
		_draw_setter_release_path()
	if bool(visualization_layers & VISUAL_PLAYER_PATHS):
		_draw_assignments()
		_draw_assignment_drag()
		_draw_movement_trails()
	if bool(visualization_layers & VISUAL_COVERAGE_ZONES):
		_draw_serve_receive_legality()
		_draw_defensive_zones()
	_draw_shadow_reception_trace()
	_draw_opponents()
	_draw_players()
	_draw_rally_playback()
	if bool(visualization_layers & VISUAL_COGNITION):
		_draw_cognition_badges()


## Lanes as the stretches of net they are, rather than five dots.
##
## These were drawn at `lane_target`, which was the whole of what a lane meant
## when the setter aimed at a constant. A lane is a region a hitter works inside
## now, so the guide draws the region and marks its centre -- otherwise the board
## shows a target the game no longer aims at.
func _draw_lane_guides() -> void:
	for lane_name in CourtConstants.LANES:
		var span: Vector2 = CourtConstants.lane_range(lane_name)
		var depth: float = CourtConstants.lane_target(lane_name).y
		var left := _court_to_local(Vector2(span.x, depth))
		var right := _court_to_local(Vector2(span.y, depth))
		var guide_color: Color = palette["line"]
		guide_color.a = 0.28
		draw_line(left, right, guide_color, 3.0)
		## The ends of the region, so a lane reads as bounded rather than as a
		## line that happens to stop.
		var tick := Vector2(0.0, 5.0)
		draw_line(left - tick, left + tick, guide_color, 2.0)
		draw_line(right - tick, right + tick, guide_color, 2.0)
		var centre := (left + right) * 0.5
		guide_color.a = 0.45
		draw_circle(centre, 3.0, guide_color)
		draw_string(
			ThemeDB.fallback_font, centre + Vector2(-28, -10), lane_name,
			HORIZONTAL_ALIGNMENT_CENTER, 56, 11, _with_alpha(palette["text"], 0.68),
		)


func _draw_assignments() -> void:
	for assignment in assignments:
		var start := _court_to_local(assignment.start_position)
		## Where this hitter actually wants it, which is what the setter is aiming
		## at -- not the middle of their lane.
		var target := _court_to_local(HitterPlacementModel.preferred_point(
			players_by_id.get(assignment.player_id) as VolleyballPlayer,
			str(assignment.lane), LANE_PREVIEW_SEED, 0
		))
		var path_color: Color = palette["path"]
		if assignment.player_id == secondary_hitter_id:
			path_color = palette["secondary_path"]
		elif assignment.player_id != primary_hitter_id:
			path_color = _with_alpha(palette["text"], 0.55)
		draw_dashed_line(start, target, path_color, 3.0, 8.0)
		draw_circle(target, 9.0, path_color, false, 3.0)
		draw_string(
			ThemeDB.fallback_font, target + Vector2(10, 14), "T%d" % assignment.tempo,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 14, path_color,
		)


func _draw_defensive_zones() -> void:
	if not coverage_zones_visible or not defensive_mode or defensive_plan == null or lineup == null:
		return
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		var zones: Dictionary = defensive_plan.zones_for(defensive_zone_type)
		var zone: Resource = zones.get(player_id) as Resource
		if zone == null or not bool(zone.enabled):
			continue
		var points := PackedVector2Array()
		for point_index in range(41):
			var angle := TAU * float(point_index) / 40.0
			var court_point: Vector2 = Vector2(zone.center) + Vector2(
				cos(angle) * float(zone.radius_meters) / 9.0,
				sin(angle) * float(zone.radius_meters) / 18.0,
			)
			points.append(_court_to_local(court_point))
		var zone_color: Color = palette["secondary_path"]
		zone_color.a = 0.12 + float(zone.priority) * 0.035
		draw_colored_polygon(points, zone_color)
		var outline_color: Color = palette["secondary_path"]
		outline_color.a = 0.45 if player_id != selected_player_id else 0.90
		draw_polyline(points, outline_color, 2.0 if player_id != selected_player_id else 3.5)
		var label_position := _court_to_local(zone.center)
		draw_string(
			ThemeDB.fallback_font, label_position + Vector2(23, -19),
			"P%d · %.1fm" % [int(zone.priority), float(zone.radius_meters)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, outline_color,
		)


func _draw_serve_receive_legality() -> void:
	if not coverage_zones_visible or not defensive_mode or defensive_plan == null or lineup == null:
		return
	if defensive_zone_type != DefensiveZoneModel.ZoneType.SERVE_RECEIVE:
		return
	var selected_slot := lineup.slot_for_player(selected_player_id)
	if selected_slot < 1:
		return
	var reception_zones: Dictionary = defensive_plan.zones_for(
		DefensiveZoneModel.ZoneType.SERVE_RECEIVE
	)
	var positions_by_slot := {}
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		var zone: Resource = reception_zones.get(player_id) as Resource
		positions_by_slot[slot_number] = Vector2(zone.center) \
			if zone != null else CourtConstants.slot_position(slot_number)
	var bounds: Rect2 = RotationLegalityModel.legal_bounds(
		selected_slot, positions_by_slot
	)
	var selected_position: Vector2 = positions_by_slot[selected_slot]
	var legal := RotationLegalityModel.is_position_legal(
		selected_slot, selected_position, positions_by_slot
	)
	var legality_color := Color("52c781") if legal else Color("ef6461")
	var bounds_points := PackedVector2Array([
		_court_to_local(bounds.position),
		_court_to_local(Vector2(bounds.end.x, bounds.position.y)),
		_court_to_local(bounds.end),
		_court_to_local(Vector2(bounds.position.x, bounds.end.y)),
	])
	var fill_color := legality_color
	fill_color.a = 0.075
	draw_colored_polygon(bounds_points, fill_color)
	var constraint_color := legality_color
	constraint_color.a = 0.82
	var related: Dictionary = RotationLegalityModel.related_slots(selected_slot)
	for relation_name in ["left", "right", "counterpart"]:
		var related_slot := int(related[relation_name])
		if related_slot < 0:
			continue
		var related_position: Vector2 = positions_by_slot[related_slot]
		if relation_name == "counterpart":
			draw_dashed_line(
				_court_to_local(Vector2(0.06, related_position.y)),
				_court_to_local(Vector2(0.94, related_position.y)),
				constraint_color, 2.0, 8.0,
			)
		else:
			draw_dashed_line(
				_court_to_local(Vector2(related_position.x, 0.53)),
				_court_to_local(Vector2(related_position.x, 0.96)),
				constraint_color, 2.0, 8.0,
			)
		draw_dashed_line(
			_court_to_local(related_position),
			_court_to_local(selected_position),
			_with_alpha(constraint_color, 0.62), 1.5, 6.0,
		)
	var label_position := _court_to_local(bounds.position) + Vector2(8, 18)
	draw_string(
		ThemeDB.fallback_font, label_position,
		"LEGAL AT SERVE" if legal else "ROTATION OVERLAP",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, constraint_color,
	)


func _draw_setter_release_path() -> void:
	if not defensive_mode or defensive_phase != 0 or defensive_plan == null or lineup == null:
		return
	var setter_id := lineup.active_setter_id()
	var setter_slot := lineup.slot_for_player(setter_id)
	if setter_slot < 0:
		return
	var start := _player_court_position(setter_id, setter_slot)
	var target: Vector2 = _local_to_court(drag_position) if dragging_release_target \
		else defensive_plan.setter_release_target(setter_id)
	var start_local := _court_to_local(start)
	var target_local := _court_to_local(target)
	_draw_directional_line(start_local, target_local, palette["secondary_path"])
	draw_circle(target_local, 17.0, palette["outside"])
	draw_circle(target_local, 17.0, palette["secondary_path"], false, 3.0)
	draw_string(
		ThemeDB.fallback_font, target_local + Vector2(-11, 5),
		"S→", HORIZONTAL_ALIGNMENT_CENTER, 22, 12, palette["text"],
	)


func _draw_directional_line(start: Vector2, target: Vector2, color: Color) -> void:
	draw_line(start, target, color, 3.0, true)
	var direction := (target - start).normalized()
	if direction.length_squared() <= 0.0:
		return
	var midpoint := start.lerp(target, 0.52)
	var perpendicular := Vector2(-direction.y, direction.x)
	var arrow := PackedVector2Array([
		midpoint + direction * 10.0,
		midpoint - direction * 7.0 + perpendicular * 6.0,
		midpoint - direction * 7.0 - perpendicular * 6.0,
	])
	draw_colored_polygon(arrow, color)


func _draw_assignment_drag() -> void:
	if dragging_player_id < 0 or lineup == null:
		return
	var slot_number := lineup.slot_for_player(dragging_player_id)
	if slot_number < 0:
		return
	var start := _court_to_local(_player_court_position(dragging_player_id, slot_number))
	draw_dashed_line(start, drag_position, palette["path"], 4.0, 9.0)
	draw_circle(drag_position, 10.0, palette["path"], false, 3.0)


func _draw_movement_trails() -> void:
	for player_id in movement_trails:
		var trail: Array = movement_trails[player_id]
		if trail.size() < 2:
			continue
		var local_points := PackedVector2Array()
		for court_point in trail:
			local_points.append(_court_to_local(court_point))
		draw_polyline(local_points, _with_alpha(palette["secondary_path"], 0.58), 3.0)
	if movement_player_id < 0:
		return
	var local_target := _court_to_local(movement_target)
	draw_circle(local_target, 12.0, palette["secondary_path"], false, 3.0)
	if not movement_phase_caption.is_empty():
		draw_string(
			ThemeDB.fallback_font, local_target + Vector2(14, -10),
			movement_phase_caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			palette["text"],
		)


func _draw_shadow_reception_trace() -> void:
	if shadow_reception_trace.is_empty():
		return
	var summary: Dictionary = shadow_reception_trace.get("summary", {})
	if not bool(summary.get("available", false)):
		return
	var show_core := bool(shadow_overlay_layers & SHADOW_LAYER_CORE)
	var show_intent := bool(shadow_overlay_layers & SHADOW_LAYER_INTENT)
	var show_reads := bool(shadow_overlay_layers & SHADOW_LAYER_READS)
	var show_opportunities := bool(
		shadow_overlay_layers & SHADOW_LAYER_OPPORTUNITIES
	)
	var show_labels := bool(shadow_overlay_layers & SHADOW_LAYER_LABELS)
	var show_envelopes := bool(shadow_overlay_layers & SHADOW_LAYER_ENVELOPES)
	var show_continuous := bool(shadow_overlay_layers & SHADOW_LAYER_CONTINUOUS)
	var true_destination := Vector2(
		summary.get("true_destination", Vector2.ZERO)
	)
	if show_reads:
		var true_local := _court_to_local(true_destination)
		var truth_color := Color("ff5fd1")
		draw_circle(true_local, 13.0, _with_alpha(truth_color, 0.18))
		draw_circle(true_local, 13.0, truth_color, false, 3.0)
		draw_line(
			true_local + Vector2(-8.0, 0.0),
			true_local + Vector2(8.0, 0.0), truth_color, 2.0,
		)
		draw_line(
			true_local + Vector2(0.0, -8.0),
			true_local + Vector2(0.0, 8.0), truth_color, 2.0,
		)
		if show_labels:
			draw_string(
				ThemeDB.fallback_font, true_local + Vector2(15.0, -10.0),
				"TRUE LANDING", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, truth_color,
			)
	var candidates: Array = shadow_reception_trace.get("entries", [])
	var shadow_decision: Dictionary = summary.get("shadow_decision", {})
	var decision_player_id := int(shadow_decision.get("selected_player_id", -1))
	var outgoing_candidate: Dictionary = summary.get("outgoing_flight_candidate", {})
	var outgoing_flight: Dictionary = outgoing_candidate.get("flight", {})
	if show_core and bool(outgoing_candidate.get("available", false)):
		var outgoing_origin := _court_to_local(Vector2(
			outgoing_flight.get("origin", true_destination)
		))
		var outgoing_local := _court_to_local(Vector2(
			outgoing_flight.get("destination", true_destination)
		))
		draw_dashed_line(
			outgoing_origin, outgoing_local, Color("b388ff"), 2.5, 6.0,
		)
		draw_circle(outgoing_local, 6.0, Color("b388ff"), false, 2.0)
	var setter_response: Dictionary = summary.get("shadow_setter_response", {})
	var selected_setter_id := int(setter_response.get("selected_setter_id", -1))
	if show_intent:
		_draw_shadow_setter_intent(setter_response, show_labels)
	if show_envelopes:
		_draw_shadow_contact_envelope(
			setter_response, outgoing_flight, show_labels
		)
	var shadow_attack: Dictionary = summary.get("shadow_attack", {})
	if show_intent or show_reads:
		_draw_shadow_attack(
			shadow_attack, show_reads, show_labels
		)
	if not show_reads and not show_opportunities and not show_continuous:
		return
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		var start := _court_to_local(Vector2(
			candidate.get("start_position", Vector2.ZERO)
		))
		var perceived := _court_to_local(Vector2(
			candidate.get("perceived_destination", Vector2.ZERO)
		))
		var shadow_selected := bool(candidate.get("shadow_selected", false))
		var legacy_selected := bool(candidate.get("legacy_selected", false))
		var decision_selected := int(candidate.get("player_id", -1)) \
			== decision_player_id
		var reachable := bool(candidate.get("reachable", false))
		var candidate_color := Color("53d769") if reachable else Color("ef6461")
		if shadow_selected:
			candidate_color = Color("62b4ff")
		if show_reads:
			draw_dashed_line(
				start, perceived, _with_alpha(candidate_color, 0.60),
				3.0 if shadow_selected else 1.5, 7.0,
			)
			draw_circle(
				perceived, 10.0 if shadow_selected else 7.0,
				candidate_color, false, 3.0 if shadow_selected else 2.0,
			)
			if legacy_selected:
				draw_arc(perceived, 14.0, 0.0, TAU, 20, Color("f2c94c"), 2.5)
			if decision_selected:
				draw_arc(perceived, 18.0, 0.0, TAU, 24, Color("b388ff"), 3.0)
		if bool(candidate.get("repeated_read_selected", false)):
			var repeated: Dictionary = candidate.get("repeated_read_candidate", {})
			var read_points := PackedVector2Array()
			var movement_points := PackedVector2Array([start])
			for raw_moment in repeated.get("moments", []):
				var moment: Dictionary = raw_moment
				var read_local := _court_to_local(Vector2(
					moment.get("perceived_destination", Vector2.ZERO)
				))
				read_points.append(read_local)
				if show_reads:
					draw_circle(read_local, 4.0, Color("ff9f43"))
				var projected_local := _court_to_local(Vector2(
					moment.get("projected_position", candidate.get(
						"start_position", Vector2.ZERO
					))
				))
				movement_points.append(projected_local)
				if show_reads:
					draw_circle(projected_local, 3.5, Color("8ee3c7"))
			if show_reads and read_points.size() > 1:
				draw_polyline(read_points, Color("ff9f43"), 2.0)
			if show_reads and movement_points.size() > 1:
				draw_polyline(movement_points, Color("8ee3c7"), 3.0)
			var opportunity_timeline: Dictionary = repeated.get(
				"opportunity_timeline", {}
			)
			if show_opportunities:
				for raw_transition in opportunity_timeline.get("timeline", []):
					var transition: Dictionary = raw_transition
					var read_index := int(transition.get("read_index", -1))
					if read_index < 0 or read_index >= read_points.size():
						continue
					var transition_name := str(transition.get(
						"window_transition", "sample"
					))
					if transition_name == "opened":
						draw_arc(
							read_points[read_index], 9.0, 0.0, TAU, 16,
							Color("53d769"), 2.5,
						)
					elif transition_name == "closed":
						draw_arc(
							read_points[read_index], 9.0, 0.0, TAU, 16,
							Color("ef6461"), 2.5,
						)
			if show_continuous:
				_draw_continuous_reachability(repeated, show_labels)
		var label := "%s %+.2fs" % [
			str(candidate.get("player_name", candidate.get("player_id", "?"))),
			float(candidate.get("arrival_margin", 0.0)),
		]
		if shadow_selected:
			label += " · SHADOW"
		if legacy_selected:
			label += " · LEGACY"
		if decision_selected:
			label += " · DECISION"
		if show_labels and show_reads:
			draw_string(
				ThemeDB.fallback_font, perceived + Vector2(12.0, 14.0),
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, candidate_color,
			)


## Gate 51: draws the continuously-sampled reachability traversal.
##
## The discrete overlay above marks reachability only at the three perception
## reads. This draws the same receiver's real integrated path between those
## reads, segment-coloured by whether they could still make the contact at
## that instant, plus a ring at the moment reachability actually opens. The
## gap between that ring and the discrete "opened" arc is the timing error the
## read-only model carries, made visible rather than reported as a number.
func _draw_continuous_reachability(
	repeated: Dictionary, show_labels: bool
) -> void:
	var trail: Array = repeated.get("continuous_trail", [])
	if trail.size() < 2:
		return
	var reachable_color := Color("53d769")
	var unreachable_color := Color("ef6461")
	var opened_at := float(repeated.get("continuous_opened_at", -1.0))
	var open_marker := Vector2.ZERO
	var has_open_marker := false
	for index in range(1, trail.size()):
		var previous: Dictionary = trail[index - 1]
		var current: Dictionary = trail[index]
		var from_local := _court_to_local(Vector2(previous.get("position", Vector2.ZERO)))
		var to_local := _court_to_local(Vector2(current.get("position", Vector2.ZERO)))
		var reachable := bool(current.get("reachable", false))
		draw_line(
			from_local, to_local,
			_with_alpha(reachable_color if reachable else unreachable_color, 0.85),
			2.5,
		)
		if not has_open_marker and opened_at >= 0.0 \
				and is_equal_approx(float(current.get("time", -1.0)), opened_at):
			open_marker = to_local
			has_open_marker = true
	if has_open_marker:
		draw_arc(open_marker, 11.0, 0.0, TAU, 20, reachable_color, 2.5)
		draw_line(
			open_marker + Vector2(0.0, -15.0),
			open_marker + Vector2(0.0, 15.0),
			_with_alpha(reachable_color, 0.55), 1.5,
		)
	if not show_labels:
		return
	var anchor := _court_to_local(Vector2(
		Dictionary(trail[trail.size() - 1]).get("position", Vector2.ZERO)
	))
	var delta: Variant = repeated.get("continuous_open_delta_seconds")
	var label := "continuous"
	if delta != null:
		## Negative means the continuous read found the receiver in reach
		## before the discrete read noticed.
		label = "continuous %+.2fs vs reads" % float(delta)
	elif not bool(repeated.get("continuous_ever_reachable", false)):
		label = "continuous · never in reach"
	draw_string(
		ThemeDB.fallback_font, anchor + Vector2(12.0, -10.0),
		label, HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		_with_alpha(reachable_color, 0.95),
	)


func _draw_shadow_setter_intent(
	setter_response: Dictionary,
	show_labels: bool,
) -> void:
	var intended_id := int(setter_response.get("expected_setter_id", -1))
	var actual_id := int(setter_response.get("selected_setter_id", -1))
	var intended_target := _court_to_local(Vector2(setter_response.get(
		"expected_setter_target", Vector2(0.50, 0.60)
	)))
	var intent_color := Color("b388ff")
	var diamond := PackedVector2Array([
		intended_target + Vector2(0.0, -10.0),
		intended_target + Vector2(10.0, 0.0),
		intended_target + Vector2(0.0, 10.0),
		intended_target + Vector2(-10.0, 0.0),
	])
	draw_colored_polygon(diamond, _with_alpha(intent_color, 0.22))
	draw_polyline(PackedVector2Array([
		diamond[0], diamond[1], diamond[2], diamond[3], diamond[0],
	]), intent_color, 2.5)
	var intended_candidate := _shadow_setter_candidate(
		setter_response.get("candidates", []), intended_id
	)
	if not intended_candidate.is_empty():
		var source_local := _court_to_local(Vector2(intended_candidate.get(
			"source_position", Vector2.ZERO
		)))
		var prepared_local := _court_to_local(Vector2(intended_candidate.get(
			"prepared_position", Vector2.ZERO
		)))
		draw_dashed_line(
			source_local, prepared_local, Color("53d769"), 3.0, 6.0,
		)
	var actual_candidate := _shadow_setter_candidate(
		setter_response.get("candidates", []), actual_id
	)
	if not actual_candidate.is_empty():
		var actual_start := _court_to_local(Vector2(actual_candidate.get(
			"prepared_position", Vector2.ZERO
		)))
		var actual_final := _court_to_local(Vector2(actual_candidate.get(
			"final_position", Vector2.ZERO
		)))
		draw_dashed_line(
			actual_start, actual_final, Color("55e6c1"), 3.0, 5.0,
		)
		draw_circle(actual_final, 8.0, Color("55e6c1"), false, 2.5)
		if bool(setter_response.get("ownership_changed", false)):
			draw_dashed_line(
				intended_target, actual_final, Color("f2c94c"), 2.5, 5.0,
			)
			draw_circle(
				intended_target.lerp(actual_final, 0.5), 7.0,
				Color("f2c94c"), false, 2.5,
			)
	if show_labels:
		draw_string(
			ThemeDB.fallback_font, intended_target + Vector2(13.0, -9.0),
			"TARGET: %s" % str(setter_response.get(
				"expected_setter_name", intended_id
			)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, intent_color,
		)
		if bool(setter_response.get("ownership_changed", false)):
			draw_string(
				ThemeDB.fallback_font, intended_target + Vector2(13.0, 8.0),
				"ACTUAL: %s · HANDOFF" % str(setter_response.get(
					"selected_setter_name", actual_id
				)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f2c94c"),
			)


func _draw_shadow_attack(
	shadow_attack: Dictionary,
	show_reads: bool,
	show_labels: bool,
) -> void:
	if not bool(shadow_attack.get("available", false)):
		return
	var assignment: Dictionary = shadow_attack.get("selected_assignment", {})
	var response: Dictionary = shadow_attack.get("hitter_response", {})
	if assignment.is_empty() or not bool(response.get("available", false)):
		return
	var perceived_start := _court_to_local(Vector2(assignment.get(
		"perceived_start_position", response.get("source_position", Vector2.ZERO)
	)))
	var contact := _court_to_local(Vector2(response.get(
		"contact_position", assignment.get("target", Vector2.ZERO)
	)))
	var target := _court_to_local(Vector2(response.get(
		"target", Vector2(0.5, 0.2)
	)))
	var approach_color := Color("ff9f43")
	var shot_color := Color("62b4ff")
	draw_dashed_line(perceived_start, contact, approach_color, 3.0, 6.0)
	draw_circle(contact, 9.0, approach_color, false, 2.5)
	draw_dashed_line(contact, target, shot_color, 3.0, 7.0)
	draw_circle(target, 8.0, shot_color, false, 2.5)
	if show_reads:
		var observation: Dictionary = response.get("observation", {})
		for raw_opponent in observation.get("perceived_opponents", []):
			var opponent: Dictionary = raw_opponent
			var perceived := _court_to_local(Vector2(opponent.get(
				"perceived_position", Vector2.ZERO
			)))
			draw_circle(perceived, 5.0, Color("ef6461"), false, 1.5)
		for raw_moment in response.get("moments", []):
			var moment: Dictionary = raw_moment
			var read_target := _court_to_local(Vector2(moment.get(
				"perceived_destination", Vector2.ZERO
			)))
			draw_circle(read_target, 3.5, approach_color)
	if show_labels:
		draw_string(
			ThemeDB.fallback_font, contact + Vector2(12.0, -12.0),
			"%s · %s · %+.2fs" % [
				str(response.get("player_name", "Hitter")),
				str(response.get("selected_action", "no action")),
				float(response.get("true_arrival_margin", 0.0)),
			], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, approach_color,
		)
		draw_string(
			ThemeDB.fallback_font, target + Vector2(10.0, 14.0),
			"PERCEIVED GAP", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, shot_color,
		)


func _draw_shadow_contact_envelope(
	setter_response: Dictionary,
	outgoing_flight: Dictionary,
	show_labels: bool,
) -> void:
	if not bool(setter_response.get("available", false)):
		return
	var selected_id := int(setter_response.get("selected_setter_id", -1))
	var candidate := _shadow_setter_candidate(
		setter_response.get("candidates", []), selected_id
	)
	if candidate.is_empty():
		return
	var final_position := Vector2(candidate.get("final_position", Vector2.ZERO))
	var contact_position := Vector2(outgoing_flight.get(
		"destination", final_position
	))
	var reach_meters := maxf(float(candidate.get(
		"contact_reach_meters", 0.0
	)), 0.0)
	var reachable := bool(candidate.get("true_reachable", false))
	var envelope_color := Color("55e6c1") if reachable else Color("ef6461")
	var points := PackedVector2Array()
	for point_index in range(41):
		var angle := TAU * float(point_index) / 40.0
		points.append(_court_to_local(final_position + Vector2(
			cos(angle) * reach_meters / 9.0,
			sin(angle) * reach_meters / 18.0,
		)))
	if points.size() > 1:
		draw_colored_polygon(points, _with_alpha(envelope_color, 0.10))
		draw_polyline(points, _with_alpha(envelope_color, 0.90), 2.5)
	var final_local := _court_to_local(final_position)
	var contact_local := _court_to_local(contact_position)
	draw_dashed_line(final_local, contact_local, envelope_color, 2.0, 4.0)
	draw_circle(contact_local, 8.0, envelope_color, false, 2.5)
	if not show_labels:
		return
	var contact_height := float(candidate.get("contact_height_meters", 0.0))
	var standing_reach := float(candidate.get("standing_reach_meters", 0.0))
	var maximum_height := float(candidate.get(
		"maximum_contact_height_meters", standing_reach
	))
	var access_mode := "LATE"
	if bool(candidate.get("requires_jump", false)):
		access_mode = "JUMP"
	elif bool(candidate.get("standing_reachable", false)):
		access_mode = "STAND"
	draw_string(
		ThemeDB.fallback_font, contact_local + Vector2(12.0, 26.0),
		"%s · reach %.2fm · ball %.2fm / stand %.2fm / max %.2fm" % [
			access_mode, reach_meters, contact_height, standing_reach,
			maximum_height,
		], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, envelope_color,
	)


func _shadow_setter_candidate(candidates: Array, player_id: int) -> Dictionary:
	for raw_candidate in candidates:
		var candidate: Dictionary = raw_candidate
		if int(candidate.get("player_id", -1)) == player_id:
			return candidate
	return {}


## How far off the floor this player is at the moment being drawn, 0 to 1.
##
## A 2D top-down court has no natural way to show height, which is why spikes
## and blocks read as flat slides. The resolver already knows who left the floor
## and how well -- `jump_multiplier` for a hitter, the setter's own reach state
## for a jump set -- so the drawing layer reads that rather than inventing it.
func _contact_elevation(player_id: int, side: String) -> float:
	if player_id < 0:
		return 0.0
	## A jump is not an instant. While the ball is still travelling the upcoming
	## contactor is already gathering and rising; during the contact itself they
	## hang and come down. Reading only `playback_event` showed the lift for the
	## contact frame alone, which is why it barely registered even at half speed.
	if pending_contact_event != null:
		var rising := _event_elevation(pending_contact_event, player_id, side)
		if rising > 0.0:
			return rising * smoothstep(0.45, 1.0, playback_progress)
	var landing := _event_elevation(playback_event, player_id, side)
	return landing * (1.0 - smoothstep(0.55, 1.0, playback_progress))


## Peak elevation this player reaches for a given event, ignoring timing.
func _event_elevation(event: Resource, player_id: int, side: String) -> float:
	if event == null:
		return 0.0
	var metadata: Dictionary = event.metadata
	if str(metadata.get("side", "")) != side:
		return 0.0
	var is_actor := int(event.actor_id) == player_id
	match int(event.event_type):
		RallyEventModel.EventType.ATTACK:
			if is_actor:
				## A poor run-up converts to less height, which is the whole
				## point of the approach model being causal.
				return clampf(
					inverse_lerp(0.55, 1.25, float(metadata.get("jump_multiplier", 1.0))),
					0.35, 1.0,
				)
		RallyEventModel.EventType.BLOCK:
			if is_actor or int(metadata.get("assist_id", -1)) == player_id:
				return 0.85
		RallyEventModel.EventType.SET:
			if is_actor:
				match str(Dictionary(
					metadata.get("setter_capability", {})
				).get("reach_state", "")):
					"jump":
						return 0.55
					"beyond_reach":
						## Straining at a ball they cannot actually reach.
						return 0.70
	return 0.0


## Which way this player's hands are working, in local draw space. Zero when
## they are not the one touching the ball.
func _hand_direction(player_id: int, side: String) -> Vector2:
	if player_id < 0:
		return Vector2.ZERO
	## Hands come up with the jump, so they follow the same two-phase read.
	var source: Resource = playback_event
	if pending_contact_event != null \
			and int(pending_contact_event.actor_id) == player_id:
		source = pending_contact_event
	if source == null or int(source.actor_id) != player_id:
		return Vector2.ZERO
	if str(source.metadata.get("side", "")) != side:
		return Vector2.ZERO
	var travel := _court_to_local(source.end_position) \
		- _court_to_local(source.start_position)
	return travel.normalized() if travel.length() > 0.001 else Vector2.ZERO


const JUMP_LIFT_PIXELS: float = 15.0
const HAND_SPREAD_RADIANS: float = 0.62


## One player body: floor shadow, marker, and hand posture.
##
## Both sides draw through here so the two can never drift apart, which is the
## defect this session found three times in the simulation code.
func _draw_player_body(
	center: Vector2,
	radius: float,
	fill: Color,
	elevation: float,
	hand_direction: Vector2,
) -> Vector2:
	var lift := clampf(elevation, 0.0, 1.0) * JUMP_LIFT_PIXELS
	## The shadow stays on the floor and spreads as the player rises; only the
	## marker leaves the ground. That separation is what reads as height.
	var shadow_center := center + Vector2(3.0, 4.0 + lift * 0.55)
	draw_circle(
		shadow_center, radius * (1.0 + clampf(elevation, 0.0, 1.0) * 0.18),
		Color(0, 0, 0, 0.28 - clampf(elevation, 0.0, 1.0) * 0.10),
	)
	var body_center := center - Vector2(0.0, lift)
	var body_radius := radius * (1.0 + clampf(elevation, 0.0, 1.0) * 0.12)
	draw_circle(body_center, body_radius, fill)
	draw_circle(body_center, body_radius, palette["line"], false, 2.0)
	if hand_direction != Vector2.ZERO:
		## Two small marks orbiting toward the work: which way the hands are
		## facing is the difference between a swing and a dig at this zoom.
		var hand_color: Color = _with_alpha(palette["text"], 0.92)
		for sign_value in [-1.0, 1.0]:
			var offset := hand_direction.rotated(
				HAND_SPREAD_RADIANS * sign_value
			) * (body_radius + 5.0)
			draw_circle(body_center + offset, 3.4, hand_color)
			draw_circle(body_center + offset, 3.4, palette["line"], false, 1.0)
	return body_center


func _draw_players() -> void:
	if lineup == null:
		return
	for slot_number in range(1, 7):
		var player_id := lineup.player_at_slot(slot_number)
		var player := players_by_id.get(player_id) as VolleyballPlayer
		var center := _court_to_local(_player_court_position(player_id, slot_number))
		var marker_color: Color = (
			palette["marker_selected"]
			if player_id == selected_player_id else palette["marker"]
		)
		var body_center := _draw_player_body(
			center, 20.0, marker_color,
			_contact_elevation(player_id, "home"),
			_hand_direction(player_id, "home"),
		)
		var short_name := player.position_code if player != null else "?"
		draw_string(
			ThemeDB.fallback_font, body_center + Vector2(-14, 5), short_name,
			HORIZONTAL_ALIGNMENT_CENTER, 28, 14, palette["text"],
		)
		draw_string(
			ThemeDB.fallback_font, center + Vector2(-46, 38),
			"%d · %s" % [slot_number, player.display_name if player != null else "Vacant"],
			HORIZONTAL_ALIGNMENT_CENTER, 92, 12, palette["text"],
		)
		if defensive_mode and defensive_plan != null:
			var assignment: Resource = defensive_plan.assignment_for(player_id)
			if assignment != null:
				var phase_label := ""
				if defensive_phase == 1:
					phase_label = "BLOCK" if bool(assignment.block_participation) \
						and CourtConstants.is_front_row_slot(slot_number) else "NO BLOCK ROLE"
				elif defensive_phase == 2:
					var floor_zone: Resource = defensive_plan.zone_for(
						player_id, DefensiveZoneModel.ZoneType.FLOOR_DEFENSE
					)
					phase_label = "FLOOR ACTIVE" if floor_zone != null and bool(floor_zone.enabled) \
						else "OUT OF FLOOR DEFENSE"
				elif defensive_phase == 3:
					phase_label = "ACTIVE SETTER" if player_id == lineup.active_setter_id() \
						else str(assignment.attack_coverage_responsibility)
				else:
					var receive_zone: Resource = defensive_plan.zone_for(
						player_id, DefensiveZoneModel.ZoneType.SERVE_RECEIVE
					)
					phase_label = "PASSER" if receive_zone != null and bool(receive_zone.enabled) \
						else "HIDDEN"
				draw_string(
					ThemeDB.fallback_font, center + Vector2(-48, 52),
					phase_label,
					HORIZONTAL_ALIGNMENT_CENTER, 96, 10,
					_with_alpha(palette["text"], 0.78),
				)


func _draw_opponents() -> void:
	if not show_opponents or opponent_team == null:
		return
	for player_resource in opponent_team.on_court_players():
		var player: VolleyballPlayer = player_resource as VolleyballPlayer
		if player == null:
			continue
		var court_position: Vector2 = opponent_live_player_positions.get(
			player.id, opponent_team.court_position(player.id, "defense")
		)
		var center := _court_to_local(court_position)
		var active := playback_event != null \
			and str(playback_event.metadata.get("side", "")) == "opponent" \
			and int(playback_event.actor_id) == player.id
		var radius := 19.0 if active else 16.0
		var body_center := _draw_player_body(
			center, radius, palette["opponent_marker"],
			_contact_elevation(player.id, "opponent"),
			_hand_direction(player.id, "opponent"),
		)
		draw_string(
			ThemeDB.fallback_font, body_center + Vector2(-14, 5), player.position_code,
			HORIZONTAL_ALIGNMENT_CENTER, 28, 12, palette["opponent_text"],
		)
		draw_string(
			ThemeDB.fallback_font, body_center + Vector2(-38, -24), player.display_name,
			HORIZONTAL_ALIGNMENT_CENTER, 76, 10,
			_with_alpha(palette["text"], 0.82),
		)


## `_short_responsibility()` abbreviated responsibility labels for a compact
## overlay that no longer draws them. Uncalled.


func _draw_rally_playback() -> void:
	if playback_event == null:
		return
	var followup_block := _followup_block_event()
	var trajectory: Dictionary = playback_event.metadata.get("outgoing_trajectory", {})
	if followup_block != null and int(playback_event.event_type) == RallyEventModel.EventType.ATTACK:
		## The resolver re-slices the attack's own flight to the net whenever the
		## block actually touches it, and emits the deflection as the block's own
		## trajectory. Playback used to rebuild that first leg here instead --
		## fabricating a path with no timing on it, which is a ball trajectory
		## decided by the view rather than the resolver. Only the terminal stuff
		## is still special-cased, because a stuffed ball has no onward flight
		## for this leg to draw.
		if str(followup_block.metadata.get("outcome", "")) == "stuff":
			trajectory = {}
	var trajectory_start: Vector2 = trajectory.get(
		"start_position", playback_event.start_position
	)
	var trajectory_control: Vector2 = trajectory.get(
		"control_position", trajectory_start.lerp(playback_event.end_position, 0.5)
	)
	var trajectory_end: Vector2 = trajectory.get(
		"end_position", playback_event.end_position
	)
	var start := _court_to_local(trajectory_start)
	var finish := _court_to_local(trajectory_end)
	var control := _court_to_local(trajectory_control)
	var inverse := 1.0 - playback_progress
	var ball_position := inverse * inverse * start \
		+ 2.0 * inverse * playback_progress * control \
		+ playback_progress * playback_progress * finish
	var event_color: Color = _playback_event_color(followup_block)
	if bool(visualization_layers & VISUAL_CONTACT_OVERLAYS) \
			and playback_event.actor_id >= 0 and lineup != null:
		var slot_number := lineup.slot_for_player(playback_event.actor_id)
		if slot_number >= 0:
			var actor_position := _court_to_local(_player_court_position(
				int(playback_event.actor_id), slot_number
			))
			draw_circle(actor_position, 27.0, event_color, false, 4.0)
	if not playback_ball_visible:
		return
	if trajectory.is_empty():
		if bool(visualization_layers & VISUAL_CONTACT_OVERLAYS) \
				and followup_block != null \
				and int(playback_event.event_type) == RallyEventModel.EventType.ATTACK:
			_draw_block_reach_marker(followup_block)
		return
	var path_points := PackedVector2Array()
	for path_index in range(21):
		var path_t := float(path_index) / 20.0
		var path_inverse := 1.0 - path_t
		path_points.append(
			path_inverse * path_inverse * start
			+ 2.0 * path_inverse * path_t * control
			+ path_t * path_t * finish
		)
	if bool(visualization_layers & VISUAL_BALL_PATH):
		draw_polyline(path_points, _with_alpha(event_color, 0.34), 2.0)
	var block_event: Resource = followup_block
	if block_event == null and playback_event.event_type == RallyEventModel.EventType.BLOCK:
		block_event = playback_event
	if block_event != null and bool(visualization_layers & VISUAL_CONTACT_OVERLAYS):
		_draw_block_coverage(block_event)
		_draw_block_players(block_event)
	var apex_height := float(trajectory.get("apex_height_meters", 0.0))
	var uses_arc_perspective := int(playback_event.event_type) in [
		RallyEventModel.EventType.SET_DECISION, RallyEventModel.EventType.SET,
	]
	var perspective_progress := playback_progress
	if uses_arc_perspective:
		var height_scale := sin(PI * playback_progress) * apex_height
		perspective_progress = _perspective_adjusted_progress(playback_progress, height_scale, apex_height)
	var perspective_inverse := 1.0 - perspective_progress
	var perspective_ball_position := perspective_inverse * perspective_inverse * start \
		+ 2.0 * perspective_inverse * perspective_progress * control \
		+ perspective_progress * perspective_progress * finish
	var ball_radius_scale: float = 1.0
	if uses_arc_perspective:
		var perspective_height_scale := sin(PI * perspective_progress) * apex_height
		ball_radius_scale = 1.0 + (perspective_height_scale / maxf(apex_height, 0.1)) * 0.35
	var shadow_position := perspective_ball_position + Vector2(3.0, 5.0)
	draw_circle(shadow_position, 9.0, Color(0, 0, 0, 0.3))
	draw_circle(perspective_ball_position, 9.0 * ball_radius_scale, Color("f5d328"))
	draw_arc(perspective_ball_position, 6.0 * ball_radius_scale, 0.0, TAU, 16, Color("245ba7"), 2.0)


func _draw_block_coverage(block_event: Resource) -> void:
	var segments: Array = block_event.metadata.get("coverage_segments", [])
	if segments.is_empty():
		segments.append({
			"x_min": clampf(block_event.end_position.x - 0.08, 0.0, 1.0),
			"x_max": clampf(block_event.end_position.x + 0.08, 0.0, 1.0),
			"completeness": float(block_event.quality),
		})
	for segment_data in segments:
		var segment: Dictionary = segment_data
		var completeness := clampf(float(segment.get("completeness", 0.0)), 0.0, 1.0)
		var coverage_color := _block_flash_color(block_event, completeness)
		draw_line(
			_court_to_local(Vector2(float(segment.get("x_min", 0.45)), CourtConstants.NET_Y)),
			_court_to_local(Vector2(float(segment.get("x_max", 0.55)), CourtConstants.NET_Y)),
			coverage_color, 7.0 + completeness * 4.0,
		)


## Per-blocker feedback, drawn over the ordinary circle marker while a block is
## active: each blocker becomes a square whose opacity and redness track their
## own close quality, rather than only the combined net-coverage bar above.
## A double block additionally draws a bridging rectangle between the two
## blockers -- solid when they closed together, split with a visible gap when
## the assist did not actually seal the seam.
func _draw_block_players(block_event: Resource) -> void:
	var side := str(block_event.metadata.get("side", "opponent"))
	var primary_close := clampf(
		float(block_event.metadata.get("primary_close", block_event.quality)), 0.0, 1.0
	)
	var primary_position := _blocker_local_position(
		int(block_event.actor_id), side, block_event, "primary_position"
	)
	_draw_blocker_square(primary_position, primary_close)
	var assist_id := int(block_event.metadata.get("assist_id", -1))
	if assist_id < 0:
		return
	var assist_close := clampf(float(block_event.metadata.get("assist_close", 0.0)), 0.0, 1.0)
	var assist_position := _blocker_local_position(
		assist_id, side, block_event, "assist_position"
	)
	_draw_blocker_square(assist_position, assist_close)
	_draw_block_connection(primary_position, assist_position, assist_close)


## Where to draw one blocker. The resolver records the wall it actually formed,
## because a block is two players shoulder to shoulder at the net rather than
## wherever each happens to defend from -- reading their individual defensive
## positions put both markers on the attack lane and drew them stacked.
func _blocker_local_position(
	player_id: int,
	side: String,
	block_event: Resource = null,
	position_key: String = "",
) -> Vector2:
	if block_event != null and position_key != "" \
			and block_event.metadata.has(position_key):
		return _court_to_local(Vector2(block_event.metadata[position_key]))
	if side == "opponent" and opponent_team != null:
		var court_position: Vector2 = opponent_live_player_positions.get(
			player_id, opponent_team.court_position(player_id, "defense")
		)
		return _court_to_local(court_position)
	if lineup != null:
		var slot_number := lineup.slot_for_player(player_id)
		if slot_number >= 0:
			return _court_to_local(_player_court_position(player_id, slot_number))
	return _court_to_local(Vector2(0.5, CourtConstants.NET_Y))


## The block-together threshold a connection rect is judged against. Above it
## a double block reads as one sealed wall; below it, a poor assist should not
## imply a wall that was never actually closed.
const BLOCK_TOGETHER_THRESHOLD := 0.45


func _blocker_square_fill(strength: float) -> Color:
	var fit := clampf(strength, 0.0, 1.0)
	return _with_alpha(
		Color.WHITE.lerp(palette["block_stuff"], fit), lerpf(0.22, 0.88, fit)
	)


func _draw_blocker_square(center: Vector2, strength: float) -> void:
	var half := 16.0
	var rect := Rect2(center - Vector2(half, half), Vector2(half, half) * 2.0)
	draw_rect(rect, _blocker_square_fill(strength))
	draw_rect(rect, palette["line"], false, 2.0)


## Returns the rect(s) a block connection should draw, in local screen space:
## one continuous rect spanning both blockers when coordination clears
## BLOCK_TOGETHER_THRESHOLD, or two shorter rects with a real empty gap between
## them otherwise. Kept separate from drawing so the gap geometry is testable
## without a live CanvasItem context.
func _block_connection_rects(
	primary: Vector2, assist: Vector2, coordination: float
) -> Array[Rect2]:
	var span := absf(assist.x - primary.x)
	if span < 1.0:
		return []
	var bar_height := 12.0
	var top := minf(primary.y, assist.y) - bar_height * 0.5
	var left_x := minf(primary.x, assist.x)
	if coordination >= BLOCK_TOGETHER_THRESHOLD:
		return [Rect2(Vector2(left_x, top), Vector2(span, bar_height))]
	var gap := lerpf(0.6, 0.2, coordination / BLOCK_TOGETHER_THRESHOLD) * span
	var segment_width := maxf((span - gap) * 0.5, 3.0)
	return [
		Rect2(Vector2(left_x, top), Vector2(segment_width, bar_height)),
		Rect2(Vector2(left_x + span - segment_width, top), Vector2(segment_width, bar_height)),
	]


func _draw_block_connection(primary: Vector2, assist: Vector2, coordination: float) -> void:
	var color := _with_alpha(palette["block_stuff"], lerpf(0.16, 0.62, coordination))
	for rect in _block_connection_rects(primary, assist, coordination):
		draw_rect(rect, color)


func _followup_block_event() -> Resource:
	if contact_overlay_event != null \
			and int(contact_overlay_event.event_type) == RallyEventModel.EventType.BLOCK:
		return contact_overlay_event
	return null


func _playback_event_color(followup_block: Resource) -> Color:
	var event_type := int(playback_event.event_type)
	match event_type:
		RallyEventModel.EventType.SERVE:
			return palette["serve"]
		RallyEventModel.EventType.RECEPTION:
			return palette["reception"]
		RallyEventModel.EventType.SET_DECISION, RallyEventModel.EventType.SET:
			return palette["set"]
		RallyEventModel.EventType.ATTACK:
			if followup_block == null:
				return palette["attack"]
			var block_outcome := str(followup_block.metadata.get("outcome", ""))
			match block_outcome:
				"stuff": return palette["block_stuff"]
				"touch", "funnel", "recycle": return palette["block_deflect"]
				_: return palette["block_miss"]
		RallyEventModel.EventType.BLOCK:
			var block_outcome := str(playback_event.metadata.get("outcome", ""))
			match block_outcome:
				"stuff": return palette["block_stuff"]
				"touch", "funnel", "recycle": return palette["block_deflect"]
				"miss": return palette["block_miss"]
				_: return palette["block_miss"]
		RallyEventModel.EventType.DEFENSE:
			return palette["defense"]
		RallyEventModel.EventType.POINT:
			return palette["path"]
		_:
			return palette["path"]


func _block_flash_color(block_event: Resource, completeness: float) -> Color:
	var outcome := str(block_event.metadata.get("outcome", ""))
	var base_color: Color
	var dark_color: Color
	match outcome:
		"stuff":
			base_color = palette["block_stuff"]
			dark_color = palette["block_stuff"].darkened(0.5)
		"touch", "funnel", "recycle":
			base_color = palette["block_deflect"]
			dark_color = palette["block_deflect"].darkened(0.4)
		_:
			base_color = palette["block_miss"]
			dark_color = palette["block_miss"].darkened(0.4)
	return base_color.lerp(dark_color, completeness)


func _draw_block_reach_marker(block_event: Resource) -> void:
	var net_point := _court_to_local(Vector2(float(block_event.end_position.x), CourtConstants.NET_Y))
	var intensity := clampf(float(block_event.quality), 0.0, 1.0)
	draw_circle(net_point, 12.0 + intensity * 5.0, _block_flash_color(block_event, intensity), false, 4.0)


func _court_rect() -> Rect2:
	var margin := 34.0
	var available_size := Vector2(
		maxf(size.x - margin * 2.0, 1.0),
		maxf(size.y - margin * 2.0, 1.0),
	)
	## A full volleyball court is 9 m wide by 18 m long.
	var court_height: float
	var court_width: float
	if landscape_orientation:
		court_width = minf(available_size.x, available_size.y * 2.0)
		court_height = court_width * 0.5
	else:
		court_height = minf(available_size.y, available_size.x * 2.0)
		court_width = court_height * 0.5
	var court_size := Vector2(court_width, court_height)
	var centered_position := (size - court_size) * 0.5
	return Rect2(centered_position, court_size)


func _court_to_local(court_point: Vector2) -> Vector2:
	var rect := _court_rect()
	if landscape_orientation:
		return rect.position + Vector2(
			court_point.y * rect.size.x,
			(1.0 - court_point.x) * rect.size.y,
		)
	return rect.position + court_point * rect.size


func _local_to_court(local_point: Vector2) -> Vector2:
	var rect := _court_rect()
	if landscape_orientation:
		return Vector2(
			clampf(1.0 - (local_point.y - rect.position.y) / rect.size.y, 0.0, 1.0),
			clampf((local_point.x - rect.position.x) / rect.size.x, 0.0, 1.0),
		)
	return Vector2(
		clampf((local_point.x - rect.position.x) / rect.size.x, 0.0, 1.0),
		clampf((local_point.y - rect.position.y) / rect.size.y, 0.0, 1.0),
	)


func _player_court_position(player_id: int, slot_number: int) -> Vector2:
	if player_id in live_player_positions:
		return live_player_positions[player_id]
	var fallback := CourtConstants.slot_position(slot_number)
	if defensive_mode and defensive_plan != null:
		var zones: Dictionary = defensive_plan.zones_for(defensive_zone_type)
		var zone: Resource = zones.get(player_id) as Resource
		if zone != null:
			return Vector2(zone.center)
		return defensive_plan.defender_position(player_id, fallback)
	return fallback


func _with_alpha(raw_color: Variant, alpha: float) -> Color:
	var result: Color = raw_color
	result.a = alpha
	return result


func _perspective_adjusted_progress(nominal_progress: float, current_height: float, apex_height: float) -> float:
	if apex_height <= 0.0:
		return nominal_progress
	var height_ratio: float = clampf(current_height / apex_height, 0.0, 1.0)
	var speed_multiplier: float = lerpf(1.15, 0.75, height_ratio)
	var adjusted_progress: float = nominal_progress * speed_multiplier
	return clampf(adjusted_progress, 0.0, 1.0)


## The cognition stream for the rally about to be replayed.
##
## Taken from the resolved result rather than recomputed, so a replay shows the
## thoughts the rally was resolved with and not the ones the current roster,
## confidence or scouting state would produce now.
func set_cognition_stream(cues: Array) -> void:
	cognition_cues = cues
	cognition_time = 0.0
	queue_redraw()


## Moves the rally's own clock across one event's playback window.
##
## `duration` is wall-clock seconds -- already divided by the playback speed --
## while `from_time` and `to_time` are the resolver's seconds. Separating them
## is what lets 0.5x and 2x show the same thoughts at the same points of the
## rally instead of at the same points of the animation.
func advance_cognition_time(
	from_time: float, to_time: float, duration: float
) -> void:
	if cognition_tween != null and cognition_tween.is_valid():
		cognition_tween.kill()
	cognition_time = from_time
	if duration <= 0.0 or to_time <= from_time:
		cognition_time = maxf(to_time, from_time)
		queue_redraw()
		return
	cognition_tween = create_tween()
	cognition_tween.tween_method(
		_set_cognition_time, from_time, to_time, duration
	)


func _set_cognition_time(value: float) -> void:
	cognition_time = value
	queue_redraw()


## Playback ended, or a lineup changed under it. Leaving a badge on screen after
## the rally it belonged to is the same class of defect as a stale movement
## trail, which this file already clears for the same reason.
func clear_cognition() -> void:
	if cognition_tween != null and cognition_tween.is_valid():
		cognition_tween.kill()
	cognition_cues = []
	cognition_time = 0.0
	queue_redraw()


## One badge above one head, for whichever players have a cue running now.
##
## The board is a coaching instrument, so it uses the unfiltered sampler and
## shows private thought -- a setter weighing options nobody in the gym could
## see. The 3D presentation is a camera in a room and uses the spectator
## sampler instead. That difference is the only one between the two renderers,
## and it is a difference of audience rather than of meaning.
func _draw_cognition_badges() -> void:
	if cognition_cues.is_empty():
		return
	var active: Dictionary = CognitionTimeline.active_by_player(
		cognition_cues, cognition_time
	)
	for raw_player_id in active:
		var player_id := int(raw_player_id)
		var cue: Resource = active[player_id]
		if not CognitionBadge.is_worth_drawing(cue):
			continue
		var anchor: Variant = _cognition_anchor(player_id)
		if anchor == null:
			continue
		var center := Vector2(anchor)
		var toward := _cognition_attention_offset(cue, center)
		_draw_cognition_badge(center + Vector2(0.0, -34.0), cue, toward)


## Where a badge hangs, in local coordinates, or null when the player is not on
## this court -- an opponent on a home-only view, or a substituted voli.
func _cognition_anchor(player_id: int) -> Variant:
	if lineup != null and lineup.slot_for_player(player_id) >= 0:
		return _court_to_local(
			_player_court_position(player_id, lineup.slot_for_player(player_id))
		)
	if opponent_team != null and show_opponents \
			and opponent_players_by_id.has(player_id):
		return _court_to_local(opponent_live_player_positions.get(
			player_id, opponent_team.court_position(player_id, "defense")
		))
	return null


## Screen-space direction from the badge to whatever the cue is attending to.
##
## A cue naming a player is resolved against that player's live position, so a
## setter's eyes follow a hitter who is still moving. Attention to the ball is
## left flat rather than pointed at a guess: the ball's drawn position during a
## movement phase is not the position the cue was computed against, and a pupil
## that lies is worse than a pupil that rests.
func _cognition_attention_offset(cue: Resource, from: Vector2) -> Vector2:
	match str(cue.attention_kind):
		"hitter", "setter", "teammate":
			var target: Variant = _cognition_anchor(int(cue.attention_player_id))
			if target == null:
				return Vector2.ZERO
			return (Vector2(target) - from)
		"position":
			return _court_to_local(Vector2(cue.attention_position)) - from
	return Vector2.ZERO


func _draw_cognition_badge(
	center: Vector2, cue: Resource, toward: Vector2
) -> void:
	var reading: Dictionary = CognitionBadge.describe(cue, toward)
	if reading.is_empty():
		return
	var radius := 11.0
	var color: Color = Color(reading.color)
	_draw_cognition_outline(center, radius, str(reading.shape), color)
	## The eye: a lens whose height is the openness, so a narrow scan and a wide
	## recognition are different shapes rather than different colours.
	var openness := float(reading.eye_openness)
	var lens_height := maxf(radius * openness, 1.2)
	draw_rect(
		Rect2(center - Vector2(radius * 0.62, lens_height * 0.5),
			Vector2(radius * 1.24, lens_height)),
		Color(color, 0.22),
	)
	if openness > 0.2:
		var pupil := Vector2(reading.pupil) * radius
		draw_circle(
			center + Vector2(pupil.x, clampf(pupil.y, -lens_height * 0.3, lens_height * 0.3)),
			maxf(lens_height * 0.34, 1.6), color,
		)
	else:
		## Closed: a line, which reads as "cannot see" even in a screenshot with
		## no colour at all.
		draw_line(
			center - Vector2(radius * 0.6, 0.0),
			center + Vector2(radius * 0.6, 0.0), color, 2.0,
		)
	var punctuation := str(reading.punctuation)
	if not punctuation.is_empty():
		draw_string(
			ThemeDB.fallback_font, center + Vector2(radius * 0.9, -radius * 0.4),
			punctuation, HORIZONTAL_ALIGNMENT_LEFT, 26, 15, color,
		)
	var trend := int(reading.trend_direction)
	if trend != 0:
		var tip := center + Vector2(-radius * 1.25, -radius * 0.55 * float(trend))
		draw_line(
			center + Vector2(-radius * 1.25, radius * 0.45 * float(trend)),
			tip, color, 2.0,
		)


## The outline, which carries the state independently of the colour.
func _draw_cognition_outline(
	center: Vector2, radius: float, shape: String, color: Color
) -> void:
	match shape:
		"wedge":
			## A call: a speech-bubble tail, because it is the one cue another
			## player is meant to hear.
			draw_circle(center, radius, Color(color, 0.16))
			draw_arc(center, radius, 0.0, TAU, 28, color, 2.0)
			draw_colored_polygon(
				PackedVector2Array([
					center + Vector2(-radius * 0.45, radius * 0.85),
					center + Vector2(radius * 0.10, radius * 0.85),
					center + Vector2(-radius * 0.15, radius * 1.55),
				]), color,
			)
		"diamond":
			var points := PackedVector2Array([
				center + Vector2(0.0, -radius),
				center + Vector2(radius, 0.0),
				center + Vector2(0.0, radius),
				center + Vector2(-radius, 0.0),
			])
			draw_colored_polygon(points, Color(color, 0.16))
			draw_polyline(
				PackedVector2Array(Array(points) + [points[0]]), color, 2.0
			)
		"dashed_ring":
			for segment in range(8):
				var from_angle := TAU * float(segment) / 8.0
				draw_arc(
					center, radius, from_angle, from_angle + TAU / 16.0, 4, color, 2.0
				)
		"burst":
			draw_circle(center, radius, Color(color, 0.16))
			for spike in range(8):
				var angle := TAU * float(spike) / 8.0
				draw_line(
					center + Vector2(cos(angle), sin(angle)) * radius,
					center + Vector2(cos(angle), sin(angle)) * radius * 1.42,
					color, 2.0,
				)
		_:
			draw_circle(center, radius, Color(color, 0.16))
			draw_arc(center, radius, 0.0, TAU, 28, color, 2.0)
