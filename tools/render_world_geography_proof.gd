extends SceneTree

const T := preload("res://scripts/data/world_panel_topology.gd")
const M := preload("res://scripts/world/world_surface_mapper.gd")
const G := preload("res://scripts/data/world_geography.gd")
const POL := preload("res://scripts/data/world_political_geography.gd")
const P := preload("res://scripts/data/ui_palette.gd")
const DARK_THEME := preload("res://scenes/themes/dark_theme.tres")

const OUT := "res://artifacts/world-geography"
const VIEW_SIZE := Vector2i(1024,1024)
const FLAT_SIZE := Vector2i(1024,768)
const FLAT_SCALE := 64.0
const FLAT_ORIGIN := Vector2(128.0,704.0)
const R := 2.5
const LR := R * 1.006
const GU := 24
const GV := 72
const VIEWS := {
	"geography_globe_landavol.png":Vector3(-5.4,3.3,7.2),
	"geography_globe_opposite.png":Vector3(5.4,-3.3,-7.2),
	"geography_globe_pole.png":Vector3(0.15,8.8,0.2),
}

const REGION_TINTS := {
	"Landavol":Color("f2c84b"), "Zaitgaist":Color("ff8b6b"),
	"Spëddigh":Color("8fc7da"), "Rhėn Tempaol":Color("86d1b1"), "Ĭspayk":Color("b8a2df"),
	"Blôc du Larg":Color("d9d2a7"), "Bompaçao":Color("77c98d"),
	"Xérvu":Color("df9b68"), "Kutré Lyn":Color("eac285"),
	"Taktikã":Color("a6b0c4"), "Tãul ys Feynt":Color("c2a5cf"),
	"Pāwa Hitō":Color("ef8c72"), "Lo-ong Ralī":Color("aec4d8"), "A'ace":Color("f0d17b"),
}

func _initialize()->void:
	call_deferred("_run")

func _run()->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var physical := _build_flat(false)
	var err := physical.save_png("%s/geography_flat.png" % OUT)
	if err != OK: _fail("geography_flat.png",err); return
	var political := _build_flat(true)
	await _save_political_flat(political)
	await _render_globes()
	print("Rendered canonical world geography proof to %s" % OUT)
	quit()


func _terrain_color(sample:Dictionary)->Color:
	var c:Color
	match String(sample.terrain):
		"deep_ocean": c=Color("15364a")
		"shelf": c=Color("2f6872")
		"glacial": c=Color("d9e2da")
		"cold_highland": c=Color("a6b3aa")
		"dry_plateau": c=Color("a98562")
		"arid": c=Color("c49c68")
		"volcanic": c=Color("776f66")
		"river_lowland": c=Color("719c79")
		"highland": c=Color("8c8b6d")
		"wet_lowland": c=Color("6e9c78")
		_: c=Color("9da77a")
	if float(sample.river_strength) > 0.56 and bool(sample.land):
		c = c.lerp(Color("4c9aa3"),0.68)
	return c

func _region_color(region:String)->Color:
	return Color(REGION_TINTS.get(region,P.color(&"accent")))


func _build_flat(show_politics:bool)->Image:
	var image := Image.create(FLAT_SIZE.x,FLAT_SIZE.y,false,Image.FORMAT_RGBA8)
	image.fill(P.color(&"canvas"))
	var nu:=64; var nv:=192
	for panel in T.PANEL_IDS:
		for y in range(nv):
			for x in range(nu):
				var uv:=Vector2((float(x)+0.5)/float(nu),(float(y)+0.5)/float(nv))
				var d:=M.panel_uv_to_world(panel,uv)
				var color:=_terrain_color(G.sample_world(d))
				if show_politics:
					var region:=POL.region_at(d)
					if not region.is_empty(): color=color.lerp(_region_color(region),0.30)
				var q:=_flat_screen(M.panel_uv_to_flat(panel,uv))
				var px:=int(floor(q.x)); var py:=int(floor(q.y))
				if px>=0 and px<image.get_width() and py>=0 and py<image.get_height(): image.set_pixel(px,py,color)
	_draw_panel_seams(image)
	if show_politics: _draw_political_boundaries_flat(image)
	return image

func _flat_screen(q:Vector2)->Vector2:
	return Vector2(FLAT_ORIGIN.x+q.x*FLAT_SCALE,FLAT_ORIGIN.y-q.y*FLAT_SCALE)

func _draw_panel_seams(image:Image)->void:
	for panel in T.PANEL_IDS:
		for i in range(193):
			var t:=float(i)/192.0
			_dot(image,_flat_screen(M.panel_uv_to_flat(panel,Vector2(t,0))),P.color(&"canvas"),1)
			_dot(image,_flat_screen(M.panel_uv_to_flat(panel,Vector2(t,1))),P.color(&"canvas"),1)
			_dot(image,_flat_screen(M.panel_uv_to_flat(panel,Vector2(0,t))),P.color(&"canvas"),1)
			_dot(image,_flat_screen(M.panel_uv_to_flat(panel,Vector2(1,t))),P.color(&"canvas"),1)

func _draw_political_boundaries_flat(image:Image)->void:
	var nu:=48; var nv:=144
	for panel in T.PANEL_IDS:
		for y in range(nv):
			for x in range(nu):
				var uv:=Vector2((float(x)+0.5)/float(nu),(float(y)+0.5)/float(nv))
				var here:=POL.region_at(M.panel_uv_to_world(panel,uv))
				if x+1<nu:
					var there:=POL.region_at(M.panel_uv_to_world(panel,Vector2((float(x)+1.5)/float(nu),uv.y)))
					if here!=there and (not here.is_empty() or not there.is_empty()):
						_dot(image,_flat_screen(M.panel_uv_to_flat(panel,Vector2(float(x+1)/float(nu),uv.y))),P.color(&"accent"),1)
				if y+1<nv:
					var there2:=POL.region_at(M.panel_uv_to_world(panel,Vector2(uv.x,(float(y)+1.5)/float(nv))))
					if here!=there2 and (not here.is_empty() or not there2.is_empty()):
						_dot(image,_flat_screen(M.panel_uv_to_flat(panel,Vector2(uv.x,float(y+1)/float(nv)))),P.color(&"accent"),1)

func _dot(image:Image,p:Vector2,color:Color,radius:int)->void:
	var cx:=int(round(p.x)); var cy:=int(round(p.y))
	for dy in range(-radius,radius+1):
		for dx in range(-radius,radius+1):
			var x:=cx+dx; var y:=cy+dy
			if x>=0 and x<image.get_width() and y>=0 and y<image.get_height(): image.set_pixel(x,y,color)


func _save_political_flat(image:Image)->void:
	var vp:=SubViewport.new(); vp.size=FLAT_SIZE; vp.transparent_bg=false; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(vp)
	var texture:=TextureRect.new(); texture.texture=ImageTexture.create_from_image(image); texture.size=Vector2(FLAT_SIZE); vp.add_child(texture)
	var title:=Label.new(); title.theme=DARK_THEME; title.text="WORLD REGISTER / POLITICAL FOOTPRINT PROOF"; title.position=Vector2(38,22); title.size=Vector2(620,42); title.add_theme_color_override("font_color",P.color(&"ink")); title.add_theme_font_size_override("font_size",22); vp.add_child(title)
	for region in POL.all_regions():
		var a:=POL.label_anchor(region); var q:=_flat_screen(M.panel_uv_to_flat(String(a.panel),Vector2(a.uv)))
		var label:=Label.new(); label.theme=DARK_THEME; label.text=region; label.position=q-Vector2(78,11); label.size=Vector2(156,24); label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; label.vertical_alignment=VERTICAL_ALIGNMENT_CENTER; label.add_theme_color_override("font_color",P.color(&"ink")); label.add_theme_color_override("font_outline_color",P.color(&"canvas")); label.add_theme_constant_override("outline_size",5); label.add_theme_font_size_override("font_size",13); vp.add_child(label)
	await _save_viewport(vp,"politics_flat.png")
	vp.queue_free(); await process_frame


func _render_globes()->void:
	var vp:=SubViewport.new(); vp.size=VIEW_SIZE; vp.transparent_bg=false; vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS; vp.own_world_3d=true; root.add_child(vp)
	var world:=World3D.new(); vp.world_3d=world
	var env:=Environment.new(); env.background_mode=Environment.BG_COLOR; env.background_color=P.color(&"canvas"); env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color=Color.WHITE; env.ambient_light_energy=1.0; world.environment=env

	var physical:=MeshInstance3D.new(); physical.mesh=_surface_mesh(false); vp.add_child(physical)
	var political:=MeshInstance3D.new(); political.mesh=_surface_mesh(true); political.visible=false; vp.add_child(political)
	var seams:=MeshInstance3D.new(); seams.mesh=_structural_lines(); vp.add_child(seams)
	var boundaries:=MeshInstance3D.new(); boundaries.mesh=_political_lines(); boundaries.visible=false; vp.add_child(boundaries)

	var cam:=Camera3D.new(); cam.fov=32.0; vp.add_child(cam); cam.current=true
	for name in VIEWS:
		cam.position=VIEWS[name]; var up:=Vector3.UP
		if absf(cam.position.normalized().dot(Vector3.UP))>0.96: up=Vector3.FORWARD
		cam.look_at(Vector3.ZERO,up); await _save_viewport(vp,name)

	physical.visible=false; political.visible=true; boundaries.visible=true
	cam.position=VIEWS["geography_globe_landavol.png"]; cam.look_at(Vector3.ZERO,Vector3.UP)
	await _save_viewport(vp,"politics_globe_landavol.png")
	vp.queue_free(); await process_frame

func _surface_mesh(show_politics:bool)->ImmediateMesh:
	var im:=ImmediateMesh.new(); var mat:=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.vertex_color_use_as_albedo=true
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES,mat)
	for panel in T.PANEL_IDS:
		for y in range(GV):
			for x in range(GU):
				var u0:=float(x)/float(GU); var u1:=float(x+1)/float(GU); var v0:=float(y)/float(GV); var v1:=float(y+1)/float(GV)
				_vertex(im,panel,Vector2(u0,v0),show_politics); _vertex(im,panel,Vector2(u1,v0),show_politics); _vertex(im,panel,Vector2(u1,v1),show_politics)
				_vertex(im,panel,Vector2(u0,v0),show_politics); _vertex(im,panel,Vector2(u1,v1),show_politics); _vertex(im,panel,Vector2(u0,v1),show_politics)
	im.surface_end(); return im

func _vertex(im:ImmediateMesh,panel:String,uv:Vector2,show_politics:bool)->void:
	var d:=M.panel_uv_to_world(panel,uv); var color:=_terrain_color(G.sample_world(d))
	if show_politics:
		var region:=POL.region_at(d)
		if not region.is_empty(): color=color.lerp(_region_color(region),0.30)
	im.surface_set_color(color); im.surface_add_vertex(d*R)

func _structural_lines()->ImmediateMesh:
	var im:=ImmediateMesh.new(); var mat:=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color=P.color(&"canvas")
	im.surface_begin(Mesh.PRIMITIVE_LINES,mat)
	for seam in T.MACRO_SEAMS: _macro_curve(im,String(seam.a_face),String(seam.a_edge))
	for face in T.FACE_IDS: _internal_curve(im,face,-1.0/3.0); _internal_curve(im,face,1.0/3.0)
	im.surface_end(); return im

func _macro_curve(im:ImmediateMesh,face:String,edge:String)->void:
	for i in range(64):
		var a:=-1.0+2.0*float(i)/64.0; var b:=-1.0+2.0*float(i+1)/64.0
		im.surface_add_vertex(M.macro_edge_to_world(face,edge,a)*LR); im.surface_add_vertex(M.macro_edge_to_world(face,edge,b)*LR)

func _internal_curve(im:ImmediateMesh,face:String,u:float)->void:
	for i in range(64):
		var a:=-1.0+2.0*float(i)/64.0; var b:=-1.0+2.0*float(i+1)/64.0
		im.surface_add_vertex(M.macro_uv_to_world(face,u,a)*LR); im.surface_add_vertex(M.macro_uv_to_world(face,u,b)*LR)

func _political_lines()->ImmediateMesh:
	var im:=ImmediateMesh.new(); var mat:=StandardMaterial3D.new(); mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; mat.albedo_color=P.color(&"accent")
	im.surface_begin(Mesh.PRIMITIVE_LINES,mat)
	var nu:=20; var nv:=60
	for panel in T.PANEL_IDS:
		for y in range(nv):
			for x in range(nu):
				var uv:=Vector2((float(x)+0.5)/float(nu),(float(y)+0.5)/float(nv)); var here:=POL.region_at(M.panel_uv_to_world(panel,uv))
				if x+1<nu:
					var there:=POL.region_at(M.panel_uv_to_world(panel,Vector2((float(x)+1.5)/float(nu),uv.y)))
					if here!=there and (not here.is_empty() or not there.is_empty()):
						var bx:=float(x+1)/float(nu); _political_segment(im,panel,Vector2(bx,float(y)/float(nv)),Vector2(bx,float(y+1)/float(nv)))
				if y+1<nv:
					var there2:=POL.region_at(M.panel_uv_to_world(panel,Vector2(uv.x,(float(y)+1.5)/float(nv))))
					if here!=there2 and (not here.is_empty() or not there2.is_empty()):
						var by:=float(y+1)/float(nv); _political_segment(im,panel,Vector2(float(x)/float(nu),by),Vector2(float(x+1)/float(nu),by))
	im.surface_end(); return im

func _political_segment(im:ImmediateMesh,panel:String,a:Vector2,b:Vector2)->void:
	im.surface_add_vertex(M.panel_uv_to_world(panel,a)*LR); im.surface_add_vertex(M.panel_uv_to_world(panel,b)*LR)

func _save_viewport(vp:SubViewport,name:String)->void:
	for _i in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var image:=vp.get_texture().get_image(); var path:="%s/%s"%[OUT,name]; var err:=image.save_png(path)
	if err!=OK: _fail(path,err)

func _fail(path:String,err:int)->void:
	push_error("Could not save %s: %s" % [path,error_string(err)]); quit(1)
