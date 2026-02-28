#!/usr/bin/env python3
import argparse
import pathlib
import random
import re
import string

EXCLUDED_DIRS = {"Pods", ".git", "build", "DerivedData", "Carthage", "fastlane"}
FILE_EXTS = {".h", ".m", ".mm", ".c", ".cc", ".cpp"}
KEYWORDS = {
    "if", "for", "while", "switch", "case", "break", "continue", "return", "void", "int", "long",
    "float", "double", "char", "bool", "BOOL", "id", "self", "super", "nil", "NULL", "YES", "NO",
    "strong", "weak", "copy", "assign", "nonatomic", "atomic", "readonly", "readwrite", "class",
    "static", "extern", "const", "typedef", "struct", "enum", "protocol", "property", "synthesize", "dynamic",
}


def random_name(rng: random.Random, length: int = 18) -> str:
    return "_" + "".join(rng.choice(string.ascii_letters) for _ in range(length))


def collect_identifiers(text: str):
    names = set()
    patterns = [
        r"@interface\s+([A-Za-z_][A-Za-z0-9_]*)",
        r"@implementation\s+([A-Za-z_][A-Za-z0-9_]*)",
        r"@protocol\s+([A-Za-z_][A-Za-z0-9_]*)",
        r"typedef\s+NS_ENUM\s*\([^)]*\)\s*\{([^}]*)\}",
        r"\b(?:static\s+)?(?:inline\s+)?(?:[A-Za-z_][A-Za-z0-9_<>\*\s]+)\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(",
        r"@property\s*\([^)]*\)\s*[A-Za-z_][A-Za-z0-9_<>\*\s]+\s*\*?\s*([A-Za-z_][A-Za-z0-9_]*)\s*;",
    ]

    for p in patterns[:3]:
        names.update(re.findall(p, text))

    for enum_block in re.findall(patterns[3], text, re.S):
        for token in re.findall(r"\b([A-Za-z_][A-Za-z0-9_]*)\b", enum_block):
            names.add(token)

    for p in patterns[4:]:
        names.update(re.findall(p, text))

    # selector pieces (aggressive)
    for sel in re.findall(r"\b([a-z][A-Za-z0-9_]*)\s*:", text):
        names.add(sel)

    return names


def main():
    ap = argparse.ArgumentParser(description="Generate aggressive ObjC confusion header.")
    ap.add_argument("--root", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--seed", required=True)
    ap.add_argument("--min-len", type=int, default=5)
    ap.add_argument("--include-prefixes", default="")
    ap.add_argument("--exclude-prefixes", default="NS,UI,CA,CF")
    args = ap.parse_args()

    root = pathlib.Path(args.root)
    output = pathlib.Path(args.output)
    include_prefixes = [p.strip() for p in args.include_prefixes.split(",") if p.strip()]
    exclude_prefixes = [p.strip() for p in args.exclude_prefixes.split(",") if p.strip()]

    all_names = set()
    for path in root.rglob("*"):
        if not path.is_file() or path.suffix not in FILE_EXTS:
            continue
        if any(part in EXCLUDED_DIRS for part in path.parts):
            continue
        txt = path.read_text(encoding="utf-8", errors="ignore")
        all_names |= collect_identifiers(txt)

    filtered = set()
    for name in all_names:
        if len(name) < args.min_len:
            continue
        if name in KEYWORDS:
            continue
        if exclude_prefixes and any(name.startswith(p) for p in exclude_prefixes):
            continue
        if include_prefixes and not any(name.startswith(p) for p in include_prefixes):
            continue
        filtered.add(name)

    rng = random.Random(args.seed)
    mapping = {name: random_name(rng) for name in sorted(filtered)}

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as f:
        f.write("// Auto-generated. Do not edit manually.\n")
        f.write("#ifndef CONFUSION_HEADER_H\n#define CONFUSION_HEADER_H\n\n")
        for old, new in mapping.items():
            f.write(f"#define {old} {new}\n")
        f.write("\n#endif /* CONFUSION_HEADER_H */\n")

    print(f"Generated {len(mapping)} rename rules -> {output}")


if __name__ == "__main__":
    main()
