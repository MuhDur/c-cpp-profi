---
name: c-cpp-profi
description: Expert C and C++ systems engineering workflow for implementation, review, debugging, hardening, performance tuning, portability, ABI/API work, native UI/pixel output, and build-system changes. Use when editing or auditing .c, .cc, .cpp, .cxx, .h, .hpp, CMake, Meson, Make, native library bindings, embedded/RT code, parsers, allocators, concurrency, SIMD, FFI, or any task where C/C++ safety, speed, determinism, and maintainability matter.
---

# c-cpp-profi

## Overview

Use this skill to make C/C++ work evidence-grade: safe by construction where possible, mechanically checked where possible, measured before claiming speed, and explicit about every remaining unsafe or non-portable assumption.

The goal is not "write clever C++." The goal is code a senior C/C++ maintainer would accept after seeing the invariants, tests, sanitizer evidence, performance evidence, and ABI/build impact.

## First Pass

1. Read project instructions first: `AGENTS.md`, build docs, contribution docs, issue tracker state, and local style files.
2. Inventory the project instead of guessing: run `bash skill/c-cpp-profi/scripts/cpp_inventory.sh <repo>` when available.
3. Identify the boundary: executable, library, public header, ABI, embedded target, parser, allocator, UI/rendering, or build tooling. Then detect the **domain** from repo signals via [DOMAIN-AGNOSTIC-MASTERY.md](references/DOMAIN-AGNOSTIC-MASTERY.md) and load (or synthesize from the pack template) its domain pack before choosing gates.
4. Choose the gate set before editing. A small change still needs compile and focused tests; parser, memory, concurrency, or security changes need sanitizer and fuzz gates.
5. Keep diffs small. In C/C++, broad cleanup can hide lifetime, ABI, and undefined-behavior changes.

## Operating Rules

- Use this skill as an enforcement workflow, not a suggestion list. For non-trivial work, produce an evidence packet that names each applicable gate as passed, failed, not run, or not applicable.
- Read [C-CPP-EXPERT-CANON.md](references/C-CPP-EXPERT-CANON.md) before broad implementation, audit, hardening, performance, ABI, parser, allocator, or concurrency work.
- Read [TOOLCHAIN-MATRIX.md](references/TOOLCHAIN-MATRIX.md) before installing, selecting, or skipping C/C++ quality tools.
- Treat undefined behavior as a release blocker unless it is isolated behind a documented, tested, platform-specific contract.
- Prefer ownership clarity over local convenience: RAII in C++, explicit owner/release contracts in C, and typed views for non-owning memory.
- Use the project standard first. If unspecified, prefer current stable standards and toolchains: C23 where supported for C, C++23 for C++, with compatibility exceptions documented.
- Do not add raw owning `new`/`delete`, naked `malloc` lifetimes, unchecked pointer arithmetic, unbounded string functions, or C-style casts without a written invariant and a better alternative considered.
- Do not claim performance from intuition. Benchmark, profile, change one lever, and remeasure.
- Do not claim memory safety from tests alone. Combine static analysis, sanitizers, fuzzing, API design, and manual invariant review.
- For public headers and shared libraries, treat ABI as part of behavior. Check symbol visibility, layout, calling convention, exception boundary, allocator boundary, and C/C++ linkage.
- For native UI, graphics, font, terminal, image, video, CAD, game, or rendering tasks, include golden artifact or screenshot comparison. "Looks right" is not a gate.

## Gate Ladder

Use the strongest applicable ladder the project can support:

1. `inventory`: build system, standards, compilers, source counts, test runners, generated files, public APIs.
2. `format`: project formatter only; do not impose a new style unless asked.
3. `compile`: warning-clean with the project compiler; add strict warnings only through the existing build system or a separate diagnostic preset.
4. `static`: `clang-tidy`, Clang Static Analyzer, MSVC `/analyze`, CodeQL, `cppcheck`, or project-approved equivalent.
5. `dynamic`: ASan+UBSan for memory/UB, LSan for leaks, MSan when dependencies can be instrumented, TSan for concurrency.
6. `tests`: focused unit/integration tests plus regression tests for every found defect.
7. `fuzz`: required for parsers, decoders, protocol handling, serialization, compression, regex-like engines, crypto wrappers, and any untrusted bytes.
8. `perf`: baseline and post-change measurements for any optimization or hot-path change.
9. `portability`: at least one non-primary compiler or platform check when the touched code is intended to be portable.
10. `handoff`: document residual risk, exact commands run, and what was not proven.

## Optimization Card

For any request that says optimize, slow, bottleneck, hotspot, p95, latency, throughput, memory, allocation, cache, SIMD, startup, frame time, or binary size, follow this card before editing:

1. `baseline`: run the workload in a release-like build and record command, inputs, environment, build flags, warmup, repetitions, p50/p95/p99 or throughput, memory when relevant, and noise controls.
2. `profile`: identify a top hotspot in the changed path using the best available tool: `perf`, Google Benchmark, `heaptrack`, `callgrind`, `cachegrind`, `massif`, `strace -c`, VTune, Instruments, WPA, Tracy, or project tooling.
3. `score`: write an opportunity row using `score = impact * confidence / effort`; only change candidates with score >= 2.0.
4. `oracle`: capture behavior proof before editing: golden outputs, checksum/corpus replay, differential scalar-vs-SIMD comparison, ABI/API/layout check, numeric tolerance, and error/ordering/ownership semantics as applicable.
5. `one lever`: change one performance lever per commit. Do not mix formatting, cleanup, bug fixes, and optimization.
6. `verify`: rerun the same oracle and benchmark, then re-profile because bottlenecks shift.
7. `report`: fill the performance gate with `baseline:`, `profile:` or `hotspot:`, `score:` or `opportunity:`, `oracle:` or `isomorphism:`, and `after:` or `result:`; then run `cpp_evidence_check.py --profile performance --require-performance-proof`.

Native C/C++ extras are mandatory when relevant: no UB-for-speed contracts, no `-ffast-math` semantic drift unless declared, no `-march=native` or target intrinsics without dispatch/fallback proof, no allocator swap without allocation evidence, no average-latency win that hides p99 or worst-case regression, and no ABI/API/ownership change hidden inside a speed patch. Read [PERFORMANCE.md](references/PERFORMANCE.md) for the full matrix.

## Task Router

| User asks for | Do this |
|---|---|
| Understand / onboard to any-domain repo | Climb the four-layer comprehension ladder in [REPO-COMPREHENSION.md](references/REPO-COMPREHENSION.md), read [DOMAIN-AGNOSTIC-MASTERY.md](references/DOMAIN-AGNOSTIC-MASTERY.md), detect the domain from repo signals, load or synthesize its pack, then gate comprehension and that pack's oracle |
| Implement feature | Inventory -> design invariants -> edit -> compile -> tests -> relevant dynamic/static gates |
| Fix crash | Reproduce first -> minimize input -> sanitizer/debugger -> regression test -> fix |
| Security hardening | Threat model -> CERT/Core Guideline checks -> static analysis -> sanitizer/fuzz -> hardening flags |
| Memory safety | Read [MEMORY-SAFETY.md](references/MEMORY-SAFETY.md), then prove ownership, bounds, lifetimes, and error paths |
| Concurrency/deadlock | Read [CONCURRENCY-DEADLOCKS.md](references/CONCURRENCY-DEADLOCKS.md), then prove lock order, interleavings, memory ordering, and runtime validation |
| Performance | Read [PERFORMANCE.md](references/PERFORMANCE.md), then profile before changing code |
| Parser/input handling | Read [TESTING-FUZZING.md](references/TESTING-FUZZING.md), then add fuzz and regression coverage |
| Build system | Read [BUILD-PORTABILITY.md](references/BUILD-PORTABILITY.md), preserve existing presets and developer workflows |
| Refactor/simplify | Read [REFACTOR-ISOMORPHISM.md](references/REFACTOR-ISOMORPHISM.md), then prove behavior, ABI, layout, and artifacts before editing |
| Port (cross compiler/std/platform/arch or C/C++ ↔ Rust) | Read [CODE-TRANSFORM.md](references/CODE-TRANSFORM.md), then build a differential oracle (origin triple, target triple, emulator/hardware, corpus) and gate `--profile port --require-transform-proof` |
| Modernize (raise standard, `clang-tidy modernize-*`, replace deprecated API) | Read [CODE-TRANSFORM.md](references/CODE-TRANSFORM.md), then carry a per-transform refactor isomorphism row plus an ABI/API check and gate `--profile modernize --require-transform-proof` |
| Re-architect (new layering/data structure/ownership) | Read [CODE-TRANSFORM.md](references/CODE-TRANSFORM.md), then keep a migration ledger with per-commit caller census plus tests plus ABI/API and gate `--profile rearchitect --require-transform-proof` |
| Review/audit | Use the multi-pass audit loop in [QUALITY-GATES.md](references/QUALITY-GATES.md), then lead with findings, file:line evidence, severity, proof, and gate gaps |
| Propose what to build / improve / rethink | Read [INNOVATION-ENGINE.md](references/INNOVATION-ENGINE.md), comprehend first, enumerate the accretive backlog plus radical bets, then land each behind its idea-evidence packet |
| Native UI/pixels | Read [NATIVE-UI-GOLDENS.md](references/NATIVE-UI-GOLDENS.md), then capture and compare rendered artifacts across target viewports/devices |
| Document / write README / API docs / changelog / docs site | Read [DOCUMENTATION.md](references/DOCUMENTATION.md), then author from inventory facts so the README usage snippet compiles, every public symbol carries an ownership/thread-safety/error contract, the changelog records ABI status, and the slop pass is clean |

## Reference Map

Load only the relevant file:

| Need | Reference |
|---|---|
| Enforcing expert workflow and elite-project patterns | [C-CPP-EXPERT-CANON.md](references/C-CPP-EXPERT-CANON.md) |
| Any-domain transfer, domain packs, unknown-domain template | [DOMAIN-AGNOSTIC-MASTERY.md](references/DOMAIN-AGNOSTIC-MASTERY.md) |
| Four-layer comprehension ladder, comprehension gate | [REPO-COMPREHENSION.md](references/REPO-COMPREHENSION.md) |
| Idea generation, accretive backlog, radical bets, idea-evidence gate | [INNOVATION-ENGINE.md](references/INNOVATION-ENGINE.md) |
| Tool families, commands, manpages, missing-tool handling | [TOOLCHAIN-MATRIX.md](references/TOOLCHAIN-MATRIX.md) |
| Gate selection and commands | [QUALITY-GATES.md](references/QUALITY-GATES.md) |
| Ownership, lifetimes, bounds, UB | [MEMORY-SAFETY.md](references/MEMORY-SAFETY.md) |
| Locks, atomics, threads, signals, loader reentrancy | [CONCURRENCY-DEADLOCKS.md](references/CONCURRENCY-DEADLOCKS.md) |
| Security review and hardening | [SECURITY-REVIEW.md](references/SECURITY-REVIEW.md) |
| Fuzzing and test strategy | [TESTING-FUZZING.md](references/TESTING-FUZZING.md) |
| Performance methodology | [PERFORMANCE.md](references/PERFORMANCE.md) |
| Build systems, ABI, portability | [BUILD-PORTABILITY.md](references/BUILD-PORTABILITY.md) |
| Behavior-preserving C/C++ refactors | [REFACTOR-ISOMORPHISM.md](references/REFACTOR-ISOMORPHISM.md) |
| Behavior- or target-changing transforms: port, modernize, re-architect | [CODE-TRANSFORM.md](references/CODE-TRANSFORM.md) |
| Native UI, rendering, screenshots, pixels | [NATIVE-UI-GOLDENS.md](references/NATIVE-UI-GOLDENS.md) |
| README, architecture/API docs, changelog, docs site, slop-free prose, docs-as-tests | [DOCUMENTATION.md](references/DOCUMENTATION.md) |
| Sanitizer/fuzz templates | [TOOLCHAIN-TEMPLATES.md](references/TOOLCHAIN-TEMPLATES.md) |
| Hermes/Codex/Claude operating mode | [AGENT-OPERATING-MODE.md](references/AGENT-OPERATING-MODE.md) |

## Helper Scripts

All scripts are read-only unless the script text explicitly says otherwise.

```bash
bash skill/c-cpp-profi/scripts/cpp_inventory.sh .
bash skill/c-cpp-profi/scripts/cpp_comprehension_map.sh .
bash skill/c-cpp-profi/scripts/cpp_gate_plan.sh .
bash skill/c-cpp-profi/scripts/cpp_risk_scan.sh .
bash skill/c-cpp-profi/scripts/cpp_backlog.sh .
bash skill/c-cpp-profi/scripts/cpp_gate_report.sh .
python3 skill/c-cpp-profi/scripts/cpp_evidence_check.py <filled-gate-report.md> --profile basic --require-warning-clean --require-analyzer-review
python3 skill/c-cpp-profi/scripts/cpp_evidence_check.py <filled-gate-report.md> --profile performance --require-performance-proof
python3 skill/c-cpp-profi/scripts/cpp_idea_check.py <filled-idea-card.md>
python3 skill/c-cpp-profi/scripts/cpp_docs_check.py <doc.md> --kind readme
bash skill/c-cpp-profi/scripts/cpp_abi_snapshot.sh <candidate-library> [baseline-library]
python3 skill/c-cpp-profi/scripts/cpp_pixel_diff.py <baseline-image> <candidate-image> --threshold 0
python3 skill/c-cpp-profi/scripts/validate_skill_contract.py skill/c-cpp-profi
```

Use the inventory script at the start of non-trivial work, `cpp_comprehension_map.sh <repo>` to emit a falsifiable L1+L2 comprehension map (build graph and ground, entry points, and a coarse module map, every line anchored to a repo-relative `file:line` or path) in one command before modeling an unfamiliar repo, the gate plan before changing build/test commands, the risk scan before review or after touching memory/input/concurrency code, the ABI snapshot helper when public libraries or plugin boundaries are touched, the pixel diff helper when rendered image artifacts are touched, and the gate report script before handoff. Prefer running `cpp_risk_scan.sh` on changed files or touched directories; whole-repo scans on mature C/C++ projects are intentionally noisy triage, not a defect list.
After filling a gate report, run `cpp_evidence_check.py` with the applicable risk profiles (`parser`, `memory`, `public-abi`, `concurrency`, `performance`, `refactor`, `native-ui`, `portability`, or `security`) before claiming the work is complete. Use `--require-warning-clean` when compile success must mean warning-clean, and `--require-analyzer-review` whenever static-analysis output is part of the gate; static tools can exit `0` while printing findings.
When proposing what to build, first run `cpp_backlog.sh <repo>` to enumerate a deduplicated, reproducible capability-gap backlog (hardening, API ergonomics, portability, test/fuzz coverage) where every row carries a `file:line` or inventory-key evidence anchor, then validate every Idea Card with `cpp_idea_check.py` before it earns an edit; it rejects blank or placeholder fields, a problem-evidence that reads as a feeling instead of a measurable anchor, and a `kind: radical` card missing its behavior oracle or reversible one-lever floor. Then enforce the matching gate row with `cpp_evidence_check.py --profile idea`.
When writing or revising a documentation surface, run `cpp_docs_check.py <doc.md> --kind readme|api|changelog` (or `--kind auto`) to lint it the same way: it flags banned AI-slop tokens outside code fences, a README missing its build/usage/license sections, a public symbol whose contract omits ownership, thread-safety, or an error/returns field, and a changelog with no versioned section.

## Examples

Use the examples as compact execution cards when a task matches a common C/C++ surface:

- [C library](examples/c-library.md): public C API, ABI, symbols, ownership, and downstream smoke.
- [Modern C++ library](examples/modern-cpp-library.md): templates, concepts, RAII, public headers, and exception safety.
- [Embedded C or RT](examples/embedded-c.md): fixed resources, ISR-like contexts, MMIO, timing, and stack/heap budgets.
- [Parser or untrusted input](examples/parser-input.md): harnesses, corpora, sanitizers, minimization, and crash regression.
- [Native UI or rendering](examples/native-ui-rendering.md): screenshots, pixel/golden artifacts, DPI/font/color/platform matrices, and frame-time evidence.
- [Idea generation](examples/idea-generation.md): accretive vs radical Idea Cards, adversarial scoring, and the idea-card evidence gate validated by `cpp_idea_check.py`.
- [Code transform](examples/code-transform.md): worked `port` + `modernize` + `re-architect` transforms with one combined Evidence Packet that passes `--profile port --profile modernize --profile rearchitect --require-transform-proof`.
- [Documentation](examples/documentation.md): a worked README + architecture note + header API contract + Keep-a-Changelog ABI-break excerpt for a sample C library, slop-free and passing `cpp_docs_check.py` for each `--kind`.

## Assets

Reusable templates live under `assets/`. Copy them into a target repo only after checking its build system and local style:

- `assets/cmake/`: CMake presets and sanitizer helper module.
- `assets/meson/`: Meson native files and libFuzzer build fragment.
- `assets/fuzz/`: minimal C and C++ libFuzzer harnesses.

## Handoff Contract

Every final answer after C/C++ edits must state: changed files, exact gates run, gates not run and why, sanitizer/fuzz/perf evidence when relevant, ABI/API impact, residual risks, and follow-up issues created. When the change touches a public API, README, or release, also record the documentation evidence from [DOCUMENTATION.md](references/DOCUMENTATION.md): which usage snippet compiled, the contract-complete header result, the changelog ABI status, and the slop-pass result.
