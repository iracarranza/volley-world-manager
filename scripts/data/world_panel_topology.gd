class_name WorldPanelTopology
extends RefCounted

## Canonical construction authority for the 18-panel volleyball world.
##
## Panels are macro-geographic surface units, never political territories.
## Physical geography and political footprints must depend on this topology;
## this file must not depend on either of those layers.

const FACE_IDS := ["L", "T", "S", "X", "B", "P"]
const PANEL_IDS := [
	"L1", "L2", "L3",
	"T1", "T2", "T3",
	"S1", "S2", "S3",
	"X1", "X2", "X3",
	"B1", "B2", "B3",
	"P1", "P2", "P3",
]

const TRIPLETS := {
	"L": ["L1", "L2", "L3"],
	"T": ["T1", "T2", "T3"],
	"S": ["S1", "S2", "S3"],
	"X": ["X1", "X2", "X3"],
	"B": ["B1", "B2", "B3"],
	"P": ["P1", "P2", "P3"],
}

const OPPOSITE_FACE := {
	"L": "T", "T": "L", "B": "P", "P": "B", "S": "X", "X": "S",
}

const PANEL_NEIGHBORS := {
	"B1": ["B2", "S3", "X3", "T1", "T2", "T3"],
	"B2": ["B1", "B3", "S3", "X3"],
	"B3": ["B2", "S3", "X3", "L1", "L2", "L3"],
	"L1": ["L2", "B3", "P3", "S1", "S2", "S3"],
	"L2": ["L1", "L3", "B3", "P3"],
	"L3": ["L2", "B3", "P3", "X1", "X2", "X3"],
	"P1": ["P2", "S1", "X1", "T1", "T2", "T3"],
	"P2": ["P1", "P3", "S1", "X1"],
	"P3": ["P2", "S1", "X1", "L1", "L2", "L3"],
	"S1": ["S2", "L1", "T1", "P1", "P2", "P3"],
	"S2": ["S1", "S3", "L1", "T1"],
	"S3": ["S2", "L1", "T1", "B1", "B2", "B3"],
	"T1": ["T2", "B1", "P1", "S1", "S2", "S3"],
	"T2": ["T1", "T3", "B1", "P1"],
	"T3": ["T2", "B1", "P1", "X1", "X2", "X3"],
	"X1": ["X2", "L3", "T3", "P1", "P2", "P3"],
	"X2": ["X1", "X3", "L3", "T3"],
	"X3": ["X2", "L3", "T3", "B1", "B2", "B3"],
}

const MACRO_SEAMS := [
	{"a_face":"L","a_edge":"v_max","b_face":"B","b_edge":"u_max"},
	{"a_face":"L","a_edge":"v_min","b_face":"P","b_edge":"u_max"},
	{"a_face":"L","a_edge":"u_min","b_face":"S","b_edge":"v_max"},
	{"a_face":"L","a_edge":"u_max","b_face":"X","b_edge":"v_max"},
	{"a_face":"T","a_edge":"v_max","b_face":"B","b_edge":"u_min"},
	{"a_face":"T","a_edge":"v_min","b_face":"P","b_edge":"u_min"},
	{"a_face":"T","a_edge":"u_min","b_face":"S","b_edge":"v_min"},
	{"a_face":"T","a_edge":"u_max","b_face":"X","b_edge":"v_min"},
	{"a_face":"B","a_edge":"v_min","b_face":"S","b_edge":"u_max"},
	{"a_face":"B","a_edge":"v_max","b_face":"X","b_edge":"u_max"},
	{"a_face":"P","a_edge":"v_min","b_face":"S","b_edge":"u_min"},
	{"a_face":"P","a_edge":"v_max","b_face":"X","b_edge":"u_min"},
]

const FLAT_JOINED_MACRO_SEAMS := [
	{"a_face":"L","a_edge":"v_max","b_face":"B","b_edge":"u_max"},
	{"a_face":"L","a_edge":"v_min","b_face":"P","b_edge":"u_max"},
	{"a_face":"L","a_edge":"u_min","b_face":"S","b_edge":"v_max"},
	{"a_face":"L","a_edge":"u_max","b_face":"X","b_edge":"v_max"},
	{"a_face":"X","a_edge":"v_min","b_face":"T","b_edge":"u_max"},
]

const EXPECTED_FACE_COUNT := 6
const EXPECTED_PANEL_COUNT := 18
const EXPECTED_EDGE_COUNT := 48
const EXPECTED_VERTEX_COUNT := 32
const EXPECTED_EULER_CHARACTERISTIC := 2

static func face_for_panel(panel_id:String)->String:
	return panel_id.substr(0,1)

static func panel_index(panel_id:String)->int:
	return int(panel_id.substr(1,1))

static func panel_u_bounds(panel_id:String)->Vector2:
	match panel_index(panel_id):
		1: return Vector2(-1.0,-1.0/3.0)
		2: return Vector2(-1.0/3.0,1.0/3.0)
		3: return Vector2(1.0/3.0,1.0)
	return Vector2.ZERO

static func panel_for_macro_u(face:String,u:float)->String:
	var index:=1
	if u > -1.0/3.0: index=2
	if u > 1.0/3.0: index=3
	return "%s%d" % [face,index]

static func undirected_edge_key(a:String,b:String)->String:
	return "%s|%s" % [a,b] if a < b else "%s|%s" % [b,a]
