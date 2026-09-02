extends SceneTree
const T:=preload("res://scripts/data/world_panel_topology.gd")
const M:=preload("res://scripts/world/world_surface_mapper.gd")
const P:=preload("res://scripts/data/ui_palette.gd")
const OUT:="res://artifacts/world-surface"
const SIZE:=Vector2i(1024,1024)
const R:=2.5
const LR:=R*1.004
const VIEWS:={
	"topology_globe_landavol.png":Vector3(-5.4,3.3,7.2),
	"topology_globe_opposite.png":Vector3(5.4,-3.3,-7.2),
	"topology_globe_pole.png":Vector3(0.15,8.8,0.2),
}
func _initialize()->void: call_deferred("_run")
func _run()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	await _globes(); await _flat(); print("Rendered world topology proof to %s"%OUT); quit()
func _globes()->void:
	var vp:=SubViewport.new(); vp.size=SIZE; vp.transparent_bg=false; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; vp.own_world_3d=true; root.add_child(vp)
	var world:=World3D.new(); vp.world_3d=world
	var env:=Environment.new(); env.background_mode=Environment.BG_COLOR; env.background_color=P.color(&"canvas"); env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color.WHITE; env.ambient_light_energy=1.0; world.environment=env
	var sm:=SphereMesh.new(); sm.radius=R; sm.height=R*2.0; sm.radial_segments=96; sm.rings=48
	var surfmat:=StandardMaterial3D.new(); surfmat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; surfmat.albedo_color=P.color(&"ink"); sm.material=surfmat
	var sphere:=MeshInstance3D.new(); sphere.mesh=sm; vp.add_child(sphere)
	var im:=ImmediateMesh.new(); var lm:=StandardMaterial3D.new(); lm.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; lm.albedo_color=P.color(&"canvas"); im.surface_begin(Mesh.PRIMITIVE_LINES,lm)
	for s in T.MACRO_SEAMS: _edge_curve(im,s.a_face,s.a_edge)
	for f in T.FACE_IDS:
		_internal_curve(im,f,-1.0/3.0); _internal_curve(im,f,1.0/3.0)
	im.surface_end(); var lines:=MeshInstance3D.new(); lines.mesh=im; vp.add_child(lines)
	for panel in T.PANEL_IDS:
		var l:=Label3D.new(); l.text=panel; l.font_size=42; l.outline_size=8; l.modulate=P.color(&"accent"); l.outline_modulate=P.color(&"canvas"); l.billboard=BaseMaterial3D.BILLBOARD_ENABLED; l.position=M.panel_uv_to_world(panel,Vector2(0.5,0.5))*(R*1.025); vp.add_child(l)
	var cam:=Camera3D.new(); cam.fov=32.0; vp.add_child(cam); cam.current=true
	for name in VIEWS:
		cam.position=VIEWS[name]; var up:=Vector3.UP
		if absf(cam.position.normalized().dot(Vector3.UP))>0.96: up=Vector3.FORWARD
		cam.look_at(Vector3.ZERO,up); await _save(vp,name)
	vp.queue_free(); await process_frame
func _edge_curve(im:ImmediateMesh,face:String,edge:String)->void:
	for i in range(64):
		var a:=-1.0+2.0*float(i)/64.0; var b:=-1.0+2.0*float(i+1)/64.0
		im.surface_add_vertex(M.macro_edge_to_world(face,edge,a)*LR); im.surface_add_vertex(M.macro_edge_to_world(face,edge,b)*LR)
func _internal_curve(im:ImmediateMesh,face:String,u:float)->void:
	for i in range(64):
		var a:=-1.0+2.0*float(i)/64.0; var b:=-1.0+2.0*float(i+1)/64.0
		im.surface_add_vertex(M.macro_uv_to_world(face,u,a)*LR); im.surface_add_vertex(M.macro_uv_to_world(face,u,b)*LR)
func _flat()->void:
	var vp:=SubViewport.new(); vp.size=SIZE; vp.transparent_bg=false; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	var bg:=ColorRect.new(); bg.color=P.color(&"canvas"); bg.size=Vector2(float(SIZE.x),float(SIZE.y)); vp.add_child(bg)
	var title:=Label.new(); title.text="WORLD TOPOLOGY / FLAT NET"; title.position=Vector2(64,30); title.size=Vector2(520,40); title.add_theme_color_override("font_color",P.color(&"ink")); title.add_theme_font_size_override("font_size",24); vp.add_child(title)
	var scale:=minf((float(SIZE.x)-144.0)/M.FLAT_SIZE.x,(float(SIZE.y)-216.0)/M.FLAT_SIZE.y); var origin:=Vector2((float(SIZE.x)-M.FLAT_SIZE.x*scale)*0.5,float(SIZE.y)-72.0)
	for panel in T.PANEL_IDS:
		var c:=PackedVector2Array([_screen(M.panel_uv_to_flat(panel,Vector2(0,0)),origin,scale),_screen(M.panel_uv_to_flat(panel,Vector2(1,0)),origin,scale),_screen(M.panel_uv_to_flat(panel,Vector2(1,1)),origin,scale),_screen(M.panel_uv_to_flat(panel,Vector2(0,1)),origin,scale)])
		var poly:=Polygon2D.new(); poly.polygon=c; poly.color=P.color(&"surface_raised"); vp.add_child(poly)
		var line:=Line2D.new(); line.width=3.0; line.default_color=P.color(&"stroke_strong"); line.antialiased=true; line.points=PackedVector2Array([c[0],c[1],c[2],c[3],c[0]]); vp.add_child(line)
		var center:=_screen(M.panel_uv_to_flat(panel,Vector2(0.5,0.5)),origin,scale); var label:=Label.new(); label.text=panel; label.position=center-Vector2(30,16); label.size=Vector2(60,32); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; label.add_theme_color_override("font_color",P.color(&"accent")); label.add_theme_font_size_override("font_size",19); vp.add_child(label)
	await _save(vp,"topology_flat.png"); vp.queue_free(); await process_frame
func _screen(q:Vector2,o:Vector2,s:float)->Vector2: return Vector2(o.x+q.x*s,o.y-q.y*s)
func _save(vp:SubViewport,name:String)->void:
	for _i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var image:=vp.get_texture().get_image(); var path:="%s/%s"%[OUT,name]; var err:=image.save_png(path)
	if err!=OK: push_error("Could not save %s: %s"%[path,error_string(err)]); quit(1)
