#!/usr/bin/env python3
"""Enable exactly one CPU architecture in export_presets.cfg so one APK is built per ABI."""

import argparse
import re
import sys

ABIS = ("armeabi-v7a", "arm64-v8a", "x86", "x86_64")


class AbiError(ValueError):
    """Raised when the ABI or the preset cannot be used."""


def select_abi(text, abi):
    if abi not in ABIS:
        raise AbiError("Unknown ABI '%s'. Use one of: %s." % (abi, ", ".join(ABIS)))
    for name in ABIS:
        value = "true" if name == abi else "false"
        text, count = re.subn(
            r"^architectures/%s=[^\r\n]*" % re.escape(name),
            lambda _m, n=name, v=value: "architectures/%s=%s" % (n, v),
            text,
            flags=re.MULTILINE,
        )
        if count != 1:
            raise AbiError("Expected exactly one architectures/%s line in the preset, found %d." % (name, count))
    return text


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("abi", choices=ABIS)
    parser.add_argument("--preset", default="export_presets.cfg")
    args = parser.parse_args(argv)
    try:
        with open(args.preset, "r", encoding="utf-8", newline="") as handle:
            text = handle.read()
        updated = select_abi(text, args.abi)
        with open(args.preset, "w", encoding="utf-8", newline="") as handle:
            handle.write(updated)
    except (AbiError, OSError) as error:
        print("::error::%s" % error)
        return 1
    print("%s: only %s is enabled" % (args.preset, args.abi))
    return 0


if __name__ == "__main__":
    sys.exit(main())