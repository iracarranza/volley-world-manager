extends Node

## Photograph the eight major venues as *rooms*, not as floors.
##
## The surface pass asked what a court is made of. These ask what it is like to
## play in, and almost none of it is the floor: altitude, mist, glare off a
## pillar, a resonance at the end line, a wall of sponsor screens. Those are
## light, atmosphere and a little geometry, which is why this probe exists
## separately from `court_surface_probe` rather than growing another column.
##
## **Purely visual.** Each venue below is a *look* for a modifier that is not
## designed yet and is not designed here. What this can settle is narrow and
## worth settling first: whether a venue reads as itself in one frame, from the
## camera a match is actually watched from, without a label.
##
## It depends on the exposure fix. At the old stop the floor was already clipping,
## so a deliberate glare and an accidental blow-out were the same pixels and
## Blôc's whole idea was unphotographable. 0.42 is the headroom these live in.
##
## Run:
##   xvfb-run -a godot --path . res://tools/venue_probe.tscn

const COURT := preload("res://scenes/components/match_court_3d.tscn")
const ACTOR := preload("res://scenes/components/player_actor_3d.tscn")

## The home kit each region wears, from the kit pass. Dark or near-white and
## nothing between, because a kit is seen against a terracotta floor and a
## midtone disappears into it.
const KITS := {
	"landavol": Color("35393A"), "pawa": Color("26355C"),
	"speddigh": Color("1F4E6B"), "bloc": Color("414055"),
	"xervu": Color("3A2415"), "taktika": Color("1E2124"),
	"aace": Color("0B0F14"), "ispayk": Color("0C4F52"),
}

## The visitors, in a change strip. Every home kit above is dark, so the away
## side has to be the light one or two dark teams share a floor and nobody can
## tell who touched the ball.
const AWAY_KIT := Color("E4E0D6")

## **Construction, not colour.** The kits are all dark by necessity -- a midtone
## disappears into a terracotta floor -- and making them louder to tell them
## apart would undo the contrast work that got them readable in the first place.
## So the difference is *how a kit is built*: panels, seams, bands and their
## spacing, which survive grayscale because they are value structure rather than
## hue. A viewer should be able to name the side from a black-and-white frame.
##
## `trim` is how far the marks sit from the kit in value -- lighter for most,
## since a dark kit can only be marked by something paler.
const KIT_BUILD := {
	## The template every other kit is a deviation from. Not an absence of
	## design: a placket and a collar, cleanly made, so it reads as the canonical
	## strip rather than as one nobody finished.
	"landavol": {"pattern": "reference", "trim": 0.34},
	## Compressed and repeated -- short marks, many of them, close together. The
	## same thing the region does to a rally.
	"speddigh": {"pattern": "ticks", "trim": 0.40},
	## Broad athletic panels running with the body, so the shape reads as motion
	## even standing still.
	"pawa": {"pattern": "panels", "trim": 0.30},
	## Vertical divisions, structural and evenly spaced: the kit is built like the
	## thing the region believes in.
	"bloc": {"pattern": "columns", "trim": 0.36},
	## Irregular, rhythmic accents -- uneven spacing that still keeps a beat.
	"xervu": {"pattern": "rhythm", "trim": 0.46},
	## Precise geometric seams. Thin, exact, and nothing decorative.
	"taktika": {"pattern": "seams", "trim": 0.30},
	## Immaculate and technical, and covered in the people who paid for it.
	"aace": {"pattern": "sponsored", "trim": 0.42},
	## The old strip, one broad chest band, essentially unchanged for decades.
	"ispayk": {"pattern": "heritage", "trim": 0.38},
}

## Six a side, in a legal rotation: three front at the attack line, three back.
const SLOTS: Array = [
	Vector3(-3.0, 0.0, 2.9), Vector3(0.0, 0.0, 2.6), Vector3(3.0, 0.0, 2.9),
	Vector3(-3.2, 0.0, 6.8), Vector3(0.0, 0.0, 7.2), Vector3(3.2, 0.0, 6.8),
]
const BODIES: Array = ["Feli", "Avi", "Feli", "Avi", "Feli", "Avi"]

## Court metrics, taken from the court scene rather than restated: the net is at
## the origin, the posts sit at ±4.72, and the floor is 18 x 9.
const HALF_LENGTH := 9.0
const HALF_WIDTH := 4.5

## Where the building starts. **Nothing structural may stand inside this.** The
## first pass put Blôc's pillars at z = -6.6, which is inside the free zone -- on
## the court, in play, where a voli chasing a ball would run into them. A pillar
## holds up a hall; it does not stand on the sand.
## **The axes were swapped, and it put the seating on the end line.** The net
## spans x = ±4.72, so the court is 9 m wide along X and 18 m long along Z. The
## first build ran the long-side rakes along Z at 8.2 -- which is 0.8 m past an
## end line that sits at z = 9, so the stand stood exactly where a server takes
## their run-up. Nobody could have jump served in any of these halls.
##
## FIVB competition free zone, and the end figure is the one that matters: 5 m
## from the sidelines, 8 m behind the end lines, because the run-up is what the
## end zone is *for*.
const FREE_ZONE_SIDE := 9.5
const FREE_ZONE_END := 17.0

## The camera's broadcast preset is (12.5, 8.2, 10.8), which is *inside* the
## near stand and above it -- exactly where a real broadcast camera sits. So the
## near rake may exist as long as it stays under that sightline; it is the far
## side that carries height.
const NEAR_RAKE_TOP := 2.2
const FAR_RAKE_TOP := 6.0

## What each hall is lit by, now that it has a roof to hang it from.
##
## Until now the key was a directional sun with the roof told not to cast, which
## is a stand-in and was labelled as one. A covered hall is lit by fixtures, and
## the fixtures are a characterisation in their own right: how many, how warm,
## how evenly, and how many still work.
##
## `count` is per side of the net. `spread` is how far out along the court they
## run, `warm` is the colour, `energy` per fixture, and `fail` is how many of
## them are dead -- which only Ĭspayk uses, because a hall past its best keeps
## its lamps until they go and then keeps them a while longer.
const ROOF_LIGHTS := {
	"landavol": {"count": 3, "warm": Color(1.0, 0.97, 0.92), "energy": 9.0, "fail": 0},
	"speddigh": {"count": 3, "warm": Color(0.86, 0.94, 1.0), "energy": 7.0, "fail": 0},
	"bloc": {"count": 2, "warm": Color(1.0, 0.96, 0.88), "energy": 4.0, "fail": 0},
	"xervu": {"count": 3, "warm": Color(1.0, 0.88, 0.68), "energy": 8.0, "fail": 0},
	"taktika": {"count": 4, "warm": Color(0.94, 0.98, 1.0), "energy": 8.0, "fail": 0},
	"aace": {"count": 4, "warm": Color(0.97, 0.99, 1.0), "energy": 10.0, "fail": 0},
	"ispayk": {"count": 3, "warm": Color(1.0, 0.86, 0.62), "energy": 7.5, "fail": 2},
}

## Where the scoreline lives, which is a wealth statement before it is a fixture.
##
## Most halls bolt a board to the end wall. A centre-hung cube over the net costs
## a roof strong enough to carry it and the money to buy it, so it is not a
## default -- it is three specific venues saying three different things: A'ace
## bought one last season, Blôc's hall was built to carry one, and Ĭspayk's is
## the one they hung when they could still afford to, now half-lit.
const CENTRE_HUNG := {"aace": 1.0, "bloc": 0.85, "ispayk": 0.28}

## Which floor each venue plays on, from the surface pass. Five majors keep the
## default -- a league where every floor is a statement has no statement left.
const FLOORS := {
	"taktika": {"albedo": Color(0.36, 0.44, 0.47), "rough": 0.62},
	"aace": {"albedo": Color(0.88, 0.75, 0.54), "rough": 0.18},
	"ispayk": {"albedo": Color(0.25, 0.49, 0.39), "rough": 0.88},
}

var _court: Node3D
var _env: Environment
var _key: DirectionalLight3D
var _fill: OmniLight3D
var _extras: Node3D
var _open_air := false
var _tight := false
## Set by `_arena()` and read by `_roof_lights()`, because a lamp bolted to the
## roof has to know where the roof is. It was a literal 12.4 under a literal
## 14.0 and the two were never connected, so the first small hall put its lamps
## through its own ceiling.
var _roof_h := 14.0


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	for venue in _venues():
		await _shoot(Dictionary(venue))
	get_tree().quit()


## Eight rooms. Each entry is a light change, an atmosphere change, and a hook
## that adds whatever geometry the idea needs.
func _venues() -> Array:
	return [
		{
			"id": "landavol", "label": "Landavol - the canonical room",
			## **Baseline is not blankness.** Landavol should read as the strip
			## every other hall is a deviation from -- built properly, evenly lit,
			## nothing added and nothing missing -- rather than as the one that has
			## not been decorated yet. So it gets the things a well-made ordinary
			## hall has: an exposed roof truss, a run of matching banners, and
			## light that falls the same everywhere.
			"build": func():
				_env.ambient_light_energy = 0.62
				for i in range(7):
					var truss := _box(
						Vector3(FREE_ZONE_SIDE * 2.0 + 12.0, 0.35, 0.35),
						Vector3(0.0, 13.2, -18.0 + float(i) * 6.0),
						Color(0.34, 0.35, 0.38), 0.0, 0.85
					)
					truss.name = "Truss%d" % i
				for i in range(6):
					var banner := _box(
						Vector3(0.06, 2.4, 1.1),
						Vector3(-(FREE_ZONE_SIDE + 6.1), 7.4, -13.0 + float(i) * 5.2),
						Color(0.62, 0.60, 0.54), 0.0, 0.9
					)
					banner.name = "Banner%d" % i,
		},
		{
			"id": "pawa", "label": "Pawa Hito - a terrace, and the sky", "open_air": true,
			## Thin air scatters less, so the light is harder and the shadows are
			## blacker rather than the room being brighter. Height is drawn by what
			## the light does, not by a mountain in the background.
			"build": func():
				_key.rotation_degrees = Vector3(-58.0, -42.0, 0.0)
				_key.light_energy = 3.2
				_key.light_color = Color(1.0, 0.99, 0.94)
				_fill.light_energy = 0.0
				_sky()
				_env.fog_enabled = true
				_env.fog_light_color = Color(0.62, 0.70, 0.80)
				_env.fog_density = 0.004
				_env.fog_sky_affect = 0.0
				## **The haze was set for a backdrop and the subject moved behind
				## it.** `_sky()` fades everything out by 520 m, and the water
				## only starts at 140 -- so sea, islands and stone all arrived at
				## the same pale grey and the frame had no horizon in it at all.
				## Pushed back so the near half of the view keeps its colour and
				## only the far peaks go soft, which is the job aerial perspective
				## was brought in to do.
				_env.fog_depth_begin = 110.0
				_env.fog_depth_end = 780.0
				_env.fog_aerial_perspective = 0.45,
		},
		{
			"id": "speddigh", "label": "Speddigh - a small hall, and cold air",
			"tight": true,
			## The mist is the room. Dense, cold, and sitting low so a voli standing
			## still is in it to the knee while the ball above is clear.
			"build": func():
				_key.light_energy = 0.75
				_key.light_color = Color(0.78, 0.88, 1.0)
				_fill.light_color = Color(0.70, 0.85, 1.0)
				_fill.light_energy = 2.0
				_env.ambient_light_color = Color(0.55, 0.68, 0.80)
				_env.ambient_light_energy = 0.95
				_env.fog_enabled = true
				_env.fog_light_color = Color(0.74, 0.86, 0.94)
				_env.fog_density = 0.004
				_env.fog_sky_affect = 0.0
				for layer in range(3):
					var sheet := _box(
						Vector3(26.0, 0.02, 16.0),
						Vector3(0.0, 0.28 + float(layer) * 0.30, 0.0),
						Color(0.80, 0.90, 0.98, 0.16), 0.0, 1.0
					)
					sheet.name = "Mist%d" % layer
					var material := sheet.material_override as StandardMaterial3D
					material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					material.albedo_color = Color(0.80, 0.90, 0.98, 0.16)
					material.emission_enabled = true
					material.emission = Color(0.62, 0.76, 0.88)
					material.emission_energy_multiplier = 0.30,
		},
		{
			"id": "bloc", "label": "Bloc du Larg - sun and gleaming pillars",
			## The one that needed the exposure fix. A low sun rakes across the net
			## and four polished pillars sit behind it, so the block is read against
			## bright metal rather than against a dark hall.
			"build": func():
				_key.rotation_degrees = Vector3(-14.0, -86.0, 0.0)
				_key.light_energy = 2.4
				_key.light_color = Color(1.0, 0.96, 0.84)
				_env.ambient_light_energy = 0.55
				_env.glow_enabled = true
				_env.glow_intensity = 1.6
				_env.glow_bloom = 0.55
				## Polished columns along the far wall, behind the far stand -- the
				## hall's own structure catching the sun, which is what makes the
				## block hard to read. Not on the court.
				for i in range(5):
					var pillar := _box(
						Vector3(1.0, 12.0, 1.0),
						Vector3(-(FREE_ZONE_SIDE + 5.2), 6.0, -14.0 + float(i) * 7.0),
						Color(0.95, 0.93, 0.88), 0.94, 0.08, 0.7
					)
					pillar.name = "Pillar%d" % i
				## And the windows they stand between.
				for i in range(4):
					var window := _box(
						Vector3(0.2, 7.0, 4.4),
						Vector3(-(FREE_ZONE_SIDE + 5.8), 6.4, -10.5 + float(i) * 7.0),
						Color(1.0, 0.97, 0.86), 0.0, 0.2, 2.4
					)
					window.name = "Window%d" % i,
		},
		{
			"id": "xervu", "label": "Xervu - the end line answers the serve",
			## The architecture responds at the end line, so the light lives *there*
			## rather than over the net: two warm bands under the serving zones and
			## a resonance ring on the floor behind each.
			"build": func():
				_env.ambient_light_energy = 0.42
				_env.glow_enabled = true
				_env.glow_intensity = 0.9
				for side in [-1.0, 1.0]:
					var band := _box(
						Vector3(9.4, 0.02, 0.5),
						Vector3(0.0, 0.02, side * (HALF_LENGTH + 0.9)),
						Color(1.0, 0.72, 0.26), 0.0, 1.0, 2.6
					)
					band.name = "Resonance%d" % int(side)
					for ring in range(3):
						var arc := _box(
							Vector3(6.0 - float(ring) * 1.6, 0.02, 0.10),
							Vector3(0.0, 0.02, side * (HALF_LENGTH + 1.9 + float(ring) * 0.75)),
							Color(1.0, 0.62, 0.20), 0.0, 1.0, 1.4 - float(ring) * 0.35
						)
						arc.name = "Ring%d_%d" % [int(side), ring],
		},
		{
			"id": "taktika", "label": "Taktika - the room that is watching",
			## Flat, even, shadowless: nothing here should feel like weather. The
			## only mark is a fine grid on the floor, which is the room treating the
			## court as a diagram.
			"build": func():
				_key.light_energy = 0.9
				_key.light_color = Color(0.94, 0.97, 1.0)
				_fill.light_energy = 1.0
				_env.ambient_light_color = Color(0.70, 0.76, 0.80)
				_env.ambient_light_energy = 1.05
				for i in range(-4, 5):
					var line := _box(
						Vector3(0.03, 0.02, HALF_LENGTH * 2.0),
						Vector3(float(i) * 1.0, 0.012, 0.0),
						Color(0.80, 0.86, 0.88), 0.0, 1.0, 0.25
					)
					line.name = "Grid%d" % i,
		},
		{
			"id": "aace", "label": "A'ace - sponsors and bettors, watching",
			## A wall of screens on both sides and a ring of cold light above. The
			## room is instrumented, and the volis are the instrument.
			"build": func():
				_env.ambient_light_color = Color(0.62, 0.68, 0.82)
				_env.ambient_light_energy = 0.6
				_env.glow_enabled = true
				_env.glow_intensity = 1.3
				var tints := [
					Color(0.20, 0.85, 0.95), Color(0.95, 0.30, 0.55),
					Color(0.30, 0.95, 0.55), Color(0.98, 0.78, 0.20),
				]
				## Screens on the mezzanine fascia, and camera pods slung under it.
				## The room is instrumented from the deck, not from the floor.
				for i in range(5):
					var screen := _box(
						Vector3(0.14, 2.2, 5.0),
						Vector3(-(FREE_ZONE_SIDE + 3.7), 6.6, -14.0 + float(i) * 7.0),
						Color(tints[i % 4]), 0.0, 1.0, 2.3
					)
					screen.name = "Screen%d" % i
					var pod := _box(
						Vector3(0.5, 0.5, 0.9),
						Vector3(-(FREE_ZONE_SIDE + 3.1), 7.4, -14.0 + float(i) * 7.0),
						Color(0.86, 0.92, 0.98), 0.7, 0.25, 0.6
					)
					pod.name = "Pod%d" % i,
		},
		{
			"id": "ispayk", "label": "Ispayk - hallowed, and past it",
			## Grand and dim. High warm light from far above, banners down the long
			## walls, and nothing new in the room -- the pride and the poverty being
			## the same fact, which is how `GEOGRAPHY.md` already puts it.
			"build": func():
				_key.rotation_degrees = Vector3(-78.0, -20.0, 0.0)
				_key.light_energy = 1.0
				_key.light_color = Color(1.0, 0.90, 0.72)
				_fill.light_color = Color(1.0, 0.82, 0.58)
				_fill.light_energy = 3.0
				_env.ambient_light_color = Color(0.42, 0.36, 0.30)
				_env.ambient_light_energy = 0.5
				_env.fog_enabled = true
				_env.fog_light_color = Color(0.52, 0.44, 0.34)
				_env.fog_density = 0.012
				_env.fog_sky_affect = 0.0
				## Hung down the far wall above the stand, the way a hall keeps its
				## history: high, dusty and slightly too many.
				for i in range(7):
					var banner := _box(
						Vector3(0.06, 4.2, 1.3),
						Vector3(-(FREE_ZONE_SIDE + 5.5), 7.2, -15.0 + float(i) * 5.0),
						Color(0.55, 0.20, 0.18), 0.0, 0.9, 0.22
					)
					banner.name = "Banner%d" % i,
		},
	]


func _shoot(venue: Dictionary) -> void:
	_court = COURT.instantiate()
	add_child(_court)
	await get_tree().process_frame
	_key = _court.get_node("KeyLight") as DirectionalLight3D
	_fill = _court.get_node("FillLight") as OmniLight3D
	## The environment is a shared sub-resource, so it must be duplicated or every
	## venue after the first inherits the one before it -- which is exactly the
	## bug that made the first run of this look like a single foggy room eight
	## times.
	var holder := _court.get_node("WorldEnvironment") as WorldEnvironment
	_env = holder.environment.duplicate() as Environment
	holder.environment = _env
	_extras = Node3D.new()
	_extras.name = "VenueExtras"
	_court.add_child(_extras)
	_open_air = bool(venue.get("open_air", false))
	_tight = bool(venue.get("tight", false))
	_arena()
	_roof_lights(str(venue.get("id", "")))
	_fixtures(str(venue.get("id", "")))
	_floor_for(str(venue.get("id", "")))
	_volis(str(venue.get("id", "")))
	var build: Callable = venue.get("build", func(): pass)
	build.call()
	_frame_broadcast()
	await get_tree().process_frame
	await get_tree().process_frame
	var path := "user://venue_%s.png" % str(venue.get("id", "x"))
	get_tree().root.get_texture().get_image().save_png(path)
	print("saved %s  (%s)" % [ProjectSettings.globalize_path(path), venue.get("label", "")])
	await _closeup(str(venue.get("id", "x")))
	if _open_air:
		await _establishing(str(venue.get("id", "x")))
	_court.queue_free()
	await get_tree().process_frame


## The building every venue shares: a raked bowl outside the free zone, the
## columns that hold the roof up, and a mezzanine over the far side.
##
## This exists because the first pass dressed the *court* -- pillars and screens
## standing in the playing area -- when what these venues are about is the room
## around it. Stands, columns and a mezzanine are where a crowd, a roof and a
## sponsor's camera actually go, and putting them outside the free zone is not a
## detail: it is the difference between a hall and an obstacle course.
func _arena() -> void:
	var concrete := Color(0.30, 0.31, 0.34)
	var seat := Color(0.24, 0.27, 0.32)
	## **A small hall is short and low, not narrow.** The first attempt at
	## Spëddigh dropped the roof to 8.6 m and pulled every wall in 4.2 m, and the
	## frame came back as an empty grey gradient: the broadcast camera's eye is at
	## y = 9.0 and x = 15.5, so an 8.6 m roof renders *from above*, and a side wall
	## at x = 11.7 puts the camera outside its own building. §0 again -- a knob
	## that cannot reach its own stated range, and fails silently when it tries.
	##
	## The camera fixes the two dimensions it stands in. Compactness therefore has
	## to come from the ones it does not: a lid low enough to see is low, the ends
	## come in, and the stands behind the service zone shrink with them.
	_roof_h = 11.5 if _tight else 14.0
	var end_inset: float = 2.6 if _tight else 0.0
	## Long sides. Each step rises and retreats, so the rake reads as seating
	## rather than as a wall -- and the near side stops under the camera.
	for side in [-1.0, 1.0]:
		## Typed explicitly: `side` comes from an untyped array literal, so `:=` on a
		## comparison against it has nothing to infer from and the whole script fails
		## to parse -- silently, as an idle process that renders nothing.
		var far: bool = side < 0.0
		## **An open terrace does not wall off its own view.** Pāwa's altitude kept
		## failing from the broadcast seat and the islands were only half the
		## reason: a 6 m far rake sits exactly across the sightline, so whatever
		## was beyond it could not have been seen at any distance. A cliff-top
		## court has a low rail on the seaward side, because the drop is the thing
		## people came for. Two steps and a metre, and the horizon is in frame.
		var open_far: bool = far and _open_air
		var steps: int = 2 if open_far else (6 if far else 3)
		var top: float = 1.0 if open_far else (FAR_RAKE_TOP if far else NEAR_RAKE_TOP)
		for i in range(steps):
			var t := float(i) / float(steps - 1)
			var step := _box(
				Vector3(1.3, 0.5, FREE_ZONE_END * 2.0 + 4.0 - end_inset * 2.0),
				Vector3(side * (FREE_ZONE_SIDE + 0.9 + float(i) * 1.25), 0.35 + t * top, 0.0),
				seat if i % 2 == 0 else concrete, 0.0, 0.95
			)
			step.name = "Rake%d_%d" % [int(side), i]
	## Ends, lower and shallower: an end stand behind the service zone. A tight
	## hall gets two rows rather than four, because four would stand through the
	## end wall that just came in 2.6 m.
	var end_steps: int = 2 if _tight else 4
	for end in [-1.0, 1.0]:
		for i in range(end_steps):
			var t := float(i) / float(end_steps - 1)
			var step := _box(
				Vector3(FREE_ZONE_SIDE * 2.0 + 6.0, 0.5, 1.4),
				Vector3(0.0, 0.35 + t * 3.2, end * (FREE_ZONE_END + 1.0 + float(i) * 1.35)),
				seat if i % 2 == 0 else concrete, 0.0, 0.95
			)
			step.name = "End%d_%d" % [int(end), i]
	## The columns that hold the roof, at the corners of the building and well
	## outside anything anybody plays in. An open terrace has no roof, so it has
	## no columns -- four posts holding up the sky is worse than none.
	if _open_air:
		_terrace()
		return
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var column := _box(
				Vector3(0.8, _roof_h - 1.0, 0.8),
				Vector3(sx * (FREE_ZONE_SIDE + 4.6), (_roof_h - 1.0) * 0.5,
					sz * (FREE_ZONE_END + 5.6 - end_inset)),
				Color(0.42, 0.43, 0.45), 0.0, 0.85
			)
			column.name = "Column%d_%d" % [int(sx), int(sz)]
	## A mezzanine over the far rake -- the deck a camera or a sponsor hangs off.
	## **The hall has to be enclosed.** Without walls and a roof the seating reads
	## as open scaffolding, and the end board hangs in mid-air because there is
	## nothing behind it -- which is what the first two passes looked like. These
	## are the surfaces every venue's own light then plays on: Blôc's windows cut
	## into one, Ĭspayk's banners hang down another.
	## **A hall's size is a culture, not a dimension.** Spëddigh's mist was
	## reading as climate when the region's identity is compactness and tempo --
	## towns wedged between water and rock with nowhere to sprawl. So its hall is
	## genuinely small, within what the camera allows: see the note at the top.
	_walls(_roof_h, end_inset)
	var deck := _box(
		Vector3(3.2, 0.45, FREE_ZONE_END * 2.0 + 6.0 - end_inset * 2.0),
		Vector3(-(FREE_ZONE_SIDE + 5.4), _roof_h - 6.2, 0.0),
		Color(0.26, 0.27, 0.30), 0.0, 0.9
	)
	deck.name = "Mezzanine"


## A real sky, with a horizon in it.
##
## A flat background colour has no horizon, and a horizon is the one line that
## says where the ground stops -- without it a terrace with sky beyond reads as a
## slab in a void, which is what every previous pass of this venue looked like.
## `ProceduralSkyMaterial` gives the gradient *and* the ground half, so the land
## meets something instead of ending.
##
## Depth fog does the other half. Distant land at full saturation sits in the
## same plane as near land; fading it with distance is the cue that tells a
## viewer the ridge is far away and therefore large, which is the whole reason
## the ridge is there. `fog_sky_affect` stays low so the sky itself is not washed
## out along with it.
func _sky() -> void:
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color(0.26, 0.46, 0.76)
	material.sky_horizon_color = Color(0.78, 0.87, 0.94)
	material.sky_curve = 0.14
	## The ground half is the haze *below* the horizon seen from height, not soil:
	## at 0.20 it rendered as a black void under the ridge and the whole frame went
	## murky. It should read as distance, so it is pale and only slightly cooler
	## than the sky it meets.
	material.ground_bottom_color = Color(0.46, 0.47, 0.50)
	material.ground_horizon_color = Color(0.74, 0.79, 0.83)
	material.ground_curve = 0.05
	material.sun_angle_max = 18.0
	material.energy_multiplier = 1.0
	var sky := Sky.new()
	sky.sky_material = material
	_env.sky = sky
	_env.background_mode = Environment.BG_SKY
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_energy = 1.05
	_env.fog_enabled = true
	_env.fog_mode = Environment.FOG_MODE_DEPTH
	_env.fog_light_color = Color(0.70, 0.80, 0.90)
	_env.fog_density = 0.0
	_env.fog_depth_begin = 60.0
	_env.fog_depth_end = 520.0
	_env.fog_depth_curve = 0.7
	_env.fog_sky_affect = 0.08
	_env.fog_aerial_perspective = 0.4


## Pāwa Hitō plays outside.
##
## `GEOGRAPHY.md` has the region as terraced volcanic hillside where everything
## is uphill, so a court there is cut into a terrace rather than roofed over. It
## is also the answer to the venue that would not read: thin hard light and a
## black shadow are subtle indoors, competing with a lit room, and obvious under
## an open sky where nothing else is lighting the floor. The problem was never
## that the effect was too weak -- it was in the wrong building.
func _terrace() -> void:
	for sx in [-1.0, 1.0]:
		var rail := _box(
			Vector3(0.5, 1.15, FREE_ZONE_END * 2.0 + 12.0),
			Vector3(sx * (FREE_ZONE_SIDE + 6.4), 0.6, 0.0),
			Color(0.36, 0.31, 0.27), 0.0, 0.95
		)
		rail.name = "Parapet%d" % int(sx)
	for sz in [-1.0, 1.0]:
		var rail := _box(
			Vector3(FREE_ZONE_SIDE * 2.0 + 13.0, 1.15, 0.5),
			Vector3(0.0, 0.6, sz * (FREE_ZONE_END + 6.2)),
			Color(0.36, 0.31, 0.27), 0.0, 0.95
		)
		rail.name = "ParapetEnd%d" % int(sz)
	## The ground it stands on, so the court reads as cut into something rather
	## than floating in a blue void.
	var terrace := _box(
		Vector3(FREE_ZONE_SIDE * 2.0 + 26.0, 3.0, FREE_ZONE_END * 2.0 + 24.0),
		Vector3(0.0, -1.6, 0.0), Color(0.29, 0.24, 0.21), 0.0, 0.98
	)
	terrace.name = "Terrace"
	## Lower terraces stepping away down the hillside, then the water. Without
	## these the court is a slab in a blue void, which is not the same thing as
	## being high up -- height only reads when something else is visibly below.
	## **These were what hid the sea.** Each step was widened as it went down, so
	## by the fifth the apron reached x = -158 -- and a ray from the broadcast
	## camera grazing the parapet does not fall to the water until x = -130. The
	## hillside was standing in front of the thing it was there to give scale to.
	## Volcanic terracing drops; it does not fan out. Narrow steps, stepping
	## seaward and down, finished by x = -72, which puts water in the sightline.
	for i in range(5):
		var step := _box(
			Vector3(30.0, 3.4, FREE_ZONE_END * 2.0 + 30.0 - float(i) * 4.0),
			Vector3(-24.0 - float(i) * 11.0, -5.0 - float(i) * 4.8, 0.0),
			Color(0.26, 0.21, 0.18).lightened(float(i) * 0.06), 0.0, 0.98
		)
		step.name = "Hillside%d" % i
	var sea := _box(
		Vector3(900.0, 0.6, 900.0), Vector3(-120.0, -26.0, 0.0),
		Color(0.16, 0.34, 0.46), 0.0, 0.28
	)
	sea.name = "Sea"
	## **Peaks, because the drop is not a frame of reference.** A court on a
	## terrace with sky beyond it reads as a court in space: nothing in frame has
	## a known size, so nothing says how high up this is. Land *above* the horizon
	## fixes what land below cannot -- a ridge is visible from any camera,
	## including the match one, and a viewer knows roughly how big a mountain is.
	##
	## **And they have to be on the side the camera faces.** These sat at
	## x = +150 and beyond, which is *behind* the broadcast seat -- so the one
	## thing in this venue that could survive the sightline was pointed away from
	## the only frame that mattered. Moved across, spread along the coast, and
	## tall enough that their tops clear the horizon rather than the parapet.
	for i in range(6):
		var peak := _box(
			Vector3(64.0 + float(i % 3) * 30.0, 78.0 + float(i % 4) * 34.0,
				64.0 + float(i % 2) * 26.0),
			Vector3(-470.0 - float(i % 3) * 130.0, 4.0 + float(i % 4) * 16.0,
				-460.0 + float(i) * 180.0),
			Color(0.30, 0.33, 0.40).lightened(float(i) * 0.05), 0.0, 1.0
		)
		peak.name = "Peak%d" % i
		peak.rotation.y = 0.6 + float(i) * 0.4
	## **Islands across the water, on the open side.** The inland ridge is behind
	## the broadcast camera and does nothing for the frame a match is actually
	## watched in -- which is why altitude still did not read. An archipelago has
	## other islands in view, and put across the drop they sit above the open far
	## side exactly where the camera is already looking. Height reads because
	## their bases are hidden below the horizon and only their tops show.
	## **Islands across the water, and the reason four passes of them were
	## invisible.** They were moved to 70 m, 120 m and 200 m in turn and none of
	## it ever reached a pixel, which was read each time as an occlusion problem
	## and answered with more geometry. It was not: `match_court_3d.tscn` sets the
	## camera's `far` to **80 m**, so the sea at 140 m, the islands and the peaks
	## were all being clipped by the frustum before anything could occlude them.
	## The one island that ever showed up sat at 72 m -- inside the plane, which
	## is the whole reason it looked like a cliff face rather than an island.
	## §0 exactly: the knob could not reach its own stated range, and every
	## measurement taken through it was of the wrong thing. `_venue_camera()`
	## opens the plane now.
	for i in range(4):
		var island := _box(
			Vector3(52.0 + float(i % 3) * 30.0, 26.0 + float(i % 3) * 14.0,
				46.0 + float(i % 2) * 28.0),
			Vector3(-290.0 - float(i % 2) * 90.0, -14.0 + float(i % 3) * 4.0,
				-150.0 + float(i) * 128.0),
			Color(0.26, 0.31, 0.40).lightened(float(i) * 0.06), 0.0, 1.0
		)
		island.name = "Island%d" % i
		island.rotation.y = 0.3 + float(i) * 0.5
	## And the shoulder this court is cut into, running up behind the near stand,
	## so the terrace is part of a hillside rather than a table in the air.
	var shoulder := _box(
		Vector3(70.0, 46.0, 150.0),
		Vector3(FREE_ZONE_SIDE + 44.0, 17.0, -20.0),
		Color(0.27, 0.23, 0.20), 0.0, 0.99
	)
	shoulder.name = "Shoulder"
	## A coastline: two headlands running out into it, so the water reads as a
	## shore seen from above rather than as a blue floor.
	for i in range(2):
		var headland := _box(
			Vector3(46.0, 7.0, 120.0 + float(i) * 90.0),
			Vector3(-120.0 - float(i) * 60.0, -23.5, -150.0 + float(i) * 320.0),
			Color(0.22, 0.20, 0.19), 0.0, 0.98
		)
		headland.name = "Headland%d" % i


## Walls and a roof, and neither of them casts.
##
## Enclosing the hall put a lid over a directional key, and a sun does not reach
## into a closed building -- six of eight venues went black the moment the roof
## appeared. With real fixtures overhead the key is only standing in for a
## lantern, so the shell stays out of its way.
func _walls(wall_h: float, end_inset: float) -> void:
	## The long walls never move. They sit at x = ±15.9 and the broadcast camera
	## stands at x = 15.5, so a side wall pulled in by any amount at all puts the
	## camera outside the building and the frame goes empty.
	for sz in [-1.0, 1.0]:
		var wall := _box(
			Vector3(0.4, wall_h, FREE_ZONE_END * 2.0 + 12.0 - end_inset * 2.0),
			Vector3(sz * (FREE_ZONE_SIDE + 6.4), wall_h * 0.5, 0.0),
			Color(0.23, 0.24, 0.27), 0.0, 0.92
		)
		wall.name = "WallLong%d" % int(sz)
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for sx in [-1.0, 1.0]:
		var wall := _box(
			Vector3(FREE_ZONE_SIDE * 2.0 + 13.0, wall_h, 0.4),
			Vector3(0.0, wall_h * 0.5, sx * (FREE_ZONE_END + 6.2 - end_inset)),
			Color(0.21, 0.22, 0.25), 0.0, 0.92
		)
		wall.name = "WallEnd%d" % int(sx)
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var roof := _box(
		Vector3(FREE_ZONE_SIDE * 2.0 + 13.0, 0.5, FREE_ZONE_END * 2.0 + 12.0 - end_inset * 2.0),
		Vector3(0.0, wall_h, 0.0),
		Color(0.17, 0.18, 0.21), 0.0, 0.95
	)
	roof.name = "Roof"
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Hang the hall's lamps, and stop pretending a sun gets in.
##
## An open-air venue gets none: it is lit by the sky, which is the whole point of
## being outside. Everywhere else the directional key drops to a fraction of its
## old energy -- it stands in for a roof lantern now rather than for the sun --
## and the fixtures do the work.
func _roof_lights(id: String) -> void:
	if _open_air:
		return
	var spec: Dictionary = ROOF_LIGHTS.get(id, ROOF_LIGHTS["landavol"])
	var count := int(spec.get("count", 3))
	var failed := int(spec.get("fail", 0))
	var placed := 0
	## Hung below the roof rather than at a fixed 12.4, which was under the
	## default 14.0 lid and above every lower one.
	var hang := _roof_h - 1.6
	for side in [-1.0, 1.0]:
		for i in range(count):
			placed += 1
			var housing := _box(
				Vector3(2.6, 0.3, 1.4),
				Vector3(0.0, hang, side * (2.6 + float(i) * 5.2)),
				Color(0.20, 0.21, 0.24), 0.0, 0.85
			)
			housing.name = "Housing%d_%d" % [int(side), i]
			housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			## A dead lamp is dark housing, not a missing one -- the fitting is
			## still bolted to the roof.
			if placed <= failed:
				continue
			var lamp := OmniLight3D.new()
			lamp.name = "RoofLight%d_%d" % [int(side), i]
			lamp.position = Vector3(0.0, hang - 0.4, side * (2.6 + float(i) * 5.2))
			lamp.light_color = Color(spec.get("warm", Color.WHITE))
			lamp.light_energy = float(spec.get("energy", 8.0))
			lamp.omni_range = 22.0
			lamp.shadow_enabled = false
			_extras.add_child(lamp)
			var lens := _box(
				Vector3(2.2, 0.08, 1.0),
				Vector3(0.0, hang - 0.18, side * (2.6 + float(i) * 5.2)),
				Color(spec.get("warm", Color.WHITE)), 0.0, 1.0, 1.6
			)
			lens.name = "Lens%d_%d" % [int(side), i]
			lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	## The key is no longer the light in the room; it is what comes through a
	## lantern or a high window, so it drops back and lets the fixtures lead.
	_key.light_energy *= 0.45


## The things every professional court has and none of these had: somewhere for
## the fourteen people not on court to sit, somewhere to warm up, and a scoreline.
##
## Benches and the scorer's table go on the far sideline, outside the free zone
## and in front of the rake -- which is where they are in a real hall, and also
## the only side that does not stand between the broadcast camera and the match.
##
## A venue may opt out. **Bompaçao is the case this is built for**: a concrete
## slab with no net posts worth the name does not have a scorer's table, and
## giving it one to be consistent would delete the thing its tagline is about.
## Nothing in the majors opts out yet.
func _fixtures(id: String) -> void:
	var bench_x := -(FREE_ZONE_SIDE + 0.5)
	## Two benches flanking the officials, the way the sideline is actually laid
	## out -- reserves on each side of the table rather than in one long row.
	for side in [-1.0, 1.0]:
		var bench := _box(
			Vector3(0.9, 0.45, 6.4), Vector3(bench_x, 0.45, side * 5.6),
			Color(0.22, 0.25, 0.30), 0.0, 0.9
		)
		bench.name = "Bench%d" % int(side)
		var back := _box(
			Vector3(0.12, 0.7, 6.4), Vector3(bench_x - 0.42, 0.9, side * 5.6),
			Color(0.18, 0.21, 0.26), 0.0, 0.9
		)
		back.name = "BenchBack%d" % int(side)
	var table := _box(
		Vector3(1.0, 0.75, 3.0), Vector3(bench_x, 0.42, 0.0),
		Color(0.30, 0.28, 0.24), 0.0, 0.85
	)
	table.name = "ScorerTable"
	## Warm-up zones behind each end, outside the free zone, painted rather than
	## built -- they are a marking on the floor, not furniture.
	for end in [-1.0, 1.0]:
		var zone := _box(
			Vector3(5.6, 0.02, 2.4),
			Vector3(0.0, 0.012, end * (HALF_LENGTH + 4.6)),
			Color(0.34, 0.30, 0.26), 0.0, 1.0
		)
		zone.name = "WarmUp%d" % int(end)
	var hung := float(CENTRE_HUNG.get(id, 0.0))
	if hung <= 0.0 and _open_air:
		## **An open-air board needs something to stand on.** There is no end wall
		## on a terrace, so the first version hung in mid-air behind the court --
		## a scoreboard floating over a mountainside.
		for sx in [-1.0, 1.0]:
			var leg := _box(
				Vector3(0.35, 6.4, 0.35),
				Vector3(sx * 2.6, 3.2, -(FREE_ZONE_END + 4.2)),
				Color(0.34, 0.30, 0.27), 0.0, 0.9
			)
			leg.name = "BoardLeg%d" % int(sx)
		var frame := _box(
			Vector3(6.0, 2.4, 0.3), Vector3(0.0, 7.0, -(FREE_ZONE_END + 4.2)),
			Color(0.16, 0.17, 0.19), 0.0, 0.9
		)
		frame.name = "GantryBoard"
		var face := _box(
			Vector3(4.6, 1.4, 0.12), Vector3(0.0, 7.0, -(FREE_ZONE_END + 4.05)),
			Color(0.95, 0.78, 0.30), 0.0, 1.0, 1.5
		)
		face.name = "GantryBoardFace"
		return
	if hung <= 0.0:
		## The ordinary case: a board on the end wall, above the end stand.
		var board := _box(
			Vector3(5.4, 2.2, 0.25),
			Vector3(0.0, 5.4, -(FREE_ZONE_END + 5.4)),
			Color(0.10, 0.13, 0.16), 0.0, 0.9
		)
		board.name = "WallScoreboard"
		var lit := _box(
			Vector3(4.2, 1.3, 0.10),
			Vector3(0.0, 5.4, -(FREE_ZONE_END + 5.25)),
			Color(0.95, 0.78, 0.30), 0.0, 1.0, 1.5
		)
		lit.name = "WallScoreboardFace"
		return
	## A cube over the net, four faces, hung from the roof it needs.
	var rig := _box(
		Vector3(0.18, 2.4, 0.18), Vector3(0.0, 11.0, 0.0),
		Color(0.30, 0.31, 0.34), 0.0, 0.8
	)
	rig.name = "ScoreboardRig"
	for face in range(4):
		var along_x: bool = face % 2 == 0
		var offset: float = 1.65 if face < 2 else -1.65
		var panel := _box(
			Vector3(0.14 if not along_x else 3.2, 2.0, 3.2 if not along_x else 0.14),
			Vector3(offset if not along_x else 0.0, 9.4, 0.0 if not along_x else offset),
			Color(0.96, 0.80, 0.34), 0.0, 1.0, 2.2 * hung
		)
		panel.name = "HungFace%d" % face


## Twelve volis, so a hall is judged with people standing in it.
##
## A room drawn empty is judged on its architecture; a room with bodies in it is
## judged on whether you can see them, which is the only question a venue has to
## answer. It is also the first time the kit palette and the court palette are in
## the same frame -- the two were designed a day apart against different grounds.
func _volis(id: String) -> void:
	var home: Color = Color(KITS.get(id, KITS["landavol"]))
	for side in [1.0, -1.0]:
		var kit := home if side > 0.0 else AWAY_KIT
		for i in range(SLOTS.size()):
			var slot: Vector3 = SLOTS[i]
			var actor := ACTOR.instantiate()
			_court.add_child(actor)
			actor.position = Vector3(slot.x * side, 0.0, slot.z * side)
			## Both sides face the net, which is the only orientation that reads
			## as volleyball rather than as a queue.
			actor.rotation.y = 0.0 if side > 0.0 else PI
			actor.configure(
				int(side) * 100 + i, side > 0.0, "",
				"Right", {"body_type": str(BODIES[i])}
			)
			_wear(actor, kit)
			_build_kit(actor, id if side > 0.0 else "", kit)
			## A still frame is not a live match: the name plate and the cogniticon
			## are readouts for a rally in progress, and in a photograph they are
			## twelve floating rectangles.
			_hide_readouts(actor)


## Aim the broadcast seat, which until now was whatever the scene shipped with.
##
## **This is where the Pāwa backdrop actually died, four passes running.** Each
## pass moved sea, islands and headlands around and re-rendered, and each time
## the frame came back empty -- because the far plane was only ever raised inside
## `_closeup`, and the *broadcast* capture ran against a freshly instantiated
## court still carrying the scene's 80 m. Every measurement of "is the backdrop
## visible" was taken through a camera that could not see 80 m, and the answer
## was recorded as a fact about the geometry.
##
## The pitch is the second half of it, and it is not a bug. Indoors the camera
## looks down at the floor 19 m away, which puts the top edge of the frame
## almost exactly on the horizon -- correct for a hall, where there is nothing
## above the horizon to see. An open-air venue is the one case where there is,
## so its camera lifts and levels off until a band of ridge and sky is in shot.
## A broadcaster on a cliff top would frame it that way for the same reason.
func _frame_broadcast() -> void:
	var camera := _venue_camera()
	if camera == null:
		return
	if _open_air:
		camera.position = Vector3(16.5, 8.4, 10.4)
		camera.fov = 50.0
		camera.look_at(Vector3(-1.5, 4.0, 0.0), Vector3.UP)
	else:
		camera.position = Vector3(15.5, 9.0, 9.5)
		camera.fov = 46.0
		camera.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)


## The court camera, with its horizon opened.
##
## **`far` is 80 m in `match_court_3d.tscn`, and that is correct for the scene it
## is in** -- an indoor hall has nothing 80 m away and the plane is free
## performance. It is wrong for the one venue that plays outdoors, and it cost
## four passes of Pāwa backdrop work: sea, islands and headlands were all built,
## all lit, and all clipped before they were drawn. Set in one place because the
## probe moves this camera three times and setting it at two of them would have
## produced the same bug with a smaller footprint.
func _venue_camera() -> Camera3D:
	var camera := _court.get_node_or_null("Camera3D") as Camera3D
	if camera != null:
		camera.far = 1400.0
	return camera


## A closeup at play level, because a venue is finally judged on whether a body
## reads in it -- kit against floor, and a shadow that says where they stand.
func _closeup(id: String) -> void:
	var camera := _venue_camera()
	if camera == null:
		return
	camera.position = Vector3(11.5, 3.4, 7.2)
	camera.fov = 44.0
	camera.look_at(Vector3(-0.5, 1.5, 1.0), Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	var path := "user://venue_%s_close.png" % id
	get_tree().root.get_texture().get_image().save_png(path)
	print("saved %s  (closeup)" % ProjectSettings.globalize_path(path))
	## Put the camera back, so an establishing shot starts from a known place
	## rather than from wherever the last frame left it.
	camera.position = Vector3(15.5, 9.0, 9.5)
	camera.fov = 46.0
	camera.look_at(Vector3(0.0, 0.85, 0.0), Vector3.UP)
	await get_tree().process_frame


## A second frame for an open-air venue, from far enough out to see what it
## stands on.
##
## **The match camera cannot show this and no amount of terrain will fix that.**
## Broadcast sits 9 m up looking slightly down at a court 19 m away, so the
## terrace edge occludes everything below it -- you cannot see a drop from a
## camera framed on the floor you are standing on. Height is not a property of
## the court; it is a property of the approach to it, and it needs a shot that
## includes the ground falling away.
func _establishing(id: String) -> void:
	var camera := _venue_camera()
	if camera == null:
		return
	## Framed rather than guessed: at 48 degrees an 18 m court fills about 40%
	## of frame height from 55 m, so the camera stands off the side at that
	## distance -- inland and its ridge to one side of frame, the drop and the
	## water to the other, court between them. Two earlier attempts put the
	## camera inside the hillside and then 140 m away looking at sky.
	camera.position = Vector3(-4.0, 21.0, 57.0)
	camera.fov = 48.0
	## Aimed below and beyond the court, not at it: the subject of this frame is
	## the hillside, and the court is the thing perched on top of it.
	camera.look_at(Vector3(2.0, -2.0, 0.0), Vector3.UP)
	await get_tree().process_frame
	await get_tree().process_frame
	var path := "user://venue_%s_wide.png" % id
	get_tree().root.get_texture().get_image().save_png(path)
	print("saved %s  (establishing)" % ProjectSettings.globalize_path(path))


## Put the region's construction on the shirt.
##
## Marks are children of the torso so they move with it, sitting a few
## millimetres proud of the chest. Away sides get nothing for now -- the cream
## change strip is deliberately universal, and the brief is to keep it that way
## until each region's construction can be carried in dark trim on it.
func _build_kit(actor: Node, id: String, kit: Color) -> void:
	if id.is_empty():
		return
	var torso := actor.get_node_or_null("BodyPivot/Torso") as MeshInstance3D
	if torso == null:
		return
	var spec: Dictionary = KIT_BUILD.get(id, KIT_BUILD["landavol"])
	var trim: Color = kit.lightened(float(spec.get("trim", 0.35)))
	var pattern := str(spec.get("pattern", "reference"))
	## Torso-local, in metres: the chest is roughly 0.42 across and 0.5 tall.
	var marks: Array = []
	match pattern:
		"reference":
			marks = [[Vector3(0.035, 0.34, 0.01), Vector3(0.0, 0.02, 0.115)],
				[Vector3(0.30, 0.035, 0.01), Vector3(0.0, 0.20, 0.108)]]
		"ticks":
			for row in range(4):
				for col in [-1.0, 1.0]:
					marks.append([Vector3(0.10, 0.026, 0.01),
						Vector3(col * 0.10, 0.16 - float(row) * 0.085, 0.112)])
		"panels":
			marks = [[Vector3(0.15, 0.46, 0.012), Vector3(-0.12, 0.0, 0.112)],
				[Vector3(0.15, 0.46, 0.012), Vector3(0.12, 0.0, 0.112)]]
		"columns":
			for col in range(3):
				marks.append([Vector3(0.045, 0.50, 0.011),
					Vector3(-0.13 + float(col) * 0.13, 0.0, 0.112)])
		"rhythm":
			var beat := [0.20, 0.09, 0.15, 0.05, 0.13]
			var y := 0.22
			for i in range(beat.size()):
				marks.append([Vector3(0.26, 0.03, 0.011), Vector3(0.0, y, 0.112)])
				y -= float(beat[i])
		"seams":
			marks = [[Vector3(0.34, 0.014, 0.01), Vector3(0.0, 0.12, 0.112)],
				[Vector3(0.34, 0.014, 0.01), Vector3(0.0, -0.10, 0.112)],
				[Vector3(0.014, 0.44, 0.01), Vector3(0.0, 0.0, 0.112)]]
		"sponsored":
			marks = [[Vector3(0.30, 0.075, 0.012), Vector3(0.0, 0.17, 0.112)],
				[Vector3(0.12, 0.055, 0.012), Vector3(-0.10, 0.02, 0.112)],
				[Vector3(0.12, 0.055, 0.012), Vector3(0.10, 0.02, 0.112)],
				[Vector3(0.24, 0.045, 0.012), Vector3(0.0, -0.13, 0.112)]]
		"heritage":
			marks = [[Vector3(0.40, 0.13, 0.013), Vector3(0.0, 0.09, 0.112)]]
	## **Both sides of the shirt.** These sat at z = +0.112 only, which is the
	## chest -- and the closeup camera stands behind the home side, so the one
	## frame built to judge the construction language was showing twelve unmarked
	## backs. A kit carries its panels and seams round the body; so does this.
	for mark in marks:
		for face in [1.0, -1.0]:
			var size: Vector3 = mark[0]
			var at: Vector3 = mark[1]
			var mesh := BoxMesh.new()
			mesh.size = size
			var node := MeshInstance3D.new()
			node.mesh = mesh
			node.position = Vector3(at.x * face, at.y, at.z * face)
			var material := StandardMaterial3D.new()
			material.albedo_color = trim
			material.roughness = 0.8
			node.material_override = material
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			torso.add_child(node)


## Hide the readouts -- the name plate and the focus ring, which belong to a live
## rally rather than to a photograph.
##
## **The flat panels on each voli are not readouts and must stay.** They are
## `WingLeft` and `WingRight` -- 0.75 x 0.35 plates parented to the arms of every
## `Avi` body, which is why exactly half the twelve have them and why they are
## skin-coloured rather than kit-coloured. Three separate passes have read them
## as floating debug quads or as a kit bug and gone looking for the code that
## draws them; there isn't any, they are the voli.
func _hide_readouts(node: Node) -> void:
	for child in node.get_children():
		if child is Label3D or child is Sprite3D:
			(child as Node3D).visible = false
		elif str(child.name) in ["FocusRing", "SignatureSurge3D"]:
			(child as Node3D).visible = false
		_hide_readouts(child)


## Paint the kit on after `configure`, which sets team colour from `UIPalette`
## -- the same two theme colours for every club in the world. Shorts follow the
## shirt darkened, which is the relationship the rig already uses.
func _wear(actor: Node, kit: Color) -> void:
	for path in ["BodyPivot/Torso", "BodyPivot/Shorts"]:
		var mesh := actor.get_node_or_null(path) as MeshInstance3D
		if mesh == null:
			continue
		_paint(mesh, kit if path.ends_with("Torso") else kit.darkened(0.38))
	## **This currently matches nothing, and the claim it used to carry was
	## false.** It was written to fix cosmetics stuck in `UIPalette`'s teal and
	## coral, and said it had -- but the rig only ever emits `color_key` of
	## `skin`, `crown` or `literal`, so the `kit` branch has never once fired. The
	## cosmetics a voli actually has are ears, muzzle, tail, neck and an Avi's
	## wings, and every one of them is anatomy: skin-coloured is correct and a
	## kit colour would be wrong. Kept as the hook for the first cosmetic that is
	## genuinely clothing, and no longer pretending to have done anything.
	_paint_cosmetics(actor, kit)


func _paint_cosmetics(node: Node, kit: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and str(child.get_meta("color_key", "")) == "kit":
			_paint(child as MeshInstance3D, kit)
		_paint_cosmetics(child, kit)


func _paint(mesh: MeshInstance3D, colour: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.82
	mesh.material_override = material


## The court floor this region actually plays on.
func _floor_for(id: String) -> void:
	var spec: Dictionary = FLOORS.get(id, {})
	if spec.is_empty():
		return
	var floor_mesh := _court.get_node_or_null("CourtSurface") as MeshInstance3D
	if floor_mesh == null:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(spec["albedo"])
	material.roughness = float(spec["rough"])
	floor_mesh.material_override = material


## One emissive or plain box, parented under the venue's own node so it goes away
## with the court.
func _box(
	size: Vector3, at: Vector3, colour: Color,
	metallic: float = 0.0, roughness: float = 0.9, emission: float = 0.0
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.metallic = metallic
	material.roughness = roughness
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = colour
		material.emission_energy_multiplier = emission
	node.material_override = material
	_extras.add_child(node)
	return node
