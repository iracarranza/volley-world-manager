#!/usr/bin/env python3
"""Find values derived from X before X is reassigned, and read after.

That is the shape of the arrival-margin defect: `hitter_arrival_margin` was
derived from `set_target`, `set_target` was then moved by `_reachable_contact`,
and the margin was read afterwards without being refreshed.

Heuristic and deliberately noisy -- it reports candidates for a human read, not
verdicts. GDScript-specific: functions start at column 0 with `func `, locals
are declared with `var`.
"""
import re
import sys
import pathlib

VAR_DECL = re.compile(r'^\s*var\s+([A-Za-z_]\w*)')
REASSIGN = re.compile(r'^\s*([A-Za-z_]\w*)\s*(?:=|\+=|-=|\*=|/=)(?!=)')
IDENT = re.compile(r'\b([A-Za-z_]\w*)\b')
FUNC = re.compile(r'^(?:static\s+)?func\s+(\w+)')

# Names that are reassigned as ordinary accumulators, not corrections.
ACCUMULATOR_HINT = re.compile(r'\+=|-=|\*=|/=')


def functions(lines):
    current, start = None, 0
    for i, line in enumerate(lines):
        m = FUNC.match(line)
        if m:
            if current:
                yield current, start, i
            current, start = m.group(1), i
    if current:
        yield current, start, len(lines)


def audit(path):
    lines = path.read_text().splitlines()
    findings = []
    for name, start, end in functions(lines):
        body = lines[start:end]
        # declaration line for each local
        declared = {}
        for i, line in enumerate(body):
            m = VAR_DECL.match(line)
            if m and m.group(1) not in declared:
                declared[m.group(1)] = i
        # reassignments (not the declaration)
        for i, line in enumerate(body):
            if line.lstrip().startswith('#'):
                continue
            m = REASSIGN.match(line)
            if not m:
                continue
            target = m.group(1)
            if target not in declared or declared[target] == i:
                continue
            if ACCUMULATOR_HINT.search(line.split('#')[0]):
                continue
            # locals derived from `target` strictly before this line
            for other, decl_line in declared.items():
                if other == target or decl_line >= i:
                    continue
                # the declaration must mention `target`
                decl_text = body[decl_line]
                # multi-line declarations: gather until brackets balance
                j, text = decl_line, decl_text
                depth = text.count('(') - text.count(')')
                while (depth > 0 or text.rstrip().endswith((',', '\\'))) and j + 1 < i:
                    j += 1
                    text += ' ' + body[j]
                    depth = text.count('(') - text.count(')')
                if target not in IDENT.findall(text):
                    continue
                # is `other` reassigned between decl and the mutation? then fine
                refreshed = any(
                    REASSIGN.match(body[k]) and REASSIGN.match(body[k]).group(1) == other
                    for k in range(i + 1, end - start)
                )
                if refreshed:
                    continue
                # is `other` read after the mutation?
                read_after = [
                    k for k in range(i + 1, end - start)
                    if other in IDENT.findall(body[k].split('#')[0])
                    and not body[k].lstrip().startswith('#')
                ]
                if not read_after:
                    continue
                findings.append((
                    name, start + i + 1, target, other,
                    start + decl_line + 1, start + read_after[0] + 1,
                    len(read_after),
                ))
    return findings


def main():
    roots = [pathlib.Path(p) for p in sys.argv[1:]] or [pathlib.Path('scripts')]
    total = 0
    for root in roots:
        for path in sorted(root.rglob('*.gd')):
            found = audit(path)
            if not found:
                continue
            print(f'\n=== {path}')
            for fn, mut, target, other, decl, first_read, n in found:
                print(f'  {fn}()  L{mut}: `{target}` reassigned')
                print(f'      `{other}` derived from it at L{decl}, '
                      f'read again at L{first_read} ({n} reads), never refreshed')
                total += 1
    print(f'\n{total} candidates')


main()
