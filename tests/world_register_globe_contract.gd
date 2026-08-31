extends SceneTree

const Globe := preload("res://scenes/components/world_register_globe.gd")
const RegisterView := preload("res://scenes/components/world_register_view.gd")
const Topology := preload("res://scripts/data/world_panel_topology.gd")
const Mapper := preload("res://scripts/world/world_surface_mapper.gd")
const Politics := preload("res://scripts/data/world_political_geography.gd")

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func _check(ok: bool, message: String) -> void:
	checks += 1
	if ok:
		return
	failures += 1
	push_error("WORLD REGISTER GLOBE: %s" % message)


func _run() -> void:
	var globe := Globe.new()
	globe.size = Vector2(720, 520)
	root.add_child(globe)
	await process_frame
	_check(globe is WorldRegisterGlobe, "component must instantiate as WorldRegisterGlobe")
	_check(Globe.canonical_panel_count() == Topology.EXPECTED_PANEL_COUNT, "globe must use canonical 18-panel count")

	var counts := Globe.panel_vertex_counts()
	_check(counts.size() == Topology.EXPECTED_PANEL_COUNT, "every canonical panel must have a geometry record")
	for panel_id in Topology.PANEL_IDS:
		_check(int(counts.get(panel_id, 0)) > 0, "%s contributes no sphere geometry" % panel_id)

	_check(
		Globe.unique_seam_count() == Topology.EXPECTED_EDGE_COUNT,
		"deduplicated seams must equal the canonical 48 edges (got %d)" % Globe.unique_seam_count()
	)
	for direction in Globe.seam_sample_directions():
		_check(absf(direction.length() - 1.0) < 0.00001, "seam sample is not a valid unit-sphere point")
		var mapped := Mapper.world_to_panel_uv(direction)
		_check(float(mapped.get("error", 1.0)) < 0.0001, "seam sample does not round-trip through the canonical mapper")

	for region_name in Politics.all_regions():
		var anchor := Politics.region_center_world(region_name)
		_check(
			Globe.world_direction_to_region(anchor) == region_name,
			"%s is not selectable at its canonical political anchor" % region_name
		)

	## L2 contains both the Landavol polity and the higher-priority Zaitgaist
	## enclave. Resolving them differently proves that the globe does not treat a
	## panel as a country.
	var landavol := Mapper.panel_uv_to_world("L2", Vector2(0.28, 0.49))
	var zaitgaist := Mapper.panel_uv_to_world("L2", Vector2(0.53, 0.52))
	_check(Globe.world_direction_to_region(landavol) == "Landavol", "Landavol anchor must resolve politically")
	_check(Globe.world_direction_to_region(zaitgaist) == "Zaitgaist", "same-panel enclave must resolve independently")
	var open_ocean := Mapper.panel_uv_to_world("P1", Vector2(0.93, 0.18))
	_check(Globe.world_direction_to_region(open_ocean).is_empty(), "canonical ocean must not select a region")

	var canonical_before := Globe.world_direction_to_region(Politics.region_center_world("Pāwa Hitō"))
	var rotation_before := globe.presentation_rotation()
	globe.set_presentation_rotation_degrees(Vector3(19, 127, 0))
	var canonical_after := Globe.world_direction_to_region(Politics.region_center_world("Pāwa Hitō"))
	_check(globe.presentation_rotation() != rotation_before, "rotation must change presentation")
	_check(canonical_before == canonical_after and canonical_after == "Pāwa Hitō", "rotation must not change canonical world data")

	var view := RegisterView.new()
	view.size = Vector2(1100, 620)
	root.add_child(view)
	await process_frame
	view.select_region("Kutré Lyn")
	_check(view.selected_region() == "Kutré Lyn", "selected region did not sync to globe state")
	_check(view.details_text().contains("Kutré Lyn"), "selected region did not sync to details UI")
	_check(view.details_text().contains("Development links"), "development links must remain distinct in region details")

	globe.queue_free()
	view.queue_free()
	await process_frame
	if failures == 0:
		print("World Register globe contract: %d checks, 0 failures" % checks)
		quit(0)
		return
	push_error("World Register globe contract: %d checks, %d failures" % [checks, failures])
	quit(1)
