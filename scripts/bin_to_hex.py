#!/usr/bin/env python3
"""Convert a raw little-endian RV32 binary to a Verilog $readmemh file.

Each output line contains one 32-bit word. Input bytes are interpreted in
little-endian order, matching a little-endian RV32 processor and a
SystemVerilog memory declared as:

    logic [31:0] mem [0:WORDS-1];

Example:
    python3 scripts/bin_to_hex.py \
        firmware/start.bin \
        firmware/start.hex \
        --depth 1024 \
        --fill 0x00000013
"""

from __future__ import annotations

import argparse
from pathlib import Path


WORD_BYTES = 4
WORD_MASK = 0xFFFF_FFFF
DEFAULT_FILL_WORD = 0x0000_0013  # RV32I NOP: addi x0, x0, 0


def parse_u32(value: str) -> int:
    """Parse a decimal or 0x-prefixed unsigned 32-bit integer."""
    try:
        parsed = int(value, 0)
    except ValueError as exc:
        raise argparse.ArgumentTypeError(
            f"invalid 32-bit value: {value!r}"
        ) from exc

    if not 0 <= parsed <= WORD_MASK:
        raise argparse.ArgumentTypeError(
            f"value must be between 0 and 0x{WORD_MASK:08X}"
        )

    return parsed


def binary_to_words(data: bytes) -> list[int]:
    """Convert bytes to padded little-endian 32-bit words."""
    if not data:
        return []

    padding = (-len(data)) % WORD_BYTES
    if padding:
        data += bytes(padding)

    return [
        int.from_bytes(
            data[offset : offset + WORD_BYTES],
            byteorder="little",
            signed=False,
        )
        for offset in range(0, len(data), WORD_BYTES)
    ]


def write_hex(
    output_path: Path,
    words: list[int],
    *,
    depth: int | None,
    fill_word: int,
) -> None:
    """Write one uppercase eight-digit hexadecimal word per line."""
    if depth is not None:
        if depth <= 0:
            raise ValueError("--depth must be greater than zero")

        if len(words) > depth:
            raise ValueError(
                f"firmware needs {len(words)} words, but depth is {depth}"
            )

        words = words + [fill_word] * (depth - len(words))

    output_path.parent.mkdir(parents=True, exist_ok=True)

    content = "".join(f"{word:08X}\n" for word in words)
    output_path.write_text(content, encoding="ascii")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Convert a raw little-endian RV32 binary into a "
            "32-bit Verilog $readmemh file."
        )
    )

    parser.add_argument(
        "input",
        type=Path,
        help="input raw binary file",
    )
    parser.add_argument(
        "output",
        type=Path,
        help="output hexadecimal memory file",
    )
    parser.add_argument(
        "--depth",
        type=int,
        default=None,
        help=(
            "optional total output depth in 32-bit words; "
            "remaining words are filled"
        ),
    )
    parser.add_argument(
        "--fill",
        type=parse_u32,
        default=DEFAULT_FILL_WORD,
        help=(
            "32-bit fill word used with --depth "
            "(default: 0x00000013, RV32I NOP)"
        ),
    )

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()

    try:
        data = args.input.read_bytes()
        words = binary_to_words(data)

        write_hex(
            args.output,
            words,
            depth=args.depth,
            fill_word=args.fill,
        )
    except (OSError, ValueError) as exc:
        parser.error(str(exc))

    print(
        f"Converted {len(data)} byte(s) into {len(words)} "
        f"firmware word(s): {args.output}"
    )

    if args.depth is not None:
        print(
            f"Output depth: {args.depth} word(s), "
            f"fill word: 0x{args.fill:08X}"
        )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
