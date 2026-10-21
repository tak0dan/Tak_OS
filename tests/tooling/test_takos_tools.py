"""Tests for the Tak_OS installer and rebuild tooling (standard library only).

    python3 -m unittest discover -s tests/tooling -t tests/tooling -v
"""

from __future__ import annotations

import importlib.util
import sys
import tempfile
import unittest
import urllib.error
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[2]
SCRIPTS = REPO / "scripts"
sys.path.insert(0, str(SCRIPTS))

import takos_profiles as tp  # noqa: E402
import takos_releases as tr  # noqa: E402


def _load(name: str, path: Path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


rebuild = _load("takos_rebuild", SCRIPTS / "takos-rebuild.py")
installer = _load("takos_installer", SCRIPTS / "takos-installer.py")


def _catalog(modules: dict, profiles: dict) -> dict:
    return {"modules": modules, "profiles": profiles}


class ProfileResolverTests(unittest.TestCase):
    def setUp(self):
        self.cat = _catalog(
            {
                "base": {"path": "modules/base.nix"},
                "kde-base": {"path": "modules/kde.nix"},
                "hyprland": {"path": "modules/hyprland.nix", "requires": ["kde-base"]},
                "docker": {"path": "modules/docker.nix", "conflicts": ["vbox"]},
                "vbox": {"path": "modules/virtualbox.nix"},
            },
            {
                "minimal": {"modules": ["base"]},
                "hyprland": {"includes": ["minimal"], "modules": ["kde-base", "hyprland"]},
                "dev": {"includes": ["minimal"], "modules": ["docker"]},
                "clash": {"modules": ["docker", "vbox"]},
                "loop-a": {"includes": ["loop-b"]},
                "loop-b": {"includes": ["loop-a"]},
            },
        )

    def test_shared_base_is_kept_once(self):
        res = tp.resolve(self.cat, "hyprland")
        self.assertEqual(res.modules, ["base", "kde-base", "hyprland"])

    def test_requires_are_added_and_reported(self):
        res = tp.resolve(self.cat, "dev", ["hyprland"])
        self.assertEqual(res.modules, ["hyprland", "kde-base"])
        self.assertEqual(res.added_required, ["kde-base"])

    def test_duplicates_in_explicit_list_are_removed(self):
        res = tp.resolve(self.cat, "x", ["docker", "docker", "base"])
        self.assertEqual(res.modules, ["docker", "base"])

    def test_conflict_is_an_error(self):
        with self.assertRaisesRegex(tp.CatalogError, "conflict"):
            tp.resolve(self.cat, "clash")

    def test_unknown_module_and_profile(self):
        with self.assertRaisesRegex(tp.CatalogError, "unknown module"):
            tp.resolve(self.cat, "x", ["nope"])
        with self.assertRaisesRegex(tp.CatalogError, "unknown profile"):
            tp.resolve(self.cat, "nope")

    def test_include_cycle_is_detected(self):
        with self.assertRaisesRegex(tp.CatalogError, "cycle"):
            tp.resolve(self.cat, "loop-a")

    def test_nix_output_skips_already_loaded_modules(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            (repo / "configuration.nix").write_text('imports = [ ./modules/base.nix ];\n')
            (repo / "profiles").mkdir()
            (repo / "profiles/catalog.toml").write_text(
                '[modules.base]\npath = "modules/base.nix"\n'
                '[modules.docker]\npath = "modules/docker.nix"\n'
                '[profiles.p]\nmodules = ["base", "docker"]\n'
            )
            _res, text = tp.build_selection(repo, "p")
        self.assertIn("./modules/docker.nix", text)
        self.assertNotIn("./modules/base.nix", text.split("imports")[1])
        self.assertIn("Already loaded by configuration.nix", text)

    def test_real_catalog_is_valid(self):
        cat = tp.load_catalog(REPO)
        self.assertEqual(tp.check(cat, REPO), [])


class RebuildLogicTests(unittest.TestCase):
    # Real text printed by NixOS for a renamed attribute.
    RENAME_WARNING = "evaluation warning: 'swww' has been renamed to 'awww'\n"
    # Removed attributes use typographic quotes in nixpkgs.
    REMOVED_ERROR = "error: Package ‘old-tool’ has been removed\n"

    def test_renames_are_parsed_from_warnings(self):
        renames, removed = rebuild.parse_eval_messages(self.RENAME_WARNING * 2)
        self.assertEqual(renames, {"swww": "awww"})
        self.assertEqual(removed, [])

    def test_removed_names_are_parsed(self):
        renames, removed = rebuild.parse_eval_messages(self.REMOVED_ERROR)
        self.assertEqual(renames, {})
        self.assertEqual(removed, ["old-tool"])

    def test_rewrite_matches_identifiers_only(self):
        text = "environment.systemPackages = [ pkgs.swww swww ];\nswww-extras = 1; my-swww = 2;\n"
        new, count = rebuild.rewrite_names(text, {"swww": "awww"})
        self.assertEqual(count, 2)
        self.assertIn("pkgs.awww awww", new)
        self.assertIn("swww-extras", new)
        self.assertIn("my-swww", new)

    def test_plan_and_rollback_on_temp_repo(self):
        with tempfile.TemporaryDirectory() as tmp:
            repo = Path(tmp)
            target = repo / "packages" / "x.nix"
            target.parent.mkdir()
            original = "[ pkgs.swww ]\n"
            target.write_text(original)
            changes = rebuild.plan_renames(repo, {"swww": "awww"})
            self.assertEqual(list(changes), [target])
            self.assertEqual(target.read_text(), original)  # planning writes nothing
            saved = rebuild.apply_changes(changes)
            self.assertIn("awww", target.read_text())
            rebuild.rollback(saved)
            self.assertEqual(target.read_text(), original)

    def test_release_validation(self):
        self.assertTrue(rebuild.valid_release("25.11"))
        self.assertFalse(rebuild.valid_release("25.11.1"))
        self.assertFalse(rebuild.valid_release("unstable"))


class ReleaseTests(unittest.TestCase):
    def test_local_release_from_os_release(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "os-release"
            path.write_text('ID=nixos\nVERSION_ID="25.11.5198.e576e3c9cf9b"\n')
            self.assertEqual(tr.local_release(path), "25.11")

    def test_non_nixos_has_no_local_release(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "os-release"
            path.write_text("ID=arch\nVERSION_ID=rolling\n")
            self.assertIsNone(tr.local_release(path))
            with self.assertRaises(tr.ReleaseError):
                tr.resolve("pc", REPO, path)

    def test_configured_release_reads_state_version(self):
        self.assertEqual(tr.configured_release(REPO), "26.05")

    def test_resolve_accepts_only_known_forms(self):
        self.assertEqual(tr.resolve("25.05", REPO), "25.05")
        with self.assertRaises(tr.ReleaseError):
            tr.resolve("bogus", REPO)

    def test_fetch_falls_back_when_offline(self):
        with mock.patch.object(tr.urllib.request, "urlopen",
                               side_effect=urllib.error.URLError("offline")):
            releases, live = tr.fetch_releases()
        self.assertFalse(live)
        self.assertIn("23.05", releases)
        self.assertIn("26.05", releases)

    def test_fetch_parses_bucket_listing(self):
        xml = (b'<?xml version="1.0"?>'
               b'<ListBucketResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">'
               b"<Prefix>nixos/</Prefix><Prefix>nixos/22.11/</Prefix>"
               b"<Prefix>nixos/23.05/</Prefix><Prefix>nixos/25.11/</Prefix>"
               b"<Prefix>nixos/25.11-small/</Prefix></ListBucketResult>")
        resp = mock.MagicMock()
        resp.read.return_value = xml
        cm = mock.MagicMock()
        cm.__enter__.return_value = resp
        with mock.patch.object(tr.urllib.request, "urlopen", return_value=cm):
            releases, live = tr.fetch_releases()
        self.assertTrue(live)
        self.assertEqual(releases, ["25.11", "23.05"])  # 22.11 is below the floor


class InstallerCommandTests(unittest.TestCase):
    def test_command_carries_profile_modules_and_release(self):
        argv, env = installer.build_install_command(
            "devops", ["docker", "httpd"], release="25.11", dry_run=True, edit=False
        )
        self.assertEqual(argv[-1], "--dry-run")
        self.assertEqual(env["TAKOS_PROFILE"], "devops")
        self.assertEqual(env["TAKOS_MODULES"], "docker,httpd")
        self.assertEqual(env["TAKOS_RELEASE"], "25.11")

    def test_defaults_leave_release_to_install_sh(self):
        _argv, env = installer.build_install_command("minimal", None)
        self.assertNotIn("TAKOS_MODULES", env)
        self.assertNotIn("TAKOS_RELEASE", env)


if __name__ == "__main__":
    unittest.main()
