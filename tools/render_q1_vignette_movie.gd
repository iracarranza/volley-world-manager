extends SceneTree

## Movie Maker harness for reviewing the actual 02 VOLLEYBALL Q1 preview in motion.
## Q1 now plays a real resolved RallyResult through MatchScreen, so the capture
## window is deliberately longer than the old authored 5.2-second puppet loop.

const SIZE := Vector2i(1280, 720)
const DARK_THEME := preload("res://scenes/themes/dark_theme.tres")
const CAREER_SCENE := preload("res://scenes/screens/new_career_screen_v2.tscn")
const CHOICES := {"quick": 0, "read": 1, "hitter": 2}
const CAPTURE_SECONDS := 8.0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var mode := "quick" if args.is_empty() else str(args[0]).to_lower()
	if not CHOICES.has(mode):
		push_error("Unknown Q1 vignette '%s'; expected quick, read, or hitter." % mode)
		quit(2)
		return

	root.size = SIZE
	var screen := CAREER_SCENE.instantiate()
	screen.theme = DARK_THEME
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(screen)
	await process_frame
	await process_frame

	screen.debug_show_volleyball_question_for_render(0, int(CHOICES[mode]))
	await process_frame
	await process_frame

	var preview := screen.get("_volleyball_preview") as Node
	if preview == null:
		push_error("Q1 movie renderer could not find the live volleyball preview.")
		quit(3)
		return
	preview.process_mode = Node.PROCESS_MODE_INHERIT
	preview.call(
		"set_vignette",
		["good_ball_quick", "good_ball_read", "good_ball_hitter"][int(CHOICES[mode])]
	)

	## Fixed-fps capture watches a complete production rally and the beginning of
	## its deterministic replay. There is no independent preview clock to sync.
	var fps := 30
	var frames := int(ceil(CAPTURE_SECONDS * float(fps)))
	for _frame in range(frames):
		await process_frame
	quit()
