# redis — gauntlet card (final batch → 50/50)

- repo: https://github.com/redis/redis
- commit: 65401042dc6105eac649dfc3b52eadb3fbb852a2
- domain (brief): in-memory DB/server (C). Expected pack: **Databases / storage engines**
- gates: READ-ONLY (no build). All four exit 0.
- shape: pure-C core in `src/` (471 .c, 310 .h) + bundled deps in **`deps/`** (jemalloc, lua, hiredis,
  linenoise, tre, xxhash, fpconv, hdr_histogram). Only shipped C++ TU is the **vendored** `deps/jemalloc/src/jemalloc_cpp.cpp`.

## Gate results

**domain-detect** — PRIMARY = **Networking / protocols** (343), then Parser (321), Crypto (165),
HPC (86), FS (69), Compilers (53), Compression (32), **Databases / storage engines (10, dead last)**,
Space (3); Generic 5479. WRONG primary, and the expected pack ranks last. Two distortions:
(1) the 343 anchors on `LICENSE.txt:1163` + bundled **hiredis** (the C *client* lib under `deps/`);
(2) the Databases pack is starved — see regression check.

**comprehension-map** — exits 0. L1 build graph fine (autotools/cmake/make; notes compile_commands absent).
L2 exported API (4130+, capped) is **dominated by vendored deps** — `XXH128_*` (xxhash), `lua*`/`luaL_*` (lua),
RedisModule_* (src/redismodule.h). Redis's own public surface (the `RedisModule_*` module API) is buried under
xxhash/lua noise. FP: `double()` / `float()` extracted as "function names" from the function-pointer-typedef idiom
`REDISMODULE_API double (*RedisModule_LoadDouble)(...)` (src/redismodule.h:1140,1268,1272…). Entry points correctly
tag conditional `#if *_TEST_MAIN` drivers + the hiredis fuzz harness.

**risk-scan** — exits 0. C++ signal = **yes** (raw new/delete enabled). 6599 hits total: **2297 from `deps/`**
(jemalloc/lua/linenoise/tre — NOT redis code), 4302 from `src/`. Top categories: unsafe-string, raw-alloc,
casts, memmove, assert-only, threading (pthread-heavy, legit for a threaded server).

  spot-triage (redis's own `src/`):
  - `src/sparsearray.c:202` `memcpy(dup, ptr, total)` — **SAFE**: `total=hdr_size+len`, dest `zmalloc(total)` sized to match.
  - `src/redis-cli.c:10555` `strncpy(total_length," - ",sizeof(total_length))` — **SAFE**: 3-byte literal into fixed buf, bounded.
  - `src/mstr.c:223` `(char*)str - mstrHdrSize(...)` — **SAFE**: sds-style header pointer-arith on opaque string; not a width/alias hazard.
  - `src/fmacros.h:46-48` `int sprintf(...) __attribute__((deprecated(...)))` — **FALSE POSITIVE**: these are redis's
    deliberate *deprecation poison prototypes* (the hardening that bans sprintf/strcpy/strcat), the OPPOSITE of misuse.

**backlog** — exits 0. Lanes flood from `deps/` (api-ergonomics span/owning-raw-malloc on vendored hiredis/jemalloc/xxhash).
Non-deps signal: `test-fuzz-coverage` flags ~every `src/*.c` parser/decoder entry (zipmap, t_zset, t_stream, listpack…)
as "no fuzz harness." Redis ships no in-tree libFuzzer harness; CI has codeql + coverity (no cifuzz/oss-fuzz workflow),
so the lane is technically right but very noisy. api-ergonomics span lane fires only because the vendored C++ tripped the C++ signal.

## REGRESSION CHECK (iter-15/16 fixes)

- **domainCorrect = no.** Databases / storage engines is dead-last (10) on an in-memory database. R9-vocab class,
  NOT yet fixed for this pack: redis's `src/` is saturated with database-engine vocabulary the pack ignores —
  **rdb=1132, aof=587, expire=380, fsync=81, keyspace=72, eviction=68, checkpoint=8**. The Databases pack lacks
  RDB-snapshot / AOF-WAL / expire / eviction / keyspace / fsync / durability tokens (the analog of the Net/Crypto/
  Compression enrichment that landed in iter-16; Databases was left thin). New Compression pack DID fire (secondary 32) —
  correct that it is not primary here (redis only LZF-compresses internally), so that iter-16 addition behaves.
- **fixesHeld = mostly.** F1 holds: comment/prose/string + C++-substring FPs are gone; `src/` hits are real tokens.
  F4 holds (risk exit 0). N-cmphang holds (comprehension exits 0 despite jemalloc's `-std=$(...)` configure noise).
  R7 cast-lane holds — no single-pointer-prototype / sizeof FPs in the cast sample (the `(char*)`/`(FirstSegHdr*)`
  hits are genuine value casts). BUT three holes surface (see new weaknesses): the bare `deps/` vendored dir is not
  excluded (R3/F7 class), the deprecation-poison prototype is a new unsafe-string FP class (F1 class), and the C++
  signal fires off a vendored dep's C++ TU (R1 class, new trigger).

## NEW weaknesses (not in F1-F7 / R1-R9)

1. **`deps/` vendored-dependency dir not excluded** (systemic, all 4 gates). Exclusion lists `_deps/`, `third_party/`,
   `vendor/`, `extern/` but NOT the bare `deps/` convention redis/git/php use for bundled libraries. 2297/6599 risk
   hits, the entire comprehension exported-API top, and the api-ergonomics flood all come from `deps/`; it also feeds
   the wrong domain primary (hiredis → Networking). F7/R3 covered test/bench/vendored-*test* dirs but not a project's
   vendored *runtime* deps under `deps/`. Fix: add `**/deps/**` to the shared exclusion glob.
2. **Deprecation-poison prototype FP** (risk-scan, unsafe-string lane). `src/fmacros.h:46-48` declares
   `int sprintf(...) __attribute__((deprecated(...)))` — a *declaration that bans* the function, flagged as a *use*.
   New FP class: a prototype/decl with `deprecated`/`__attribute__` and no call args should not count as an unsafe call.
3. **C++ signal fires off a vendored dep's shipped C++** (`deps/jemalloc/src/jemalloc_cpp.cpp`). R1's fix requires
   real C++ in non-test shipped dirs, but here the only shipped C++ is inside a *vendored dependency*; redis core is
   pure C. This re-enables new/delete + the span lane repo-wide. New trigger: shipped C++ that lives under `deps/`.
4. **Function-pointer-typedef return type mis-read as API name** (comprehension). `REDISMODULE_API double (*Name)(...)`
   surfaces `double()`/`float()` as exported functions (src/redismodule.h). New idiom for R4's export extractor.

## Negative evidence (preserved)

- All four gates exit 0 (no F4/N-cmphang abort regression; jemalloc's `-std=$(...)` and `-std=c++` configure noise
  did not crash comprehension).
- F1 holds: no comment/prose/string or C++-substring FPs; the `src/` risk hits are genuine code tokens.
- R7 holds: cast lane shows real value casts only, no single-pointer-prototype / `sizeof(T*)` FPs.
- Compression pack (iter-16) behaves: present as secondary (32), correctly NOT primary.
- The 3 spot-read `src/` risk hits triage to true negatives (bounded / benign sds idiom) — no missed defect found here.

## Verdict: **PARTIAL**

Gates run clean and the iter-15/16 comment/string/cast/exit fixes hold, but redis exposes a real classification miss:
the expected **Databases / storage engines** pack ranks LAST (10) on the canonical in-memory database because the pack
lacks RDB/AOF/expire/eviction/keyspace/fsync vocabulary (R9-vocab, Databases left un-enriched), and the **bare `deps/`
vendored dir is not excluded**, polluting every gate. Productive breadth find: two new fold-back items (deps/ exclusion,
deprecation-poison FP) plus a Databases-pack vocabulary gap.
