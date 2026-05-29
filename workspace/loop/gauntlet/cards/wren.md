# wren — c-cpp-profi READ-ONLY gauntlet card

- **Repo:** wren-lang/wren @ `99d2f0b8fc2686134b32b18166e037639f7e9f2c` (shallow, 2026-05-29)
- **Expected pack:** Compilers / interpreters / VMs
- **Size:** 12 MB; 33 `.c` + 33 `.h` + 1 `.hpp`; clean canonical layout (`src/vm/` compiler+core+value+vm+debug+primitive+utils, `src/include/wren.h` public API, `src/optional/` meta+random)

## Gate results
- **domain-detect:** PRIMARY = **Compilers / interpreters / VMs** | `src/vm/wren_compiler.c:2868` (96 code matches). SECONDARY = Generic library (8). Decisive margin, correct file. SPACE pack did NOT fire (correct — no fprime/cFE tokens).
- **comprehension:** build=make; `compile_commands.json` absent (noted, L2-blind for index tools). lang breakdown `.c=33 .h=33 .hpp=1 .cpp/.cc/.cxx=0`. **Exported API fully surfaced**: 40 shown + 85 capped `wren*` functions from `src/include/wren.h` (wrenNewVM/FreeVM/Interpret/Call, all slot/list/map accessors). 4 entry `main()` (all in example/test/try — correctly module-mapped, not library). Module map: example/src/test/try.
- **risk-scan (clean, exit 0):** top hits with triage —
  - `wren_compiler.c:431-432` `sprintf`/`vsprintf` into `message[ERROR_MESSAGE_SIZE]` — **REAL, weak**: only a *post-hoc* `ASSERT(length < SIZE)` guards it; overflow already happened by then. Worth a `snprintf`.
  - `wren_value.c:792` `sprintf(buffer,"%.14g",value)` into `char[24]` — **safe** (24 sized to max `%.14g` per adjacent comment), idiomatic.
  - casts `(Obj**)vm->config.reallocateFn(...)` value.c:992 / vm.c:89 — **safe**, idiomatic realloc-result cast; not the R7 arithmetic-`sizeof` FP.
  - memcpy/memmove/memcmp cluster in compiler.c/value.c — **bounded**, all length-checked against interned-string/token lengths.
  - new/delete, shell-exec, threading, assert-only: **no matches** (correct for pure-C VM).
- **backlog:** hardening (no FORTIFY/CFI/sanitizer/stack-protector preset — true, plain Makefile); the 5 sprintf candidates; portability (one std, one arch in CI); test-fuzz-coverage flags `wrenUtf8Decode` (utils.c:122) + value/utils string ctors as parser-entry with no harness — **legitimate**, no fuzzer ships.

## REGRESSION CHECK (iter-12/13)
- **domainCorrect = yes.** Primary is the expected pack with a 96-vs-8 margin on the real compiler TU. F2/F8 (compiler tokens) held; no misclassification off an incidental token.
- **fixesHeld = mostly.**
  - F1/R2 comment+string strip **HELD**: every reported risk hit is live code; the `new`/`delete` tokens present only in `.wren`/`.lua`/`.dart` test fixtures and in C identifiers `wrenReallocate`/`defaultReallocate`/`newSize` were correctly NOT flagged.
  - F5/R4 exported-API **HELD strongly**: full `wren*` public surface listed from the header; no macro-wrapping needed (plain `WREN_API`-free decls).
  - R3/F7 test exclusion **HELD**: `test/` (42 files) and `example/`/`try/` kept out of risk-scan; their `main()` appear only in the comprehension module map, not as library entries.
  - R7 cast lane **HELD**: no single-pointer-prototype / arithmetic-`sizeof` false casts; the two reported casts are real realloc-result casts.
  - **R1 PARTIAL MISS (the one soft spot):** backlog/risk-scan print "C++ signal: yes (raw new/delete category enabled)" — but wren is pure C. The sole trigger is `src/include/wren.hpp`, a 12-line `extern "C" { #include "wren.h" }` convenience wrapper with **zero C++ TUs**. R1's intent was "require actual C++ source in shipped non-test dirs, not a header." A pure `extern "C"` shim header still flips the signal. No FP *explosion* resulted (genuinely no new/delete to match, so output stayed correct), but the C++-category gate is armed on a C codebase — the exact R1 class, just benign here because the category found nothing.

## NEW weakness
- **N1 (new):** C++-signal detection counts a header-only `extern "C"` shim (`src/include/wren.hpp`) as a C++ signal. R1 hardened against build-vars/test-`.cpp`; it did not exclude a `.hpp` that is *literally a C-interop wrapper containing no C++ code*. Fix: when the only C++ artifact is a header whose body is `extern "C"`-wrapping a C header (no class/template/namespace/new/delete inside), treat the repo as C. file: `src/include/wren.hpp:1-11`. (Severity low — benign output here, but it is a real residual of R1 and would re-arm new/delete on any C lib that ships a C++ convenience header.)

## Negative evidence (preserved)
- No comment/prose/string-literal risk FPs. No C++ category fired output despite the armed signal. No `runners/`-style harness leak (none exists). domain-detect did not over-match incidental tokens. Exported API not buried. The `wrenUtf8Decode` decoder flagged as an un-fuzzed entry is a genuine, valuable attack-surface call-out, not noise.

## Verdict: **PRODUCTIVE**
Clean canonical VM; the gates classified, mapped, and triaged it correctly. One real actionable defect surfaced (unbounded `sprintf`+post-hoc ASSERT at compiler.c:431). iter-12/13 fixes held across domain/comment-strip/exported-API/test-exclusion/cast lanes; one residual R1-class soft spot (N1: `extern "C"` shim header arms the C++ signal) — benign here, worth folding back.
