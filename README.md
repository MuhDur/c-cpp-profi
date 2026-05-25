# c-cpp-profi

[![skill-validate](https://github.com/MuhDur/c-cpp-profi/actions/workflows/skill-validate.yml/badge.svg)](https://github.com/MuhDur/c-cpp-profi/actions/workflows/skill-validate.yml)

`c-cpp-profi` is an agent skill for serious C and C++ work: implementation, review, hardening, debugging, performance tuning, ABI/API work, native rendering, and build-system changes.

GitHub: <https://github.com/MuhDur/c-cpp-profi>

## TL;DR

C and C++ give agents enough control to do excellent systems work and enough rope to ship undefined behavior, ABI breaks, false performance wins, and brittle portability. This skill forces the missing engineering loop:

```text
inventory -> invariants -> gate plan -> implementation -> mechanical evidence -> residual-risk handoff
```

| What agents usually miss | What this skill enforces |
|---|---|
| "It compiles" treated as done | warning-clean compile evidence, tests, static analysis, sanitizers, fuzzing, ABI, perf, portability, and artifact gates when applicable |
| Performance from intuition | baseline, profile, opportunity score, one lever, behavior oracle, same-workload remeasure |
| Static tools by exit code | analyzer output must be read and triaged |
| ABI as an afterthought | symbol, layout, public-header, calling-convention, exception, allocator, and C/C++ linkage review |
| Parser/input optimism | sanitizer-backed fuzz or corpus evidence for untrusted bytes |
| Native UI "looks right" claims | captured artifacts and pixel/golden comparisons |

Current rating:

| Layer | Rating | Meaning |
|---|---:|---|
| Design-enforcement | 12.0/12 | Skill package, references, scripts, CI, completion audit, and evidence checker are complete and innovation-grade. |
| Empirical confidence | 11.1/12 | Fresh trials on cJSON, tinyxml2, and libuv show the workflow preserves real positive and negative evidence. More blind-agent/platform trials remain useful. |

## Quick Start

Install by cloning and linking the skill into your local skill root:

```bash
git clone git@github.com:MuhDur/c-cpp-profi.git
cd c-cpp-profi
mkdir -p "$HOME/.codex/skills"
ln -s "$PWD/skill/c-cpp-profi" "$HOME/.codex/skills/c-cpp-profi"
python3 skill/c-cpp-profi/scripts/validate_skill_contract.py skill/c-cpp-profi
```

For shared-agent sessions, link the same skill into the shared root:

```bash
mkdir -p "$HOME/.agents/skills"
ln -s "$PWD/skill/c-cpp-profi" "$HOME/.agents/skills/c-cpp-profi"
```

If a destination already exists, inspect it first and decide whether to keep it, move it aside, or point agents at this checkout. The commands above intentionally fail rather than overwrite.

## Use It On A C/C++ Repo

From a target repository that contains C or C++ code:

```bash
bash /path/to/c-cpp-profi/skill/c-cpp-profi/scripts/cpp_inventory.sh .
bash /path/to/c-cpp-profi/skill/c-cpp-profi/scripts/cpp_gate_plan.sh .
bash /path/to/c-cpp-profi/skill/c-cpp-profi/scripts/cpp_gate_report.sh . > gate-report.md
python3 /path/to/c-cpp-profi/skill/c-cpp-profi/scripts/cpp_evidence_check.py gate-report.md --profile basic
```

For risk-specific work, add strict profiles:

```bash
# Parser or untrusted input
python3 /path/to/c-cpp-profi/skill/c-cpp-profi/scripts/cpp_evidence_check.py gate-report.md --profile parser --require-warning-clean --require-analyzer-review

# Public library or ABI surface
python3 /path/to/c-cpp-profi/skill/c-cpp-profi/scripts/cpp_evidence_check.py gate-report.md --profile public-abi

# Optimization claim
python3 /path/to/c-cpp-profi/skill/c-cpp-profi/scripts/cpp_evidence_check.py gate-report.md --profile performance --require-performance-proof
```

## Optimization Card

For any C/C++ performance claim, the skill now keeps the full loop visible in `SKILL.md`:

```text
baseline -> profile -> opportunity score -> oracle -> one lever -> verify -> report
```

The strict performance proof requires evidence for:

- baseline or before timing;
- profile or hotspot;
- opportunity score;
- behavior oracle, golden output, or isomorphism proof;
- after or result data.

Native-code extras stay in scope: UB, floating-point semantics, ABI/API, allocator ownership, SIMD fallback, target dispatch, portability, p99, and worst-case latency.

## Artifact Map

| Path | Purpose |
|---|---|
| `skill/c-cpp-profi/SKILL.md` | Skill entrypoint and routing. |
| `skill/c-cpp-profi/references/` | Deep references for memory safety, concurrency, performance, ABI, security, fuzzing, portability, UI goldens, and refactoring. |
| `skill/c-cpp-profi/scripts/` | Read-only helper scripts for inventory, gate planning, risk scanning, gate reports, evidence checking, ABI snapshots, pixel diffs, and contract validation. |
| `skill/c-cpp-profi/assets/` | Reusable CMake, Meson, and libFuzzer scaffolds. |
| `workspace/FORWARD-TEST-REPORT.md` | Earlier forward tests across zlib, fmt, tree-sitter, inih, FTXUI, and stb. |
| `workspace/EMPIRICAL-VALIDATION.md` | Fresh clone trials on cJSON, tinyxml2, and libuv. |
| `workspace/RATING.md` | 0-12 rating ledger with separate design and empirical-confidence layers. |
| `workspace/completion_audit.py` | Local audit that checks required files, evidence markers, stale claims, skill-root exposure, Beads state, and validators. |

## Architecture

```text
agent request
    |
    v
SKILL.md
    |
    +--> references/*.md        deep C/C++ domain rules
    +--> scripts/*.sh,*.py      deterministic gates and report checks
    +--> examples/*.md          compact execution cards
    +--> assets/                reusable sanitizer and fuzz scaffolds
    |
    v
gate report + evidence checker
    |
    v
final handoff with passed/failed/not-run/not-applicable gates
```

## Validation

Run the full local validation set:

```bash
python3 /home/durakovic/.codex/skills/.system/skill-creator/scripts/quick_validate.py skill/c-cpp-profi
python3 workspace/completion_audit.py
python3 workspace/completion_audit.py --portable
python3 skill/c-cpp-profi/scripts/validate_skill_contract.py skill/c-cpp-profi
bash -n skill/c-cpp-profi/scripts/*.sh
python3 -m py_compile skill/c-cpp-profi/scripts/*.py workspace/completion_audit.py
```

The GitHub workflow runs the portable checks and evidence-checker fixtures on push and pull request.

## Comparison

| Alternative | Strength | Gap this skill covers |
|---|---|---|
| General C/C++ model knowledge | Flexible reasoning | No enforced gate packet or machine-checkable handoff. |
| Linters and static analyzers alone | Good defect discovery | They do not prove tests, sanitizer coverage, ABI, fuzz, performance, or residual risk. |
| Generic optimization skills | Profile-first methodology | Native-code semantics such as UB, allocator ownership, ABI, SIMD fallback, and portability need C/C++-specific proof. |
| Project CI alone | Project-specific regression signal | CI often misses local tool availability, analyzer output review, fuzz campaigns, ABI drift, and performance methodology. |

## Troubleshooting

| Symptom | Fix |
|---|---|
| `ctest` fails before showing a version | Check whether `ctest` on `PATH` is a broken wrapper. Use the CTest binary from the same CMake installation and record the substitution. |
| `cpp_evidence_check.py` rejects a report | Fill every required scope and residual-risk field, then mark each gate as `passed`, `failed`, `not run`, or `not applicable` with exact command and evidence. |
| Static analysis exits `0` but prints findings | Do not mark the gate clean until findings are reviewed, triaged, fixed, or explicitly deferred. |
| `abi-dumper -public-headers` gives strange `ctags` warnings | Pass a directory of public headers or a file containing header paths. Verify Universal Ctags when public-header filtering matters. |
| Performance looks faster once | Re-run with warmups, repetitions, same inputs, same build mode, same CPU policy, and a profile showing the hotspot moved or shrank. |

## Limitations

- The evidence checker validates report shape, not the truth of command output.
- Empirical confidence is strong but not complete. Blind-agent trials and more OS/compiler/platform coverage are still tracked work.
- No license has been selected in this repository yet.
- The skill does not replace project maintainers, project CI, or domain-specific safety certification.
- Some gates are intentionally expensive. Agents should mark unavailable or skipped gates honestly rather than pretending they passed.

## Contributions

*About Contributions:* Please don't take this the wrong way, but I do not accept outside contributions for any of my projects. I simply don't have the mental bandwidth to review anything, and it's my name on the thing, so I'm responsible for any problems it causes; thus, the risk-reward is highly asymmetric from my perspective. I'd also have to worry about other "stakeholders," which seems unwise for tools I mostly make for myself for free. Feel free to submit issues, and even PRs if you want to illustrate a proposed fix, but know I won't merge them directly. Instead, I'll have Claude or Codex review submissions via `gh` and independently decide whether and how to address them. Bug reports in particular are welcome. Sorry if this offends, but I want to avoid wasted time and hurt feelings. I understand this isn't in sync with the prevailing open-source ethos that seeks community contributions, but it's the only way I can move at this velocity and keep my sanity.
