"""Tests for scripts/takos_tokens.py (standard library only)."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts"))

import takos_tokens as tt  # noqa: E402


class LexerTests(unittest.TestCase):
    def test_braces_in_strings_and_comments_do_not_count(self):
        text = 'a = "}}}";\n# {{{\nb = ${x};\n/* { */\nc = 1;\n'
        self.assertEqual(tt.line_depths(text)[:5], [0, 0, 0, 0, 0])

    def test_multiline_string_lines_are_marked(self):
        text = "x = ''\n  inside = 1;\n'';\ny = 2;\n"
        depths = tt.line_depths(text)
        self.assertEqual(depths[1], -1)  # line 2 starts inside ''...''
        self.assertEqual(depths[3], 0)

    def test_depth_follows_nesting(self):
        text = "{ pkgs, ... }:\n{\n  a = {\n    b = 1;\n  };\n}\n"
        self.assertEqual(tt.line_depths(text)[:6], [0, 0, 1, 2, 2, 1])


class TokenTests(unittest.TestCase):
    def _module(self, body: str) -> tuple[Path, Path]:
        tmp = tempfile.mkdtemp()
        repo = Path(tmp)
        (repo / "modules").mkdir()
        path = repo / "modules" / "demo.nix"
        path.write_text(body, encoding="utf-8")
        return repo, path

    def test_top_level_bindings_are_tokens_and_nested_ones_are_not(self):
        repo, path = self._module(
            "{ pkgs, ... }:\n{\n"
            "  services.demo = {\n    enable = true;\n    inner = 1;\n  };\n"
            "  environment.systemPackages = with pkgs; [ git ];\n"
            "}\n"
        )
        names = [t.name for t in tt.tokens_in_file(repo, path) if t.kind == "binding"]
        self.assertEqual(names, ["services.demo", "environment.systemPackages"])

    def test_module_token_covers_whole_file(self):
        repo, path = self._module("{ ... }:\n{\n  a = 1;\n}\n")
        module = [t for t in tt.tokens_in_file(repo, path) if t.kind == "module"][0]
        self.assertEqual((module.name, module.start, module.end), ("demo", 1, 4))

    def test_fuzzy_find(self):
        repo, path = self._module("{ ... }:\n{\n  services.networkManager = {};\n}\n")
        hits = tt.find_tokens(tt.index_repo(repo), "networkmanager")
        self.assertTrue(any(h.name == "services.networkManager" for h in hits))


class ReconstructTests(unittest.TestCase):
    def test_missing_module_is_reconstructed_from_closest_token(self):
        tmp = Path(tempfile.mkdtemp())
        (tmp / "profiles").mkdir()
        (tmp / "profiles" / "catalog.toml").write_text(
            '[modules.gamer]\npath = "modules/gamer.nix"\n'
            '[profiles.p]\nmodules = ["gamer"]\n', encoding="utf-8")
        (tmp / "modules").mkdir()
        (tmp / "modules" / "gaming.nix").write_text(
            "{ ... }:\n{\n  programs.steam = {\n    enable = true;\n  };\n}\n", encoding="utf-8")
        tokens = tt.index_repo(tmp)
        self.assertTrue(any(t.name == "gaming" and t.kind == "module" for t in tokens))
        self.assertIsNotNone(tt.find_tokens(tokens, "gamer", limit=1))

        # Preview writes nothing; the module is still missing.
        self.assertEqual(tt.main(["--repo", str(tmp), "missing"]), 1)
        self.assertEqual(tt.main(["--repo", str(tmp), "reconstruct", "gamer"]), 0)
        self.assertFalse((tmp / "modules" / "gamer.nix").exists())

        self.assertEqual(tt.main(["--repo", str(tmp), "reconstruct", "gamer", "--apply"]), 0)
        text = (tmp / "modules" / "gamer.nix").read_text(encoding="utf-8")
        self.assertIn("RECONSTRUCTED", text)
        self.assertIn("programs.steam", text)


if __name__ == "__main__":
    unittest.main()
