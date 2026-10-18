#!/usr/bin/env python3
"""Check the language packs in i18n/ and how the code uses them.

  * every pack is valid TOML and has valid metadata
  * placeholders match the English text, and plural forms match the pack's rule
  * the required languages have every English key
  * every translation key used in the scripts exists in English
  * a report of how many UI texts are still written directly in the scripts
"""

import argparse
import re
import sys
import tomllib
from pathlib import Path

RULE_CATEGORIES = {
    "none": ["other"],
    "one_other": ["one", "other"],
    "one_other_zero_one": ["one", "other"],
    "east_slavic": ["one", "few", "many", "other"],
    "polish": ["one", "few", "many", "other"],
    "czech": ["one", "few", "many", "other"],
    "arabic": ["zero", "one", "two", "few", "many", "other"],
}
PLURAL_SUFFIXES = {"zero", "one", "two", "few", "many", "other"}
CODE_RE = re.compile(r"^[a-z]{2,3}(-[A-Za-z0-9]{2,8}){0,3}$")
KEY_RE = re.compile(r"^[a-z0-9_]+(\.[a-z0-9_]+)*$")
PLACEHOLDER_RE = re.compile(r"\{([a-z_][a-z0-9_]*)\}")
HARDCODED_RES = [
    re.compile(r'\b(?:text|title_text|placeholder_text|tooltip_text)\s*=\s*"([^"]*[A-Za-z][^"]*)"'),
    re.compile(r'\bnotify\(\s*"([^"]*[A-Za-z][^"]*)"'),
    re.compile(r'\bempty_note\(\s*"([^"]*[A-Za-z][^"]*)"'),
    re.compile(r'\bbuild_row\(\s*"([^"]*[A-Za-z][^"]*)"'),
]


def placeholders(text):
    return sorted(set(PLACEHOLDER_RE.findall(text)))


def split_plural(key):
    head, _, tail = key.rpartition(".")
    if head and tail in PLURAL_SUFFIXES:
        return head, tail
    return key, None


def load(path):
    with open(path, "rb") as handle:
        return tomllib.load(handle)


def check_pack(data, en_strings, label):
    errors = []
    meta = data.get("meta", {})
    strings = data.get("strings", {})
    if meta.get("format") != 1:
        errors.append(f"{label}: format must be 1")
    code = meta.get("code", "")
    if not CODE_RE.match(str(code)):
        errors.append(f"{label}: invalid code {code!r}")
    if meta.get("plural_rule") not in RULE_CATEGORIES:
        errors.append(f"{label}: unknown plural_rule {meta.get('plural_rule')!r}")
    if meta.get("direction") not in ("ltr", "rtl"):
        errors.append(f"{label}: direction must be ltr or rtl")
    if not isinstance(meta.get("version"), int) or meta.get("version") < 1:
        errors.append(f"{label}: version must be an integer of 1 or more")
    groups = {}
    for key, value in strings.items():
        if not KEY_RE.match(key):
            errors.append(f"{label}: invalid key {key!r}")
        if not isinstance(value, str) or not value.strip():
            errors.append(f"{label}: empty or non-text value for {key!r}")
            continue
        base, suffix = split_plural(key)
        if suffix:
            groups.setdefault(base, set()).add(suffix)
        if label != "en" and key in en_strings and placeholders(value) != placeholders(en_strings[key]):
            errors.append(f"{label}: placeholders of {key!r} differ from English")
        elif label != "en" and suffix and f"{base}.other" in en_strings:
            if not set(placeholders(value)) <= set(placeholders(en_strings[f"{base}.other"])):
                errors.append(f"{label}: {key!r} uses a placeholder English does not have")
    rule = meta.get("plural_rule")
    for base, forms in groups.items():
        for needed in RULE_CATEGORIES.get(rule, ["other"]):
            if needed not in forms:
                errors.append(f"{label}: plural {base!r} is missing the {needed!r} form")
    return errors


def base_keys(strings):
    keys = set()
    for key in strings:
        base, suffix = split_plural(key)
        keys.add(base if suffix else key)
    return keys


def used_keys(root, prefixes):
    pattern = re.compile(r'"((?:%s)\.[a-z0-9_.]+)"' % "|".join(re.escape(p) for p in prefixes))
    found = {}
    for script in sorted(Path(root, "scripts").rglob("*.gd")):
        text = script.read_text(encoding="utf-8")
        for match in pattern.finditer(text):
            found.setdefault(match.group(1), script.as_posix())
    return found


def count_hardcoded(root):
    total = 0
    per_file = {}
    for script in sorted(Path(root, "scripts").rglob("*.gd")):
        if "tests" in script.parts or "server" in script.parts or "i18n" in script.parts:
            continue
        text = script.read_text(encoding="utf-8")
        count = sum(len(r.findall(text)) for r in HARDCODED_RES)
        if count:
            per_file[script.as_posix()] = count
            total += count
    return total, per_file


def run(root, required, max_unconverted=None):
    root = Path(root)
    errors = []
    index = load(root / "i18n" / "index.toml")
    codes = index.get("languages", [])
    packs = {}
    for code in codes:
        path = root / "i18n" / f"{code}.toml"
        if not path.exists():
            errors.append(f"index lists {code} but {path.as_posix()} is missing")
            continue
        try:
            packs[code] = load(path)
        except tomllib.TOMLDecodeError as problem:
            errors.append(f"{code}: not valid TOML: {problem}")
    if "en" not in packs:
        errors.append("the English pack is required")
        return errors, {}
    en_strings = packs["en"].get("strings", {})
    en_bases = base_keys(en_strings)
    report = {"coverage": {}, "unconverted": 0}
    for code, data in packs.items():
        if data.get("meta", {}).get("code") != code:
            errors.append(f"{code}: the code inside the pack is {data.get('meta', {}).get('code')!r}")
        errors.extend(check_pack(data, en_strings, code))
        have = base_keys(data.get("strings", {}))
        report["coverage"][code] = round(100.0 * len(have & en_bases) / max(len(en_bases), 1), 1)
        if code in required:
            for missing in sorted(en_bases - have):
                errors.append(f"{code}: required language is missing {missing!r}")
    for code in required:
        if code not in packs:
            errors.append(f"required language {code} is not shipped")
    prefixes = sorted({key.split(".")[0] for key in en_strings})
    for key, where in used_keys(root, prefixes).items():
        if key not in en_strings and key not in en_bases and f"{key}.other" not in en_strings:
            errors.append(f"{where} uses the key {key!r} that English does not define")
    total, per_file = count_hardcoded(root)
    report["unconverted"] = total
    report["unconverted_files"] = per_file
    if max_unconverted is not None and total > max_unconverted:
        errors.append(f"{total} texts are still written in the scripts (limit {max_unconverted})")
    return errors, report


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", default=".")
    parser.add_argument("--required", default="en,id,de,ms,ja")
    parser.add_argument("--max-unconverted", type=int, default=None)
    args = parser.parse_args(argv)
    errors, report = run(args.root, [c for c in args.required.split(",") if c], args.max_unconverted)
    for problem in errors:
        print(f"::error::{problem}")
    for code, percent in report.get("coverage", {}).items():
        print(f"{code}: {percent}% of the English keys translated")
    print(f"Texts still written directly in the scripts: {report.get('unconverted', 0)}")
    if errors:
        return 1
    print("Language packs are consistent.")
    return 0


if __name__ == "__main__":
    sys.exit(main())