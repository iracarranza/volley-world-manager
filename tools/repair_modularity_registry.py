#!/usr/bin/env python3
from __future__ import annotations
import re, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = "origin/claude/m8-visual-continuity"

def original(path: str) -> str:
    return subprocess.check_output(["git","show",f"{BASE}:{path}"], cwd=ROOT, text=True)

def write(path: str, text: str) -> None:
    p=ROOT/path; p.parent.mkdir(parents=True, exist_ok=True); p.write_text(text,encoding="utf-8")

def extract_const(src: str, name: str) -> str:
    m=re.search(rf"(?m)^const\s+{re.escape(name)}(?:\s*:\s*[^=\n]+)?\s*(?::=|=)\s*",src)
    if not m: raise RuntimeError(name)
    start=m.start(); i=m.end(); depth=0; quote=None; esc=False
    while i<len(src):
        c=src[i]
        if quote:
            if esc: esc=False
            elif c=='\\': esc=True
            elif c==quote: quote=None
        else:
            if c in ('\"',"'"): quote=c
            elif c in '([{': depth+=1
            elif c in ')]}': depth-=1
            elif c=='\n' and depth==0:
                line=src[src.rfind('\n',start,i)+1:i].rstrip()
                if not line.endswith('\\'): return src[start:i]
        i+=1
    return src[start:i]

def top_func(src: str, name: str) -> str:
    m=re.search(rf"(?m)^(?:static\s+)?func\s+{re.escape(name)}\b",src)
    if not m: raise RuntimeError(name)
    n=re.search(r"(?m)^(?:static\s+)?func\s+[_A-Za-z0-9]+\b",src[m.end():])
    end=m.end()+n.start() if n else len(src)
    return src[m.start():end].rstrip()+"\n"

gen=original("scripts/systems/player_generator.gd")
player=original("scripts/models/volleyball_player.gd")
rally=original("scripts/simulation/rally_simulator.gd")

ability=extract_const(player,"ABILITY_ATTRIBUTES")
physical=extract_const(gen,"PHYSICAL_ATTRIBUTES")
mental=extract_const(gen,"MENTAL_ATTRIBUTES")
write("scripts/domain/attribute_registry.gd", f'''class_name AttributeRegistry
extends RefCounted

## Canonical ability-attribute vocabulary. Formulas stay in their owning systems.
{ability}

{physical}

{mental}

static func all_ids() -> Array[String]:
\treturn ABILITY_ATTRIBUTES.duplicate()

static func category_of(attribute_id: String) -> String:
\tif attribute_id in PHYSICAL_ATTRIBUTES: return "Physical"
\tif attribute_id in MENTAL_ATTRIBUTES: return "Mental"
\treturn "Technical"

static func definition(attribute_id: String) -> Dictionary:
\treturn {{"id": attribute_id, "category": category_of(attribute_id),
\t\t"trainable": attribute_id in ABILITY_ATTRIBUTES,
\t\t"scoutable": attribute_id in ABILITY_ATTRIBUTES}}
''')

region_names=["REGION_HEIGHT_BIAS","REGION_MASS_BIAS","REGION_WINGSPAN_BIAS","REGION_SPECIALTY","REGION_EGO_BIAS","REGION_AGGRESSION_BIAS","REGION_CEILING_PENALTY"]
region_parts=[extract_const(gen,n) for n in region_names]
write("scripts/domain/region_profiles.gd", '''class_name RegionProfiles
extends RefCounted

## Canonical regional generation/development profile data.

'''+"\n\n".join(region_parts)+'''\n
static func specialty(region_name: String) -> Array:
\treturn Array(REGION_SPECIALTY.get(region_name, []))

static func physique(region_name: String) -> Dictionary:
\treturn {"height": float(REGION_HEIGHT_BIAS.get(region_name,0.0)),
\t\t"mass": float(REGION_MASS_BIAS.get(region_name,0.0)),
\t\t"wingspan": float(REGION_WINGSPAN_BIAS.get(region_name,0.0))}
''')

role_names=["POSITION_WEIGHTS","POSITION_APPROACH_STEP_MODIFIER","POSITION_APPROACH_TOLERANCE_MODIFIER"]
role_parts=[extract_const(player,n) for n in role_names]
for n in ["POSITION_EGO_BIAS","POSITION_LEADERSHIP_BIAS","POSITION_AGGRESSION_BIAS","POSITIONS","ROLE_SECONDARY","ROLE_HEIGHT_SPREAD"]:
    role_parts.append(extract_const(gen,n))
write("scripts/domain/role_profiles.gd", '''class_name RoleProfiles
extends RefCounted

## Canonical role profile data shared by player scoring and generation.

'''+"\n\n".join(role_parts)+'''\n
static func primary_attributes(role_name: String) -> Array:
\treturn Array(POSITION_WEIGHTS.get(role_name, []))

static func secondary_attributes(role_name: String) -> Array:
\treturn Array(ROLE_SECONDARY.get(role_name, []))
''')

body_parts=[extract_const(gen,n) for n in ["BODY_TYPES","BODY_TYPE_METRICS","BODY_TYPE_ATTRIBUTES"]]
write("scripts/domain/body_type_gameplay.gd", '''class_name BodyTypeGameplay
extends RefCounted

## Gameplay-side body definitions; rendering remains in body_type_models.gd.

'''+"\n\n".join(body_parts)+'''\n
static func attribute_modifiers(body_type: String) -> Dictionary:
\treturn Dictionary(BODY_TYPE_ATTRIBUTES.get(body_type, {}))

static func metric_modifiers(body_type: String) -> Dictionary:
\treturn Dictionary(BODY_TYPE_METRICS.get(body_type, {}))
''')

rescue=top_func(rally,"_set_rescue_height_meters").replace("static func _set_rescue_height_meters","static func rescue_height_meters",1)
height=top_func(rally,"_set_height_difficulty").replace("static func _set_height_difficulty","static func set_height_difficulty",1)
write("scripts/simulation/setter_decision_math.gd", '''class_name SetterDecisionMath
extends RefCounted

## Pure setter-option geometry extracted without changing formulas or RNG.

'''+rescue+"\n"+height)
print("repaired registry sources from", BASE)
