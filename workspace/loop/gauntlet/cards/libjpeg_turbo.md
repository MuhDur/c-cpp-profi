# libjpeg-turbo — c-cpp-profi gauntlet card (final batch → 50/50)

- repo: https://github.com/libjpeg-turbo/libjpeg-turbo
- commit: `afad69dafa6193d838ed075dc34652e646bf745e` (shallow, 2026-05-29)
- shape: JPEG/lossless codec + per-arch SIMD (NEON/AVX2/SSE2/AltiVec/MIPS), pure **C**; 11 OSS-Fuzz `.cc` harnesses in `fuzz/`; bundled libspng + zlib under `src/spng/`.
- expected pack: Compression/codec or Parser.

## Gate results (READ-ONLY, no build)

**domain-detect** (exit 0): PRIMARY = **HPC / SIMD / numerics** (2004 matches, simd/arm/aarch32/jccolext-neon.c:60). Secondary: **Compression/codec** (160, the R9-vocab pack — huffman/decompress/crc32/adler32/inflate), Parser (15), Crypto (13), Generic (151). SIMD wins primary because 84 of 321 source files live in `simd/` and carry the densest tokens — genuine for a "turbo" codec, but not the brief's headline.

**comprehension-map** (exit 0): build=cmake; no compile_commands.json. Lang: .c=271 .cc=11 .h=50 (.cpp=0). Exported API surfaced correctly — `jpeg_huff_decode`@jdhuff.h:247, `jsimd_color_convert`@jsimd.h:33, `jpeg_make_d_derived_tbl`, `jpeg12_read_scanlines`@jpeglib.h, plus 706 more capped. Entry points: all 11 `LLVMFuzzerTestOneInput` harnesses + tj* tool `main()`s correctly identified. Modules: fuzz/(11), simd/(84), src/(237).

**risk-scan** (exit 0): unsafe-API 39 (mostly bounded `sscanf`/`strncpy` in cjpeg/djpeg arg parsing — triage: arg-string parses, low sev), alloc 140, **new/delete 0**, casts 820, memmove 271, shell 0, assert 0, threads 0.
  - Triaged top hits: `src/djpeg.c:681 (unsigned char *)realloc(inbuffer, insize+INPUT_BUF_SIZE)` — real cast, grow-realloc, size is checked upstream → low. `simd/arm/aarch64/jccolext-neon.c:169 memcpy(tmp_buf, inptr, cols_remaining*RGB_PIXELSIZE)` — bounded by remaining-cols, tmp_buf is fixed SIMD tile → benign. `src/md5/md5.c:49 BYTE_ORDER==LITTLE_ENDIAN` (portability lane) — TRUE positive endian assumption.

**backlog** (exit 0): api-ergonomics span (~120, see regression), hardening (no FORTIFY/CFI/stack-protector in CMake defaults; strcat/strcpy@wrjpgcom.c:441/456), portability endian (md5.c:49, spng.c:81), test-fuzz-coverage (~110 "decoder entry, no fuzz harness" on jdarith/jdhuff/turbojpeg — see regression).

## REGRESSION CHECK (iter-15/16 fixes)

- **domainCorrect = partial.** R9-vocab Compression/codec pack EXISTS and FIRES (secondary, 160) — the fix landed. Primary is HPC/SIMD, defensible by file/token density but not the brief's "Compression/codec". Note: a slice of the 160 compression tokens (deflate/inflate/crc32/adler32) comes from the **vendored** `src/spng/zlib/`, so the codec signal is partly inflated by third-party code.
- **F1 / R1 = PARTIAL (regressed, NEW trigger).** Comment/string/substring filter holds — no prose FPs, no English-word `new`/`delete`. BUT `[scope] C++ signal: yes` fired on a pure-C library because `detect_cpp()` found the 11 `fuzz/*.cc` OSS-Fuzz harnesses (none match the `*test*.cc` suffix glob, and `fuzz/` is not in EXCLUDE_GLOBS). new/delete count happened to be 0, but the C++ **span** lane was enabled and proposed `std::span` across the whole C API (rdbmp.c, jpeglib.h, turbojpeg.h…) — the exact W2/F3 noise the C++-gate was meant to suppress. Same class as R1, new path: harness dir, not `test/`.
- **F4 = holds.** All four gates exit 0.
- **R7 cast lane = holds.** 820 cast hits, zero single-pointer-prototype / `sizeof(T*)` FPs (grep for bare `(Type *)` at line-end = 0). Every hit has a value/expr after the cast.
- **R8 case-sensitive distinctive tokens = holds.** No spurious SPACE/Compilers primary; SIMD + Compression are the real signals.
- **F5/R4 comprehension API = holds** (jpeg_*/jsimd_*/tj* surfaced via headers), though polluted by vendored `spng_*` symbols.

## NEW weaknesses (not in F1–F7 / R1–R9)

1. **`fuzz/` harness dir excluded from neither risk-scan nor domain-detect EXCLUDE_GLOBS.** 11 OSS-Fuzz `.cc` harnesses are scanned as "shipped library code" (45 risk hits from `fuzz/`) AND flip `detect_cpp()` to yes on a pure-C repo → re-enables C++ span/new-delete lanes (W2/F3/R1 class, new trigger). Fix: add `--glob '!**/fuzz/**'` + `!**/fuzzers/**` to both scripts' exclusion sets (or treat `fuzz/` as a known shipped-harness dir excluded from the C++ signal probe but mapped by the coverage lane — see #3).
2. **Vendored-under-`src/` blindspot: `src/spng/` (libspng, own LICENSE) + `src/spng/zlib/` (full bundled zlib).** Not under `third_party/`/`vendor/`, so EXCLUDE_GLOBS miss it: 232 risk hits, ~50 backlog span/coverage entries, dozens of `spng_*` "exported API" + `crc32.c`/`inftrees.c`/`md5/` `main()` entries, and part of the Compression domain signal all come from copied-in third-party code, not libjpeg-turbo. Fix: detect a bundled-license sibling (`*-LICENSE.txt`/`LICENSE` in a leaf src subdir) or add a `src/spng`-style known-vendor heuristic; at minimum exclude nested `**/zlib/**` libc-style trees.
3. **test-fuzz-coverage false-negative on a heavily-fuzzed codec (R6, still-open, confirmed here at scale).** Lane flags ~110 decoder entries (jdarith.c, jdhuff.c, turbojpeg.c, rdpng.c) as "no fuzz harness referencing it" — but the shipped `fuzz/decompress*.cc`/`transform.cc` harnesses reach all of them through the public `tj3Decompress`/libjpeg API (libjpeg-turbo is a flagship OSS-Fuzz project; `fuzz/build.sh` is the OSS-Fuzz contract). Lane can't trace call-graph reachability through the public API, so a thoroughly-fuzzed library reads as uncovered. Also mislabels static-inline SIMD IDCT helpers (`simd/arm/jidctint-neon.c:107` `jsimd_idct_islow_pass1_sparse`) as "decoder entry points".

## Negative evidence (preserved)

- No comment/string/substring FPs (F1 strip holds). No `-ffast-math`/`-std=$(...)` gate abort (F2/N-cmphang holds). No cast-lane prototype FPs (R7 holds). No spurious case-folded primary (R8 holds). All gates exit 0 (F4 holds). HPC primary is NOT a token-substring artifact — it is real, dense SIMD source.

## Verdict: PRODUCTIVE

Breadth + regression value: confirmed R7/R8/F4/N-cmphang/comment-strip + the R9 Compression pack all hold; surfaced one fresh recurring class (harness/vendored-under-src dirs not excluded → C++-signal + scope pollution) and reconfirmed R6 at scale on the canonical heavily-fuzzed codec. domainCorrect partial (right pack present as secondary; SIMD legitimately primary).
