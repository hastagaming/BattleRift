import os
import tempfile
import unittest

import version

PRESET = (
    '[preset.0.options]\n'
    '\n'
    'gradle_build/min_sdk="24"\n'
    'architectures/arm64-v8a=true\n'
    'version/code=1791546920\n'
    'version/name="1.0"\n'
    'package/unique_name="com.battlerift"\n'
    'permissions/internet=true\n'
)


class ParseTagTest(unittest.TestCase):
    def test_examples_from_the_spec(self):
        self.assertEqual(version.parse_tag("v1.0.0"), ("1.0.0", 1000000))
        self.assertEqual(version.parse_tag("v1.2.0"), ("1.2.0", 1002000))
        self.assertEqual(version.parse_tag("v1.2.3"), ("1.2.3", 1002003))
        self.assertEqual(version.parse_tag("v2.0.0"), ("2.0.0", 2000000))

    def test_rejects_invalid_tags(self):
        for tag in ["1.2.0", "v1.2", "v1.2.3.4", "v01.2.0", "v1.2.0-rc1", "vx.y.z", "", "v1.2.0 ", "V1.2.0"]:
            with self.subTest(tag=tag):
                with self.assertRaises(version.VersionError):
                    version.parse_tag(tag)

    def test_rejects_out_of_range(self):
        for tag in ["v0.0.0", "v1.1000.0", "v1.0.1000", "v2001.0.0"]:
            with self.subTest(tag=tag):
                with self.assertRaises(version.VersionError):
                    version.parse_tag(tag)

    def test_highest_allowed_code_fits_in_android_limit(self):
        _, code = version.parse_tag("v2000.999.999")
        self.assertLess(code, 2100000000)

    def test_code_follows_semantic_version_order(self):
        tags = ["v0.1.0", "v0.9.9", "v1.0.0", "v1.0.1", "v1.1.0", "v1.10.0", "v2.0.0", "v10.0.0"]
        codes = [version.parse_tag(tag)[1] for tag in tags]
        self.assertEqual(codes, sorted(codes))
        self.assertEqual(len(set(codes)), len(codes))


class ApplyPresetTest(unittest.TestCase):
    def test_only_version_lines_change(self):
        updated = version.apply_to_preset(PRESET, "1.2.0", 1002000)
        before = PRESET.splitlines()
        after = updated.splitlines()
        self.assertEqual(len(before), len(after))
        changed = [(a, b) for a, b in zip(before, after) if a != b]
        self.assertEqual(
            changed,
            [("version/code=1791546920", "version/code=1002000"), ('version/name="1.0"', 'version/name="1.2.0"')],
        )

    def test_keeps_crlf_line_endings(self):
        crlf = PRESET.replace("\n", "\r\n")
        updated = version.apply_to_preset(crlf, "1.2.0", 1002000)
        self.assertNotIn("\r\r", updated)
        self.assertEqual(updated.count("\r\n"), crlf.count("\r\n"))

    def test_fails_when_a_field_is_missing_or_duplicated(self):
        with self.assertRaises(version.VersionError):
            version.apply_to_preset(PRESET.replace("version/code=1791546920\n", ""), "1.0.0", 1000000)
        with self.assertRaises(version.VersionError):
            version.apply_to_preset(PRESET + 'version/name="2.0"\n', "1.0.0", 1000000)


class CheckOrderTest(unittest.TestCase):
    def test_accepts_a_newer_tag(self):
        version.check_order("v1.2.0", ["v1.0.0", "v1.1.9", "not-a-release", "v1.2.0"])

    def test_rejects_an_older_tag(self):
        with self.assertRaises(version.VersionError):
            version.check_order("v1.0.1", ["v1.0.0", "v1.1.0"])

    def test_first_release_has_no_previous_tags(self):
        version.check_order("v1.0.0", [])


class CommandLineTest(unittest.TestCase):
    def test_apply_and_resolve(self):
        with tempfile.TemporaryDirectory() as tmp:
            preset = os.path.join(tmp, "export_presets.cfg")
            output = os.path.join(tmp, "github_output")
            with open(preset, "w", encoding="utf-8", newline="") as handle:
                handle.write(PRESET)
            self.assertEqual(version.main(["apply", "v1.2.0", "--preset", preset]), 0)
            with open(preset, "r", encoding="utf-8") as handle:
                text = handle.read()
            self.assertIn('version/name="1.2.0"', text)
            self.assertIn("version/code=1002000", text)
            self.assertEqual(version.main(["resolve", "v1.2.0", "--github-output", output]), 0)
            with open(output, "r", encoding="utf-8") as handle:
                self.assertEqual(handle.read(), "version_name=1.2.0\nversion_code=1002000\n")

    def test_bad_tag_returns_failure(self):
        self.assertEqual(version.main(["resolve", "release-1"]), 1)


if __name__ == "__main__":
    unittest.main()