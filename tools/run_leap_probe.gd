extends Node

## What a blocker's leap actually is, across the population.
##
## The drawn block height has to be scaled by something, and picking a band
## without measuring the distribution it acts on is the failure this repository
## keeps a document about.

const WorldPopulation := preload("res://scripts/systems/world_population.gd")


func _ready() -> void:
	await get_tree().process_frame
	var leaps: Array[float] = []
	for player in WorldPopulation.generate(4242, 1500):
		leaps.append(maxf(
			(player.jumping_reach_cm() - player.standing_reach_cm()) / 100.0, 0.0
		))
	leaps.sort()
	var n := leaps.size()
	var total := 0.0
	for value in leaps:
		total += value
	print("leap metres, n=%d: min %.3f  p05 %.3f  p25 %.3f  p50 %.3f  p75 %.3f  p95 %.3f  max %.3f  mean %.3f" % [
		n, leaps[0], leaps[int(n * 0.05)], leaps[int(n * 0.25)], leaps[n / 2],
		leaps[int(n * 0.75)], leaps[int(n * 0.95)], leaps[n - 1], total / float(n),
	])
	get_tree().quit()
