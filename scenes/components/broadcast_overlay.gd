class_name BroadcastOverlay
extends Control

## Presentation-only broadcast shell. It consumes labels and playback state; it
## never reads or writes rally authority. Portrait actors are dedicated
## broadcaster fixtures, never members of either match roster.

const ANNOUNCER_SCENE := preload("res://scenes/components/player_actor_3d.tscn")

@export_enum("top_right", "bottom_right") var commentary_placement := "top_right"
@onready var score_bug: PanelContainer = %ScoreBug
@onready var home_name: Label = %HomeName
@onready var away_name: Label = %AwayName
@onready var home_score: Label = %HomeScore
@onready var away_score: Label = %AwayScore
@onready var home_sets: Label = %HomeSets
@onready var away_sets: Label = %AwaySets
@onready var home_serve: Label = %HomeServe
@onready var away_serve: Label = %AwayServe
@onready var commentary_panel: PanelContainer = %CommentaryPanel
@onready var commentary_label: Label = %CommentaryLabel
@onready var ribbon: PanelContainer = %Ribbon
@onready var phase_label: Label = %PhaseLabel
@onready var lower_third: PanelContainer = %LowerThird
@onready var lower_kicker: Label = %LowerKicker
@onready var lower_title: Label = %LowerTitle
@onready var replay_flag: Label = %ReplayFlag
@onready var announcer_left: SubViewportContainer = %AnnouncerLeft
@onready var announcer_right: SubViewportContainer = %AnnouncerRight
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var speed_option: OptionButton = %SpeedOption
@onready var pause_button: Button = %PauseButton
@onready var replay_button: Button = %ReplayButton
@onready var skip_button: Button = %SkipButton
@onready var camera_option: OptionButton = %CameraOption
@onready var free_camera_button: Button = %FreeCameraButton
@onready var follow_option: OptionButton = %FollowOption
@onready var zoom_out_button: Button = %ZoomOutButton
@onready var zoom_in_button: Button = %ZoomInButton
@onready var camera_status_label: Label = %CameraStatusLabel
@onready var close_button: Button = %CloseButton

## The furniture the wide layout needs, in pixels, summed from what it asks for
## rather than picked: the score bug's 430 and the commentary panel's 390, plus
## the 24-pixel margin either side and between them. Below this the two overlap,
## and the announcer portraits either side of the bug are the first thing to eat
## the picture -- reported as the announcers covering the whole viewable screen.
const WIDE_LAYOUT_MINIMUM_PX: float = 430.0 + 390.0 + 24.0 * 3.0

var compact := false
var live_rally := false
var replay_mode := false


func _ready() -> void:
	_setup_announcer(announcer_left, 91001, "Maro", {
		"body_type": "Ursi", "body_marking": "mask", "head_extra": "tuft",
		"club_region": "Landavol", "height_meters": 1.82,
	})
	_setup_announcer(announcer_right, 91002, "Seli", {
		"body_type": "Avi", "body_marking": "brow", "head_extra": "crest",
		"club_region": "Xérvu", "height_meters": 1.76,
	})
	set_commentary_placement(commentary_placement)
	set_live_rally(false)
	resized.connect(_on_resized)
	_on_resized()


func configure_score(home: String, away: String, home_points: int, away_points: int,
	home_set_count: int, away_set_count: int, serving_home: bool) -> void:
	home_name.text = home
	away_name.text = away
	home_score.text = str(home_points)
	away_score.text = str(away_points)
	home_sets.text = "SETS %d" % home_set_count
	away_sets.text = "SETS %d" % away_set_count
	home_serve.visible = serving_home
	away_serve.visible = not serving_home


## **Compact when there is not room to be wide.**
##
## `set_compact` existed and was called from nowhere, so the wide layout ran at
## every size -- including hosts far narrower than the 892 px it needs, where the
## bug and the commentary panel overlap and the two announcer portraits cover the
## court they are supposed to be commenting on.
##
## Derived from the host's own width rather than set by whoever embeds this, so a
## new caller cannot forget it and an existing one does not have to be found.
func _on_resized() -> void:
	var wants_compact := size.x < WIDE_LAYOUT_MINIMUM_PX
	if wants_compact != compact:
		set_compact(wants_compact)


func set_compact(value: bool) -> void:
	compact = value
	score_bug.custom_minimum_size.x = 330.0 if compact else 430.0
	for node in [home_sets, away_sets, announcer_left, announcer_right]:
		node.visible = not compact
	commentary_panel.custom_minimum_size.x = 300.0 if compact else 390.0


func set_commentary_placement(value: String) -> void:
	commentary_placement = value
	commentary_panel.anchor_left = 1.0
	commentary_panel.anchor_right = 1.0
	commentary_panel.anchor_top = 1.0 if value == "bottom_right" else 0.0
	commentary_panel.anchor_bottom = commentary_panel.anchor_top
	commentary_panel.offset_left = -420.0
	commentary_panel.offset_right = -24.0
	commentary_panel.offset_top = -205.0 if value == "bottom_right" else 24.0
	commentary_panel.offset_bottom = -61.0 if value == "bottom_right" else 168.0


func set_commentary(text: String, speaker: int = 0, reactive: bool = false) -> void:
	commentary_label.text = text
	_set_speaker_emphasis(speaker, reactive)


func set_live_rally(value: bool, phase: String = "LIVE RALLY") -> void:
	live_rally = value
	phase_label.text = phase
	lower_third.visible = not value
	replay_flag.visible = replay_mode
	## Controls remain legible and clickable throughout the rally. The old draft
	## faded the whole ribbon almost to invisibility during live play, which made
	## pause, camera and follow look disabled exactly when they were useful.
	ribbon.modulate.a = 0.94 if value else 1.0


func show_lower_third(kicker: String, title: String) -> void:
	lower_kicker.text = kicker
	lower_title.text = title
	lower_third.visible = true


func set_replay_state(value: bool) -> void:
	replay_mode = value
	replay_flag.visible = value
	if value:
		phase_label.text = "REPLAY"


func set_camera_status(text: String, free_active: bool = false) -> void:
	camera_status_label.text = text
	free_camera_button.set_pressed_no_signal(free_active)
	free_camera_button.text = "FREE ON" if free_active else "FREE"


func set_progress(value: float) -> void:
	progress_bar.value = clampf(value, 0.0, 100.0)


func _setup_announcer(container: SubViewportContainer, id: int,
	display_name: String, profile: Dictionary) -> void:
	var viewport := container.get_child(0) as SubViewport
	var world := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("152134")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9e4f2")
	environment.ambient_light_energy = 1.05
	world.environment = environment
	viewport.add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28.0, -150.0, 0.0)
	light.light_energy = 1.45
	viewport.add_child(light)
	var actor := ANNOUNCER_SCENE.instantiate() as PlayerActor3D
	viewport.add_child(actor)
	actor.configure(id, id % 2 == 0, display_name, "Right", profile)
	actor.set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)
	actor.rotation.y = PI + deg_to_rad(-8.0 if id % 2 == 0 else 8.0)
	for path in ["IdentityLabel", "FocusRing", "CognitionBillboard3D", "SignatureSurge3D"]:
		var readout := actor.get_node_or_null(path)
		if readout is Node3D:
			(readout as Node3D).visible = false
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(0.0, 1.63, 2.35)
	camera.fov = 25.0
	camera.look_at(Vector3(0.0, 1.58, 0.0), Vector3.UP)


func _set_speaker_emphasis(speaker: int, reactive: bool) -> void:
	announcer_left.modulate = Color.WHITE if speaker == 0 else Color(0.55, 0.60, 0.68, 0.78)
	announcer_right.modulate = Color.WHITE if speaker == 1 else Color(0.55, 0.60, 0.68, 0.78)
	commentary_label.add_theme_color_override(
		"font_color", Color("fff0b0") if reactive else Color("edf3fa"))
