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


def _const_pattern(name: str) -> re.Pattern[str]:
    # GDScript accepts both `=` and `:=`, with optional type annotations.
    return re.compile(
        rf"(?m)^const\s+{re.escape(name)}(?:\s*:\s*[^=\n]+)?\s*(?::=|=)\s*"
    )


def extract_const(source: str, name: str) -> tuple[str, int, int]:
    match = _const_pattern(name).search(source)
    if not match:
        raise RuntimeError(f"constant not found: {name}")
    start = match.start()
    i = match.end()
    depth = 0
    quote: str | None = None
    escaped = False
    while i < len(source):
        ch = source[i]
        if quote is not None:
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
                line = source[source.rfind("\n", start, i) + 1:i].rstrip()
                if not line.endswith("\\"):
                    return source[start:i], start, i
        i += 1
    return source[start:i], start, i


def const_names(source: str, prefix: str) -> list[str]:
    return re.findall(
        rf"(?m)^const\s+({re.escape(prefix)}[A-Z0-9_]+)(?:\s*:\s*[^=\n]+)?\s*(?::=|=)",
        source,
    )


def has_const(source: str, name: str) -> bool:
    return _const_pattern(name).search(source) is not None


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
    next_match = re.search(
        r"(?m)^(?:static\s+)?func\s+[_A-Za-z0-9]+\b", source[m.end():]
    )
    end = m.end() + next_match.start() if next_match else len(source)
    return source[m.start():end].rstrip() + "\n", m.start(), end


def dedupe_statements(statements: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for statement in statements:
        name = re.search(r"^const\s+([A-Z0-9_]+)", statement).group(1)
        if name not in seen:
            seen.add(name)
            result.append(statement)
    return result


def build_domain_registries() -> None:
    generator_path = "scripts/systems/player_generator.gd"
    player_path = "scripts/models/volleyball_player.gd"
    generator = read(generator_path)
    player = read(player_path)

    region_names = const_names(generator, "REGION_")
    generator_role_names = const_names(generator, "POSITION_")
    generator_role_names += [
        n for n in ("POSITIONS", "ROLE_SECONDARY", "ROLE_HEIGHT_SPREAD")
        if has_const(generator, n)
    ]
    player_role_names = const_names(player, "POSITION_")
    body_names = [
        n for n in ("BODY_TYPES", "BODY_TYPE_METRICS", "BODY_TYPE_ATTRIBUTES")
        if has_const(generator, n)
    ]
    category_names = [
        n for n in ("PHYSICAL_ATTRIBUTES", "MENTAL_ATTRIBUTES", "TECHNICAL_ATTRIBUTES")
        if has_const(generator, n)
    ]

    ability_attributes = extract_const(player, "ABILITY_ATTRIBUTES")[0]
    region_statements = dedupe_statements([extract_const(generator, n)[0] for n in region_names])
    role_statements = dedupe_statements(
        [extract_const(player, n)[0] for n in player_role_names]
        + [extract_const(generator, n)[0] for n in generator_role_names]
    )
    body_statements = dedupe_statements([extract_const(generator, n)[0] for n in body_names])
    category_statements = dedupe_statements([extract_const(generator, n)[0] for n in category_names])

    category_checks: list[str] = []
    if "PHYSICAL_ATTRIBUTES" in category_names:
        category_checks.append('    if attribute_id in PHYSICAL_ATTRIBUTES:\n        return "Physical"')
    if "MENTAL_ATTRIBUTES" in category_names:
        category_checks.append('    if attribute_id in MENTAL_ATTRIBUTES:\n        return "Mental"')
    if "TECHNICAL_ATTRIBUTES" in category_names:
        category_checks.append('    if attribute_id in TECHNICAL_ATTRIBUTES:\n        return "Technical"')
    category_body = "\n".join(category_checks) or "    pass"

    write(
        "scripts/domain/attribute_registry.gd",
        """class_name AttributeRegistry
extends RefCounted

## Canonical identity/metadata registry for player ability attributes.
## Formulas remain in their owning gameplay systems; this registry gives every
## generator, role, region, scout, trainer and UI one attribute vocabulary.

"""
        + ability_attributes
        + ("\n\n" + "\n\n".join(category_statements) if category_statements else "")
        + f"""

static func all_ids() -> Array[String]:
    var result: Array[String] = []
    for attribute in ABILITY_ATTRIBUTES:
        result.append(str(attribute))
    return result


static func category_of(attribute_id: String) -> String:
{category_body}
    return "Technical"


static func definition(attribute_id: String) -> Dictionary:
    return {{
        "id": attribute_id,
        "category": category_of(attribute_id),
        "trainable": attribute_id in ABILITY_ATTRIBUTES,
        "scoutable": attribute_id in ABILITY_ATTRIBUTES,
    }}


static func invalid_ids(attribute_ids: Array) -> Array[String]:
    var invalid: Array[String] = []
    for attribute in attribute_ids:
        var key := str(attribute)
        if key not in ABILITY_ATTRIBUTES and key not in invalid:
            invalid.append(key)
    return invalid
""",
    )

    write(
        "scripts/domain/region_profiles.gd",
        """class_name RegionProfiles
extends RefCounted

## Player-development/profile inputs by region. PlayerGenerator composes these
## profiles; it no longer authors the world's regional definitions.

"""
        + "\n\n".join(region_statements)
        + """

static func specialty(region_name: String) -> Array:
    return Array(REGION_SPECIALTY.get(region_name, []))


static func physique(region_name: String) -> Dictionary:
    return {
        "height": float(REGION_HEIGHT_BIAS.get(region_name, 0.0)),
        "mass": float(REGION_MASS_BIAS.get(region_name, 0.0)),
        "wingspan": float(REGION_WINGSPAN_BIAS.get(region_name, 0.0)),
    }
""",
    )

    write(
        "scripts/domain/role_profiles.gd",
        """class_name RoleProfiles
extends RefCounted

## Canonical role definitions shared by generation and ability scoring.
## Capabilities remain situational systems: a role describes weighting and
## development preference rather than hard-coded permission to act.

"""
        + "\n\n".join(role_statements)
        + """

static func primary_attributes(role_name: String) -> Array:
    return Array(POSITION_WEIGHTS.get(role_name, []))


static func secondary_attributes(role_name: String) -> Array:
    return Array(ROLE_SECONDARY.get(role_name, []))
""",
    )

    write(
        "scripts/domain/body_type_gameplay.gd",
        """class_name BodyTypeGameplay
extends RefCounted

## Gameplay-side body definitions. Rendering remains in body_type_models.gd;
## the body-type key is the explicit contract between simulation and presentation.

"""
        + "\n\n".join(body_statements)
        + """

static func attribute_modifiers(body_type: String) -> Dictionary:
    return Dictionary(BODY_TYPE_ATTRIBUTES.get(body_type, {}))


static func metric_modifiers(body_type: String) -> Dictionary:
    return Dictionary(BODY_TYPE_METRICS.get(body_type, {}))
""",
    )

    generator = inject_preloads(
        generator,
        [
            'const AttributeRegistry := preload("res://scripts/domain/attribute_registry.gd")',
            'const RegionProfiles := preload("res://scripts/domain/region_profiles.gd")',
            'const RoleProfiles := preload("res://scripts/domain/role_profiles.gd")',
            'const BodyTypeGameplay := preload("res://scripts/domain/body_type_gameplay.gd")',
        ],
    )
    player = inject_preloads(
        player,
        [
            'const AttributeRegistry := preload("res://scripts/domain/attribute_registry.gd")',
            'const RoleProfiles := preload("res://scripts/domain/role_profiles.gd")',
        ],
    )

    for name in region_names:
        generator = replace_const(generator, name, f"const {name} := RegionProfiles.{name}")
    for name in set(generator_role_names):
        generator = replace_const(generator, name, f"const {name} := RoleProfiles.{name}")
    for name in body_names:
        generator = replace_const(generator, name, f"const {name} := BodyTypeGameplay.{name}")
    for name in category_names:
        generator = replace_const(generator, name, f"const {name} := AttributeRegistry.{name}")

    for name in player_role_names:
        player = replace_const(player, name, f"const {name} := RoleProfiles.{name}")
    player = replace_const(
        player, "ABILITY_ATTRIBUTES", "const ABILITY_ATTRIBUTES := AttributeRegistry.ABILITY_ATTRIBUTES"
    )

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

    # Both multiline and one-line versions used in this file are normalized.
    pattern = re.compile(
        r"var\s+(?P<var>[A-Za-z0-9_]+_rng)\s*:=\s*RandomNumberGenerator\.new\(\)\n"
        r"\s*(?P=var)\.seed\s*=\s*hash\(\"%d\|(?P<channel>[^|\"]+)\|%d\|%s\"\s*%\s*\["
        r"(?P<inside>[^\]]*rng\.seed[^\]]*player\.id[^\]]*region_name[^\]]*)\]\s*\)",
        re.MULTILINE,
    )
    source = pattern.sub(
        lambda m: f'var {m.group("var")} := _player_channel_rng(rng, player, region_name, "{m.group("channel")}")',
        source,
    )
    write(path, source)


def extract_vertical_slice_roster() -> None:
    path = "scripts/managers/game_manager.gd"
    source = read(path)
    preload = 'const VerticalSliceRoster := preload("res://scripts/data/vertical_slice_roster.gd")'
    if preload in source:
        return
    fn_start = source.find("func seed_vertical_slice_data() -> void:")
    team_marker = source.find("\n\tteam = TeamScript.new()", fn_start)
    first = source.find("\n\tplayers.append(_make_player(", fn_start, team_marker)
    if min(fn_start, team_marker, first) < 0:
        raise RuntimeError("vertical-slice roster markers missing")
    player_block = source[first:team_marker]
    count = player_block.count("players.append(_make_player(")
    if count < 6:
        raise RuntimeError(f"unexpected vertical-slice player count: {count}")

    generated_block = player_block.replace(
        "players.append(_make_player(", "players.append(make_player.call("
    )
    module = '''class_name VerticalSliceRoster\nextends RefCounted\n\n## Hand-authored development fixture roster. Kept outside GameManager so the\n## runtime coordinator does not also own hundreds of lines of seed data.\nstatic func make_players(make_player: Callable) -> Array[VolleyballPlayer]:\n\tvar players: Array[VolleyballPlayer] = []\n''' + generated_block.lstrip("\n") + "\n\treturn players\n"
    write("scripts/data/vertical_slice_roster.gd", module)

    source = source[:first] + (
        "\n\tplayers.append_array(VerticalSliceRoster.make_players(Callable(self, \"_make_player\")))"
    ) + source[team_marker:]
    source = inject_preloads(source, [preload])
    write(path, source)


def cache_weekly_service() -> None:
    path = "scripts/managers/career_manager.gd"
    source = read(path)
    if "var weekly_service := _week_service(str(career.region), int(career.absolute_week))" not in source:
        marker = "\n\tfor player in _game_manager().players:\n\t\t## Weekly recovery must exceed every training load."
        pos = source.find(marker)
        if pos < 0:
            raise RuntimeError("advance_week recovery loop marker missing")
        source = source[:pos] + (
            "\n\tvar weekly_service := _week_service(str(career.region), int(career.absolute_week))"
        ) + source[pos:]
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
        source = source.replace(
            'var served_now: Dictionary = _week_service(\n\t\t\tstr(career.region), int(career.absolute_week)\n\t\t)',
            "var served_now: Dictionary = weekly_service",
            1,
        )

    if "func _weekly_recovery_share(player: VolleyballPlayer) -> float:" in source:
        source = source.replace(
            "func _weekly_recovery_share(player: VolleyballPlayer) -> float:",
            "func _weekly_recovery_share(\n\tplayer: VolleyballPlayer, served_override: Dictionary = {},\n) -> float:",
            1,
        )
        source = source.replace(
            "var served: Dictionary = _week_service(club_region, week)",
            "var served: Dictionary = served_override if not served_override.is_empty() else _week_service(club_region, week)",
            1,
        )

    if "func _advance_weekly_palate(player: VolleyballPlayer) -> void:" in source:
        source = source.replace(
            "func _advance_weekly_palate(player: VolleyballPlayer) -> void:",
            "func _advance_weekly_palate(\n\tplayer: VolleyballPlayer, served_override: Dictionary = {},\n) -> void:",
            1,
        )
        source = source.replace(
            "var served: Dictionary = _week_service(club_region, week)",
            "var served: Dictionary = served_override if not served_override.is_empty() else _week_service(club_region, week)",
            1,
        )
    write(path, source)


def extract_rally_pure_helpers() -> None:
    path = "scripts/simulation/rally_simulator.gd"
    source = read(path)
    preload = 'const SetterDecisionMath := preload("res://scripts/simulation/setter_decision_math.gd")'
    source = inject_preloads(source, [preload])

    rescue = extract_top_level_func(source, "_set_rescue_height_meters")[0]
    height = extract_top_level_func(source, "_set_height_difficulty")[0]
    module_rescue = rescue.replace(
        "static func _set_rescue_height_meters", "static func rescue_height_meters", 1
    )
    module_height = height.replace(
        "static func _set_height_difficulty", "static func set_height_difficulty", 1
    )
    write(
        "scripts/simulation/setter_decision_math.gd",
        """class_name SetterDecisionMath
extends RefCounted

## Pure setter-option geometry. This is deliberately a behavior-preserving first
## extraction: RallySimulator remains orchestration authority while setter math
## gets a stable place to grow.

""" + module_rescue + "\n" + module_height,
    )

    rescue_wrapper = '''static func _set_rescue_height_meters(\n\ttravel_time: float, ordinary_flight_time: float\n) -> float:\n\treturn SetterDecisionMath.rescue_height_meters(travel_time, ordinary_flight_time)\n\n\n'''
    height_wrapper = '''static func _set_height_difficulty(\n\tsetter: VolleyballPlayer, rescue_height_meters: float\n) -> float:\n\treturn SetterDecisionMath.set_height_difficulty(setter, rescue_height_meters)\n\n\n'''
    _, start, end = extract_top_level_func(source, "_set_rescue_height_meters")
    source = source[:start] + rescue_wrapper + source[end:]
    _, start, end = extract_top_level_func(source, "_set_height_difficulty")
    source = source[:start] + height_wrapper + source[end:]
    write(path, source)


def add_registry_validator() -> None:
    write("tools/validate_domain_registries.gd", '''extends SceneTree\n\nconst Attributes := preload("res://scripts/domain/attribute_registry.gd")\nconst Regions := preload("res://scripts/domain/region_profiles.gd")\nconst Roles := preload("res://scripts/domain/role_profiles.gd")\nconst Bodies := preload("res://scripts/domain/body_type_gameplay.gd")\nconst BodyPresentation := preload("res://scripts/data/body_type_models.gd")\n\nfunc _initialize() -> void:\n\tvar errors: Array[String] = []\n\tvar known := Attributes.all_ids()\n\tfor region_name in Regions.REGION_SPECIALTY:\n\t\tfor attribute in Array(Regions.REGION_SPECIALTY[region_name]):\n\t\t\tif str(attribute) not in known:\n\t\t\t\terrors.append("region %s references unknown attribute %s" % [region_name, attribute])\n\tfor role_name in Roles.POSITION_WEIGHTS:\n\t\tfor attribute in Array(Roles.POSITION_WEIGHTS[role_name]):\n\t\t\tif str(attribute) not in known:\n\t\t\t\terrors.append("role %s primary references unknown attribute %s" % [role_name, attribute])\n\tfor role_name in Roles.ROLE_SECONDARY:\n\t\tfor attribute in Array(Roles.ROLE_SECONDARY[role_name]):\n\t\t\tif str(attribute) not in known:\n\t\t\t\terrors.append("role %s secondary references unknown attribute %s" % [role_name, attribute])\n\tfor body_name in Bodies.BODY_TYPE_ATTRIBUTES:\n\t\tfor attribute in Dictionary(Bodies.BODY_TYPE_ATTRIBUTES[body_name]):\n\t\t\tif str(attribute) not in known:\n\t\t\t\terrors.append("body %s references unknown attribute %s" % [body_name, attribute])\n\tfor body_name in Bodies.BODY_TYPES:\n\t\tif str(body_name) not in BodyPresentation.MODELLED:\n\t\t\terrors.append("gameplay body %s has no presentation model" % body_name)\n\tfor body_name in BodyPresentation.MODELLED:\n\t\tif str(body_name) not in Bodies.BODY_TYPES:\n\t\t\terrors.append("presentation body %s has no gameplay definition" % body_name)\n\tif errors.is_empty():\n\t\tprint("DOMAIN REGISTRY CONTRACT: PASS (%d attributes, %d regions, %d roles, %d bodies)" % [\n\t\t\tknown.size(), Regions.REGION_SPECIALTY.size(), Roles.POSITION_WEIGHTS.size(), Bodies.BODY_TYPES.size(),\n\t\t])\n\t\tquit(0)\n\t\treturn\n\tfor error in errors:\n\t\tpush_error(error)\n\tprint("DOMAIN REGISTRY CONTRACT: FAIL (%d errors)" % errors.size())\n\tquit(1)\n''')


def add_notes() -> None:
    write("docs/architecture/MODULARITY_REFACTOR.md", '''# Modularity and efficiency refactor\n\nThis pass separates two concerns: repeated runtime work, and the cost of adding new content.\n\n## Ownership\n\n- `AttributeRegistry`: canonical ability-attribute vocabulary and category metadata.\n- `RoleProfiles`: role primary weights, approach modifiers and generation support attributes.\n- `RegionProfiles`: regional generation/development biases.\n- `BodyTypeGameplay`: body gameplay modifiers; `BodyTypeModels` stays presentation-only.\n- `PlayerGenerator`: composition pipeline consuming those profiles. Compatibility aliases remain during migration.\n- `VerticalSliceRoster`: hand-authored fixture player data, outside `GameManager`.\n- `SetterDecisionMath`: first pure setter-decision extraction from `RallySimulator`, behind compatibility wrappers.\n\n## Growth rule\n\nPrefer **definition + registration + consumer** over adding another branch to a procedural file. New attributes should be registered once, then deliberately referenced by roles/regions/bodies/training/scouting/simulation. `tools/validate_domain_registries.gd` catches dangling attribute and body references.\n\n## Runtime change\n\n`CareerManager.advance_week()` resolves the team's served food once per week and reuses it for recovery, palate progression and chef familiarity instead of reconstructing the same service for every player.\n\n## Deliberately unchanged\n\nRally formulas, RNG order, event schema and scoring are not redesigned. Declarative visual catalogues are not split merely for being large. Home/opponent resolver consolidation remains a behavior-level migration requiring phase-specific symmetry tests; it is not safe as a mechanical size refactor.\n''')


def main() -> None:
    build_domain_registries()
    consolidate_private_rng()
    extract_vertical_slice_roster()
    cache_weekly_service()
    extract_rally_pure_helpers()
    add_registry_validator()
    add_notes()
    print("modularity refactor applied")


if __name__ == "__main__":
    main()
