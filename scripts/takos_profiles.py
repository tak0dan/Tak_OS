#!/usr/bin/env python3
"""Tak_OS profile resolver and generator.

Reads profiles/catalog.toml, resolves a profile into an ordered, de-duplicated
list of modules, and writes profile-selection.nix with the imports the
configuration does not already load.

    takos_profiles.py list
    takos_profiles.py show <profile>
    takos_profiles.py check
    takos_profiles.py write <profile> [--modules a,b] [--out FILE] [--repo DIR]

Standard library only (tomllib needs Python 3.11+), so it runs on a fresh
NixOS install before any extra package is available.
"""

from __future__ import annotations

import argparse
import re
import sys
import tomllib
from dataclasses import dataclass, field
from pathlib import Path

REPO_DEFAULT = Path(__file__).resolve().parent.parent
CATALOG_REL = Path("profiles/catalog.toml")
SELECTION_REL = Path("profile-selection.nix")


class CatalogError(Exception):
    """The catalog is malformed or a profile cannot be resolved."""


@dataclass
class Resolution:
    profile: str
    modules: list[str]                       # ordered, unique, after requires
    added_required: list[str] = field(default_factory=list)


def load_catalog(repo: Path) -> dict:
    path = repo / CATALOG_REL
    with path.open("rb") as fh:
        data = tomllib.load(fh)
    return {
        "modules": data.get("modules", {}),
        "profiles": data.get("profiles", {}),
    }


def _expand_profile(cat: dict, name: str, stack: tuple[str, ...] = ()) -> list[str]:
    """Modules of a profile in order, with included profiles first."""
    if name in stack:
        raise CatalogError(f"include cycle: {' -> '.join(stack + (name,))}")
    profile = cat["profiles"].get(name)
    if profile is None:
        raise CatalogError(f"unknown profile '{name}'")
    out: list[str] = []
    for inc in profile.get("includes", []):
        out.extend(_expand_profile(cat, inc, stack + (name,)))
    out.extend(profile.get("modules", []))
    return out


def _dedupe(items: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for item in items:
        if item not in seen:
            seen.add(item)
            out.append(item)
    return out


def resolve(cat: dict, profile: str, modules: list[str] | None = None) -> Resolution:
    """Resolve a profile, or an explicit module list, into the final selection.

    A module listed twice (directly or through an include) is kept once, at its
    first position. `requires` closure is added and reported. A conflict is an
    error, because the two modules cannot be loaded together.
    """
    if modules is None:
        ordered = _dedupe(_expand_profile(cat, profile))
    else:
        ordered = _dedupe(modules)

    for mod in ordered:
        if mod not in cat["modules"]:
            raise CatalogError(f"unknown module '{mod}'")

    added: list[str] = []
    selected = list(ordered)
    queue = list(ordered)
    while queue:
        mod = queue.pop(0)
        for dep in cat["modules"][mod].get("requires", []):
            if dep not in cat["modules"]:
                raise CatalogError(f"module '{mod}' requires unknown module '{dep}'")
            if dep not in selected:
                selected.append(dep)
                added.append(dep)
                queue.append(dep)

    chosen = set(selected)
    for mod in selected:
        for other in cat["modules"][mod].get("conflicts", []):
            if other in chosen:
                raise CatalogError(f"modules '{mod}' and '{other}' conflict")

    return Resolution(profile=profile if modules is None else "custom",
                      modules=selected, added_required=added)


def check(cat: dict, repo: Path) -> list[str]:
    """Return a list of problems in the catalog and the files it names."""
    problems: list[str] = []
    mods = cat["modules"]
    for name, meta in mods.items():
        path = meta.get("path")
        if not path:
            problems.append(f"module '{name}' has no path")
        elif not (repo / path).is_file():
            problems.append(f"module '{name}': file missing: {path}")
        for key in ("requires", "conflicts"):
            for ref in meta.get(key, []):
                if ref not in mods:
                    problems.append(f"module '{name}': {key} unknown module '{ref}'")
    for name in cat["profiles"]:
        try:
            resolve(cat, name)
        except CatalogError as exc:
            problems.append(f"profile '{name}': {exc}")
    return problems


def configuration_imports(repo: Path) -> set[str]:
    """Repo-relative paths that configuration.nix already imports."""
    text = (repo / "configuration.nix").read_text(encoding="utf-8")
    found = set()
    for match in re.finditer(r"\./((?:modules|packages)/[\w./-]+\.nix)", text):
        found.add(match.group(1))
    return found


def nix_imports(cat: dict, selected: list[str], already: set[str]) -> list[str]:
    """Paths the generated file must import: selected, not yet loaded, de-duped."""
    paths = []
    for mod in selected:
        path = cat["modules"][mod]["path"]
        if path in already:
            continue
        paths.append(path)
    return _dedupe(paths)


def render_nix(label: str, paths: list[str], skipped: list[str]) -> str:
    lines = [
        "# Tak_OS · profile-selection.nix — generated by scripts/takos_profiles.py",
        "# Do not edit by hand: run the profile installer or",
        "#   python3 scripts/takos_profiles.py write <profile>",
        f"# Selection: {label}",
    ]
    if skipped:
        lines.append("# Already loaded by configuration.nix (not imported twice): " + ", ".join(skipped))
    lines.append("{ ... }:")
    lines.append("{")
    if not paths:
        lines.append("  imports = [ ];")
    else:
        lines.append("  imports = [")
        for path in paths:
            lines.append(f"    ./{path}")
        lines.append("  ];")
    lines.append("}")
    return "\n".join(lines) + "\n"


def build_selection(repo: Path, profile: str, modules: list[str] | None = None) -> tuple[Resolution, str]:
    cat = load_catalog(repo)
    res = resolve(cat, profile, modules)
    already = configuration_imports(repo)
    paths = nix_imports(cat, res.modules, already)
    skipped = [m for m in res.modules if cat["modules"][m]["path"] in already]
    label = res.profile if modules is None else "custom: " + ", ".join(res.modules)
    return res, render_nix(label, paths, [f"{m}" for m in skipped])


def _cmd_list(cat: dict, _args) -> int:
    for name, prof in cat["profiles"].items():
        print(f"{name:14} {prof.get('title', name)} — {prof.get('description', '')}")
    return 0


def _cmd_show(cat: dict, args) -> int:
    res = resolve(cat, args.profile)
    print(f"profile {args.profile}:")
    for mod in res.modules:
        meta = cat["modules"][mod]
        tag = " (required, added)" if mod in res.added_required else ""
        print(f"  {mod:14} {meta.get('title', '')} [{meta['path']}]{tag}")
    return 0


def _cmd_check(cat: dict, args) -> int:
    problems = check(cat, Path(args.repo))
    if problems:
        for p in problems:
            print(f"error: {p}", file=sys.stderr)
        return 1
    print(f"catalog OK: {len(cat['modules'])} modules, {len(cat['profiles'])} profiles")
    return 0


def _cmd_write(cat: dict, args) -> int:
    repo = Path(args.repo)
    modules = [m.strip() for m in args.modules.split(",") if m.strip()] if args.modules else None
    _res, text = build_selection(repo, args.profile, modules)
    out = Path(args.out) if args.out else repo / SELECTION_REL
    out.write_text(text, encoding="utf-8")
    print(f"wrote {out}")
    return 0


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--repo", default=str(REPO_DEFAULT), help="repository root")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    p_show = sub.add_parser("show")
    p_show.add_argument("profile")
    sub.add_parser("check")
    p_write = sub.add_parser("write")
    p_write.add_argument("profile")
    p_write.add_argument("--modules", help="comma-separated module ids (overrides the profile)")
    p_write.add_argument("--out", help="output file (default: profile-selection.nix in the repo)")
    args = parser.parse_args(argv)

    handlers = {"list": _cmd_list, "show": _cmd_show, "check": _cmd_check, "write": _cmd_write}
    try:
        cat = load_catalog(Path(args.repo))
        return handlers[args.cmd](cat, args)
    except CatalogError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
