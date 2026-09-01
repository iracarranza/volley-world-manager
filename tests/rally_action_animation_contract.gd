extends SceneTree

const Serve := preload("res://scripts/data/serve_action_biomechanics.gd")
const Defense := preload("res://scripts/data/defense_action_biomechanics.gd")
const SetMotion := preload("res://scripts/data/set_biomechanics.gd")
const Attack := preload("res://scripts/data/attack_action_biomechanics.gd")
const Idle := preload("res://scripts/data/idle_biomechanics.gd")
const PlayerActor := preload("res://scenes/components/player_actor_3d.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("RALLY ACTION ANIMATION: %s" % message)


func _finite_joints(joints: Dictionary, label: String) -> void:
	for key in [
		"striking_shoulder_degrees", "striking_elbow_degrees",
		"torso_pitch_radians", "lead_hip_degrees", "trail_hip_degrees",
		"knee_degrees", "rise_metres",
	]:
		_check(is_finite(float(joints.get(key, NAN))), "%s has invalid %s" % [label, key])


func _run() -> void:
	var contact_shapes := {}
	for style in Serve.STYLES:
		var contact := Serve.resolve(0.0, 1.0, 0.78, style, 1)
		_finite_joints(contact, style)
		contact_shapes[style] = "%s|%.1f|%.1f|%.3f" % [
			contact.support,
			float(contact.striking_shoulder_degrees),
			float(contact.striking_elbow_degrees),
			float(contact.rise_metres),
		]
	var unique_contact_shapes: Array = []
	for shape in contact_shapes.values():
		if shape not in unique_contact_shapes:
			unique_contact_shapes.append(shape)
	_check(unique_contact_shapes.size() == Serve.STYLES.size(),
		"every serve style needs a distinct contact silhouette")
	_check(float(Serve.resolve(0.0, 1.0, 0.7, Serve.JUMP_TOPSPIN).rise_metres) > 0.45,
		"jump topspin must be airborne at contact")
	_check(float(Serve.resolve(0.0, 1.0, 0.7, Serve.JUMP_FLOAT).rise_metres) > 0.24,
		"jump float must be airborne at contact")
	_check(is_zero_approx(float(Serve.resolve(0.0, 1.0, 0.7, Serve.STANDING).rise_metres)),
		"standing serve must remain grounded")
	var sky := Serve.resolve(0.0, 1.0, 0.7, Serve.SKY_BALL)
	_check(bool(sky.underhand) and is_zero_approx(float(sky.rise_metres)),
		"sky ball must use a grounded underhand chain")
	_check(Serve.routine_variant(42) == Serve.routine_variant(42),
		"serve routine must be stable per actor")

	var no_dive := Defense.resolve(0.0, false)
	var dive_commit := Defense.resolve(-0.16, true)
	var dive_floor := Defense.resolve(0.24, true)
	_check(is_zero_approx(float(no_dive.forward_metres)), "ordinary reception gained dive travel")
	_check(float(dive_commit.forward_metres) > 0.0 and float(dive_commit.drop_metres) > 0.0,
		"diving receive must travel toward and down to the ball before contact")
	_check(float(dive_floor.drop_metres) > float(dive_commit.drop_metres),
		"diving receive must arrive on the floor after contact")
	_check(Defense.is_diving("reaching", "fall") and not Defense.is_diving("planted", "platform"),
		"published posture/recovery must select diving without inventing a new verdict")
	var slide_impact := PlayerActor.recovery_motion(
		"fall", "reaching", 0.82, Vector2.UP
	)
	var slide_finish := PlayerActor.recovery_motion(
		"fall", "reaching", 1.0, Vector2.UP
	)
	_check(-Vector3(slide_impact.offset).z > 0.30,
		"dive recovery must preserve its established forward slide through impact")
	_check(absf(Vector3(slide_finish.offset).z) < 0.01 \
		and absf(float(slide_finish.pitch_radians)) < 0.01,
		"dive recovery must hand back a neutral local transform at phase end")

	for posture in [SetMotion.POSTURE_STANDING, SetMotion.POSTURE_JUMP, SetMotion.POSTURE_UNDERHAND]:
		var front := SetMotion.resolve(0.0, 1.0, posture, false)
		var back := SetMotion.resolve(0.0, 1.0, posture, true)
		_check(back.posture == front.posture, "back set changed support posture")
		_check(float(back.torso_pitch_radians) > float(front.torso_pitch_radians),
			"back set must arch farther than its front-set counterpart")
		_check(float(back.shoulder_degrees) > float(front.shoulder_degrees),
			"back set must carry the hands behind the crown")

	var power_sell := Attack.resolve(-0.36, 1.0, 0.8, "Power swing")
	var roll_sell := Attack.resolve(-0.36, 1.0, 0.8, "Roll shot")
	var dink_sell := Attack.resolve(-0.36, 1.0, 0.8, "Dink")
	for key in [
		"striking_shoulder_degrees", "striking_elbow_degrees",
		"guide_shoulder_degrees", "torso_pitch_radians", "knee_degrees",
	]:
		_check(is_equal_approx(float(power_sell[key]), float(roll_sell[key])) \
			and is_equal_approx(float(power_sell[key]), float(dink_sell[key])),
			"soft shots changed the sold approach at %s" % key)
	var power_contact := Attack.resolve(0.0, 1.0, 0.8, "Power swing")
	var roll_contact := Attack.resolve(0.0, 1.0, 0.8, "Controlled roll")
	var dink_contact := Attack.resolve(0.0, 1.0, 0.8, "Short tip")
	_check(roll_contact.attack_family == Attack.ROLL and dink_contact.attack_family == Attack.DINK,
		"resolved attack vocabulary did not select roll/dink families")
	_check(float(roll_contact.striking_elbow_degrees) > float(power_contact.striking_elbow_degrees),
		"roll shot must soften the elbow at contact")
	_check(float(dink_contact.striking_elbow_degrees) > float(roll_contact.striking_elbow_degrees),
		"dink must retain the most compact striking elbow")

	var idle := Idle.resolve(1.75, 12, "watching")
	_check(absf(float(idle.rise_metres)) <= 0.0061, "idle breathing exceeds its vertical bound")
	_check(absf(float(idle.lateral_metres)) <= 0.0121, "idle sway exceeds its lateral bound")
	_check(Idle.blink_weight(1.0, 9, true) == 0.0, "blink must be suppressed at contact")
	var blink_seen := false
	for sample in range(0, 800):
		if Idle.blink_weight(float(sample) * 0.01, 9, false) > 0.95:
			blink_seen = true
			break
	_check(blink_seen, "deterministic blink schedule never closes the eyes")
	_check(Idle.blink_weight(0.37, 9, false) == Idle.blink_weight(0.37, 9, false),
		"blink schedule must repeat exactly for inspection")

	if failures == 0:
		print("Rally action animation contract: %d checks, 0 failures" % checks)
		quit(0)
		return
	push_error("Rally action animation contract: %d checks, %d failures" % [checks, failures])
	quit(1)
