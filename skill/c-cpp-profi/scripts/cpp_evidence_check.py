#!/usr/bin/env python3
"""Validate a filled c-cpp-profi evidence packet.

The gate report template is intentionally human-readable Markdown. This checker
turns the high-risk parts back into a deterministic contract so agents cannot
claim completion while leaving applicable gates blank or "not run".
"""

from __future__ import annotations

import argparse
import json
import sys
from dataclasses import dataclass
from pathlib import Path


VALID_STATUSES = {"passed", "failed", "not run", "not applicable"}
PLACEHOLDERS = {"", "yes/no", "todo", "tbd", "n/a?", "?"}

BASELINE_REQUIRED = [
    ("inventory",),
    ("compile",),
    ("tests",),
]

PROFILE_REQUIRED = {
    "basic": BASELINE_REQUIRED,
    "docs-scripts": [("inventory",)],
    "memory": [("static analysis",), ("ASan+UBSan",)],
    "parser": [("static analysis",), ("ASan+UBSan",), ("fuzz/corpus",)],
    "security": [("static analysis",), ("ASan+UBSan",)],
    "public-abi": [("ABI/API",)],
    "performance": [("performance",)],
    "concurrency": [("TSan/MSan/LSan", "Helgrind/DRD/rr/stress")],
    "refactor": [("refactor isomorphism",)],
    "native-ui": [("golden artifacts",)],
    "portability": [("portability",)],
}

SCOPE_KEYS = {
    "Issue/task",
    "Touched files",
    "Public API/ABI touched",
    "User-visible rendering/artifacts touched",
    "Parser/input/security boundary touched",
    "Threads/locks/atomics/signals touched",
    "Refactor/simplification claim",
    "Performance claim",
}

RESIDUAL_KEYS = {
    "Missing gates",
    "Why missing gates are acceptable or follow-up issue",
    "Follow-up issues",
}


@dataclass(frozen=True)
class GateRow:
    gate: str
    status: str
    command: str
    evidence: str


def normalize(value: str) -> str:
    return " ".join(value.strip().lower().split())


def read_report(path: str) -> str:
    if path == "-":
        return sys.stdin.read()
    return Path(path).read_text(encoding="utf-8")


def split_table_row(line: str) -> list[str]:
    return [cell.strip().strip("`") for cell in line.strip().strip("|").split("|")]


def section_lines(text: str, heading: str) -> list[str]:
    lines = text.splitlines()
    start = None
    for idx, line in enumerate(lines):
        if line.strip() == heading:
            start = idx + 1
            break
    if start is None:
        return []

    out: list[str] = []
    for line in lines[start:]:
        if line.startswith("## "):
            break
        out.append(line)
    return out


def parse_key_values(lines: list[str]) -> dict[str, str]:
    values: dict[str, str] = {}
    for line in lines:
        stripped = line.strip()
        if not stripped.startswith("- ") or ":" not in stripped:
            continue
        key, value = stripped[2:].split(":", 1)
        values[key.strip()] = value.strip()
    return values


def parse_gates(text: str) -> dict[str, GateRow]:
    rows: dict[str, GateRow] = {}
    for line in section_lines(text, "## Commands"):
        stripped = line.strip()
        if not stripped.startswith("|") or "---" in stripped:
            continue
        cells = split_table_row(stripped)
        if len(cells) < 4 or normalize(cells[0]) == "gate":
            continue
        gate, status, command, evidence = cells[:4]
        rows[normalize(gate)] = GateRow(gate, normalize(status), command.strip(), evidence.strip())
    return rows


def is_placeholder(value: str) -> bool:
    return normalize(value) in PLACEHOLDERS


def require_filled(
    name: str,
    values: dict[str, str],
    required: set[str],
    errors: list[str],
) -> None:
    missing = sorted(required - set(values))
    for key in missing:
        errors.append(f"{name}: missing field: {key}")
    for key in sorted(required & set(values)):
        if is_placeholder(values[key]):
            errors.append(f"{name}: unfilled field: {key}")


def required_gate_groups(profiles: list[str]) -> list[tuple[str, ...]]:
    groups: list[tuple[str, ...]] = []
    for profile in profiles:
        groups.extend(PROFILE_REQUIRED[profile])
    deduped: list[tuple[str, ...]] = []
    seen: set[tuple[str, ...]] = set()
    for group in groups:
        normalized = tuple(normalize(gate) for gate in group)
        if normalized not in seen:
            seen.add(normalized)
            deduped.append(group)
    return deduped


def check_gates(
    rows: dict[str, GateRow],
    profiles: list[str],
    allow_failed: bool,
    require_warning_clean: bool,
    require_analyzer_review: bool,
    require_performance_proof: bool,
    errors: list[str],
) -> None:
    for gate_name, row in sorted(rows.items()):
        if row.status not in VALID_STATUSES:
            errors.append(f"gate {row.gate}: invalid status {row.status!r}")
        if row.status == "failed" and not allow_failed:
            errors.append(f"gate {row.gate}: failed gate cannot be claimed complete")
        if row.status == "passed":
            if is_placeholder(row.command):
                errors.append(f"gate {row.gate}: passed without exact command")
            if is_placeholder(row.evidence):
                errors.append(f"gate {row.gate}: passed without evidence")
            evidence = normalize(row.evidence)
            if require_warning_clean and gate_name == "compile":
                warning_clean = (
                    "warning-clean: yes" in evidence
                    or "warnings: 0" in evidence
                    or "0 warnings" in evidence
                )
                if not warning_clean:
                    errors.append(
                        "gate compile: passed compile evidence must state "
                        "'warning-clean: yes' or 'warnings: 0'"
                    )
            if require_analyzer_review and gate_name == "static analysis":
                analyzer_reviewed = (
                    "findings: 0" in evidence
                    or "0 findings" in evidence
                    or "no findings" in evidence
                    or "no relevant findings" in evidence
                    or "findings reviewed:" in evidence
                    or "findings triaged:" in evidence
                )
                if not analyzer_reviewed:
                    errors.append(
                        "gate static analysis: passed evidence must state "
                        "'findings: 0', 'no relevant findings', "
                        "'findings reviewed:', or 'findings triaged:'"
                    )
            if require_performance_proof and gate_name == "performance":
                requirements = {
                    "baseline/before": ("baseline:" in evidence or "before:" in evidence),
                    "profile/hotspot": ("profile:" in evidence or "hotspot:" in evidence),
                    "opportunity score": ("score:" in evidence or "opportunity:" in evidence),
                    "behavior oracle": (
                        "oracle:" in evidence
                        or "golden:" in evidence
                        or "isomorphism:" in evidence
                    ),
                    "after/result": ("after:" in evidence or "result:" in evidence),
                }
                missing = [name for name, ok in requirements.items() if not ok]
                if missing:
                    errors.append(
                        "gate performance: passed evidence missing strict proof fields: "
                        + ", ".join(missing)
                    )

    for group in required_gate_groups(profiles):
        matching_rows = [rows.get(normalize(gate)) for gate in group]
        if not any(row is not None and row.status == "passed" for row in matching_rows):
            errors.append(
                "required gate not passed for profile "
                + ",".join(profiles)
                + ": one of "
                + ", ".join(group)
            )


def check_report(
    text: str,
    profiles: list[str],
    allow_failed: bool,
    require_warning_clean: bool,
    require_analyzer_review: bool,
    require_performance_proof: bool,
) -> list[str]:
    errors: list[str] = []
    if "# C/C++ Gate Report" not in text:
        errors.append("missing '# C/C++ Gate Report' heading")

    scope = parse_key_values(section_lines(text, "## Change Scope"))
    residual = parse_key_values(section_lines(text, "## Residual Risk"))
    rows = parse_gates(text)

    require_filled("Change Scope", scope, SCOPE_KEYS, errors)
    require_filled("Residual Risk", residual, RESIDUAL_KEYS, errors)
    if not rows:
        errors.append("Commands: no gate table rows found")
    check_gates(
        rows,
        profiles,
        allow_failed,
        require_warning_clean,
        require_analyzer_review,
        require_performance_proof,
        errors,
    )
    return errors


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("report", help="filled cpp_gate_report Markdown path, or '-' for stdin")
    parser.add_argument(
        "--profile",
        action="append",
        choices=sorted(PROFILE_REQUIRED),
        default=None,
        help="risk profile to enforce; may be repeated; default: basic",
    )
    parser.add_argument(
        "--allow-failed",
        action="store_true",
        help="allow failed gates for blocked handoffs; still rejects missing required gates",
    )
    parser.add_argument(
        "--require-warning-clean",
        action="store_true",
        help=(
            "require passed compile evidence to explicitly state "
            "'warning-clean: yes' or 'warnings: 0'"
        ),
    )
    parser.add_argument(
        "--require-analyzer-review",
        action="store_true",
        help=(
            "require passed static-analysis evidence to explicitly state "
            "zero findings or triaged/reviewed findings"
        ),
    )
    parser.add_argument(
        "--require-performance-proof",
        action="store_true",
        help=(
            "require passed performance evidence to include baseline/before, "
            "profile/hotspot, score/opportunity, oracle/golden/isomorphism, and after/result"
        ),
    )
    parser.add_argument("--json", action="store_true", help="emit JSON result")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    profiles = args.profile or ["basic"]
    text = read_report(args.report)
    errors = check_report(
        text,
        profiles,
        args.allow_failed,
        args.require_warning_clean,
        args.require_analyzer_review,
        args.require_performance_proof,
    )

    if args.json:
        print(
            json.dumps(
                {
                    "ok": not errors,
                    "profiles": profiles,
                    "require_analyzer_review": args.require_analyzer_review,
                    "require_performance_proof": args.require_performance_proof,
                    "require_warning_clean": args.require_warning_clean,
                    "errors": errors,
                },
                indent=2,
                sort_keys=True,
            )
        )
    elif errors:
        print("c-cpp-profi evidence check: FAIL")
        for error in errors:
            print(f"- {error}")
    else:
        print("c-cpp-profi evidence check: PASS")
        print("profiles=" + ",".join(profiles))

    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
