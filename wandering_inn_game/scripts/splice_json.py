#!/usr/bin/env python3
"""Format-preserving append of one record into a shipped JSON container.

Why this exists (2026-07-17 retrospective): hand-rolled tail-anchor splices
kept re-deriving each file's indent style, and one silently nested ten
sprite records INSIDE the last existing entry (parse-valid, structurally
wrong). Serializer round-trips are equally banned for shipped JSON (#133
churn/em-dash trap). This tool does the one safe thing: locate the named
top-level container with a string-aware bracket scan, splice the new
record before its closing bracket with indentation cloned from the last
sibling, then PROVE placement (parse + top-level path + sibling count +
byte-identity outside the splice).

Usage:
  splice_json.py --file data/skills.json --container skills \
      --record '{"id": "x", ...}'            # array container: append
  splice_json.py --file data/sprites.json --container-dict \
      --key wolf_pup --record '{...}'        # top-level dict: add key
  --record-file path.json  instead of --record
  --dry-run  prints the would-be splice region and exits.

The record is re-indented to match the container's last sibling. Exits
non-zero (file untouched) on any verification failure.
"""
import argparse
import json
import sys


def scan_container_span(text: str, open_ch: str, close_ch: str, start: int):
    """Return (open_idx, close_idx) of the bracket pair starting at/after
    `start`, skipping string literals and escapes."""
    depth = 0
    in_str = False
    esc = False
    open_idx = -1
    for i in range(start, len(text)):
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            continue
        if c == '"':
            in_str = True
        elif c == open_ch:
            if depth == 0:
                open_idx = i
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return open_idx, i
    raise SystemExit("splice_json: unbalanced %s%s scan" % (open_ch, close_ch))


def last_sibling_indent(text: str, open_idx: int, close_idx: int) -> str:
    """Indent of the line that opens the LAST direct child in the span."""
    depth = 0
    in_str = False
    esc = False
    last_child_start = -1
    for i in range(open_idx + 1, close_idx):
        c = text[i]
        if in_str:
            if esc:
                esc = False
            elif c == "\\":
                esc = True
            elif c == '"':
                in_str = False
            continue
        if c == '"':
            in_str = True
            if depth == 0 and last_child_start == -1:
                last_child_start = i
        elif c in "[{":
            # -1 guard: a dict child STARTS at its key string; the value's
            # own brace on the same line must not overwrite that position.
            if depth == 0 and last_child_start == -1:
                last_child_start = i
            depth += 1
        elif c in "]}":
            depth -= 1
        elif depth == 0 and c == ",":
            last_child_start = -1  # next child (if any) will reset it
    if last_child_start == -1:
        raise SystemExit("splice_json: container has no existing sibling to clone indent from")
    line_start = text.rfind("\n", 0, last_child_start) + 1
    return text[line_start:last_child_start]


def reindent(record: str, indent: str) -> str:
    obj = json.loads(record)  # validates the record itself
    unit = "\t" if indent.startswith("\t") else " " * max(1, len(indent) // max(1, indent.count(" ")) if indent else 1)
    # Render with a 1-unit relative indent, then prefix every line.
    rendered = json.dumps(obj, indent=1, ensure_ascii=False)
    if unit == "\t":
        rendered = rendered.replace(" ", "\t", 0)
        lines = rendered.split("\n")
        out = [lines[0]]
        for ln in lines[1:]:
            stripped = ln.lstrip(" ")
            depth = len(ln) - len(stripped)
            out.append("\t" * depth + stripped)
        rendered = "\n".join(out)
    lines = rendered.split("\n")
    return ("\n".join(indent + ln for ln in lines)).lstrip()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", required=True)
    ap.add_argument("--container", help="top-level ARRAY key to append into")
    ap.add_argument("--container-dict", action="store_true", help="file's top level IS the dict; add --key")
    ap.add_argument("--key", help="new key name (dict mode)")
    ap.add_argument("--record")
    ap.add_argument("--record-file")
    ap.add_argument("--dry-run", action="store_true")
    args = ap.parse_args()

    if bool(args.record) == bool(args.record_file):
        raise SystemExit("splice_json: exactly one of --record / --record-file")
    record = args.record or open(args.record_file).read()
    if args.container_dict and not args.key:
        raise SystemExit("splice_json: dict mode needs --key")

    original = open(args.file).read()
    before = json.loads(original)

    if args.container:
        if not isinstance(before.get(args.container), list):
            raise SystemExit("splice_json: %r is not a top-level array in %s" % (args.container, args.file))
        anchor = original.find('"%s"' % args.container)
        open_idx, close_idx = scan_container_span(original, "[", "]", anchor)
        expected_count = len(before[args.container]) + 1
    else:
        open_idx, close_idx = scan_container_span(original, "{", "}", 0)
        expected_count = len(before) + 1

    indent = last_sibling_indent(original, open_idx, close_idx)
    body = reindent(record, indent)
    if args.container_dict:
        body = '"%s": %s' % (args.key, body)
    insertion = ",\n" + indent + body
    # place before the whitespace that precedes the closing bracket; the
    # original pre-bracket whitespace (e.g. "\n\t") survives untouched after us
    tail_ws_start = close_idx
    while tail_ws_start > 0 and original[tail_ws_start - 1] in " \t\n":
        tail_ws_start -= 1
    spliced = original[:tail_ws_start] + insertion + original[tail_ws_start:]

    if args.dry_run:
        lo = max(0, tail_ws_start - 120)
        print(spliced[lo:tail_ws_start + len(insertion) + 40])
        return 0

    # PROOFS before writing
    after = json.loads(spliced)
    if args.container:
        got = after.get(args.container)
        if not isinstance(got, list) or len(got) != expected_count:
            raise SystemExit("splice_json: FAILED count proof (%s)" % args.container)
        record_value = json.loads(record)
        new_id = record_value.get("id") if isinstance(record_value, dict) else record_value
        placed = (any(isinstance(e, dict) and e.get("id") == new_id for e in got)
            if isinstance(record_value, dict) else got[-1] == record_value)
        if new_id is not None and not placed:
            raise SystemExit("splice_json: FAILED placement proof: %r not a direct child of %r" % (new_id, args.container))
    else:
        if args.key not in after or len(after) != expected_count:
            raise SystemExit("splice_json: FAILED placement proof: %r not a TOP-LEVEL key (the watchgolem trap)" % args.key)
    # byte-identity outside the splice
    if not (spliced.startswith(original[:tail_ws_start]) and spliced.endswith(original[close_idx:])):
        raise SystemExit("splice_json: FAILED byte-identity proof outside the splice region")

    open(args.file, "w").write(spliced)
    record_value = json.loads(record)
    record_label = record_value.get("id", "?") if isinstance(record_value, dict) else record_value
    print("splice_json: OK — %s +1 (%s)" % (args.file, args.key or record_label))
    return 0


if __name__ == "__main__":
    sys.exit(main())
