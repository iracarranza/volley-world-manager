extends SceneTree

const T := preload("res://scripts/data/world_panel_topology.gd")
const M := preload("res://scripts/world/world_surface_mapper.gd")
const G := preload("res://scripts/data/world_geography.gd")
const POL := preload("res://scripts/data/world_political_geography.gd")

var checks := 0
var failures := 0

func _initialize()->void:
	_test_seam_continuity()
	_test_locked_physical_character()
	_test_locked_core_contacts()
	_test_political_footprints()
	_finish()


func _check(condition:bool, message:String)->void:
	checks += 1
	if condition:
		return
	failures += 1
	push_error("WORLD GEOGRAPHY: %s" % message)


func _near(a:float,b:float,eps:float=0.00002)->bool:
	return absf(a-b) <= eps


func _test_seam_continuity()->void:
	# Every physical field is world-space authority. Paired panel seams therefore
	# must produce the same elevation/climate/water values from either side.
	for seam in T.MACRO_SEAMS:
		for i in range(33):
			var t := -1.0 + 2.0 * float(i) / 32.0
			var a := M.macro_edge_to_world(String(seam.a_face), String(seam.a_edge), t)
			var b := M.macro_edge_to_world(String(seam.b_face), String(seam.b_edge), t)
			_check(a.distance_to(b) < 0.00002, "topology seam coordinate drift %s/%s at %.3f" % [seam.a_face,seam.b_face,t])
			var sa := G.sample_world(a)
			var sb := G.sample_world(b)
			_check(_near(float(sa.elevation),float(sb.elevation)), "elevation discontinuity %s/%s" % [seam.a_face,seam.b_face])
			_check(_near(float(sa.moisture),float(sb.moisture)), "moisture discontinuity %s/%s" % [seam.a_face,seam.b_face])
			_check(_near(float(sa.temperature),float(sb.temperature)), "temperature discontinuity %s/%s" % [seam.a_face,seam.b_face])
			_check(_near(float(sa.river_strength),float(sb.river_strength)), "river discontinuity %s/%s" % [seam.a_face,seam.b_face])

	for panel in T.PANEL_IDS:
		for uv in [Vector2(0.13,0.19),Vector2(0.50,0.50),Vector2(0.87,0.81)]:
			var via_panel := G.sample_panel(panel,uv)
			var via_world := G.sample_world(M.panel_uv_to_world(panel,uv))
			_check(_near(float(via_panel.elevation),float(via_world.elevation)), "%s panel/world elevation mismatch" % panel)
			_check(String(via_panel.terrain)==String(via_world.terrain), "%s panel/world terrain mismatch" % panel)


func _test_locked_physical_character()->void:
	var landavol := G.sample_panel("L2",Vector2(0.50,0.50))
	_check(bool(landavol.land), "Landavol basin center must be land")
	_check(float(landavol.moisture) > 0.40, "Landavol basin must remain moderated rather than arid")

	var speddigh := G.sample_panel("S1",Vector2(0.50,0.55))
	_check(bool(speddigh.land), "Spëddigh fjord core must include land")
	_check(float(speddigh.temperature) < float(landavol.temperature), "Spëddigh must be colder than Landavol")
	_check(float(speddigh.moisture) > float(landavol.moisture), "Spëddigh must be wetter/more maritime than Landavol")

	var bloc := G.sample_panel("B1",Vector2(0.50,0.54))
	_check(float(bloc.elevation) < 0.62, "Blôc core must remain low shelf/tidal country")
	_check(float(bloc.moisture) > 0.58, "Blôc system must remain maritime/wet")

	var xervu := G.sample_panel("X1",Vector2(0.50,0.50))
	_check(float(xervu.elevation) > float(landavol.elevation), "Xérvu must rise above Landavol")
	_check(float(xervu.moisture) < 0.42, "Xérvu must remain dry")

	var taktika := G.sample_panel("T1",Vector2(0.50,0.50))
	_check(float(taktika.elevation) > 0.48, "Taktikã must remain high country")
	_check(float(taktika.temperature) < float(xervu.temperature), "Taktikã must be colder than Xérvu")
	_check(float(taktika.moisture) < 0.42, "Taktikã must remain dry")

	for uv in [Vector2(0.18,0.18),Vector2(0.38,0.34),Vector2(0.58,0.54),Vector2(0.80,0.76)]:
		var pawa := G.sample_panel("P1",uv)
		_check(bool(pawa.land), "Pāwa open volcanic arc node must be land at %s" % uv)
		_check(String(pawa.terrain)=="volcanic", "Pāwa arc node must classify volcanic at %s" % uv)

	var loong := G.sample_panel("P2",Vector2(0.50,0.48))
	_check(float(loong.elevation)>0.35, "Lo-ong uplift must remain high")
	_check(float(loong.temperature)<float(landavol.temperature), "Lo-ong uplift must remain cool/thin-air country")

	var aace_coast := G.sample_panel("P3",Vector2(0.55,0.72))
	_check(bool(aace_coast.land), "A'ace footprint must sit on the outer dry coast, not open ocean")
	_check(float(aace_coast.moisture)<0.48, "outer P3 coast must remain dry")

	var open_pawa_sea := G.sample_panel("P1",Vector2(0.93,0.18))
	_check(not bool(open_pawa_sea.land), "Pāwa arc must stay open rather than closing into a land ring")


func _test_locked_core_contacts()->void:
	var contacts := [
		["Landavol-Spëddigh","L","u_min",-0.35,-0.02],
		["Landavol-Blôc","L","v_max",-0.18,-0.10],
		["Landavol-Xérvu","L","u_max",0.15,0.02],
		["Landavol-Pāwa","L","v_min",0.25,-0.08],
		["Blôc-Xérvu","B","v_max",0.34,-0.02],
		["Xérvu-Taktikã","X","v_min",0.20,0.20],
		["Spëddigh-Taktikã","S","v_min",-0.10,0.18],
	]
	for c in contacts:
		var s := G.sample_world(M.macro_edge_to_world(String(c[1]),String(c[2]),float(c[3])))
		_check(float(s.elevation)>float(c[4]), "%s physical contact collapsed into deep water" % String(c[0]))


func _test_political_footprints()->void:
	for region in POL.all_regions():
		var center := POL.region_center_world(region)
		_check(center.length()>0.9, "%s lacks a political label anchor" % region)
		_check(POL.region_at(center)==region, "%s center resolves as %s" % [region,POL.region_at(center)])
		_check(bool(G.sample_world(center).land), "%s political center must lie on physical land" % region)

	var z := POL.region_center_world("Zaitgaist")
	_check(POL.contains_region(z,"Landavol"), "Zaitgaist must remain an enclave inside the Landavol footprint")
	_check(POL.region_at(z)=="Zaitgaist", "enclave must resolve to Zaitgaist before surrounding Landavol")

	# Landavol is unequivocally landlocked: its political footprint may span L1-L3
	# but cannot touch any macro-face edge, even where the physical basin reaches a
	# neighbouring system.
	for edge in ["u_min","u_max","v_min","v_max"]:
		for i in range(49):
			var t := -1.0 + 2.0 * float(i) / 48.0
			var d := M.macro_edge_to_world("L",edge,t)
			_check(not POL.contains_region(d,"Landavol"), "Landavol political footprint touches %s at %.3f" % [edge,t])

	# Minor and exceptional polities must not silently become whole-panel regions.
	var minor_checks := [
		["Kutré Lyn","X2",Vector2(0.92,0.52)],
		["Tãul ys Feynt","T2",Vector2(0.15,0.50)],
		["Lo-ong Ralī","P2",Vector2(0.90,0.50)],
		["A'ace","P3",Vector2(0.18,0.18)],
		["Rhėn Tempaol","S2",Vector2(0.80,0.70)],
	]
	for c in minor_checks:
		var d := M.panel_uv_to_world(String(c[1]),Vector2(c[2]))
		_check(not POL.contains_region(d,String(c[0])), "%s expanded to consume its macro panel" % String(c[0]))

	# Pāwa is an open chain: a point between the last arc island and the panel edge
	# remains outside the polity even though it is in the same P1 panel.
	_check(not POL.contains_region(M.panel_uv_to_world("P1",Vector2(0.94,0.86)),"Pāwa Hitō"), "Pāwa political chain closed into a panel-sized territory")


func _finish()->void:
	if failures == 0:
		print("World geography contract: %d checks, 0 failures" % checks)
		quit(0)
		return
	push_error("World geography contract: %d checks, %d failures" % [checks,failures])
	quit(1)
