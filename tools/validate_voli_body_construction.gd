extends SceneTree

const Bodies := preload("res://scripts/data/body_type_models.gd")
const Faces := preload("res://scripts/data/face_expressions.gd")
const ActorScene := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEvent := preload("res://scripts/models/rally_event.gd")

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _extra(spec: Dictionary, name: String) -> Dictionary:
	for raw_part in spec.get("extras", []):
		var part: Dictionary = raw_part
		if str(part.get("name", "")) == name:
			return part
	return {}


## Face parts by name rather than by index. `parts()` returned eyes then mouth
## when this file was written; pupils were later interleaved after each eye, so
## every positional face assertion below silently retargeted -- see the NOTE at
## the call site.
func _part(parts: Array, name: String) -> Dictionary:
	for raw_part in parts:
		var part: Dictionary = raw_part
		if str(part.get("name", "")) == name:
			return part
	return {}


func _run() -> void:
	var produce_signatures: Dictionary = {}
	for produce in Bodies.PRODUCE:
		var spec: Dictionary = Bodies.silhouette(
			"Vegi", 41, {"produce": produce, "marking": "none"}
		)
		var torso: Dictionary = spec.get("torso", {})
		_check(str(torso.get("shape", "")) == "profile", "%s is not purpose-built" % produce)
		_check(Array(torso.get("profile", [])).size() >= 5, "%s profile lacks resolution" % produce)
		produce_signatures[str(torso.get("profile", []))] = true
		_check(Bodies.build_mesh(torso).get_faces().size() > 0, "%s torso mesh is empty" % produce)
	_check(produce_signatures.size() == Bodies.PRODUCE.size(), "produce torso profiles are duplicated")

	var animal_signatures: Dictionary = {}
	for body_type in ["Feli", "Avi", "Cani", "Ursi", "Simi"]:
		var spec: Dictionary = Bodies.silhouette(
			body_type, 57, {"marking": "none"}
		)
		var torso: Dictionary = spec.get("torso", {})
		_check(str(torso.get("shape", "")) == "profile", "%s still uses a shared primitive" % body_type)
		animal_signatures[str(torso.get("profile", []))] = true
	_check(animal_signatures.size() == 5, "animal torso profiles are duplicated")
	var light_build: Dictionary = Bodies.silhouette(
		"Feli", 59, {"build": "light", "marking": "none"}
	)
	var heavy_build: Dictionary = Bodies.silhouette(
		"Feli", 59, {"build": "heavy", "marking": "none"}
	)
	var light_profile: Array = light_build.get("torso", {}).get("profile", [])
	var heavy_profile: Array = heavy_build.get("torso", {}).get("profile", [])
	_check(
		float((heavy_profile[2] as Vector2).y) > float((light_profile[2] as Vector2).y),
		"authored profiles ignore build girth",
	)

	var pepper: Dictionary = Bodies.silhouette(
		"Vegi", 61, {"produce": "Pepper", "marking": "none"}
	).get("torso", {})
	_check(int(pepper.get("lobes", 0)) == 4, "Pepper is not a continuous four-lobe body")
	_check(float(pepper.get("lobe_depth", 0.0)) >= 0.20, "Pepper lobes are visually weak")
	var tomato: Dictionary = Bodies.silhouette(
		"Vegi", 61, {"produce": "Tomato", "marking": "none"}
	).get("torso", {})
	_check(int(tomato.get("lobes", 0)) == 6, "Tomato lacks produce-derived lobing")

	var feli := Bodies.silhouette("Feli", 73, {"marking": "none"})
	var avi := Bodies.silhouette("Avi", 73, {"marking": "none"})
	var cani := Bodies.silhouette("Cani", 73, {"marking": "none"})
	var ursi := Bodies.silhouette("Ursi", 73, {"marking": "none"})
	var simi := Bodies.silhouette("Simi", 73, {"marking": "none"})
	_check(str(_extra(feli, "EarLeft").get("shape", "")) == "cone", "Feli ear lost its point")
	_check(str(_extra(cani, "EarLeft").get("shape", "")) == "profile", "Cani ear is not a flap")
	_check(str(_extra(ursi, "EarLeft").get("shape", "")) == "sphere", "Ursi ear is not round")
	_check(str(_extra(simi, "BrowLeft").get("shape", "")) == "sphere", "Simi brow is still a box")
	_check(str(_extra(feli, "Muzzle").get("shape", "")) == "wedge", "Feli still has the legacy round muzzle")
	_check(str(_extra(feli, "Muzzle").get("color", "")) == "skin", "Feli muzzle is still a face patch")
	for wing_name in ["WingCovertLeft", "WingPrimaryLeft", "WingCovertRight", "WingPrimaryRight"]:
		var wing := _extra(avi, wing_name)
		_check(str(wing.get("shape", "")) == "fan", "%s is not a folding wing fan" % wing_name)
		_check(str(wing.get("ink", "")) == "body", "%s uses the noisy cosmetic outline" % wing_name)
	var face_parts := Faces.parts("neutral", 0.18, 0.17)
	## NOTE keyed by name -- pupils were interleaved into a positional read and
	## silently moved the mouth assertion onto the right eye
	for eye_name in ["EyeL", "EyeR"]:
		_check(
			str(_part(face_parts, eye_name).get("ink", "")) == "none",
			"%s still receives an independent outline hull" % eye_name,
		)
	for pupil_name in ["PupilL", "PupilR"]:
		_check(
			str(_part(face_parts, pupil_name).get("ink", "")) == "none",
			"%s still receives an independent outline hull" % pupil_name,
		)
	_check(
		str(_part(face_parts, "Mouth").get("shape", "")) == "stroke",
		"mouth is still assembled from legacy boxes",
	)
	_check(str(face_parts[2].get("ink", "")) == "none", "mouth stroke receives a second outline")

	var actor := ActorScene.instantiate() as PlayerActor3D
	root.add_child(actor)
	actor.configure(91, true, "motion gate", "Right", {
		"height_cm": 188.0, "wingspan_cm": 191.0,
		"stride_length_m": 0.81, "body_type": "Feli",
		"appearance": {"marking": "none"},
	})
	var samples: Array[Vector3] = []
	for phase in [-0.58, -0.18, 0.18, 0.62]:
		actor.set_pose(
			RallyEvent.EventType.ATTACK, 0.5, phase, Vector2.RIGHT, true
		)
		samples.append(Vector3(
			actor.torso.scale.x, actor.torso.scale.y, actor.body_pivot.rotation.z
		))
	var unique_samples: Dictionary = {}
	for sample in samples:
		unique_samples[str(sample)] = true
	_check(unique_samples.size() == samples.size(), "attack phases do not produce distinct body deformation")
	_check(absf(samples[0].z - samples[2].z) > deg_to_rad(4.0), "load/contact weight transfer is too small")
	actor.queue_free()

	var light_actor := ActorScene.instantiate() as PlayerActor3D
	var heavy_actor := ActorScene.instantiate() as PlayerActor3D
	root.add_child(light_actor)
	root.add_child(heavy_actor)
	var shared_profile := {
		"height_cm": 188.0, "wingspan_cm": 191.0,
		"stride_length_m": 0.81, "body_type": "Feli",
		"appearance": {"marking": "none"},
	}
	var light_physical := shared_profile.duplicate(true)
	var heavy_physical := shared_profile.duplicate(true)
	light_physical["mass_kg"] = 60.0
	heavy_physical["mass_kg"] = 112.0
	light_actor.configure(92, true, "light", "Right", light_physical)
	heavy_actor.configure(93, true, "heavy", "Right", heavy_physical)
	_check(heavy_actor.torso.scale.x > light_actor.torso.scale.x, "mass does not change torso girth")
	_check(heavy_actor.left_arm.scale.x > light_actor.left_arm.scale.x, "mass does not change limb girth")
	_check(is_equal_approx(heavy_actor.left_leg.scale.y, light_actor.left_leg.scale.y), "mass changes leg length")
	light_actor.queue_free()
	heavy_actor.queue_free()

	var short_actor := ActorScene.instantiate() as PlayerActor3D
	var long_actor := ActorScene.instantiate() as PlayerActor3D
	root.add_child(short_actor)
	root.add_child(long_actor)
	var short_physical := shared_profile.duplicate(true)
	var long_physical := shared_profile.duplicate(true)
	short_physical["wingspan_cm"] = 176.0
	short_physical["stride_length_m"] = 0.62
	long_physical["wingspan_cm"] = 212.0
	long_physical["stride_length_m"] = 1.02
	short_actor.configure(94, true, "short", "Right", short_physical)
	long_actor.configure(95, true, "long", "Right", long_physical)
	var short_upper := short_actor.left_arm.get_node("Mesh") as MeshInstance3D
	var long_upper := long_actor.left_arm.get_node("Mesh") as MeshInstance3D
	_check(long_upper.scale.y > short_upper.scale.y, "wingspan does not change arm length")
	_check(long_actor.left_leg.scale.y > short_actor.left_leg.scale.y, "stride does not change leg length")
	short_actor.queue_free()
	long_actor.queue_free()

	if failures.is_empty():
		print("VOLI BODY CONSTRUCTION: PASS (5 produce, 5 animals, mass/reach/stride geometry, 4 motion phases)")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("VOLI BODY CONSTRUCTION: FAIL (%d)" % failures.size())
	quit(1)
