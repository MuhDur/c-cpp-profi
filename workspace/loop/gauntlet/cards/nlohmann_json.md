# nlohmann_json — c-cpp-profi gauntlet card

- repo: nlohmann/json @ `d10879bca8f0aa790105446075a9525b34a3f718` (depth-1, 2026-05-29)
- expected pack: Parser  |  detected primary: **Parser / text-format / serialization** (599 code matches) — MATCH
- size: 29M, 490 C/C++ headers+sources. Header-only lib: `include/nlohmann/**` (57 .hpp, 17 .h);
  `single_include/nlohmann/json.hpp` is the generated 26,076-line amalgamation of `include/`; `tests/` (416 .cpp), `tools/`.
- C++ signal: yes (correctly enabled; this is C++11+ template-heavy code).

## Gate results
- **domain-detect**: primary Parser @ exceptions.hpp:166 (599 matches), runaway-dominant. secondary Space/satellites
  (6, off `cmake/download_test_data.cmake`) + Compilers (2, off an LICENSE GPL text). Both secondaries are noise but
  ranked far below primary; classification is correct. exit 0.
- **comprehension-map**: emits ONLY `## L1 build graph & ground`, then aborts (exit 1). L2 exported-API / entry-points /
  module-map sections are silently dropped. See NEW WEAKNESS N1 — root-caused to a `set -e`/`pipefail` abort. L1 itself is
  good: 4 build systems, lang breakdown (.cpp=416 .hpp=57 .h=17 .c=1), std hints c++11→c++23, compile_commands absent.
- **risk-scan**: exit 0 (F4 holds). Categories with hits: raw new/delete (6), casts-requiring-review (~80), unchecked
  memmove/memcpy/memset (16), assert-only (2). No unsafe-string, no alloc, no shell-exec, no threading. Top hits + triage:
  - `include/nlohmann/ordered_map.hpp:191` `new (&*it) value_type{std::move(*next)}` — SAFE: placement-new into existing
    slot after explicit `~value_type()`, bounded by the erase loop. Real code, correctly C++-gated.
  - `include/nlohmann/detail/input/binary_reader.hpp:2851` `reinterpret_cast<std::uint8_t*>(&number)` — SAFE: byte-swap,
    bounded by `sz/2`; deliberate byte view.
  - `include/nlohmann/detail/conversions/to_chars.hpp:1012` `std::memmove(...)` — REVIEW→likely-SAFE: Grisu dtoa, guarded by
    `JSON_ASSERT(k > n)` + documented length invariant. No comment/string/prose FPs in any sampled hit.
- **backlog**: hardening (no FORTIFY/CFI/stack-protector in build files — fair for a header-only lib), portability (CI matrix
  6 compilers/4 arches), and **78× `test-fuzz-coverage: parser entry point with no fuzz harness`** — WRONG (see R6 below).
  exit 0; benign `ignored null byte` warning x2 on workflow read (R6 nullbyte note, non-fatal).

## REGRESSION CHECK
- **domainCorrect: yes.** Parser is primary by a 100:1 margin over noise secondaries. SPACE pack fired here only as a weak
  secondary (6 matches) off a CMake test-data-download URL — NOT a misclassification (it stays buried; the fprime/cFE SPACE
  case is unrelated). Generic-C pack correctly did NOT win over the real domain (R5 tiebreak holds).
- **fixesHeld: mostly.**
  - F1 (comment/string/substring FPs; C++ cats on pure-C): HOLDS. Sampled risk hits are all real code; new/delete correctly
    enabled on actual C++; no prose/literal matches.
  - F4 (risk-scan exit 0): HOLDS (exit 0).
  - F2/F7 (domain ranking, scope exclusions): HOLD for domain-detect (tests/ excluded, ranked by count).
  - R6 (fuzz-coverage blindness): **DID NOT HOLD.** Repo ships 6 libFuzzer harnesses (`tests/src/fuzzer-parse_{json,cbor,
    msgpack,bson,ubjson,bjdata}.cpp`) + `.github/workflows/cifuzz.yml` (OSS-Fuzz/CIFuzz), and README documents OSS-Fuzz
    running "against all parsers 24/7". Backlog still emits 78 "no fuzz harness referencing it" because `tests/` is
    scope-excluded and cifuzz.yml is undetected. Clean R6 recurrence on a flagship repo (R6 was only "partial").
  - F5/R4 (exported API surfaced): UNVERIFIABLE on shipped script — L2 never prints (N1). With N1 patched, the API DOES
    surface (`accept()`, `binary_reader()`, `from_json()`, `escape()`, parser/lexer internals) but is unranked and includes
    non-API noise (`static_assert()`, `size_t()`, `M_minus()`) — an open-F5/R4 quality gap, secondary to N1.

## NEW weaknesses (not in F1-F7 / R1-R7)
- **N1 (decisive, comprehension-map)**: `cpp_comprehension_map.sh:251-253` — the std-hint loop computes
  `hint="$(printf ... | grep -oE '...-std=[a-z0-9+]+' | head -n1)"`. On `docs/Makefile:19` the broad `rg` prefilter matches
  `-std=$(call ...)` but the narrow `grep -oE` requires `[a-z0-9+]+` after `-std=` and the next char is `$` → grep exits 1 →
  under `set -euo pipefail` the substitution aborts the whole script BEFORE the `[ -n "$hint" ] || hint='std hint'` fallback
  on line 254 ever runs. Net effect: the entire L2 map (exported API, entry points, module map) is dropped and the gate
  exits 1 — on the exact deliverable the comprehension gate exists to produce. Same class as F2's `-ffast-math`/`rg`-flag
  brittleness, recurring in a different lane. Fix: append `|| true` to the `head -n1)` substitution (or `set +e` around the
  loop). Verified: with that one-line patch the gate exits 0 and emits all four sections (full parser API list).
- **N2 (minor, whole-repo scans)**: the checked-in `single_include/nlohmann/json.hpp` is a generated mirror of `include/`,
  so risk-scan reports every shipped finding twice (43 of the cast hits are the single_include duplicates) and backlog
  double-counts fuzz entry points. Not F7 (that was tests/bench/vendored) — this is a generated amalgamation of the PRIMARY
  shipped headers. Suggest: detect "amalgamation/single-header" mirrors (header banner says generated) and scan one copy.

## Negative evidence (preserved)
- domain-detect did NOT misfire SPACE/Compilers as primary; generic-C did not usurp Parser. No `-ffast-math`-style HPC bug
  here. risk-scan produced ZERO comment/string/prose false positives across sampled hits and correctly enabled C++-only
  categories. F1 and F4 are solid on this repo.

## Verdict: PARTIAL
Breadth + regression value delivered: domain-detect nails Parser; risk-scan/F1/F4 hold cleanly. But comprehension-map is
broken on this repo (N1 — drops all of L2, exits 1) and backlog regresses on R6 (78 false fuzz-coverage findings despite 6
shipped harnesses + cifuzz.yml). Two actionable defects, one decisive (N1) and one regression (R6), both fold-back-worthy.
