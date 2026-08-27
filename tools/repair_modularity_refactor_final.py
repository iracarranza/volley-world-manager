#!/usr/bin/env python3
from __future__ import annotations

import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = "origin/claude/m8-visual-continuity"


def original(path: str) -> str:
    return subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT, text=True)


def write(path: str, text: str) -> None:
    target = ROOT / path
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(text, encoding="utf-8")


def const_span(source: str, name: str) -> tuple[int, int, str]:
    """Return exactly one GDScript const declaration, never following functions/docs."""
    match = re.search(
        rf"(?m)^const\s+{re.escape(name)}(?:\s*:\s*[^=\n]+)?\s*(?::=|=)\s*",
        source,
    )
    if not match:
        raise RuntimeError(f"constant not found: {name}")
    start = match.start()
    value_start = match.end()
    while value_start < len(source) and source[value_start] in " \t":
        value_start += 1
    first = source[value_start] if value_start < len(source) else ""
    pairs = {"{": "}", "[": "]", "(": ")"}
    if first in pairs:
        stack = [pairs[first]]
        i = value_start + 1
        quote = None
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
                if ch in ('"', "'"):
                    quote = ch
                elif ch in pairs:
                    stack.append(pairs[ch])
                elif stack and ch == stack[-1]:
                    stack.pop()
                    if not stack:
                        end = i + 1
                        if end < len(source) and source[end] == "\n":
                            end += 1
                        return start, end, source[start:end].rstrip()
            i += 1
        raise RuntimeError(f"unterminated constant: {name}")

    # Scalar/string expression: consume physical lines only while explicitly continued.
    line_end = source.find("\n", value_start)
    if line_end < 0:
        line_end = len(source)
    end = line_end
    while source[source.rfind("\n", start, end) + 1:end].rstrip().endswith("\\"):
        next_end = source.find("\n", end + 1)
        end = len(source) if next_end < 0 else next_end
    if end < len(source):
        end += 1
    return start, end, source[start:end].rstrip()


def const_text(source: str, name: str) -> str:
    return const_span(source, name)[2]


def replace_const(source: str, name: str, replacement: str) -> str:
    start, end, _ = const_span(source, name)
    return source[:start] + replacement.rstrip() + "\n" + source[end:]


def inject_after_extends(source: str, lines: list[str]) -> str:
    missing = [line for line in lines if line not in source]
    if not missing:
        return source
    match = re.search(r"(?m)^extends\s+[^\n]+\n", source)
    if not match:
        raise RuntimeError("extends line not found")
    return source[:match.end()] + "\n" + "\n".join(missing) + "\n" + source[match.end():]


def function_span(source: str, name: str) -> tuple[int, int, str]:
    match = re.search(rf"(?m)^(?:static\s+)?func\s+{re.escape(name)}\b", source)
    if not match:
        raise RuntimeError(f"function not found: {name}")
    next_match = re.search(r"(?m)^(?:static\s+)?func\s+[_A-Za-z0-9]+\b", source[match.end():])
    end = match.end() + next_match.start() if next_match else len(source)
    return match.start(), end, source[match.start():end].rstrip() + "\n"


def replace_function(source: str, name: str, replacement: str) -> str:
    start, end, _ = function_span(source, name)
    return source[:start] + replacement.rstrip() + "\n\n\n" + source[end:]


def build_registries(base_gen: str, base_player: str) -> None:
    ability = const_text(base_player, "ABILITY_ATTRIBUTES")
    physical = const_text(base_gen, "PHYSICAL_ATTRIBUTES")
    mental = const_text(base_gen, "MENTAL_ATTRIBUTES")
    write("scripts/domain/attribute_registry.gd", f'''class_name AttributeRegistry
extends RefCounted

## Canonical player-attribute vocabulary and metadata. Gameplay formulas stay in
## their owning systems; this registry makes integration points auditable.

{ability}

{physical}

{mental}

## Player traits which generation/profile data may reference but which are not
## trainable ability attributes. Leadership acts on teammates; ego is temperament.
const NON_ABILITY_TRAITS: Array[String] = ["leadership", "ego"]

static func all_ids() -> Array[String]:
\treturn ABILITY_ATTRIBUTES.duplicate()

static func all_player_traits() -> Array[String]:
\tvar result: Array[String] = ABILITY_ATTRIBUTES.duplicate()
\tfor trait in NON_ABILITY_TRAITS:
\t\tif trait not in result:
\t\t\tresult.append(trait)
\treturn result

static func category_of(attribute_id: String) -> String:
\tif attribute_id in PHYSICAL_ATTRIBUTES:
\t\treturn "Physical"
\tif attribute_id in MENTAL_ATTRIBUTES:
\t\treturn "Mental"
\tif attribute_id in NON_ABILITY_TRAITS:
\t\treturn "Temperament"
\treturn "Technical"

static func definition(attribute_id: String) -> Dictionary:
\treturn {{
\t\t"id": attribute_id,
\t\t"category": category_of(attribute_id),
\t\t"trainable": attribute_id in ABILITY_ATTRIBUTES,
\t\t"scoutable": attribute_id in all_player_traits(),
\t}}
''')

    region_names = [
        "REGION_HEIGHT_BIAS", "REGION_MASS_BIAS", "REGION_WINGSPAN_BIAS",
        "REGION_SPECIALTY", "REGION_EGO_BIAS", "REGION_AGGRESSION_BIAS",
        "REGION_CEILING_PENALTY",
    ]
    region_parts = [const_text(base_gen, name) for name in region_names]
    write("scripts/domain/region_profiles.gd", '''class_name RegionProfiles
extends RefCounted

## Canonical region inputs for player generation/development. Region definitions
## live here; PlayerGenerator only composes them.

''' + "\n\n".join(region_parts) + '''

static func specialty(region_name: String) -> Array:
\treturn Array(REGION_SPECIALTY.get(region_name, []))

static func physique(region_name: String) -> Dictionary:
\treturn {
\t\t"height": float(REGION_HEIGHT_BIAS.get(region_name, 0.0)),
\t\t"mass": float(REGION_MASS_BIAS.get(region_name, 0.0)),
\t\t"wingspan": float(REGION_WINGSPAN_BIAS.get(region_name, 0.0)),
\t}
''')

    role_parts = [
        const_text(base_player, "POSITION_WEIGHTS"),
        const_text(base_player, "POSITION_APPROACH_STEP_MODIFIER"),
        const_text(base_player, "POSITION_APPROACH_TOLERANCE_MODIFIER"),
        const_text(base_gen, "POSITIONS"),
        const_text(base_gen, "ROLE_SECONDARY"),
        const_text(base_gen, "ROLE_HEIGHT_SPREAD"),
        const_text(base_gen, "POSITION_EGO_BIAS"),
        const_text(base_gen, "POSITION_LEADERSHIP_BIAS"),
        const_text(base_gen, "POSITION_AGGRESSION_BIAS"),
    ]
    write("scripts/domain/role_profiles.gd", '''class_name RoleProfiles
extends RefCounted

## Canonical role profile data shared by player scoring and generation. Situation
## capability remains in capability systems rather than becoming a role permission.

''' + "\n\n".join(role_parts) + '''

static func primary_attributes(role_name: String) -> Array:
\treturn Array(POSITION_WEIGHTS.get(role_name, []))

static func secondary_attributes(role_name: String) -> Array:
\treturn Array(ROLE_SECONDARY.get(role_name, []))
''')

    body_parts = [
        const_text(base_gen, "BODY_TYPES"),
        const_text(base_gen, "BODY_TYPE_METRICS"),
        const_text(base_gen, "BODY_TYPE_ATTRIBUTES"),
    ]
    write("scripts/domain/body_type_gameplay.gd", '''class_name BodyTypeGameplay
extends RefCounted

## Gameplay-side body definitions. Presentation remains in BodyTypeModels; the
## shared body key is validated in CI.

''' + "\n\n".join(body_parts) + '''

static func attribute_modifiers(body_type: String) -> Dictionary:
\treturn Dictionary(BODY_TYPE_ATTRIBUTES.get(body_type, {}))

static func metric_modifiers(body_type: String) -> Dictionary:
\treturn Dictionary(BODY_TYPE_METRICS.get(body_type, {}))
''')


def refactor_player_generator(base_gen: str) -> None:
    source = inject_after_extends(base_gen, [
        'const AttributeRegistry := preload("res://scripts/domain/attribute_registry.gd")',
        'const RegionProfiles := preload("res://scripts/domain/region_profiles.gd")',
        'const RoleProfiles := preload("res://scripts/domain/role_profiles.gd")',
        'const BodyTypeGameplay := preload("res://scripts/domain/body_type_gameplay.gd")',
    ])
    aliases = {
        "POSITIONS": "RoleProfiles.POSITIONS",
        "REGION_HEIGHT_BIAS": "RegionProfiles.REGION_HEIGHT_BIAS",
        "REGION_MASS_BIAS": "RegionProfiles.REGION_MASS_BIAS",
        "REGION_WINGSPAN_BIAS": "RegionProfiles.REGION_WINGSPAN_BIAS",
        "REGION_SPECIALTY": "RegionProfiles.REGION_SPECIALTY",
        "ROLE_SECONDARY": "RoleProfiles.ROLE_SECONDARY",
        "ROLE_HEIGHT_SPREAD": "RoleProfiles.ROLE_HEIGHT_SPREAD",
        "BODY_TYPES": "BodyTypeGameplay.BODY_TYPES",
        "BODY_TYPE_METRICS": "BodyTypeGameplay.BODY_TYPE_METRICS",
        "BODY_TYPE_ATTRIBUTES": "BodyTypeGameplay.BODY_TYPE_ATTRIBUTES",
        "REGION_EGO_BIAS": "RegionProfiles.REGION_EGO_BIAS",
        "POSITION_EGO_BIAS": "RoleProfiles.POSITION_EGO_BIAS",
        "POSITION_LEADERSHIP_BIAS": "RoleProfiles.POSITION_LEADERSHIP_BIAS",
        "REGION_AGGRESSION_BIAS": "RegionProfiles.REGION_AGGRESSION_BIAS",
        "POSITION_AGGRESSION_BIAS": "RoleProfiles.POSITION_AGGRESSION_BIAS",
        "REGION_CEILING_PENALTY": "RegionProfiles.REGION_CEILING_PENALTY",
        "PHYSICAL_ATTRIBUTES": "AttributeRegistry.PHYSICAL_ATTRIBUTES",
        "MENTAL_ATTRIBUTES": "AttributeRegistry.MENTAL_ATTRIBUTES",
    }
    for name, target in aliases.items():
        source = replace_const(source, name, f"const {name} = {target}")

    helper_marker = "static func assign_body_type(player: VolleyballPlayer, rng: RandomNumberGenerator) -> void:"
    helper_pos = source.find(helper_marker)
    if helper_pos < 0:
        raise RuntimeError("assign_body_type marker missing")
    helper = '''static func _player_channel_rng(
\tbase_rng: RandomNumberGenerator,
\tplayer: VolleyballPlayer,
\tregion_name: String,
\tchannel: String,
) -> RandomNumberGenerator:
\t## Stable private stream: adding/tuning one temperament channel must not
\t## advance the shared roster RNG and silently reroll unrelated attributes.
\tvar result := RandomNumberGenerator.new()
\tresult.seed = hash("%d|%s|%d|%s" % [
\t\tbase_rng.seed, channel, player.id, region_name,
\t])
\treturn result


'''
    source = source[:helper_pos] + helper + source[helper_pos:]

    # Normalize only the known independent channels. The produced seed string is
    # byte-for-byte equivalent to the original channel-specific expression.
    for channel in ("leadership", "ego", "aggression"):
        pattern = re.compile(
            rf"var\s+({channel}_rng)\s*:=\s*RandomNumberGenerator\.new\(\)\n"
            rf"\s*\1\.seed\s*=\s*hash\(\"%d\|{channel}\|%d\|%s\"\s*%\s*\["
            rf"(?P<body>[^\]]*?)\]\s*\)",
            re.MULTILINE,
        )
        source, _ = pattern.subn(
            rf'var \1 := _player_channel_rng(rng, player, region_name, "{channel}")',
            source,
        )
    if "static func _apply_attributes(" not in source:
        raise RuntimeError("restored generator lost _apply_attributes")
    write("scripts/systems/player_generator.gd", source)


def refactor_player(base_player: str) -> None:
    source = inject_after_extends(base_player, [
        'const AttributeRegistry := preload("res://scripts/domain/attribute_registry.gd")',
        'const RoleProfiles := preload("res://scripts/domain/role_profiles.gd")',
    ])
    source = replace_const(source, "ABILITY_ATTRIBUTES", "const ABILITY_ATTRIBUTES = AttributeRegistry.ABILITY_ATTRIBUTES")
    source = replace_const(source, "POSITION_WEIGHTS", "const POSITION_WEIGHTS = RoleProfiles.POSITION_WEIGHTS")
    source = replace_const(source, "POSITION_APPROACH_STEP_MODIFIER", "const POSITION_APPROACH_STEP_MODIFIER = RoleProfiles.POSITION_APPROACH_STEP_MODIFIER")
    source = replace_const(source, "POSITION_APPROACH_TOLERANCE_MODIFIER", "const POSITION_APPROACH_TOLERANCE_MODIFIER = RoleProfiles.POSITION_APPROACH_TOLERANCE_MODIFIER")
    write("scripts/models/volleyball_player.gd", source)


def refactor_game_manager(base_game: str) -> None:
    source = inject_after_extends(base_game, [
        'const VerticalSliceRoster := preload("res://scripts/data/vertical_slice_roster.gd")',
    ])
    fn_start = source.find("func seed_vertical_slice_data() -> void:")
    team_marker = source.find("\n\tteam = TeamScript.new()", fn_start)
    first = source.find("\n\tplayers.append(_make_player(", fn_start, team_marker)
    if min(fn_start, team_marker, first) < 0:
        raise RuntimeError("vertical slice markers missing")
    block = source[first:team_marker]
    if block.count("players.append(_make_player(") < 6:
        raise RuntimeError("unexpected vertical slice roster size")
    module_block = block.replace("players.append(_make_player(", "players.append(make_player.call(")
    write("scripts/data/vertical_slice_roster.gd", '''class_name VerticalSliceRoster
extends RefCounted

## Hand-authored development fixture roster. Kept outside GameManager so the
## runtime coordinator does not also own hundreds of lines of seed data.
static func make_players(make_player: Callable) -> Array[VolleyballPlayer]:
\tvar players: Array[VolleyballPlayer] = []
''' + module_block.lstrip("\n") + "\n\treturn players\n")
    source = source[:first] + '\n\tplayers.append_array(VerticalSliceRoster.make_players(Callable(self, "_make_player")))' + source[team_marker:]
    write("scripts/managers/game_manager.gd", source)


def refactor_career_manager(base_career: str) -> None:
    source = base_career
    marker = "\n\tfor player in _game_manager().players:\n\t\t## Weekly recovery must exceed every training load."
    pos = source.find(marker)
    if pos < 0:
        raise RuntimeError("weekly recovery loop marker missing")
    source = source[:pos] + '\n\tvar weekly_service := _week_service(str(career.region), int(career.absolute_week))' + source[pos:]
    source = source.replace(
        "recover_weekly_fatigue(player, _weekly_recovery_share(player))",
        "recover_weekly_fatigue(player, _weekly_recovery_share(player, weekly_service))", 1,
    )
    source = source.replace("_advance_weekly_palate(player)", "_advance_weekly_palate(player, weekly_service)", 1)
    source = source.replace(
        'var served_now: Dictionary = _week_service(\n\t\t\tstr(career.region), int(career.absolute_week)\n\t\t)',
        "var served_now: Dictionary = weekly_service", 1,
    )
    source = source.replace(
        "func _weekly_recovery_share(player: VolleyballPlayer) -> float:",
        "func _weekly_recovery_share(\n\tplayer: VolleyballPlayer, served_override: Dictionary = {},\n) -> float:", 1,
    )
    first_service = source.find("var served: Dictionary = _week_service(club_region, week)", source.find("func _weekly_recovery_share"))
    if first_service < 0:
        raise RuntimeError("weekly recovery service derivation missing")
    old = "var served: Dictionary = _week_service(club_region, week)"
    new = "var served: Dictionary = served_override if not served_override.is_empty() else _week_service(club_region, week)"
    source = source[:first_service] + source[first_service:].replace(old, new, 1)
    source = source.replace(
        "func _advance_weekly_palate(player: VolleyballPlayer) -> void:",
        "func _advance_weekly_palate(\n\tplayer: VolleyballPlayer, served_override: Dictionary = {},\n) -> void:", 1,
    )
    palate_pos = source.find(old, source.find("func _advance_weekly_palate"))
    if palate_pos < 0:
        raise RuntimeError("palate service derivation missing")
    source = source[:palate_pos] + source[palate_pos:].replace(old, new, 1)
    write("scripts/managers/career_manager.gd", source)


def refactor_rally(base_rally: str) -> None:
    source = inject_after_extends(base_rally, [
        'const SetterDecisionMath := preload("res://scripts/simulation/setter_decision_math.gd")',
    ])
    _, _, rescue = function_span(base_rally, "_set_rescue_height_meters")
    _, _, difficulty = function_span(base_rally, "_set_height_difficulty")
    module = '''class_name SetterDecisionMath
extends RefCounted

## Pure setter-option geometry extracted without changing formulas or RNG order.

''' + rescue.replace("static func _set_rescue_height_meters", "static func rescue_height_meters", 1) + "\n" + difficulty.replace("static func _set_height_difficulty", "static func set_height_difficulty", 1)
    write("scripts/simulation/setter_decision_math.gd", module)
    source = replace_function(source, "_set_rescue_height_meters", '''static func _set_rescue_height_meters(
\ttravel_time: float, ordinary_flight_time: float
) -> float:
\treturn SetterDecisionMath.rescue_height_meters(travel_time, ordinary_flight_time)''')
    source = replace_function(source, "_set_height_difficulty", '''static func _set_height_difficulty(
\tsetter: VolleyballPlayer, rescue_height_meters: float
) -> float:
\treturn SetterDecisionMath.set_height_difficulty(setter, rescue_height_meters)''')
    write("scripts/simulation/rally_simulator.gd", source)


def validator() -> None:
    write("tools/validate_domain_registries.gd", '''extends SceneTree

const Attributes := preload("res://scripts/domain/attribute_registry.gd")
const Regions := preload("res://scripts/domain/region_profiles.gd")
const Roles := preload("res://scripts/domain/role_profiles.gd")
const Bodies := preload("res://scripts/domain/body_type_gameplay.gd")
const BodyPresentation := preload("res://scripts/data/body_type_models.gd")

func _initialize() -> void:
\tvar errors: Array[String] = []
\tvar known := Attributes.all_player_traits()
\tfor region_name in Regions.REGION_SPECIALTY:
\t\tfor attribute in Array(Regions.REGION_SPECIALTY[region_name]):
\t\t\tif str(attribute) not in known:
\t\t\t\terrors.append("region %s references unknown player trait %s" % [region_name, attribute])
\tfor role_name in Roles.POSITION_WEIGHTS:
\t\tfor attribute in Array(Roles.POSITION_WEIGHTS[role_name]):
\t\t\tif str(attribute) not in known:
\t\t\t\terrors.append("role %s primary references unknown player trait %s" % [role_name, attribute])
\tfor role_name in Roles.ROLE_SECONDARY:
\t\tfor attribute in Array(Roles.ROLE_SECONDARY[role_name]):
\t\t\tif str(attribute) not in known:
\t\t\t\terrors.append("role %s secondary references unknown player trait %s" % [role_name, attribute])
\tfor body_name in Bodies.BODY_TYPE_ATTRIBUTES:
\t\tfor attribute in Dictionary(Bodies.BODY_TYPE_ATTRIBUTES[body_name]):
\t\t\tif str(attribute) not in known:
\t\t\t\terrors.append("body %s references unknown player trait %s" % [body_name, attribute])
\tfor body_name in Bodies.BODY_TYPES:
\t\tif str(body_name) not in BodyPresentation.MODELLED:
\t\t\terrors.append("gameplay body %s has no presentation model" % body_name)
\tfor body_name in BodyPresentation.MODELLED:
\t\tif str(body_name) not in Bodies.BODY_TYPES:
\t\t\terrors.append("presentation body %s has no gameplay definition" % body_name)
\tif errors.is_empty():
\t\tprint("DOMAIN REGISTRY CONTRACT: PASS (%d abilities, %d regions, %d roles, %d bodies)" % [
\t\t\tAttributes.all_ids().size(), Regions.REGION_SPECIALTY.size(),
\t\t\tRoles.POSITION_WEIGHTS.size(), Bodies.BODY_TYPES.size(),
\t\t])
\t\tquit(0)
\t\treturn
\tfor error in errors:
\t\tpush_error(error)
\tprint("DOMAIN REGISTRY CONTRACT: FAIL (%d errors)" % errors.size())
\tquit(1)
''')


def notes() -> None:
    write("docs/architecture/MODULARITY_REFACTOR.md", '''# Modularity and efficiency refactor

This pass targets both repeated runtime work and the cost of adding new content.

## New ownership boundaries

- `AttributeRegistry` owns the canonical ability/trait vocabulary and metadata.
- `RoleProfiles` owns role scoring/development profile data.
- `RegionProfiles` owns regional player-generation/development profile data.
- `BodyTypeGameplay` owns body gameplay modifiers; `BodyTypeModels` remains presentation-only.
- `PlayerGenerator` composes those definitions rather than authoring them.
- `VerticalSliceRoster` owns hand-authored fixture player data outside `GameManager`.
- `SetterDecisionMath` is the first pure setter-decision extraction from `RallySimulator`.

## Growth rule

Prefer **definition + registration + consumer** over adding another branch to an unrelated procedural file. A new attribute should be registered once, then deliberately referenced by role/region/body/training/scouting/simulation consumers. `tools/validate_domain_registries.gd` catches dangling trait and body references.

Roles describe weighting and development, not blanket permissions. Situation-specific ability remains in capability systems (`SetterCapabilitySystem`, attack eligibility, etc.), so unusual players can participate without acquiring the wrong roster label.

## Runtime change

`CareerManager.advance_week()` resolves the club's served food once and reuses that immutable team/week result for recovery, palate progression and chef familiarity instead of reconstructing the same service for every player.

## Deliberately incremental

Rally formulas, RNG order, event schema and scoring are unchanged. Declarative visual catalogues are not split merely for being large. Full home/opponent resolver unification is a behavior migration, not a mechanical file-size change; it should proceed phase-by-phase behind symmetry tests rather than risking the authoritative rally model in this refactor.
''')


def main() -> None:
    base_gen = original("scripts/systems/player_generator.gd")
    base_player = original("scripts/models/volleyball_player.gd")
    build_registries(base_gen, base_player)
    refactor_player_generator(base_gen)
    refactor_player(base_player)
    refactor_game_manager(original("scripts/managers/game_manager.gd"))
    refactor_career_manager(original("scripts/managers/career_manager.gd"))
    refactor_rally(original("scripts/simulation/rally_simulator.gd"))
    validator()
    notes()
    print("final modularity/efficiency repair applied")


if __name__ == "__main__":
    main()
