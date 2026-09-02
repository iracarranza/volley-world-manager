class_name RallyCommentaryLines
extends RefCounted

## Evidence-constrained presentation templates. These are deliberately short:
## the corpus supports contact/result language and selective post-point
## analysis, not a sentence for every item in the simulator trace.

const PBP_LINES := {
	"serve_in": "{actor} serves.",
	"serve_net": "{actor}'s serve catches the net.",
	"serve_long": "{actor}'s serve is long.",
	"serve_wide": "{actor}'s serve is wide.",
	"serve_error": "Service error from {actor}.",
	"ace": "Ace for {actor}.",
	"pass_good": "Good pass from {actor}.",
	"pass_trouble": "Trouble on the pass for {actor}.",
	"pass_scramble": "{actor} keeps the pass alive.",
	"pass_seam": "Confusion in reception.",
	"set": "{actor} sets {target}.",
	"perfect_set": "Excellent set from {actor}.",
	"save_set": "{actor} rescues the second contact.",
	"emergency_set": "{actor} takes the second contact.",
	"attack": "{actor} attacks.",
	"kill": "{actor} puts it away.",
	"kill_line": "{actor} finishes down the line.",
	"kill_cross": "{actor} scores cross-court.",
	"kill_seam": "{actor} finds the seam.",
	"kill_tip": "{actor} tips it over.",
	"kill_roll": "{actor} scores with the roll shot.",
	"kill_tool": "{actor} uses the block.",
	"off_block": "{actor}'s attack goes off the block.",
	"attack_net": "{actor} hits into the net.",
	"attack_long": "{actor}'s attack is long.",
	"attack_wide": "{actor}'s attack is wide.",
	"attack_antenna": "The attack catches the antenna.",
	"attack_error": "Attack error from {actor}.",
	"emergency_tip": "{actor} has to tip.",
	"block_stuff": "{actor} shuts it down.",
	"block_touch": "Touch at the net from {actor}.",
	"dig": "Picked up by {actor}.",
	"diving_save": "What a dig from {actor}.",
	"defense_beaten": "That gets past {actor}.",
	"easy_miss": "{actor} cannot control it.",
	"coverage": "{actor} covers the attack.",
}

const ANALYST_LINES := {
	"setter_save": "{actor} rescued an off-target first contact.",
	"timing_mismatch": "The hitter and setter were out of sync.",
	"predictable_set": "The block had time to read that set.",
	"called_play": "The called pattern produced the scoring chance.",
	"emergency_tip": "Out of system, the hitter had to tip.",
	"funnel": "The block took away one lane and shaped the ball toward the back court.",
	"block_touch": "That block touch slowed the attack for the back-court defense.",
	"late_block": "The pace left the second blocker no time to close.",
	"easy_miss": "That ball should have been handled.",
}


static func fill(template: String, values: Dictionary) -> String:
	var result := template
	for key in values:
		result = result.replace("{%s}" % str(key), str(values[key]))
	return result


static func pbp(key: String, values: Dictionary) -> String:
	return fill(str(PBP_LINES.get(key, "")), values)


static func analyst(key: String, values: Dictionary) -> String:
	return fill(str(ANALYST_LINES.get(key, "")), values)
