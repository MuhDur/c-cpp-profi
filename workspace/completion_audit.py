#!/usr/bin/env python3
"""Audit the local c-cpp-profi completion evidence.

This script verifies the workspace-level evidence claim around the skill. It is
intentionally stricter than the packaged skill contract: it checks forward-test
evidence, local skill-root exposure, stale wording, and the remaining Beads.
"""

from __future__ import annotations

import argparse
import json
import subprocess  # nosec B404 - this only invokes fixed local validators.
import sys
from pathlib import Path


REPO = Path(__file__).resolve().parents[1]
SKILL = REPO / "skill" / "c-cpp-profi"
CODEX_ROOT = Path("/home/durakovic/.codex/skills/c-cpp-profi")
AGENTS_ROOT = Path("/home/durakovic/.agents/skills/c-cpp-profi")
QUICK_VALIDATE = Path(
    "/home/durakovic/.codex/skills/.system/skill-creator/scripts/quick_validate.py"
)

REQUIRED_FILES = [
    "workspace/ACCEPTANCE.md",
    "workspace/FORWARD-TEST-REPORT.md",
    "workspace/EMPIRICAL-VALIDATION.md",
    "workspace/PROPOSAL.md",
    "workspace/RATING.md",
    "workspace/SOURCE-LEDGER.md",
    ".skill-loop-progress.md",
    ".github/workflows/skill-validate.yml",
    "skill/c-cpp-profi/SKILL.md",
    "skill/c-cpp-profi/agents/openai.yaml",
    "skill/c-cpp-profi/references/C-CPP-EXPERT-CANON.md",
    "skill/c-cpp-profi/references/CODE-TRANSFORM.md",
    "skill/c-cpp-profi/references/DOCUMENTATION.md",
    "skill/c-cpp-profi/references/DOMAIN-AGNOSTIC-MASTERY.md",
    "skill/c-cpp-profi/references/INNOVATION-ENGINE.md",
    "skill/c-cpp-profi/references/REPO-COMPREHENSION.md",
    "skill/c-cpp-profi/references/TOOLCHAIN-MATRIX.md",
    "skill/c-cpp-profi/references/QUALITY-GATES.md",
    "skill/c-cpp-profi/references/TESTING-FUZZING.md",
    "skill/c-cpp-profi/references/NATIVE-UI-GOLDENS.md",
    "skill/c-cpp-profi/scripts/cpp_backlog.sh",
    "skill/c-cpp-profi/scripts/cpp_comprehension_map.sh",
    "skill/c-cpp-profi/scripts/cpp_evidence_check.py",
    "skill/c-cpp-profi/scripts/cpp_idea_check.py",
    "skill/c-cpp-profi/scripts/cpp_docs_check.py",
    "skill/c-cpp-profi/examples/idea-generation.md",
    "skill/c-cpp-profi/examples/code-transform.md",
    "skill/c-cpp-profi/examples/documentation.md",
]

STALE_PHRASES = [
    "Partially proven",
    "abidiff remains unavailable",
    "public-header filtering is limited",
    "c-cpp-systems-engineering",
]

EVIDENCE_NEEDLES = {
    "workspace/FORWARD-TEST-REPORT.md": [
        "Fuzz Forward Tests",
        "10000` executed units",
        "Corpus replay result",
        "abidiff=/tmp/cpp-profi-abigail",
        "public-header-filtered ABI report",
        "FTXUI was used",
        "FFmpeg SSIM/PSNR",
        "X11/Xvfb",
        "/usr/bin/abidiff",
        "abigail-tools` and `libabigail7` are installed",
    ],
    "workspace/SOURCE-LEDGER.md": [
        "LLVM libFuzzer docs",
        "Local skill roots",
        "libabigail `abidiff`",
        "Universal Ctags",
        "C++ Core Guidelines",
        "SEI CERT C and C++ Coding Standards",
        "After global installation",
    ],
    ".skill-loop-progress.md": [
        "## Status: COMPLETE - 7 of 7",
        "research-software",
        "codebase-pattern-extraction",
        "testing-fuzzing",
        "extreme-software-optimization",
        "multi-pass-bug-hunting",
        "deadlock-finder-and-fixer",
        "simplify-and-refactor-code-isomorphically",
    ],
    "skill/c-cpp-profi/references/C-CPP-EXPERT-CANON.md": [
        "simdjson",
        "mimalloc",
        "SQLite",
        "curl",
        "Non-Negotiable Agent Contract",
        "No \"should be fine\" handoff is acceptable.",
    ],
    "workspace/ACCEPTANCE.md": [
        "Remaining gaps are repo hygiene or remote-publication follow-ups",
        "Local skill-root availability",
        "Evidence-packet enforcement",
        "Optimization self-containment",
        "Empirical confidence rating",
        "Proven locally",
    ],
    "workspace/RATING.md": [
        "Before rating: 10.4/12",
        "After rating: 12.0/12",
        "Empirical Confidence Layer",
        "11.1/12 empirical confidence",
        "Innovation credit",
        "Not Proven By This Rating",
    ],
    "workspace/EMPIRICAL-VALIDATION.md": [
        "cJSON",
        "tinyxml2",
        "libuv",
        "Current empirical-confidence rating after this pass: **11.1/12**",
        "--require-warning-clean",
        "--require-analyzer-review",
        "static-analysis findings",
    ],
    "skill/c-cpp-profi/SKILL.md": [
        "cpp_evidence_check.py",
        "Optimization Card",
        "--require-performance-proof",
        "--require-warning-clean",
        "--require-analyzer-review",
        "DOMAIN-AGNOSTIC-MASTERY.md",
        "INNOVATION-ENGINE.md",
    ],
    "skill/c-cpp-profi/references/DOMAIN-AGNOSTIC-MASTERY.md": [
        "Universal Core",
        "Domain Pack Template",
        "Seed Packs",
        "Pack-Selection Procedure",
        "Space / satellites",
    ],
    "skill/c-cpp-profi/references/INNOVATION-ENGINE.md": [
        "Idea Card",
        "Adversarial Scoring",
        "Accretive vs Radical",
        "Mandatory Evidence Gates for Radical Change",
    ],
    "skill/c-cpp-profi/references/CODE-TRANSFORM.md": [
        "port",
        "modernize",
        "re-architect",
        "differential oracle",
        "migration ledger",
    ],
    "skill/c-cpp-profi/references/DOCUMENTATION.md": [
        "README",
        "Architecture",
        "API Docs",
        "Changelog",
        "slop",
        "docs-as-test",
        "Completion Standard",
    ],
    "skill/c-cpp-profi/references/REPO-COMPREHENSION.md": [
        "Build graph",
        "Domain intent",
        "Comprehension is falsifiable",
        "No editing code you cannot model",
        "--require-comprehension-proof",
    ],
    "skill/c-cpp-profi/references/QUALITY-GATES.md": [
        "validate the filled packet",
        "Profiles are intentionally stricter",
        "--require-performance-proof",
        "--require-warning-clean",
        "--require-analyzer-review",
    ],
    "skill/c-cpp-profi/references/PERFORMANCE.md": [
        "Quick Optimization Card",
        "--require-performance-proof",
        "Opportunity score",
    ],
    ".github/workflows/skill-validate.yml": [
        "workspace/completion_audit.py --portable",
        "Evidence checker rejects template",
        "Evidence checker accepts filled parser report",
        "Evidence checker enforces warning and analyzer claims",
        "Evidence checker accepts filled performance report",
        "Evidence checker rejects incomplete performance proof",
    ],
}

ALLOWED_OPEN_BEADS = {
    "cpp-1ko": "Clean generated foo.gz after explicit approval",
    "cpp-c5p": "Run blind-agent and platform empirical trials for c-cpp-profi",
}
JSON_DECODER = json.JSONDecoder()


def read(rel: str) -> str:
    return (REPO / rel).read_text(encoding="utf-8")


def add_error(errors: list[str], message: str) -> None:
    errors.append(message)


def run_checked(args: list[str], errors: list[str]) -> None:
    result = subprocess.run(
        args,
        cwd=REPO,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        check=False,
        timeout=30,
    )  # nosec B603 - args are assembled from trusted local constants.
    if result.returncode != 0:
        add_error(errors, f"command failed: {' '.join(args)}\n{result.stdout}")


def check_required_files(errors: list[str]) -> None:
    for rel in REQUIRED_FILES:
        if not (REPO / rel).exists():
            add_error(errors, f"required file missing: {rel}")


def check_skill_roots(errors: list[str]) -> None:
    for root in [CODEX_ROOT, AGENTS_ROOT]:
        if not root.exists():
            add_error(errors, f"skill root path missing: {root}")
            continue
        if not root.is_symlink():
            add_error(errors, f"skill root path is not a symlink: {root}")
            continue
        if root.resolve() != SKILL.resolve():
            add_error(errors, f"skill root points to {root.resolve()}, expected {SKILL}")


def check_acceptance_table(errors: list[str]) -> None:
    text = read("workspace/ACCEPTANCE.md")
    rows = [
        line
        for line in text.splitlines()
        if line.startswith("| ") and not line.startswith("|---")
    ]
    requirement_rows = [line for line in rows if "| Requirement |" not in line]
    if len(requirement_rows) < 13:
        add_error(errors, f"acceptance table has too few requirement rows: {len(requirement_rows)}")
    for row in requirement_rows:
        cells = [cell.strip() for cell in row.strip("|").split("|")]
        if len(cells) < 3:
            add_error(errors, f"malformed acceptance row: {row}")
            continue
        status = cells[-1]
        if status not in {"Proven locally", "Proven by current files"}:
            add_error(errors, f"unproven acceptance row: {cells[0]} -> {status}")


def check_stale_phrases(errors: list[str]) -> None:
    targets = [
        "workspace/ACCEPTANCE.md",
        "workspace/FORWARD-TEST-REPORT.md",
        "workspace/SOURCE-LEDGER.md",
        "skill/c-cpp-profi/SKILL.md",
        "skill/c-cpp-profi/references/TOOLCHAIN-MATRIX.md",
    ]
    for rel in targets:
        text = read(rel)
        for phrase in STALE_PHRASES:
            if phrase in text:
                add_error(errors, f"stale phrase in {rel}: {phrase}")


def check_evidence_needles(errors: list[str]) -> None:
    for rel, needles in EVIDENCE_NEEDLES.items():
        text = read(rel)
        for needle in needles:
            if needle not in text:
                add_error(errors, f"missing evidence marker in {rel}: {needle}")


def check_open_beads(errors: list[str]) -> None:
    path = REPO / ".beads" / "issues.jsonl"
    if not path.exists():
        add_error(errors, ".beads/issues.jsonl missing")
        return

    open_beads: dict[str, str] = {}
    for line_no, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        if not line.strip():
            continue
        try:
            issue = JSON_DECODER.decode(line)
        except json.JSONDecodeError as exc:
            add_error(errors, f".beads/issues.jsonl:{line_no}: invalid JSON: {exc}")
            continue
        if not isinstance(issue, dict):
            add_error(errors, f".beads/issues.jsonl:{line_no}: expected JSON object")
            continue
        if issue.get("status") == "open":
            open_beads[str(issue.get("id"))] = str(issue.get("title"))

    if open_beads != ALLOWED_OPEN_BEADS:
        add_error(
            errors,
            "unexpected open Beads: "
            + json.dumps(open_beads, sort_keys=True)
            + " expected "
            + json.dumps(ALLOWED_OPEN_BEADS, sort_keys=True),
        )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--portable",
        action="store_true",
        help="skip local skill-root and quick_validate checks that depend on this workstation",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    errors: list[str] = []

    if not SKILL.exists():
        add_error(errors, f"skill directory missing: {SKILL}")

    check_required_files(errors)
    if not args.portable:
        check_skill_roots(errors)
    check_acceptance_table(errors)
    check_stale_phrases(errors)
    check_evidence_needles(errors)
    check_open_beads(errors)

    validator = SKILL / "scripts" / "validate_skill_contract.py"
    validator_targets = [SKILL] if args.portable else [SKILL, CODEX_ROOT, AGENTS_ROOT]
    for target in validator_targets:
        run_checked([sys.executable, str(validator), str(target)], errors)

    if QUICK_VALIDATE.exists() and not args.portable:
        for target in validator_targets:
            run_checked([sys.executable, str(QUICK_VALIDATE), str(target)], errors)
    elif not args.portable:
        add_error(errors, f"quick_validate.py missing: {QUICK_VALIDATE}")

    if errors:
        print("c-cpp-profi completion audit: FAIL")
        for error in errors:
            print(f"- {error}")
        return 1

    print("c-cpp-profi completion audit: PASS")
    print(f"skill={SKILL}")
    print(f"codex_root={CODEX_ROOT}")
    print(f"agents_root={AGENTS_ROOT}")
    print("allowed_open_beads=" + ",".join(sorted(ALLOWED_OPEN_BEADS)))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
