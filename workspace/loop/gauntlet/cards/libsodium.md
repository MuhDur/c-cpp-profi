# libsodium — c-cpp-profi gauntlet card

- **Repo:** jedisct1/libsodium @ `63b3003` ("Update for zig-current")
- **Expected pack:** Crypto. **Detected primary:** Crypto (4303 code matches) — MATCH.
- **Size:** 418 C/H files (245 .c, 173 .h), ~71k LOC. Pure C (0 .cc/.cpp/.cxx/.hpp). Build: autotools.
- **Date:** 2026-05-29. Read-only gates, no build.

## Gate results

**domain-detect** — primary `Crypto` @ aead_aegis128l.c:107 (4303). Secondaries, correctly ranked
by code-match count: HPC/SIMD/numerics (1554; legit — AVX2/SSSE3/NEON/AVX512 impls), Generic-library
(257), Filesystems (7), Parser/serialization (5). Ranking is sane; the two low-count tails are noise but
clearly de-prioritized. No misclassification off an incidental token.

**comprehension-map** — L1: autotools, `compile_commands.json` absent (flagged). L2 exported API:
surfaces the real public C surface — `argon2_hash`, `argon2id_verify`, `blake2b`, `crypto_aead_*`,
`crypto_sign_ed25519_*`, `_*_pick_best_implementation` — 900 decls (+860 capped). Entry points: 4 `main()`
all correctly under `test/`; exported-symbol hints (SODIUM_EXPORT) enumerated. Module map: src(310),
test(106), builds(2). Exported-API surfacing for a library WORKS (F5 fix held).

**risk-scan** — exit 0 (F4 held). C++ signal: **no** → new/delete category suppressed (F1 held).
Top categories: unchecked memory movement 295 (memcpy/memset/memmove), raw alloc 35 (malloc/free/calloc),
assert-only 33, casts 1, threading 2 (pthread_mutex in core.c). unsafe-string: none. shell-exec: none.
Triage of spot-checked hits:
  - utils.c:593 `return malloc(size > 0 ? size : 1U)` — REAL call, intentional 0→1 guard. TP-benign.
  - codecs.c:471 `memmove(endp-n, colonp, n)` — REAL call in IPv6 `::` compression; bounds derived from parse. TP, needs-context.
  - core.c:121 `pthread_mutex_lock(&_sodium_lock)` — REAL call, return checked. TP-benign.
  - argon2.h:47 `ARGON2_MIN(UINT32_C(32),(sizeof(void*)*CHAR_BIT-10-1))` — **FALSE POSITIVE** in "casts requiring review": no cast on the line; the lane matched the parenthesized `(sizeof... )` expr as a cast. See NEW weakness.
  No comment/prose/substring false positives in the alloc/mem/assert lanes (spot-read confirms all real calls).

**backlog** — exit 0. 441 lines. Lanes: api-ergonomics 315, test-fuzz-coverage 123, portability 2.
  - api-ergonomics correctly relabeled for C: "document the ptr+len ownership/bounds contract" (NOT span/view). W2 fix held.
  - portability lane is CI-aware: "CI matrix present (covers 6 compilers, 13 arches)" off `.github/workflows`. F3/F6 held.
  - test-fuzz-coverage fired 123× "parser/decoder entry point with no fuzz harness referencing it" — misleading; see NEW weakness.

## REGRESSION CHECK

- **domainCorrect = yes.** Primary `Crypto` with a decisive 4303-match lead; secondaries ranked, HPC/SIMD is a
  defensible second given the hand-vectorized impls. No one-token misfire (F2 held).
- **fixesHeld = yes.** (F1) C++ new/delete suppressed on pure-C, no comment/substring FPs in spot-reads.
  (F4) risk-scan exit 0. (F5) exported C API surfaced (argon2/blake2b/crypto_aead_*). (F2/W1) ranked single
  primary, no incidental-token misclassification. (W2) api-ergonomics gives the C ptr+len wording, not span.
  (F3/F6) backlog + portability see `.github/workflows`.

## NEW weaknesses (not in F1–F7)

- **N1 — casts-lane false positive on a parenthesized sizeof expression.** `cpp_risk_scan.sh` "casts requiring
  review" flagged `argon2.h:47`, which has NO cast — it matched `(sizeof(void *) * CHAR_BIT - 10 - 1)` inside the
  `ARGON2_MIN(...)` macro arg. The cast regex treats a leading `(type/sizeof-expr)` as a C cast. Low-frequency
  (1/repo here) but a genuine FP. Fix: require the parenthesized group to be a *type-name* (optionally `*`),
  not an arithmetic expression; exclude `(sizeof ...)` and `#define` lines.
- **N2 — test-fuzz-coverage blind to OSS-Fuzz / CIFuzz.** Backlog fired 123× "entry point with no fuzz harness
  referencing it", yet libsodium ships `.github/workflows/cifuzz.yml` running `google/oss-fuzz` build/run
  actions with `oss-fuzz-project-name: libsodium`. The library is continuously fuzzed; the in-tree harness
  greps for `*fuzz*.c` only and ignores OSS-Fuzz workflow integration. Refines F3: recognize `cifuzz.yml` /
  `oss-fuzz` / `LLVMFuzzerTestOneInput` references as fuzz coverage and downgrade/suppress the lane.

## Negative evidence (preserved)

- No genuine missed defect found on a fast read (unlike the klib aliasing bug). The 295 mem-movement hits are
  the expected crypto idiom (fixed-size buffers, `sizeof`-bounded); none looked like an over-read on spot-read.
- unsafe-string and shell-exec lanes correctly empty (libsodium uses no str(cpy|cat)/sprintf/system).
- HPC secondary is real, not a `-ffast-math`-flag artifact (F2's rg `-e` fix not re-triggered here).

## Verdict

**PRODUCTIVE.** All iter-10/11 fixes held on a large pure-C crypto library: correct primary pack, ranked
secondaries, exported API surfaced, C++ categories suppressed, exit 0, CI-aware backlog, C-flavored
api-ergonomics. Two new low-frequency refinements surfaced (N1 cast-expr FP, N2 OSS-Fuzz blindness).
