#!/usr/bin/env python3
"""takos-rebuild — smart rebuild and release rebasing for Tak_OS.

    takos-rebuild --plan                    # show what a build would change
    takos-rebuild --yes                     # apply renames and build
    takos-rebuild --version                 # curses picker: 23.05 … 26.05 or custom
    takos-rebuild --version 25.11 --plan    # plan a move to 25.11 without writing
    takos-rebuild --version 25.11 --yes --switch

Passes, in order:
  1. Rename pass. Evaluating the configuration against the target release
     reports every renamed attribute ("'swww' has been renamed to 'awww'").
     The reported names are rewritten in the repo's .nix files.
  2. Removed-package pass. Attributes the target release reports as removed are
     listed with replacement candidates from `nixorcist search --release`.
     Candidates are only printed; nothing is rewritten for them automatically.
  3. Build with the target release as nixpkgs. If the build fails, every file
     this run rewrote is restored from memory.

Standard library only, so it runs before any extra package is installed.
"""

from __future__ import annotations

import argparse
import curses
import json
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
import takos_releases as tr  # noqa: E402  (sibling module)
RELEASE_RE = re.compile(r"^\d{2}\.\d{2}$")
SKIP_DIRS = {".git", "result", ".hm-local-cache"}

RENAMED_RE = re.compile(r"'([^']+)' has been renamed to '([^']+)'")
REMOVED_RE = re.compile(r"['‘]([^'’]+)['’] has been removed")


# ── pure logic (tested) ──────────────────────────────────────────────────────

def valid_release(value: str) -> bool:
    return bool(RELEASE_RE.match(value))


def channel_url(release: str) -> str:
    return f"https://channels.nixos.org/nixos-{release}/nixexprs.tar.xz"


def parse_eval_messages(text: str) -> tuple[dict[str, str], list[str]]:
    """Return (renames old->new, removed names) from evaluation output."""
    renames: dict[str, str] = {}
    for old, new in RENAMED_RE.findall(text):
        if old != new:
            renames[old] = new
    removed = sorted({name for name in REMOVED_RE.findall(text) if name not in renames})
    return renames, removed


def rewrite_names(text: str, renames: dict[str, str]) -> tuple[str, int]:
    """Rename whole identifiers. Attribute paths such as `pkgs.swww` match;
    `swww-extras` and `my-swww` do not, because `-` is part of the name."""
    count = 0
    for old, new in renames.items():
        pattern = re.compile(rf"(?<![\w'-]){re.escape(old)}(?![\w'-])")
        text, n = pattern.subn(new, text)
        count += n
    return text, count


def nix_files(repo: Path):
    for root, dirs, files in os.walk(repo):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for name in files:
            if name.endswith(".nix"):
                yield Path(root) / name


def plan_renames(repo: Path, renames: dict[str, str]) -> dict[Path, tuple[str, int]]:
    """Map each file that would change to its new text and replacement count."""
    changes: dict[Path, tuple[str, int]] = {}
    if not renames:
        return changes
    for path in nix_files(repo):
        original = path.read_text(encoding="utf-8")
        updated, count = rewrite_names(original, renames)
        if count and updated != original:
            changes[path] = (updated, count)
    return changes


def search_candidates(name: str, release: str) -> list[str]:
    """Top `nixorcist search` hits for a removed name, or [] if unavailable."""
    tool = shutil.which("nixorcist") or shutil.which("nist")
    if tool is None:
        return []
    proc = subprocess.run(
        [tool, "search", name, "--release", release, "--json", "--limit", "3"],
        capture_output=True, text=True, check=False,
    )
    if proc.returncode != 0:
        return []
    try:
        data = json.loads(proc.stdout)
    except json.JSONDecodeError:
        return []
    return [item.get("name", "") for item in data.get("results", []) if item.get("name")]


def eval_target(repo: Path, release: str) -> tuple[int, str]:
    """Evaluate the configuration on the target release.

    Returns (exit code, stderr+stdout). A non-zero code means evaluation failed,
    so the caller must not read "no renames" from the output.
    """
    expr = ("(import <nixpkgs/nixos> { configuration = import <nixos-config>; })"
            ".config.system.build.toplevel.drvPath")
    home_manager = f"https://github.com/nix-community/home-manager/archive/release-{release}.tar.gz"
    cmd = [
        "nix-instantiate", "--eval", "--strict", "-E", expr,
        "-I", f"nixpkgs={channel_url(release)}",
        "-I", f"nixos-config={repo / 'configuration.nix'}",
        "-I", f"home-manager={home_manager}",
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return proc.returncode, proc.stderr + proc.stdout


# ── curses picker ────────────────────────────────────────────────────────────

def pick_release(current: str | None) -> str | None:
    """Stable releases from the live list plus a free-text custom release."""
    releases, _live = tr.fetch_releases()

    def ui(stdscr):
        curses.curs_set(0)
        options = releases + ["custom…"]
        idx = releases.index(current) if current in releases else 0
        while True:
            h, w = stdscr.getmaxyx()
            stdscr.erase()
            stdscr.addnstr(0, 0, " takos-rebuild — target NixOS release ", w - 1, curses.A_REVERSE)
            stdscr.addnstr(h - 1, 0, "↑/↓ move   Enter select   q cancel", w - 1, curses.A_DIM)
            for row, name in enumerate(options, start=2):
                mark = "  (current)" if name == current else ""
                attr = curses.A_REVERSE if row - 2 == idx else curses.A_NORMAL
                stdscr.addnstr(row, 2, f"nixos-{name}{mark}" if name != "custom…" else name, w - 3, attr)
            stdscr.refresh()
            key = stdscr.getch()
            if key in (curses.KEY_UP, ord("k")):
                idx = (idx - 1) % len(options)
            elif key in (curses.KEY_DOWN, ord("j")):
                idx = (idx + 1) % len(options)
            elif key in (curses.KEY_ENTER, 10, 13):
                if options[idx] != "custom…":
                    return options[idx]
                return _custom_field(stdscr)
            elif key in (ord("q"), 27):
                return None

    return curses.wrapper(ui)


def _custom_field(stdscr) -> str | None:
    curses.curs_set(1)
    curses.echo()
    try:
        h, w = stdscr.getmaxyx()
        stdscr.erase()
        stdscr.addnstr(0, 0, " Custom release (for example 25.05) ", w - 1, curses.A_REVERSE)
        stdscr.addnstr(2, 2, "release: ", w - 3)
        stdscr.refresh()
        value = stdscr.getstr(2, 12, 16).decode("utf-8", "replace").strip()
    finally:
        curses.noecho()
        curses.curs_set(0)
    return value or None


# ── actions ──────────────────────────────────────────────────────────────────

def print_plan(release: str | None, renames: dict[str, str], removed: list[str],
               changes: dict[Path, tuple[str, int]], repo: Path) -> None:
    print(f"Target release : {release or 'current (no --version)'}")
    if renames:
        print("Renames:")
        for old, new in sorted(renames.items()):
            print(f"  {old} -> {new}")
    else:
        print("Renames: none")
    for path, (_text, count) in sorted(changes.items()):
        print(f"  {count:>3} change(s)  {path.relative_to(repo)}")
    if removed:
        print("Removed on the target release (not rewritten automatically):")
        for name in removed:
            candidates = search_candidates(name, release) if release else []
            hint = ", ".join(candidates) if candidates else "no candidate found"
            print(f"  {name}: candidates: {hint}")


def apply_changes(changes: dict[Path, tuple[str, int]]) -> dict[Path, str]:
    """Write the rewritten files. Returns the original text of each for rollback."""
    originals: dict[Path, str] = {}
    for path, (text, _count) in changes.items():
        originals[path] = path.read_text(encoding="utf-8")
        path.write_text(text, encoding="utf-8")
    return originals


def rollback(originals: dict[Path, str]) -> None:
    for path, text in originals.items():
        path.write_text(text, encoding="utf-8")


def build(repo: Path, release: str | None, switch: bool) -> int:
    cmd = ["nixos-rebuild", "switch" if switch else "build"]
    if switch and os.geteuid() != 0:
        cmd = ["sudo", "-E"] + cmd
    if release:
        cmd += ["-I", f"nixpkgs={channel_url(release)}"]
    return subprocess.call(cmd, cwd=repo)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Tak_OS smart rebuild and release rebasing")
    parser.add_argument("--version", nargs="?", const="", default=None, metavar="RELEASE",
                        help="target NixOS release; without a value opens the picker")
    parser.add_argument("--plan", action="store_true", help="show the plan and write nothing")
    parser.add_argument("--yes", action="store_true", help="apply renames and build without asking")
    parser.add_argument("--switch", action="store_true", help="switch to the new generation after building")
    parser.add_argument("--repo", default=None,
                        help="configuration root (default: /etc/nixos on an installed system, else the repo)")
    args = parser.parse_args(argv)
    if args.repo:
        repo = Path(args.repo)
    elif (Path("/etc/nixos/configuration.nix")).is_file():
        repo = Path("/etc/nixos")
    else:
        repo = REPO

    release: str | None = None
    if args.version is not None:
        if args.version:
            release = args.version
        else:
            if not sys.stdin.isatty():
                print("error: --version without a value needs a terminal", file=sys.stderr)
                return 1
            release = pick_release(current=None)
            if release is None:
                print("Cancelled.")
                return 0
        if not valid_release(release):
            print(f"error: '{release}' is not a release like 25.11", file=sys.stderr)
            return 1

    target = release or tr.configured_release(repo)
    print(f"Evaluating the configuration against nixos-{target} …")
    code, output = eval_target(repo, target)
    if code != 0 and not parse_eval_messages(output)[1]:
        print(output[-2000:], file=sys.stderr)
        print(f"error: evaluation against nixos-{target} failed", file=sys.stderr)
        return 1
    renames, removed = parse_eval_messages(output)
    changes = plan_renames(repo, renames)
    print_plan(target, renames, removed, changes, repo)

    if args.plan:
        return 0
    if not changes and not args.yes and not sys.stdin.isatty():
        print("Nothing to rename. Add --yes to build anyway.")
        return 0
    if not args.yes:
        answer = input("Apply the renames above and build? [y/N] ").strip().lower()
        if answer != "y":
            print("Not applied.")
            return 0

    originals = apply_changes(changes)
    print(f"Rewrote {len(originals)} file(s). Building…")
    code = build(repo, release, args.switch)
    if code != 0:
        print("Build failed; restoring the files this run changed.", file=sys.stderr)
        rollback(originals)
        return code
    print("Build succeeded." + ("" if args.switch else " Use --switch to activate it."))
    return 0


if __name__ == "__main__":
    sys.exit(main())
