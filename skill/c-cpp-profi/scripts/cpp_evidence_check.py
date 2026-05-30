#!/usr/bin/env python3
"""Validate a filled c-cpp-profi evidence packet.

The gate report template is intentionally human-readable Markdown. This checker
turns the high-risk parts back into a deterministic contract so agents cannot
claim completion while leaving applicable gates blank or "not run".
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
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
    "comprehension": [("comprehension",)],
    "docs-scripts": [("inventory",)],
    "idea": [("idea card",)],
    "memory": [("static analysis",), ("ASan+UBSan",)],
    "parser": [("static analysis",), ("ASan+UBSan",), ("fuzz/corpus",)],
    "security": [("static analysis",), ("ASan+UBSan",)],
    "public-abi": [("ABI/API",)],
    "performance": [("performance",)],
    "concurrency": [("TSan/MSan/LSan", "Helgrind/DRD/rr/stress")],
    "refactor": [("refactor isomorphism",)],
    "native-ui": [("golden artifacts",)],
    "portability": [("portability",)],
    "port": [("differential oracle",)],
    "modernize": [("refactor isomorphism",), ("ABI/API",)],
    "rearchitect": [("migration ledger",), ("tests",), ("ABI/API",)],
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

# The six yes/no Change Scope fields whose answers select risk profiles.
# Each maps to the profiles its affirmative answer requires. `--derive-profiles`
# reads the report's own answers so profile selection is derived from the work,
# not self-attested on the command line.
SCOPE_BOOLEAN_KEYS = (
    "Public API/ABI touched",
    "User-visible rendering/artifacts touched",
    "Parser/input/security boundary touched",
    "Threads/locks/atomics/signals touched",
    "Refactor/simplification claim",
    "Performance claim",
)

SCOPE_PROFILE_MAP = {
    "Public API/ABI touched": ("public-abi",),
    "User-visible rendering/artifacts touched": ("native-ui",),
    "Parser/input/security boundary touched": ("parser", "security"),
    "Threads/locks/atomics/signals touched": ("concurrency",),
    "Refactor/simplification claim": ("refactor",),
    "Performance claim": ("performance",),
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


def scope_answer(value: str) -> str | None:
    """Classify a Change Scope yes/no answer.

    Returns "yes", "no", or None when the answer is not machine-usable.
    A trailing parenthetical note is tolerated (e.g. "yes (TLV parser)") so the
    report can stay human-readable while the answer stays deterministic.
    """
    normalized = normalize(value)
    if normalized == "yes" or normalized.startswith("yes ") or normalized.startswith("yes("):
        return "yes"
    if normalized == "no" or normalized.startswith("no ") or normalized.startswith("no("):
        return "no"
    return None


def derive_profiles(
    scope: dict[str, str],
    explicit: list[str],
    errors: list[str],
) -> tuple[list[str], bool]:
    """Compute the minimum profile set from the report's Change Scope answers.

    The scope vocabulary is constrained here: every *present* boolean field must
    read as yes or no. Anything else (maybe, sort of, free-text) is rejected so
    the answers stay machine-usable. Absent fields are governed by the existing
    require_filled presence check, not treated as a vocabulary error, so this
    does not change behavior for reports that omit a field.

    Returns (derived_profiles, require_performance_proof_from_scope).
    """
    derived = ["basic"]
    perf_proof = False
    for key in SCOPE_BOOLEAN_KEYS:
        if key not in scope:
            continue
        answer = scope_answer(scope[key])
        if answer is None:
            errors.append(
                f"Change Scope: field {key!r} must be yes or no (got {scope[key]!r})"
            )
            continue
        if answer == "yes":
            derived.extend(SCOPE_PROFILE_MAP[key])
            if key == "Performance claim":
                perf_proof = True

    combined = list(derived) + list(explicit)
    deduped: list[str] = []
    seen: set[str] = set()
    for profile in combined:
        if profile not in seen:
            seen.add(profile)
            deduped.append(profile)
    return deduped, perf_proof


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
    require_comprehension_proof: bool,
    require_transform_proof: bool,
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
                # Shape-only proof-of-execution tightening (checks the shape of
                # the claim, NOT its truth). A 'findings reviewed:'/'findings
                # triaged:' claim must carry a following non-empty token, and a
                # 'findings: <n>' count must be a digit, so the claim cannot be
                # an empty header or a non-numeric placeholder.
                for label in ("findings reviewed:", "findings triaged:"):
                    if label in evidence and not re.search(
                        re.escape(label) + r"\s*\S", evidence
                    ):
                        errors.append(
                            f"gate static analysis: '{label.rstrip(':')}' "
                            "must be followed by a non-empty summary"
                        )
                count_match = re.search(r"findings:\s*(\S+)", evidence)
                if count_match and not count_match.group(1).isdigit():
                    errors.append(
                        "gate static analysis: 'findings: <n>' count must be a "
                        f"digit (got {count_match.group(1)!r})"
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
            if require_comprehension_proof and gate_name == "comprehension":
                requirements = {
                    "entry-point": ("entry-point:" in evidence),
                    "module-map": ("module-map:" in evidence),
                    "callgraph": (
                        "callgraph:" in evidence
                        or "touched-path-callgraph:" in evidence
                    ),
                    "intent": ("intent:" in evidence),
                }
                missing = [name for name, ok in requirements.items() if not ok]
                if missing:
                    errors.append(
                        "gate comprehension: passed evidence missing strict proof fields: "
                        + ", ".join(missing)
                    )
            if require_transform_proof and gate_name == "differential oracle":
                requirements = {
                    "origin-triple": ("origin-triple:" in evidence),
                    "target-triple": ("target-triple:" in evidence),
                    "emulator-or-hardware": (
                        "emulator:" in evidence or "hardware:" in evidence
                    ),
                    "corpus": ("corpus:" in evidence),
                }
                missing = [name for name, ok in requirements.items() if not ok]
                if missing:
                    errors.append(
                        "gate differential oracle: passed evidence missing strict proof fields: "
                        + ", ".join(missing)
                    )
            if require_transform_proof and gate_name == "migration ledger":
                requirements = {
                    "caller-census": ("caller-census:" in evidence),
                    "ledger": ("ledger:" in evidence),
                }
                missing = [name for name, ok in requirements.items() if not ok]
                if missing:
                    errors.append(
                        "gate migration ledger: passed evidence missing strict proof fields: "
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
    require_comprehension_proof: bool,
    require_transform_proof: bool,
    derive: bool = False,
) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    if "# C/C++ Gate Report" not in text:
        errors.append("missing '# C/C++ Gate Report' heading")

    scope = parse_key_values(section_lines(text, "## Change Scope"))
    residual = parse_key_values(section_lines(text, "## Residual Risk"))
    rows = parse_gates(text)

    if derive:
        profiles, perf_proof_from_scope = derive_profiles(scope, profiles, errors)
        require_performance_proof = require_performance_proof or perf_proof_from_scope

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
        require_comprehension_proof,
        require_transform_proof,
        errors,
    )
    return errors, profiles


# --- Evidence TRUTH verification (vs. report SHAPE) ----------------------------
# The shape checks above confirm a gate is marked passed with a non-placeholder
# command + evidence. They do NOT confirm the evidence is true. `--verify-evidence`
# closes part of that gap WITHOUT re-running arbitrary (side-effecting) commands:
# the report author embeds machine-checkable assertions about the artifacts a gate
# produced, and the checker re-checks them independently. An agent then cannot
# claim a digest or artifact that does not actually exist/match.
#
#   @verify-exists{<path>}              -- path must exist (relative to --verify-base)
#   @verify-sha256{<hex>}{<path>}       -- sha256(path) must equal <hex>
#   @verify-contains{<path>}{<substr>}  -- path must exist and contain <substr> (bytes)
#
# Paths resolve against --verify-base (default: the report's directory).
VERIFY_EXISTS_RE = re.compile(r"@verify-exists\{([^{}]+)\}")
VERIFY_SHA256_RE = re.compile(r"@verify-sha256\{([0-9a-fA-F]{64})\}\{([^{}]+)\}")
VERIFY_CONTAINS_RE = re.compile(r"@verify-contains\{([^{}]+)\}\{([^{}]*)\}")


def verify_evidence(text: str, base: Path) -> tuple[list[str], int]:
    """Independently re-check @verify-* directives. Returns (errors, n_checks)."""
    errors: list[str] = []
    checks = 0

    def resolve(p: str) -> Path:
        q = Path(p)
        return q if q.is_absolute() else (base / q)

    for rel in VERIFY_EXISTS_RE.findall(text):
        checks += 1
        if not resolve(rel).exists():
            errors.append(f"verify-evidence: @verify-exists path not found: {rel}")

    for hexdigest, rel in VERIFY_SHA256_RE.findall(text):
        checks += 1
        path = resolve(rel)
        if not path.is_file():
            errors.append(f"verify-evidence: @verify-sha256 file not found: {rel}")
            continue
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        if actual.lower() != hexdigest.lower():
            errors.append(
                f"verify-evidence: @verify-sha256 mismatch for {rel}: "
                f"claimed {hexdigest.lower()}, actual {actual}"
            )

    for rel, needle in VERIFY_CONTAINS_RE.findall(text):
        checks += 1
        path = resolve(rel)
        if not path.is_file():
            errors.append(f"verify-evidence: @verify-contains file not found: {rel}")
            continue
        if needle.encode() not in path.read_bytes():
            errors.append(
                f"verify-evidence: @verify-contains: {rel} does not contain {needle!r}"
            )

    return errors, checks


def run_self_test() -> int:
    """Exercise verify_evidence on a real temp file: correct claims pass, tampered fail."""
    import tempfile

    with tempfile.TemporaryDirectory() as d:
        base = Path(d)
        (base / "out.txt").write_text("hello cross-arch world\n", encoding="utf-8")
        good_sha = hashlib.sha256((base / "out.txt").read_bytes()).hexdigest()

        ok_report = (
            "@verify-exists{out.txt} "
            f"@verify-sha256{{{good_sha}}}{{out.txt}} "
            "@verify-contains{out.txt}{cross-arch}"
        )
        errs, n = verify_evidence(ok_report, base)
        if errs or n != 3:
            print(f"cpp_evidence_check self-test: FAIL (good report: errs={errs}, n={n})")
            return 1

        bad_sha = "0" * 64
        bad_report = (
            f"@verify-sha256{{{bad_sha}}}{{out.txt}} "
            "@verify-exists{missing.txt} "
            "@verify-contains{out.txt}{NOT_PRESENT}"
        )
        errs, n = verify_evidence(bad_report, base)
        if n != 3 or len(errs) != 3:
            print(f"cpp_evidence_check self-test: FAIL (bad report should give 3 errors: errs={errs}, n={n})")
            return 1

    print("cpp_evidence_check self-test: PASS")
    return 0


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "report",
        nargs="?",
        help="filled cpp_gate_report Markdown path, or '-' for stdin",
    )
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
    parser.add_argument(
        "--require-comprehension-proof",
        action="store_true",
        help=(
            "require passed comprehension evidence to include entry-point, "
            "module-map, callgraph (or touched-path-callgraph), and intent"
        ),
    )
    parser.add_argument(
        "--require-transform-proof",
        action="store_true",
        help=(
            "require passed differential-oracle evidence to include origin-triple, "
            "target-triple, emulator/hardware, and corpus; and passed migration-ledger "
            "evidence to include caller-census and ledger"
        ),
    )
    parser.add_argument(
        "--derive-profiles",
        action="store_true",
        help=(
            "derive the required profile set from the report's '## Change Scope' "
            "yes/no answers (parser-touched -> parser+security; ABI-touched -> "
            "public-abi; threads-touched -> concurrency; perf-claim -> performance "
            "+ --require-performance-proof; refactor-claim -> refactor; "
            "rendering-touched -> native-ui; always basic), union it with any "
            "explicit --profile, and constrain each present scope answer to yes/no"
        ),
    )
    parser.add_argument(
        "--strict-numeric",
        action="store_true",
        help="alias for --require-performance-proof",
    )
    parser.add_argument(
        "--verify-evidence",
        action="store_true",
        help=(
            "independently re-check @verify-exists{}/@verify-sha256{}{}/"
            "@verify-contains{}{} directives embedded in the evidence (artifact "
            "TRUTH, not just report shape); any mismatch fails the report"
        ),
    )
    parser.add_argument(
        "--verify-base",
        default=None,
        help="base directory for @verify-* relative paths (default: the report's directory)",
    )
    parser.add_argument(
        "--self-test",
        action="store_true",
        help="run the evidence-verification self-test and exit",
    )
    parser.add_argument("--json", action="store_true", help="emit JSON result")
    return parser.parse_args(argv)


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.self_test:
        return run_self_test()
    if not args.report:
        print("error: report path required (or '-' for stdin), unless --self-test", file=sys.stderr)
        return 2
    # When --derive-profiles is set, --profile is a seed the scope answers extend;
    # without it the explicit profile set wins, defaulting to basic as before.
    explicit_profiles = args.profile or ([] if args.derive_profiles else ["basic"])
    require_performance_proof = args.require_performance_proof or args.strict_numeric
    text = read_report(args.report)
    errors, profiles = check_report(
        text,
        explicit_profiles,
        args.allow_failed,
        args.require_warning_clean,
        args.require_analyzer_review,
        require_performance_proof,
        args.require_comprehension_proof,
        args.require_transform_proof,
        args.derive_profiles,
    )

    verify_checks = 0
    if args.verify_evidence:
        if args.verify_base is not None:
            base = Path(args.verify_base)
        elif args.report == "-":
            base = Path.cwd()
        else:
            base = Path(args.report).resolve().parent
        verify_errors, verify_checks = verify_evidence(text, base)
        errors = list(errors) + verify_errors

    if args.json:
        print(
            json.dumps(
                {
                    "ok": not errors,
                    "derived_profiles": profiles if args.derive_profiles else [],
                    "profiles": profiles,
                    "require_analyzer_review": args.require_analyzer_review,
                    "require_comprehension_proof": args.require_comprehension_proof,
                    "require_performance_proof": require_performance_proof,
                    "require_transform_proof": args.require_transform_proof,
                    "require_warning_clean": args.require_warning_clean,
                    "verify_evidence": args.verify_evidence,
                    "verify_checks": verify_checks,
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
        if args.verify_evidence:
            print(f"verify-evidence: {verify_checks} artifact assertion(s) re-checked OK")

    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
