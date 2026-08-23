#!/usr/bin/env python3
"""Find comments that name a function or constant which no longer exists.

The house comment style explains *why*, and cites the function that did the
thing. That makes the comments unusually valuable and unusually fragile: when a
function is deleted or renamed, every comment naming it becomes a confident
statement about code that is not there.

This is the highest-precision staleness signal available without judgement.
A comment saying `_serve_arc`'s relief sweep does X is definitely wrong once
`_serve_arc` is gone, and there is nothing to argue about.

Validation cases from the serve pass, which deleted `_serve_arc`,
`_errant_serve_landing` and `_ground_to_net_meters`: comments in `ball_spin.gd`
and `attack_power_model.gd` still cite `_serve_arc` by name.

Method: collect every declared symbol -- `func`, `static func`, `const`,
`class_name`, `var`, `signal`, `enum` -- across the tree. Then scan comments for
identifiers that look like code references and report the ones nothing declares.
Deliberately conservative about what counts as a reference, since prose contains
plenty of ordinary words.

Usage:
    python3 tools/audit_stale_references.py [root ...]
"""
import re
import sys
import pathlib
from collections import defaultdict

DECL = re.compile(
    r'^\s*(?:static\s+)?(?:func|const|var|signal|enum|class_name|class)\s+([A-Za-z_]\w*)'
)
COMMENT = re.compile(r'#(.*)$')
## Only these two shapes are treated as code references, because prose is full
## of ordinary words and anything looser drowns the signal:
##   `backticked`      -- the house style for naming code in a comment
##   _leading_underscore -- unambiguously a private symbol in this codebase
BACKTICKED = re.compile(r'`([A-Za-z_][\w.]*)\s*(?:\(\))?`')
UNDERSCORED = re.compile(r'(?<![\w`])(_[a-z]\w{3,})')

## Names that are not project symbols but legitimately appear in comments.
FILE_SUFFIXES = {
    "md", "gd", "tscn", "tres", "json", "txt", "py", "csv", "png", "jpg",
    "gdshader", "uid", "docx", "html", "ttf", "sh",
}

IGNORE = {
    "_ready", "_init", "_process", "_physics_process", "_draw", "_input",
    "_notification", "_enter_tree", "_exit_tree", "_gui_input", "_to_string",
    "_get", "_set", "_unhandled_input", "_initialize", "_finalize",
}


def declared(files):
    names = set()
    for path in files:
        for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
            found = DECL.match(line)
            if found:
                names.add(found.group(1))
    return names


def references(path):
    """Yield (line_number, name, comment_text) for code-ish names in comments."""
    for number, line in enumerate(
        path.read_text(encoding="utf-8", errors="replace").splitlines(), 1
    ):
        found = COMMENT.search(line)
        if not found:
            continue
        text = found.group(1)
        seen = set()
        for name in BACKTICKED.findall(text):
            ## `Foo.bar` -- check the leaf, which is the part that gets deleted.
            ## But `SOMETHING.md` is a document, not a symbol, and its leaf is an
            ## extension; the first run reported 57 of those as dangling.
            if name.rsplit(".", 1)[-1].lower() in FILE_SUFFIXES:
                continue
            leaf = name.split(".")[-1]
            if leaf and leaf not in seen:
                seen.add(leaf)
                yield number, leaf, text.strip()
        for name in UNDERSCORED.findall(text):
            if name not in seen:
                seen.add(name)
                yield number, name, text.strip()


def main(roots):
    files = []
    for root in roots:
        base = pathlib.Path(root)
        files.extend(sorted(base.rglob("*.gd")) if base.is_dir() else [base])
    known = declared(files)
    ## Anything that appears as a bare word anywhere in the code -- a dictionary
    ## key, an exported property, a match arm -- is not a dangling reference even
    ## if it is not declared with `func` or `const`.
    corpus = "\n".join(
        p.read_text(encoding="utf-8", errors="replace") for p in files
    )
    code_only = "\n".join(
        COMMENT.sub("", line) for line in corpus.splitlines()
    )
    mentioned = set(re.findall(r'\b([A-Za-z_]\w*)\b', code_only))

    stale = defaultdict(list)
    for path in files:
        for number, name, text in references(path):
            if name in IGNORE or name in known or name in mentioned:
                continue
            stale[name].append((path, number, text))

    print("=" * 78)
    print("COMMENTS NAMING A SYMBOL THAT NO LONGER EXISTS ANYWHERE")
    print("=" * 78)
    for name in sorted(stale, key=lambda n: -len(stale[n])):
        print('\n  %s   -- %d comment(s)' % (name, len(stale[name])))
        for path, number, text in stale[name]:
            snippet = text if len(text) <= 88 else text[:85] + "..."
            print("      %s:%d" % (path, number))
            print("          %s" % snippet)
    if not stale:
        print("\n  (none)")
    print("\n%d dangling names across %d files." % (len(stale), len(files)))


if __name__ == "__main__":
    main(sys.argv[1:] or ["scripts", "scenes", "tests"])
