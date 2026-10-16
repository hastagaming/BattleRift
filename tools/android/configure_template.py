#!/usr/bin/env python3
"""Patch the Godot 4.3 Android build template so it builds for compileSdk 36.

The template that ships with Godot 4.3 uses AGP 8.2.0, Gradle 8.2 and compileSdk 34.
This script changes only what is needed for API 36:
  * config.gradle: Android Gradle Plugin, compileSdk and build tools version
  * gradle-wrapper.properties: Gradle version
  * gradle.properties: allow a compileSdk newer than the plugin was tested with
  * AndroidManifest.xml: opt out of predictive back and of restricted resizability,
    which apps targeting API 36 would otherwise get by default

Every change is idempotent, so running the script twice gives the same result.
"""

import argparse
import os
import re
import sys

BACK_ATTRIBUTE = 'android:enableOnBackInvokedCallback="false"'
RESIZE_PROPERTY = (
    '        <property\n'
    '            android:name="android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"\n'
    '            android:value="true" />\n'
)


class PatchError(RuntimeError):
    """Raised when the template does not look like the expected Godot template."""


def _replace_once(text, pattern, replacement, label):
    result, count = re.subn(pattern, replacement, text, count=0, flags=re.MULTILINE)
    if count != 1:
        raise PatchError("Expected exactly one %s, found %d." % (label, count))
    return result


def patch_config_gradle(text, agp, compile_sdk, build_tools):
    text = _replace_once(
        text,
        r"^(\s*androidGradlePlugin\s*:\s*)'[^']*'",
        lambda m: "%s'%s'" % (m.group(1), agp),
        "androidGradlePlugin entry",
    )
    text = _replace_once(
        text,
        r"^(\s*compileSdk\s*:\s*)[0-9]+",
        lambda m: "%s%s" % (m.group(1), compile_sdk),
        "compileSdk entry",
    )
    text = _replace_once(
        text,
        r"^(\s*buildTools\s*:\s*)'[^']*'",
        lambda m: "%s'%s'" % (m.group(1), build_tools),
        "buildTools entry",
    )
    return text


def patch_wrapper(text, gradle_version):
    return _replace_once(
        text,
        r"gradle-[0-9][0-9.]*-bin\.zip",
        lambda _m: "gradle-%s-bin.zip" % gradle_version,
        "Gradle distributionUrl",
    )


def ensure_property(text, key, value):
    line = "%s=%s" % (key, value)
    if re.search(r"^%s=" % re.escape(key), text, flags=re.MULTILINE):
        return re.sub(r"^%s=[^\r\n]*" % re.escape(key), lambda _m: line, text, flags=re.MULTILINE)
    if text and not text.endswith("\n"):
        text += "\n"
    return text + line + "\n"


def patch_manifest(text):
    application = re.search(r"<application\b", text)
    if not application:
        raise PatchError("The template manifest has no <application> element.")
    if "enableOnBackInvokedCallback" not in text:
        text = text[: application.end()] + "\n        " + BACK_ATTRIBUTE + text[application.end():]
    if "PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY" not in text:
        closing = text.rfind("</application>")
        if closing == -1:
            raise PatchError("The template manifest has no </application> element.")
        text = text[:closing] + RESIZE_PROPERTY + "\n    " + text[closing:]
    return text


def _read(path):
    with open(path, "r", encoding="utf-8", newline="") as handle:
        return handle.read()


def _write(path, text):
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def _existing(build_dir, *candidates):
    found = [os.path.join(build_dir, c) for c in candidates if os.path.isfile(os.path.join(build_dir, c))]
    if not found:
        raise PatchError("None of these files exist in %s: %s" % (build_dir, ", ".join(candidates)))
    return found


def configure(build_dir, agp, gradle, compile_sdk, build_tools):
    for path in _existing(build_dir, "config.gradle", "app/config.gradle"):
        _write(path, patch_config_gradle(_read(path), agp, compile_sdk, build_tools))
    for path in _existing(build_dir, "gradle/wrapper/gradle-wrapper.properties"):
        _write(path, patch_wrapper(_read(path), gradle))
    props = os.path.join(build_dir, "gradle.properties")
    current = _read(props) if os.path.isfile(props) else ""
    _write(props, ensure_property(current, "android.suppressUnsupportedCompileSdk", compile_sdk))
    for path in _existing(build_dir, "AndroidManifest.xml", "app/AndroidManifest.xml"):
        _write(path, patch_manifest(_read(path)))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("build_dir")
    parser.add_argument("--agp", required=True)
    parser.add_argument("--gradle", required=True)
    parser.add_argument("--compile-sdk", required=True)
    parser.add_argument("--build-tools", required=True)
    args = parser.parse_args(argv)
    try:
        configure(args.build_dir, args.agp, args.gradle, args.compile_sdk, args.build_tools)
    except (PatchError, OSError) as error:
        print("::error::%s" % error)
        return 1
    print("Android template configured: AGP %s, Gradle %s, compileSdk %s, build tools %s"
          % (args.agp, args.gradle, args.compile_sdk, args.build_tools))
    return 0


if __name__ == "__main__":
    sys.exit(main())