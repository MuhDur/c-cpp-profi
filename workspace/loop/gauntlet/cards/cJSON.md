# Gauntlet card — DaveGamble/cJSON @ fb16e5c

- **Domain pack:** Parser/decoder (JSON), untrusted-input boundary. Size S. Std C89.
- **Reasons applied (6):** inventory, domain-detect, comprehension-map, risk-scan, backlog, **fuzz+ASan outcome-lift**.

## Gate results (real output)
- **comprehension-map:** build = cmake + make; std c89 (CMakeLists.txt:22, Makefile:27); 37 .c / 16 .h;
  no `compile_commands.json` (flagged); fuzz entry `fuzzing/cjson_read_fuzzer.c:11`. Mental model: single-file
  parser (`cJSON.c`) + utils (`cJSON_Utils.c`); parse path `cJSON_ParseWithLengthOpts` → `parse_value` → string/
  number/array/object sub-parsers guarded by `can_access_at_index`.
- **outcome-lift (the headline):** baseline clean (1.27M fuzz execs, 0 crash); seeded off-by-one in the
  `can_access_at_index` macro → ASan heap-buffer-overflow at cJSON.c:1102 `buffer_skip_whitespace`, 5-byte
  reproducer; restored clean. See [../OUTCOME-LIFT.md](../OUTCOME-LIFT.md). **The skill's gate detects real defects.**
- **risk-scan:** flagged `sprintf`/`strcat`/`strcpy` in cJSON_Utils.c (path building) + cJSON.c:461 `strcpy`.
  Triage: cJSON.c:461 is **bounded** (alloc of `strlen(valuestring)+1` immediately prior, line ~456) → FALSE
  POSITIVE for a defect, correct as triage. cJSON_Utils.c path-building `sprintf` into malloc'd buffers sized by
  a length pass — needs the recipe's overflow-checked-alloc lens to confirm; not obviously wrong.
- **backlog:** `api-ergonomics: pointer+length with no span/view` fired ~14× on the public C API (`cJSON.h:155`
  etc.). For a **C** (not C++) library this is the idiomatic API; span/view is C++ → NOT actionable here.

## Observed skill weaknesses (→ FINDINGS.md, fold back)
1. **W1 cpp_domain_detect over-matches incidental tokens**: matched "Embedded/real-time" from a Unity *test
   fixture* (`tests/unity/.../unity_fixture_malloc_overrides.h`) and gave 3 unranked packs, missing the obvious
   PARSER classification. Fix: exclude `tests/`, `third_party/`, vendored dirs; rank by match count; map JSON/XML
   parse APIs to the parser/networking pack.
2. **W2 cpp_backlog api-ergonomics lane is C++-centric**: "use span/view" is noise on a C library. Fix: gate that
   lane behind a C++ signal (`.cc/.cpp/.hpp` present or `std=c++`), or relabel for C as "document ptr+len contract".
3. **W3 risk-scan has no allocation-context awareness** (expected — it's grep triage): the bounded strcpy@461
   shows the value of REMEDIATION-RECIPES.md's "is the alloc sized?" check; not a tool bug, but a card should pair
   each risk hit with a one-line triage verdict so a finding is never reported without context.

## Negative evidence preserved
- Baseline fuzz found NO real defect in the clean tree (cJSON is heavily OSS-Fuzz'd at this commit) — honest null result.
- The risk-scan hits are NOT confirmed defects; triaged as bounded/false-positive above.

## Verdict
Skill drove genuine outcome lift (seeded-fault caught) + a correct mental model in minutes, while exposing 3 real
tool weaknesses (W1–W3) that the loop will fold back. PRODUCTIVE.
