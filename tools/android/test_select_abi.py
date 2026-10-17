import unittest

import select_abi

PRESET = (
    "[preset.0.options]\n"
    "\n"
    "architectures/armeabi-v7a=true\n"
    "architectures/arm64-v8a=true\n"
    "architectures/x86=false\n"
    "architectures/x86_64=true\n"
    'package/unique_name="com.battlerift"\n'
)


def enabled(text):
    result = []
    for line in text.splitlines():
        if line.startswith("architectures/") and line.endswith("=true"):
            result.append(line.split("/", 1)[1].split("=", 1)[0])
    return result


class SelectAbiTest(unittest.TestCase):
    def test_each_abi_is_the_only_one_enabled(self):
        for abi in select_abi.ABIS:
            with self.subTest(abi=abi):
                self.assertEqual(enabled(select_abi.select_abi(PRESET, abi)), [abi])

    def test_x86_does_not_touch_x86_64(self):
        text = select_abi.select_abi(PRESET, "x86")
        self.assertIn("architectures/x86=true", text)
        self.assertIn("architectures/x86_64=false", text)

    def test_other_lines_stay_the_same(self):
        text = select_abi.select_abi(PRESET, "arm64-v8a")
        self.assertIn('package/unique_name="com.battlerift"', text)
        self.assertEqual(len(text.splitlines()), len(PRESET.splitlines()))

    def test_keeps_crlf_line_endings(self):
        crlf = PRESET.replace("\n", "\r\n")
        text = select_abi.select_abi(crlf, "x86_64")
        self.assertNotIn("\r\r", text)
        self.assertEqual(text.count("\r\n"), crlf.count("\r\n"))

    def test_rejects_unknown_abi_and_missing_keys(self):
        with self.assertRaises(select_abi.AbiError):
            select_abi.select_abi(PRESET, "mips")
        with self.assertRaises(select_abi.AbiError):
            select_abi.select_abi(PRESET.replace("architectures/x86=false\n", ""), "arm64-v8a")


if __name__ == "__main__":
    unittest.main()