#!/usr/bin/env python3
"""Compare obfuscation effectiveness between two IPA packages.

Usage:
  python compare_ipa_obfuscation.py --before old.ipa --after new.ipa
"""

from __future__ import annotations

import argparse
import math
import os
import re
import statistics
import struct
import sys
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

IDENT_RE = re.compile(r"\b[A-Za-z_][A-Za-z0-9_]{3,}\b")
PRINTABLE_BYTES = set(range(32, 127))
MACHO_MAGICS = {
    0xfeedface,
    0xcefaedfe,
    0xfeedfacf,
    0xcffaedfe,
    0xcafebabe,
    0xbebafeca,
}


@dataclass
class IpaMetrics:
    ipa_path: Path
    macho_files: int
    identifiers_total: int
    identifiers_unique: int
    readable_count: int
    randomish_count: int
    mean_len: float
    entropy_mean: float
    obfuscation_score: float


def is_macho_file(path: Path) -> bool:
    try:
        with path.open("rb") as f:
            header = f.read(4)
        if len(header) < 4:
            return False
        magic = struct.unpack(">I", header)[0]
        return magic in MACHO_MAGICS
    except OSError:
        return False


def extract_printable_strings(blob: bytes, min_len: int = 4) -> list[str]:
    out: list[str] = []
    buf = bytearray()
    for b in blob:
        if b in PRINTABLE_BYTES:
            buf.append(b)
        else:
            if len(buf) >= min_len:
                out.append(buf.decode("ascii", errors="ignore"))
            buf.clear()
    if len(buf) >= min_len:
        out.append(buf.decode("ascii", errors="ignore"))
    return out


def token_entropy(token: str) -> float:
    if not token:
        return 0.0
    counts = {}
    for ch in token:
        counts[ch] = counts.get(ch, 0) + 1
    n = len(token)
    return -sum((c / n) * math.log2(c / n) for c in counts.values())


def looks_readable(token: str) -> bool:
    if len(token) < 5:
        return False
    lower = token.lower()
    if lower.startswith(("_t", "ns", "ui", "cf")) and len(token) <= 6:
        return False
    if re.fullmatch(r"[0-9a-fA-F_]+", token):
        return False
    vowels = sum(1 for ch in lower if ch in "aeiou")
    return vowels >= 2 and (vowels / len(token)) >= 0.22


def looks_randomish(token: str) -> bool:
    if len(token) < 6:
        return False
    lower = token.lower()
    if re.fullmatch(r"[0-9a-f]+", lower):
        return True
    vowels = sum(1 for ch in lower if ch in "aeiou")
    ent = token_entropy(token)
    return ent >= 3.3 and (vowels / len(token)) <= 0.25


def iter_macho_files(unzip_dir: Path) -> Iterable[Path]:
    payload = unzip_dir / "Payload"
    if not payload.exists():
        return []
    for root, _dirs, files in os.walk(payload):
        for name in files:
            p = Path(root) / name
            if is_macho_file(p):
                yield p


def score_obfuscation(readable_ratio: float, entropy_mean: float) -> float:
    # readable_ratio low => better; entropy high => better
    entropy_norm = max(0.0, min(entropy_mean / 4.5, 1.0))
    score = ((1.0 - readable_ratio) * 70.0) + (entropy_norm * 30.0)
    return max(0.0, min(score, 100.0))


def analyze_ipa(ipa_path: Path) -> IpaMetrics:
    if not ipa_path.exists():
        raise FileNotFoundError(f"IPA file not found: {ipa_path}")

    with tempfile.TemporaryDirectory(prefix="ipa_cmp_") as tmp:
        tmp_path = Path(tmp)
        with zipfile.ZipFile(ipa_path) as zf:
            zf.extractall(tmp_path)

        tokens: list[str] = []
        macho_count = 0
        for macho in iter_macho_files(tmp_path):
            macho_count += 1
            try:
                data = macho.read_bytes()
            except OSError:
                continue
            for s in extract_printable_strings(data):
                tokens.extend(IDENT_RE.findall(s))

    if not tokens:
        return IpaMetrics(
            ipa_path=ipa_path,
            macho_files=macho_count,
            identifiers_total=0,
            identifiers_unique=0,
            readable_count=0,
            randomish_count=0,
            mean_len=0.0,
            entropy_mean=0.0,
            obfuscation_score=0.0,
        )

    unique = sorted(set(tokens))
    readable = [t for t in unique if looks_readable(t)]
    randomish = [t for t in unique if looks_randomish(t)]
    lengths = [len(t) for t in unique]
    entropies = [token_entropy(t) for t in unique]
    readable_ratio = len(readable) / len(unique)

    return IpaMetrics(
        ipa_path=ipa_path,
        macho_files=macho_count,
        identifiers_total=len(tokens),
        identifiers_unique=len(unique),
        readable_count=len(readable),
        randomish_count=len(randomish),
        mean_len=statistics.mean(lengths),
        entropy_mean=statistics.mean(entropies),
        obfuscation_score=score_obfuscation(readable_ratio, statistics.mean(entropies)),
    )


def print_report(before: IpaMetrics, after: IpaMetrics) -> None:
    print("\n=== IPA 混淆对比报告 ===")
    print(f"Before: {before.ipa_path}")
    print(f"After : {after.ipa_path}\n")

    print(f"{'指标':<24}{'Before':>14}{'After':>14}{'变化':>14}")
    print("-" * 66)

    def row(name: str, b: float, a: float, digits: int = 2):
        delta = a - b
        fmt = f"{{:<24}}{{:>14.{digits}f}}{{:>14.{digits}f}}{{:>+14.{digits}f}}"
        print(fmt.format(name, b, a, delta))

    row("Mach-O 文件数", float(before.macho_files), float(after.macho_files), 0)
    row("标识符总数", float(before.identifiers_total), float(after.identifiers_total), 0)
    row("标识符去重数", float(before.identifiers_unique), float(after.identifiers_unique), 0)
    row("可读标识符数", float(before.readable_count), float(after.readable_count), 0)
    row("随机化标识符数", float(before.randomish_count), float(after.randomish_count), 0)
    row("平均标识符长度", before.mean_len, after.mean_len)
    row("平均字符熵", before.entropy_mean, after.entropy_mean)
    row("混淆评分(0-100)", before.obfuscation_score, after.obfuscation_score)

    print("\n=== 结论 ===")
    improved = after.obfuscation_score > before.obfuscation_score
    readable_drop = after.readable_count < before.readable_count
    entropy_up = after.entropy_mean > before.entropy_mean

    if improved and (readable_drop or entropy_up):
        print("✅ 混淆效果有提升：可读性下降/随机性增强。")
    elif after.obfuscation_score == before.obfuscation_score:
        print("⚠️ 混淆效果基本无变化。")
    else:
        print("❌ 混淆效果可能未达预期（评分未提升）。")

    print("\n提示：该工具基于符号可读性与字符熵的启发式分析，建议结合逆向抽样做最终验证。")


def parse_args(argv: list[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description="对比两个 IPA 的混淆程度")
    p.add_argument("--before", required=True, help="混淆前 IPA 路径")
    p.add_argument("--after", required=True, help="混淆后 IPA 路径")
    return p.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    before = analyze_ipa(Path(args.before))
    after = analyze_ipa(Path(args.after))
    print_report(before, after)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
