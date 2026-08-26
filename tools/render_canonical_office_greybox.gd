extends SceneTree
## Headless render harness for the canonical office greybox.
## Writes seven PNGs to artifacts/canonical-office-greybox/.

const OFFICE := preload("res://scenes/office/canonical_office_greybox.tscn")
const OUTPUT_DIR := "res://artifacts/canonical-office-greybox"
const CAMERA_NAMES := [
	"MainMenu",
	"TransitionMid",
	"Desk",
	"Calendar",
	"Door",
	"Interview",
	"OfficeWide",
]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var office := OFFICE.instantiate()
	root.add_child(office)
	await process_frame
	await process_frame
	var cams := office.get_node("Cameras")
	for camera_name in CAMERA_NAMES:
		for child in cams.get_children():
			if child is Camera3D:
				child.current = child.name == camera_name
		await process_frame
		await process_frame
		var image := root.get_viewport().get_texture().get_image()
		var path := "%s/%s.png" % [OUTPUT_DIR, _slug(camera_name)]
		var err := image.save_png(path)
		if err != OK:
			push_error("Could not write %s: %s" % [path, error_string(err)])
		else:
			print("OFFICE_RENDER ", path)
	quit()

func _slug(value: String) -> String:
	var out := ""
	for i in value.length():
		var ch := value.substr(i, 1)
		if ch.to_lower() != ch.to_upper() and ch == ch.to_upper() and i > 0:
			out += "_"
		out += ch.to_lower()
	return out
