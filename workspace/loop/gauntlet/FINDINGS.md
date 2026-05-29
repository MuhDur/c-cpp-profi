# Gauntlet Findings — skill weaknesses observed on real repos (→ fold back into the skill)

The point of the 50-repo gauntlet (per the brief): surface the skill's "limitations, shortcuts, weak spots,
failures, shortcomings" on real code and IMPROVE the skill with them. Each finding: ID, repo(s) that exposed it,
the weakness, the fix, and status (open / folded-back commit).

| ID | Exposed by | Weakness | Fix | Status |
|---|---|---|---|---|
| W1 | cJSON | `cpp_domain_detect.sh` over-matches incidental tokens (matched "embedded" off a Unity test fixture) and returns unranked multi-packs, missing the obvious parser classification | exclude `tests/`/`third_party/`/vendored dirs; rank packs by match count; add JSON/XML-parse → parser/networking signal | open → fold in a "findings" pass |
| W2 | cJSON | `cpp_backlog.sh` `api-ergonomics` lane proposes span/view on a **C** library where ptr+len is the idiom (noise) | gate that lane behind a C++ signal; for C, relabel as "document ptr+len ownership contract" | open |
| W3 | cJSON | risk-scan hits reported without allocation/bounds context invite false positives (strcpy@461 is bounded) | card protocol: every risk hit gets a one-line triage verdict; cross-link REMEDIATION-RECIPES "is the alloc sized?" | open (process, partly a doc fix) |

## Batch-1 synthesis (66 observations across 12 repos → 7 recurring findings)

| ID | Freq | Weakness | Fix | Status |
|---|---|---|---|---|
| F1 | ~11/12 | risk-scan & backlog match inside **comments/string-literals** and as **substrings** (English `new`/`delete`/`system`/`gets`/`sprintf` in prose flagged as code); C++-only categories (new/delete, span) fire on **pure-C** repos | strip comments+strings before matching; word-boundary/expression tokens not substrings; gate C++ categories behind a C++ file signal | **FOLDED `dca0f16`** (cglm 233→1, uthash 460→70, dr_libs 127→38; no over-correction) |
| F2 | ~10/12 | `cpp_domain_detect.sh`: (a) **no parser/text-format pack** & no generic-C-library pack; (b) misclassifies off ONE incidental token; (c) **BUG: HPC pattern starts `-ffast-math` → `rg` parses `-f` as a flag → HPC pack never matches** (cglm) | use `rg -e`; add parser + generic-C packs; exclude tests/docs/vendored; rank by code-match count | **FOLDED `07bad20`** (5 parsers fixed; cglm→HPC; klib/uthash/sds→generic; littlefs stays) |
| F3 | ~9/12 | backlog: C++ `span` on C libs; **blind to `.github/workflows`**; flags **shipped fuzz harness** + test files as uncovered; flags the **existing** portable accessor (littlefs) | gate span behind C++; detect `.github/workflows`; recognize shipped harnesses + exclude tests | **FOLDED `dca0f16`** |
| F4 | tinyxml2 | `cpp_risk_scan.sh` **exits 1 on success** (trailing `rg` no-match) | ensure final exit 0 on successful triage | **FOLDED `dca0f16`** (exit=0 verified) |
| F5 | ~6/12 | comprehension-map: omits **exported C API** (inih `ini_parse`, logc `log_*`); counts doc-comment / `#ifdef *_MAIN` `main()` as entry; 1511 unranked symbol-hints on cglm | surface non-static public-header functions; skip `#ifdef *_MAIN`; strip comments; dedup+cap | open → iter 11 pass C |
| F6 | ~5/12 | inventory/backlog blind to `.github/workflows/` (subsumed by F3) | scan `.github/workflows/` | **FOLDED `dca0f16`** |
| F7 | littlefs,utf8h | whole-repo scans mix non-shipped test/bench/vendored harnesses with library code | exclude tests/bench/third_party/vendored | **FOLDED `dca0f16`/`07bad20`** (note: `runners/` added in domain-detect; risk-scan `runners/` left — see card) |

**Genuine missed defect (not a false positive — a real bug the tool SHOULD have caught):** klib `knetfile.c:173`
`*((unsigned long*)hp->h_addr)` — 8-byte read of a 4-byte `in_addr` on LP64 (strict-aliasing + over-read). The
risk-scan endian/packing lane landed on the adjacent safe line and missed this. → motivates an aliasing/cast-width
lane (future). Recorded as a real-world find the skill should detect.

## Batch-2 synthesis (34 observations across 12 repos → 7 recurring REGRESSIONS of the iter-10/11 fixes)

The regression-check proved the fixes hold on easy repos but break on harder ones (auxiliary C++ build targets,
macro-wrapped APIs, suffix-named tests, multi-line comments). domainCorrect 3/12 fully-yes, fixes-held 10/12.
This is the value of breadth: it found exactly where the fixes are incomplete.

| ID | Freq | Regression | Fix | Status |
|---|---|---|---|---|
| R1 | mbedtls,libuv,FreeRTOS,(miniaudio) | `detect_cpp()` fires C++ on `CMAKE_CXX_STANDARD`/conditional `enable_language(CXX)`/a test-only `.cpp` with ZERO shipped C++ TUs → re-enables new/delete → FP explosion (FreeRTOS ~200) | require actual C++ source in shipped (non-test) dirs, not a build-var/test target | **FOLDED `<D>`** |
| R2 | FTXUI,leveldb,FreeRTOS,lwip,re2 | comment filter drops only LEADING comment lines; trailing `//` + inline/multi-line `/* */` continuation leak | strip trailing `//`, inline `/* */`, track block-comment state | **FOLDED `<D>`** |
| R3 | leveldb,re2,lua,miniaudio | exclusion is path-segment-only — misses `*_test.*`/`*test*.c*`, `testing/`, `extras/`, flat-root harness (`ltests.*`) | add suffix-name + `testing/`/`extras/`/`bench*` + harness-name exclusion | **FOLDED `<D>`** |
| R4 | lua,mbedtls,libuv,FreeRTOS,leveldb,xsimd,miniaudio,FTXUI | comprehension exported-API breaks on macro/paren idioms (`LUA_API (name)`, `UV_EXTERN`, `MBEDTLS_PRIVATE`, `MA_API`, `PRIVILEGED_FUNCTION`); cap buried public API behind internal/`_`/UPPER tokens; C++ `static` member dropped | handle macro-wrapped decls; skip `_PRIVATE`/asm/macro-param; rank include/-path + macro-exported first | open → iter 13 Pass E |
| R5 | miniaudio,FreeRTOS,lwip | domain-detect: `__device__` substring-matches a fn name (miniaudio→GPU); priority tiers have no count-floor (8 GPU matches beat 1446 Audio); generic wins primary by raw count over the real domain | word-bound tokens; count-floor / domain-over-generic tiebreak | **FOLDED `<D>`** (token-bound + floor) |
| R6 | mbedtls,libsodium,lwip | backlog fuzz-coverage over-matches any `(const unsigned char*,size_t)` as parser; blind to OSS-Fuzz/CIFuzz (`.github/workflows/cifuzz.yml`); `test/` excluded so shipped fuzzer missed; nullbyte warning (mbedtls N4) | tighten parser-entry heuristic; detect cifuzz/oss-fuzz; `tr -d '\0'` on corpus read | partial (`<D>`) → iter 13 |
| R7 | libsodium,libuv | risk-scan cast lane FPs (arithmetic `(sizeof…)` expr; single-pointer prototypes read as casts) | tighten the cast regex (require a value after the cast) | open → iter 13 |

Real domain-detect win recorded: chibicc/lua now hit Compilers-VMs secondary; F8 (compiler vs parser signals) noted
for a Compilers-pack token enrichment (AST/Node/tokenize/codegen) — iter 13.

## Batch-3 synthesis (22 observations across 12 repos; iter-12/13 fixes held 12/12)

Good news first: the SPACE pack fired correctly as PRIMARY on **NASA cFE** (24,806 matches — real flight software,
the brief's headline domain) and secondary on F´; lz4/nlohmann/fmt/wren/tinycc/blake2/cFE all PRODUCTIVE; the
R1–R5 fixes held on all 12. New issues cluster into:

| ID | Freq/sev | Finding | Fix | Status |
|---|---|---|---|---|
| N-cmphang | nlohmann (CRITICAL) | `cpp_comprehension_map.sh` `grep -oE '-std=…'` exits 1 on a `-std=$(call…)` Makefile; under `set -euo pipefail` the whole gate aborts and drops all L2 (same brittleness class as F2's `-ffast-math`) | `|| true` on the std-hint substitution | **FOLDED `<F>`** |
| R8 | zlib, fprime (HIGH) | case-insensitive domain matching: cFS `OS_[A-Z]` matches zlib `OS_CODE` → SPACE wins PRIMARY on a compression lib; `\bopcode\b` matches fprime `FwOpcodeType` → Compilers over Space | case-sensitive matching for distinctive uppercase API tokens (`OS_`, `CFE_`) and `opcode` | **FOLDED `<F>`** |
| R7 | nng 68%, tinycc, pcre2, cFE, fprime, libsodium, libuv (HIGH freq) | cast-lane reads single-pointer prototype params `foo(Type *)` and `sizeof(T*)` as C-style casts | require a value/expr after `(T*)`; don't match decl param lists / sizeof | **FOLDED `<F>`** |
| R3+ | cFE `ut-coverage/`/`ut-stubs/` (77% of hits), fprime CamelCase `STest/`/`FppTestProject/`, pcre2 `*test_inc.h`, tinycc `win32/include/`, nlohmann `single_include/` (generated amalgam) | exclusion misses these conventions | add `ut-coverage/`, `ut-stubs/`, CamelCase `*Test*/`, `*test_inc.h`, vendored `*/include/` target-libc, generated `single_include/` | **FOLDED `<F>`** |
| R9-vocab | nng (Net 9 vs Parser), blake2 (Crypto 10 vs HPC), lz4 (no compression pack), fprime (Space blind to F´/CCSDS/Tlm/APID), zlib (no compression pack) | domain packs lack key vocabulary → wrong primary | enrich Networking (socket/listener/dialer/send/recv), Crypto (hash/digest/cipher/blake/sha), Space (CCSDS/Framer/Tlm/APID/FwOpcode), add a Compression/codec pack; narrow Parser `*_decode` | open → iter 16 |
| R1± | rapidjson (false-neg), wren (false-pos) | header-only C++ libs (templates in .h, .cpp only in test) read as pure-C (suppresses new/delete); extern-C `.hpp` shim read as C++ | content-probe `.h` for `template<`/`namespace`/`class`/`reinterpret_cast`; ignore pure extern-C shims | open → iter 16 |
| R4+ | zlib (ZEXTERN, no underscore), pcre2 (`.h.in`/`.h.generic` generated) | export-macro allowlist + public-header glob miss these idioms | add `Z*EXTERN`/no-underscore macros; treat `*.h.in`/`*.h.generic` as public headers | open → iter 16 |
| R6 | nlohmann (78 false "no fuzz"), lz4, libsodium | backlog blind to shipped libFuzzer harnesses + OSS-Fuzz/CIFuzz | (still open) detect cifuzz.yml / oss-fuzz + better harness mapping | open → iter 16 |

## Batch-4 synthesis — GAUNTLET COMPLETE 50/50 (28 findings; the hardest/largest batch)

domainCorrect fully-yes 7/13 (quickjs, zephyr, highway, nginx, libzmq, simdjson, jq); lane-level fixes (F1/R2/
R7/F4/R8) held broadly. But the hard repos exposed material gaps → these set the honest C6 down-rate (17→16,
primary accuracy across all 50 ≈ 80%) and the iter-18 fold-back G:

| ID | Freq/sev | Finding | Fix | Status |
|---|---|---|---|---|
| R10 | sqlite,redis,libjpeg,simdjson,duktape (HIGH) | EXCLUDE_GLOBS keeps missing vendored/generated/aux dirs: `jimsh0.c` amalgam + `*.txt` data tables (sqlite), `deps/` not `_deps/` (redis), `src/spng/`+`fuzz/*.cc` (libjpeg), `singleheader/`+`dependencies/` (simdjson), `misc/`/`dukweb/` (duktape) → wrong primaries + risk noise | broaden exclusion: `deps/`,`dependencies/`,`singleheader/`, codec `fuzz/*.cc`, repo amalgams; domain-detect skip `*.txt`/data tables | open → iter 18 (fold-back G) |
| R11 | Catch2 (HIGH, correctness) | vendored-framework globs `!**/catch2/**` (+gtest/unity/utest) exclude the repo's OWN source when the repo IS that framework → 3/4 gates scanned ~19 files of 289 | anchor globs to `**/{third_party,vendor,extern,_deps,tests}/**/catch2/**` (only embedded copies) | open → iter 18 |
| R12 | sqlite,redis (HIGH) | Databases pack lacks SQL/btree/pager/WAL/vdbe/server/RDB/AOF vocab → sqlite→Parser, redis→Networking (DB last) | enrich DB pack vocabulary | open → iter 18 |
| R13 | duktape (HIGH) | domain-detect scans `*.txt` data files + does not strip `#`-comments → Crypto wins off `UnicodeData.txt` "CYRILLIC LETTER SHA" + Makefile `# SHA1` | exclude data-table files from domain signal; strip `#`-comments in strip() | open → iter 18 |
| N-cmphang-2 | zephyr (CRITICAL) | `rel=$(printf '%s' "$files" | head -n1)` SIGPIPEs (exit 141) on a ~3500-path list under `set -euo pipefail` → comprehension dies, L2 lost | avoid head-on-pipe SIGPIPE (read first line without closing the pipe early) | open → iter 18 |
| R1-mixed | zephyr,redis,libjpeg (HIGH) | C++ signal is REPO-level; a mixed repo (or a vendored/fuzz `.cpp`) fires new/delete + span lanes on pure-C files → zephyr 9,436 span FPs + 35 new/delete FPs on C vars named `new`/`delete` | per-FILE language gating: fire C++ categories only on `.cc/.cpp/.cxx/.hpp` files | open → iter 18 |
| R6 | duktape,libjpeg,jq,nginx,nlohmann (recurring) | backlog fuzz-coverage blind to shipped harnesses + OSS-Fuzz/cifuzz; flags internal statics as parser entries; volume noise on big repos | resolve harness→API; detect cifuzz/oss-fuzz; cap/sample | open → iter 18 |
| N-castvol | nginx 1326, duktape 2066 (precision) | R7 fixed cast FALSE positives, but real casts are now HIGH VOLUME with no ranking (unactionable list) | stratify: narrowing/width-change/length-feeding casts above pointer-retype noise | open → iter 18 |
| N-exportprec | quickjs (goto-labels), highway (`for()`), libpng (`PNG_EXPORT` macro), redis (fn-ptr typedef) | comprehension export extractor leaks non-decls / misses more macro idioms | tighten: skip goto-labels/keywords; add `PNG_EXPORT`-style (name as 2nd macro arg) | open → iter 18 |

**Honest read:** across all 50 repos the domain detector gets the PRIMARY right ~80% of the time (excellent on
parser/crypto/compression/net/space/HPC/VM/audio/embedded; weak on DBs, test frameworks, SIMD-heavy codecs, and
some library-shapes). That is strong domain-agnostic coverage but not the "near-complete" 17/18 the easier
batches implied → C6 honestly re-rated 17→16. Lane-level FP discipline (comment/string/cast/C++-gating) is solid
on single-language repos but leaks on MIXED and vendored-heavy repos (R1-mixed, R10) → fold-back G targets exactly these.

## Fold-back protocol
After each batch, the highest-frequency / highest-severity findings become a dedicated improvement pass
(via /repeatedly-apply-skill on the most relevant sibling skill, or a direct scoped fix), each re-verified by the
validators + the script self-tests, then re-rate Q2 and the lifted design caps. Findings that recur across many
repos are higher priority than one-off observations.
