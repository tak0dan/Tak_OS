#!/usr/bin/env python3
"""Tak_OS profile installer — nmtui-style chooser in front of install.sh.

    takos-installer.py                       # curses UI: profile -> modules -> confirm
    takos-installer.py --list                # list profiles
    takos-installer.py --profile hyprland --yes [--dry-run] [--edit]
    takos-installer.py --profile devops --modules docker,httpd --yes

The UI only collects a choice. The install itself is install.sh, driven by the
TAKOS_PROFILE / TAKOS_MODULES environment variables, so the automatic path and
the profile path share one code path.

Standard library only (curses, tomllib); it runs before anything else is installed.
"""

from __future__ import annotations

import argparse
import curses
import os
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))

import takos_profiles as tp  # noqa: E402  (sibling module)
import takos_releases as tr  # noqa: E402

REPO = SCRIPT_DIR.parent
INSTALL_SCRIPT = SCRIPT_DIR / "install.sh"


def build_install_command(
    profile: str,
    modules: list[str] | None,
    *,
    release: str | None = None,
    dry_run: bool = False,
    edit: bool = False,
) -> tuple[list[str], dict[str, str]]:
    """Command and environment that run install.sh with the chosen profile.

    Pure function: no I/O, so it can be tested without a terminal.
    """
    argv = ["bash", str(INSTALL_SCRIPT)]
    if edit:
        argv.append("--edit")
    if dry_run:
        argv.append("--dry-run")
    env = dict(os.environ)
    env["TAKOS_PROFILE"] = profile
    if modules is not None:
        env["TAKOS_MODULES"] = ",".join(modules)
    else:
        env.pop("TAKOS_MODULES", None)
    if release is not None:
        env["TAKOS_RELEASE"] = release
    else:
        env.pop("TAKOS_RELEASE", None)
    return argv, env


def selected_modules(cat: dict, profile: str) -> list[str]:
    """Modules the profile resolves to; used as the checklist's starting state."""
    return tp.resolve(cat, profile).modules


def run_install(argv: list[str], env: dict[str, str], dry_run: bool) -> int:
    # The deploy step needs root; the dry run does not.
    if not dry_run and os.geteuid() != 0:
        sudo = shutil.which("sudo")
        if sudo is None:
            print("error: run as root (sudo) or use --dry-run", file=sys.stderr)
            return 1
        argv = [sudo, "-E"] + argv
    return subprocess.call(argv, env=env)


# ── curses screens ───────────────────────────────────────────────────────────

def _draw_header(stdscr, title: str, hint: str) -> None:
    stdscr.erase()
    h, w = stdscr.getmaxyx()
    stdscr.addnstr(0, 0, f" {title} ", w - 1, curses.A_REVERSE)
    stdscr.addnstr(h - 1, 0, hint, w - 1, curses.A_DIM)


def pick_profile(stdscr, cat: dict) -> str | None:
    names = list(cat["profiles"])
    idx = 0
    while True:
        _draw_header(stdscr, "Tak_OS — choose a profile",
                     "↑/↓ move   Enter select   q quit")
        for row, name in enumerate(names, start=2):
            prof = cat["profiles"][name]
            text = f"  {prof.get('title', name):<16} {prof.get('description', '')}"
            attr = curses.A_REVERSE if row - 2 == idx else curses.A_NORMAL
            stdscr.addnstr(row, 0, text, stdscr.getmaxyx()[1] - 1, attr)
        stdscr.refresh()
        key = stdscr.getch()
        if key in (curses.KEY_UP, ord("k")):
            idx = (idx - 1) % len(names)
        elif key in (curses.KEY_DOWN, ord("j")):
            idx = (idx + 1) % len(names)
        elif key in (curses.KEY_ENTER, 10, 13):
            return names[idx]
        elif key in (ord("q"), 27):
            return None


def pick_modules(stdscr, cat: dict, profile: str) -> list[str] | None:
    """Checklist of every catalog module, pre-set to the profile's selection."""
    names = list(cat["modules"])
    chosen = set(selected_modules(cat, profile))
    idx = 0
    while True:
        _draw_header(stdscr, f"Modules — {profile}",
                     "↑/↓ move   Space toggle   Enter continue   q back")
        for row, name in enumerate(names, start=2):
            meta = cat["modules"][name]
            mark = "[x]" if name in chosen else "[ ]"
            text = f"  {mark} {name:<14} {meta.get('title', '')}"
            attr = curses.A_REVERSE if row - 2 == idx else curses.A_NORMAL
            stdscr.addnstr(row, 0, text, stdscr.getmaxyx()[1] - 1, attr)
        stdscr.refresh()
        key = stdscr.getch()
        if key in (curses.KEY_UP, ord("k")):
            idx = (idx - 1) % len(names)
        elif key in (curses.KEY_DOWN, ord("j")):
            idx = (idx + 1) % len(names)
        elif key == ord(" "):
            name = names[idx]
            chosen.symmetric_difference_update({name})
        elif key in (curses.KEY_ENTER, 10, 13):
            return [m for m in names if m in chosen]
        elif key in (ord("q"), 27):
            return None


def confirm(stdscr, cat: dict, profile: str, modules: list[str]) -> str | None:
    """Show what will be installed. Returns 'auto', 'edit' or None (cancel)."""
    try:
        res = tp.resolve(cat, profile, modules)
    except tp.CatalogError as exc:
        res = None
        problem = str(exc)
    while True:
        _draw_header(stdscr, "Confirm", "Enter install   e review in install.sh --edit   q cancel")
        lines = [f"Profile : {profile}"]
        if res is None:
            lines.append(f"Problem : {problem}")
        else:
            lines.append("Modules : " + ", ".join(res.modules))
            if res.added_required:
                lines.append("Added   : " + ", ".join(res.added_required) + " (required)")
        for row, line in enumerate(lines, start=2):
            stdscr.addnstr(row, 2, line, stdscr.getmaxyx()[1] - 3)
        stdscr.refresh()
        key = stdscr.getch()
        if key in (curses.KEY_ENTER, 10, 13) and res is not None:
            return "auto"
        if key == ord("e") and res is not None:
            return "edit"
        if key in (ord("q"), 27):
            return None


def pick_release(stdscr, repo: Path) -> str | None:
    """Release source: the configuration's version, this PC's version, or a
    release from the live list. Returns 'config', 'pc' or an X.Y string."""
    config_rel = tr.configured_release(repo)
    pc_rel = tr.local_release()
    options: list[tuple[str, str]] = [("config", f"Version of the pulled configuration ({config_rel})")]
    if pc_rel:
        options.append(("pc", f"Version of this PC ({pc_rel})"))
    _draw_header(stdscr, "Tak_OS — release", "Fetching the release list…")
    stdscr.refresh()
    releases, live = tr.fetch_releases()
    for rel in releases:
        if rel not in (config_rel, pc_rel):
            options.append((rel, f"NixOS {rel}"))
    if not live:
        options.append(("", "(offline: built-in list)"))
    idx = 0
    while True:
        _draw_header(stdscr, "Tak_OS — choose the NixOS release",
                     "↑/↓ move   Enter select   q cancel")
        for row, (_tag, text) in enumerate(options, start=2):
            attr = curses.A_REVERSE if row - 2 == idx else curses.A_NORMAL
            stdscr.addnstr(row, 2, text, stdscr.getmaxyx()[1] - 3, attr)
        stdscr.refresh()
        key = stdscr.getch()
        if key in (curses.KEY_UP, ord("k")):
            idx = (idx - 1) % len(options)
        elif key in (curses.KEY_DOWN, ord("j")):
            idx = (idx + 1) % len(options)
        elif key in (curses.KEY_ENTER, 10, 13):
            tag = options[idx][0]
            if tag:
                return tag
        elif key in (ord("q"), 27):
            return None


def run_ui(cat: dict, dry_run: bool) -> int:
    result: dict = {}

    def ui(stdscr):
        curses.curs_set(0)
        release = pick_release(stdscr, REPO)
        if release is None:
            return
        while True:
            profile = pick_profile(stdscr, cat)
            if profile is None:
                return
            modules = pick_modules(stdscr, cat, profile)
            if modules is None:
                continue
            action = confirm(stdscr, cat, profile, modules)
            if action is None:
                continue
            result.update(profile=profile, modules=modules, action=action, release=release)
            return

    curses.wrapper(ui)
    if not result:
        print("Cancelled.")
        return 0
    argv, env = build_install_command(
        result["profile"], result["modules"], release=result["release"],
        dry_run=dry_run, edit=result["action"] == "edit",
    )
    return run_install(argv, env, dry_run)


# ── entry point ──────────────────────────────────────────────────────────────

def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Tak_OS profile installer")
    parser.add_argument("--list", action="store_true", help="list profiles and exit")
    parser.add_argument("--profile", help="profile to install (skips the UI)")
    parser.add_argument("--modules", help="comma-separated module ids (overrides the profile)")
    parser.add_argument("--yes", action="store_true", help="do not ask; install the given profile")
    parser.add_argument("--dry-run", action="store_true", help="stage only (no root needed)")
    parser.add_argument("--edit", action="store_true", help="review the install.sh values first")
    parser.add_argument("--release", help="pc, config (default) or a release such as 25.11")
    args = parser.parse_args(argv)

    cat = tp.load_catalog(REPO)
    if args.list:
        for name, prof in cat["profiles"].items():
            print(f"{name:14} {prof.get('title', name)} — {prof.get('description', '')}")
        return 0

    if args.profile:
        modules = [m.strip() for m in args.modules.split(",") if m.strip()] if args.modules else None
        try:
            tp.resolve(cat, args.profile, modules)
        except tp.CatalogError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 1
        if not args.yes:
            print("Pass --yes to install without the UI.", file=sys.stderr)
            return 1
        try:
            argv_cmd, env = build_install_command(
                args.profile, modules, release=args.release, dry_run=args.dry_run, edit=args.edit
            )
        except tp.CatalogError as exc:
            print(f"error: {exc}", file=sys.stderr)
            return 1
        return run_install(argv_cmd, env, args.dry_run)

    if not sys.stdin.isatty():
        print("error: the UI needs a terminal; use --profile NAME --yes instead", file=sys.stderr)
        return 1
    return run_ui(cat, args.dry_run)


if __name__ == "__main__":
    sys.exit(main())
