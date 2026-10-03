#!/usr/bin/env python3
"""Regression checks for current catalog facts, using temporary repo copies."""

import shutil
import tempfile
import unittest
from pathlib import Path

import storybook_manifest as manifest


class CatalogFactsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = Path(temporary.name)
        self.scenarios = manifest.load_manifest(manifest.DEFAULT_MANIFEST)
        paths = list(manifest.CATALOG_FACTS) + [
            "Sources/Liveline/LivelineChartContent.swift",
            "Sources/Liveline/LivelineAdvancedContent.swift",
        ]
        for relative in paths:
            target = self.root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(manifest.ROOT / relative, target)

    def test_current_facts_and_historical_counts(self):
        path = self.root / "README.md"
        path.write_text(path.read_text() + "\nHistorical release: 12 scenarios.\n")
        manifest.validate_catalog_facts(self.scenarios, self.root)

    def test_missing_and_stale_facts_in_every_designated_document(self):
        for relative, facts in manifest.CATALOG_FACTS.items():
            path = self.root / relative
            original = path.read_text()
            for fact in facts:
                begin = f"<!-- catalog:{fact} -->"
                for invalid in ("missing", "stale", "duplicate-stale"):
                    with self.subTest(path=relative, fact=fact, invalid=invalid):
                        if invalid == "missing":
                            changed = original.replace(begin, "<!-- removed -->")
                        elif invalid == "stale":
                            before, after = original.split(begin, 1)
                            value, rest = after.split("<!-- /catalog -->", 1)
                            changed = before + begin + str(int(value) + 1) + "<!-- /catalog -->" + rest
                        else:
                            changed = original + f"\n{begin}0<!-- /catalog -->\n"
                        path.write_text(changed)
                        with self.assertRaisesRegex(ValueError, f"catalog:{fact}"):
                            manifest.validate_catalog_facts(self.scenarios, self.root)
                        path.write_text(original)

    def test_changes_to_authoritative_sources_invalidate_docs(self):
        with self.assertRaisesRegex(ValueError, "catalog:scenarios"):
            manifest.validate_catalog_facts(self.scenarios[:-1], self.root)
        for relative, fact, first_case in (
            ("Sources/Liveline/LivelineChartContent.swift", "families", "line\n"),
            ("Sources/Liveline/LivelineAdvancedContent.swift", "advanced", "violin"),
        ):
            with self.subTest(fact=fact):
                path = self.root / relative
                original = path.read_text()
                declaration = f"    case {first_case}"
                path.write_text(original.replace(declaration, "    case newFamily\n" + declaration, 1))
                with self.assertRaisesRegex(ValueError, f"catalog:{fact}"):
                    manifest.validate_catalog_facts(self.scenarios, self.root)
                path.write_text(original)

    def test_unsupported_enum_layout_fails_instead_of_undercounting(self):
        path = self.root / "Sources/Liveline/LivelineChartContent.swift"
        path.write_text("enum LivelineChartKind {\n    case line, bars\n}\n")
        with self.assertRaisesRegex(ValueError, "one catalog case per line"):
            manifest.enum_case_count(path, "LivelineChartKind")


if __name__ == "__main__":
    unittest.main()
