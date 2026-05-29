# simdjson — gauntlet card

- repo: simdjson/simdjson @ 98fde69253a7f92c55a0c5289264e2096c496ce3
- domain: SIMD JSON parser (C++17+); header-heavy, per-ISA backends (arm64/haswell/icelake/lasx/lsx/ppc64/rvv-vls/westmere)
- expected pack: Parser or HPC/SIMD
- size: .cpp=162, .h=385, .hpp=1; ships generated amalgamation `singleheader/simdjson.{h,cpp}` (7.4M/2.6M)
- clone: ok; all four read-only gates exit 0

## Gate results
- domain-detect: PRIMARY **Parser / text-format / serialization** (3040) — correct. Secondaries:
  HPC/SIMD (1024), **Compression/codec (239)** (new C6 pack fires), Networking (12), Crypto (2),
  Compilers (2), Generic (237). Parser-over-HPC ordering is right for a JSON parser.
  Caveat: PRIMARY anchor line is `dependencies/jsoncppdist/json-forwards.h` (vendored jsoncpp, see N1).
- comprehension: build graph ok (cmake+make; compile_commands absent flagged; std hints c++11..c++26).
  L2 exported-API surfaces real public symbols — `allocate()`, `add_overflow()`, `analyze()`,
  `allocate_padded_buffer()` from `include/simdjson/...` — but list is **+24291 capped** (8 per-ISA copies
  of every simd helper × amalgam mirror; see N3). L3 entries: 15 `LLVMFuzzerTestOneInput` fuzz harnesses
  + benchmark/example `main()`s correctly identified.
- risk-scan (C++ signal: yes — correct, simdjson is genuine C++): unsafe-string lane = **no matches** (F1 held).
  raw-alloc + new/delete + cast lanes populated; threading lane (std::mutex/unique_lock/thread) populated.
  Hits cluster in `singleheader/` (generated mirror), `dependencies/jsoncppdist/` (vendored), and real
  `include/simdjson/**` + `src/**`.
- backlog: test-fuzz-coverage 556, api-ergonomics 15, portability 13, hardening 4. The 556 is dominated by
  `singleheader/` (453) leak + the R6 fuzz-mapping miss (below).

## Risk-scan triage (spot-read at file:line)
- include/simdjson/dom/serialization.h:112 `auto new_buffer = new char[new_capacity]` — REAL raw owning
  alloc in a header (paired delete[] at :109). Legit api-ergonomics/RAII candidate, not a bug.
- include/simdjson/padded_string-inl.h:48 `new (std::nothrow) char[totalpaddedlength]` — REAL, null-checked
  at :49. Correct hardened style; legit "owner-annotate" item.
- include/simdjson/generic/ondemand/parser-inl.h:66 `reinterpret_cast<const uint8_t *>(json.data())` — REAL
  cast WITH a value after it → R7 cast-lane FP-killer HELD (not a decl-param / sizeof false positive).
- Verdict: zero comment/prose/string FPs; C++ new/delete category fires only because the repo is genuinely C++.

## REGRESSION CHECK (iter-15/16 fixes)
- domainCorrect: **yes**. Parser PRIMARY (3040) over HPC/SIMD (1024) is the right call for a SIMD JSON parser;
  matches the expected pack. The new C6 **Compression pack fired as a secondary (239)** without stealing
  PRIMARY — R9-vocab/C6 behaves on a non-codec repo.
- fixesHeld: **mostly**. HELD: F1 (no comment/string/substring FPs; unsafe-string lane empty), R1/F1a
  (C++ categories correctly enabled on real C++), R7 (cast lane requires a value — no decl-param FPs),
  F4 (all four gates exit 0), F5/R4 (exported C++ API surfaced from public headers). DID NOT hold: the
  generated-amalgamation exclusion (R3+ landed `single_include/` only; simdjson's `singleheader/` leaks —
  NEW N2) and R6 fuzz-harness mapping (still open — 556 "no harness" despite 14 shipped fuzzers + cifuzz).

## NEW weaknesses (not in F1–F7 / R1–R9)
- N2 (risk-scan + backlog, GENUINELY NEW — R3+ only covers `single_include/`): the generated amalgamation
  dir is named **`singleheader/`** here; it carries the literal banner `auto-generated ... Do not edit!`.
  It is NOT in EXCLUDE_GLOBS, so risk-scan + backlog double-count the ENTIRE shipped surface (backlog: 453 of
  556 fuzz hits, plus the bulk of new/delete + cast hits). Fix: add `**/singleheader/**` to EXCLUDE_GLOBS, or
  generically skip files whose first lines contain `auto-generated`/`Do not edit`/`amalgam`.
- N1 (domain-detect, NEW): the vendored benchmark-only dependency `dependencies/jsoncppdist/` (a copy of
  jsoncpp, used solely for comparison benchmarks) is scanned by every gate — it supplies the PRIMARY-pack
  anchor line and most raw-alloc hits. `dependencies/` is not in the exclusion set (only third_party/vendor/
  extern/external). Fix: add `**/dependencies/**` (or content-probe for a vendored-lib license/header).

## Known-open findings reproduced here (NOT new — preserve)
- R6 (open → iter 16): simdjson SHIPS 14 libFuzzer harnesses in `fuzz/` + `.github/workflows/cifuzz.yml` +
  `fuzzers.yml` (OSS-Fuzz). Backlog still emits 556 "parser entry, no fuzz harness referencing it" — it does
  not map shipped harnesses to the entries they exercise. Confirms R6 still open.
- F5 cap-noise (open): L2 capped at +24291 because per-ISA backends define identical helpers 7–8× and the
  amalgam mirrors them; dedup is per-(name,file), not per-name. Aggravated by N2.

## Negative evidence (fixes that DID hold)
- risk-scan unsafe-string lane = no matches (no English-prose `new`/`gets`/`system` FPs; F1 held).
- C++ new/delete category fires (correctly) — simdjson is real C++, so R1/F1a gate did NOT over-suppress.
- R7 cast lane: every flagged cast has a value/expr operand; no single-pointer-prototype or sizeof FPs.
- All four gates exit 0 (F4/N-cmphang held — the c++26/CMAKE_CXX_STANDARD std-hints did not abort the gate).
- C6 Compression pack present and ranked as a non-stealing secondary; Parser correctly beat HPC for PRIMARY.

## Verdict: PRODUCTIVE
domainCorrect=yes (Parser PRIMARY, C6 secondary clean). Two genuinely-new scope leaks: N2 (generated
`singleheader/` amalgamation not excluded — the dominant noise source, generalizes R3+ beyond `single_include/`)
and N1 (vendored `dependencies/jsoncppdist/` scanned, even supplies the PRIMARY anchor). R6 (fuzz-harness
mapping) reproduced as known-open. F1/F4/F5-surface/R1/R4/R7/N-cmphang held.
