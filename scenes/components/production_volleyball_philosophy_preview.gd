class_name ProductionVolleyballPhilosophyPreview
extends VolleyballPhilosophyPreview

const MATCH_SCREEN_SCENE := preload("res://scenes/screens/match_screen.tscn")
const VIGNETTE_FACTORY := preload(
	"res://scripts/simulation/volleyball_vignette_rally_factory.gd"
)

## Preserve the readable Q1 presentation established in 2275b6e while letting
## the real MatchScreen/RallyResult own movement, contacts and ball flight.
## Character creation may exaggerate tactical evidence, but it should not alter
## the production ball's physical presentation just to make it readable.
const PREVIEW_CAMERA_POSITION := Vector3(9.1, 8.2, 8.9)
const PREVIEW_CAMERA_TARGET := Vector3(-0.25, 0.85, 1.15)
const PREVIEW_CAMERA_FOV := 37.0

var _match_screen: MatchScreen = null
var _production_ready := false
var _production_result: Resource = null
var _production_vignette := ""
var _replay_wait := 0.0
var _queued_vignette := "good_ball_read"


func _ready() -> void:
	await super._ready()
	## The old authored court remains the temporary Q2-Q6 renderer. Q1 gets an
	## actual MatchScreen, stripped only of its chrome; its RallyResult,
	## MatchCourt3D, movement plans, poses and BallActor3D are production.
	_court.visible = false
	_match_screen = MATCH_SCREEN_SCENE.instantiate() as MatchScreen
	_viewport.add_child(_match_screen)
	_match_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fit_inner_viewport()
	var hud := _match_screen.get_node_or_null("HUD") as Control
	if hud != null:
		hud.visible = false
	var top := _match_screen.get_node_or_null("VignetteTop") as CanvasItem
	if top != null:
		top.visible = false
	var backdrop := _match_screen.get_node_or_null("Backdrop") as CanvasItem
	if backdrop != null:
		backdrop.visible = false
	_apply_preview_presentation()
	_production_ready = true
	set_vignette(_queued_vignette)


## The MatchScreen brings its own SubViewport, so the outer one resizing has to
## carry through or the court is rendered at a size the page is not showing.
func _viewport_fitted(_to: Vector2i) -> void:
	_fit_inner_viewport()


func _fit_inner_viewport() -> void:
	if _match_screen == null or _viewport == null:
		return
	var inner := _match_screen.get_node_or_null(
		"SubViewportContainer/SubViewport"
	) as SubViewport
	if inner != null:
		inner.size = _viewport.size


func set_vignette(vignette_id: String) -> void:
	_queued_vignette = vignette_id
	if not _production_ready:
		return
	## **Every question the resolver can answer, not just the first one.**
	##
	## Q1 was promoted to real rallies and Q2 to Q6 were left drawing through the
	## inherited authored path -- hand-placed bodies and hand-flown balls that
	## cannot disagree with the simulation because they never ask it. A page whose
	## claim is "this is what your volleyball will look like" cannot keep four
	## fifths of its answers as illustration.
	var split := vignette_id.find("_")
	var family := vignette_id.substr(0, split) if split > 0 else ""
	var mode := vignette_id.substr(split + 1) if split > 0 else ""
	if vignette_id.begins_with("good_ball_"):
		family = "good_ball"
		mode = vignette_id.trim_prefix("good_ball_")
	var resolved: Resource = null
	if family == "good_ball":
		resolved = VIGNETTE_FACTORY.q1(mode)
	elif VIGNETTE_FACTORY.QUESTION_SPECS.has(family):
		resolved = VIGNETTE_FACTORY.question(family, mode)
	if resolved != null:
		_court.visible = false
		_match_screen.visible = true
		if vignette_id != _production_vignette or _production_result == null:
			_production_vignette = vignette_id
			_production_result = resolved
		_replay_wait = 0.0
		_start_production_playback()
		return
	_match_screen.playback_generation += 1
	_match_screen.visible = false
	_court.visible = true
	_production_vignette = ""
	_production_result = null
	super.set_vignette(vignette_id)


func set_montage_vignettes(vignette_ids: Array[String]) -> void:
	## Until Q2-Q6 move through the same resolver seam, keep the inherited montage
	## rather than pretending the whole review is simulation-authoritative.
	super.set_montage_vignettes(vignette_ids)


func _process(delta: float) -> void:
	if not _production_ready or not visible:
		return
	if _production_vignette.is_empty():
		super._process(delta)
		return
	if _match_screen.playback_active:
		return
	_replay_wait += delta
	if _replay_wait >= 0.65:
		_replay_wait = 0.0
		_start_production_playback()


func _start_production_playback() -> void:
	if _match_screen == null or _production_result == null:
		return
	if _match_screen.playback_active:
		_match_screen.playback_generation += 1
	_match_screen.load_and_play_rally(_production_result, 1.0)
	## load_and_play_rally rebuilds/resets production presentation state. Restore
	## only the approved vignette framing and visibility; never author ball motion.
	_apply_preview_presentation()


func _apply_preview_presentation() -> void:
	if _match_screen == null or _match_screen.match_court_3d == null:
		return
	var court := _match_screen.match_court_3d
	court.camera_3d.position = PREVIEW_CAMERA_POSITION
	court.camera_3d.fov = PREVIEW_CAMERA_FOV
	court.camera_3d.look_at(PREVIEW_CAMERA_TARGET, Vector3.UP)
	if court.ball_actor != null:
		## 2275b6e's ball fix was visibility, not scale. Keep the production ball
		## at its normal size and ensure reset_flight cannot leave it hidden.
		court.ball_actor.scale = Vector3.ONE
		court.ball_actor.visible = true
