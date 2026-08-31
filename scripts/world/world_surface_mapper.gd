class_name WorldSurfaceMapper
extends RefCounted

const TOPOLOGY := preload("res://scripts/data/world_panel_topology.gd")
const FLAT_SIZE := Vector2(12.0,9.0)
const EPS := 0.0001

static func macro_uv_to_cube(face:String,u:float,v:float)->Vector3:
	match face:
		"L": return Vector3(u,v,1.0)
		"T": return Vector3(u,v,-1.0)
		"S": return Vector3(-1.0,u,v)
		"X": return Vector3(1.0,u,v)
		"B": return Vector3(v,1.0,u)
		"P": return Vector3(v,-1.0,u)
	return Vector3.ZERO

static func cube_to_sphere(c:Vector3)->Vector3:
	var x2:=c.x*c.x; var y2:=c.y*c.y; var z2:=c.z*c.z
	return Vector3(
		c.x*sqrt(maxf(0.0,1.0-y2*0.5-z2*0.5+y2*z2/3.0)),
		c.y*sqrt(maxf(0.0,1.0-z2*0.5-x2*0.5+z2*x2/3.0)),
		c.z*sqrt(maxf(0.0,1.0-x2*0.5-y2*0.5+x2*y2/3.0))
	).normalized()

static func macro_uv_to_world(face:String,u:float,v:float)->Vector3:
	return cube_to_sphere(macro_uv_to_cube(face,u,v))

static func panel_uv_to_world(panel_id:String,uv:Vector2)->Vector3:
	var b:=TOPOLOGY.panel_u_bounds(panel_id)
	return macro_uv_to_world(TOPOLOGY.face_for_panel(panel_id),lerpf(b.x,b.y,uv.x),lerpf(-1.0,1.0,uv.y))

static func macro_edge_to_world(face:String,edge:String,t:float)->Vector3:
	match edge:
		"u_min": return macro_uv_to_world(face,-1.0,t)
		"u_max": return macro_uv_to_world(face,1.0,t)
		"v_min": return macro_uv_to_world(face,t,-1.0)
		"v_max": return macro_uv_to_world(face,t,1.0)
	return Vector3.ZERO

static func world_to_panel_uv(direction:Vector3)->Dictionary:
	var target:=direction.normalized(); var face:=_dominant_face(target); var m:=_initial(face,target)
	for _i in range(12):
		var q:=macro_uv_to_world(face,m.x,m.y); var r:=q-target
		var u0:=maxf(-1.0,m.x-EPS); var u1:=minf(1.0,m.x+EPS); var v0:=maxf(-1.0,m.y-EPS); var v1:=minf(1.0,m.y+EPS)
		var du:=(macro_uv_to_world(face,u1,m.y)-macro_uv_to_world(face,u0,m.y))/maxf(u1-u0,0.0000001)
		var dv:=(macro_uv_to_world(face,m.x,v1)-macro_uv_to_world(face,m.x,v0))/maxf(v1-v0,0.0000001)
		var a:=du.dot(du); var b:=du.dot(dv); var c:=dv.dot(dv); var det:=a*c-b*b
		if absf(det)<0.0000000001: break
		var ru:=du.dot(r); var rv:=dv.dot(r)
		var delta:=Vector2((c*ru-b*rv)/det,(a*rv-b*ru)/det)
		m=Vector2(clampf(m.x-delta.x,-1.0,1.0),clampf(m.y-delta.y,-1.0,1.0))
		if delta.length_squared()<0.000000000001: break
	var panel:=TOPOLOGY.panel_for_macro_u(face,m.x); var bounds:=TOPOLOGY.panel_u_bounds(panel)
	var uv:=Vector2(inverse_lerp(bounds.x,bounds.y,m.x),inverse_lerp(-1.0,1.0,m.y))
	return {"face":face,"panel_id":panel,"uv":uv,"error":panel_uv_to_world(panel,uv).distance_to(target)}

static func _dominant_face(d:Vector3)->String:
	var ax:=absf(d.x); var ay:=absf(d.y); var az:=absf(d.z)
	if ax>=ay and ax>=az: return "X" if d.x>=0.0 else "S"
	if ay>=ax and ay>=az: return "B" if d.y>=0.0 else "P"
	return "L" if d.z>=0.0 else "T"

static func _initial(face:String,d:Vector3)->Vector2:
	match face:
		"L": return Vector2(d.x/d.z,d.y/d.z).clamp(Vector2(-1,-1),Vector2(1,1))
		"T": return Vector2(d.x/-d.z,d.y/-d.z).clamp(Vector2(-1,-1),Vector2(1,1))
		"X": return Vector2(d.y/d.x,d.z/d.x).clamp(Vector2(-1,-1),Vector2(1,1))
		"S": return Vector2(d.y/-d.x,d.z/-d.x).clamp(Vector2(-1,-1),Vector2(1,1))
		"B": return Vector2(d.z/d.y,d.x/d.y).clamp(Vector2(-1,-1),Vector2(1,1))
		"P": return Vector2(d.z/-d.y,d.x/-d.y).clamp(Vector2(-1,-1),Vector2(1,1))
	return Vector2.ZERO

static func macro_uv_to_flat(face:String,u:float,v:float)->Vector2:
	var panel:=TOPOLOGY.panel_for_macro_u(face,u); var b:=TOPOLOGY.panel_u_bounds(panel)
	return panel_uv_to_flat(panel,Vector2(inverse_lerp(b.x,b.y,u),inverse_lerp(-1.0,1.0,v)))

static func macro_edge_to_flat(face:String,edge:String,t:float)->Vector2:
	match edge:
		"u_min": return macro_uv_to_flat(face,-1.0,t)
		"u_max": return macro_uv_to_flat(face,1.0,t)
		"v_min": return macro_uv_to_flat(face,t,-1.0)
		"v_max": return macro_uv_to_flat(face,t,1.0)
	return Vector2.ZERO

static func panel_uv_to_flat(panel_id:String,uv:Vector2)->Vector2:
	var f:=TOPOLOGY.face_for_panel(panel_id); var i:=TOPOLOGY.panel_index(panel_id)
	match f:
		"L": return Vector2(3.0+float(i-1)+uv.x,3.0+3.0*uv.y)
		"T": return Vector2(13.0-float(i)-uv.x,3.0+3.0*uv.y)
		"S": return Vector2(3.0*uv.y,3.0+float(i-1)+uv.x)
		"X": return Vector2(9.0-3.0*uv.y,3.0+float(i-1)+uv.x)
		"B": return Vector2(3.0+3.0*uv.y,10.0-float(i)-uv.x)
		"P": return Vector2(3.0+3.0*uv.y,float(i-1)+uv.x)
	return Vector2.ZERO
