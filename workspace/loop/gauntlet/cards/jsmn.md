# jsmn @ 25647e6

- Repo: https://github.com/zserge/jsmn (minimal JSON parser, C, header-only)
- Domain pack: unknown-domain (see W1)
- Size: 6 source files (.c=3, .h=3); single public header jsmn.h
- Std: none pinned (header-only; consumer supplies CFLAGS). Makefile has no -std=.

## Gate results

### domain-detect
`unknown-domain: build a pack from references/UNKNOWN-DOMAIN.md`. Pack table covers
space/embedded/kernel/gpu/hpc/crypto/networking/compilers/databases/audio/filesystems.
There is no parser/serialization/text-format pack, so jsmn (a textbook parser) drops
through. Honest, not a misclassification, but a real coverage gap (W1).

### comprehension-map
Correct and useful. build=make|Makefile; flags compile_commands.json absent (true).
Lang breakdown right (.c=3 .h=3, no C++). Entry points: jsmn_init/jsmn_parse via
JSON_API hints in jsmn.h plus three main() (jsondump, simple, tests). Module map
(root/example/test) matches layout. No std reported — accurate, none is pinned.

### risk-scan (~14 hits, mostly benign)
- jsmn.h:456 "raw C++ new/delete" -> FALSE POSITIVE. Matched the word "new" in the
  comment "Creates a *new* parser". Pure C header, zero C++. (W2)
- example/jsondump.c:15 realloc -> SAFE. Inside realloc_it(), a checked wrapper that
  frees on NULL and returns NULL; the surrounding comment lines (8,12) also matched as
  noise (W3).
- jsondump.c:87 `malloc(sizeof(*tok) * tokcount)` -> real but low: example program,
  no overflow guard; tokcount from token count, small.
- testutil.h:78 `malloc(numtok * sizeof(jsmntok_t))` -> test helper, bounded numtok.
- test/tests.c:161 `memcpy(toklarge, toksmall, sizeof(toksmall))` -> SAFE. Both are
  jsmntok_t[10]; copy size == source size == dest size. memset 156/157 likewise safe.
- All other buckets (unsafe-str, casts, shell/exec, assert-only, threading): no matches
  — correct negative evidence for this codebase.

### backlog (sample)
- test-fuzz-coverage: ~30 hits flagging jsmn_parse + tests as "parser entry point with
  no fuzz harness". The library-API ones (jsmn.h:99/135/193/268/362/425) are the SIGNAL
  — jsmn is exactly the kind of code that wants a fuzzer. But it also flags every
  test/tests.c assertion line (test_* fns) as a "parser entry point" -> noise (W4).
- hardening: no _FORTIFY_SOURCE / CFI / sanitizer / stack-protector in build files.
  Defensible advice but partly N/A: jsmn is header-only with no build flags of its own;
  these belong to the consumer's build (W5).
- portability: ".travis.yml exercises one std/arch/compiler". Technically zero std is
  pinned, so "at most one std" is slightly mislabeled (W6).
- api-ergonomics: pointer+length pairs flagged for span/view — this is a C library; the
  span/view remedy is C++-only and not actionable here (W7).

## Observed skill weaknesses (W-list)
- W1: domain-detect has no parser/serialization pack; a pure JSON parser -> unknown-domain.
- W2: jsmn.h:456 — "new/delete" regex fires on the English word "new" in a comment in a
  C-only file. Should require `new`/`delete` as a C++ expression token (`new T`, `new[]`).
- W3: risk-scan emits comment lines as hits (jsondump.c:8,12 around realloc) — comment
  stripping absent; inflates the hit count.
- W4: backlog test-fuzz-coverage treats individual test-function bodies in test/tests.c
  as "parser entry points," flooding the list (~20 of ~30 hits are test internals).
- W5: hardening backlog recommends build-flag mitigations for a header-only library that
  ships no build of its own; advice is misdirected without a "header-only" caveat.
- W6: portability backlog says "at most one language standard" when in fact NO std is
  pinned anywhere — wording obscures the more useful finding (jsmn deliberately portable).
- W7: api-ergonomics span/view advice (C++) emitted against a C codebase (pointer+length
  is idiomatic C; no std::span available).

## Negative evidence preserved
- comprehension-map: clean, accurate, no crash. Correctly reported absent compile_commands
  and absent C++ (.cc/.cpp/.cxx/.hpp = 0).
- risk-scan: genuinely found NO unsafe string APIs, NO dubious casts, NO shell/exec, NO
  assert-only validation, NO threading. The one real-ish bucket (raw alloc) is all benign
  on inspection. The memcpy is provably bounded. No true memory-safety defect surfaced.
- All four scripts exited without error and produced output.

## Verdict
PARTIAL. comprehension-map is solid; risk-scan/backlog produce signal (fuzz gap on the
parser API is the real takeaway) but are noisy on this small C header: one hard false
positive (W2), comment-line noise (W3), test-body flooding (W4), and several C++-flavored
recommendations (W5/W7) that don't fit a header-only C library. Domain layer misses the
parser class entirely (W1). No actual bug found — appropriate for a mature, fuzzed library.
