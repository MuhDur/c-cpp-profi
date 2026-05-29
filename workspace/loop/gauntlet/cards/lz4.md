# lz4 — c-cpp-profi gauntlet card

- repo: https://github.com/lz4/lz4 @ `64e81c59de3971089c9a524db3eca174e1bbad49`
- size: 2.7M; 48 .c / 20 .h / 1 .cpp (`contrib/gen_manual/gen_manual.cpp`). Pure-C compression library + CLI.
- expected pack: Generic/compression  ·  detected primary: **Parser / text-format / serialization** (MISCLASSIFIED)

## Gate results (READ-ONLY, no build)

**domain-detect** (exit 0):
- primary: Parser / text-format / serialization | lib/lz4.c:1851 (7 code matches)
- secondary: Networking / protocols (3) ; Generic library / data-structures / strings | lib/lz4.c:1554 (130)
- The 130-match Generic signal is the real one; Parser won on 7 incidental hits.

**comprehension-map** (exit 0): build=cmake+make; std hints c90/c99/c11 + one c++17 (Makefile:214);
compile_commands absent (noted). Exported API surfaced cleanly — 179 public fns from `lib/*.h`
(`LZ4_compress_default` lz4.h:191, `LZ4_compress_HC` lz4hc.h:66, `LZ4F_compressFrame` lz4frame.h:225,
`XXH32_digest` xxhash.h:179), capped +139. Entry points: 12 `LLVMFuzzerTestOneInput` (ossfuzz/) +
main()s correctly tagged as program/example/test. Module map lib/ programs/ ossfuzz/ contrib/.

**risk-scan** (exit 0): C++ signal = yes; new/delete category = "no matches" (no FP). Top categories:
- unsafe-str: `strcpy`/`strcat` lz4cli.c:795-796 — TRIAGE: SAFE, dst is `calloc(1, strlen(input)+5)` (l.793) sized to source + extension; bounded by construction.
- casts: lz4.c:1401 `((sizeof(void*)==4) && ((uptrval)source > LZ4_DISTANCE_MAX))` — TRIAGE: SAFE, 32-bit pointer-width guard, not a width-truncating cast (no R7 FP).
- portability endian/packing: xxhash.c:166 `__attribute__((packed)) unalign` — TRIAGE: REAL idiom, guarded behind `XXH_FORCE_MEMORY_ACCESS==1` with a portable-memcpy fallback (l.171); load-bearing, correctly flagged.
- allocation/memmove: large but accurate lists across lib/ programs/ ossfuzz/.
- process/shell exec: no matches. threading: pthread/Win32 in programs/threadpool.c (correct).

**backlog** (exit 0): hardening (sprintf/strcpy/strcat migration, no FORTIFY/CFI/stack-protector in build);
portability (CI matrix 15 compilers/9 arch via .cirrus.yml — recognized); test-fuzz-coverage parser entries;
api-ergonomics span/string_view — fired only on ossfuzz/*.c fuzz harnesses (see NEW-2).

## REGRESSION CHECK

- **domainCorrect: no.** No dedicated compression pack exists; "compression" folds into Generic, which DID
  fire secondary at 130 matches — but primary went to Parser (7). Root cause: the parser token
  `[a-z0-9]+_decode\b` (domain_detect.sh:261) snags LZ4's pervasive `*_decode`/`decode_full_block` codec
  identifiers, and the **Generic-demotion rule (domain_detect.sh:366-374) has no ratio guard** — when the
  count-leader is Generic it unconditionally promotes the best specific pack (Parser@7) over Generic@130.
  An 18x-weaker incidental pack displaces the dominant real signal. (SPACE pack note: did NOT fire here — correct, no fprime/cFE tokens.)
- **fixesHeld: mostly.** F1 (comment/string/substring FP) held — spot-read strcpy@795, cast@1401, packed@166
  all real code, zero prose/comment/literal FPs in the triaged hits. R7 (cast lane) held — the `sizeof(void*)==4`
  guard is not read as a truncating cast. F5/R4 (exported API) held strongly — 179 clean `LZ4_*`/`LZ4F_*`/`XXH32_*`
  public decls, well past the macro/paren breakage of batch-2. F4 (exit 0) held on all four gates.

## NEW weaknesses (not in F1-F7 / R1-R7)

- **NEW-1 (domain-detect ranking):** Generic-demotion at domain_detect.sh:366-374 promotes a specific pack
  over Generic with NO count-ratio floor, so 7 parser-token hits beat 130 generic hits. Compounded by the
  parser `_decode` token matching codec (compress/decompress) identifiers. Fix: gate generic-demotion behind a
  ratio (e.g. specific*RATIO >= generic) AND add a Compression/codec pack (lz4/zstd/deflate/huffman/entropy/
  rANS/`*_decompress`/`*_compress`/blockSize/dictionary) so codecs stop landing in Parser.
- **NEW-2 (scope: contrib/ + ossfuzz/ not excluded):** EXCLUDE_GLOBS (risk_scan.sh:22-59, backlog.sh:56) omit
  `contrib/` and `ossfuzz/`. Effect: (a) the lone `contrib/gen_manual/gen_manual.cpp` doc-generator tool flips
  the whole-repo C++ signal to "yes" (harmless here — new/delete still 0 — but it would re-enable C++ categories
  on an otherwise pure-C lib); (b) backlog's span/string_view lane fires on every `ossfuzz/*` fuzz harness, and
  risk-scan lists ossfuzz malloc/memcpy as if library code. `programs/` (the shipped CLI) is defensible to keep.

## Negative evidence (preserved)

- new/delete: no matches (C++ signal yes via contrib tool, but library is pure C — no over-fire).
- process/shell execution: no matches (correct).
- Cast lane produced no R7-style FP; comment/string filter produced no F1-style FP on triaged hits.
- SPACE pack did not fire (correct — no flight-software tokens).

## Verdict: PRODUCTIVE

Breadth surfaced a real, generalizable misclassification (NEW-1: codec → Parser via unguarded generic-demotion +
`_decode` token) and a scope gap (NEW-2: contrib/+ossfuzz/). Batch-1/2 fixes (F1/F4/F5/R4/R7) held on the
triaged hits. domainCorrect=no is itself the highest-value finding of this run.
