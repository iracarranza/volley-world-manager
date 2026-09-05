extends RefCounted

## The staging every voli contact sheet wants: a lit dark stage, an orthogonal
## camera fitted to what is actually on it, and a PNG.
##
## Written once because three sheets wanted the same thing and the first of them
## got its framing wrong twice -- once by fitting `size` to a width when it is a
## vertical extent, once by guessing a padding that cropped the widest subject.
## Neither is a mistake worth making in three places.

const RESOLUTION := Vector2i(1920, 1080)


## Lit from the camera's side. The rig faces -Z, so a light over +Z photographs
## the backs of their heads -- which this tool's ancestor did for its whole life.
static func build_stage(root: Window) -> Node3D:
	var stage := Node3D.new()
	root.add_child(stage)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-32.0, 158.0, 0.0)
	light.light_energy = 1.25
	stage.add_child(light)

	var fill := DirectionalLight3D.new()
	## A second, weaker light from the other shoulder. A single source leaves a
	## turned subject's far side unreadable, which matters the moment a sheet
	## shows anything but a facing view.
	fill.rotation_degrees = Vector3(-18.0, 205.0, 0.0)
	fill.light_energy = 0.45
	stage.add_child(fill)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("101722")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("53637d")
	env.ambient_light_energy = 0.95
	environment.environment = env
	stage.add_child(environment)
	return stage


## Framed against content that has already been placed and measured, never
## against an assumed extent.
##
## `size` is the camera's *vertical* extent, so a sheet wider than it is tall is
## fitted through the viewport aspect rather than by passing the width in.
static func frame_camera(
	root: Window, stage: Node3D, width: float, height: float, centre_y: float
) -> Camera3D:
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	camera.size = maxf(
		height, width * float(root.size.y) / maxf(float(root.size.x), 1.0)
	)
	camera.position = Vector3(0.0, centre_y, -9.0)
	stage.add_child(camera)
	return camera


## A ground shadow and a floor ring under a subject lifted into a grid row are
## both drawn in mid-air, and neither is part of the body.
static func present(actor: Node3D, caption: String) -> void:
	actor.set_highlighted(true)
	actor.identity_label.text = caption
	## Cleared above the head rather than resting on it: a Stalk's leaves are the
	## tallest thing on any of these bodies and the default seat puts the caption
	## through them.
	actor.identity_label.position.y += 0.55
	actor.shadow.visible = false
	actor.focus_ring.visible = false


static func save(root: Window, name: String) -> void:
	var path := "user://%s.png" % name
	root.get_texture().get_image().save_png(path)
	print("saved %s" % ProjectSettings.globalize_path(path))
