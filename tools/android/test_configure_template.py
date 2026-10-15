import argparse
import tempfile
import unittest
from pathlib import Path

import configure_template as tool

CONFIG = """ext.versions = [
    androidGradlePlugin: '8.2.0',
    compileSdk         : 34,
    minSdk             : 21,
    targetSdk          : 34,
    buildTools         : '34.0.0',
    kotlinVersion      : '1.9.20',
]
"""

WRAPPER = "distributionUrl=https\\://services.gradle.org/distributions/gradle-8.2-bin.zip\n"

PROPERTIES = "android.useAndroidX=true\norg.gradle.jvmargs=-Xmx4536m\n"

MANIFEST = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <application
        android:label="@string/godot_project_name_string"
        android:isGame="true"
        tools:ignore="GoogleAppIndexingWarning" >
        <profileable android:shell="true" />
        <activity android:name=".GodotApp" android:screenOrientation="landscape" />
    </application>
</manifest>
"""


def make_args(**overrides):
    values = {"agp": "8.6.1", "gradle": "8.11.1", "compile_sdk": "36", "build_tools": "36.1.0"}
    values.update(overrides)
    return argparse.Namespace(**values)


def write_template(root: Path, manifest: str = MANIFEST) -> None:
    (root / "gradle" / "wrapper").mkdir(parents=True)
    (root / "config.gradle").write_text(CONFIG)
    (root / "gradle" / "wrapper" / "gradle-wrapper.properties").write_text(WRAPPER)
    (root / "gradle.properties").write_text(PROPERTIES)
    (root / "AndroidManifest.xml").write_text(manifest)


def patch_all(root: Path, args) -> None:
    tool.patch_config(root, args)
    tool.patch_wrapper(root, args)
    tool.patch_properties(root, args)
    tool.patch_manifest(root, args)


class ConfigureTemplateTest(unittest.TestCase):
    def setUp(self):
        self._dir = tempfile.TemporaryDirectory()
        self.root = Path(self._dir.name)
        self.addCleanup(self._dir.cleanup)

    def test_unpatched_template_fails_verification(self):
        write_template(self.root)
        self.assertGreaterEqual(len(tool.verify(self.root, make_args())), 6)

    def test_patch_sets_every_value(self):
        write_template(self.root)
        args = make_args()
        patch_all(self.root, args)
        self.assertEqual(tool.verify(self.root, args), [])
        config = (self.root / "config.gradle").read_text()
        self.assertIn("androidGradlePlugin: '8.6.1'", config)
        self.assertIn("compileSdk         : 36", config)
        self.assertIn("buildTools         : '36.1.0'", config)
        self.assertIn("minSdk             : 21", config)
        self.assertIn("targetSdk          : 34", config)

    def test_min_and_target_sdk_are_left_to_the_export_preset(self):
        write_template(self.root)
        patch_all(self.root, make_args())
        config = (self.root / "config.gradle").read_text()
        self.assertIn("minSdk             : 21", config)
        self.assertIn("targetSdk          : 34", config)

    def test_patch_is_idempotent(self):
        write_template(self.root)
        args = make_args()
        patch_all(self.root, args)
        first = {p.name: p.read_text() for p in self.root.rglob("*") if p.is_file()}
        patch_all(self.root, args)
        second = {p.name: p.read_text() for p in self.root.rglob("*") if p.is_file()}
        self.assertEqual(first, second)
        self.assertEqual(second["AndroidManifest.xml"].count("PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"), 1)
        self.assertEqual(second["gradle.properties"].count("suppressUnsupportedCompileSdk"), 1)

    def test_manifest_stays_valid_and_keeps_existing_content(self):
        write_template(self.root)
        patch_all(self.root, make_args())
        text = (self.root / "AndroidManifest.xml").read_text()
        self.assertIn('tools:ignore="GoogleAppIndexingWarning"', text)
        self.assertIn('android:screenOrientation="landscape"', text)
        self.assertIn("<profileable", text)

    def test_missing_anchor_fails_instead_of_guessing(self):
        write_template(self.root)
        (self.root / "config.gradle").write_text("ext.versions = [ compileSdk: 34 ]\n")
        with self.assertRaises(tool.TemplateError):
            tool.patch_config(self.root, make_args())

    def test_missing_file_fails(self):
        with self.assertRaises(tool.TemplateError):
            tool.patch_manifest(self.root, make_args())

    def test_verification_catches_a_wrong_value(self):
        write_template(self.root)
        patch_all(self.root, make_args())
        problems = tool.verify(self.root, make_args(compile_sdk="35"))
        self.assertTrue(any("compileSdk" in p for p in problems))


if __name__ == "__main__":
    unittest.main()