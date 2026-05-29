# uthash @ 5ada598

- Repo: https://github.com/troydhanson/uthash (hash-table / list / array macros, C)
- Domain pack (detected): Crypto + Audio/DSP/real-time media  -- BOTH WRONG (see W1)
- Size: 111 .c, 7 .h, 1 .cpp (test only). src/ = 6 header-only macro libs; tests/ = 113 files.
- Std: c89 (tests/Makefile:24), c99 (tests/lru_cache/Makefile:3). Library headers themselves target C89.
- Build: make (doc/Makefile). No compile_commands.json.

## Gate results

### domain-detect
- `pack: Crypto | doc/userguide.txt:1451` and `pack: Audio/DSP/real-time media | doc/ChangeLog.txt:40`.
- Both false. No crypto, no audio. Header-only hash/list/array container macros. Verdict: misclassified (W1).

### comprehension-map
- Correct: build=make, std hints, .c/.h breakdown, module map (src/ 6 files, tests/ 113), compile_commands absent.
- WRONG: lists `src/utlist.h:50` and `src/utstack.h:42` as `main() program entry`. Both are `int main()`
  inside `/* */` doc-comment usage examples in headers, not real entry points (W2). Verified by read.

### risk-scan (~460 hits; intentionally noisy whole-repo triage)
Per category: raw alloc 181, assert-only 155, unchecked memmove 50, C++ new/delete 35, unsafe string 32, casts 7.
- `raw C++ new/delete x35` -- ALL FALSE: every hit is the comment word "delete" in uthash.h
  (e.g. `/* delete "delptr" from the hash table.`). Repo has zero C++ new/delete (W3). Triage: drop all.
- `unsafe string strcpy: src/utarray.h:245` -- the ONLY library-source strcpy; dst is `malloc(strlen(src)+1)`
  with OOM guard at :241-243. Provably bounded. Triage: safe, no action (W4).
- remaining 31 strcpy hits are all in tests/ (test fixtures copying fixed literals into sized fields). Triage: low.
- raw alloc 181 / unchecked memmove 50: expected for a container lib + 113 test programs. Triage: noise, not bugs.
- assert-only 155: nearly all in tests/test86.c etc -- asserts ARE the test oracle here, not validation gaps.
- `process or shell execution: no matches` -- correct negative.

### backlog (sample)
- `api-ergonomics | owning raw new/malloc in a header ... | src/uthash.h:818` -- uthash.h:818 is a COMMENT
  ("In fractions this is just n/b"); no malloc there. Stale/misattributed line (W5).
- `hardening | malloc with a multiply in size arg | tests/example.c:20` etc -- overflow-guard advice aimed at
  test fixtures, low value on a header-only lib whose alloc hooks are user-overridable (uthash_malloc).
- `hardening | no sanitizer preset / no CFI in build files` -- fair generic gap.
- `portability | only one architecture in CI | .travis.yml` -- fair.

## Observed skill weaknesses (W-list)
- W1: domain-detect misclassifies a pure container lib as Crypto (matched "ideal%" hash metric,
  userguide.txt:1451) AND Audio/DSP (matched "utringbuffer" data-structure name, ChangeLog.txt:40).
  No "generic / data-structure library" pack offered; keyword match has no context guard.
- W2: comprehension-map reports `main()` in doc-comment examples as real program entry points
  (src/utlist.h:50, src/utstack.h:42). Grep does not strip C comments.
- W3: risk-scan "raw C++ new/delete" fires on the English word "delete" in comments -- 35/35 false on
  this repo (all uthash.h HASH_DEL doc text). Category is unusable without a token/comment filter on C code.
- W4: hardening flags the one bounded, OOM-guarded strcpy (utarray.h:245) as a migration candidate --
  technically harmless but it is the safest possible usage; pure noise.
- W5: backlog points at uthash.h:818 for "owning raw new/malloc in a header" but that line is a comment
  with no allocation -- line attribution is off (likely matched a nearby line / multi-line construct).

## Negative evidence preserved
- "process or shell execution: no matches" -- TRUE negative, no system()/exec/popen in repo. Good.
- comprehension-map L1 (build system, std hints, language breakdown, module map) is all ACCURATE.
- The single real library strcpy (utarray.h:245) is genuinely safe -- gate raised no TRUE positive bug.
- No threading-primitive false drama beyond tests/threads/* which legitimately use threads.

## Verdict
PARTIAL. Comprehension-map L1 is solid and the shell-exec negative is correct, but on this C
header-only container lib the skill's domain classification is fully wrong (W1), and its grep-based
risk/backlog gates produce structural false positives: comment-word "delete" as C++ delete (W3),
doc-comment main() as entry points (W2), a provably-safe strcpy flagged (W4), and a comment line
attributed as an allocation (W5). Useful as triage scaffolding, but every flagged "finding" here
required manual read to discard. Zero true positives surfaced.
