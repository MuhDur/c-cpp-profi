# sds (antirez) — c-cpp-profi gauntlet card

- Repo: github.com/antirez/sds @ 5347739 (Merge PR #153)
- Domain pack (reported): Networking/protocols + Filesystems/block storage — BOTH WRONG (see W1)
- Actual domain: in-memory dynamic string library (C)
- Size: 112K, sds.c=1328 LOC, sds.h=274 LOC, 1 .c + 3 .h
- Build: make (Makefile); std: -std=c99 -pedantic -O2 (single TU)

## Gate results

### domain-detect
- `pack: Networking / protocols | sds.h:47` — FALSE POSITIVE. Matched `__attribute__((__packed__))` on struct sdshdr5 (header byte-layout packing), not protocol packing.
- `pack: Filesystems / block storage | sds.c:324` — FALSE POSITIVE. Matched "block"/"kernel" inside a doc comment ("cat bytes coming from the kernel ... without copying into an intermediate buffer"). No FS/block code exists.

### comprehension-map (accurate)
- build=make, no compile_commands.json (flagged), std hint c99 from Makefile:4 — all correct.
- entry: main() sds.c:1325 (this is the `#ifdef SDS_TEST_MAIN` test driver, not a real program — minor mislabel, W4).
- API headers sds.h / sdsalloc.h / testhelp.h correctly surfaced. Module map trivial (1 root module). Solid.

### risk-scan top hits (~55 total, almost all noise)
- `sds.c:533,601` unsafe string/format API — FALSE POSITIVE x2. 533 matched "gets" in prose ("gets va_list"); 601 matched "sprintf()" in a comment that explains code does NOT use it. Real code uses vsnprintf (sds.c:553). Zero unsafe-string calls in repo.
- `raw C++ new/delete` 12 hits (sds.c:76,153,255,...) — ALL FALSE POSITIVE. Pure-C repo; every hit is the English word "new" in comments. C++ category fired on a C file.
- `sds.c:273` raw realloc — comment match ("we just realloc()"); real s_realloc calls are wrapped allocator macros. Benign.
- casts sds.c:1063,1069 — TRUE but benign: `s_realloc(vector,(n+1)*sizeof(char*))` / `s_malloc(sizeof(void*))`, idiomatic bounded sizing.
- memcpy/memmove/memset ~13 hits — verified bounded. e.g. sds.c:240 copies len+1 into a buffer sized hdrlen+newlen+1 (newlen>=len). No overflow.
- memcmp ~20 hits — ALL inside `#ifdef SDS_TEST_MAIN` self-test asserts (sds.c:1151-1313), not library code. Triage: test-only noise.
- assert hits sds.c:230,341,348,354,360,366 — REAL and GOOD: 230 is an explicit size_t-overflow guard; others guard sdsIncrLen bounds. Skill flags as "assert-only validation" but these are deliberate invariant checks, not a substitute for runtime checks.

### backlog sample
- api-ergonomics: 19 "pointer+length pair, no span/view" hits — C++ advice (std::span) on a C99 lib that cannot use it. Category noise (W3). The (ptr,len) pairs ARE sds's whole point and are length-safe via the header.
- hardening: no _FORTIFY_SOURCE / stack-protector / CFI / sanitizer — FAIR (Makefile is minimal -O2).
- portability: no CI matrix, single std — FAIR observation.
- hardening sds.c:601 sprintf migration candidate — FALSE POSITIVE (same comment as risk-scan).

## Observed skill weaknesses (W-list)
- W1 (domain-detect, sds.h:47 & sds.c:324): keyword matcher classifies a string lib as Networking + Filesystems off `__packed__` and "block"/"kernel" in comments. Both packs wrong; no "String/text/data-structure" pack offered.
- W2 (risk-scan, sds.c:533,601 + all 12 new/delete + sds.c:273): no comment-stripping. Vast majority of hits are prose/comments or test-harness code. Real unsafe-API count is 0 but scan implies otherwise.
- W3 (backlog api-ergonomics + new/delete category): C++-specific advice (std::span, new/delete) emitted against a strict-C99 codebase that cannot adopt it.
- W4 (comprehension, sds.c:1325): labels the `#ifdef SDS_TEST_MAIN` test driver as the program "main() entry" with no note it is conditional/test-only.

## Negative evidence preserved
- risk-scan found ZERO real unsafe string calls (no strcpy/strcat/sprintf/gets in code); vsnprintf is used correctly.
- No process/shell execution, no threading primitives — correctly reported "no matches" (true).
- memcpy/memmove sites verified bounded; no real buffer-overflow found.
- assert at sds.c:230 is a legitimate overflow guard — a genuine quality signal, not a defect.
- comprehension-map build/std/API detection was fully correct.

## Verdict
PARTIAL. Comprehension-map and the hardening/portability backlog items are accurate and useful. But on this small pure-C string lib the value is swamped: domain-detect is 2/2 wrong, risk-scan is dominated by comment and test-harness false positives (0 real unsafe calls), and backlog pushes C++-only advice. Read-the-file triage was required to clear nearly every flag.
