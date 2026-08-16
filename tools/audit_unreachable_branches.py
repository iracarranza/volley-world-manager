#!/usr/bin/env python3
"""Find `match` arms whose value nothing in the codebase ever produces.

This repository's most-repeated defect is "a knob that cannot reach its own
range" -- `docs/FAILURE_MODES.md` section 0. The dead branch in
`_dig_pass_result` is the clearest instance:

    match posture:
        "off-axis": posture_penalty = 0.35
        "reaching": posture_penalty = 0.55
        "emergency", "fall": posture_penalty = 0.80   # neither is ever a posture

`"fall"` is a *recovery state*, `"emergency"` is produced nowhere at all, so the
largest penalty tier could never fire and the band calibrated against it was
calibrated against a third of its stated range. That was found by accident. This
finds the same shape on purpose.

**The first version of this file could not find it**, and that is worth keeping
written down. It required an arm to end in a colon, so it only saw arms whose
body was on the next line and missed every inline `"x": y = 1` -- which is the
form the known defect takes. It reported two findings and looked plausible. An
audit instrument that cannot reproduce the case it was built for is measuring
something else; validating against a known-true case is not optional.

Distinguishing an arm from a dictionary key needs context, since both are
`"literal":`. Brace depth does it: a dictionary entry sits inside `{...}` and a
match arm does not.

Method, deliberately noisy: collect every string literal used as a `match` arm,
then count *productions* of that literal elsewhere -- any line mentioning it that
is not itself an arm. Zero producers is a candidate, not a verdict: a string may
legitimately arrive from a save file, a scene, a resource or a `.tres`.

Usage:
    python3 tools/audit_unreachable_branches.py [root ...]
"""
import re
import sys
import pathlib
from collections import defaultdict

MATCH_LINE = re.compile(r'^\s*match\s+(.+?)\s*:\s*$')
STRING_LIST = re.compile(
    r'^\s*("(?:[^"\\]|\\.)*"(?:\s*,\s*"(?:[^"\\]|\\.)*")*)\s*,?\s*:(?!=)'
)
STRING = re.compile(r'"((?:[^"\\]|\\.)*)"')
# Strip strings and comments before counting braces, so a brace inside a literal
# does not move the depth.
STRIP = re.compile(r'"(?:[^"\\]|\\.)*"|#.*$')


def indent_of(line: str) -> int:
    return len(line) - len(line.lstrip())


def depth_delta(line: str) -> int:
    bare = STRIP.sub("", line)
    return (bare.count("{") + bare.count("(") + bare.count("[")
            - bare.count("}") - bare.count(")") - bare.count("]"))


def scan(path: pathlib.Path):
    """Return (arms, arm_lines) for one file.

    arms      -- list of (line_number, subject, [values])
    arm_lines -- set of line numbers that are match arms
    """
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    arms, arm_lines = [], set()
    stack = []  # (indent, depth, subject)
    depth = 0
    for number, line in enumerate(lines, 1):
        stripped = line.strip()
        if stripped and not stripped.startswith("#"):
            column = indent_of(line)
            while stack and (column <= stack[-1][0] or depth < stack[-1][1]):
                stack.pop()
            found = MATCH_LINE.match(line)
            if found:
                stack.append((column, depth, found.group(1)))
                depth += depth_delta(line)
                continue
            listed = STRING_LIST.match(line)
            ## An arm sits directly under its `match`, at the same brace depth.
            ## A dictionary key looks identical and is inside braces.
            if listed and stack and column > stack[-1][0] and depth == stack[-1][1]:
                arms.append((number, stack[-1][2], STRING.findall(listed.group(1))))
                arm_lines.add(number)
        depth += depth_delta(line)
    return arms, arm_lines


def main(roots):
    files = []
    for root in roots:
        base = pathlib.Path(root)
        files.extend(sorted(base.rglob("*.gd")) if base.is_dir() else [base])

    arms = defaultdict(list)          # value -> [(path, line, subject)]
    arm_lines = {}                    # path -> {line numbers}
    corpus = {}
    for path in files:
        corpus[path] = path.read_text(encoding="utf-8", errors="replace").splitlines()
        found, lines = scan(path)
        arm_lines[path] = lines
        for number, subject, values in found:
            for value in values:
                arms[value].append((path, number, subject))

    def producers(value):
        quoted = '"%s"' % value
        total = 0
        where = []
        for path, lines in corpus.items():
            for number, raw in enumerate(lines, 1):
                if number in arm_lines[path]:
                    continue
                text = raw.strip()
                if not text or text.startswith("#") or quoted not in text:
                    continue
                total += 1
                where.append("%s:%d" % (path, number))
        return total, where

    dead, thin = [], []
    for value, sites in sorted(arms.items()):
        count, where = producers(value)
        if count == 0:
            dead.append((value, sites))
        elif count == 1:
            thin.append((value, sites, where))

    print("=" * 78)
    print("NEVER PRODUCED -- no line outside a match arm mentions this literal")
    print("=" * 78)
    for value, sites in dead:
        print('\n  "%s"' % value)
        for path, number, subject in sites:
            print("      %s:%d   match %s" % (path, number, subject))
    if not dead:
        print("\n  (none)")

    print("\n" + "=" * 78)
    print("PRODUCED ONCE -- the single producer may itself be unreachable")
    print("=" * 78)
    for value, sites, where in thin:
        print('\n  "%s"   produced at %s' % (value, ", ".join(where)))
        for path, number, subject in sites:
            print("      %s:%d   match %s" % (path, number, subject))
    if not thin:
        print("\n  (none)")

    print("\n%d distinct match-arm values across %d files; "
          "%d never produced, %d produced once."
          % (len(arms), len(files), len(dead), len(thin)))


if __name__ == "__main__":
    main(sys.argv[1:] or ["scripts", "scenes"])
