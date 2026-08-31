extends Control

## Which pages change the size of the container they are put into?
##
##   xvfb-run -a godot --path . --rendering-method gl_compatibility \
##       res://tools/page_container.tscn
##
## A full-screen page is supposed to lay out *inside* the shell it is given. The
## report is that some of them resize the shell instead, which is why the window
## furniture appears to move between pages that should be identical frames.
##
## Asked of each page rather than reasoned about: a fixed-size host is created,
## the page is added to it, several frames are allowed for layout to settle, and
## the host is measured again. A page that lays out inside its container leaves
## the host exactly as it found it.
##
## The host is deliberately the project's own `viewport_height` shape, because a
## page that only misbehaves at some other size is a page that misbehaves at the
## size nobody runs.

const HOST_SIZE := Vector2(1280.0, 720.0)
## Every full-screen page that exists as a scene. The rest of `scenes/screens/`
## is script-only and is reached through one of these, so a page that resizes its
## frame shows up here whichever file authored the offending control.
const PAGES: Array[String] = [
	"res://scenes/screens/journal_screen.tscn",
	"res://scenes/screens/match_screen.tscn",
	"res://scenes/screens/new_career_screen.tscn",
	"res://scenes/screens/new_career_screen_v2.tscn",
	"res://scenes/screens/title_screen.tscn",
]


func _ready() -> void:
	var manager := get_node_or_null("/root/CareerManager")
	if manager != null:
		manager.create_career(
			"Probe Career", "Harbor City VC", "Landavol", "Club", "Balanced"
		)
	print("%-34s %9s %9s %9s %9s   %s" % [
		"page", "host w", "host h", "page w", "page h", "verdict",
	])
	for path in PAGES:
		await _measure(path)
	print("\nA page that lays out inside its container leaves the host at")
	print("%d x %d. Anything else is the page resizing its own frame." % [
		int(HOST_SIZE.x), int(HOST_SIZE.y),
	])
	get_tree().quit()


func _measure(path: String) -> void:
	var packed := load(path) as PackedScene
	if packed == null:
		print("%-34s   could not load" % path.get_file())
		return
	## A plain `Control` rather than a container: a `VBoxContainer` would impose
	## its own sizing and the question is what the *page* does, not what a
	## container does to it.
	var host := Control.new()
	host.custom_minimum_size = HOST_SIZE
	host.size = HOST_SIZE
	add_child(host)
	var page := packed.instantiate()
	host.add_child(page)
	for _settle in 8:
		await get_tree().process_frame
	var control := page as Control
	var page_size := control.size if control != null else Vector2.ZERO
	var moved := not host.size.is_equal_approx(HOST_SIZE)
	print("%-34s %9.1f %9.1f %9.1f %9.1f   %s" % [
		path.get_file(), host.size.x, host.size.y,
		page_size.x, page_size.y,
		"RESIZES ITS CONTAINER" if moved else "",
	])
	page.queue_free()
	host.queue_free()
	await get_tree().process_frame
