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
2. Inventory the project instead of guessing: run `bash skill/c-cpp-systems-engineering/scripts/cpp_inventory.sh <repo>` when available.
3. Identify the boundary: executable, library, public header, ABI, embedded target, parser, allocator, UI/rendering, or build tooling.
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

## Task Router

| User asks for | Do this |
|---|---|
| Implement feature | Inventory -> design invariants -> edit -> compile -> tests -> relevant dynamic/static gates |
| Fix crash | Reproduce first -> minimize input -> sanitizer/debugger -> regression test -> fix |
| Security hardening | Threat model -> CERT/Core Guideline checks -> static analysis -> sanitizer/fuzz -> hardening flags |
| Memory safety | Read [MEMORY-SAFETY.md](references/MEMORY-SAFETY.md), then prove ownership, bounds, lifetimes, and error paths |
| Concurrency/deadlock | Read [CONCURRENCY-DEADLOCKS.md](references/CONCURRENCY-DEADLOCKS.md), then prove lock order, interleavings, memory ordering, and runtime validation |
| Performance | Read [PERFORMANCE.md](references/PERFORMANCE.md), then profile before changing code |
| Parser/input handling | Read [TESTING-FUZZING.md](references/TESTING-FUZZING.md), then add fuzz and regression coverage |
| Build system | Read [BUILD-PORTABILITY.md](references/BUILD-PORTABILITY.md), preserve existing presets and developer workflows |
| Refactor/simplify | Read [REFACTOR-ISOMORPHISM.md](references/REFACTOR-ISOMORPHISM.md), then prove behavior, ABI, layout, and artifacts before editing |
| Review/audit | Use the multi-pass audit loop in [QUALITY-GATES.md](references/QUALITY-GATES.md), then lead with findings, file:line evidence, severity, proof, and gate gaps |
| Native UI/pixels | Read [NATIVE-UI-GOLDENS.md](references/NATIVE-UI-GOLDENS.md), then capture and compare rendered artifacts across target viewports/devices |

## Reference Map

Load only the relevant file:

| Need | Reference |
|---|---|
| Enforcing expert workflow and elite-project patterns | [C-CPP-EXPERT-CANON.md](references/C-CPP-EXPERT-CANON.md) |
| Tool families, commands, manpages, missing-tool handling | [TOOLCHAIN-MATRIX.md](references/TOOLCHAIN-MATRIX.md) |
| Gate selection and commands | [QUALITY-GATES.md](references/QUALITY-GATES.md) |
| Ownership, lifetimes, bounds, UB | [MEMORY-SAFETY.md](references/MEMORY-SAFETY.md) |
| Locks, atomics, threads, signals, loader reentrancy | [CONCURRENCY-DEADLOCKS.md](references/CONCURRENCY-DEADLOCKS.md) |
| Security review and hardening | [SECURITY-REVIEW.md](references/SECURITY-REVIEW.md) |
| Fuzzing and test strategy | [TESTING-FUZZING.md](references/TESTING-FUZZING.md) |
| Performance methodology | [PERFORMANCE.md](references/PERFORMANCE.md) |
| Build systems, ABI, portability | [BUILD-PORTABILITY.md](references/BUILD-PORTABILITY.md) |
| Behavior-preserving C/C++ refactors | [REFACTOR-ISOMORPHISM.md](references/REFACTOR-ISOMORPHISM.md) |
| Native UI, rendering, screenshots, pixels | [NATIVE-UI-GOLDENS.md](references/NATIVE-UI-GOLDENS.md) |
| Sanitizer/fuzz templates | [TOOLCHAIN-TEMPLATES.md](references/TOOLCHAIN-TEMPLATES.md) |
| Hermes/Codex/Claude operating mode | [AGENT-OPERATING-MODE.md](references/AGENT-OPERATING-MODE.md) |

## Helper Scripts

All scripts are read-only unless the script text explicitly says otherwise.

```bash
bash skill/c-cpp-systems-engineering/scripts/cpp_inventory.sh .
bash skill/c-cpp-systems-engineering/scripts/cpp_gate_plan.sh .
bash skill/c-cpp-systems-engineering/scripts/cpp_risk_scan.sh .
bash skill/c-cpp-systems-engineering/scripts/cpp_gate_report.sh .
```

Use the inventory script at the start of non-trivial work, the gate plan before changing build/test commands, the risk scan before review or after touching memory/input/concurrency code, and the gate report script before handoff. Prefer running `cpp_risk_scan.sh` on changed files or touched directories; whole-repo scans on mature C/C++ projects are intentionally noisy triage, not a defect list.

## Assets

Reusable templates live under `assets/`. Copy them into a target repo only after checking its build system and local style:

- `assets/cmake/`: CMake presets and sanitizer helper module.
- `assets/meson/`: Meson native files and libFuzzer build fragment.
- `assets/fuzz/`: minimal C and C++ libFuzzer harnesses.

## Handoff Contract

Every final answer after C/C++ edits must state: changed files, exact gates run, gates not run and why, sanitizer/fuzz/perf evidence when relevant, ABI/API impact, residual risks, and follow-up issues created.
