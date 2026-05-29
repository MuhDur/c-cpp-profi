# sqlite — gauntlet card (final batch → 50/50)

- repo: https://github.com/sqlite/sqlite
- commit: 3d006d0d00cc79bb8cfb9dc63f2db2acb080ac82 (shallow, depth 1)
- expected pack: Databases / storage engines
- profile: SQL database engine in C; 316 .c / 42 .h, 0 C++ TUs. Ships a vendored
  Jim Tcl build amalgam (`autosetup/jimsh0.c`), Unicode data tables
  (`ext/fts3/unicode/*.txt`), and ~64 MB of binary fuzz seed corpora (`test/fuzzdata*.db`).

## Gate results

### domain-detect — PRIMARY WRONG (see regression check)
- pack[primary]: **Parser / text-format / serialization** | autosetup/jimsh0.c:23263 (214)
- pack[secondary]: Compilers/interpreters/VMs (211, jimsh0.c) · **Databases/storage (146)** ·
  Filesystems (136, UnicodeData.txt) · Crypto (98) · Space (32) · Compression/codec (23) ·
  Networking (19) · Generic (2056)
- Top hits for the 3 winners all land in non-library files: `autosetup/jimsh0.c` (vendored
  Jim Tcl interpreter — header literally says "bootstrap version of Jim Tcl") and
  `ext/fts3/unicode/UnicodeData.txt`/`CaseFolding.txt` (data tables counted as code matches).
- The TRUE storage-engine signal sits in shipped `src/`: pager.c 1459, btree.c 764,
  vdbe.c 232, wal.c 217 hits for btree/pager/wal/vdbe/journal/savepoint/pgno. Databases
  should be primary by a wide margin; the vendored amalgam + .txt tables outvote it. EXIT 0.

### comprehension-map — exits 0, surfaces exported API (GOOD)
- L1: autotools + make detected; lang breakdown .c=316/.h=42/.cpp=0; std hint -std=c99; no compile_commands (noted).
- L2 exported API: real public surface present — `sqlite3rbu_*` (17 fns, ext/rbu/sqlite3rbu.h),
  `sqlite3_expert_analyze`, `sqlite3Fts3Init`, `sqlite3Fts5AuxInit`, `sqlite3RtreeInit`,
  `sqlite3_intarray_*`; +1692 more (capped). Module map: src(149), ext(137), tool(36), test(34).
- L2 entries: LLVMFuzzerTestOneInput correctly tagged for dbfuzz2/fuzzcheck/ossfuzz/ossshell;
  `#if CMPP_MAIN` correctly flagged as conditional test driver (F5 holds). Many tool/ + test/ main()s listed.
- NIT: the +431 capped "exported-symbol hint" list is 100% `autosetup/jimsh0.c` lines (vendored amalgam noise);
  the real `sqlite3_*` API is what matters and it is surfaced.

### risk-scan — exits 0; lanes clean on real C (GOOD); vendored amalgam not excluded
- counts: unsafe-string 67 · raw-alloc 69 · new/delete SKIPPED (pure-C, correct) · casts 3735 ·
  memmove 1793 · process/shell 8 · assert-only 7869 · threading 24. EXIT 0 (F4 holds).
- triage of spot-read hits:
  - process/shell `src` real: `tool/sqlite3_rsync.c:308 execl(zCmd,...)` + `:310 execl("/bin/sh","-c",zCmd,0)`
    — genuine exec of a constructed command (TP, worth a note). Rest of lane is jimsh0.c (`system()`, `execvp`).
  - cast lane: every sampled hit is a real C-style cast WITH a value/expr after `(T*)`
    (`(void*)(_key_)`, `(char*)Jim_String(...)`, `(const unsigned char*)string`) — R7 holds, no
    prototype-param / sizeof FPs. But many are inside `assert( (void*)env==(void*)L ...)` → cast-in-assert noise.
  - unsafe-string `tool/pagesig.c:36/44 sprintf(zCksum+i*2,"%02x",...)` — bounded hex format into sized buf (likely safe; TP-needs-triage).
- jimsh0.c contributes 138 risk hits (vendored Jim Tcl amalgam) — should be excluded like generated/vendored amalgams.

### backlog — DID NOT COMPLETE (NEW weakness, see below)
- Foreground run `timeout 240` → EXIT 124 (timeout), ZERO stdout. Background runs wedged >2min each.
- Hang is in the fuzz-harness-corpus build (script line 488 `cat "$absf"`), spamming
  "ignored null byte in input" warnings. No backlog lanes were produced for this repo.

## REGRESSION CHECK (iter-15/16 fixes)
- domainCorrect = **no**. PRIMARY is Parser, driven by vendored `autosetup/jimsh0.c` + `ext/fts3/unicode/*.txt`.
  Databases only ranks #3. Same failure class as R8 (vendored/incidental file steals PRIMARY from true
  domain) and R3+ (vendored amalgam like `single_include/` should be excluded — `jimsh0.c` is not on the list).
  Databases is present as a secondary, so it is detected but mis-ranked.
- fixesHeld = **mostly**. Held: F1/R2 (no comment/prose/string FPs in sampled lanes), F4 (risk exit 0),
  R1 (pure-C → new/delete suppressed), R7 (cast lane needs value after `(T*)`; no proto/sizeof FPs),
  F5 (`#if CMPP_MAIN` tagged conditional; LLVMFuzzer entries tagged), comprehension exits 0 + surfaces
  the `sqlite3_*`/`sqlite3rbu_*` exported API. New Compression/codec pack fired (secondary, ext/misc/compress.c) — sane.
  NOT held: vendored amalgam (`jimsh0.c`) + data `.txt` tables are not excluded from domain-detect/risk-scan
  (R3+/R8 class), and backlog does not terminate (below).

## NEW weaknesses (not in F1-F7 / R1-R9)
- **N-blhang (CRITICAL, backlog non-termination on large binary fuzz corpora).** `cpp_backlog.sh`
  fuzz-coverage path globs `**/*fuzz*` (line 466), matching SQLite's binary seed corpora
  `test/fuzzdata*.db` (8 files, 64 MB total; largest 17 MB), then `cat`s each into a bash
  string variable with O(n²) concatenation (line 488) and null-byte stripping. The gate wedges
  (>240s, exit 124, zero output). Fix: cap per-file size, skip binary files (NUL probe / extension
  allowlist `.c/.cc/.cpp/.h`), and honor the test/ exclusion for the fuzz glob (these `.db` are seed
  data under test/, not harness source). Same brittleness *class* as F2/N-cmphang (a single
  pathological input aborts the whole gate) but a distinct mechanism (size/binary blowup, not a `||true` gap).
- **N-jimsh (MEDIUM, vendored build-amalgam not excluded).** `autosetup/jimsh0.c` (self-described
  "bootstrap version of Jim Tcl") is the single biggest contributor to domain-detect's wrong Parser/
  Compiler PRIMARY (214/211 matches), 138 risk hits, and 431 capped comprehension export-hints. It is a
  vendored interpreter amalgam shipped only to run the build, analogous to the `single_include/` case in
  R3+ but the exclusion list does not cover an `autosetup/`-vendored single-file amalgam. Also `ext/fts3/
  unicode/*.txt` data tables are counted as "code matches" by domain-detect (Filesystems/Crypto secondaries).

## Negative evidence (what did NOT misfire — preserve)
- No comment/prose/string/substring FPs in any sampled risk lane (F1/R2 hold).
- Cast lane has no prototype-param or sizeof FPs (R7 holds).
- C++-only new/delete lane correctly suppressed on this pure-C repo (R1 holds).
- comprehension exits 0 and DOES surface the exported `sqlite3_*` / `sqlite3rbu_*` C API (F5/R4 hold here).
- Compression/codec pack fired only as a low secondary (23, ext/misc/compress.c) — no over-fire.
- `#if CMPP_MAIN` main() correctly tagged conditional, not a real entry.

## Verdict
**PARTIAL.** Read-only gates ran and the iter-15/16 FP-suppression fixes (comments/strings/casts/
new-delete/C++-gating) all held on real C, and comprehension surfaced the true API. But two issues
keep it from PRODUCTIVE: (1) domain PRIMARY is wrong (Parser, not Databases) because a vendored Jim Tcl
amalgam + Unicode data tables outvote the genuine storage-engine signal in `src/`; (2) the backlog gate
does not terminate — it wedges on 64 MB of binary fuzz seed corpora. N-blhang is the headline NEW finding.
