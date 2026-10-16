#!/usr/bin/env python3
"""Derive Android version fields from a Git tag and apply them to export_presets.cfg.

Tag format: vMAJOR.MINOR.PATCH (for example v1.2.0).
  version name = "MAJOR.MINOR.PATCH"
  version code = MAJOR * 1_000_000 + MINOR * 1_000 + PATCH

The version code is deterministic and follows semantic version order, so a higher
version always gets a higher code. MINOR and PATCH must be 0..999 and MAJOR 1..2000,
which keeps the code below the Android limit of 2_100_000_000.
"""

import argparse
import re
import sys

TAG_RE = re.compile(r"^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$")
MAX_MAJOR = 2000
MAX_PART = 999


class VersionError(ValueError):
    """Raised when a tag or preset cannot be used."""


def parse_tag(tag):
    match = TAG_RE.match(tag)
    if not match:
        raise VersionError(
            "Tag '%s' is not valid. Use vMAJOR.MINOR.PATCH, for example v1.2.0." % tag
        )
    major, minor, patch = (int(part) for part in match.groups())
    if major > MAX_MAJOR or minor > MAX_PART or patch > MAX_PART:
        raise VersionError(
            "Tag '%s' is out of range. MAJOR must be <= %d, MINOR and PATCH <= %d."
            % (tag, MAX_MAJOR, MAX_PART)
        )
    code = major * 1_000_000 + minor * 1_000 + patch
    if code < 1:
        raise VersionError("Tag '%s' gives version code 0. Android needs a code of at least 1." % tag)
    return "%d.%d.%d" % (major, minor, patch), code


def apply_to_preset(text, version_name, version_code):
    """Replace only version/name and version/code. Every other line stays byte for byte."""
    text, name_count = re.subn(
        r'^version/name=[^\r\n]*', lambda _m: 'version/name="%s"' % version_name, text, flags=re.MULTILINE
    )
    text, code_count = re.subn(
        r'^version/code=[^\r\n]*', lambda _m: "version/code=%d" % version_code, text, flags=re.MULTILINE
    )
    if name_count != 1:
        raise VersionError("Expected exactly one version/name line in the preset, found %d." % name_count)
    if code_count != 1:
        raise VersionError("Expected exactly one version/code line in the preset, found %d." % code_count)
    return text


def check_order(tag, existing_tags):
    """The new tag must have a higher version code than every other release tag."""
    _, new_code = parse_tag(tag)
    for other in existing_tags:
        other = other.strip()
        if not other or other == tag or not TAG_RE.match(other):
            continue
        _, other_code = parse_tag(other)
        if other_code >= new_code:
            raise VersionError(
                "Tag %s (version code %d) is not newer than existing tag %s (version code %d)."
                % (tag, new_code, other, other_code)
            )


def _write_outputs(path, version_name, version_code):
    with open(path, "a", encoding="utf-8") as handle:
        handle.write("version_name=%s\n" % version_name)
        handle.write("version_code=%d\n" % version_code)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    resolve = sub.add_parser("resolve", help="print the version name and code for a tag")
    resolve.add_argument("tag")
    resolve.add_argument("--github-output", help="append version_name and version_code to this file")

    apply = sub.add_parser("apply", help="write the version fields into export_presets.cfg")
    apply.add_argument("tag")
    apply.add_argument("--preset", default="export_presets.cfg")

    order = sub.add_parser("check-order", help="fail if the tag is not newer than the existing tags")
    order.add_argument("tag")
    order.add_argument("existing", nargs="*", help="existing tags (read from stdin when empty)")

    args = parser.parse_args(argv)
    try:
        if args.command == "resolve":
            name, code = parse_tag(args.tag)
            print("version_name=%s" % name)
            print("version_code=%d" % code)
            if args.github_output:
                _write_outputs(args.github_output, name, code)
        elif args.command == "apply":
            name, code = parse_tag(args.tag)
            with open(args.preset, "r", encoding="utf-8", newline="") as handle:
                text = handle.read()
            updated = apply_to_preset(text, name, code)
            with open(args.preset, "w", encoding="utf-8", newline="") as handle:
                handle.write(updated)
            print("%s: version/name=%s version/code=%d" % (args.preset, name, code))
        else:
            existing = args.existing or sys.stdin.read().split()
            check_order(args.tag, existing)
            print("Tag %s is newer than all existing release tags." % args.tag)
    except (VersionError, OSError) as error:
        print("::error::%s" % error)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())