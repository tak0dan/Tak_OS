#!/usr/bin/env python3
"""NixOS release discovery for the Tak_OS installer and takos-rebuild.

Three sources for "which release do I install?":

    pc      the release the machine is running now   (/etc/os-release VERSION_ID)
    config  the release the pulled configuration is written for (stateVersion)
    <X.Y>   a release picked from the list, or typed in

    takos_releases.py list                 # stable releases 23.05 … 26.05
    takos_releases.py resolve pc|config|X.Y [--repo DIR]
    takos_releases.py exists X.Y

The list is read from the public NixOS release bucket, so it is current. If the
network is unavailable it falls back to a built-in list. Standard library only.
"""

from __future__ import annotations

import argparse
import re
import sys
import urllib.error
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

RELEASE_BUCKET = "https://nix-releases.s3.amazonaws.com/?delimiter=/&prefix=nixos/"
CHANNEL_URL = "https://channels.nixos.org/nixos-{release}/nixexprs.tar.xz"
FALLBACK_RELEASES = ["26.05", "25.11", "25.05", "24.11", "24.05", "23.11", "23.05"]
MIN_RELEASE = (23, 5)

RELEASE_RE = re.compile(r"^(\d{2})\.(\d{2})$")
PREFIX_RE = re.compile(r"^nixos/(\d{2}\.\d{2})/$")
SOURCES = ("pc", "config")


class ReleaseError(Exception):
    """A release source could not be resolved."""


def valid_release(value: str) -> bool:
    return bool(RELEASE_RE.match(value))


def _key(release: str) -> tuple[int, int]:
    major, minor = release.split(".")
    return int(major), int(minor)


def fetch_releases(timeout: float = 15.0) -> tuple[list[str], bool]:
    """Stable releases from MIN_RELEASE upwards, newest first.

    Returns (releases, from_network). Falls back to FALLBACK_RELEASES when the
    bucket cannot be read, so the installer still offers choices offline.
    """
    try:
        with urllib.request.urlopen(RELEASE_BUCKET, timeout=timeout) as resp:
            body = resp.read()
    except (urllib.error.URLError, TimeoutError, OSError):
        return list(FALLBACK_RELEASES), False

    try:
        root = ET.fromstring(body)
    except ET.ParseError:
        return list(FALLBACK_RELEASES), False
    found = []
    for el in root.iter():
        # The bucket uses a default XML namespace, so match on the local tag name.
        if el.tag.rsplit("}", 1)[-1] != "Prefix":
            continue
        match = PREFIX_RE.match(el.text or "")
        if match and _key(match.group(1)) >= MIN_RELEASE:
            found.append(match.group(1))
    if not found:
        return list(FALLBACK_RELEASES), False
    return sorted(set(found), key=_key, reverse=True), True


def release_exists(release: str) -> bool:
    """True when the release is listed in the bucket (and so is supported here)."""
    if not valid_release(release) or _key(release) < MIN_RELEASE:
        return False
    releases, live = fetch_releases()
    return release in releases if live else release in FALLBACK_RELEASES


def local_release(os_release: Path = Path("/etc/os-release")) -> str | None:
    """The release this machine runs, or None when it is not NixOS."""
    try:
        text = os_release.read_text(encoding="utf-8")
    except OSError:
        return None
    fields = {}
    for line in text.splitlines():
        if "=" in line and not line.lstrip().startswith("#"):
            key, _, value = line.partition("=")
            fields[key.strip()] = value.strip().strip('"')
    if fields.get("ID") != "nixos":
        return None
    parts = fields.get("VERSION_ID", "").split(".")
    if len(parts) < 2:
        return None
    release = f"{parts[0]}.{parts[1]}"
    return release if valid_release(release) else None


def configured_release(repo: Path) -> str:
    """The release the configuration is written for (system.stateVersion)."""
    text = (repo / "configuration.nix").read_text(encoding="utf-8")
    match = re.search(r'stateVersion\s*=\s*"([^"]+)"', text)
    if not match:
        raise ReleaseError("no system.stateVersion in configuration.nix")
    return match.group(1)


def resolve(source: str, repo: Path, os_release: Path = Path("/etc/os-release")) -> str:
    """Turn 'pc', 'config' or 'X.Y' into a release string."""
    if source == "pc":
        release = local_release(os_release)
        if release is None:
            raise ReleaseError("this machine is not NixOS; choose 'config' or a release")
        return release
    if source == "config":
        return configured_release(repo)
    if valid_release(source):
        return source
    raise ReleaseError(f"'{source}' is not pc, config, or a release like 25.11")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--repo", default=str(Path(__file__).resolve().parent.parent))
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("list")
    p_res = sub.add_parser("resolve")
    p_res.add_argument("source")
    p_ex = sub.add_parser("exists")
    p_ex.add_argument("release")
    args = parser.parse_args(argv)

    try:
        if args.cmd == "list":
            releases, live = fetch_releases()
            print("\n".join(releases))
            if not live:
                print("(offline: built-in list)", file=sys.stderr)
            return 0
        if args.cmd == "resolve":
            print(resolve(args.source, Path(args.repo)))
            return 0
        if args.cmd == "exists":
            ok = release_exists(args.release)
            print("yes" if ok else "no")
            return 0 if ok else 1
    except ReleaseError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 1


if __name__ == "__main__":
    sys.exit(main())
