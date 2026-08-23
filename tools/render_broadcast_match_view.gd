extends Node

## Presentation-only broadcast UI draft. Uses real MatchCourt3D + PlayerActor3D,
## stages an active attack/block/dig rally, and captures exact Godot frames.

const COURT := preload("res://scenes/components/match_court_3d.tscn")
const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const UI_FONT := preload("res://Short_Stack/ShortStack-Regular.ttf")

var court: MatchCourt3D
var overlay: Control
var announcer_cluster: Control

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	_build_court()
	_build_broadcast_overlay()
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture("broadcast_rally_top_right.png")
	_place_commentary_bottom_right()
	await get_tree().process_frame
	await _capture("broadcast_rally_bottom_right.png")
	_set_compact_score(true)
	_set_commentary("MIO", "Touched high off the hands — Pāwa has time to build again.")
	await get_tree().process_frame
	await _capture("broadcast_rally_compact.png")
	_set_dead_ball_state()
	await get_tree().process_frame
	await _capture("broadcast_dead_ball.png")
	get_tree().quit()

func _build_court() -> void:
	court = COURT.instantiate() as MatchCourt3D
	add_child(court)
	var home := {1:Vector2(0.20,0.73),2:Vector2(0.50,0.78),3:Vector2(0.80,0.72),4:Vector2(0.24,0.57),5:Vector2(0.51,0.55),6:Vector2(0.76,0.57)}
	var away := {11:Vector2(0.18,0.28),12:Vector2(0.50,0.22),13:Vector2(0.82,0.28),14:Vector2(0.25,0.43),15:Vector2(0.50,0.45),16:Vector2(0.76,0.43)}
	var names := {1:"Tōfa",2:"Hara",3:"Mako",4:"Sena",5:"Ira",6:"Nalu",11:"Rin",12:"Aster",13:"Mika",14:"Vale",15:"Noa",16:"Sora"}
	var profiles := {}
	for id in home.keys(): profiles[id]={"body_type":"Feli","body_marking":"blaze","club_region":"Pāwa Hitō"}
	for id in away.keys(): profiles[id]={"body_type":"Feli","body_marking":"patch","club_region":"Spëddigh"}
	court.setup_players(home,away,names,{},profiles)

	# Active rally tableau, not formation poses: setter has just released a high ball;
	# right-side attacker is airborne into a formed double block; floor defence is loaded.
	var setter := court.player_actors[5] as PlayerActor3D
	setter.set_pose(RallyEventModel.EventType.SET,0.82,0.58,Vector2(0.72,-0.70),true)
	var hitter := court.player_actors[3] as PlayerActor3D
	hitter.set_pose(RallyEventModel.EventType.ATTACK,0.98,0.82,Vector2(-0.20,-1.0),true)
	for id in [14,15]:
		var blocker := court.player_actors[id] as PlayerActor3D
		blocker.block_arms=&"two"
		blocker.set_pose(RallyEventModel.EventType.BLOCK,0.96,0.82,Vector2(0.0,1.0),true)
	for id in [11,12,13,16]:
		(court.player_actors[id] as PlayerActor3D).set_pose(RallyEventModel.EventType.DIG,0.76,0.58,Vector2(0.0,1.0),true)
	for id in [1,2,4,6]:
		(court.player_actors[id] as PlayerActor3D).set_pose(RallyEventModel.EventType.COVERAGE,0.68,0.48,Vector2(0.0,-1.0),true)
	court.ball_actor.position=Vector3(court.tactical_to_world(0.73,0.485,2.78).x,2.78,court.tactical_to_world(0.73,0.485,2.78).z)
	var cam:=court.camera_3d
	cam.position=Vector3(15.2,7.2,10.4); cam.fov=44.0
	cam.look_at(Vector3(0.0,1.25,-0.15),Vector3.UP)

func _panel_style(color:Color,radius:=8,border:=Color(1,1,1,0.12))->StyleBoxFlat:
	var s:=StyleBoxFlat.new(); s.bg_color=color
	s.border_width_left=1;s.border_width_top=1;s.border_width_right=1;s.border_width_bottom=1;s.border_color=border
	s.corner_radius_top_left=radius;s.corner_radius_top_right=radius;s.corner_radius_bottom_left=radius;s.corner_radius_bottom_right=radius
	return s

func _label(text:String,size:int,color:=Color.WHITE)->Label:
	var l:=Label.new();l.text=text;l.add_theme_font_override("font",UI_FONT);l.add_theme_font_size_override("font_size",size);l.add_theme_color_override("font_color",color);return l

func _build_broadcast_overlay()->void:
	overlay=Control.new();add_child(overlay);overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var score:=PanelContainer.new();score.name="ScoreBug";overlay.add_child(score);score.position=Vector2(22,20);score.size=Vector2(322,112);score.add_theme_stylebox_override("panel",_panel_style(Color(0.018,0.030,0.050,0.94),7))
	var sm:=MarginContainer.new();sm.name="Margin";score.add_child(sm);sm.add_theme_constant_override("margin_left",14);sm.add_theme_constant_override("margin_right",14);sm.add_theme_constant_override("margin_top",10);sm.add_theme_constant_override("margin_bottom",10)
	var sv:=VBoxContainer.new();sv.name="ScoreContent";sm.add_child(sv);sv.add_theme_constant_override("separation",3)
	var top:=HBoxContainer.new();sv.add_child(top);top.add_child(_label("SET 2",13,Color(0.78,0.82,0.87)));var spacer:=Control.new();spacer.size_flags_horizontal=Control.SIZE_EXPAND_FILL;top.add_child(spacer);top.add_child(_label("PĀWA LEADS 1–0",13,Color(0.96,0.78,0.30)))
	_add_score_row(sv,"PĀWA HITŌ",18,true);_add_score_row(sv,"SPËDDIGH",16,false)

	announcer_cluster=Control.new();announcer_cluster.name="AnnouncerCluster";overlay.add_child(announcer_cluster);announcer_cluster.position=Vector2(846,22);announcer_cluster.size=Vector2(408,206)
	var bubble:=PanelContainer.new();bubble.name="CommentaryBubble";announcer_cluster.add_child(bubble);bubble.position=Vector2(0,0);bubble.size=Vector2(408,116);bubble.add_theme_stylebox_override("panel",_panel_style(Color(0.018,0.030,0.050,0.91),9))
	var bm:=MarginContainer.new();bm.name="Margin";bubble.add_child(bm);bm.add_theme_constant_override("margin_left",14);bm.add_theme_constant_override("margin_right",14);bm.add_theme_constant_override("margin_top",10);bm.add_theme_constant_override("margin_bottom",10)
	var bv:=VBoxContainer.new();bv.name="Copy";bm.add_child(bv);bv.add_theme_constant_override("separation",4)
	var speaker:=_label("KAI",12,Color(0.96,0.78,0.30));speaker.name="Speaker";bv.add_child(speaker)
	var commentary:=_label("Tōfa sees the seam and drives through it — Spëddigh's block is late closing the outside hand.",16,Color(0.94,0.95,0.97));commentary.name="Commentary";commentary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;commentary.size_flags_vertical=Control.SIZE_EXPAND_FILL;bv.add_child(commentary)
	_build_announcer_headshot(announcer_cluster,Vector2(246,122),"KAI",901,"blaze")
	_build_announcer_headshot(announcer_cluster,Vector2(326,122),"MIO",902,"speckles")

	var ribbon:=PanelContainer.new();ribbon.name="ControlRibbon";overlay.add_child(ribbon);ribbon.position=Vector2(240,660);ribbon.size=Vector2(800,46);ribbon.add_theme_stylebox_override("panel",_panel_style(Color(0.015,0.025,0.043,0.86),10))
	var rm:=MarginContainer.new();ribbon.add_child(rm);rm.add_theme_constant_override("margin_left",16);rm.add_theme_constant_override("margin_right",16);rm.add_theme_constant_override("margin_top",7);rm.add_theme_constant_override("margin_bottom",7)
	var rh:=HBoxContainer.new();rm.add_child(rh);rh.add_theme_constant_override("separation",14)
	for txt in ["◀","Ⅱ","▶"]:rh.add_child(_label(txt,17,Color(0.90,0.92,0.95)))
	rh.add_child(VSeparator.new());rh.add_child(_label("BROADCAST",14,Color(0.96,0.78,0.30)));rh.add_child(_label("FREE",14,Color(0.72,0.78,0.85)));rh.add_child(_label("FOLLOW",14,Color(0.72,0.78,0.85)));var flex:=Control.new();flex.size_flags_horizontal=Control.SIZE_EXPAND_FILL;rh.add_child(flex);rh.add_child(_label("−   ZOOM   +",14,Color(0.72,0.78,0.85)));rh.add_child(VSeparator.new());rh.add_child(_label("REPLAY",14,Color(0.90,0.92,0.95)))

func _add_score_row(parent:VBoxContainer,region:String,score_value:int,serving:bool)->void:
	var row:=HBoxContainer.new();parent.add_child(row);var name:=_label(("●  " if serving else "   ")+region,18,Color(0.95,0.96,0.98));name.size_flags_horizontal=Control.SIZE_EXPAND_FILL;row.add_child(name);var score:=_label(str(score_value),24,Color.WHITE);score.custom_minimum_size=Vector2(34,0);score.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT;row.add_child(score)

func _build_announcer_headshot(parent:Control,pos:Vector2,tag:String,actor_id:int,mark:String)->void:
	var frame:=PanelContainer.new();parent.add_child(frame);frame.position=pos;frame.size=Vector2(68,68);frame.add_theme_stylebox_override("panel",_panel_style(Color(0.04,0.06,0.09,0.96),34,Color(1,1,1,0.18)))
	var vpc:=SubViewportContainer.new();frame.add_child(vpc);vpc.stretch=true;var vp:=SubViewport.new();vpc.add_child(vp);vp.size=Vector2i(136,136);vp.transparent_bg=true;vp.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	# Dedicated neutral announcer placeholders: unique IDs/marks, no club_region/team kit.
	var actor:=ACTOR.instantiate() as PlayerActor3D;vp.add_child(actor);actor.configure(actor_id,true,tag,"Right",{"body_type":"Feli","body_marking":mark});actor.position=Vector3(0,-1.05,0)
	var light:=DirectionalLight3D.new();vp.add_child(light);light.rotation_degrees=Vector3(-35,-25,0);light.light_energy=1.4
	var world:=WorldEnvironment.new();vp.add_child(world);var env:=Environment.new();world.environment=env;env.background_mode=Environment.BG_COLOR;env.background_color=Color(0.03,0.04,0.06);env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color(1,0.92,0.82);env.ambient_light_energy=1.2
	var cam:=Camera3D.new();vp.add_child(cam);cam.position=Vector3(0,1.38,3.2);cam.fov=28;cam.look_at(Vector3(0,1.30,0),Vector3.UP);cam.current=true
	var tag_label:=_label(tag,12,Color(0.90,0.92,0.95));parent.add_child(tag_label);tag_label.position=pos+Vector2(17,70)

func _place_commentary_bottom_right()->void:
	announcer_cluster.position=Vector2(846,430)

func _set_compact_score(compact:bool)->void:
	var score:=overlay.get_node("ScoreBug") as PanelContainer
	if compact:
		score.size=Vector2(282,82);var content:=score.get_node("Margin/ScoreContent") as VBoxContainer;(content.get_child(0) as Control).visible=false

func _set_commentary(speaker_name:String,text:String)->void:
	var copy:=overlay.get_node("AnnouncerCluster/CommentaryBubble/Margin/Copy") as VBoxContainer;(copy.get_node("Speaker") as Label).text=speaker_name;(copy.get_node("Commentary") as Label).text=text

func _set_dead_ball_state()->void:
	announcer_cluster.position=Vector2(846,22);_set_commentary("KAI","That touch changed the whole rally. The block takes enough pace off it for Pāwa to reset behind the ball.")
	var lower:=PanelContainer.new();lower.name="LowerThird";overlay.add_child(lower);lower.position=Vector2(32,548);lower.size=Vector2(390,84);lower.add_theme_stylebox_override("panel",_panel_style(Color(0.018,0.030,0.050,0.92),7));var m:=MarginContainer.new();lower.add_child(m);m.add_theme_constant_override("margin_left",14);m.add_theme_constant_override("margin_top",9);var v:=VBoxContainer.new();m.add_child(v);v.add_child(_label("POINT — PĀWA HITŌ",13,Color(0.96,0.78,0.30)));v.add_child(_label("19 – 16",26,Color.WHITE));v.add_child(_label("Block touch creates the reset",14,Color(0.78,0.83,0.89)))

func _capture(filename:String)->void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://artifacts/broadcast-draft"));await RenderingServer.frame_post_draw;var image:=get_tree().root.get_texture().get_image();var path:="res://artifacts/broadcast-draft/%s"%filename;image.save_png(path);print("saved %s"%ProjectSettings.globalize_path(path))
