#!/usr/bin/env python3
"""Token index for the Tak_OS configuration.

A TOKEN is a named piece of a Nix file: one top-level binding of a module
(`services.xserver = { ... };`, `environment.systemPackages = ...;`), or a whole
module file when it has no structure to split. Tokens let the tooling find,
compose and reconstruct pieces of the configuration by name.

    takos_tokens.py index [--json]            # every token in the repo
    takos_tokens.py find NAME                 # tokens whose name matches (exact, then fuzzy)
    takos_tokens.py missing                   # catalog modules whose file is absent
    takos_tokens.py reconstruct MODULE_ID     # preview a rebuilt module file
    takos_tokens.py reconstruct MODULE_ID --apply

Standard library only. The lexer skips strings ("..." and ''...''), line comments
and block comments, so braces inside them do not change the depth.
"""

from __future__ import annotations

import argparse
import difflib
import json
import re
import sys
from dataclasses import asdict, dataclass
from pathlib import Path

REPO_DEFAULT = Path(__file__).resolve().parent.parent
SCAN_DIRS = ("modules", "packages", "home")
BINDING_RE = re.compile(r"^(\s*)((?:[A-Za-z_][\w'-]*|\"[^\"]+\")(?:\.(?:[A-Za-z_][\w'-]*|\"[^\"]+\"))*)\s*=")


@dataclass
class Token:
    name: str       # binding path, e.g. "services.xserver", or the module stem
    file: str       # repo-relative path
    start: int      # 1-based first line
    end: int        # 1-based last line (inclusive)
    kind: str       # "binding" or "module"

    @property
    def origin(self) -> str:
        return f"{self.file}:{self.start}-{self.end}"


def line_depths(text: str) -> list[int]:
    """Bracket depth at the start of every line, or -1 when the line starts
    inside a string or block comment (such lines never hold a binding).

    Strings ("..." and ''...''), line comments and block comments are skipped,
    so braces inside them do not change the depth.
    """
    depths: list[int] = []
    depth = 0
    state: str | None = None  # None | "multi" (''...'') | "block" (/* ... */)
    for line in text.split("\n"):
        depths.append(depth if state is None else -1)
        i = 0
        while i < len(line):
            if state == "block":
                j = line.find("*/", i)
                if j == -1:
                    break
                state, i = None, j + 2
                continue
            if state == "multi":
                j = line.find("''", i)
                if j == -1:
                    break
                state, i = None, j + 2
                continue
            if line.startswith("/*", i):
                state, i = "block", i + 2
                continue
            if line.startswith("''", i):
                state, i = "multi", i + 2
                continue
            ch = line[i]
            if ch == "#":
                break
            if ch == '"':
                i += 1
                while i < len(line) and line[i] != '"':
                    i += 2 if line[i] == "\\" else 1
                i += 1
                continue
            if ch in "{[(":
                depth += 1
            elif ch in "}])":
                depth -= 1
            i += 1
    return depths


def tokens_in_file(repo: Path, path: Path) -> list[Token]:
    """Binding tokens at depth 1 (the module body) plus one module token.

    A `{ args }:` header opens and closes before the body, so the body's
    bindings are also at depth 1 and are found the same way.
    """
    rel = path.relative_to(repo).as_posix()
    lines = path.read_text(encoding="utf-8").split("\n")
    depths = line_depths("\n".join(lines))
    starts: list[tuple[int, str]] = []
    for idx, line in enumerate(lines):
        if depths[idx] != 1:
            continue
        match = BINDING_RE.match(line)
        if match:
            starts.append((idx + 1, match.group(2).replace('"', '')))
    out: list[Token] = []
    for pos, (line_no, name) in enumerate(starts):
        nxt = starts[pos + 1][0] - 1 if pos + 1 < len(starts) else len(lines)
        end = max(line_no, _trim_blank(lines, nxt))
        out.append(Token(name=name, file=rel, start=line_no, end=end, kind="binding"))
    out.append(Token(name=path.stem, file=rel, start=1, end=_trim_blank(lines, len(lines)), kind="module"))
    return out


def _trim_blank(lines: list[str], end: int) -> int:
    while end > 1 and not lines[end - 1].strip():
        end -= 1
    return end


def index_repo(repo: Path) -> list[Token]:
    tokens: list[Token] = []
    for sub in SCAN_DIRS:
        base = repo / sub
        if not base.is_dir():
            continue
        for path in sorted(base.rglob("*.nix")):
            if "disabled" in path.parts:
                continue
            tokens.extend(tokens_in_file(repo, path))
    return tokens


def find_tokens(tokens: list[Token], name: str, limit: int = 8) -> list[Token]:
    exact = [t for t in tokens if t.name == name]
    if exact:
        return exact
    names = sorted({t.name for t in tokens})
    close = difflib.get_close_matches(name, names, n=limit, cutoff=0.5)
    return [t for t in tokens if t.name in close]


def read_token(repo: Path, token: Token) -> str:
    lines = (repo / token.file).read_text(encoding="utf-8").split("\n")
    return "\n".join(lines[token.start - 1: token.end])


def reconstruct_text(repo: Path, module_stem: str, source: Token, module_id: str) -> str:
    body = read_token(repo, source)
    return (
        f"# Tak_OS · {module_stem}.nix — RECONSTRUCTED by scripts/takos_tokens.py\n"
        f"# Module id   : {module_id}\n"
        f"# Built from  : {source.origin} ({source.kind} '{source.name}')\n"
        "# Review before use: the original file was missing, and this copy may need edits.\n"
        "\n"
        f"{body}\n"
    )


def _catalog(repo: Path) -> dict:
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    import takos_profiles as tp  # noqa: WPS433  (sibling module)
    return tp.load_catalog(repo)


def cmd_index(repo: Path, args) -> int:
    tokens = index_repo(repo)
    if args.json:
        print(json.dumps([asdict(t) | {"origin": t.origin} for t in tokens], indent=2))
        return 0
    counts = {"module": 0, "binding": 0}
    for t in tokens:
        counts[t.kind] += 1
        if t.kind == "binding":
            print(f"{t.name:40} {t.origin}")
    print(f"\n{counts['module']} module token(s), {counts['binding']} binding token(s)")
    return 0


def cmd_find(repo: Path, args) -> int:
    tokens = index_repo(repo)
    hits = find_tokens(tokens, args.name)
    if not hits:
        print(f"no token matches '{args.name}'")
        return 1
    for t in hits:
        print(f"{t.name:40} {t.kind:8} {t.origin}")
    return 0


def cmd_missing(repo: Path, args) -> int:
    cat = _catalog(repo)
    tokens = index_repo(repo)
    status = 0
    for mod_id, meta in cat["modules"].items():
        path = meta.get("path", "")
        if (repo / path).is_file():
            continue
        status = 1
        stem = Path(path).stem
        hits = find_tokens(tokens, stem, limit=3)
        hint = ", ".join(f"{t.name} ({t.origin})" for t in hits) or "nothing close"
        print(f"missing: {mod_id} -> {path}\n    closest tokens: {hint}")
    if status == 0:
        print("every catalog module file is present")
    return status


def cmd_reconstruct(repo: Path, args) -> int:
    cat = _catalog(repo)
    if args.module not in cat["modules"]:
        print(f"error: unknown module '{args.module}'", file=sys.stderr)
        return 1
    path = cat["modules"][args.module]["path"]
    if (repo / path).is_file() and not args.force:
        print(f"{path} already exists; pass --force to overwrite")
        return 1
    stem = Path(path).stem
    tokens = index_repo(repo)
    hits = find_tokens(tokens, stem, limit=1)
    if not hits:
        print(f"error: no token close to '{stem}' to rebuild from", file=sys.stderr)
        return 1
    text = reconstruct_text(repo, stem, hits[0], args.module)
    if not args.apply:
        print(f"# preview: would write {path} from {hits[0].origin}\n")
        print(text)
        return 0
    (repo / path).parent.mkdir(parents=True, exist_ok=True)
    (repo / path).write_text(text, encoding="utf-8")
    print(f"wrote {path} from {hits[0].origin}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--repo", default=str(REPO_DEFAULT))
    sub = parser.add_subparsers(dest="cmd", required=True)
    p_index = sub.add_parser("index")
    p_index.add_argument("--json", action="store_true")
    p_find = sub.add_parser("find")
    p_find.add_argument("name")
    sub.add_parser("missing")
    p_rec = sub.add_parser("reconstruct")
    p_rec.add_argument("module")
    p_rec.add_argument("--apply", action="store_true")
    p_rec.add_argument("--force", action="store_true")
    args = parser.parse_args(argv)
    handlers = {"index": cmd_index, "find": cmd_find, "missing": cmd_missing, "reconstruct": cmd_reconstruct}
    return handlers[args.cmd](Path(args.repo), args)


if __name__ == "__main__":
    sys.exit(main())
