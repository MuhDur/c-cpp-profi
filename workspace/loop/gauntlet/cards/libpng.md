# libpng — c-cpp-profi gauntlet card (final batch → 50/50)

- Repo: https://github.com/pnggroup/libpng — PNG reference codec (C89)
- Commit: 92c853c34e41570504baa48b8a8169e53b188324 (depth-1)
- Date: 2026-05-29 | gates: READ-ONLY (no build) | expected pack: Compression/codec or Parser
- Shape: 18 core `.c` + 7 core `.h` (png.c, pngr*/pngw* read/write, pngrutil/pngwutil chunk codec,
  pngmem, pngsimd) + per-arch SIMD (`arm/ intel/ mips/ powerpc/ loongarch/ riscv/`) + `contrib/` tools/viewers.
  zlib/DEFLATE wrapper codec; chunk parser (IHDR/IDAT/PLTE/tEXt…); NEON/SSE accel row filters.

## Gate results
- **Domain PRIMARY: HPC / SIMD / numerics (75)** @ arm/filter_neon_intrinsics.c:150.
  Secondaries: Databases(24), **Compression/codec(23)**, Networking(17), Parser(7), Generic(242). Exit 0.
  → The new Compression pack DID fire (secondary) but lost PRIMARY to SIMD-token density. See REGRESSION.
- **Comprehension: exit 0.** L1: autotools+cmake+make, .c=78/.h=23, std-hints c89/gnu11 (configure.ac).
  L2 API: surfaced contrib helpers (readpng_init/writepng_init/PngFile*) + **7 public headers (png.h,
  pngconf.h, pngpriv.h…) + 233+ export-macro hints @ png.h** (capped). Module map: root/arm/intel/mips/
  powerpc/loongarch/riscv/contrib. NB: named-API list shows contrib helpers, not `png_*` core API (see R4).
- **Risk scan: exit 0**, 655 lines. Hits: unsafe-fmt (sscanf/sprintf/strcpy, all contrib viewers),
  raw-alloc (malloc/free), casts (real C-casts), memmove (memset/memcpy), assert-only (~heavy pngfix.c),
  new/delete = **"skipped: no C++ signal (pure-C)"**, threading = none, exec = none. Core-lib 143 / contrib 443.
- **Backlog: exit 0.** 208 api-ergonomics (C ptr+len contract, correctly *not* span), 71 hardening
  (strcpy bounded-copy candidates), 5 portability (Y2038 time_t @ png.h:1002/pngwrite.c:531; CI 1-arch),
  4 test-fuzz-coverage (readpng2 decoder entry, no harness).

## Risk top hits WITH triage (spot-read at file:line)
- `pngmem.c:98` `return malloc((size_t)/*SAFE*/size); /* checked for truncation above */` — TP-flag /
  **already-audited**: dev `/*SAFE*/` annotation + prior truncation check; scanner correctly flags for review.
- `pngrutil.c:1336` `(png_byte *)keyword` cast — TP cast, real code (chunk-keyword read); not a decl-param/sizeof FP.
- `contrib/libtests/makepng.c:1600` `memcpy(bar, *line++, foo)` — TP, test-tool string concat into fixed `bar`.
- `contrib/gregbook/rpng-x.c:349` `sprintf(titlebar,"%s: ...%s",appname,filename+(...))` — TP unsafe-fmt (example viewer).
- All sampled hits are real source lines: **zero comment / prose / string-literal / cast FPs.**

## REGRESSION CHECK (iter-15/16)
- domainCorrect = **partial**. The repo's true domain is image **codec/compression**; Compression pack fired
  (23, secondary) — the iter-16 pack EXISTS and matched, which is the win. But PRIMARY went to HPC/SIMD on
  genuine NEON intrinsic density (`vld1q/vst1q/vaddq` in shipped `arm/*neon*.c`), not an FP — real code outvoted
  the codec. Defensible-but-wrong: libpng *wraps* zlib so bare `deflate/inflate` tokens are sparse vs the
  per-arch SIMD files.
- fixesHeld = **mostly**. F1/R1 (new/delete C++-suppression) HELD — "pure-C, skipped". F4/N-cmphang exit-0 HELD
  (all four gates exit 0). R7 cast lane HELD — casts carry values, no decl-param/sizeof FPs. F1/R2 comment+string
  strip HELD — 655 risk lines, no prose FPs across 5 sampled categories. F2/F5 comprehension surfaces public
  headers + export hints + exits 0. F3/W2 backlog correctly relabels ptr+len as C contract (no span on C). R6
  (oss-fuzz blindness) N/A here: this checkout ships **no fuzzer** (no contrib/oss-fuzz, no cifuzz.yml) so the
  "no harness" flag is CORRECT, not a regression.

## NEW weaknesses
1. **Compression pack lacks codec-WRAPPER + PNG vocabulary → SIMD density steals PRIMARY on a real codec.**
   libpng = zlib-wrapper codec; the pack's tokens (`deflate/inflate/zlib/crc32/huffman/LZ4_`) are sparse here,
   while shipped `arm/*neon*.c` SIMD intrinsics (75) outrank Compression (23). Core lib actually holds ~150
   compression-vocab hits in pngrutil.c/png.c + 35 `IDAT` + filter/unfilter row-codec tokens that the pack does
   NOT score. R9-vocab fixed *missing* packs / zlib-mis-primary; it did NOT cover (a) PNG-codec terms
   (IDAT/IHDR/zstream/png_inflate/scanline/unfilter/filter-row/palette/interlace) nor (b) a count tier so a
   shipped-accel SIMD file can't outvote the codec domain. Evidence: domain primary HPC@arm/filter_neon_intrinsics.c:150.
2. **R4-class macro shape not handled: `PNG_EXPORT(type, NAME, (args))`.** The real public API
   (`png_set_expand`, `png_convert_from_time_t`, ~233 decls) is declared with the name as the *2nd macro arg*;
   the named-API extractor surfaces only contrib plain-decl helpers, not one `png_*` symbol. R4 covered
   *prefix* macros (`LUA_API name`, `MA_API`); the *name-as-argument* form is a distinct unhandled idiom.
   (Incompleteness, not a break: export-macro hints @ png.h:1001+ still surface; gate exits 0.) Evidence: png.h:1001.

## Negative evidence (preserved)
- No comment/string/prose/substring FPs in any sampled risk category (F1/R2 hold).
- No C++ new/delete/span on this pure-C repo (F1/R1/W2 hold).
- No cast-lane decl-param / sizeof FPs (R7 holds).
- All four gates exit 0 (F4/N-cmphang hold).
- Compression pack present and matching (iter-16 R9-vocab pack confirmed live).
- "No fuzz harness" backlog flag is accurate — repo genuinely ships no fuzzer in this checkout.

## Verdict: PRODUCTIVE
Fixes broadly held; two real, actionable findings (codec-wrapper/PNG vocab + count tier; PNG_EXPORT arg-name
macro) both extend already-tracked open lanes (R9-vocab, R4) rather than contradicting a folded fix.
