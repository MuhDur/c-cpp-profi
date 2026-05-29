# highway — c-cpp-profi gauntlet card

- **Repo:** google/highway @ `fc2bde7cb765db446c5f09dcdf8de69f650d9285`
- **What:** portable C++ SIMD library (HWY) — one source, runtime dispatch across SSE2..AVX-512 / NEON / SVE / RVV / VSX / WASM / LoongArch
- **Expected pack:** HPC / SIMD / numerics
- **Detected pack:** HPC / SIMD / numerics (PRIMARY)  ✓ match
- **Size:** ~14 MB; 149 `.cc`, 74 `.h`, 0 `.c`/`.cpp`. C++11/14/17. Bazel + CMake + Meson build, header-heavy (`hwy/ops/*-inl.h`).

## Gate results

**domain-detect** (exit 0) — PRIMARY `HPC / SIMD / numerics` at `CMakeLists.txt:262` with **1369 code matches**, a >12x lead. Secondaries: Compression/codec 108 (`vqsort-inl.h:773` — the new R9 pack fires off the vectorized quicksort `contrib/sort`), Filesystems 35, Networking 18, Parser 3, Generic-lib 12. Ranking decisive and correct; secondaries are subordinate vectorized-sort/threadpool vocabulary, not misclassification.

**comprehension-map** (exit 0) — build graph detects bazel/cmake/make/meson; language breakdown `.cc=149 .h=74 .c=0` correct; std hints c++11/14/17 from CMakeLists (no `-std=$(...)` Makefile brittleness → N-cmphang held). L2 exported-API IS surfaced (6124+ entries, capped 40) with real SIMD ops: `AESInvMixColumns`, `ApproximateReciprocal(Sqrt)`, `BF16FromF32/F64`, `CompressBlocksNot`, `BroadcastSignBit`, `CopyBytes`, `RearrangeToOddPlusEven`. Entry points: 12 `main()` all in `examples/`/`*_benchmark.cc`/`tests/` (no `#ifdef *_MAIN` false entry); export-macro hints map to `base.h`/`aligned_allocator.h`. Module map: 223 files under `hwy/`.

**risk-scan** (exit 0, C++ signal: yes → new/delete enabled correctly) — unsafe-string 2; raw-alloc 6; new/delete 11; casts ~400; memcpy/memmove/memset 5; **process/shell `no matches`**; **assert-only `no matches`**; threading ~55 (`std::atomic`/`std::thread`/futex — real). Top hits + triage:
- `hwy/profiler.h:115 strcpy(chars_ + pos, name)` — REAL, but **bounded**: line 114 `HWY_ASSERT(pos + len <= sizeof(chars_))` guards it; `// NOLINT`. Benign (the "is the dest sized?" triage answers yes).
- `hwy/perf_counters.cc:67 sscanf(buf.release, "%d.%d", ...)` — REAL, parses kernel version from `uname`; format is two `%d`, no `%s`/unbounded field. Benign.
- `hwy/contrib/thread_pool/thread_pool.h:956 new (storage) Worker(...)` — REAL **placement-new** into pre-sized storage, RAII-paired with explicit Destroy; the `reinterpret_cast` on 962-963 is a DASSERT self-check. Legit, not a leak.
- ~400 casts are almost entirely `reinterpret_cast<__m128i/__m256/VU64...>` SIMD lane type-puns in `ops/*-inl.h` (the library's core idiom) + uintptr alignment math in `aligned_allocator.cc`. Real, review-worthy-by-nature, zero prose/comment FPs.

**backlog** (exit 0) — api-ergonomics fires ONCE (`thread_pool.h:956` owning placement-new in a header) — correctly C++-gated (F2/F3 held), and it's a fair flag. hardening lane: no FORTIFY/CFI/stack-protector (low value for a header SIMD lib). portability: CI matrix `.github/workflows/build_test.yml` (6 compilers/6 arches) — F3/F6 held; endian/packing at `detect_compiler_arch.h:498-503` + `ppc_vsx-inl.h` (load-bearing, legit); Y2038 `futex.h:134`. test-fuzz-coverage flags `contrib/hash/hash_eval.cc:801-890` functions as un-fuzzed parser entries.

## REGRESSION CHECK
- **domainCorrect = yes.** PRIMARY is exactly HPC/SIMD/numerics with a >12x margin. F2 (`-ffast-math`/`rg -e` flag bug) did not recur. New R9 Compression pack fires as a sane secondary off the vqsort code — no wrong-primary (R8 case-sensitivity held: no `OS_`/SPACE hijack here).
- **fixesHeld = mostly.**
  - F1 (comment/string + C++-on-C FPs): HELD. Spot-read 4 risk hits — all real code; `process/shell` + `assert-only` correctly `no matches` (no English-`system`/`assert` prose). C++ categories fired because the repo IS C++ (correct), confirmed by the `[scope] C++ signal: yes` line.
  - F4 (risk-scan exit 1 on success): HELD — exit 0. F5/N-cmphang (comprehension exit / std-hint brittleness): HELD — exit 0, API surfaced.
  - F3/F6/F7 (span gating, `.github/workflows`, test exclusion): HELD — tests/examples/benchmarks excluded from risk-scan; CI matrix detected; span lane silent.
  - R7 (cast-lane reads prototypes/`sizeof(T*)` as casts): HELD — all ~400 cast hits are real `_cast<>` expressions with a value, no decl-param/sizeof FPs spotted.

## NEW weaknesses (beyond F1–F7 / R1–R9)
- **W-eval-harness (backlog test-fuzz-coverage, MED):** `hwy/contrib/hash/hash_eval.cc` is hash-QUALITY evaluation tooling (its header: *"For testing quality of hash functions. Parts are derived from smhasher"*; sibling `hash_bench.cc`; not referenced as a lib target in CMakeLists). The lane flags its internal key-gen helpers (`SparseKeygenR`, `SparseKeygen`, lines 801-890) as "parser/decoder entry point with no fuzz harness." These are eval-only, not a shipped attack surface. The `*_eval.cc` / smhasher-derived-eval naming convention is not in the test/bench exclusion set (extends R3/R6 — exclusion still misses an eval-tooling idiom). Fix: add `*_eval.cc` (and content-probe for `smhasher`/"testing quality") to the harness/bench exclusion.
- **W-comprehension-for (L2 export FP, LOW):** the non-static-decl export regex surfaces the control-flow keyword `for()` as exported API at `contrib/matvec/matvec-inl.h:82,121` and `contrib/sort/vqsort-inl.h:412,539` (a `for (...)` loop header read as a function decl). Same precision class as xsimd's W8 (`__volatile__`/macro params): drop language keywords (`for`/`while`/`switch`/`if`) from the export candidate set. Distinct token from W8.

## Negative evidence (honest)
- No crash, no hang, no nonzero exit on any of the four gates. C++11/14/17 SIMD template lib is squarely in scope.
- No genuine missed safety defect found in the spot-read areas (strcpy is asserted-bounded; placement-new is RAII-managed; casts are the SIMD core idiom). Not a from-scratch audit, so absence-of-bug is weak evidence.
- W-eval-harness and W-comprehension-for are precision/exclusion flaws (noise / one bogus token), not safety misses; the real API and real risk hits are all still emitted.
- R8 (case-sensitive distinctive tokens) had a real chance to mis-fire here (sort/threadpool vocab) and did NOT hijack the primary — held.

## Verdict
**PRODUCTIVE.** Clean clone; domain-detect nails HPC/SIMD/numerics with a >12x margin and the new Compression pack lands as a defensible secondary off the vqsort code; risk-scan triage is accurate with zero comment/prose FPs, correct C++ gating, and exit 0; backlog is span-gated and CI-aware. The iter-15/16 fixes (R7 cast-lane, R8 case-sensitivity, R9 packs, N-cmphang) hold. Two NEW low/med findings: backlog flags an `*_eval.cc` smhasher-derived eval harness as un-fuzzed (exclusion gap), and comprehension emits `for()` as exported API (keyword leak) — both worth folding back.
