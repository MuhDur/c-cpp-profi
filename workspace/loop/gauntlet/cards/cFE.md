# cFE — gauntlet card

- **Repo:** nasa/cFE (core Flight Executive) @ `e21a83b524ec670836136753441e4a3a28e0ecb3`
- **Expected pack:** Space / satellites — **Detected primary:** Space / satellites ✓
- **Size:** 12M, 500 C/C++ files (.c=208 .h=292; .cpp/.cc/.cxx=0 → pure C, C99)
- **Gates:** all four read-only gates exited 0 (no build).

## Gate results

**domain-detect** — primary `Space / satellites | CMakeLists.txt:128 (24806 code matches)`;
secondary `Generic library / data-structures / strings (169)`. The SPACE pack fires decisively
(24806 vs 169) — same family as fprime. Correct and well-ranked.

**comprehension-map** — build: cmake + make; `compile_commands.json` absent (noted). Lang
breakdown correct (pure C). Exported API: surfaces the public `CFE_*` surface from
`modules/core_api/fsw/inc/*.h` (e.g. `CFE_EVS_Register` @cfe_evs.h:105, `CFE_ES_AppID_ToIndex`
@cfe_es.h:87, `CFE_MSG_GenerateChecksum`@cfe_msg.h:511) — 40 in-band + "+1123 more (capped)" =
1163 total. Entry points + 2-module map (cmake/, modules/491) present.

**risk-scan** — 689 hits, C++ signal `no` → new/delete category correctly suppressed; process/shell,
assert-only, threading all "no matches". Breakdown: unsafe-string 164, casts 5, unchecked-mem(memcpy/
memset/memmove) 520. Top hits triaged:
  - `cfe_assert_init.c:73` `strcpy(&...LogFileTemp[NameLen], ".tmp")` — **SAFE (true-shape/triaged-clear):**
    preceding `if (NameLen > sizeof(..)-5) NameLen = sizeof(..)-5;` clamp guarantees room. Real code, not prose.
  - `cfe_es_api.c:235/829/873` `strncpy(...sizeof(..)-1)` — bounded copies, real fsw, low concern.
  - casts `(uint8 *)TblPtr`@cfe_tbl_handlers.c:63 — genuine cast (TP, in test stub).

**backlog** — api-ergonomics correctly relabeled "C: document ptr+len ownership/bounds contract"
(no C++ span on pure C). hardening (no FORTIFY/stack-protector/CFI in build files), portability
(single arch/compiler in CI; Y2038 time_t @cfe_time_api.c:579), test-fuzz-coverage lane large.

## REGRESSION CHECK (iter-12/13 fixes)

- **domainCorrect: yes.** SPACE pack fires as primary for cFE (parallels fprime), 24806:169 margin. R5 count-floor / domain-over-generic tiebreak holds.
- **F1/R2 (comment/string/substring FP):** HOLD. Zero unsafe-string hits inside `//`,`/* */`, or string literals; all spot-reads were genuine calls.
- **R1 (C++ on pure-C):** HOLD. C++ signal `no`; new/delete category emits "skipped: no C++ signal"; cast lane fired only on real casts/expressions, not C++ constructs. W2/F3 span gating holds (0 span suggestions).
- **R4/F5 (exported macro-wrapped API):** HOLD. The `CFE_*` public API surfaces from `core_api/fsw/inc/` headers despite NASA's macro/typedef-heavy style.
- **R7 (cast lane `sizeof(T *)` FP):** STILL OPEN (as documented). 3 of 5 cast hits are FPs: `ut_support.c:247` (`memcpy(...,sizeof(void *))`), `sb_UT.c:268` (`= sizeof(void *)`), `cfe_sb_api.c:163` (`sizeof(CFE_SB_BufferD_t *)` arg) — the `(T *)` inside `sizeof` is misread as a cast. Not a regression; confirms R7 not yet folded.

**fixesHeld: mostly** — F1/R1/R2/R4/R5 + W2 all hold; R7 cast FP confirmed still open (already tracked).

## NEW weakness (not in F1-F7/R1-R7)

- **N1 — exclusion blind to NASA test-dir convention `ut-coverage/` and `ut-stubs/`.** 533 of 689
  risk-scan hits (77%) live in `modules/*/ut-coverage/` (unit-test coverage drivers) and
  `modules/*/ut-stubs/` (test doubles) — verified test-only code. The scope banner excludes
  `tests/ test/ testing/ bench*/ extras/` and suffix `*_test.*`, but **not** `ut-coverage/`/`ut-stubs/`,
  so they flood every lane (e.g. unsafe-string: 117 of 164 hits are test; only 41 are real `fsw/`).
  This is a path-naming variant of F7/R3 — the dir-name allowlist needs `ut-coverage`, `ut-stubs`
  (and likely `*-coverage/`, `ut/`). Backlog inherits the same leak (test-fuzz-coverage lists
  `es_UT.c`, `fs_UT.c`, `tbl_ut_*` as uncovered parsers).

## Negative evidence (preserved)

- No comment/string/substring FPs in unsafe-string lane.
- No C++ categories fired (correctly gated on pure-C).
- No process/shell, assert-only, or threading hits — accurate for this corpus.
- Exported public API was NOT dropped (the R4/F5 failure mode did not recur).
- R7 is the only stale-fix-shaped item and it was already open, not a backslide.

## Verdict: PRODUCTIVE

Correct domain, real API surfaced, FP-clean on the folded lanes; surfaced one genuine NEW finding
(N1: `ut-coverage/`/`ut-stubs/` exclusion gap, 77% of hits are test code) plus reconfirmed R7 open.
