import tempfile
import unittest
from pathlib import Path

import check_packs

META = (
    'format = 1\ncode = "{code}"\nname = "{name}"\nname_en = "{name}"\nversion = 1\n'
    'direction = "ltr"\nplural_rule = "{rule}"\ndecimal_separator = "."\ngroup_separator = ","\n'
    'date_order = "dmy"\ndate_separator = "/"\nfallback = "en"\n'
)


def pack(code, rule, strings):
    body = "[meta]\n" + META.format(code=code, name=code, rule=rule) + "\n[strings]\n"
    for key, value in strings.items():
        body += f'"{key}" = "{value}"\n'
    return body


def make_root(packs, script=""):
    root = Path(tempfile.mkdtemp())
    (root / "i18n").mkdir()
    (root / "scripts").mkdir()
    codes = ", ".join(f'"{c}"' for c in packs)
    (root / "i18n" / "index.toml").write_text(f"format = 1\nlanguages = [{codes}]\n", encoding="utf-8")
    for code, text in packs.items():
        (root / "i18n" / f"{code}.toml").write_text(text, encoding="utf-8")
    (root / "scripts" / "screen.gd").write_text(script, encoding="utf-8")
    return root


EN = pack("en", "one_other", {"a.hello": "Hello {name}", "a.items.one": "{count} item", "a.items.other": "{count} items"})


class CheckPacksTest(unittest.TestCase):
    def test_consistent_packs_pass(self):
        id_pack = pack("id", "none", {"a.hello": "Halo {name}", "a.items.other": "{count} barang"})
        root = make_root({"en": EN, "id": id_pack}, 'var x = Loc.t("a.hello")')
        errors, report = check_packs.run(root, ["en", "id"])
        self.assertEqual(errors, [])
        self.assertEqual(report["coverage"]["id"], 100.0)

    def test_placeholder_mismatch_is_reported(self):
        bad = pack("id", "none", {"a.hello": "Halo {nama}", "a.items.other": "{count} barang"})
        errors, _ = check_packs.run(make_root({"en": EN, "id": bad}), ["en"])
        self.assertTrue(any("placeholders" in e for e in errors))

    def test_missing_plural_form_is_reported(self):
        bad = pack("de", "one_other", {"a.hello": "Hallo {name}", "a.items.other": "{count} Dinge"})
        errors, _ = check_packs.run(make_root({"en": EN, "de": bad}), ["en"])
        self.assertTrue(any("missing the 'one' form" in e for e in errors))

    def test_required_language_must_be_complete(self):
        short = pack("id", "none", {"a.hello": "Halo {name}"})
        errors, report = check_packs.run(make_root({"en": EN, "id": short}), ["en", "id"])
        self.assertTrue(any("required language is missing" in e for e in errors))
        self.assertLess(report["coverage"]["id"], 100.0)

    def test_optional_language_may_be_partial(self):
        short = pack("fr", "one_other_zero_one", {"a.hello": "Bonjour {name}"})
        errors, _ = check_packs.run(make_root({"en": EN, "fr": short}), ["en"])
        self.assertEqual(errors, [])

    def test_unknown_key_in_code_is_reported(self):
        root = make_root({"en": EN}, 'label.text = Loc.t("a.missing")')
        errors, _ = check_packs.run(root, ["en"])
        self.assertTrue(any("a.missing" in e for e in errors))

    def test_unknown_plural_rule_is_reported(self):
        bad = pack("xx", "klingon", {"a.hello": "Qapla {name}"})
        errors, _ = check_packs.run(make_root({"en": EN, "xx": bad}), ["en"])
        self.assertTrue(any("plural_rule" in e for e in errors))

    def test_hardcoded_texts_are_counted(self):
        script = 'label.text = "Hello there"\nnotify("Saved")\nlabel.text = Loc.t("a.hello")\n'
        errors, report = check_packs.run(make_root({"en": EN}, script), ["en"], max_unconverted=1)
        self.assertEqual(report["unconverted"], 2)
        self.assertTrue(any("still written" in e for e in errors))

    def test_shipped_packs_are_consistent(self):
        root = Path(__file__).resolve().parents[2]
        errors, report = check_packs.run(root, ["en", "id", "de", "ms", "ja"])
        self.assertEqual(errors, [])
        for code in ["en", "id", "de", "ms", "ja"]:
            self.assertEqual(report["coverage"][code], 100.0)


if __name__ == "__main__":
    unittest.main()