import unittest

import check_config as cc

ENV = {
    "ANDROID_MIN_SDK": "24", "ANDROID_TARGET_SDK": "36", "ANDROID_COMPILE_SDK": "36",
    "ANDROID_PACKAGE": "com.battlerift",
}
OPTIONS = {
    "gradle_build/use_gradle_build": "true", "gradle_build/min_sdk": "24", "gradle_build/target_sdk": "36",
    "package/unique_name": "com.battlerift", "architectures/arm64-v8a": "true", "package/signed": "true",
    "keystore/release": "", "keystore/release_password": "",
}
PLUGIN = "android {\n    compileSdk = 36\n    defaultConfig {\n        minSdk = 24\n    }\n}\n"


class CheckConfigTest(unittest.TestCase):
    def test_consistent(self):
        self.assertEqual(cc.check(ENV, OPTIONS, PLUGIN), [])

    def test_wrong_min_sdk(self):
        self.assertEqual(len(cc.check(ENV, dict(OPTIONS, **{"gradle_build/min_sdk": "26"}), PLUGIN)), 1)

    def test_plugin_min_sdk_too_high(self):
        self.assertEqual(len(cc.check(ENV, OPTIONS, PLUGIN.replace("minSdk = 24", "minSdk = 26"))), 1)

    def test_committed_secret(self):
        self.assertEqual(len(cc.check(ENV, dict(OPTIONS, **{"keystore/release_password": "x"}), PLUGIN)), 1)

    def test_arm64_missing(self):
        self.assertEqual(len(cc.check(ENV, dict(OPTIONS, **{"architectures/arm64-v8a": "false"}), PLUGIN)), 1)


if __name__ == "__main__":
    unittest.main()