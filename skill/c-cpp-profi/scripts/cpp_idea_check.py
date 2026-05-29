#!/usr/bin/env python3
"""Validate c-cpp-profi Idea Cards.

The Innovation Engine reference defines an Idea Card: a fixed set of fields that
must be filled with falsifiable content before a proposal earns an edit. This
checker turns that card into a deterministic contract the same way
cpp_evidence_check.py turns the gate report into one. Blank or placeholder
fields fail with a field-level reason; problem-evidence that reads as a feeling
rather than a measurable anchor fails; a radical idea missing the four-gate
floor fails.

A card is a `## Idea Card` section, or an `Idea:`-led fenced block, with
`- Key: value` lines. Multiple cards in one file are each validated.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


REQUIRED_FIELDS = [
    "Kind",
    "Lens(es)",
    "Problem-evidence",
    "Prior-art-check",
    "Proposed change",
    "Reversibility",
    "Blast-radius",
    "Behavior oracle",
    "Score",
    "Kill-criteria",
]

KINDS = {"accretive", "radical"}

# Reuse the evidence-checker placeholder set, extended with idea-specific junk.
PLACEHOLDERS = {
    "",
    "yes/no",
    "todo",
    "tbd",
    "n/a?",
    "?",
    "feels slow",
    "feels fast",
    "should be faster",
    "maybe",
    "sort of",
    "idk",
}

# A normalized problem-evidence value equal to one of these is a bare feeling.
FEELING_PHRASES = {
    "feels slow",
    "feels fast",
    "should be faster",
    "maybe",
    "sort of",
}

# Anchor tokens that make problem-evidence measurable rather than a feeling.
ANCHOR_TOKENS = ("crash", "cve", "coverage")
ANCHOR_RE = re.compile(r"\d|%|/")


def normalize(value: str) -> str:
    return " ".join(value.strip().lower().split())


def read_doc(path: str) -> str:
    if path == "-":
        return sys.stdin.read()
    return Path(path).read_text(encoding="utf-8")


def is_placeholder(value: str) -> bool:
    return normalize(value) in PLACEHOLDERS


def has_measurable_anchor(value: str) -> bool:
    text = normalize(value)
    if ANCHOR_RE.search(text):
        return True
    return any(token in text for token in ANCHOR_TOKENS)


def parse_card_fields(lines: list[str]) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in lines:
        stripped = line.strip()
        if not stripped.startswith("- ") or ":" not in stripped:
            continue
        key, value = stripped[2:].split(":", 1)
        values[key.strip()] = value.strip()
    return values


def extract_cards(text: str) -> list[list[str]]:
    """Return each Idea Card as its list of raw `- Key: value` lines.

    Accepts `## Idea Card` Markdown sections and `Idea:`-led fenced blocks. A
    fenced `Idea:` block nested under a `## Idea Card` heading is counted once.
    """
    lines = text.splitlines()
    in_fence = [False] * len(lines)

    # First pass: mark fenced regions and harvest `Idea:`-led fenced cards.
    fenced_cards: list[list[str]] = []
    open_fence = False
    fence: list[str] = []
    fence_lines: list[int] = []
    for idx, line in enumerate(lines):
        if line.strip().startswith("```"):
            if open_fence:
                for fi in fence_lines:
                    in_fence[fi] = True
                first = next((l.strip() for l in fence if l.strip()), "")
                if first.lower().startswith("idea:") and any(
                    l.strip().startswith("- ") for l in fence
                ):
                    fenced_cards.append(list(fence))
                open_fence = False
                fence = []
                fence_lines = []
            else:
                open_fence = True
                fence = []
                fence_lines = []
            continue
        if open_fence:
            fence.append(line)
            fence_lines.append(idx)

    # Second pass: `## Idea Card` sections, counting only non-fenced field lines
    # so a section that merely wraps a fenced card is not double-counted.
    section_cards: list[list[str]] = []
    idx = 0
    while idx < len(lines):
        if normalize(lines[idx]) in ("## idea card", "## idea cards"):
            block: list[str] = []
            for offset, line in enumerate(lines[idx + 1 :], start=idx + 1):
                if line.startswith("## "):
                    break
                if not in_fence[offset]:
                    block.append(line)
            if any(l.strip().startswith("- ") for l in block):
                section_cards.append(block)
        idx += 1

    return fenced_cards + section_cards


def check_card(index: int, fields: dict[str, str]) -> list[str]:
    label = f"card {index}"
    errors: list[str] = []

    for key in REQUIRED_FIELDS:
        if key not in fields:
            errors.append(f"{label}: missing field: {key}")
        elif is_placeholder(fields[key]):
            errors.append(f"{label}: unfilled field: {key}")

    kind = normalize(fields.get("Kind", ""))
    if "Kind" in fields and not is_placeholder(fields["Kind"]) and kind not in KINDS:
        errors.append(f"{label}: Kind must be exactly accretive or radical")

    problem = fields.get("Problem-evidence", "")
    if "Problem-evidence" in fields and not is_placeholder(problem):
        if normalize(problem) in FEELING_PHRASES or not has_measurable_anchor(problem):
            errors.append(
                f"{label}: problem-evidence must cite a measurable anchor, not a feeling"
            )

    if kind == "radical":
        for floor in ("Behavior oracle", "Reversibility"):
            value = fields.get(floor, "")
            if floor not in fields or is_placeholder(value):
                errors.append(
                    f"{label}: radical idea requires filled {floor} (four-gate floor)"
                )

    return errors


def check_doc(text: str) -> tuple[int, list[str]]:
    blocks = extract_cards(text)
    if not blocks:
        return 0, ["no Idea Card found (expected a '## Idea Card' section or an 'Idea:' fenced block)"]
    errors: list[str] = []
    for index, block in enumerate(blocks, start=1):
        errors.extend(check_card(index, parse_card_fields(block)))
    return len(blocks), errors


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("card", help="markdown file with one or more Idea Cards, or '-' for stdin")
    parser.add_argument("--json", action="store_true", help="emit JSON result")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    text = read_doc(args.card)
    cards, errors = check_doc(text)

    if args.json:
        print(
            json.dumps(
                {"ok": not errors, "cards": cards, "errors": errors},
                indent=2,
                sort_keys=True,
            )
        )
    elif errors:
        print("c-cpp-profi idea check: FAIL")
        for error in errors:
            print(f"- {error}")
    else:
        print("c-cpp-profi idea check: PASS")
        print(f"cards={cards}")

    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
