#!/usr/bin/env python3
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")


def extract_const(source: str, name: str) -> tuple[str, int, int]:
    match = re.search(rf"(?m)^const\s+{re.escape(name)}(?:\s*:[^:=\n]+)?\s*:=", source)
    if not match:
        raise RuntimeError(f"constant not found: {name}")
    start = match.start()
    i = match.end()
    depth = 0
    quote = None
    escaped = False
    while i < len(source):
        ch = source[i]
        if quote:
            if escaped:
                escaped = False
            elif ch == "\\":
                escaped = True
            elif ch == quote:
                quote = None
        else:
            if ch in ('\"', "'"):
                quote = ch
            elif ch in "([{":
                depth += 1
            elif ch in ")]}":
                depth -= 1
            elif ch == "\n" and depth == 0:
                # A GDScript line continuation deliberately keeps the statement open.
                line = source[source.rfind("\n", start, i) + 1:i].rstrip()
                if not line.endswith("\\"):
                    return source[start:i], start, i
        i += 1
    return source[start:i], start, i


def const_names(source: str, prefix: str) -> list[str]:
    return re.findall(rf"(?m)^const\s+({re.escape(prefix)}[A-Z0-9_]+)(?:\s*:[^:=\n]+)?\s*:=", source)


def inject_preloads(source: str, preloads: list[str]) -> str:
    missing = [line for line in preloads if line not in source]
    if not missing:
        return source
    m = re.search(r"(?m)^extends\s+[^\n]+\n", source)
    if not m:
        raise RuntimeError("extends line not found for preload injection")
    return source[:m.end()] + "\n" + "\n".join(missing) + "\n" + source[m.end():]


def replace_const(source: str, name: str, replacement: str) -> str:
    _, start, end = extract_const(source, name)
    return source[:start] + replacement + source[end:]


def extract_top_level_func(source: str, signature: str) -> tuple[str, int, int]:
    m = re.search(rf"(?m)^(?:static\s+)?func\s+{re.escape(signature)}\b", source)
    if not m:
        raise RuntimeError(f"function not found: {signature}")
    start = m.start()
    nxt = re.search(r"(?m)^(?:static\s+)?func\s+[_A-Za-z0-9]+\b", source[m.end():])
    end = m.end() + nxt.start() if nxt else len(source)
    return source[start:end].rstrip() + "\n", start, end


def build_domain_registries() -> None:
    generator_path = "scripts/systems/player_generator.gd"
    player_path = "scripts/models/volleyball_player.gd"
    generator = read(generator_path)
    player = read(player_path)

    region_names = const_names(generator, "REGION_")
    role_names = const_names(generator, "POSITION_")
    role_names += [n for n in ("POSITIONS", "ROLE_SECONDARY", "ROLE_HEIGHT_SPREAD") if re.search(rf"(?m)^const\s+{n}\b", generator)]
    body_names = [n for n in ("BODY_TYPES", "BODY_TYPE_METRICS", "BODY_TYPE_ATTRIBUTES") if re.search(rf"(?m)^const\s+{n}\b", generator)]
    attribute_category_names = [n for n in ("PHYSICAL_ATTRIBUTES", "MENTAL_ATTRIBUTES", "TECHNICAL_ATTRIBUTES") if re.search(rf"(?m)^const\s+{n}\b", generator)]

    # Role primary weights and the canonical ability attribute list are currently
    # authored by VolleyballPlayer. Move their source-of-truth into domain registries
    # while preserving aliases on VolleyballPlayer for every existing caller.
    position_weights, _, _ = extract_const(player, "POSITION_WEIGHTS")
    ability_attributes, _, _ = extract_const(player, "ABILITY_ATTRIBUTES")

    region_statements = [extract_const(generator, n)[0] for n in region_names]
    role_statements = [extract_const(generator, n)[0] for n in role_names]
    body_statements = [extract_const(generator, n)[0] for n in body_names]
    category_statements = [extract_const(generator, n)[0] for n in attribute_category_names]

    # Deduplicate while preserving source order.
    def unique(items: list[str]) -> list[str]:
        seen = set()
        out = []
        for item in items:
            key = re.search(r"^const\s+([A-Z0-9_]+)", item).group(1)
            if key not in seen:
                seen.add(key)
                out.append(item)
        return out

    region_statements = unique(region_statements)
    role_statements = unique(role_statements)
    body_statements = unique(body_statements)

    role_primary = position_weights.replace("const POSITION_WEIGHTS", "const PRIMARY_WEIGHTS", 1)

    write("scripts/domain/attribute_registry.gd", """class_name AttributeRegistry
extends RefCounted

## Canonical identity/metadata registry for player ability attributes.
## Gameplay formulas stay in their owning systems; this file answers what an
## attribute *is* so generation, roles, regions, training, scouting and UI can
## validate against one vocabulary.
""" + ability_attributes + "\n\n" + "\n\n".join(category_statements) + """

static func all_ids() -> Array[String]:
    var result: Array[String] = []
    for attribute in ABILITY_ATTRIBUTES:
        result.append(str(attribute))
    return result


static func category_of(attribute_id: String) -> String:
    if "PHYSICAL_ATTRIBUTES" in AttributeRegistry and attribute_id in PHYSICAL_ATTRIBUTES:
        return "Physical"
    if "MENTAL_ATTRIBUTES" in AttributeRegistry and attribute_id in MENTAL_ATTRIBUTES:
        return "Mental"
    if "TECHNICAL_ATTRIBUTES" in AttributeRegistry and attribute_id in TECHNICAL_ATTRIBUTES:
        return "Technical"
    return "Technical"


static func definition(attribute_id: String) -> Dictionary:
    return {
        "id": attribute_id,
        "category": category_of(attribute_id),
        "trainable": attribute_id in ABILITY_ATTRIBUTES,
        "scoutable": attribute_id in ABILITY_ATTRIBUTES,
    }


static func invalid_ids(attribute_ids: Array) -> Array[String]:
    var invalid: Array[String] = []
    for attribute in attribute_ids:
        var key := str(attribute)
        if key not in ABILITY_ATTRIBUTES and key not in invalid:
            invalid.append(key)
    return invalid
""")

    write("scripts/domain/region_profiles.gd", """class_name RegionProfiles
extends RefCounted

## Player-development/profile inputs by region. PlayerGenerator composes these
## profiles; it no longer owns the world's regional definitions.

""" + "\n\n".join(region_statements) + """

static func specialty(region_name: String) -> Array:
    return Array(REGION_SPECIALTY.get(region_name, [])) if "REGION_SPECIALTY" in RegionProfiles else []


static func physique(region_name: String) -> Dictionary:
    return {
        "height": float(REGION_HEIGHT_BIAS.get(region_name, 0.0)),
        "mass": float(REGION_MASS_BIAS.get(region_name, 0.0)),
        "wingspan": float(REGION_WINGSPAN_BIAS.get(region_name, 0.0)),
    }
""")

    write("scripts/domain/role_profiles.gd", """class_name RoleProfiles
extends RefCounted

## Canonical role definitions shared by generation and ability scoring.
## Capabilities remain situational systems; a role describes weighting and
## development preference rather than hard-coded permission to act.

""" + role_primary + "\n\n" + "\n\n".join(role_statements) + """

static func primary_weights(role_name: String) -> Dictionary:
    return Dictionary(PRIMARY_WEIGHTS.get(role_name, {}))


static func secondary_attributes(role_name: String) -> Array:
    return Array(ROLE_SECONDARY.get(role_name, [])) if "ROLE_SECONDARY" in RoleProfiles else []
""")

    write("scripts/domain/body_type_gameplay.gd", """class_name BodyTypeGameplay
extends RefCounted

## Gameplay-side body definitions. Rendering remains in body_type_models.gd;
## the shared body-type key is the contract between simulation and presentation.

""" + "\n\n".join(body_statements) + """

static func attribute_modifiers(body_type: String) -> Dictionary:
    return Dictionary(BODY_TYPE_ATTRIBUTES.get(body_type, {}))


static func metric_modifiers(body_type: String) -> Dictionary:
    return Dictionary(BODY_TYPE_METRICS.get(body_type, {}))
""")

    generator = inject_preloads(generator, [
        'const AttributeRegistry := preload("res://scripts/domain/attribute_registry.gd")',
        'const RegionProfiles := preload("res://scripts/domain/region_profiles.gd")',
        'const RoleProfiles := preload("res://scripts/domain/role_profiles.gd")',
        'const BodyTypeGameplay := preload("res://scripts/domain/body_type_gameplay.gd")',
    ])
    player = inject_preloads(player, [
        'const AttributeRegistry := preload("res://scripts/domain/attribute_registry.gd")',
        'const RoleProfiles := preload("res://scripts/domain/role_profiles.gd")',
    ])

    for name in region_names:
        generator = replace_const(generator, name, f"const {name} := RegionProfiles.{name}")
    for name in set(role_names):
        generator = replace_const(generator, name, f"const {name} := RoleProfiles.{name}")
    for name in body_names:
        generator = replace_const(generator, name, f"const {name} := BodyTypeGameplay.{name}")
    for name in attribute_category_names:
        generator = replace_const(generator, name, f"const {name} := AttributeRegistry.{name}")

    player = replace_const(player, "POSITION_WEIGHTS", "const POSITION_WEIGHTS := RoleProfiles.PRIMARY_WEIGHTS")
    player = replace_const(player, "ABILITY_ATTRIBUTES", "const ABILITY_ATTRIBUTES := AttributeRegistry.ABILITY_ATTRIBUTES")

    write(generator_path, generator)
    write(player_path, player)


def consolidate_private_rng() -> None:
    path = "scripts/systems/player_generator.gd"
    source = read(path)
    if "static func _player_channel_rng(" not in source:
        marker = "static func assign_body_type(player: VolleyballPlayer, rng: RandomNumberGenerator) -> void:"
        pos = source.find(marker)
        if pos < 0:
            raise RuntimeError("assign_body_type marker missing")
        helper = '''static func _player_channel_rng(\n\tbase_rng: RandomNumberGenerator,\n\tplayer: VolleyballPlayer,\n\tregion_name: String,\n\tchannel: String,\n) -> RandomNumberGenerator:\n\t## Stable private stream: adding/tuning one generated temperament must not\n\t## advance the shared roster RNG and silently reroll unrelated attributes.\n\tvar result := RandomNumberGenerator.new()\n\tresult.seed = hash("%d|%s|%d|%s" % [\n\t\tbase_rng.seed, channel, player.id, region_name,\n\t])\n\treturn result\n\n\n'''
        source = source[:pos] + helper + source[pos:]

    pattern = re.compile(
        r"var\s+(?P<var>[A-Za-z0-9_]+_rng)\s*:=\s*RandomNumberGenerator\.new\(\)\n"
        r"\s*(?P=var)\.seed\s*=\s*hash\(\"%d\|(?P<channel>[^|\"]+)\|%d\|%s\"\s*%\s*\["
        r"\s*rng\.seed,\s*player\.id,\s*region_name,?\s*\]\s*\)",
        re.MULTILINE,
    )
    source, count = pattern.subn(
        lambda m: f'var {m.group("var")} := _player_channel_rng(rng, player, region_name, "{m.group("channel")}")',
        source,
    )
    if count == 0:
        # Known branches may format one seed on one line. Handle that too.
        one_line = re.compile(
            r"var\s+(?P<var>[A-Za-z0-9_]+_rng)\s*:=\s*RandomNumberGenerator\.new\(\)\n"
            r"\s*(?P=var)\.seed\s*=\s*hash\(\"%d\|(?P<channel>[^|\"]+)\|%d\|%s\"\s*%\s*\[rng\.seed, player\.id, region_name\]\)"
        )
        source, count = one_line.subn(
            lambda m: f'var {m.group("var")} := _player_channel_rng(rng, player, region_name, "{m.group("channel")}")',
            source,
        )
    write(path, source)


def extract_vertical_slice_roster() -> None:
    path = "scripts/managers/game_manager.gd"
    source = read(path)
    if 'VerticalSliceRoster := preload("res://scripts/data/vertical_slice_roster.gd")' in source:
        return
    fn_start = source.find("func seed_vertical_slice_data() -> void:")
    if fn_start < 0:
        raise RuntimeError("seed_vertical_slice_data missing")
    team_marker = source.find("\n\tteam = TeamScript.new()", fn_start)
    if team_marker < 0:
        raise RuntimeError("vertical-slice team marker missing")
    first = source.find("\n\tplayers.append(_make_player(", fn_start, team_marker)
    if first < 0:
        raise RuntimeError("vertical-slice player block missing")
    player_block = source[first:team_marker]
    count = player_block.count("players.append(_make_player(")
    if count < 6:
        raise RuntimeError(f"unexpected vertical-slice player count: {count}")

    generated_block = player_block.replace("\n\t", "\n\t")
    generated_block = generated_block.replace("players.append(_make_player(", "players.append(make_player.call(")
    module = '''class_name VerticalSliceRoster\nextends RefCounted\n\n## Hand-authored development fixture roster. Kept outside GameManager so the\n## runtime coordinator does not also own several hundred lines of seed data.\nstatic func make_players(make_player: Callable) -> Array[VolleyballPlayer]:\n\tvar players: Array[VolleyballPlayer] = []\n''' + generated_block.lstrip("\n") + "\n\treturn players\n"
    write("scripts/data/vertical_slice_roster.gd", module)

    replacement = "\n\tplayers.append_array(VerticalSliceRoster.make_players(Callable(self, \"_make_player\")))"
    source = source[:first] + replacement + source[team_marker:]
    source = inject_preloads(source, [
        'const VerticalSliceRoster := preload("res://scripts/data/vertical_slice_roster.gd")',
    ])
    write(path, source)


def cache_weekly_service() -> None:
    path = "scripts/managers/career_manager.gd"
    source = read(path)
    if "weekly_service := _week_service(" not in source:
        marker = "\n\tfor player in _game_manager().players:\n\t\t## Weekly recovery must exceed every training load."
        pos = source.find(marker)
        if pos < 0:
            raise RuntimeError("advance_week recovery loop marker missing")
        cache = "\n\tvar weekly_service := _week_service(str(career.region), int(career.absolute_week))"
        source = source[:pos] + cache + source[pos:]
        source = source.replace(
            "recover_weekly_fatigue(player, _weekly_recovery_share(player))",
            "recover_weekly_fatigue(player, _weekly_recovery_share(player, weekly_service))",
            1,
        )
        source = source.replace(
            "_advance_weekly_palate(player)",
            "_advance_weekly_palate(player, weekly_service)",
            1,
        )
        # The chef records familiarity against the same service the roster was charged.
        source = source.replace(
            'var served_now: Dictionary = _week_service(\n\t\t\tstr(career.region), int(career.absolute_week)\n\t\t)',
            "var served_now: Dictionary = weekly_service",
            1,
        )

    old_sig = "func _weekly_recovery_share(player: VolleyballPlayer) -> float:"
    new_sig = "func _weekly_recovery_share(\n\tplayer: VolleyballPlayer, served_override: Dictionary = {},\n) -> float:"
    if old_sig in source:
        source = source.replace(old_sig, new_sig, 1)
        old = "var served: Dictionary = _week_service(club_region, week)"
        new = "var served: Dictionary = served_override if not served_override.is_empty() \\\n\t\telse _week_service(club_region, week)"
        source = source.replace(old, new, 1)

    old_sig = "func _advance_weekly_palate(player: VolleyballPlayer) -> void:"
    new_sig = "func _advance_weekly_palate(\n\tplayer: VolleyballPlayer, served_override: Dictionary = {},\n) -> void:"
    if old_sig in source:
        source = source.replace(old_sig, new_sig, 1)
        old = "var served: Dictionary = _week_service(club_region, week)"
        new = "var served: Dictionary = served_override if not served_override.is_empty() \\\n\t\telse _week_service(club_region, week)"
        # Replace the next remaining occurrence (the recovery one was already changed).
        source = source.replace(old, new, 1)

    write(path, source)


def extract_rally_pure_helpers() -> None:
    path = "scripts/simulation/rally_simulator.gd"
    source = read(path)
    preload = 'const SetterDecisionMath := preload("res://scripts/simulation/setter_decision_math.gd")'
    if preload not in source:
        source = inject_preloads(source, [preload])

    rescue, rs, re_ = extract_top_level_func(source, "_set_rescue_height_meters")
    height, hs, he = extract_top_level_func(source, "_set_height_difficulty")
    # Re-locate after injection and replace independently by signature, not stale offsets.
    module_rescue = rescue.replace("static func _set_rescue_height_meters", "static func rescue_height_meters", 1)
    module_height = height.replace("static func _set_height_difficulty", "static func set_height_difficulty", 1)
    module_height = module_height.replace("_set_height_difficulty", "set_height_difficulty")
    write("scripts/simulation/setter_decision_math.gd", """class_name SetterDecisionMath
extends RefCounted

## Pure setter-option geometry. Extracted from RallySimulator so setter decision
## features can grow without adding another calculation directly to the rally
## orchestrator.

""" + module_rescue + "\n" + module_height)

    rescue_wrapper = '''static func _set_rescue_height_meters(\n\ttravel_time: float, ordinary_flight_time: float\n) -> float:\n\treturn SetterDecisionMath.rescue_height_meters(travel_time, ordinary_flight_time)\n\n\n'''
    height_wrapper = '''static func _set_height_difficulty(\n\tsetter: VolleyballPlayer, rescue_height_meters: float\n) -> float:\n\treturn SetterDecisionMath.set_height_difficulty(setter, rescue_height_meters)\n\n\n'''

    _, s, e = extract_top_level_func(source, "_set_rescue_height_meters")
    source = source[:s] + rescue_wrapper + source[e:]
    _, s, e = extract_top_level_func(source, "_set_height_difficulty")
    source = source[:s] + height_wrapper + source[e:]
    write(path, source)


def add_registry_validator() -> None:
    write("tools/validate_domain_registries.gd", '''extends SceneTree\n\nconst Attributes := preload("res://scripts/domain/attribute_registry.gd")\nconst Regions := preload("res://scripts/domain/region_profiles.gd")\nconst Roles := preload("res://scripts/domain/role_profiles.gd")\nconst Bodies := preload("res://scripts/domain/body_type_gameplay.gd")\nconst BodyPresentation := preload("res://scripts/data/body_type_models.gd")\n\nfunc _initialize() -> void:\n\tvar errors: Array[String] = []\n\tvar known := Attributes.all_ids()\n\tfor region_name in Regions.REGION_SPECIALTY:\n\t\tfor attribute in Array(Regions.REGION_SPECIALTY[region_name]):\n\t\t\tif str(attribute) not in known:\n\t\t\t\terrors.append("region %s references unknown attribute %s" % [region_name, attribute])\n\tfor role_name in Roles.PRIMARY_WEIGHTS:\n\t\tfor attribute in Dictionary(Roles.PRIMARY_WEIGHTS[role_name]):\n\t\t\tif str(attribute) not in known:\n\t\t\t\terrors.append("role %s primary references unknown attribute %s" % [role_name, attribute])\n\tfor role_name in Roles.ROLE_SECONDARY:\n\t\tfor attribute in Array(Roles.ROLE_SECONDARY[role_name]):\n\t\t\tif str(attribute) not in known:\n\t\t\t\terrors.append("role %s secondary references unknown attribute %s" % [role_name, attribute])\n\tfor body_name in Bodies.BODY_TYPE_ATTRIBUTES:\n\t\tfor attribute in Dictionary(Bodies.BODY_TYPE_ATTRIBUTES[body_name]):\n\t\t\tif str(attribute) not in known:\n\t\t\t\terrors.append("body %s references unknown attribute %s" % [body_name, attribute])\n\tfor body_name in Bodies.BODY_TYPES:\n\t\tif str(body_name) not in BodyPresentation.MODELLED:\n\t\t\terrors.append("gameplay body %s has no presentation model" % body_name)\n\tfor body_name in BodyPresentation.MODELLED:\n\t\tif str(body_name) not in Bodies.BODY_TYPES:\n\t\t\terrors.append("presentation body %s has no gameplay definition" % body_name)\n\tif errors.is_empty():\n\t\tprint("DOMAIN REGISTRY CONTRACT: PASS (%d attributes, %d regions, %d roles, %d bodies)" % [\n\t\t\tknown.size(), Regions.REGION_SPECIALTY.size(), Roles.PRIMARY_WEIGHTS.size(), Bodies.BODY_TYPES.size(),\n\t\t])\n\t\tquit(0)\n\t\treturn\n\tfor error in errors:\n\t\tpush_error(error)\n\tprint("DOMAIN REGISTRY CONTRACT: FAIL (%d errors)" % errors.size())\n\tquit(1)\n''')


def add_refactor_notes() -> None:
    write("docs/architecture/MODULARITY_REFACTOR.md", '''# Modularity and efficiency refactor\n\nThis pass targets two different problems without mixing them:\n\n1. remove repeated work where the same state is recomputed inside one operation;\n2. make new content additive by moving domain definitions out of procedural systems.\n\n## New ownership boundaries\n\n- `AttributeRegistry` owns the canonical ability-attribute vocabulary and category metadata.\n- `RoleProfiles` owns role primary weights and generation support attributes.\n- `RegionProfiles` owns regional generation/development biases.\n- `BodyTypeGameplay` owns body-type gameplay modifiers; `BodyTypeModels` remains presentation-only.\n- `PlayerGenerator` composes those definitions rather than authoring them. Compatibility aliases remain during migration.\n- `VerticalSliceRoster` owns hand-authored fixture player data instead of `GameManager`.\n- `SetterDecisionMath` is the first pure setter-decision extraction from `RallySimulator`; the simulator retains forwarding wrappers so existing callers and test probes remain stable.\n\n## Growth rule\n\nNew content should prefer **definition + registration + consumer** over adding another branch to an unrelated procedural file. A new attribute, for example, is registered once, then deliberately referenced by role/region/body/training/scouting/simulation consumers. `tools/validate_domain_registries.gd` fails on dangling attribute or body references.\n\n## Runtime change\n\n`CareerManager.advance_week()` resolves the club's served food once and reuses that immutable weekly result for recovery, palate progression and chef familiarity instead of recomputing the same table/service for every player.\n\n## Deliberately not changed\n\n- No rally formulas, RNG order, event schema or scoring rules are redesigned here.\n- No per-frame collision system is introduced.\n- Declarative presentation catalogues remain declarative even when large.\n- Home/opponent resolver consolidation is not attempted mechanically; that needs behavior-specific tests phase by phase rather than a blind size reduction.\n''')


def main() -> None:
    build_domain_registries()
    consolidate_private_rng()
    extract_vertical_slice_roster()
    cache_weekly_service()
    extract_rally_pure_helpers()
    add_registry_validator()
    add_refactor_notes()
    print("modularity refactor applied")


if __name__ == "__main__":
    main()
