#!/usr/bin/env python3
"""Inventory repository evidence required for Practical Reach shadow analysis.

This preflight intentionally does not synthesize missing world observations.  It
is useful before a seed comparison because a missing input is evidence about the
measurement boundary, not permission to replace that input with a fixture.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


REQUIRED_DOCUMENTS = (
    "maps.md",
    "objectives.md",
    "infrastructure.md",
    "classes.md",
    "docs/manuscript/2026-09-14-Economic-Calibration-Supplement.md",
    "docs/manuscript/2026-09-14-UAU-Work-Stock-and-Practical-Reach.md",
)
SEEDS = ("930010639", "930012642")
CAPABILITIES = {
    "resource_or_ore": ("ore", "deposit", "resource field"),
    "cave": ("cave",),
    "terrain_graph": ("terrain graph", "pathfinding", "travel cost"),
    "biome_or_ecology": ("biome", "ecology"),
    "structure_or_village": ("village", "structure", "poi"),
    "water": ("water", "coast", "ocean"),
    "homeland_depth": ("homeland depth",),
    "starter_route_or_handoff": ("starter route", "handoff"),
    "opportunity_relationship": ("opportunity relationship",),
}
TEXT_SUFFIXES = {".md", ".txt", ".json", ".gd", ".py", ".csv", ".tscn"}
SELF_PATHS = {
    "tools/audit_shadow_economic_inputs.py",
    "tests/test_audit_shadow_economic_inputs.py",
    "artifacts/shadow-economic-revalidation/2026-09-15-input-inventory.json",
    "docs/calibration/SHADOW_ECONOMIC_PRACTICAL_REACH_2026_09_15.md",
}


def _text_files(root: Path) -> list[Path]:
    excluded = {".git", ".godot"}
    return sorted(
        path
        for path in root.rglob("*")
        if path.is_file()
        and path.suffix.lower() in TEXT_SUFFIXES
        and not excluded.intersection(path.parts)
    )


def inventory(root: Path) -> dict:
    files = _text_files(root)
    searchable: list[tuple[str, str]] = []
    for path in files:
        try:
            relative = path.relative_to(root).as_posix()
            if relative in SELF_PATHS:
                continue
            searchable.append((relative, path.read_text(errors="replace").lower()))
        except OSError:
            continue

    required = {
        relative: {"present": (root / relative).is_file()}
        for relative in REQUIRED_DOCUMENTS
    }
    seed_records = {
        seed: sorted(name for name, text in searchable if seed in text)
        for seed in SEEDS
    }
    # Restrict capability discovery to the requested domain.  Generic words such
    # as "resource" and "opportunity" occur throughout unrelated projects and
    # are not evidence of Minecraft world observability.
    domain_files = [
        item for item in searchable
        if "minecraft" in item[1] or any(seed in item[1] for seed in SEEDS)
    ]
    capabilities = {}
    for name, terms in CAPABILITIES.items():
        matches = sorted(
            filename
            for filename, text in domain_files
            if any(term in text for term in terms)
        )
        capabilities[name] = {"observable": bool(matches), "evidence_files": matches}

    missing_documents = [name for name, result in required.items() if not result["present"]]
    missing_seed_records = [seed for seed, matches in seed_records.items() if not matches]
    ready = not missing_documents and not missing_seed_records
    return {
        "schema_version": 1,
        "analysis_kind": "SHADOW economic / Practical Reach input preflight",
        "repository_root": ".",
        "seeds": list(SEEDS),
        "required_documents": required,
        "seed_record_files": seed_records,
        "capability_keyword_inventory": capabilities,
        "measurement_ready": ready,
        "blocking_inputs": {
            "missing_documents": missing_documents,
            "missing_seed_records": missing_seed_records,
        },
        "guardrail": (
            "A false capability or missing record must remain UNRESOLVED; this audit "
            "does not authorize inferred world facts or analytical substitutes."
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    result = inventory(args.root.resolve())
    encoded = json.dumps(result, indent=2, sort_keys=True) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(encoded)
    else:
        print(encoded, end="")
    return 0 if result["measurement_ready"] else 2


if __name__ == "__main__":
    raise SystemExit(main())
