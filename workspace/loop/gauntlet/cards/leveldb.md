# leveldb — c-cpp-profi read-only gauntlet card

- **Repo:** google/leveldb @ `7ee830d` ("Bump third_party/ dependencies.")
- **Expected pack:** Databases / storage engines
- **Detected primary:** Generic library / data-structures / strings (Databases is SECONDARY)
- **Size:** 133 C/C++ files, ~28.9k LOC. Build: CMake. C++ (76 .cc / 56 .h) + 1 .c. std: C++ via CMAKE_CXX_STANDARD; C11 for the c_test.
- **Layout note:** classic Google style — tests are suffix-named `*_test.cc` co-located in `db/` `util/` etc.; there is NO `tests/` directory. Public API lives under `include/leveldb/**`; everything else is internal.

## Gate results

**domain-detect** (exit 0):
- primary: Generic library / data-structures / strings | db/c.cc:283 (33 code matches)
- secondary: Databases / storage engines | CMakeLists.txt:50 (6)
- secondary: Filesystems / block storage | db/skiplist.h:165 (3)
- The DB pack DID match and is ranked, but loses to the generic-library pack 33→6. Defensible (leveldb is a C++ data-structure-heavy lib) but the "obvious" classification ranks second. See domainCorrect.

**comprehension-map** (exit 0): build graph + lang breakdown clean. L2 exported API shows 40 of ~583 entries; L2 entry points lists the 7 real `main()`s (db_bench, leveldbutil, c_test, env tests) + 70-capped `LEVELDB_EXPORT` hints from c.h. Module map (benchmarks/db/helpers/include/port/table) correct.
- **Problem:** the headline public C++ API — `class DB`: `Open`, `Put`, `Get`, `Delete`, `Write`, `NewIterator`, `GetSnapshot`, `DestroyDB` (all in `include/leveldb/db.h`) — is NOT surfaced. Of the displayed 40 "exported API" entries, only 7 anchor to the real public surface `include/leveldb/**`; 31 anchor to PRIVATE internal headers (db/ 15, util/ 9, table/ 5, port/ 4). See NEW-3.

**risk-scan** (exit 0): 752 hits across 9 categories. Top categories: raw new/delete (largest), casts, threading, memory-movement.
- Triaged hits (real, not comments):
  - `util/cache.cc:274` `malloc(sizeof(LRUHandle) - 1 + key.size())` — REAL: deliberate flexible-array-member alloc; sized correctly. Not a defect.
  - `db/c.cc:553` `std::malloc(result.size() + 1)` + memcpy + NUL — REAL, sized, safe (C-API CopyString).
  - `util/env_posix_test.cc:150` `::execv(...)` — REAL call but in a TEST file (should be excluded; see NEW-1).
  - `db/skiplist.h:184` `new (node_memory) Node(key)` — placement-new into arena; arena owns it (relevant to backlog FP below).

**backlog** (exit 0): sane volume (~12 lines). Hardening lane (no FORTIFY/CFI/sanitizer/stack-protector) and portability lane (CI matrix 3 compilers/0 arch; `posix_logger.h:37` time_t Y2038) are legitimate, defensible notes. `.github/workflows/build.yml` correctly detected (F3/F6 hold).

## REGRESSION CHECK

- **domainCorrect = partial.** DB pack is present and ranked (the F2 ranking fix works), but ranks SECONDARY behind the generic-library pack (33 vs 6 code matches). For a KV store the expected primary is defensible-but-not-first. Not a regression of a prior fix; a ranking-weight gap.
- **fixesHeld = mostly, with two real misses:**
  - F4 (exit 0 on success): HOLDS — all four gates exit 0.
  - F2/F3/F6 (ranking, .github detection, span gating): HOLD.
  - **F7 (exclude non-shipped tests) DID NOT HOLD here.** Exclusion is directory-glob only (`**/tests/**`, `**/test/**`). leveldb's tests are suffix-named `*_test.cc`/`c_test.c` inside `db/` `util/`, so 203 of 752 risk hits (27%) come from test files (db_test.cc, corruption_test.cc, log_test.cc, fault_injection_test.cc, recovery_test.cc, env_test.cc, bloom_test.cc, autocompact_test.cc, c_test.c). The `[scope]` banner FALSELY claims tests are excluded. (benchmarks/ IS correctly excluded — 0 leaks.)
  - **F1b (comment stripping) partially held.** The line-prefix filter (`^*`, `^//`, `^/*`) works for normal cases, but 6 `include/leveldb/c.h` hits are BLOCK-COMMENT CONTINUATION lines whose content begins with bare prose (`(On Windows... malloc()-ed`, `set *errptr to a malloc()ed`, `REQUIRES: ptr was malloc()-ed`) — no leading marker, so they leak as fake `malloc/free` "calls". The filter has no block-comment state.

## NEW weaknesses (not in F1-F7)

- **NEW-1 (extends F7):** risk-scan + comprehension exclusion is path-segment-only and misses suffix-named test files (`*_test.cc`, `*_test.c`). Google-style repos co-locate tests; 203/752 risk hits here are test code. Fix: also exclude `*_test.{c,cc,cpp,cxx}`, `*_unittest.*`, `test_*.{c,cc}` by filename, not just `test/` dirs. The scope banner must not claim exclusion it does not perform.
- **NEW-2 (extends F1b):** comment post-filter cannot see multi-line `/* ... */` block-comment CONTINUATION lines (only first/marker-led lines). 6 `c.h` doc lines leaked as alloc "calls". Fix: carry block-comment open/close state across lines (the comprehension extractor already does this char-by-char — port that logic to risk-scan's filter).
- **NEW-3 (extends F5):** comprehension treats EVERY non-vendored `.h` as a "public header", so internal class methods (db_impl.h, version_set.h privates) dominate the "exported API" list while the actual public interface under `include/leveldb/**` is a minority. Worse, `static Status Open(...)` — leveldb's primary entry point `DB::Open` — is dropped by the `^static` internal-linkage filter, which conflates C file-scope `static` with C++ `static` member functions (public API). Fix: when an `include/` dir exists, rank/scope the exported-API surface to `include/**`; don't filter C++ `static` member methods the same as C internal-linkage functions.
- **NEW-4 (minor, backlog):** api-ergonomics lane flags `db/skiplist.h:184` `new (node_memory) Node(key)` as "owning raw new in a header" — but it is a PLACEMENT-new into arena-owned memory (no heap ownership crosses the boundary). False positive; the lane should exclude placement-new (`new (expr) Type`).

## Negative evidence (held up, no over-correction)

- All four gates exit 0 (F4 holds).
- `benchmarks/` directory correctly excluded from risk-scan (0 hits) — directory-glob path works.
- `.github/workflows/build.yml` detected by backlog (F3/F6 hold).
- C++ signal correctly detected → new/delete category enabled appropriately (not a pure-C false-gate).
- DB / storage pack DID match and is ranked (F2 ranking holds), just not primary.
- Triaged risk hits in shipped code (cache.cc:274, c.cc:553) are REAL calls, correctly sized — no false "defect" claim; the malloc/exec hits are genuine code, only the c.h ones are comment leaks.

## Verdict

**PRODUCTIVE.** Gates ran clean and surfaced real structure, but the repo's Google-convention layout (suffix-named tests, public/private header split, `DB::Open` as `static`) exposed three concrete regressions/gaps that the prior F1/F5/F7 fixes do not cover: filename-based test exclusion (NEW-1), block-comment continuation leaks (NEW-2), and public-vs-private header scoping incl. the `static` member-function filter dropping the headline API (NEW-3), plus a placement-new backlog FP (NEW-4). domainCorrect=partial, fixesHeld=mostly.
