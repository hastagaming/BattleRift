#!/usr/bin/env python3
"""Configures the Godot 4.3 Android build template for compileSdk 36 and Android 16 behaviour.

Godot 4.3 ships its Android template with compileSdk 34, AGP 8.2.0 and Gradle 8.2. The template is
unpacked fresh by CI for every build, so this script patches the unpacked copy. Every change is
asserted: if the template layout is not what is expected, the script fails instead of guessing.

  configure_template.py <android/build directory>            patch the template
  configure_template.py <android/build directory> --verify   only check that it is patched

The AGP / Gradle / compileSdk / build-tools combination below is the one the official Godot 4.7
template ships for API 36. Min SDK and target SDK are not set here: they come from the export preset
(gradle_build/min_sdk and gradle_build/target_sdk) and are passed to Gradle by the Godot exporter.
"""

import argparse
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ANDROID_NS = "http://schemas.android.com/apk/res/android"
PROPERTY_NAME = "android.window.PROPERTY_COMPAT_ALLOW_RESTRICTED_RESIZABILITY"
BACK_ATTRIBUTE = "android:enableOnBackInvokedCallback"


class TemplateError(Exception):
    pass


def read(path: Path) -> str:
    if not path.is_file():
        raise TemplateError("missing template file: %s" % path)
    return path.read_text(encoding="utf-8")


def replace_once(text: str, pattern: str, replacement: str, label: str) -> str:
    result, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)
    if count != 1:
        raise TemplateError("could not find %s in the template" % label)
    return result


def patch_config(root: Path, args: argparse.Namespace) -> None:
    path = root / "config.gradle"
    text = read(path)
    text = replace_once(text, r"(androidGradlePlugin\s*:\s*')[^']+(')", r"\g<1>%s\g<2>" % args.agp, "androidGradlePlugin")
    text = replace_once(text, r"(compileSdk\s*:\s*)\d+", r"\g<1>%s" % args.compile_sdk, "compileSdk")
    text = replace_once(text, r"(buildTools\s*:\s*')[^']+(')", r"\g<1>%s\g<2>" % args.build_tools, "buildTools")
    path.write_text(text, encoding="utf-8")


def patch_wrapper(root: Path, args: argparse.Namespace) -> None:
    path = root / "gradle" / "wrapper" / "gradle-wrapper.properties"
    text = read(path)
    text = replace_once(
        text,
        r"(distributionUrl=.*/distributions/gradle-)[0-9.]+(-bin\.zip)",
        r"\g<1>%s\g<2>" % args.gradle,
        "distributionUrl",
    )
    path.write_text(text, encoding="utf-8")


def patch_properties(root: Path, args: argparse.Namespace) -> None:
    path = root / "gradle.properties"
    text = read(path)
    line = "android.suppressUnsupportedCompileSdk=%s" % args.compile_sdk
    lines = [entry for entry in text.splitlines() if not entry.startswith("android.suppressUnsupportedCompileSdk=")]
    lines.append(line)
    path.write_text("\n".join(lines).rstrip("\n") + "\n", encoding="utf-8")


def patch_manifest(root: Path, _args: argparse.Namespace) -> None:
    path = root / "AndroidManifest.xml"
    text = read(path)
    match = re.search(r"<application\b[^>]*>", text, flags=re.DOTALL)
    if match is None:
        raise TemplateError("could not find the <application> element in AndroidManifest.xml")
    tag = match.group(0)
    new_tag = tag
    if BACK_ATTRIBUTE not in new_tag:
        new_tag = new_tag.replace("<application", '<application\n        %s="false"' % BACK_ATTRIBUTE, 1)
    text = text[: match.start()] + new_tag + text[match.end():]
    if PROPERTY_NAME not in text:
        end = text.index(new_tag) + len(new_tag)
        text = (
            text[:end]
            + '\n\n        <!-- Android 16 ignores orientation and resizability limits on large screens for apps that\n'
            + '             target API 36. BattleRift is a landscape game, so it keeps the previous behaviour. -->\n'
            + '        <property\n            android:name="%s"\n            android:value="true" />\n' % PROPERTY_NAME
            + text[end:]
        )
    path.write_text(text, encoding="utf-8")


def verify(root: Path, args: argparse.Namespace) -> list:
    problems = []
    config = read(root / "config.gradle")
    expectations = {
        "androidGradlePlugin": (r"androidGradlePlugin\s*:\s*'([^']+)'", args.agp),
        "compileSdk": (r"compileSdk\s*:\s*(\d+)", str(args.compile_sdk)),
        "buildTools": (r"buildTools\s*:\s*'([^']+)'", args.build_tools),
    }
    for label, (pattern, expected) in expectations.items():
        found = re.search(pattern, config)
        if found is None or found.group(1) != expected:
            problems.append("config.gradle %s is %s, expected %s" % (label, found.group(1) if found else "missing", expected))
    wrapper = read(root / "gradle" / "wrapper" / "gradle-wrapper.properties")
    found = re.search(r"gradle-([0-9.]+)-bin\.zip", wrapper)
    if found is None or found.group(1) != args.gradle:
        problems.append("gradle wrapper is %s, expected %s" % (found.group(1) if found else "missing", args.gradle))
    if "android.suppressUnsupportedCompileSdk=%s" % args.compile_sdk not in read(root / "gradle.properties"):
        problems.append("gradle.properties does not suppress the unsupported compileSdk warning")
    manifest_text = read(root / "AndroidManifest.xml")
    try:
        manifest = ET.fromstring(manifest_text)
    except ET.ParseError as error:
        return problems + ["AndroidManifest.xml is not valid XML: %s" % error]
    application = manifest.find("application")
    if application is None:
        return problems + ["AndroidManifest.xml has no <application>"]
    if application.get("{%s}enableOnBackInvokedCallback" % ANDROID_NS) != "false":
        problems.append("<application> does not set android:enableOnBackInvokedCallback=\"false\"")
    properties = [p for p in application.findall("property") if p.get("{%s}name" % ANDROID_NS) == PROPERTY_NAME]
    if len(properties) != 1 or properties[0].get("{%s}value" % ANDROID_NS) != "true":
        problems.append("<application> does not declare %s exactly once with value true" % PROPERTY_NAME)
    return problems


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("template_dir", type=Path)
    parser.add_argument("--verify", action="store_true", help="only check the template, do not change it")
    parser.add_argument("--agp", default="8.6.1")
    parser.add_argument("--gradle", default="8.11.1")
    parser.add_argument("--compile-sdk", default="36")
    parser.add_argument("--build-tools", default="36.1.0")
    args = parser.parse_args()
    try:
        if not args.verify:
            patch_config(args.template_dir, args)
            patch_wrapper(args.template_dir, args)
            patch_properties(args.template_dir, args)
            patch_manifest(args.template_dir, args)
        problems = verify(args.template_dir, args)
    except TemplateError as error:
        print("ERROR: %s" % error, file=sys.stderr)
        return 1
    if problems:
        for problem in problems:
            print("ERROR: %s" % problem, file=sys.stderr)
        return 1
    print("Android template OK: AGP %s, Gradle %s, compileSdk %s, build-tools %s" % (args.agp, args.gradle, args.compile_sdk, args.build_tools))
    return 0


if __name__ == "__main__":
    sys.exit(main())