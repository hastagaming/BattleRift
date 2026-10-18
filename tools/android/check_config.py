#!/usr/bin/env python3
"""Check that the sources agree with tools/android/toolchain.env before any build starts."""

import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def load_env(path):
    values = {}
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                values[key] = value
    return values


def load_preset(path):
    options = {}
    in_options = False
    with open(path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\r\n")
            if line.startswith("["):
                in_options = line == "[preset.0.options]"
            elif in_options and "=" in line:
                key, value = line.split("=", 1)
                options[key] = value.strip().strip('"')
    return options


def gradle_number(text, name):
    match = re.search(r"^\s*%s\s*=\s*([0-9]+)\s*$" % name, text, flags=re.MULTILINE)
    return int(match.group(1)) if match else None


def check_language_packs(preset_text):
    """The language packs are .toml files, which Godot only exports when include_filter lists them."""
    match = re.search(r'^include_filter="([^"]*)"', preset_text, flags=re.MULTILINE)
    patterns = [p.strip() for p in (match.group(1) if match else "").split(",")]
    if "i18n/*.toml" not in patterns:
        return ['export_presets.cfg include_filter must contain "i18n/*.toml". Without it the APK has no language packs.']
    return []


def check(env, options, plugin_gradle):
    errors = []
    expect = {
        "gradle_build/use_gradle_build": "true",
        "gradle_build/min_sdk": env["ANDROID_MIN_SDK"],
        "gradle_build/target_sdk": env["ANDROID_TARGET_SDK"],
        "package/unique_name": env["ANDROID_PACKAGE"],
        "architectures/arm64-v8a": "true",
        "package/signed": "true",
    }
    for key, wanted in expect.items():
        if options.get(key) != wanted:
            errors.append("export_presets.cfg %s is '%s', expected '%s'." % (key, options.get(key), wanted))
    for key in ["keystore/release", "keystore/release_user", "keystore/release_password",
                "keystore/debug", "keystore/debug_user", "keystore/debug_password"]:
        if options.get(key):
            errors.append("export_presets.cfg %s must be empty. Signing secrets never belong in the repository." % key)
    plugin_min = gradle_number(plugin_gradle, "minSdk")
    plugin_compile = gradle_number(plugin_gradle, "compileSdk")
    if plugin_min is None or plugin_min > int(env["ANDROID_MIN_SDK"]):
        errors.append("The notify plugin minSdk (%s) must not be higher than %s." % (plugin_min, env["ANDROID_MIN_SDK"]))
    if plugin_compile != int(env["ANDROID_COMPILE_SDK"]):
        errors.append("The notify plugin compileSdk (%s) must be %s." % (plugin_compile, env["ANDROID_COMPILE_SDK"]))
    return errors


def main():
    env = load_env(os.path.join(ROOT, "tools", "android", "toolchain.env"))
    options = load_preset(os.path.join(ROOT, "export_presets.cfg"))
    with open(os.path.join(ROOT, "android-plugin", "battlerift-notify", "build.gradle.kts"), encoding="utf-8") as handle:
        plugin_gradle = handle.read()
    errors = check(env, options, plugin_gradle)
    with open(os.path.join(ROOT, "export_presets.cfg"), encoding="utf-8") as handle:
        errors.extend(check_language_packs(handle.read()))
    for error in errors:
        print("::error::%s" % error)
    if errors:
        return 1
    print("Configuration is consistent: minSdk %s, targetSdk %s, compileSdk %s, package %s."
          % (env["ANDROID_MIN_SDK"], env["ANDROID_TARGET_SDK"], env["ANDROID_COMPILE_SDK"], env["ANDROID_PACKAGE"]))
    return 0


if __name__ == "__main__":
    sys.exit(main())