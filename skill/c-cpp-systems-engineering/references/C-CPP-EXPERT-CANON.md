# C/C++ Expert Canon

## Purpose

This is the enforcing knowledge layer for `c-cpp-profi`. It turns expert C/C++ habits into required agent behavior: study the codebase first, select evidence gates before editing, prove memory and lifetime invariants, measure performance, and record what remains unproven.

The canon is not complete until its claims are forward-tested against real C and C++ projects and kept synchronized with the scripts, templates, and acceptance criteria.

## Non-Negotiable Agent Contract

For any non-trivial C/C++ task, the agent must produce:

1. Boundary map: what changed, public/private surface, ownership boundary, ABI/API impact.
2. Risk map: memory, lifetime, integer, string, aliasing, concurrency, I/O, portability, and security risks.
3. Gate plan before editing: compile, tests, static analysis, dynamic analysis, fuzzing, performance, ABI, portability, and artifact gates as applicable.
4. Evidence report after editing: exact commands, outcomes, failures, skipped gates, and why skipped gates are acceptable or tracked.
5. Residual risk: what was not proven, which follow-up bead tracks it, and whether the code is still safe to land.

No "should be fine" handoff is acceptable.

## Repeat-Skill Extraction Program

The open-source quality target requires repeated application of these sibling skills:

| Pass | Skill | Required output |
|---|---|---|
| 1 | `research-software` | Toolchain matrix, current tool behavior, source anchors, manpage map |
| 2 | `codebase-pattern-extraction` | Patterns from elite C/C++ projects, with paths and commits |
| 3 | `testing-fuzzing` | Fuzz target discovery, harness rules, sanitizer campaigns, crash regression policy |
| 4 | `extreme-software-optimization` | Profile-first performance loop and isomorphism requirements |
| 5 | `multi-pass-bug-hunting` | Audit-fix-rescan convergence rules and fresh-eyes passes |
| 6 | `deadlock-finder-and-fixer` | Lock, atomics, scheduler, signal, loader, and TSan/Helgrind triage |
| 7 | `simplify-and-refactor-code-isomorphically` | Behavior-preserving refactor proof, ABI/layout/timing/golden checks |

The progress ledger is `.skill-loop-progress.md`. It must be updated after each pass.

## Elite Project Study

The following projects were cloned under `/tmp` on 2026-05-24 for pattern extraction. The directories were intentionally left in place because this repo forbids deletion without exact in-session approval.

| Project | Why it matters | Commit | Path |
|---|---|---|---|
| simdjson | performance-critical modern C++ parser with SIMD dispatch, fuzzing, benchmarks, sanitizer policy | `168ef58` | `/tmp/cpp-profi-study-simdjson-20260524` |
| mimalloc | allocator internals, secure mode, heap hardening, platform override, sanitizer/Valgrind integration | `fef6b0d` | `/tmp/cpp-profi-study-mimalloc-20260524` |
| SQLite | high-reliability C, parser/database engine, crash recovery, fault injection, fuzz regression corpus | `3020203` | `/tmp/cpp-profi-study-sqlite-20260524` |
| curl | portable C network library, massive protocol test harness, Valgrind support, docs/manpage checks | `4102400` | `/tmp/cpp-profi-study-curl-20260524` |

### Extracted Patterns

| Pattern | Evidence | Rule for agents |
|---|---|---|
| Reproducible bug reports | simdjson issue template requires complete repro data and small reduced examples | Do not fix C/C++ crashes from a vague stack trace. Reproduce and minimize first. |
| Performance claims need benchmarks | simdjson PR template asks for benchmark numbers for claimed speedups | No optimization claim without baseline and remeasure. |
| Sanitizers are expected, not optional | simdjson PR template gives sanitizer CMake commands; mimalloc exposes ASan/TSan/UBSan options | Use sanitizer builds on memory/input/concurrency changes. Record unsupported combinations. |
| Security/performance tradeoffs are explicit | mimalloc secure mode documents guard pages, randomization, encrypted free lists, and overhead | Hardening changes must name the cost and threat model. |
| Allocators need special dynamic-tool integration | mimalloc has Valgrind and ASan-specific configuration paths | Allocator or custom memory code needs Valgrind/ASan-aware validation, not generic unit tests only. |
| Crash and corruption tests become permanent corpus | SQLite stores fuzz/crash regression files and db fuzzers | Every crash input becomes a test or corpus seed. |
| Assertions encode internal invariants | SQLite source uses dense asserts and test macros around parser/BTrees/memory paths | Internal invariants must be written down or asserted where runtime cost is acceptable. |
| Protocol libraries need generated test servers and fixtures | curl has dedicated test servers, XML-like test data, Valgrind suppressions, and documentation consistency tests | Network/protocol work needs real fixtures and golden request/response evidence. |
| Documentation is testable | curl tests manpages, symbols, and docs consistency | Public API docs/examples are gates, not marketing. |
| Portability is a first-class build dimension | curl configure probes, simdjson multi-platform CI, mimalloc platform override code | Native code must be checked against target compilers/platforms, not the agent's host only. |

## C Internals That Must Be Covered

| Area | Expert checks |
|---|---|
| Object lifetime | allocation source, ownership transfer, cleanup label, double-free proof, leak proof |
| Bounds | every pointer+length pair, sentinel assumptions, integer narrowing before indexing |
| Undefined behavior | signed overflow, shift bounds, alignment, effective type, strict aliasing, uninitialized reads, invalid pointer provenance |
| Strings | bounded length, encoding assumptions, null termination, locale effects, `snprintf` result handling |
| Integers | width, signedness, conversion, multiplication overflow, allocation-size overflow |
| Error paths | cleanup idempotence, partial initialization, errno preservation, retry policy |
| ABI | symbol visibility, struct layout, enum width, calling convention, allocator ownership, version scripts |
| Preprocessor | feature-test macros, platform branches, ODR risk in headers, macro side effects |
| I/O | short reads/writes, EINTR/EAGAIN, fsync semantics, atomic rename, path encoding |
| Signals | async-signal safety, reentrancy, thread masks, no allocation in handlers |
| Concurrency | pthread contract, atomics order, data race proof, lock order, condition-variable loop, cancellation cleanup |

## C++ Internals That Must Be Covered

| Area | Expert checks |
|---|---|
| RAII | owning handles, move-only types, deterministic cleanup, no raw owning `new`/`delete` |
| Exception safety | no-throw/destructor rules, strong/basic guarantee, rollback plan, FFI exception boundary |
| Value categories | move/copy cost, dangling references, forwarding references, lifetime extension traps |
| Templates | concept/constraint clarity, instantiation bloat, error quality, ODR, ABI exposure |
| Polymorphism | virtual destructor, slicing, vtable ABI, CFI suitability, downcast proof |
| Standard library | iterator invalidation, string_view/span lifetime, allocator propagation, container stability |
| Concurrency | `std::atomic` memory order, `std::mutex` lock order, condition variables, thread lifetime |
| Modules/headers | self-contained headers, include cost, export surface, macro isolation |
| Coroutines | lifetime, cancellation, allocator use, promise type, scheduler ownership |
| Interop | `extern "C"`, name mangling, STL across ABI boundary, allocator ownership |

## Enforced Workflows

### New feature

1. Inventory.
2. State invariants and public surface.
3. Add or update focused tests.
4. Compile with project settings.
5. Run static analysis on changed files.
6. Run sanitizer or dynamic gate when memory/input/concurrency touched.
7. Update docs/examples for public API.
8. Record ABI/API impact.

### Crash or memory bug

1. Reproduce with exact command/input.
2. Minimize input.
3. Run ASan+UBSan and, if useful, Valgrind/Memcheck.
4. Inspect ownership/lifetime path manually.
5. Fix one root cause.
6. Add regression test or fuzz seed.
7. Re-run original reproducer, sanitizer, tests, and static analysis.

### Parser, decoder, file format, protocol, compression

1. Identify untrusted byte/string entry points.
2. Add or improve a narrow harness at the parser boundary.
3. Seed valid, invalid, boundary, and known-regression corpora.
4. Run ASan+UBSan fuzzer.
5. Consider MSan if uninitialized data risk is high and dependencies can be instrumented.
6. Minimize crashes before debugging.
7. Add every crash as a regression.

### Performance change

1. Capture baseline with command, inputs, CPU, compiler, flags, and commit.
2. Profile and identify hotspot.
3. Score candidate: impact times confidence divided by effort.
4. Change one lever only.
5. Prove behavior unchanged using tests, golden outputs, API/ABI checks, and floating-point notes.
6. Rerun same benchmark and profile.

### Refactor

1. Prove behavior equivalence before edit.
2. Preserve ABI/API unless the task explicitly changes it.
3. Preserve error semantics, ordering, side effects, logging, timing assumptions, and allocation ownership.
4. Prefer net-negative complexity, not abstraction for its own sake.
5. Run old and new behavior evidence on the same inputs.

### Concurrency

1. Build a lock/thread ownership map.
2. Check all nested locks for consistent order.
3. Require a concrete interleaving before reporting a race or deadlock.
4. Run TSan or Helgrind/DRD when practical.
5. For atomics, document the synchronization relation; use stronger ordering when proof is weak.
6. Check signal/loader/allocator reentrancy for callbacks and interposed libraries.

## Evidence Packet Template

```markdown
## C/C++ Evidence

Boundary:
- Public API:
- ABI:
- Ownership:
- Platform assumptions:

Risk map:
- Memory:
- UB:
- Integer/string:
- Concurrency:
- Security:
- Performance:
- Portability:

Commands:
| Gate | Command | Result | Notes |
|---|---|---|---|

Unproven:
- [gap] tracked by [bead/id]
```

## Completion Standard

The skill is not "12/10" until:

- At least three elite C/C++ projects have been cloned, studied, and summarized with reusable patterns.
- The toolchain matrix covers compiler, build, static, dynamic, fuzz, ABI, profiling, docs, portability, and hardening tools.
- The skill routes agents to existing sibling skills for fuzzing, optimization, bug hunting, deadlocks, and isomorphic refactoring.
- Missing tools produce explicit gaps, not silent skips.
- Forward tests cover CMake, Meson, sanitizer, fuzz, ABI, native UI/golden, and at least one memory-debugging gate.
- A conformance harness verifies reference links, scripts, acceptance criteria, and examples stay synchronized.
