class_name TrainingFlowchart
extends Control

## The training screen's front page: the rally as a loop you can click.
##
## Training was a dropdown on the career dashboard's Team tab -- one activity for
## the whole club, chosen from a list, with no sense that the phases of a rally
## are separate things a squad can be sent at. A flowchart says the thing the
## list could not: these are the six moments a point is decided in, they happen
## in an order, and the order comes back round.
##
## The edges are the engine's real phase order rather than a tidy ring. Serve
## receive is its own node because the engine treats it as its own phase -- its
## own formation, its own zone type, its own claim path -- while floor defence
## sits with blocking, because the block is what defines the space the floor
## covers. Transition is drawn as the edge back to setting, because that is what
## it is: the same offence, entered from a dig instead of a pass.

## The phases, their place on the chart in normalised space, and the training
## activity each one sends a squad to.
##
## Positions are laid out as a loop that reads left to right along the top and
## back along the bottom, so the eye follows a point through a rally rather than
## around a circle with no start.
const NODES: Array[Dictionary] = [
	{
		"id": "serve", "label": "Serving", "activity": "Serving",
		"position": Vector2(0.13, 0.24),
		"blurb": "First strike. Pressure, aces and the errors that buy them.",
	},
	{
		"id": "receive", "label": "Serve Receive", "activity": "Serve Receive",
		"position": Vector2(0.38, 0.24),
		"blurb": "Platform, balance and getting the ball to the setter.",
	},
	{
		"id": "set", "label": "Setting", "activity": "Team Practice",
		"position": Vector2(0.63, 0.24),
		"blurb": "Tempo, disguise and the hands that decide who swings.",
	},
	{
		"id": "attack", "label": "Attack", "activity": "Attack & Transition",
		"position": Vector2(0.87, 0.24),
		"blurb": "Approach, power and the shots that end a rally.",
	},
	{
		"id": "block", "label": "Blocking", "activity": "Blocking & Defense",
		"position": Vector2(0.72, 0.66),
		"blurb": "Reading the set, closing the seam, sealing the tape.",
	},
	{
		"id": "floor", "label": "Floor Defence", "activity": "Blocking & Defense",
		"position": Vector2(0.42, 0.66),
		"blurb": "The space the block leaves, and who is standing in it.",
	},
	{
		"id": "physical", "label": "Physical", "activity": "Strength & Jump",
		"position": Vector2(0.14, 0.66),
		"blurb": "Jump, engine and the conditioning under all of it.",
	},
]

## Which node leads to which, and whether the edge is the rally's forward path or
## the transition loop back into offence.
const EDGES: Array[Dictionary] = [
	{"from": "serve", "to": "receive", "kind": "forward"},
	{"from": "receive", "to": "set", "kind": "forward"},
	{"from": "set", "to": "attack", "kind": "forward"},
	{"from": "attack", "to": "block", "kind": "forward"},
	{"from": "block", "to": "floor", "kind": "pair"},
	{"from": "floor", "to": "set", "kind": "transition"},
	{"from": "physical", "to": "floor", "kind": "support"},
]

const NODE_SIZE := Vector2(148.0, 74.0)

signal phase_selected(phase_id: String, activity: String)

var _buttons: Dictionary = {}
var _line_color := Color(0.62, 0.66, 0.74, 0.55)
var _transition_color := Color(0.86, 0.68, 0.32, 0.75)


func _ready() -> void:
	custom_minimum_size = Vector2(880.0, 420.0)
	for node_data in NODES:
		var button := Button.new()
		button.text = str(node_data.label)
		button.tooltip_text = str(node_data.blurb)
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		## `top_level` is off deliberately: this Control is not a Container, so
		## nothing rewrites the child rects and the positions set in `_layout`
		## survive. Turning it on would take the buttons out of this node's
		## coordinate space and break the edges drawn between them.
		add_child(button)
		var phase_id := str(node_data.id)
		var activity := str(node_data.activity)
		button.pressed.connect(func() -> void:
			phase_selected.emit(phase_id, activity)
		)
		_buttons[phase_id] = button
	resized.connect(_layout)
	_layout()


func set_palette(line: Color, transition: Color) -> void:
	_line_color = line
	_transition_color = transition
	queue_redraw()


func _layout() -> void:
	for node_data in NODES:
		var button: Button = _buttons.get(str(node_data.id))
		if button == null:
			continue
		var centre := Vector2(node_data.position) * size
		button.position = centre - NODE_SIZE * 0.5
	queue_redraw()


func _centre_of(phase_id: String) -> Vector2:
	var button: Button = _buttons.get(phase_id)
	if button == null:
		return Vector2.ZERO
	return button.position + NODE_SIZE * 0.5


func _draw() -> void:
	for edge in EDGES:
		var from := _centre_of(str(edge.from))
		var to := _centre_of(str(edge.to))
		if from == Vector2.ZERO or to == Vector2.ZERO:
			continue
		var kind := str(edge.kind)
		var colour := _transition_color if kind == "transition" else _line_color
		var width := 3.0 if kind == "forward" else 2.0
		## Trimmed to the node edges so a line never runs under a label.
		var direction := (to - from).normalized()
		var start := from + direction * (NODE_SIZE.x * 0.5 + 6.0)
		var end := to - direction * (NODE_SIZE.x * 0.5 + 6.0)
		if kind == "pair":
			## Block and floor defence are not sequential -- they happen at once
			## and define each other. Drawn as a tie rather than an arrow.
			draw_dashed_line(start, end, colour, width, 7.0)
			continue
		draw_line(start, end, colour, width)
		_draw_arrow(end, direction, colour)


func _draw_arrow(tip: Vector2, direction: Vector2, colour: Color) -> void:
	var back := -direction * 11.0
	var side := Vector2(-direction.y, direction.x) * 5.5
	draw_colored_polygon(
		PackedVector2Array([tip, tip + back + side, tip + back - side]), colour
	)
