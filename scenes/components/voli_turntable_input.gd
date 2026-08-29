class_name VoliTurntableInput
extends SubViewportContainer

## Shared drag-to-turn interaction for UI views that display a PlayerActor3D on
## a turntable. The roster established this interaction first; character
## creation uses the same turn rate and parent-pivot rule rather than inventing a
## second preview grammar.
const SPIN_PER_PIXEL: float = 0.011

@export var turntable_path: NodePath
@export var disable_owner_process: bool = false

var turntable: Node3D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_DRAG
	gui_input.connect(_turntable_input)
	call_deferred("_bind_turntable")


func _bind_turntable() -> void:
	if disable_owner_process and owner != null:
		## The current career preview's only `_process` job is its old automatic
		## showroom swing. Turning that process off makes this a genuinely manual
		## viewer while leaving the rest of the screen's controls/signals live.
		owner.set_process(false)
	if not turntable_path.is_empty():
		turntable = get_node_or_null(turntable_path) as Node3D
	if turntable == null:
		var viewport := get_child(0) as SubViewport if get_child_count() > 0 else null
		if viewport != null:
			turntable = viewport.find_child("Turntable", true, false) as Node3D


func _turntable_input(event: InputEvent) -> void:
	if turntable == null:
		_bind_turntable()
	if turntable == null:
		return
	if event is InputEventMouseMotion \
			and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		turntable.rotation.y += event.relative.x * SPIN_PER_PIXEL
		accept_event()
