# blake2 — c-cpp-profi gauntlet card

- **Repo**: https://github.com/BLAKE2/BLAKE2 @ `ed1974ea83433eba7b2d95c5dcd9ac33cb847913`
- **Domain**: crypto hash (C). **Expected pack**: Crypto.
- **Detected primary**: HPC / SIMD / numerics (575 matches). **Crypto = secondary only (10).**
- **Size**: 6.3M, 38 `.c` / 24 `.h`, 0 `.cpp` (pure C). Layout: `ref/` + ISA variants `sse/ neon/ power8/`, `b2sum/`, `bench/`, `csharp/`, `testvectors/`.

## Gate results
- **domain-detect**: primary `HPC / SIMD / numerics` @ neon/blake2b-neon.c:419 (575); secondary `Crypto` (10), `Networking` (4), `Generic` (64). exit 0. SPACE pack correctly absent.
- **comprehension-map**: 132 exported-API decls surfaced (capped at 40 shown) — `blake2b_init/init_key/init_param/update/final`, `blake2b`, `blake2bp*`, `blake2`, plus s/sp/xb/xs variants across all 4 ISA headers. Clean. 36 `main()` "entry points" listed — but most are `#if defined(BLAKE2*_SELFTEST)` test harnesses (e.g. ref/blake2b-ref.c:316), not shipped entries (only b2sum/b2sum.c:251 + bench/bench.c:90 are real).
- **risk-scan**: exit 0. C++ new/delete category **suppressed** (pure-C signal). Lanes: unsafe-string=0, casts=0, shell-exec=0, threading=0. ~8 malloc/free (b2sum), ~250 memcpy/memset (whole hash core ×5 ISA variants), 6 power8 alignment asserts.
  - **triage** `b2sum/b2sum.c:36` malloc: SAFE — `buffer_length` is a const 32768, null-checked @38, freed @76.
  - **triage** `ref/blake2b-ref.c:231/242` memcpy (update hot path): SAFE — `S->buf` is fixed 2×BLOCKBYTES; `left∈[0,BLOCKBYTES)`, `fill=BLOCKBYTES-left`, post-loop `inlen≤BLOCKBYTES` ⇒ `buflen+inlen≤2×BLOCKBYTES`. Bounded by construction.
  - **triage** `power8/blake2-impl.h:197-228` assert-only: accurate hit — alignment guards on internal vector loads, stripped under NDEBUG; invariant-not-input so low severity.
- **backlog**: 273 `api-ergonomics` (ptr+len contract — correctly **C-relabeled**, not span/view), 7 `portability` (endian/packing @ blake2.h:24 load-bearing little-endian assumption; `.travis.yml` single-standard CI). No false C++ lanes.

## REGRESSION CHECK
- **domainCorrect = partial.** Crypto fires only as *secondary*; primary is HPC/SIMD. Defensible-ish (the repo IS dominated by SIMD intrinsics) but wrong for a library whose entire identity is a hash. SPACE pack correctly does not fire.
- **fixesHeld = mostly.**
  - F1/R1 (C++ on pure-C): HELD — new/delete suppressed, no span/view in backlog.
  - F1/R2 (comment/string FPs): HELD — inline `/* Fill buffer */` on memcpy lines preserved without splitting; no prose hits.
  - F4 (risk-scan exit 1): HELD — exit 0.
  - F5 (comprehension exported API): exported C API **fully surfaced** (132 decls). BUT entry-point list still counts `#ifdef *_SELFTEST main()` as program entry (36 listed, ~34 are test harnesses) — F5 is OPEN (iter-11 pass C), so consistent, not a new regression.

## NEW weakness
- **Crypto pack is blind to hash-primitive / cipher vocabulary.** Pattern (cpp_domain_detect.sh:255) = `constant.time|secret-dependent|\bEVP_|crypto_[a-z]|explicit_bzero|memset_s|\bFIPS\b|test.vector` — all crypto-*engineering* signals, zero primitive names. A textbook hash lib scores 10 (incidental `test.vector`) while its SIMD impl scores 575 ⇒ misclassified HPC. Tokens present but uncounted: `blake2` ×867, `hash` ×90, `digest` ×18, `salt` ×26. **Fix**: add hash/cipher names to Crypto pack (`blake2|sha[0-9]?|sha3|keccak|md5|hmac|poly1305|chacha|\baes\b|\bgcm\b|digest|\bcipher\b|\bnonce\b`) and/or a domain-over-HPC tiebreak when SIMD intrinsics co-occur with crypto-name tokens (vectorized crypto is still Crypto). Sibling of R5's "generic/HPC raw count beats the real domain" but a distinct vocabulary gap.

## Negative evidence (preserved)
- No genuine missed defect. `keylen`/`outlen` bounds-checked (ref/blake2b-ref.c:126,282,286); update memcpy bounded; this is the audited reference impl.
- backlog C relabeling (W2) and risk-scan triage-context (W3) both functioning — no span noise, no unbounded-call FP.

## Verdict
**PRODUCTIVE.** Clone + 4 gates ran read-only, exit 0. Folded fixes (F1/F4/R1/R2 + C relabel) held. One concrete NEW finding: Crypto pack misses hash-primitive vocabulary → crypto-hash repo mis-primaried as HPC. domainCorrect=partial; fixesHeld=mostly.
