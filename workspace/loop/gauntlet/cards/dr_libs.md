# dr_libs @ 47a4f08

- **Repo**: github.com/mackron/dr_libs (single-header audio decoders: FLAC/WAV/MP3, C)
- **Domain pack**: unknown-domain (detect FAILED to classify — see W1)
- **Size**: 1.7M; 3 public headers total ~27.2k LOC (dr_flac.h 12.7k, dr_wav.h 9.1k, dr_mp3.h 5.4k); 13 .c + 4 .cpp test files
- **Std**: CMake; no default std set. Only `-std=c89` exists behind opt-in `DR_LIBS_FORCE_C89` (OFF) option.

## Gate results

**domain-detect**: `unknown-domain`. Wrong/missing — this is canonical media-codec/parser attack-surface code; no audio/parser pack exists.

**comprehension**: Mostly correct. build=cmake, no compile_commands (true), lang breakdown accurate. Entry points: LLVMFuzzerTestOneInput at tests/flac/flac_fuzz.c:57 (correct), 9 main()s in tests/, 3 public headers. Module map collapses everything to "(root) 3 files" + "tests 17 files" — coarse but honest for a single-header lib. The 300+ "exported-symbol hint" lines on dr_flac.h/dr_mp3.h/dr_wav.h are pure noise (every API macro line dumped, unbudgeted).

**risk-scan**: 127 hits. Top triage:
- `tests/common/dr_common.c:712 vsprintf` — TRUE hit, but bounded: guarded by `width<=0` and `width>sizeof(buffer)` checks at 700-705, and vsprintf is the pre-C99 fallback (vsnprintf used otherwise). Low severity, test-only.
- `dr_*.h MALLOC/REALLOC/FREE/COPY_MEMORY` macro defs (~20 hits) — definitions of the lib's overridable allocator/memory macros, not call sites. Noise.
- `dr_flac.h:28`, `dr_wav.h:28` `malloc(... * channels * sizeof)` — these are in DOC-COMMENT usage examples, not library code. False-positive context.
- "raw C++ new/delete" section: every hit is the English word "new" in prose/changelog comments (e.g. dr_flac.h:7643 "a new frame"). 100% false positive — grep matched the word, no `new` expressions exist (lib is C).
- "process or shell execution" section: every hit is prose ("operating system", "framing system", "memory allocation routines"). 100% false positive — matched "system" substring; no system()/exec calls.
- `tests/flac/flac_fuzz.c:39,64 memcpy` — bounded by MIN()/clamp at :37 and `<4096?` at :64. Benign.
- casts / threading sections: "no matches" (correct — single-threaded lib).

**backlog sample**: dominated by `test-fuzz-coverage | parser/decoder entry point with no fuzz harness` — ~250 lines, one per exported decoder symbol across all 3 headers. Directionally fair (only FLAC has a fuzzer; WAV/MP3 have none) but wildly over-emitted. Plus api-ergonomics "pointer+length pair with no span/view" (C lib, span advice is C++-only — see W4), hardening "no FORTIFY/CFI/stack-protector" (true, it's a header lib with no build hardening), portability "no CI matrix".

## Observed skill weaknesses (W-list)

- **W1 (domain-detect miss)**: classifies a flagship audio codec/parser library as `unknown-domain`. No media/codec/file-format-parser pack; the single most security-relevant signal (untrusted-input parsers) is unrecognized.
- **W2 (risk-scan word-grep false positives)**: "raw C++ new/delete" and "process or shell execution" sections match the English words "new" and "system" in comments/changelogs. Every hit in both sections on this repo is a false positive (e.g. dr_flac.h:7643, dr_mp3.h:470). These categories should require token boundaries / exclude comment lines.
- **W3 (doc-example & macro-def hits)**: malloc hits at dr_flac.h:28 / dr_wav.h:28 are inside `/* usage example */` doc comments; the `#define DRFLAC_MALLOC ... malloc()` lines are overridable-allocator definitions. Scanner doesn't distinguish definition/comment from real call site.
- **W4 (backlog C/C++ confusion)**: emits "pointer+length parameter pair with no span/view" on a pure-C library (dr_mp3.h:1015 etc.). std::span is C++-only advice; inapplicable to a C99/C89 codebase.
- **W5 (comprehension std hint misleading)**: reports "toolchain/std hint: -std=c89 | CMakeLists.txt:35" as the std, but that flag is gated behind the OFF-by-default `DR_LIBS_FORCE_C89` option (CMakeLists:7,32). The default build sets no std at all. Reporting it unqualified would misdirect a reviewer.
- **W6 (unbudgeted output volume)**: comprehension dumped 300+ exported-symbol lines and backlog ~250 fuzz-coverage lines with no cap/dedup — signal buried in repetition for a 27k-LOC repo.

## Negative evidence preserved

- risk-scan "casts requiring review" = no matches, "threading primitives" = no matches — both correct; this is a single-threaded lib with disciplined casting. Gate did NOT fabricate hits in empty categories.
- The vsprintf hit (W-adjacent) is a genuine flag and correctly surfaced; on inspection it is bounded and test-only, not a live vuln.
- comprehension correctly identified the real fuzz entry point (flac_fuzz.c:57) and correctly flagged absent compile_commands.json.

## Verdict

PARTIAL. Gates ran clean (all exit 0, no crashes) and the comprehension/entry-point detection is accurate, but the headline domain-detect missed an obvious parser/codec domain, and risk-scan + backlog are heavy with word-grep false positives (W2/W3) and C/C++-mismatched advice (W4) that a reviewer must manually discard. Useful as triage scaffolding, not as a finished risk list.
