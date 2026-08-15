class_name StaffReports
extends RefCounted

## What each staff member tells you, in their own words.
##
## The Club tab used to list four people and what they own. That is an org
## chart, and an org chart is the least interesting true thing you can say about
## somebody you employ. What a manager actually has with a chef is a
## **correspondence** — the chef comes to you, about food, in the first person,
## and the reason you know the kitchen is going well is that they said so.
##
## ## Two voices, and it is the same rule as `ClubEvents`
##
## The **report** names the mechanic and its figures, because that is the
## decision being informed. The **utterance** is what they actually said, and it
## is shorter, vaguer and warmer. A chef does not know they are running at 0.91
## of a week's paste; they know the Landavoli is going further than it did.
##
## Inherited rather than reinvented, so a card from the kitchen and a card from
## the inbox read as the same world.
##
## ## Nothing here is authored per person
##
## Every line is derived from state the club already has. A chef's report is
## their familiarity table against the week's service; a scout's is their rating
## against how long they have watched somebody. That is what stops this becoming
## four hundred lines of dialogue nobody can keep consistent, and it is why two
## clubs with the same chef in different regions get different letters.
const StaffMember := preload("res://scripts/models/staff_member.gd")
const Familiarity := preload("res://scripts/data/staff_familiarity.gd")
const FoodBlock := preload("res://scripts/data/food_block.gd")
const Regions := preload("res://scripts/data/regions.gd")

## How a region's food is spoken about.
##
## `VolleyballRegions.DEMONYMS` already carries the distinction the roster obeys:
## you are *from* Xérvu and the flavour is *Xérvyan*. A chef talking about
## ingredients uses the adjective, which is the same rule and the reason it is
## read from there rather than typed here.
static func flavour_word(region: String) -> String:
	## Read from `DEMONYMS`, not from `definition()` -- the definition dictionary
	## has no demonym key, so the first version silently fell through to its
	## default and the chef said *Landavol paste* where they meant *Landavoli*.
	## A `.get()` with the right answer as its fallback is the quietest way to
	## get a wrong one.
	return str(Regions.DEMONYMS.get(region, region))


## Everything the chef has to say about this week.
##
## `service` is the week's table-shaped serving from `FoodSupply.served`, and
## `familiar` is the club's staff familiarity table.
static func kitchen(
	chef: Resource, service: Dictionary, familiar: Dictionary, block: String,
	fed: Dictionary = {}
) -> Array:
	var out: Array = []
	if chef == null:
		return out
	var pastes: Dictionary = service.get("pastes", {})
	var slots := FoodBlock.paste_slots(int(chef.rating))

	## **How the week actually went**, which is the chef's own business and does
	## not belong on the kitchen page. The kitchen is where a manager sets the
	## block, the mix and the lines; what came of it is a *report*, and a report
	## is somebody telling you. Splitting it that way is also what keeps the
	## kitchen from becoming a dashboard with controls attached.
	if not fed.is_empty():
		var uneasy := int(fed.get("uneasy", 0))
		var squad := int(fed.get("squad", 0))
		out.append(_card(
			"kitchen_week", chef,
			"Nourishment %d%% · %d of %d eating badly · mix cost %.2f" % [
				roundi(float(fed.get("nourishment", 1.0)) * 100.0),
				uneasy, squad, float(fed.get("cost", 0.0)),
			],
			_week_line(uneasy, squad, float(fed.get("nourishment", 1.0)))
		))

	## The line the whole idea started from. It fires when a paste crosses a
	## step of familiarity, which is what makes it news rather than a status.
	for paste in pastes:
		var region := str(pastes[paste])
		var level := Familiarity.of(familiar, int(chef.id), str(paste))
		if level < Familiarity.BASELINE + Familiarity.WORTH_SAYING:
			continue
		var spend := Familiarity.thrift(familiar, int(chef.id), str(paste))
		out.append(_card(
			"kitchen_thrift", chef,
			"%s paste: %d%% of a week's worth for the same plate."
				% [flavour_word(region), roundi(spend * 100.0)],
			"I improved my use of %s paste." % flavour_word(region)
		))
		break

	## And the one that is a complaint. An unfamiliar ingredient is not a chef
	## failing; it is a chef spending more of it, and saying so is how a manager
	## learns that a new line costs more than its freight for a while.
	for paste in pastes:
		var level := Familiarity.of(familiar, int(chef.id), str(paste))
		if level > Familiarity.BASELINE:
			continue
		out.append(_card(
			"kitchen_stranger", chef,
			"%s paste: %d%% of a week's worth, until it is learned."
				% [
					flavour_word(str(pastes[paste])),
					roundi(Familiarity.thrift(familiar, int(chef.id), str(paste)) * 100.0),
				],
			"I am still getting the measure of the %s."
				% flavour_word(str(pastes[paste]))
		))
		break

	## What is on the block, which is the chef reporting the thing the manager
	## chose rather than the thing the chef did.
	out.append(_card(
		"kitchen_service", chef,
		"%s, %d paste%s: %s." % [
			block, pastes.size(), "" if pastes.size() == 1 else "s",
			", ".join(pastes.keys()) if not pastes.is_empty() else "nothing",
		],
		_service_line(block, pastes.size(), slots)
	))
	return out


## What the chef says about how it landed, which is vaguer than the figures
## above it because a chef does not know a nourishment percentage -- they know
## whether plates came back empty.
static func _week_line(uneasy: int, squad: int, nourishment: float) -> String:
	if squad > 0 and uneasy * 2 >= squad:
		return "Half the room is pushing it round the plate."
	if uneasy > 0:
		return "A couple of them are not eating what I put out."
	if nourishment >= 1.05:
		return "Good week for it. Everything came in better than usual."
	return "Plates come back empty. No complaints."


static func _service_line(block: String, serving: int, slots: int) -> String:
	if serving < slots:
		return "I have room for more than you are giving me."
	if FoodBlock.resets_palate(block):
		## *...which is the point* was the design explaining a palate reset through
		## a chef's mouth. Attribution makes a judgement legal, not an authorial
		## aside: this chef knows the week was dull, and does not know why the
		## mechanic wants it to be.
		return "Quiet week. Nothing anybody is going to talk about."
	if FoodBlock.takes_paste(block) < 0.5:
		return "Whatever I put on this, it tastes of the block."
	return "The %s is carrying it well." % block


## What the scout has to say, which is about how sure they are rather than about
## anybody in particular.
static func desk(scout: Resource, watched: int, marked: int) -> Array:
	var out: Array = []
	if scout == null:
		return out
	out.append(_card(
		"desk_reach", scout,
		"Reading at %d. %d marked, %d watched closely."
			% [int(scout.rating), marked, watched],
		_reach_line(int(scout.rating))
	))
	return out


static func _reach_line(rating: int) -> String:
	if rating >= 70:
		return "Ask me about anybody. I will give you a straight answer."
	if rating >= 45:
		return "I can tell you what I have seen. Some of it twice."
	return "I would not sign anybody on my word alone yet."


## And the physio, who owns the one number the squad feels.
static func treatment(physio: Resource, tired: int, squad: int) -> Array:
	var out: Array = []
	if physio == null:
		return out
	out.append(_card(
		"treatment_room", physio,
		"%d of %d carrying something." % [tired, squad],
		"Nobody I am worried about." if tired == 0
			else ("One I would rest." if tired == 1
				else "%d I would rest, if you can spare them." % tired)
	))
	return out


## One card, in the shape the inbox already reads.
static func _card(
	id: String, member: Resource, report: String, utterance: String
) -> Dictionary:
	return {
		"id": id,
		"staff_id": int(member.id),
		"role": str(member.role),
		"speaker": str(member.display_name),
		"report": report,
		"utterance": utterance,
	}


## Which desk a role's correspondence lives at, so the hub can name the room
## rather than the job title. You do not visit the Physio, you visit the
## treatment room and the physio is in it.
const DESK_NAMES := {
	StaffMember.ROLE_CHEF: "The kitchen",
	StaffMember.ROLE_SCOUT: "The desk",
	StaffMember.ROLE_PHYSIO: "The treatment room",
	StaffMember.ROLE_ASSISTANT_COACH: "The session",
}


static func desk_name(role: String) -> String:
	return str(DESK_NAMES.get(role, role))
