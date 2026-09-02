extends Node

## Standing still, is the sole flat on the floor or up on its toe?
##
##   xvfb-run -a godot --path . res://tools/sole_contact.tscn
##
## The report is that the ready stance reads unbalanced because the volis are on
## their toes. That is a claim about the drawn shoe, not about a joint angle, so
## it is asked of the shoe: the difference in world height between the front of
## the shoe's bounds and the back of them, with the body standing still.
##
## Zero is a flat sole. Positive means the heel is higher than the toe, which is
## being up on the toes. Negative means the toe is up, which would be worse.
##
## There is a reason to expect a lift. `GaitBiomechanics.resolve` lerps both
## ankles toward **0.0** as `gait_blend` falls to zero, while its own comment for
## the stance phase says the ankle "cancels hip and knee exactly, so the sole is
## held flat". Those are different rules, and at a standstill the second one is
## not the one running -- so the shank carries the leg's fold and the shoe goes
## with it.

const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const STANCES: Array[String] = ["defending", "blocking", "watching"]
const BODY_TYPES: Array[String] = [
	"Vegi", "Feli", "Avi", "Cani", "Ursi", "Simi",
]


func _ready() -> void:
	print("%-8s %-10s %10s   %s" % ["body", "stance", "pitch", "verdict"])
	for body_type in BODY_TYPES:
		for stance in STANCES:
			var actor: Node3D = ACTOR.instantiate()
			add_child(actor)
			actor.configure(1, true, "Probe", "Right", {
				"height_cm": 186.0, "mass_kg": 82.0, "wingspan_cm": 191.0,
				"body_type": body_type,
			})
			actor.ready_stance = stance
			## Standing: no contact, no travel, so the gait blend is zero and the
			## stance is undiluted -- which is the case the report is about.
			## **Let the stance transition finish.** `ready_stance` is a setter that
			## starts a blend rather than an assignment, so reading after one frame
			## measures a body partway between the default crouch and the stance
			## asked for -- which is what made Vegi's blocking read -33 while the
			## other five read +1.6, a spread that is the clock and not the body.
			for _settle in 90:
				actor.set_pose(-1, 0.0, 0.0, Vector2.ZERO, false)
				await get_tree().process_frame
			_soles(actor, body_type, stance)
			actor.queue_free()
	print("\npitch = degrees forward of the shoe's authored orientation.")
	print("Near 0 is a foot under the body; a poised stance carries the weight")
	print("forward but keeps the heel down, which is under about 15 degrees.")
	get_tree().quit()


func _soles(actor: Node3D, body_type: String, stance: String) -> void:
	for side in ["LeftLeg", "RightLeg"]:
		var shoe := actor.get_node_or_null(
			NodePath("BodyPivot/%s/Knee/Shoe" % side)
		) as MeshInstance3D
		if shoe == null or shoe.mesh == null:
			continue
		## **Measured against the shoe's own authored orientation, not against
		## vertical.**
		##
		## The first version of this probe took the lowest-z and highest-z corners
		## of the shoe's AABB and called them toe and heel. That gave every body
		## an 11 to 24 cm "toe up", which is 30 to 70 degrees and cannot be right.
		## The shoe is a capsule whose long axis is **y** -- it is most of the
		## lower leg, as `_add_garments`' removed sock-top note says -- so its z
		## extent is a few centimetres and an extreme-z corner can sit at either
		## end of the capsule. The two corners being compared were mostly
		## different heights up the shin.
		##
		## The second version then measured the shoe's local y against world up and
		## called the difference pitch. That is wrong too, and wrong in a way that
		## produced confident verdicts: `SHOE_BASE_PITCH_DEGREES` is 90, because
		## the mesh is modelled lying down and stood up by the scene, so the
		## shoe's local y points *along the foot* rather than up out of it. A
		## correctly flat shoe reads 90 in that measure, not 0 -- so every "on the
		## toes" and every "heels" it printed was against a reference the rig does
		## not use.
		##
		## Subtracting the authored base is what makes the number mean what it
		## says: 0 is a shoe sitting as modelled, positive is tipped forward onto
		## the front of the foot, negative is back onto the heel.
		var along := shoe.global_transform.basis.y.normalized()
		var pitch := rad_to_deg(atan2(-along.z, along.y)) \
			+ PlayerActor3D.SHOE_BASE_PITCH_DEGREES
		if side == "RightLeg":
			print("%-8s %-10s %10.2f   %s" % [
				body_type, stance, pitch,
				## Poised is *weight forward*, which is not the same as up on the
				## toes: a real ready stance carries the weight over the front of
				## the foot with the heels light but down. Past about 15 degrees
				## the heel has to leave the floor, and that is the posture a body
				## cannot hold.
				"ON THE TOES" if pitch > 15.0
				else ("poised" if pitch > 6.0
				else ("heels" if pitch < -6.0 else "under the body")),
			])
