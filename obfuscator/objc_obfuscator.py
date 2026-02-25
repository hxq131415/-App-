#!/usr/bin/env python3
"""Objective-C source obfuscator for macOS app projects.

Design goals:
- Keep App Store review-safe defaults (avoid system selectors / plist / nib keys).
- Deterministic output for reproducible CI builds.
- Operate on .h/.m/.mm files only.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import random
import re
from dataclasses import dataclass
from typing import Dict, Iterable, List, Pattern, Set

CLASS_RE = re.compile(r"@interface\s+([A-Za-z_][A-Za-z0-9_]*)|@implementation\s+([A-Za-z_][A-Za-z0-9_]*)")
PROTOCOL_RE = re.compile(r"@protocol\s+([A-Za-z_][A-Za-z0-9_]*)")
FUNCTION_RE = re.compile(
    r"(?m)^\s*(?:static\s+)?(?:inline\s+)?(?:[A-Za-z_][A-Za-z0-9_<>]*\s+)+\*?\s*([A-Za-z_][A-Za-z0-9_]*)\s*\(")

# Safe list from common Cocoa lifecycle / delegate / serialization APIs.
RESERVED_SELECTORS = {
    "init",
    "dealloc",
    "load",
    "initialize",
    "viewDidLoad",
    "applicationDidFinishLaunching",
    "applicationWillTerminate",
    "encodeWithCoder",
    "initWithCoder",
    "copyWithZone",
    "isEqual",
    "hash",
    "description",
}

IDENT_RE = re.compile(r"\b([A-Za-z_][A-Za-z0-9_]*)\b")


@dataclass
class Config:
    source_root: pathlib.Path
    include_prefixes: List[str]
    exclude_symbols: Set[str]
    seed: str
    output_map: pathlib.Path


class NameGenerator:
    def __init__(self, seed: str):
        digest = hashlib.sha256(seed.encode("utf-8")).hexdigest()
        self.random = random.Random(int(digest[:16], 16))
        self.used: Set[str] = set()

    def make(self, prefix: str = "OBF") -> str:
        while True:
            body = "".join(self.random.choice("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ") for _ in range(10))
            candidate = f"{prefix}_{body}"
            if candidate not in self.used:
                self.used.add(candidate)
                return candidate


class ObjCObfuscator:
    def __init__(self, config: Config):
        self.config = config
        self.generator = NameGenerator(config.seed)
        self.mapping: Dict[str, str] = {}

    def discover_files(self) -> List[pathlib.Path]:
        exts = {".h", ".m", ".mm"}
        files: List[pathlib.Path] = []
        for path in self.config.source_root.rglob("*"):
            if path.suffix in exts and path.is_file():
                files.append(path)
        return files

    def _should_obfuscate_symbol(self, symbol: str) -> bool:
        if symbol in self.config.exclude_symbols or symbol in RESERVED_SELECTORS:
            return False
        if not self.config.include_prefixes:
            return True
        return any(symbol.startswith(prefix) for prefix in self.config.include_prefixes)

    def collect_symbols(self, contents: Iterable[str]) -> Set[str]:
        symbols: Set[str] = set()
        patterns: List[Pattern[str]] = [CLASS_RE, PROTOCOL_RE, FUNCTION_RE]
        for text in contents:
            for pattern in patterns:
                for match in pattern.finditer(text):
                    for g in match.groups():
                        if g and self._should_obfuscate_symbol(g):
                            symbols.add(g)
        return symbols

    def build_mapping(self, symbols: Iterable[str]) -> None:
        for sym in sorted(set(symbols)):
            self.mapping[sym] = self.generator.make()

    def apply_mapping(self, text: str) -> str:
        if not self.mapping:
            return text

        def replace(match: re.Match[str]) -> str:
            token = match.group(1)
            return self.mapping.get(token, token)

        out_lines: List[str] = []
        for line in text.splitlines(keepends=True):
            stripped = line.lstrip()
            if stripped.startswith("#import") or stripped.startswith("#include"):
                out_lines.append(line)
                continue
            out_lines.append(IDENT_RE.sub(replace, line))
        return "".join(out_lines)

    def run(self, dry_run: bool = False) -> Dict[str, str]:
        files = self.discover_files()
        contents = [p.read_text(encoding="utf-8") for p in files]
        symbols = self.collect_symbols(contents)
        self.build_mapping(symbols)

        if not dry_run:
            for path, text in zip(files, contents):
                new_text = self.apply_mapping(text)
                if new_text != text:
                    path.write_text(new_text, encoding="utf-8")
            self.config.output_map.write_text(
                json.dumps(self.mapping, ensure_ascii=False, indent=2, sort_keys=True),
                encoding="utf-8",
            )
        return self.mapping


def load_config(path: pathlib.Path) -> Config:
    data = json.loads(path.read_text(encoding="utf-8"))
    return Config(
        source_root=pathlib.Path(data["source_root"]).resolve(),
        include_prefixes=list(data.get("include_prefixes", [])),
        exclude_symbols=set(data.get("exclude_symbols", [])),
        seed=data.get("seed", "app-obfuscator-default-seed"),
        output_map=pathlib.Path(data.get("output_map", "obfuscation_map.json")).resolve(),
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Objective-C obfuscation tool")
    parser.add_argument("--config", required=True, help="Path to JSON config")
    parser.add_argument("--dry-run", action="store_true", help="Only print mapping without writing files")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    config = load_config(pathlib.Path(args.config))
    mapping = ObjCObfuscator(config).run(dry_run=args.dry_run)
    print(json.dumps(mapping, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
