class_name VolleyballPhilosophyPreview
extends SubViewportContainer

## Deterministic teaching vignette used by 02 VOLLEYBALL. The tactical problem,
## initial positions and decision are authored; the production actor rig owns
## locomotion, stance interpolation, approaches, contacts, block jumps and landings.
const COURT_SCENE := preload("res://scenes/components/match_court_3d.tscn")
const RallyEventModel := preload("res://scripts/models/rally_event.gd")
const BlockJumpModelRef := preload("res://scripts/simulation/block_jump_model.gd")
const SpikeBiomechanicsRef := preload("res://scripts/data/spike_biomechanics.gd")
const BlockBiomechanicsRef := preload("res://scripts/data/block_biomechanics.gd")

const HOME_BASE := {1: Vector2(0.20,0.58),2: Vector2(0.50,0.57),3: Vector2(0.80,0.58),4: Vector2(0.20,0.82),5: Vector2(0.50,0.84),6: Vector2(0.80,0.82)}
const AWAY_BASE := {101: Vector2(0.20,0.42),102: Vector2(0.50,0.43),103: Vector2(0.80,0.42),104: Vector2(0.20,0.18),105: Vector2(0.50,0.16),106: Vector2(0.80,0.18)}
const ACTIVE_FRACTION := 0.88
const BLOCK_LOAD_SECONDS := 0.18
const BLOCK_MIN_DESCENT_SECONDS := 0.12
const DEFAULT_BLOCK_LEAP_METERS := 0.60
var _viewport: SubViewport
var _court: MatchCourt3D
var _vignette_id := "good_ball_read"
var _montage_vignettes: Array[String] = ["good_ball_read","serve_target","defense_read","transition_opportunity","broken_available","construction_flexible"]
var _clock := 0.0
var _ready_to_draw := false

func _ready() -> void:
	stretch = true
	custom_minimum_size = Vector2(0,250)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_viewport = SubViewport.new(); _viewport.name = "GameplayViewport"; _viewport.size = Vector2i(760,300); _viewport.own_world_3d = true; _viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	_court = COURT_SCENE.instantiate() as MatchCourt3D; _viewport.add_child(_court)
	await get_tree().process_frame
	_court.setup_players(HOME_BASE,AWAY_BASE)
	for raw_id in _court.player_actors:
		var actor := _court.player_actors[raw_id] as PlayerActor3D
		actor.identity_label.visible = false; actor.focus_ring.visible = false
		## setup_players leaves both teams at the rig's default yaw. Home attacks
		## toward -Z; Away must start square to the net facing +Z.
		actor.facing_yaw = 0.0 if int(raw_id) < 100 else PI
		actor.has_facing = true
		actor.rotation.y = actor.facing_yaw
	_court.camera_3d.position = Vector3(9.1,8.2,8.9); _court.camera_3d.fov = 37.0; _court.camera_3d.look_at(Vector3(-0.25,0.85,1.15),Vector3.UP)
	## BallActor3D.reset_flight() hides the whole node. Authored preview placement
	## does not call begin_ball_flight(), so make the production ball visible here.
	_court.ball_actor.visible = true
	_ready_to_draw = true; _reset_players(); _apply_frame(0.0)

func set_vignette(vignette_id:String)->void:
	_vignette_id=vignette_id; _clock=0.0
	if _ready_to_draw: _reset_players(); _apply_frame(0.0)
func set_montage_vignettes(vignette_ids:Array[String])->void:
	if vignette_ids.is_empty(): return
	_montage_vignettes=vignette_ids.duplicate(); _clock=0.0
func _process(delta:float)->void:
	if not _ready_to_draw or not visible:return
	var duration:=_loop_seconds(); var next_clock:=_clock+delta
	if next_clock>=duration:
		_clock=fmod(next_clock,duration)
		if _vignette_id.begins_with("good_ball_"): _reset_players()
	else:_clock=next_clock
	_apply_frame(_clock/duration)
func _loop_seconds()->float:
	if _vignette_id.begins_with("good_ball_"):return 5.8
	if _vignette_id=="serve_aggressive":return 5.0
	if _vignette_id=="volleyball_montage":return 7.2
	return 4.2
func _apply_frame(raw_t:float)->void:
	if not _vignette_id.begins_with("good_ball_"):_reset_players()
	var t:=clampf(raw_t/ACTIVE_FRACTION,0.0,1.0)
	if _vignette_id=="volleyball_montage":_montage(t)
	else:_draw_vignette(_vignette_id,t)
func _draw_vignette(id:String,t:float)->void:
	match id:
		"good_ball_quick":_good_ball(t,"quick")
		"good_ball_read":_good_ball(t,"read")
		"good_ball_hitter":_good_ball(t,"hitter")
		"serve_controlled":_serve(t,"controlled")
		"serve_target":_serve(t,"target")
		"serve_aggressive":_serve(t,"aggressive")
		"defense_floor":_defense(t,"floor")
		"defense_read":_defense(t,"read")
		"defense_block":_defense(t,"block")
		"transition_reset":_transition(t,"reset")
		"transition_opportunity":_transition(t,"opportunity")
		"transition_pressure":_transition(t,"pressure")
		"broken_structure":_broken_ball(t,"structure")
		"broken_available":_broken_ball(t,"available")
		"broken_pressure":_broken_ball(t,"pressure")
		"construction_combination":_construction(t,"combination")
		"construction_flexible":_construction(t,"flexible")
		"construction_isolation":_construction(t,"isolation")
		_:_good_ball(t,"read")
func _reset_players()->void:
	for id in HOME_BASE:_court.set_player_position(int(id),HOME_BASE[id])
	for id in AWAY_BASE:_court.set_player_position(int(id),AWAY_BASE[id])
	for raw_id in _court.player_actors:
		var actor:=_court.player_actors[raw_id] as PlayerActor3D
		actor.ready_stance="defending"; actor.block_arms=&"two"; actor.set_pose(-1,0.0,0.0,Vector2.ZERO,false)
		actor.facing_yaw=0.0 if int(raw_id)<100 else PI; actor.has_facing=true; actor.rotation.y=actor.facing_yaw
	_court.ball_actor.visible=true
func _ball(p:Vector2,h:float)->void:
	_court.ball_actor.visible=true; _court.ball_actor.position=_court.tactical_to_world(p.x,p.y,h)
func _arc(a:Vector2,b:Vector2,t:float,peak:float=3.1)->void:
	var f:=clampf(t,0.0,1.0); _ball(a.lerp(b,f),0.8+sin(f*PI)*peak)
func _flight(a:Vector2,a_h:float,b:Vector2,b_h:float,progress:float,lift:float)->void:
	var f:=clampf(progress,0.0,1.0); _ball(a.lerp(b,f),lerpf(a_h,b_h,f)+sin(f*PI)*lift)
func _move(id:int,target:Vector2,t:float,begin:float,end:float)->void:
	var base:Vector2=HOME_BASE.get(id,AWAY_BASE.get(id,target)); _court.set_player_position(id,base.lerp(target,smoothstep(begin,end,t)))
func _sample(points:Array,times:Array,t:float)->Vector2:
	if points.is_empty() or points.size()!=times.size():return Vector2.ZERO
	if t<=float(times[0]):return Vector2(points[0])
	for i in range(points.size()-1):
		if t<=float(times[i+1]):return Vector2(points[i]).lerp(Vector2(points[i+1]),smoothstep(float(times[i]),float(times[i+1]),t))
	return Vector2(points[-1])
func _pose_action(id:int,event_type:int,t:float,begin:float,contact:float,end:float,peak:float,direction:Vector2,context:Dictionary={})->bool:
	if t<begin or t>end:return false
	var actor:=_court.player_actors.get(id) as PlayerActor3D
	if actor==null:return false
	if event_type==RallyEventModel.EventType.BLOCK:
		var seconds:=_loop_seconds()*ACTIVE_FRACTION; var leap:=maxf(float(context.get("leap_meters",DEFAULT_BLOCK_LEAP_METERS)),0.01); var contact_time:=contact*seconds
		var timeline:=BlockJumpModelRef.jump_timeline(contact_time,leap,absf(float(context.get("timing_error_seconds",0.0))),bool(context.get("late",false))); var moment:=t*seconds
		actor.set_pose(event_type,BlockJumpModelRef.draw_peak(leap)*BlockJumpModelRef.elevation_at(moment,timeline),_block_pose_phase(moment,timeline,contact_time),direction,true,context); return true
	var phase:=lerpf(-1.0,0.0,inverse_lerp(begin,contact,t)) if t<=contact else lerpf(0.0,1.0,inverse_lerp(contact,end,t)); var elevation:=0.0
	if event_type==RallyEventModel.EventType.ATTACK:
		elevation=peak*smoothstep(SpikeBiomechanicsRef.PLANT_END,0.0,phase) if phase<=0.0 else peak*(1.0-smoothstep(0.18,0.75,phase))
	actor.set_pose(event_type,elevation,phase,direction,true,context); return true
func _block_pose_phase(moment:float,timeline:Dictionary,contact_time:float)->float:
	var takeoff:=float(timeline.get("takeoff",contact_time)); var peak:=float(timeline.get("peak",contact_time)); var landing:=float(timeline.get("landing",contact_time)); var load:=takeoff-BLOCK_LOAD_SECONDS
	if moment<=load:return -1.0
	if moment<=takeoff:return lerpf(-1.0,BlockBiomechanicsRef.LOAD_END,inverse_lerp(load,takeoff,moment))
	if moment<=peak:return lerpf(BlockBiomechanicsRef.LOAD_END,0.0,inverse_lerp(takeoff,peak,moment))
	var latest:=maxf(peak,landing-BLOCK_MIN_DESCENT_SECONDS); var hold:=clampf(maxf(peak+0.06,contact_time+0.02),peak,latest)
	if moment<=hold and hold>peak+0.0001:return lerpf(0.0,BlockBiomechanicsRef.HOLD_END,inverse_lerp(peak,hold,moment))
	if moment<=landing and landing>hold+0.0001:return lerpf(BlockBiomechanicsRef.HOLD_END,BlockBiomechanicsRef.LANDED_PHASE,inverse_lerp(hold,landing,moment))
	return 1.0
func _q1_positions(mode:String,t:float)->Dictionary:
	var p:Dictionary={}; for id in HOME_BASE:p[id]=HOME_BASE[id]
	for id in AWAY_BASE:p[id]=AWAY_BASE[id]
	p[5]=_sample([HOME_BASE[5],Vector2(0.50,0.82),Vector2(0.48,0.73)],[0.0,0.08,0.28],t); p[3]=_sample([HOME_BASE[3],Vector2(0.66,0.57)],[0.0,0.20],t); p[4]=_sample([HOME_BASE[4],Vector2(0.19,0.76),Vector2(0.28,0.69)],[0.0,0.18,0.34],t); p[1]=_sample([HOME_BASE[1],Vector2(0.12,0.61),Vector2(0.18,0.54)],[0.0,0.18,0.34],t); p[2]=_sample([HOME_BASE[2],Vector2(0.48,0.54)],[0.0,0.28],t); p[6]=_sample([HOME_BASE[6],Vector2(0.78,0.73),Vector2(0.73,0.66)],[0.0,0.24,0.38],t)
	if mode=="quick":
		p[2]=_sample([HOME_BASE[2],Vector2(0.48,0.54),Vector2(0.50,0.515)],[0.0,0.27,0.37],t); p[102]=_sample([AWAY_BASE[102],Vector2(0.48,0.445)],[0.0,0.42],t); p[103]=_sample([AWAY_BASE[103],Vector2(0.72,0.445),Vector2(0.58,0.445)],[0.0,0.36,0.58],t)
	elif mode=="read":
		p[102]=_sample([AWAY_BASE[102],Vector2(0.43,0.445),Vector2(0.29,0.445),Vector2(0.29,0.445),Vector2(0.38,0.445)],[0.0,0.30,0.38,0.43,0.67],t); p[103]=_sample([AWAY_BASE[103],Vector2(0.70,0.445),Vector2(0.60,0.445),Vector2(0.32,0.445)],[0.0,0.34,0.43,0.67],t)
	else:
		p[102]=_sample([AWAY_BASE[102],Vector2(0.28,0.445),Vector2(0.235,0.445)],[0.0,0.43,0.53],t); p[103]=_sample([AWAY_BASE[103],Vector2(0.20,0.445),Vector2(0.155,0.445)],[0.0,0.45,0.53],t)
	return p
func _q1_prepare(mode:String,t:float)->void:
	for id in _q1_positions(mode,t):_court.set_player_position(int(id),Vector2(_q1_positions(mode,t)[id]))
	for id in _court.player_actors:
		var actor:=_court.player_actors[id] as PlayerActor3D; actor.block_arms=&"two"; actor.ready_stance="blocking" if int(id) in [101,102,103] else "defending"
func _mark(active:Dictionary,id:int,event_type:int,t:float,b:float,c:float,e:float,p:float,d:Vector2,ctx:Dictionary={})->void:
	if _pose_action(id,event_type,t,b,c,e,p,d,ctx):active[id]=true
func _idle(active:Dictionary)->void:
	for id in _court.player_actors:
		if not active.has(int(id)):(_court.player_actors[id] as PlayerActor3D).set_pose(-1,0.0,0.0,Vector2.ZERO,false)
func _good_ball(t:float,mode:String)->void:
	var receive:=Vector2(0.50,0.82); var setter:=Vector2(0.66,0.57); _q1_prepare(mode,t); var active:={}; _mark(active,5,RallyEventModel.EventType.RECEPTION,t,0.0,0.08,0.22,0.0,Vector2(0.16,-0.25))
	if mode=="quick":
		_mark(active,3,RallyEventModel.EventType.SET,t,0.16,0.25,0.36,0.0,Vector2(-0.16,-0.06)); _mark(active,2,RallyEventModel.EventType.ATTACK,t,0.25,0.40,0.64,0.86,Vector2(-0.02,-0.34)); _mark(active,102,RallyEventModel.EventType.BLOCK,t,0.30,0.42,0.64,0.0,Vector2(0,0.20),{"leap_meters":0.60}); (_court.player_actors[103] as PlayerActor3D).block_arms=&"one"; _mark(active,103,RallyEventModel.EventType.BLOCK,t,0.38,0.53,0.76,0.0,Vector2(-0.18,0.20),{"leap_meters":0.56,"timing_error_seconds":0.16,"late":true}); _idle(active)
		if t<0.08:_flight(Vector2(0.52,0.46),3.4,receive,0.92,t/0.08,0.35)
		elif t<0.22:_flight(receive,0.92,setter,2.08,(t-0.08)/0.14,0.72)
		elif t<0.28:_flight(setter,2.08,Vector2(0.50,0.515),2.82,(t-0.22)/0.06,0.38)
		elif t<0.40:_flight(Vector2(0.50,0.515),2.82,Vector2(0.49,0.40),3.02,(t-0.28)/0.12,0.28)
		elif t<0.58:_flight(Vector2(0.49,0.40),3.02,Vector2(0.49,0.17),0.30,(t-0.40)/0.18,0.12)
		else:_ball(Vector2(0.49,0.17),0.30)
		return
	if mode=="read":
		_mark(active,2,RallyEventModel.EventType.ATTACK,t,0.27,0.40,0.62,0.72,Vector2(-0.02,-0.25)); _mark(active,102,RallyEventModel.EventType.BLOCK,t,0.27,0.40,0.62,0.0,Vector2(0,0.22),{"leap_meters":0.58}); _mark(active,3,RallyEventModel.EventType.SET,t,0.34,0.44,0.55,0.0,Vector2(-0.48,-0.04)); _mark(active,1,RallyEventModel.EventType.ATTACK,t,0.43,0.60,0.84,0.88,Vector2(0.16,-0.34)); _mark(active,103,RallyEventModel.EventType.BLOCK,t,0.49,0.61,0.82,0.0,Vector2(-0.18,0.22),{"leap_meters":0.60}); _idle(active)
		if t<0.08:_flight(Vector2(0.52,0.46),3.4,receive,0.92,t/0.08,0.35)
		elif t<0.22:_flight(receive,0.92,setter,2.08,(t-0.08)/0.14,0.72)
		elif t<0.44:_ball(setter,2.08)
		elif t<0.57:_flight(setter,2.08,Vector2(0.18,0.535),2.92,(t-0.44)/0.13,0.72)
		elif t<0.76:_flight(Vector2(0.18,0.535),2.92,Vector2(0.34,0.20),0.32,(t-0.57)/0.19,0.14)
		else:_ball(Vector2(0.34,0.20),0.32)
		return
	_mark(active,3,RallyEventModel.EventType.SET,t,0.22,0.34,0.46,0.0,Vector2(-0.49,-0.04)); _mark(active,1,RallyEventModel.EventType.ATTACK,t,0.40,0.61,0.88,0.90,Vector2(-0.02,-0.25)); _mark(active,102,RallyEventModel.EventType.BLOCK,t,0.42,0.61,0.86,0.0,Vector2(-0.10,0.22),{"leap_meters":0.62}); _mark(active,103,RallyEventModel.EventType.BLOCK,t,0.42,0.61,0.86,0.0,Vector2(-0.10,0.22),{"leap_meters":0.62}); _idle(active)
	if t<0.08:_flight(Vector2(0.52,0.46),3.4,receive,0.92,t/0.08,0.35)
	elif t<0.22:_flight(receive,0.92,setter,2.08,(t-0.08)/0.14,0.72)
	elif t<0.47:_flight(setter,2.08,Vector2(0.17,0.535),2.94,(t-0.22)/0.25,0.82)
	elif t<0.61:_flight(Vector2(0.17,0.535),2.94,Vector2(0.155,0.445),3.12,(t-0.47)/0.14,0.20)
	elif t<0.66:_flight(Vector2(0.155,0.445),3.12,Vector2(0.10,0.40),3.06,(t-0.61)/0.05,0.02)
	elif t<0.80:_flight(Vector2(0.10,0.40),3.06,Vector2(-0.09,0.31),0.55,(t-0.66)/0.14,0.06)
	else:_ball(Vector2(-0.09,0.31),0.55)

## Q2-Q6 compact previews retained.
func _serve(t:float,mode:String)->void:
	var c:=Vector2(0.80,1.03); _move(6,c,t,0.0,0.18)
	if mode=="controlled":_move(105,Vector2(0.50,0.20),t,0.38,0.72); _arc(c,Vector2(0.50,0.20),t/0.74,2.5)
	elif mode=="target":_move(104,Vector2(0.34,0.20),t,0.30,0.68); _move(105,Vector2(0.38,0.20),t,0.30,0.68); _arc(c,Vector2(0.36,0.20),t/0.70,3.0)
	else:_arc(c,Vector2(0.74,0.18) if t<0.5 else Vector2(1.08,0.08),t/0.46 if t<0.5 else (t-0.5)/0.42,4.3)
func _defense(t:float,mode:String)->void:
	var s:=Vector2(0.50,0.38); var target:=Vector2(0.50,0.62) if mode=="floor" else Vector2(0.58,0.77) if mode=="read" else Vector2(0.26,0.34); _arc(s,target,t,2.4)
func _transition(t:float,mode:String)->void:
	var d:=Vector2(0.72,0.82); var s:=Vector2(0.52,0.65); _move(6,d,t,0.0,0.24); _move(5,s,t,0.08,0.34); _arc(Vector2(0.24,0.42),d,t/0.24,2.3) if t<0.24 else _arc(d,s,(t-0.24)/0.15,1.7) if t<0.39 else _arc(s,Vector2(0.20,0.22) if mode=="pressure" else Vector2(0.72,0.22) if mode=="opportunity" else Vector2(0.50,0.22),(t-0.39)/0.5,2.1)
func _broken_ball(t:float,mode:String)->void:
	var r:=Vector2(0.92,0.82); var o:=Vector2(0.78,0.66); _move(6,r,t,0.0,0.22); _arc(Vector2(0.58,0.15),r,t/0.22,3.0) if t<0.22 else _arc(r,o,(t-0.22)/0.16,1.5) if t<0.38 else _arc(o,Vector2(0.48,0.22) if mode=="structure" else Vector2(0.70,0.22) if mode=="available" else Vector2(0.18,0.22),(t-0.38)/0.5,2.2)
func _construction(t:float,mode:String)->void:
	var x:=0.80 if mode=="combination" or mode=="flexible" else 0.18; _arc(Vector2(0.50,0.78),Vector2(0.50,0.58),t/0.42,2.0) if t<0.42 else _arc(Vector2(0.50,0.58),Vector2(x,0.30),(t-0.42)/0.58,3.0)
func _montage(t:float)->void:
	var count:=maxi(_montage_vignettes.size(),1); var scaled:=clampf(t,0.0,0.9999)*float(count); _draw_vignette(_montage_vignettes[mini(int(floor(scaled)),count-1)],fmod(scaled,1.0))