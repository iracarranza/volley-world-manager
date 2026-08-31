extends SceneTree
const T:=preload("res://scripts/data/world_panel_topology.gd")
const M:=preload("res://scripts/world/world_surface_mapper.gd")
var checks:=0
var failures:=0
func _initialize()->void:
	_registry(); _graph(); _opposites(); _euler(); _macro_seams(); _internal_seams(); _flat_joins(); _round_trip()
	print("WORLD TOPOLOGY CONTRACT: %d checks, %d failures" % [checks,failures])
	quit(1 if failures>0 else 0)
func _check(ok:bool,msg:String)->void:
	checks+=1
	if not ok:
		failures+=1; push_error("WORLD TOPOLOGY: %s" % msg)
func _registry()->void:
	_check(T.FACE_IDS.size()==6,"expected six triplets")
	_check(T.PANEL_IDS.size()==18,"expected eighteen panels")
	var seen:={}
	for p in T.PANEL_IDS:
		_check(not seen.has(p),"duplicate panel %s"%p); seen[p]=true
	for f in T.FACE_IDS:
		_check(T.TRIPLETS.has(f),"missing triplet %s"%f)
		_check(T.TRIPLETS[f].size()==3,"triplet %s must have 3 panels"%f)
func _graph()->void:
	var edges:={}
	for p in T.PANEL_IDS:
		_check(T.PANEL_NEIGHBORS.has(p),"missing adjacency for %s"%p)
		var ns:Array=T.PANEL_NEIGHBORS[p]
		_check(ns.size()==(4 if T.panel_index(p)==2 else 6),"degree drift on %s"%p)
		for n in ns:
			_check(T.PANEL_IDS.has(n),"unknown neighbor %s"%n)
			_check(T.PANEL_NEIGHBORS[n].has(p),"asymmetric adjacency %s/%s"%[p,n])
			edges[T.undirected_edge_key(p,n)]=true
	_check(edges.size()==48,"expected 48 seam segments, got %d"%edges.size())
func _opposites()->void:
	for pair in [["L","T"],["B","P"],["S","X"]]:
		var a:String=pair[0]; var b:String=pair[1]
		_check(T.OPPOSITE_FACE[a]==b and T.OPPOSITE_FACE[b]==a,"opposite pair drift %s/%s"%[a,b])
		for p in T.TRIPLETS[a]:
			for n in T.PANEL_NEIGHBORS[p]:
				_check(T.face_for_panel(n)!=b,"opposites share seam %s/%s"%[p,n])
func _euler()->void:
	_check(T.EXPECTED_VERTEX_COUNT-T.EXPECTED_EDGE_COUNT+T.EXPECTED_PANEL_COUNT==2,"Euler characteristic must be 2")
func _macro_seams()->void:
	_check(T.MACRO_SEAMS.size()==12,"expected 12 macro seams")
	for s in T.MACRO_SEAMS:
		for i in range(33):
			var q:=-1.0+2.0*float(i)/32.0
			_check(M.macro_edge_to_world(s.a_face,s.a_edge,q).distance_to(M.macro_edge_to_world(s.b_face,s.b_edge,q))<0.00001,"open macro seam %s/%s"%[s.a_face,s.b_face])
func _internal_seams()->void:
	for f in T.FACE_IDS:
		for i in range(17):
			var y:=float(i)/16.0
			_check(M.panel_uv_to_world(f+"1",Vector2(1,y)).distance_to(M.panel_uv_to_world(f+"2",Vector2(0,y)))<0.00001,"open internal seam %s1/%s2"%[f,f])
			_check(M.panel_uv_to_world(f+"2",Vector2(1,y)).distance_to(M.panel_uv_to_world(f+"3",Vector2(0,y)))<0.00001,"open internal seam %s2/%s3"%[f,f])
func _flat_joins()->void:
	_check(T.FLAT_JOINED_MACRO_SEAMS.size()==5,"flat net needs five uncut macro joins")
	for s in T.FLAT_JOINED_MACRO_SEAMS:
		for i in range(33):
			var q:=-0.999+1.998*float(i)/32.0
			_check(M.macro_edge_to_flat(s.a_face,s.a_edge,q).distance_to(M.macro_edge_to_flat(s.b_face,s.b_edge,q))<0.00001,"flat join separates %s/%s"%[s.a_face,s.b_face])
func _round_trip()->void:
	for p in T.PANEL_IDS:
		for u in [0.17,0.5,0.83]:
			for v in [0.13,0.5,0.87]:
				var uv:=Vector2(u,v); var inv:=M.world_to_panel_uv(M.panel_uv_to_world(p,uv))
				_check(inv.panel_id==p,"round trip changed %s to %s"%[p,inv.panel_id])
				_check((inv.uv as Vector2).distance_to(uv)<0.0002,"UV round trip drift %s"%p)
				_check(float(inv.error)<0.00001,"inverse projection error %s"%p)
