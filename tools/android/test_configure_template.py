import os
import shutil
import tempfile
import unittest

import configure_template as ct

CONFIG_GRADLE = """ext.versions = [
    androidGradlePlugin: '8.2.0',
    compileSdk         : 34,
    minSdk             : 21,
    targetSdk          : 34,
    buildTools         : '34.0.0',
    kotlinVersion      : '1.9.20',
    ndkVersion         : '23.2.8568313',
]
"""
MANIFEST = """<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <application
        android:label="@string/godot_project_name_string"
        tools:ignore="GoogleAppIndexingWarning" >
        <activity
            android:name=".GodotApp"
            android:exported="true" >
        </activity>
    </application>
</manifest>
"""
WRAPPER = (
    "distributionBase=GRADLE_USER_HOME\n"
    "distributionUrl=https\\://services.gradle.org/distributions/gradle-8.2-bin.zip\n"
)
PROPERTIES = "android.useAndroidX=true\nandroid.enableJetifier=true\n"
ARGS = dict(agp="8.6.1", gradle="8.11.1", compile_sdk="36", build_tools="36.1.0")


def read(path):
    with open(path, "r", encoding="utf-8", newline="") as handle:
        return handle.read()


class ConfigureTemplateTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.tmp)
        os.makedirs(os.path.join(self.tmp, "gradle", "wrapper"))
        for name, content in [
            ("config.gradle", CONFIG_GRADLE),
            ("AndroidManifest.xml", MANIFEST),
            ("gradle.properties", PROPERTIES),
            (os.path.join("gradle", "wrapper", "gradle-wrapper.properties"), WRAPPER),
        ]:
            with open(os.path.join(self.tmp, name), "w", encoding="utf-8", newline="") as handle:
                handle.write(content)

    def run_configure(self):
        ct.configure(self.tmp, ARGS["agp"], ARGS["gradle"], ARGS["compile_sdk"], ARGS["build_tools"])

    def test_config_gradle_versions(self):
        self.run_configure()
        text = read(os.path.join(self.tmp, "config.gradle"))
        self.assertIn("androidGradlePlugin: '8.6.1'", text)
        self.assertIn("compileSdk         : 36", text)
        self.assertIn("buildTools         : '36.1.0'", text)

    def test_config_gradle_keeps_unrelated_values(self):
        original = read(os.path.join(self.tmp, "config.gradle"))
        self.run_configure()
        text = read(os.path.join(self.tmp, "config.gradle"))
        for keep in ["minSdk             : 21", "kotlinVersion      : '1.9.20'", "ndkVersion         : '23.2.8568313'"]:
            self.assertIn(keep, text)
        changed = [l for l, o in zip(text.splitlines(), original.splitlines()) if l != o]
        self.assertEqual(len(changed), 3)

    def test_wrapper_version(self):
        self.run_configure()
        text = read(os.path.join(self.tmp, "gradle", "wrapper", "gradle-wrapper.properties"))
        self.assertIn("gradle-8.11.1-bin.zip", text)
        self.assertNotIn("gradle-8.2-bin.zip", text)
        self.assertIn("distributionUrl=https\\://services.gradle.org", text)

    def test_gradle_properties(self):
        self.run_configure()
        text = read(os.path.join(self.tmp, "gradle.properties"))
        self.assertIn("android.suppressUnsupportedCompileSdk=36\n", text)
        self.assertIn("android.useAndroidX=true", text)

    def test_manifest_opt_outs(self):
        self.run_configure()
        text = read(os.path.join(self.tmp, "AndroidManifest.xml"))
        self.assertEqual(text.count('android:enableOnBackInvokedCallback="false"'), 1)
        self.assertEqual(text.count("PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"), 1)
        self.assertLess(text.index("<application"), text.index("PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"))
        self.assertLess(text.index("PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"), text.index("</application>"))
        self.assertIn('android:name=".GodotApp"', text)

    def test_manifest_is_well_formed_xml(self):
        import xml.dom.minidom
        self.run_configure()
        xml.dom.minidom.parse(os.path.join(self.tmp, "AndroidManifest.xml"))

    def test_idempotent(self):
        self.run_configure()
        first = {n: read(os.path.join(self.tmp, n)) for n in ["config.gradle", "AndroidManifest.xml", "gradle.properties"]}
        self.run_configure()
        for name, content in first.items():
            self.assertEqual(read(os.path.join(self.tmp, name)), content, name)

    def test_fails_on_unexpected_template(self):
        with open(os.path.join(self.tmp, "config.gradle"), "w", encoding="utf-8") as handle:
            handle.write("ext.versions = [ minSdk: 21 ]\n")
        with self.assertRaises(ct.PatchError):
            self.run_configure()

    def test_fails_when_files_are_missing(self):
        os.remove(os.path.join(self.tmp, "AndroidManifest.xml"))
        with self.assertRaises(ct.PatchError):
            self.run_configure()


if __name__ == "__main__":
    unittest.main()