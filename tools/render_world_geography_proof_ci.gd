extends "res://tools/render_world_geography_proof.gd"

## The six macro faces do not all share the same outward triangle winding in
## panel-local UV space. The topology is still closed; the proof material must
## therefore be double-sided or a valid face disappears when viewed from the
## opposite hemisphere. Keep this as an explicit render contract rather than
## mistaking back-face culling for missing geography.
func _surface_mesh(show_politics:bool)->ImmediateMesh:
	var im:=ImmediateMesh.new()
	var mat:=StandardMaterial3D.new()
	mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo=true
	mat.cull_mode=BaseMaterial3D.CULL_DISABLED
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES,mat)
	for panel in T.PANEL_IDS:
		for y in range(GV):
			for x in range(GU):
				var u0:=float(x)/float(GU)
				var u1:=float(x+1)/float(GU)
				var v0:=float(y)/float(GV)
				var v1:=float(y+1)/float(GV)
				_vertex(im,panel,Vector2(u0,v0),show_politics)
				_vertex(im,panel,Vector2(u1,v0),show_politics)
				_vertex(im,panel,Vector2(u1,v1),show_politics)
				_vertex(im,panel,Vector2(u0,v0),show_politics)
				_vertex(im,panel,Vector2(u1,v1),show_politics)
				_vertex(im,panel,Vector2(u0,v1),show_politics)
	im.surface_end()
	return im
