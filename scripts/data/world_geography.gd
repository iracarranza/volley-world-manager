class_name WorldGeography
extends RefCounted

## Canonical physical-geography layer for the volleyball world.
##
## Geography is sampled from a world-space direction. It never asks which
## political region owns that point and never treats a panel boundary as a
## coastline. The panel mapper supplies coordinates; these fields supply the
## continuous physical surface painted across them.

const MAPPER := preload("res://scripts/world/world_surface_mapper.gd")

const SEA_LEVEL := 0.0

## Broad radial fields. Radii are angular radians on the unit sphere. Multiple
## lobes belonging to one named system overlap into a continuous belt/basin;
## nothing here says that the corresponding political region owns the whole
## system.
const LANDFORM_LOBES := [
	# Landavol drainage basin: broad, low and connected across L1-L3. These are
	# intentionally lower than the Xérvu/Taktikã uplifts; overlap creates broad
	# plains rather than an accidental central mountain mass.
	{"system":"landavol_basin","panel":"L1","uv":Vector2(0.72,0.48),"radius":0.58,"elev":0.42,"moisture":0.06,"temp":0.00},
	{"system":"landavol_basin","panel":"L2","uv":Vector2(0.50,0.50),"radius":0.72,"elev":0.50,"moisture":0.08,"temp":0.00},
	{"system":"landavol_basin","panel":"L3","uv":Vector2(0.28,0.48),"radius":0.58,"elev":0.44,"moisture":0.04,"temp":0.01},

	# Spëddigh: glaciated uplands opening into a maritime corridor and storm sea.
	{"system":"speddigh_fjords","panel":"S1","uv":Vector2(0.50,0.55),"radius":0.70,"elev":0.76,"moisture":0.28,"temp":-0.30},
	{"system":"speddigh_maritime","panel":"S2","uv":Vector2(0.42,0.48),"radius":0.34,"elev":0.24,"moisture":0.20,"temp":-0.08},
	{"system":"rhen_island","panel":"S2","uv":Vector2(0.17,0.30),"radius":0.09,"elev":0.66,"moisture":0.12,"temp":0.01},
	{"system":"speddigh_storm_sea","panel":"S3","uv":Vector2(0.48,0.44),"radius":0.18,"elev":0.30,"moisture":0.22,"temp":-0.06},
	# Ĭspayk is a tiny polity, but its three storm-track volcanic islands still
	# need literal land beneath the political footprint.
	{"system":"ispayk_volcanic_islands","panel":"S3","uv":Vector2(0.38,0.30),"radius":0.08,"elev":0.64,"moisture":0.12,"temp":-0.02},
	{"system":"ispayk_volcanic_islands","panel":"S3","uv":Vector2(0.53,0.43),"radius":0.08,"elev":0.66,"moisture":0.12,"temp":-0.02},
	{"system":"ispayk_volcanic_islands","panel":"S3","uv":Vector2(0.64,0.58),"radius":0.075,"elev":0.64,"moisture":0.12,"temp":-0.02},

	# Blôc/Bompaçao physical system: low shelf, tidal country, then delta.
	{"system":"bloc_shelf","panel":"B1","uv":Vector2(0.50,0.54),"radius":0.70,"elev":0.56,"moisture":0.30,"temp":0.00},
	{"system":"bompacao_delta","panel":"B2","uv":Vector2(0.50,0.44),"radius":0.60,"elev":0.48,"moisture":0.38,"temp":0.06},
	{"system":"bloc_outer_shelf","panel":"B3","uv":Vector2(0.46,0.45),"radius":0.44,"elev":0.24,"moisture":0.24,"temp":0.03},

	# Xérvu: dry uplift and escarpment with lower rift country toward X3.
	{"system":"xervu_plateau","panel":"X1","uv":Vector2(0.50,0.50),"radius":0.76,"elev":0.96,"moisture":-0.48,"temp":0.07},
	{"system":"xervu_karst","panel":"X2","uv":Vector2(0.46,0.50),"radius":0.60,"elev":0.70,"moisture":-0.26,"temp":0.03},
	{"system":"xervu_rift","panel":"X3","uv":Vector2(0.42,0.55),"radius":0.56,"elev":0.54,"moisture":-0.12,"temp":0.02},

	# Taktikã: the highest continuous plateau, colder and drier than Xérvu.
	{"system":"taktika_altiplano","panel":"T1","uv":Vector2(0.50,0.50),"radius":0.74,"elev":1.05,"moisture":-0.50,"temp":-0.28},
	{"system":"taktika_slate","panel":"T2","uv":Vector2(0.50,0.50),"radius":0.56,"elev":0.74,"moisture":-0.34,"temp":-0.18},
	{"system":"taktika_seam_basin","panel":"T3","uv":Vector2(0.54,0.48),"radius":0.64,"elev":0.82,"moisture":-0.30,"temp":-0.22},

	# Pāwa: deliberately an OPEN chain, not a ring. The high P2 uplift and outer
	# P3 dry coast are separate systems inside the same macro neighbourhood.
	{"system":"pawa_arc","panel":"P1","uv":Vector2(0.18,0.18),"radius":0.23,"elev":0.68,"moisture":0.18,"temp":0.05},
	{"system":"pawa_arc","panel":"P1","uv":Vector2(0.38,0.34),"radius":0.23,"elev":0.70,"moisture":0.18,"temp":0.04},
	{"system":"pawa_arc","panel":"P1","uv":Vector2(0.58,0.54),"radius":0.23,"elev":0.72,"moisture":0.17,"temp":0.03},
	{"system":"pawa_arc","panel":"P1","uv":Vector2(0.80,0.76),"radius":0.23,"elev":0.70,"moisture":0.16,"temp":0.02},
	{"system":"loong_uplift","panel":"P2","uv":Vector2(0.50,0.48),"radius":0.40,"elev":0.90,"moisture":-0.12,"temp":-0.24},
	{"system":"outer_dry_coast","panel":"P3","uv":Vector2(0.55,0.72),"radius":0.36,"elev":0.46,"moisture":-0.34,"temp":0.14},

	# Seven locked physical core contacts. These are terrain transitions, not
	# political-border declarations.
	{"system":"landavol_speddigh_upland","face":"L","edge":"u_min","t":-0.35,"radius":0.30,"elev":0.58,"moisture":0.12,"temp":-0.15},
	{"system":"landavol_bloc_lowland","face":"L","edge":"v_max","t":-0.18,"radius":0.32,"elev":0.30,"moisture":0.26,"temp":0.02},
	{"system":"landavol_xervu_escarpment","face":"L","edge":"u_max","t":0.15,"radius":0.28,"elev":0.52,"moisture":-0.12,"temp":0.02},
	{"system":"landavol_pawa_transition","face":"L","edge":"v_min","t":0.25,"radius":0.28,"elev":0.38,"moisture":0.12,"temp":0.05},
	{"system":"bloc_xervu_coastal_highland","face":"B","edge":"v_max","t":0.34,"radius":0.28,"elev":0.48,"moisture":0.02,"temp":0.00},
	{"system":"xervu_taktika_plateau","face":"X","edge":"v_min","t":0.20,"radius":0.36,"elev":0.72,"moisture":-0.28,"temp":-0.18},
	{"system":"speddigh_taktika_upland","face":"S","edge":"v_min","t":-0.10,"radius":0.36,"elev":0.70,"moisture":0.02,"temp":-0.26},
]

const RIVERS := [
	{"name":"landavol_main","width":0.040,"points":[
		{"panel":"L1","uv":Vector2(0.55,0.28)},
		{"panel":"L2","uv":Vector2(0.28,0.42)},
		{"panel":"L2","uv":Vector2(0.48,0.62)},
		{"panel":"L2","uv":Vector2(0.52,0.88)},
	]},
	{"name":"landavol_east_branch","width":0.030,"points":[
		{"panel":"L3","uv":Vector2(0.58,0.30)},
		{"panel":"L3","uv":Vector2(0.35,0.48)},
		{"panel":"L2","uv":Vector2(0.52,0.62)},
	]},
	{"name":"bompacao_delta","width":0.055,"points":[
		{"panel":"B2","uv":Vector2(0.48,0.24)},
		{"panel":"B2","uv":Vector2(0.50,0.48)},
		{"panel":"B2","uv":Vector2(0.42,0.70)},
	]},
]

static func sample_panel(panel_id:String, uv:Vector2)->Dictionary:
	return sample_world(MAPPER.panel_uv_to_world(panel_id, uv))


static func sample_world(direction:Vector3)->Dictionary:
	var d := direction.normalized()
	var elevation := -0.42
	var moisture := 0.58
	var axis := _rotation_axis()
	var temperature := 0.72 - 0.42 * absf(d.dot(axis))
	var weights:Dictionary = {}

	for feature in LANDFORM_LOBES:
		var w := _feature_weight(d, feature)
		if w <= 0.0:
			continue
		elevation += float(feature.get("elev", 0.0)) * w
		moisture += float(feature.get("moisture", 0.0)) * w
		temperature += float(feature.get("temp", 0.0)) * w
		var system := String(feature.get("system", ""))
		weights[system] = maxf(float(weights.get(system, 0.0)), w)

	elevation = clampf(elevation, -1.0, 1.20)
	temperature -= maxf(elevation, 0.0) * 0.17
	if elevation <= SEA_LEVEL:
		moisture = maxf(moisture, 0.78)
	moisture = clampf(moisture, 0.0, 1.0)
	temperature = clampf(temperature, 0.0, 1.0)
	var river := river_strength(d)
	var terrain := _terrain_class(elevation, moisture, temperature, river, weights)
	return {
		"elevation": elevation,
		"land": elevation > SEA_LEVEL,
		"moisture": moisture,
		"temperature": temperature,
		"river_strength": river,
		"terrain": terrain,
		"systems": weights,
	}


static func system_weight(direction:Vector3, system:String)->float:
	return float(sample_world(direction).systems.get(system, 0.0))


static func river_strength(direction:Vector3)->float:
	var d := direction.normalized()
	var strongest := 0.0
	for river in RIVERS:
		var points:Array = river.get("points", [])
		var width := float(river.get("width", 0.03))
		for i in range(points.size() - 1):
			var a := _anchor(points[i])
			var b := _anchor(points[i + 1])
			for step in range(9):
				var q := a.slerp(b, float(step) / 8.0).normalized()
				var angle := acos(clampf(d.dot(q), -1.0, 1.0))
				strongest = maxf(strongest, _smooth_weight(angle, width))
	return strongest


static func _terrain_class(elevation:float, moisture:float, temperature:float, river:float, weights:Dictionary)->String:
	if elevation <= -0.22:
		return "deep_ocean"
	if elevation <= SEA_LEVEL:
		return "shelf"
	if float(weights.get("pawa_arc", 0.0)) > 0.44 or float(weights.get("ispayk_volcanic_islands", 0.0)) > 0.44:
		return "volcanic"
	if temperature < 0.23 and moisture > 0.52:
		return "glacial"
	if temperature < 0.30 and elevation > 0.44:
		return "cold_highland"
	if moisture < 0.28 and elevation > 0.44:
		return "dry_plateau"
	if moisture < 0.31:
		return "arid"
	if river > 0.52 and elevation < 0.42:
		return "river_lowland"
	if elevation > 0.58:
		return "highland"
	if moisture > 0.72:
		return "wet_lowland"
	return "temperate"


static func _feature_weight(direction:Vector3, feature:Dictionary)->float:
	var anchor := _anchor(feature)
	var angle := acos(clampf(direction.dot(anchor), -1.0, 1.0))
	return _smooth_weight(angle, float(feature.get("radius", 0.2)))


static func _smooth_weight(angle:float, radius:float)->float:
	if radius <= 0.0:
		return 0.0
	var x := clampf(1.0 - angle / radius, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


static func _anchor(spec:Dictionary)->Vector3:
	if spec.has("panel"):
		return MAPPER.panel_uv_to_world(String(spec.panel), Vector2(spec.uv)).normalized()
	return MAPPER.macro_edge_to_world(String(spec.face), String(spec.edge), float(spec.t)).normalized()


static func _rotation_axis()->Vector3:
	var speddigh := MAPPER.panel_uv_to_world("S1", Vector2(0.50, 0.56))
	var taktika := MAPPER.panel_uv_to_world("T1", Vector2(0.50, 0.50))
	return (speddigh + taktika * 0.72).normalized()
