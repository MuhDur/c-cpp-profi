# Catch2 — c-cpp-profi gauntlet card

- repo: https://github.com/catchorg/Catch2 @ `69e0473f6e98d47c93518424c08ee69ee632c0f0`
- expected pack: Generic library (test fw) | detected pack: **Compilers / interpreters / VMs** (WRONG — see below)
- size: 12M, 414 C/C++ files (226 .cpp, 187 .hpp, 1 .h); header+TU lib under `src/catch2/`; amalgamated `extras/`; CMake+Bazel+meson; C++11/14/17
- gates run READ-ONLY (no build); all four EXIT=0

## Gate results
- **domain-detect**: primary `Compilers / interpreters / VMs` | CMakeLists.txt:88 (2 matches); secondary `Parser` | tools/misc/coverage-helper.cpp:130 (2 matches). BOTH are false primaries — see REGRESSION CHECK. The "compiler" match is `find_package(Python3 COMPONENTS Interpreter)` build glue (the `interpreter` token); the "parser" match is `parse_log_file_arg` in a coverage tool. Root cause: the `--glob '!**/catch2/**'` vendored-framework exclusion (added iter-13 R3+ so Catch2 is skipped when vendored INTO other repos) excludes all 289 files of Catch2's OWN `src/catch2/` tree when Catch2 IS the repo. Real domain never scanned.
- **comprehension** (the one gate that does NOT apply the catch2 glob — sees real source): build graph bazel+cmake+meson; compile_commands absent (flagged); .cpp=166/.hpp=183/.h=1; std hints cxx_std_11/14/17; L2 exported-API 2607 entries (capped) — real public surface: `Approx()`, `AssertionHandler()`, `ConsoleReporter()`, `IEventListener()`, `ContainsSubstring()`, matchers/generators/reporters; 3 LLVMFuzzer entries (fuzzing/), conditional `main()` (catch_main.cpp:29, #if CATCH_AMALGAMATED_CUSTOM_MAIN — correctly tagged conditional), 7 modules (src=289, tests=34, fuzzing=5…); exported-symbol hints surfaced (catch_tostring.hpp:299/305, catch_compiler_capabilities.hpp:480). Clean and accurate.
- **risk-scan** (top hits + triage):
  - fuzzing/fuzz_textflow.cpp:45 `split((const char*)Data,Size,…)` — REAL C-style cast `uint8_t*`→`char*` in the shipped fuzz harness, bounded by `Size`. Verdict: SAFE (benign view cast). Not a decl/sizeof FP (R7 held).
  - tools/misc/coverage-helper.cpp:59/128 assert-only — arg-parsing sanity in a build TOOL, not library logic. Verdict: tooling, low-sev.
  - new/delete, alloc, memmove, shell, threading lanes: "no matches" — but this is BLIND, not clean: the catch2 glob excluded `src/catch2/` where 8 real `reinterpret_cast` (catch_tostring.cpp:34 byte-order probe, catch_optimizer.hpp:46 volatile clobber) and ~48 new/cast sites live, NONE scanned.
  - "C++ signal: yes" (new/delete category correctly enabled — Catch2 is C++). Scope banner lists exclusions; EXIT=0.
- **backlog** (sample, ALSO applies catch2 glob → also blind): hardening — no FORTIFY/CFI/stack-protector in build files; portability — CI matrix present (5 compilers/1 arch, linux-bazel-builds.yml). No C++ span-on-C noise (F3 held). No fuzz-coverage gap flagged (3 harnesses present, recognized by comprehension).

## REGRESSION CHECK (iter-13/15/16 fixes)
- **domainCorrect = no**. Expected Generic (test fw); got Compilers primary off 2 build-glue tokens. Compression pack correctly did NOT fire (no codec — preserved negative). But the classification is wrong for the right-sounding reason: the repo's entire shipped tree was self-excluded. This is the headline NEW finding (NW1).
- **fixesHeld = mostly** (the lane-level fixes hold; one scope fix self-defeats):
  - F1/R2 (comment/string FPs in domain): HELD — the `// …terrible codegen…` comment at catch_run_context.cpp:277 (the only raw Compilers token in src) was correctly stripped; it did NOT count.
  - R7 (cast-lane decl/sizeof FPs): HELD — the single cast hit is a real value cast, no prototype/sizeof FP.
  - F4 (exit 0): HELD — all four gates EXIT=0; domain self-test PASS.
  - R1 (C++ gating): HELD — "C++ signal: yes" correct; new/delete rightly enabled.
  - F5/R4 (exported API): HELD WELL — comprehension surfaced 2607 real public symbols + macro/EXPORT hints, conditional main tagged, fuzz entries found. Best of the four gates here.
  - **R3+ vendored-framework exclusion (catch2): SELF-DEFEATS (NW1).** Designed to skip vendored Catch2 in OTHER repos; when Catch2 is the audited repo it excludes 289/289 source files from domain-detect, risk-scan, AND backlog. 3 of 4 gates scanned only ~19 build/tool files.

## NEW weaknesses
- **NW1 (HIGH, new — not F1-F7/R1-R9):** vendored-framework exclusion globs are self-referential. `--glob '!**/catch2/**'` (also `!**/catch.hpp`, and the same risk for `!**/gtest/**`/`!**/unity*`/`!**/utest.h` on those repos) excludes the audited repo's OWN shipped source when the repo IS that framework. Effect on Catch2: domain-detect mis-primaries Compilers off CMake `Interpreter` (CMakeLists.txt:88); risk-scan reports "no matches" for new/delete/cast while 8 `reinterpret_cast` + ~48 alloc/cast sites sit unscanned in `src/catch2/`; backlog blind too. Fix: anchor framework-exclusion globs to vendored *locations* (e.g. `!**/{third_party,vendor,extern,deps}/**/catch2/**`, `!**/_deps/**/catch.hpp`) rather than the bare basename, OR detect "repo root basename == framework name" and disable the self-exclusion. Comprehension (no catch2 glob) is the proof it can be scanned safely.

## Negative evidence (preserved)
- Compression / codec pack did NOT fire (correct — no deflate/lz4/codec signal).
- SPACE pack did NOT fire (correct — no flight-software signal).
- No comment/string/prose FP counted in domain-detect (codegen comment stripped) or risk-scan (3 spot-reads).
- Cast lane did NOT FP on prototypes/sizeof (R7 holds); the one cast hit is real and benign.
- Comprehension did NOT mis-exclude src/catch2 — it saw and ranked the full 2607-symbol API.

## Verdict: PARTIAL
All four gates EXIT=0 and the lane-level fixes (comment-strip, cast R7, C++ gating, exit-0, exported-API) hold cleanly — comprehension is excellent. But the run surfaces a real, high-value NEW weakness (NW1): the self-referential vendored-framework exclusion blinds 3 of 4 gates to Catch2's entire shipped tree, producing a wrong Compilers primary and a falsely-empty risk-scan. Domain wrong, breadth value high.
