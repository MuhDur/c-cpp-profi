# picohttpparser @ f4d94b4

- Repo: https://github.com/h2o/picohttpparser (HTTP request/response + chunked-decoder parser, C)
- Domain pack: **unknown-domain** (detector miss; see W1)
- Size: 5 source files (.c=3, .h=1) + picotest submodule (empty, not fetched); ~28KB parser core
- Std: C (no explicit -std; Makefile uses gcc/clang defaults). Build: `make`, ASan+UBSan test build.

## Gate results

### domain-detect
Returned `unknown-domain: build a pack from references/UNKNOWN-DOMAIN.md`. For a textbook
HTTP-parser / network-protocol codebase this is a clear classification miss (W1).

### comprehension-map
Accurate. build=make|Makefile; flags `compile_commands.json absent`; lang breakdown correct
(.c=3,.h=1, zero C++). Entry points right: bench.c:47 main, test.c:518 main, picohttpparser.h
public header. Module map collapses everything to "(root) module (4 source files)" — fine for a
flat repo.

### risk-scan (26 file:line hits, whole-repo triage)
- picohttpparser.h:42 "raw C++ new/delete expressions" -> **FALSE POSITIVE** (W2). Matched the
  word "new" in the prose comment "a new commit is pushed". Pure C header, no new/delete.
- test.c:350 `strcpy(buf+bytes_ready, encoded+...)` -> **bounded/safe, test-only**. buf is
  malloc(strlen(encoded)+1) at test.c:332; copies a suffix of encoded. Not production.
- test.c:491/499 strcpy of literals "\r\n","0\r\n\r\n" -> bounded, test-only. Noise.
- picohttpparser.c:625/632/689 memmove -> **correct**. In-place chunk compaction, all guarded
  by `if (dst != src)`, length bounded by avail=bufsz-src / bytes_left_in_chunk. Not a bug.
- malloc/free at test.c:326/332/365/399 -> test fixtures. Noise.
- assert at picohttpparser.c:681 `assert(!"decoder is corrupt")` on a default state switch =
  legitimate invariant; bench.c:62 assert is bench-only. assert-only bucket = expected noise.
- No real production memory-safety defect surfaced; the parser core is clean (true negative).

### backlog (sample)
- api-ergonomics: 12x "pointer+length param pair with no span/view" on picohttpparser.h/.c —
  C-idiomatic, no std::span in C. **C++-flavored advice on a C repo** (W3); not actionable.
- test-fuzz-coverage: ~22 "parser/decoder entry point with no fuzz harness". Real underlying
  gap (no fuzz harness confirmed: grep found none), BUT most flagged lines are test.c helper
  funcs (test.c:60/177/276/...) misclassified as "entry points" (W4). Only picohttpparser.c
  401/474/500/545/700 are true public entry points.
- hardening: "no stack-protector / no -D_FORTIFY_SOURCE / no CFI" — literally true, but the
  Makefile:28 ships `-fsanitize=address,undefined` + UBSan halt_on_error; backlog gives no
  credit for the sanitizer posture (W5, framing gap).
- portability: "no CI matrix detected" -> **FALSE** (W6). .github/workflows/ci.yml has a
  gcc+clang matrix. Tool only inspects build files, misses GH Actions matrix.

## Observed skill weaknesses (W-list)
- **W1** domain-detect: HTTP-parser repo classified `unknown-domain`. Misses an obvious
  network-protocol/parser domain — no keyword match on "http", "parser", "phr_*".
- **W2** risk-scan FALSE POSITIVE: picohttpparser.h:42 "raw C++ new/delete" matched the English
  word "new" in a comment. No tokenization / comment-stripping; C++ check fires on a C file.
- **W3** backlog noise: 12 api-ergonomics span/view hits are C++-only advice on a pure C TU
  (picohttpparser.h:58-66, .c:105-500). No std::span exists in C; non-actionable.
- **W4** backlog misclassification: test.c helper functions (test.c:60,177,276,314,...) labeled
  "parser/decoder entry point" inflating the fuzz-coverage list with test code.
- **W5** backlog framing gap: hardening bucket reports missing FORTIFY/stack-protector/CFI but
  ignores the present ASan+UBSan in Makefile:28 — overstates the hardening deficit.
- **W6** backlog FALSE: "no CI matrix detected" while ci.yml runs a gcc+clang matrix; gate reads
  only build files, blind to .github/workflows.

## Negative evidence preserved
- risk-scan found NO real production memory-safety bug. The 3 picohttpparser.c memmoves verified
  correct; strcpys are test-only and bounded. casts/shell-exec/threading buckets all "no matches"
  (correct — none exist).
- comprehension-map is fully accurate (build system, lang counts, entry points, header).
- The fuzz-harness gap is a TRUE finding (no fuzz harness in repo) — valid signal under the noise.

## Verdict
PRODUCTIVE-with-caveats. comprehension-map is solid; risk/backlog surface one genuine gap
(no fuzz harness) but carry 6 concrete weaknesses: a hard FALSE POSITIVE (W2), a FALSE backlog
claim (W6), C++ advice on C code (W3), test-code misclassification (W4), a framing miss (W5),
and a domain whiff (W1). Net: usable triage, but a reviewer must hand-filter ~70% of hits.
