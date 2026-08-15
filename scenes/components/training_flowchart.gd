class_name TrainingFlowchart
extends Control

## The training screen's front page: the rally as a loop you can click.
##
## Training was a dropdown on the journal's Team tab -- one activity for
## the whole club, chosen from a list, with no sense that the phases of a rally
## are separate things a squad can be sent at. A flowchart says the thing the
## list could not: these are the six moments a point is decided in, they happen
## in an order, and the order comes back round.
##
## The edges are the engine's real phase order. Serve receive is its own node
## because the engine treats it as its own phase -- its own formation, its own
## zone type, its own claim path -- while floor defence sits with blocking,
## because the block is what defines the space the floor covers. Transition is
## drawn as the edge back to setting, because that is what it is: the same
## offence, entered from a dig instead of a pass.

## The phases, their place on the chart in normalised space, and the training
## activity each one sends a squad to.
##
## The rally is not a row of boxes. It is a circuit that comes back round, and
## the drawing should say so before any label does.
##
## Four phases sit on a ring -- setting, attack, blocking, floor defence -- and
## the circuit turns clockwise through them, closing on the transition edge that
## carries a dug ball back into offence. Serving and serve receive are the entry
## arm on the left, because a point is *entered* once and then loops until it
## ends; and physical work sits under the arm because it is what everything else
## is standing on rather than a phase of anything.
##
## The ring is written as literal positions rather than derived from a centre and
## a radius: the entry arm is not on the ring, so a generated ring would have to
## be overridden for three of the seven nodes anyway.
const NODES: Array[Dictionary] = [
	{
		"id": "serve", "label": "Serving", "activity": "Serving",
		"position": Vector2(0.11, 0.16),
		"blurb": "First strike. Pressure, aces and the errors that buy them.",
	},
	{
		"id": "receive", "label": "Serve Receive", "activity": "Serve Receive",
		"position": Vector2(0.11, 0.50),
		"blurb": "Platform, balance and getting the ball to the setter.",
	},
	{
		"id": "physical", "label": "Physical", "activity": "Strength & Jump",
		"position": Vector2(0.11, 0.84),
		"blurb": "Jump, engine and the conditioning under all of it.",
	},
	## The ring, clockwise from its top-left.
	{
		"id": "set", "label": "Setting", "activity": "Team Practice",
		"position": Vector2(0.44, 0.19),
		"blurb": "Tempo, disguise and the hands that decide who swings.",
	},
	{
		"id": "attack", "label": "Attack", "activity": "Attack & Transition",
		"position": Vector2(0.88, 0.19),
		"blurb": "Approach, power and the shots that end a rally.",
	},
	{
		"id": "block", "label": "Blocking", "activity": "Blocking & Defense",
		"position": Vector2(0.88, 0.81),
		"blurb": "Reading the set, closing the seam, sealing the tape.",
	},
	{
		"id": "floor", "label": "Floor Defence", "activity": "Blocking & Defense",
		"position": Vector2(0.44, 0.81),
		"blurb": "The space the block leaves, and who is standing in it.",
	},
]

## Which node leads to which, and whether the edge is the rally's forward path or
## the transition loop back into offence.
##
## `bow` is which way the edge arcs: positive bends one way off the straight
## line, negative the other, zero draws straight.
##
## Every ring edge bows *outward* from the ring's centre, by the same amount, so
## the four of them together trace one continuous circle rather than four
## separate links that happen to meet. That is the whole trick behind the
## recycling mark: the arrows are arcs of a single circle, and the eye completes
## it. The entry arm bows the other way so it reads as feeding in from outside.
const EDGES: Array[Dictionary] = [
	{"from": "serve", "to": "receive", "kind": "forward", "bow": 1.0},
	{"from": "receive", "to": "set", "kind": "forward", "bow": 1.0},
	{"from": "set", "to": "attack", "kind": "forward", "bow": -1.0},
	{"from": "attack", "to": "block", "kind": "forward", "bow": -1.0},
	{"from": "block", "to": "floor", "kind": "pair", "bow": -1.0},
	## Transition: the long way home, back up into offence. It closes the ring,
	## so it bows exactly as much as the other three and in the same direction.
	{"from": "floor", "to": "set", "kind": "transition", "bow": -1.0},
	{"from": "physical", "to": "floor", "kind": "support", "bow": -0.6},
]

const NODE_SIZE := Vector2(148.0, 74.0)

## How far an edge bows out of the straight line between two nodes, as a fraction
## of its own length.
##
## Straight rules drew the rally as a wiring diagram: six boxes and the shortest
## line between each pair. A rally is not shortest-path, it is a circuit that
## comes back round, and the drawing should say so before the labels do. Bowed
## edges give the loop a direction of travel the way the recycling mark does --
## you can see which way it turns without reading a word.
##
## Each edge bows to one side or the other by its `bow` sign in EDGES, chosen so
## every arc leans away from the middle of the chart and the loop opens out
## instead of knotting in the centre.
const EDGE_BOW: float = 0.28

## How many segments a curve is drawn in. Enough that the arc reads as a curve
## rather than a chain of chords at the sizes this chart is drawn at.
const CURVE_STEPS: int = 26

## Radius of the dot dropped along a path, and how far apart the dots sit.
##
## The board-game read: a route you travel in steps, not a pipe. The dots are
## what turn a bowed line into a track.
const STEP_DOT_RADIUS: float = 2.6
const STEP_DOT_SPACING: float = 21.0

signal phase_selected(phase_id: String, activity: String)

var _buttons: Dictionary = {}
var _line_color := Color(0.62, 0.66, 0.74, 0.55)
var _transition_color := Color(0.86, 0.68, 0.32, 0.75)


func _ready() -> void:
	## The ring is laid out in normalised space, so the chart wants all the room
	## it can get rather than a fixed box -- a taller chart is a rounder ring.
	## The minimum is the point below which the nodes start to collide.
	custom_minimum_size = Vector2(700.0, 380.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
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
		## Trimmed to where the path actually leaves the box, not to a fixed
		## radius. The first cut backed off half the node's *width* in every
		## direction, which is right leaving a side and nearly twice too much
		## leaving the top or bottom -- so the vertical edges of the ring came out
		## as stubs while the horizontal ones were fine.
		var direction := (to - from).normalized()
		var start := from + direction * _edge_offset(direction)
		var end := to - direction * _edge_offset(direction)
		var points := _curve(start, end, float(edge.get("bow", 0.0)))

		if kind == "pair":
			## Block and floor defence are not sequential -- they happen at once
			## and define each other. Drawn as a tie rather than an arrow, so it
			## gets the dashes and neither an arrowhead nor step dots.
			_draw_dashed_curve(points, colour, width)
			continue

		draw_polyline(points, colour, width, true)
		if kind != "support":
			_draw_steps(points, colour)
		## The head sits on the curve's own final direction. Taking it from the
		## straight chord instead would leave every arrowhead pointing slightly
		## off its own path, which is exactly the tell that a curve was bolted
		## onto a diagram drawn for straight lines.
		var tangent := (points[points.size() - 1] - points[points.size() - 2]).normalized()
		_draw_arrow(points[points.size() - 1], tangent, colour)


## How far from a node's centre its boundary lies, along `direction`.
##
## The box is a rectangle, so this is the smaller of the two axis crossings --
## whichever side the ray leaves through first -- plus a little air so the path
## does not touch the drawn edge.
func _edge_offset(direction: Vector2) -> float:
	var half := NODE_SIZE * 0.5
	var horizontal := INF if is_zero_approx(direction.x) else half.x / absf(direction.x)
	var vertical := INF if is_zero_approx(direction.y) else half.y / absf(direction.y)
	return minf(horizontal, vertical) + 8.0


## A quadratic bend from `start` to `end`, bowing `bow * EDGE_BOW` of its length
## to one side. `bow` of zero gives the straight line back.
func _curve(start: Vector2, end: Vector2, bow: float) -> PackedVector2Array:
	var chord := end - start
	var normal := Vector2(-chord.y, chord.x).normalized()
	var control := start + chord * 0.5 + normal * chord.length() * EDGE_BOW * bow
	var points := PackedVector2Array()
	for index in range(CURVE_STEPS + 1):
		var t := float(index) / float(CURVE_STEPS)
		var inverse := 1.0 - t
		points.append(
			start * inverse * inverse
			+ control * 2.0 * inverse * t
			+ end * t * t
		)
	return points


## Dots along the path, spaced by distance rather than by curve parameter -- a
## quadratic is not travelled at constant speed, so stepping `t` evenly would
## bunch the dots up at the ends of the harder bends.
func _draw_steps(points: PackedVector2Array, colour: Color) -> void:
	var dot := Color(colour, colour.a * 0.85)
	var carried := STEP_DOT_SPACING * 0.5
	for index in range(points.size() - 1):
		var segment := points[index + 1] - points[index]
		var length := segment.length()
		if length <= 0.0:
			continue
		var travelled := carried
		while travelled < length:
			draw_circle(points[index] + segment * (travelled / length), STEP_DOT_RADIUS, dot)
			travelled += STEP_DOT_SPACING
		carried = travelled - length


## `draw_dashed_line` only takes two points, so a dashed curve has to be drawn as
## alternating segments along the polyline.
func _draw_dashed_curve(
	points: PackedVector2Array, colour: Color, width: float
) -> void:
	for index in range(points.size() - 1):
		if index % 2 == 0:
			draw_line(points[index], points[index + 1], colour, width)


func _draw_arrow(tip: Vector2, direction: Vector2, colour: Color) -> void:
	var back := -direction * 11.0
	var side := Vector2(-direction.y, direction.x) * 5.5
	draw_colored_polygon(
		PackedVector2Array([tip, tip + back + side, tip + back - side]), colour
	)
