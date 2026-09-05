class_name WorldPoliticalGeography
extends RefCounted

## Political footprints laid over the physical world. A footprint is a set of
## small world-space lobes, not a panel assignment. The minor regions are
## intentionally small, Zaitgaist is an enclave, and Pāwa Hitō is an open island
## chain. This layer does not alter elevation, climate or topology.

const MAPPER := preload("res://scripts/world/world_surface_mapper.gd")
const FOOTPRINT_THRESHOLD := 0.34

const REGION_PRIORITY := [
	"Zaitgaist", "Tãul ys Feynt", "Lo-ong Ralī", "Bompaçao", "Rhėn Tempaol", "Kutré Lyn",
	"Ĭspayk", "A'ace",
	"Landavol", "Spëddigh", "Blôc du Larg", "Xérvu", "Taktikã", "Pāwa Hitō",
]

const REGION_LOBES := {
	"Landavol": [
		{"panel":"L1","uv":Vector2(0.82,0.48),"radius":0.27},
		{"panel":"L2","uv":Vector2(0.28,0.49),"radius":0.31},
		{"panel":"L2","uv":Vector2(0.70,0.50),"radius":0.31},
		{"panel":"L3","uv":Vector2(0.18,0.48),"radius":0.27},
	],
	"Zaitgaist": [
		{"panel":"L2","uv":Vector2(0.53,0.52),"radius":0.055},
	],
	"Spëddigh": [
		{"panel":"S1","uv":Vector2(0.50,0.57),"radius":0.34},
		{"panel":"S1","uv":Vector2(0.52,0.34),"radius":0.23},
	],
	"Rhėn Tempaol": [
		{"panel":"S2","uv":Vector2(0.17,0.30),"radius":0.070},
	],
	"Ĭspayk": [
		{"panel":"S3","uv":Vector2(0.38,0.30),"radius":0.055},
		{"panel":"S3","uv":Vector2(0.53,0.43),"radius":0.048},
		{"panel":"S3","uv":Vector2(0.64,0.58),"radius":0.042},
	],
	"Blôc du Larg": [
		{"panel":"B1","uv":Vector2(0.43,0.56),"radius":0.28},
		{"panel":"B1","uv":Vector2(0.65,0.42),"radius":0.21},
	],
	"Bompaçao": [
		{"panel":"B2","uv":Vector2(0.50,0.44),"radius":0.20},
	],
	"Xérvu": [
		{"panel":"X1","uv":Vector2(0.50,0.50),"radius":0.35},
		{"panel":"X1","uv":Vector2(0.72,0.52),"radius":0.19},
	],
	"Kutré Lyn": [
		{"panel":"X2","uv":Vector2(0.46,0.52),"radius":0.12},
	],
	"Taktikã": [
		{"panel":"T1","uv":Vector2(0.50,0.50),"radius":0.35},
	],
	"Tãul ys Feynt": [
		{"panel":"T2","uv":Vector2(0.48,0.34),"radius":0.060},
		{"panel":"T2","uv":Vector2(0.50,0.50),"radius":0.070},
		{"panel":"T2","uv":Vector2(0.52,0.66),"radius":0.060},
	],
	"Pāwa Hitō": [
		{"panel":"P1","uv":Vector2(0.18,0.18),"radius":0.075},
		{"panel":"P1","uv":Vector2(0.33,0.29),"radius":0.078},
		{"panel":"P1","uv":Vector2(0.49,0.45),"radius":0.078},
		{"panel":"P1","uv":Vector2(0.65,0.61),"radius":0.078},
		{"panel":"P1","uv":Vector2(0.81,0.77),"radius":0.075},
	],
	"Lo-ong Ralī": [
		{"panel":"P2","uv":Vector2(0.50,0.49),"radius":0.12},
	],
	"A'ace": [
		{"panel":"P3","uv":Vector2(0.55,0.72),"radius":0.080},
	],
}

const LABEL_ANCHORS := {
	"Landavol":{"panel":"L2","uv":Vector2(0.34,0.50)},
	"Zaitgaist":{"panel":"L2","uv":Vector2(0.53,0.52)},
	"Spëddigh":{"panel":"S1","uv":Vector2(0.50,0.55)},
	"Rhėn Tempaol":{"panel":"S2","uv":Vector2(0.17,0.30)},
	"Ĭspayk":{"panel":"S3","uv":Vector2(0.52,0.43)},
	"Blôc du Larg":{"panel":"B1","uv":Vector2(0.49,0.53)},
	"Bompaçao":{"panel":"B2","uv":Vector2(0.50,0.44)},
	"Xérvu":{"panel":"X1","uv":Vector2(0.50,0.50)},
	"Kutré Lyn":{"panel":"X2","uv":Vector2(0.46,0.52)},
	"Taktikã":{"panel":"T1","uv":Vector2(0.50,0.50)},
	"Tãul ys Feynt":{"panel":"T2","uv":Vector2(0.50,0.50)},
	"Pāwa Hitō":{"panel":"P1","uv":Vector2(0.49,0.45)},
	"Lo-ong Ralī":{"panel":"P2","uv":Vector2(0.50,0.49)},
	"A'ace":{"panel":"P3","uv":Vector2(0.55,0.72)},
}

static func all_regions()->Array:
	return REGION_PRIORITY.duplicate()


static func region_at(direction:Vector3)->String:
	for region in REGION_PRIORITY:
		if contains_region(direction, region):
			return region
	return ""


static func contains_region(direction:Vector3, region:String)->bool:
	return score_region(direction, region) >= FOOTPRINT_THRESHOLD


static func score_region(direction:Vector3, region:String)->float:
	var d := direction.normalized()
	var strongest := 0.0
	for lobe in REGION_LOBES.get(region, []):
		var anchor := MAPPER.panel_uv_to_world(String(lobe.panel), Vector2(lobe.uv)).normalized()
		var angle := acos(clampf(d.dot(anchor), -1.0, 1.0))
		strongest = maxf(strongest, _smooth_weight(angle, float(lobe.radius)))
	return strongest


static func label_anchor(region:String)->Dictionary:
	return Dictionary(LABEL_ANCHORS.get(region, {})).duplicate()


static func region_center_world(region:String)->Vector3:
	var a := label_anchor(region)
	if a.is_empty():
		return Vector3.ZERO
	return MAPPER.panel_uv_to_world(String(a.panel), Vector2(a.uv)).normalized()


static func _smooth_weight(angle:float, radius:float)->float:
	if radius <= 0.0:
		return 0.0
	var x := clampf(1.0 - angle / radius, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)
