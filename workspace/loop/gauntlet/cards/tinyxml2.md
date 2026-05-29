# tinyxml2 @ 8224e42 — c-cpp-profi gauntlet card

- Repo: leethomason/tinyxml2 (XML parser/serializer, C++)
- Commit: 8224e42 ("Merge branch 'master'...")
- Domain pack: **unknown-domain** (MISS — see W1)
- Size: 4 source files (.cpp=3, .h=1); tinyxml2.cpp + tinyxml2.h are the library, xmltest.cpp + contrib/html5-printer.cpp are clients
- Std: cxx_std_11 (CMakeLists.txt:26)
- Build: cmake + make + meson; no compile_commands.json

## Gate results

### domain-detect
Output: `unknown-domain: build a pack from references/UNKNOWN-DOMAIN.md`. Wrong for a textbook XML parser. Script has zero xml/parser/serialization keywords (confirmed by grep) — no pack exists to match, so any parser library lands in the unknown bucket.

### comprehension-map
Accurate. Build systems all three detected; std hint correct; entry points correct (main() in xmltest.cpp:302 and contrib/html5-printer.cpp:93; public header tinyxml2.h flagged). Module map (root=3 files, contrib=1) is right. `.h=1` correct — only one header in repo. Solid gate on this repo.

### risk-scan (≈55 hits, intentionally noisy triage)
- tinyxml2.cpp:77,93 `#define TIXML_SSCANF sscanf` — TRUE: real unbounded sscanf wrapper (used for number parsing; reviewable but field-width-guarded in practice).
- xmltest.cpp:2742,2744 `strcpy` — FALSE POSITIVE. Buffer `xml` is sized exactly `sizeof(prefix)+NDIGITS+sizeof(suffix)` (line 2741); both strcpy + the memset are precisely bounded to fill it. Also a deliberate hex-entity-overflow regression test, not shippable code.
- tinyxml2.cpp:113 `CARRIAGE_RETURN`, tinyxml2.h:649/2222 ("gets deleted"/"gets in the way") — FALSE POSITIVES in the "unsafe string APIs" bucket: regex matched substrings `cr`/`gets` in a const name and English prose.
- tinyxml2.h:302 `memcpy(... sizeof(T)*_size)` — TRUE/benign: POD-only dynamic array growth, self-commented "only works for PODs".
- new/delete bucket: mostly placement-new into pool allocator + matched-pair new[]/delete[]. No leaks evident.

### backlog
- api-ergonomics tinyxml2.h:1988/300/370 "owning raw new in header" — PARTIAL FP. h:1988 is `new (pool.Alloc()) NodeType(this)` placement-new, pool-owned via `_memPool`, not a raw owning heap alloc; "RAII candidate" advice is off here. h:300/370 are the internal DynArray/MemPool growth (legitimately raw but deliberate, the library's own allocator).
- hardening: no _FORTIFY_SOURCE / CFI / sanitizer / stack-protector in build — TRUE (build files set none).
- test-fuzz-coverage: parser entry points (tinyxml2.cpp:798,2198; tinyxml2.h:1241) with no fuzz harness — TRUE. Confirmed `find -iname '*fuzz*'` empty. Real gap for an XML parser.

## Observed skill weaknesses (W-list)
- **W1 (domain miss):** cpp_domain_detect.sh returns `unknown-domain` for a canonical XML parser. Script contains no xml/parser/serialization keyword set — parser/serialization libraries are unclassifiable. file: cpp_domain_detect.sh (no matching pack).
- **W2 (risk-scan FP, bounded strcpy):** xmltest.cpp:2742/2744 flagged as unsafe strcpy though the dest buffer is statically sized to fit exactly (xmltest.cpp:2741). Surfaced in BOTH risk-scan and backlog/hardening — double-counted noise.
- **W3 (risk-scan FP, prose/identifier match):** "unsafe string APIs" bucket matched `CARRIAGE_RETURN` (tinyxml2.cpp:113) and the word "gets" in comments (tinyxml2.h:649,2222). Pure substring noise, no API involved.
- **W4 (backlog mislabel):** tinyxml2.h:1988 labeled "owning raw new/malloc ... RAII candidate" but it is placement-new into a pool allocator with explicit `_memPool` ownership — already RAII-managed; advice misleads.
- **W5 (risk-scan exit code):** cpp_risk_scan.sh exited 1 despite producing valid output (likely trailing grep no-match); a caller checking `$?` would treat a successful triage as failure.

## Negative evidence preserved
- comprehension-map: no errors, every field correct on this repo (build/std/entries/modules) — genuinely useful gate here.
- raw allocation (malloc/free), process/shell execution, threading buckets: "no matches" — correct, library uses new[]/placement-new only and is single-threaded by design.
- test-fuzz-coverage backlog item is a TRUE finding: no fuzz harness exists in-tree for the parser.
- hardening backlog items (no FORTIFY/CFI/sanitizer/stack-protector) are all TRUE for the shipped build files.

## Verdict
PRODUCTIVE. Comprehension-map and the fuzz/hardening backlog items are accurate and actionable. But domain classification failed outright (W1), and risk-scan/backlog carry real false-positive noise (W2–W4) plus a misleading exit code (W5) that a triager must read source to discount.
