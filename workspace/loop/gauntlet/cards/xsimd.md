# xsimd — c-cpp-profi gauntlet card

- **Repo:** xtensor-stack/xsimd @ `510b4f1` ("Add efficient_bmi2 (#1354)")
- **What:** header-only C++ SIMD intrinsics wrapper (batch types over SSE/AVX/AVX512/NEON/SVE/RVV/VSX)
- **Expected pack:** HPC / SIMD / numerics
- **Detected pack:** HPC / SIMD / numerics (PRIMARY)  ✓ match
- **Size:** ~3.8 MB; 118 `.hpp` (113 in `include/`), 53 `.cpp` (all tests/benchmark/examples). Header-only library, C++14/17.

## Gate results

**domain-detect** — primary `HPC / SIMD / numerics` with a dominant **803 code matches** at `xsimd_avx.hpp:1164`; secondaries (Filesystems 50, Networking 12, Audio/DSP 6, Generic-lib 6) are far behind. Ranking is decisive and correct; the long tail is incidental token noise but clearly subordinate.

**comprehension-map** — build graph (cmake + docs make), language breakdown (`.hpp=118 .cpp=53 .c=0`), std hints (c++14/c++17), module map (include/test/benchmark/examples) all correct. L2 exported-API list IS surfaced (1517 entries, displayed cap 40) — fix-C held in that the public API appears (`aligned_allocator`, `aligned_malloc/free`, `aes_ni`, `adx`, `address`...). Entry points: 3 real `main()` (benchmark/example/doc), no `#ifdef *_MAIN` false entry. Module map clean.

**risk-scan** — 335 hits, exit 0. Sections: unsafe-string `no matches`; raw-alloc 1 (`free(ptr)` allocator.hpp:301); new/delete 1 (placement-new allocator.hpp:226); casts ~120 `reinterpret_cast` (SIMD load/store punning); unchecked-memcpy ~80; **process/shell `no matches`**; assert-only ~145; threading `no matches`. C++ signal correctly detected → new/delete category enabled.

Top hits + triage:
- `xsimd_aligned_allocator.hpp:301 free(ptr)` — REAL call, the `#else` of a `_WIN32`/`_aligned_free` pair; correct, paired with aligned_malloc. Benign.
- `xsimd_emulated.hpp:215-217 reinterpret_cast<char*>+memcpy` — REAL type-pun bitcast of a `std::array`; sized by `size*sizeof(T_out)`. Benign (the bounded-alloc triage question answers yes).
- `xsimd_avx512f.hpp:359 *reinterpret_cast<__m512i*>(&self_asf)` — REAL strict-aliasing type-pun between `__m512`/`__m512i`; the cast lane correctly flags it (legitimate-but-review-worthy in a SIMD lib). Genuine signal, not noise.

**backlog** — hardening lane (no FORTIFY/CFI/sanitizer/stack-protector in build files: fair for a header-only lib, low value); portability lane flags endian/packing at `xsimd_config.hpp:19-20` (load-bearing — legit); CI-matrix lane reads `.github/workflows` (covers 19 compilers / 18 arches) — F3/F6 hold; test-fuzz lane flags the x86 cpuid parser (`xsimd_cpu_features_x86.hpp:329,848`) as un-fuzzed. No C++ `span`/api-ergonomics lane proposed → F2/F3 C++-gating held.

## REGRESSION CHECK
- **domainCorrect = yes.** Primary pack is exactly the expected HPC/SIMD/numerics, with an order-of-magnitude lead (803 vs next 50). F2 (`-ffast-math` rg-flag bug) did not recur.
- **fixesHeld = mostly.**
  - F1 (comment/string + C++-on-C false positives): HELD. Spot-read 3 risk hits — all real code. `process/shell` and `unsafe-string` correctly `no matches` (no "system"/prose hits). C++ categories fired *because the repo is C++* (correct), not spuriously.
  - F4 (risk-scan exit 1 on success): HELD. exit 0.
  - F5/fix-C (exported API surfaced): PARTIALLY held — the API IS listed, but see NEW weakness W8 below: the alphabetical-first display cap is dominated by ASM/macro tokens, hiding the real lowercase API.
  - F3/F6/F7 (span gating, workflows, test exclusion): HELD.

## NEW weaknesses (beyond F1–F7)
- **W8 (comprehension L2 export false positives + cap starvation):** the "non-static decl" regex surfaces non-functions as exported API: inline-asm keyword `__volatile__()` (`xsimd_neon64.hpp:187,198,211,227,238,249` — these are `__asm__ __volatile__(...)` statements), macro *parameters* `OP()`/`NAME()` (`xsimd_neon.hpp:3623`, `xsimd_constants.hpp:27`), and preprocessor macros `XSIMD_HASSINCOS()` / `XSIMD_RVV_TYPE()` / `CBRT2()`. 23 of the 40 displayed entries are bogus. Because the display is alphabetical and these are `_`/UPPERCASE-prefixed, they sort first and crowd the real lowercase API off the visible cap. Fix: drop `__volatile__`/known-keyword tokens, skip all-caps macro-shaped identifiers and macro-body parameter names, and rank the cap by likely-public lowercase symbols before truncating. (Distinct from F5, which was about *missing* the C API and counting `*_MAIN` mains.)

## Negative evidence (honest)
- No crash, no hang, no exit-code defect on any gate. Header-only C++14 template lib is squarely in scope and handled.
- No genuine missed defect found by manual spot-read in the 3 areas inspected; the aliasing/cast lane (which missed the klib over-read in batch-1) here *does* land on the real `reinterpret_cast` type-puns. Not a from-scratch audit, so absence of a missed bug is weak evidence.
- W8 is a presentation/precision flaw in comprehension, not a safety miss; the underlying real API is still emitted in the full (uncapped) list.

## Verdict
**PRODUCTIVE.** Clean clone; domain-detect nails the pack with a decisive margin; risk-scan triage is accurate with zero comment/prose false positives and correct C++ category gating; backlog is sane and span-gated. The fixes from iter-10/11 hold. One NEW finding (W8: inline-asm/macro tokens polluting the comprehension export list and starving the alphabetical cap) is worth folding back.
