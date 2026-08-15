class_name TitleDeskSurface
extends Control

## The title screen's right-hand column, read as the same desk seen later from
## the chair. Here the camera is directly overhead: the desk is against the
## right wall, its working edge faces left, and its long dimension runs down the
## room. The menu remains a normal Control above this drawing; these are the
## physical things underneath it, not replacements for its controls.

const UIPalette := preload("res://scripts/data/ui_palette.gd")

var light_mode: bool = false
var departure: float = 0.0:
	set(value):
		departure = clampf(value, 0.0, 1.0)
		queue_redraw()

func _ready() -> void:
	set_meta("ui_style_exempt", true)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func set_light_mode(value: bool) -> void:
	light_mode = value
	queue_redraw()


func reset_departure() -> void:
	departure = 0.0
	modulate = Color.WHITE


func _draw() -> void:
	var desk := _desk_rect()
	var floor := Color("b8ad9a") if light_mode else Color("171416")
	var wall := Color("d5cec0") if light_mode else Color("211e23")
	var wood := Color("79583b") if light_mode else Color("2b2019")
	draw_rect(Rect2(Vector2(size.x * 0.545, 0.0), Vector2(size.x * 0.455, size.y)), floor)
	draw_rect(Rect2(Vector2(size.x - 18.0, 0.0), Vector2(18.0, size.y)), wall)

	# A top-down camera has no trapezoid: the right edge is literally flush with
	# the wall. During departure these four physical corners travel to the exact
	# four corners used by DeskScreen's chair-view projection.
	var corners := PackedVector2Array([
		_project(desk.position), _project(Vector2(desk.end.x, desk.position.y)),
		_project(desk.end), _project(Vector2(desk.position.x, desk.end.y)),
	])
	# The chair is genuinely under the desk: draw it first, then let the top hide
	# the seat. Only the back and a slim upholstered crescent remain at the left.
	_draw_chair(desk)
	draw_colored_polygon(corners, wood)
	_draw_wood(desk, wood)

	# Objects follow the later desk screen's staging, rotated as a group with the
	# room: books/lamp at the far end, journal central, phone and machine against
	# the wall, work boards and folders toward the manager.
	_draw_book(_object_rect(desk, 0.10, 0.05, 0.19, 0.14), -5.0, Color("4a664f"))
	_draw_book(_object_rect(desk, 0.17, 0.08, 0.20, 0.15), 7.0, Color("6c4a66"))
	_draw_lamp(_object_rect(desk, 0.06, 0.27, 0.18, 0.13))
	_draw_phone(_object_rect(desk, 0.08, 0.78, 0.19, 0.15))

	var journal := _object_rect(desk, 0.29, 0.43, 0.25, 0.27)
	_draw_book(journal, -2.0, Color("2c536b") if light_mode else Color("17384b"), true)
	_draw_machine(_object_rect(desk, 0.31, 0.79, 0.16, 0.16))
	_draw_board(_object_rect(desk, 0.48, 0.07, 0.32, 0.25))
	_draw_clipboard(_object_rect(desk, 0.50, 0.30, 0.29, 0.23), 6.0)
	_draw_folder(_object_rect(desk, 0.72, 0.35, 0.22, 0.27))
	_draw_pad(_object_rect(desk, 0.70, 0.64, 0.24, 0.22), 7.0)
	_draw_mug(_object_rect(desk, 0.39, 0.68, 0.10, 0.10))
	_draw_pencil_cup(_object_rect(desk, 0.81, 0.83, 0.10, 0.10))

	# The wall/desk seam remains visible beside the panel and makes the flush
	# placement unambiguous even when the menu covers most of the wood.
	draw_line(_project(Vector2(desk.end.x, desk.position.y)),
		_project(desk.end), Color(0.02, 0.02, 0.02, 0.42), 5.0)


func _desk_rect() -> Rect2:
	return Rect2(Vector2(size.x * 0.565, 18.0), Vector2(size.x * 0.425, size.y - 36.0))


## Map a point on the overhead title plane into the desk screen's real camera.
##
## The title desk has its 140cm axis running down the screen and its 70cm depth
## running from the right wall toward the chair on the left. `DeskScreen` has
## that same 140cm axis across the screen and depth running from its far edge to
## the chair. Converting the point to those two physical coordinates gives us
## its exact destination under DeskScreen's projection:
##
##     x = centre + (u - .5) * width * lerp(.8, 1, v)
##     y = .32 * height + v * (height - .32 * height - 12)
##
## Interpolating from the original point to that destination is important. The
## previous version changed coordinate systems on frame one, recentering every
## point around the journal before applying an almost-zero rotation; that was
## the visible sideways snap. At departure zero this function is now exactly
## the identity, and at departure one it is exactly DeskScreen's camera.
func _project(point: Vector2) -> Vector2:
	if departure <= 0.001:
		return point
	var desk := _desk_rect()
	var u := (point.y - desk.position.y) / desk.size.y
	var v := (desk.end.x - point.x) / desk.size.x
	var target_top := size.y * 0.32
	var target_depth := size.y - target_top - 12.0
	var narrowing := lerpf(0.80, 1.0, v)
	var target := Vector2(
		size.x * 0.5 + (u - 0.5) * size.x * narrowing,
		target_top + v * target_depth,
	)
	var eased := ease(departure, -2.2)
	return point.lerp(target, eased)


func _object_rect(desk: Rect2, along: float, inward: float, long_size: float, depth_size: float) -> Rect2:
	# Desk-local x is inward from the wall; y is along its long edge.
	var x := desk.end.x - desk.size.x * (inward + depth_size)
	var y := desk.position.y + desk.size.y * along
	return Rect2(Vector2(x, y), Vector2(desk.size.x * depth_size, desk.size.y * long_size))


func _poly(rect: Rect2, angle: float = 0.0) -> PackedVector2Array:
	var centre := rect.get_center()
	var points := PackedVector2Array()
	for point in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
			Vector2(rect.position.x, rect.end.y)]:
		points.append(_project(centre + (point - centre).rotated(deg_to_rad(angle))))
	return points


func _shadow(rect: Rect2, angle: float = 0.0) -> void:
	var shifted := Rect2(rect.position + Vector2(-5.0, 7.0), rect.size)
	draw_colored_polygon(_poly(shifted, angle), Color(0.0, 0.0, 0.0, 0.24))


func _draw_wood(desk: Rect2, wood: Color) -> void:
	for board in range(1, 14):
		var y := desk.position.y + desk.size.y * float(board) / 14.0
		draw_line(_project(Vector2(desk.position.x, y)), _project(Vector2(desk.end.x, y)),
			Color(wood.darkened(0.24), 0.42), 1.2)
	for streak in range(22):
		var seed := ((streak + 9) * 2654435761) & 0x7fffffff
		var y := desk.position.y + desk.size.y * float(seed % 1000) / 1000.0
		var x := desk.position.x + desk.size.x * float((seed / 1000) % 600) / 1000.0
		draw_line(_project(Vector2(x, y)), _project(Vector2(minf(x + desk.size.x * 0.28, desk.end.x), y)),
			Color(wood.lightened(0.12), 0.18), 2.0)


func _draw_chair(desk: Rect2) -> void:
	# Drawn after the top for a crisp partial silhouette, but most of the seat is
	# still geometrically under the desk. Only the back and left lip escape it.
	var centre := Vector2(desk.position.x - 18.0, desk.position.y + desk.size.y * 0.62)
	var chair := Color("82715f") if light_mode else Color("302a29")
	var back_shadow := PackedVector2Array()
	var back := PackedVector2Array()
	for step in range(25):
		var angle := TAU * float(step) / 24.0
		var point := centre + Vector2(cos(angle) * 45.0, sin(angle) * 76.0)
		back_shadow.append(_project(point + Vector2(-5.0, 7.0)))
		back.append(_project(point))
	draw_colored_polygon(back_shadow, Color(0.0, 0.0, 0.0, 0.28))
	draw_colored_polygon(back, chair.darkened(0.10))
	var seat := Rect2(centre - Vector2(2.0, 57.0), Vector2(62.0, 114.0))
	draw_colored_polygon(_poly(seat), chair)
	var seam := PackedVector2Array()
	for step in range(13):
		var angle := lerpf(-PI * 0.48, PI * 0.48, float(step) / 12.0)
		seam.append(_project(centre + Vector2(cos(angle) * -35.0, sin(angle) * 61.0)))
	draw_polyline(seam, Color(chair.lightened(0.18), 0.82), 5.0)


func _draw_book(rect: Rect2, angle: float, cloth: Color, journal: bool = false) -> void:
	_shadow(rect, angle)
	draw_colored_polygon(_poly(rect, angle), cloth)
	var edge := Rect2(rect.position + Vector2(rect.size.x * 0.08, rect.size.y * 0.88),
		Vector2(rect.size.x * 0.84, rect.size.y * 0.08))
	draw_colored_polygon(_poly(edge, angle), Color("c9bea2") if light_mode else Color("777064"))
	if journal:
		var c := _project(rect.get_center())
		var r := minf(rect.size.x, rect.size.y) * 0.18
		draw_arc(c, r, 0.0, TAU, 24, Color(cloth.lightened(0.26), 0.72), 2.0)
		for seam in range(3):
			var a := TAU * float(seam) / 3.0
			draw_arc(c + Vector2(cos(a), sin(a)) * r * 0.18, r * 0.74,
				a - 0.9, a + 0.9, 10, Color(cloth.lightened(0.26), 0.65), 1.4)


func _draw_clipboard(rect: Rect2, angle: float) -> void:
	_shadow(rect, angle)
	draw_colored_polygon(_poly(rect, angle), Color("9a7049") if light_mode else Color("4d3728"))
	var sheet := rect.grow_individual(-rect.size.x * 0.10, -rect.size.y * 0.12,
		-rect.size.x * 0.10, -rect.size.y * 0.06)
	draw_colored_polygon(_poly(sheet, angle), Color("eee9da") if light_mode else Color("aaa69c"))
	var clip := Rect2(Vector2(rect.get_center().x - rect.size.x * 0.18, rect.position.y),
		Vector2(rect.size.x * 0.36, rect.size.y * 0.10))
	draw_colored_polygon(_poly(clip, angle), Color("aeb3b6"))


func _draw_board(rect: Rect2) -> void:
	_shadow(rect)
	draw_colored_polygon(_poly(rect), Color("9b7047") if light_mode else Color("493426"))
	for i in range(5):
		var row := i / 2
		var col := i % 2
		var slip := Rect2(rect.position + Vector2(8.0 + col * rect.size.x * 0.46,
			8.0 + row * rect.size.y * 0.29), rect.size * Vector2(0.34, 0.21))
		draw_colored_polygon(_poly(slip, -4.0 + i * 2.0), Color("e9e3d4") if light_mode else Color("aaa69b"))
		draw_circle(_project(slip.position + Vector2(slip.size.x * 0.5, 3.0)), 2.5,
			[Color("c8443a"), Color("d9982f"), Color("3f7d52")][i % 3])


func _draw_folder(rect: Rect2) -> void:
	_shadow(rect, -4.0)
	draw_colored_polygon(_poly(rect, -4.0), Color("d9bd83") if light_mode else Color("514126"))
	var tab := Rect2(rect.position + Vector2(rect.size.x * 0.48, -5.0), Vector2(rect.size.x * 0.34, 10.0))
	draw_colored_polygon(_poly(tab, -4.0), Color("d9bd83") if light_mode else Color("514126"))


func _draw_pad(rect: Rect2, angle: float) -> void:
	_shadow(rect, angle)
	draw_colored_polygon(_poly(rect, angle), Color("e7e1d0") if light_mode else Color("706d65"))
	for i in range(4):
		var y := rect.position.y + rect.size.y * (0.30 + i * 0.14)
		draw_line(_project(Vector2(rect.position.x + 8.0, y)),
			_project(Vector2(rect.end.x - 8.0, y)), Color(0.25, 0.35, 0.42, 0.38), 1.0)


func _draw_phone(rect: Rect2) -> void:
	_shadow(rect, -3.0)
	draw_colored_polygon(_poly(rect, -3.0), Color("30343a") if light_mode else Color("1d2025"))
	var handset := Rect2(rect.position + Vector2(3.0, rect.size.y * 0.18),
		Vector2(rect.size.x - 6.0, rect.size.y * 0.34))
	draw_colored_polygon(_poly(handset, -3.0), Color("535960") if light_mode else Color("30353b"))


func _draw_machine(rect: Rect2) -> void:
	_shadow(rect, 3.0)
	draw_colored_polygon(_poly(rect, 3.0), Color("353a40") if light_mode else Color("22262b"))
	for i in range(3):
		draw_circle(_project(rect.position + Vector2(rect.size.x * (0.28 + i * 0.22), rect.size.y * 0.68)),
			2.2, Color("b64c3d") if i == 0 else Color("8d9294"))


func _draw_lamp(rect: Rect2) -> void:
	var metal := Color("4c5660") if light_mode else Color("2b323a")
	var base := _project(rect.get_center() + Vector2(0.0, rect.size.y * 0.20))
	var elbow := _project(rect.get_center() - Vector2(rect.size.x * 0.50, rect.size.y * 0.14))
	var head := _project(rect.get_center() + Vector2(rect.size.x * 0.25, -rect.size.y * 0.42))
	draw_circle(base + Vector2(-4.0, 6.0), rect.size.x * 0.40, Color(0.0, 0.0, 0.0, 0.22))
	draw_circle(base, rect.size.x * 0.40, metal)
	draw_line(base, elbow, metal.lightened(0.14), 6.0)
	draw_line(elbow, head, metal.lightened(0.14), 6.0)
	draw_circle(elbow, 4.0, metal.lightened(0.30))
	draw_colored_polygon(PackedVector2Array([head + Vector2(-15, -7), head + Vector2(15, -7),
		head + Vector2(10, 9), head + Vector2(-10, 9)]), metal)


func _draw_mug(rect: Rect2) -> void:
	var c := _project(rect.get_center())
	var china := Color("c6d3d0") if light_mode else Color("6d7c7a")
	draw_circle(c + Vector2(-4.0, 5.0), rect.size.x * 0.44, Color(0.0, 0.0, 0.0, 0.22))
	draw_arc(c + Vector2(rect.size.x * 0.42, 0.0), rect.size.x * 0.30, -PI * 0.55, PI * 0.55, 12, china, 5.0)
	draw_circle(c, rect.size.x * 0.44, china)
	draw_circle(c, rect.size.x * 0.32, Color("4b3323"))


func _draw_pencil_cup(rect: Rect2) -> void:
	var c := _project(rect.get_center())
	draw_circle(c, rect.size.x * 0.42, Color("5d665b") if light_mode else Color("343a33"))
	for shift in [-0.20, 0.05, 0.24]:
		draw_line(c + Vector2(rect.size.x * shift, 2.0),
			c + Vector2(rect.size.x * shift - 4.0, -rect.size.y * 0.75),
			Color("d5a24b") if shift < 0.2 else Color("b84c42"), 3.0)
