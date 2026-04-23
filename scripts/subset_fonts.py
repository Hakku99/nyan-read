#!/usr/bin/env python3
"""
Subset CJK fonts for Nyan Read using pyftsubset.

Usage examples:
  python scripts/subset_fonts.py --dry-run
  python scripts/subset_fonts.py --charset gb2312
  python scripts/subset_fonts.py --charset-file custom_chars.txt
"""

from __future__ import annotations

import argparse
import pathlib
import subprocess
import sys
import tempfile
from dataclasses import dataclass


REPO_ROOT = pathlib.Path(__file__).resolve().parents[1]
FONTS_DIR = REPO_ROOT / "assets" / "fonts"
DEFAULT_OUTPUT_DIR = FONTS_DIR / "subset"


GB2312_PUNCT_EXTRA = (
    "“”‘’《》〈〉「」『』【】〔〕（）—…·"
    "，。！？；：、￥％＃＠＆＊"
    "abcdefghijklmnopqrstuvwxyz"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "0123456789"
)


@dataclass(frozen=True)
class FontTarget:
    source: pathlib.Path
    output_name: str


TARGETS = [
    FontTarget(FONTS_DIR / "NotoSansSC-Regular.ttf", "NotoSansSC-Regular.ttf"),
    FontTarget(FONTS_DIR / "NotoSansSC-Medium.ttf", "NotoSansSC-Medium.ttf"),
    FontTarget(FONTS_DIR / "NotoSansSC-SemiBold.ttf", "NotoSansSC-SemiBold.ttf"),
    FontTarget(
        FONTS_DIR / "SourceHanSerifSC-Regular.otf",
        "SourceHanSerifSC-Regular.otf",
    ),
    FontTarget(
        FONTS_DIR / "SourceHanSerifSC-SemiBold.otf",
        "SourceHanSerifSC-SemiBold.otf",
    ),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Subset project fonts via pyftsubset.")
    parser.add_argument(
        "--charset",
        choices=["gb2312"],
        default="gb2312",
        help="Built-in charset profile to subset with.",
    )
    parser.add_argument(
        "--charset-file",
        type=pathlib.Path,
        help="Optional UTF-8 text file with extra characters to keep.",
    )
    parser.add_argument(
        "--output-dir",
        type=pathlib.Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Directory to place subset fonts.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print commands without executing pyftsubset.",
    )
    return parser.parse_args()


def build_text_payload(args: argparse.Namespace) -> str:
    text = ""
    if args.charset == "gb2312":
        # Keep all GB2312 code points plus common punctuation and ASCII.
        text += "".join(chr(cp) for cp in range(0x4E00, 0x9FA6))
        text += GB2312_PUNCT_EXTRA

    if args.charset_file:
        text += args.charset_file.read_text(encoding="utf-8")

    # Deduplicate while preserving order.
    seen = set()
    deduped = []
    for ch in text:
        if ch not in seen:
            seen.add(ch)
            deduped.append(ch)
    return "".join(deduped)


def ensure_pyftsubset_available() -> None:
    try:
        subprocess.run(
            ["pyftsubset", "--help"],
            check=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        print(
            "pyftsubset not found. Install with: pip install fonttools brotli zopfli",
            file=sys.stderr,
        )
        raise SystemExit(1)


def _looks_like_font(path: pathlib.Path) -> bool:
    header = path.read_bytes()[:4]
    return header in (b"\x00\x01\x00\x00", b"OTTO", b"ttcf", b"wOFF", b"wOF2")


def validate_source_fonts() -> None:
    for target in TARGETS:
        if not target.source.exists():
            print(f"Missing source font: {target.source}", file=sys.stderr)
            raise SystemExit(1)
        if not _looks_like_font(target.source):
            print(
                (
                    f"Invalid font file: {target.source}\n"
                    "File header is not TTF/OTF. If downloaded from GitHub, "
                    "you likely saved an HTML page instead of the raw font file. "
                    "Please re-download the RAW/OFT/TTF file and retry."
                ),
                file=sys.stderr,
            )
            raise SystemExit(1)


def run_subset(
    target: FontTarget,
    output_dir: pathlib.Path,
    text_file: pathlib.Path,
    dry_run: bool,
) -> None:
    output_path = output_dir / target.output_name
    cmd = [
        "pyftsubset",
        str(target.source),
        f"--output-file={output_path}",
        f"--text-file={text_file}",
        "--layout-features=*",
        "--glyph-names",
        "--symbol-cmap",
        "--legacy-cmap",
        "--notdef-glyph",
        "--notdef-outline",
        "--recommended-glyphs",
        "--name-legacy",
        "--drop-tables+=GSUB,GPOS",  # keep CJK static shaping minimal
        "--hinting",
    ]
    print(" ".join(cmd))
    if not dry_run:
        subprocess.run(cmd, check=True)


def main() -> None:
    args = parse_args()
    ensure_pyftsubset_available()
    validate_source_fonts()

    output_dir = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)
    text_payload = build_text_payload(args)
    if not text_payload:
        print("Resolved charset text is empty.", file=sys.stderr)
        raise SystemExit(1)

    with tempfile.NamedTemporaryFile(
        mode="w",
        encoding="utf-8",
        suffix=".txt",
        delete=False,
    ) as tf:
        tf.write(text_payload)
        text_file = pathlib.Path(tf.name)

    try:
        for target in TARGETS:
            run_subset(target, output_dir, text_file, args.dry_run)
    finally:
        text_file.unlink(missing_ok=True)

    print(f"Done. Subset fonts are in: {output_dir}")


if __name__ == "__main__":
    main()
