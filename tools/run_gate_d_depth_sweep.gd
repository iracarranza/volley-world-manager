extends SceneTree

## Gate D across the depths a real offence produces.
##
## The harness pinned every one of its four thousand samples at 0.36 m off the
## tape and had no caller -- no tool, no test -- which is how it and the live game
## drifted apart without anything noticing. 0.36 m is the tight front-row ideal
## and the *hardest* case to block: a ball struck close to the net covers less
## ground before it and crosses higher. Constants fit there overshoot everywhere
## else, and live contact depth now spans 0.87 m at p10 to 3.98 m at p90.
##
## So the question this answers is not "what is the mix" but "how does the mix
## move with depth", because that gradient is what the block constants have to
## describe. A row that hits target at one depth and misses at the next is a
## constant standing in for a function.
##
## Targets, from the design: kill 45-50%, attack error 10-15%, block involvement
## 35-45%, stuff 12%.
##
## Run:
##   godot --headless --path . --script res://tools/run_gate_d_depth_sweep.gd

const CalibrationScript := preload(
	"res://scripts/simulation/attack_geometry_calibration.gd"
)

const SAMPLES: int = 4000


func _initialize() -> void:
	print("Gate D -- %d samples per depth" % SAMPLES)
	print("")
	print("%8s %8s %8s %8s %8s %8s %8s %9s" % [
		"depth", "in", "error", "stuff", "touch", "tool", "involved", "clearance"
	])
	print("%8s %8s %8s %8s %8s %8s %8s %9s" % [
		"m", "%", "%", "%", "%", "%", "%", "m"
	])
	for row in CalibrationScript.depth_sweep(SAMPLES):
		var shares: Dictionary = row.shares
		var stuff := _share(shares, "stuff")
		var touch := _share(shares, "touch")
		var tool := _share(shares, "tool")
		var crush := _share(shares, "block_crush")
		var high_hands := _share(shares, "high_hands")
		var error := _share(shares, "out_long") + _share(shares, "out_wide") \
			+ _share(shares, "out_antenna") + _share(shares, "net")
		print("%8.2f %8.1f %8.1f %8.1f %8.1f %8.1f %8.1f %9.2f" % [
			float(row.contact_depth_meters), _share(shares, "in"), error,
			stuff, touch, tool,
			stuff + touch + tool + crush + high_hands,
			float(row.median_net_clearance_m),
		])
	print("")
	print("Targets: in 45-50, error 10-15, stuff 12, involved 35-45.")
	print("")
	print("Read down the stuff column. If it climbs with depth the block is being")
	print("handed lower balls the further off the net the set is, which is the")
	print("geometry doing its job -- what matters is whether the *range* brackets")
	print("the target rather than whether any one row sits on it.")
	quit()


func _share(shares: Dictionary, key: String) -> float:
	return float(shares.get(key, 0.0))
