extends SceneTree

## Does a written contact list produce a coherent ball?
##
## Slice 1 of the choreography rig: one authored serve, one authored reception,
## through the production resolvers. The point is not that it looks right -- it
## is that the two legs meet, which is the §5 claim, and that varying *one*
## authored input moves the outcome in a way a seed search cannot isolate.
##
## The second half is the whole argument for the rig. Three serves are run that
## differ only in the vertical execution draw, everything else held identical.
## A census cannot do that: it can only report what the population happened to
## contain.

const MANAGER := preload("res://scripts/managers/game_manager.gd")
const DRIVER := preload("res://scripts/simulation/scripted_rally_driver.gd")


func _initialize() -> void:
	print("=== one authored serve and reception ===")
	_run({"bearing": 0.0, "vertical": 0.0, "power": 0.0}, true)
	print("\n=== the same serve, varying only the vertical draw ===")
	print("%-10s %10s %10s %10s %10s %12s" % [
		"vertical", "flight s", "contact m", "seam m", "pass rise", "pass err m",
	])
	for sigma in [-1.5, -0.5, 0.0, 0.5, 1.5]:
		_run({"bearing": 0.0, "vertical": sigma, "power": 0.0}, false)
	quit()


func _run(draws: Dictionary, verbose: bool) -> void:
	var manager = MANAGER.new()
	manager.seed_vertical_slice_data()
	var driver = DRIVER.new()
	var script := [
		{
			"actor": 105, "family": "serve",
			"aim": Vector2(0.45, 0.78), "draws": draws,
		},
		{
			"actor": 6, "family": "reception",
			"aim": Vector2(0.62, 0.58), "height": 2.40,
		},
	]
	var served: Dictionary = driver._script_serve(
		null, Dictionary(script[0]), manager.players, manager.opponent_team, false
	)
	if served.is_empty():
		print("  serve refused")
		return
	var received: Dictionary = driver._script_reception(
		null, Dictionary(script[1]), manager.players, manager.opponent_team, served
	)
	if received.is_empty():
		print("  reception refused")
		return
	var incoming: Dictionary = received.realised_incoming
	var seam := absf(
		float(incoming.get("end_height_meters", NAN))
		- float(received.contact_height_meters)
	)
	var pass_flight: Dictionary = received.free_flight
	if verbose:
		print("  serve   %s -> %s, outcome %s" % [
			served.origin, served.landing, served.outcome,
		])
		print("  sliced  ends %.3f m at t=%.3f s" % [
			float(incoming.get("end_height_meters", NAN)), received.contact_time,
		])
		print("  contact %s at %.3f m" % [
			received.contact_position, received.contact_height_meters,
		])
		print("  pass    rises %.3f m, %.2f m from the aim" % [
			float(pass_flight.get("apex_rise_meters", NAN)),
			received.target_error_meters,
		])
		print("  SEAM    %.4f m" % seam)
		return
	print("%-10.1f %10.3f %10.3f %10.4f %10.3f %12.2f" % [
		float(draws.vertical), received.contact_time,
		received.contact_height_meters, seam,
		float(pass_flight.get("apex_rise_meters", NAN)),
		received.target_error_meters,
	])
