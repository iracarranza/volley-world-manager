#!/usr/bin/env python3
"""Find numeric constants that decide something and were never measured.

The other half of `docs/FAILURE_MODES.md` §0. The `match`-arm sweep in
`audit_unreachable_branches.py` catches a *branch* nothing can reach; this
catches a *threshold* that may sit outside the distribution it acts on.

There is no static way to know whether a threshold is inside its distribution --
that needs a runtime measurement per constant, and the simulation carries
hundreds. So this reports the proxy that is available: **a constant that appears
in exactly one comparison, and which no test and no probe has ever named.**

That combination is the profile of every §0 defect this repository has found:

- `SERVE_PACE_RELIEF_FLOOR` -- one comparison, never measured, stopped the
  search before the serve became feasible;
- the flat serve net-clearance margin -- one comparison, never measured, sat
  where a function belonged;
- `RECOVERY_HEAVY_FORCE` -- its own comment records the threshold landing outside
  the range force could reach, so no ball in the game could knock anyone down.

A constant that a gate reads by name has been thought about. One that only ever
appears in a single `if` has not necessarily been.

Reports candidates for a human to measure. It cannot tell a well-chosen constant
from a badly chosen one -- only which ones nothing has looked at.

Usage:
    python3 tools/audit_unmeasured_constants.py [root ...]
"""
import re
import sys
import pathlib
from collections import defaultdict

CONST = re.compile(r'^\s*const\s+([A-Z][A-Z0-9_]{3,})\s*:\s*(float|int)\s*=')
COMPARISON = re.compile(r'[<>]=?|is_zero_approx|is_equal_approx|clampf?\(|maxf?\(|minf?\(')
COMMENT_ONLY = re.compile(r'^\s*#')


def declarations(files):
    """name -> (path, line, type)"""
    found = {}
    for path in files:
        for number, line in enumerate(
            path.read_text(encoding="utf-8", errors="replace").splitlines(), 1
        ):
            hit = CONST.match(line)
            if hit:
                found[hit.group(1)] = (path, number, hit.group(2))
    return found


UPPER = re.compile(r'\b([A-Z][A-Z0-9_]{3,})\b')


def usage(files, names):
    """name -> {'reads': n, 'compares': n, 'lines': [...]}

    One pass over the corpus extracting the upper-case identifiers on each line,
    rather than one regex search per constant per line. The first version was the
    latter and did not finish inside two minutes on 224 files against several
    hundred constants.
    """
    wanted = set(names)
    stats = {n: {"reads": 0, "compares": 0, "lines": []} for n in names}
    for path in files:
        for number, line in enumerate(
            path.read_text(encoding="utf-8", errors="replace").splitlines(), 1
        ):
            if COMMENT_ONLY.match(line) or CONST.match(line):
                continue
            code = line.split("#", 1)[0]
            compares = bool(COMPARISON.search(code))
            for name in set(UPPER.findall(code)) & wanted:
                stats[name]["reads"] += 1
                stats[name]["lines"].append("%s:%d" % (path, number))
                if compares:
                    stats[name]["compares"] += 1
    return stats


def main(roots):
    source, witnesses = [], []
    for root in roots:
        base = pathlib.Path(root)
        found = sorted(base.rglob("*.gd")) if base.is_dir() else [base]
        ## A test or a probe naming a constant is evidence somebody measured it.
        if base.name in ("tests", "tools"):
            witnesses.extend(found)
        else:
            source.extend(found)

    declared = declarations(source)
    names = list(declared)
    used = usage(source, names)

    ## Anything a test or probe mentions, in code or in prose -- prose counts,
    ## because a comment quoting a measured figure is the measurement's record.
    witness_text = "\n".join(
        p.read_text(encoding="utf-8", errors="replace") for p in witnesses
    )
    watched = set(UPPER.findall(witness_text)) & set(names)

    candidates = []
    for name in names:
        stats = used[name]
        if stats["compares"] == 1 and stats["reads"] <= 2 and name not in watched:
            candidates.append(name)

    by_file = defaultdict(list)
    for name in candidates:
        path, number, kind = declared[name]
        by_file[path].append((number, name, kind, used[name]["lines"]))

    print("=" * 78)
    print("DECIDES ONE THING, AND NOTHING HAS EVER MEASURED IT")
    print("=" * 78)
    for path in sorted(by_file):
        print("\n  %s" % path)
        for number, name, kind, lines in sorted(by_file[path]):
            print("      L%-6d %-42s %-5s  read at %s"
                  % (number, name, kind, ", ".join(lines) or "(nowhere)"))

    print("\n  %d constants declared, %d named by a test or probe, "
          "%d candidates." % (len(names), len(watched), len(candidates)))
    print("\n  A candidate is not a defect. It is a constant whose distribution")
    print("  nobody has looked at, which is where every §0 defect has come from.")


if __name__ == "__main__":
    main(sys.argv[1:] or ["scripts", "scenes", "tests", "tools"])
