# duktape — gauntlet card

- **Repo:** svaarala/duktape @ `50af773b1b32067170786c2b7c661705ec7425d4` (shallow clone OK)
- **Expected pack:** Compilers / interpreters / VMs
- **Detected pack:** Crypto (primary) — **MISMATCH** (Compilers landed only as top secondary)
- **Size:** .c=479, .h=59, .cpp=1 (one `cpp_exceptions.cpp` example); pure-C JS engine. Core in `src-input/`.
- **Run:** read-only gates, no build. cwd = /tmp/cpp-gauntlet/duktape

## Gate results
- **domain-detect (primary):** `Crypto | Makefile:894 (90 code matches)` — WRONG. Compilers/VMs
  is secondary (`Makefile:833`, 71). Other secondaries: Networking 32, Parser 32, Compression 11,
  Generic 162 (de-prioritized, did not win). The true domain is unmistakable: 469 Compilers-token
  hits in shipped C — `duk_js_compiler.c` (287KB), `duk_js_executor.c` (174KB), `duk_lexer.c`,
  `duk_js_bytecode.h`, `duk_regexp_compiler.c`, `duk_api_bytecode.c`. The Crypto win is pure noise
  (see NEW weakness #1).
- **comprehension-map (exit 0):** build=make; lang breakdown .c=479/.cpp=1 (correctly reads C);
  std hints `-std=c99` + one `-std=c++11`. Exported API surfaced from public headers:
  `duk_js_compile()` :227, `duk_compile_file()`, `duk_cbor_decode()`, `duk_bd_decode()`,
  `duk_hbuffer_alloc()`, `duk_debug_add_breakpoint()` — R4 held (the `DUK_EXTERNAL`/`duk_*`
  surface came through). L2 entries: every `main()` correctly fenced to examples/misc/tests/
  runtests (not core). Module map: src-input(156), tests(293), examples(34), extras(28), misc(23).
- **risk-scan (2078 hits, exit 0 — F4 held):** casts 2066, unsafe-str 7, unchecked-mem 3, alloc 2.
  C++ new/delete category **correctly suppressed**: `[scope] C++ signal: no … suppressed (pure-C)`.
  - `duk_util_hashbytes.c:27` `*((const duk_uint32_t *)(const void *)data)` — REAL: deliberate
    unaligned 32-bit read, guarded by `#if DUK_USE_HASHBYTES_UNALIGNED_U32_ACCESS` (the byte-wise
    `#else` is the safe path). The one genuinely interesting cast — buried among 2065 idioms.
  - `duk_api_bytecode.c:91` `(duk_hobject *)func` — benign tagged-value downcast; safe-by-design.
  - `dukweb/dukweb.c:37` `sprintf(p, ...)` — REAL but in the Emscripten web-demo wrapper, not the
    engine; core uses `DUK_SNPRINTF`/`duk_*` wrappers (no raw sprintf/malloc in `src-input/*.c`).
- **backlog (423 items):** test-fuzz-coverage 402, hardening 10, portability 9, api-ergonomics 2.
  api-ergonomics uses the **W2-fixed C label** ("document the ptr+len ownership/bounds contract"),
  not a C++ span proposal — correct. Portability detected `.github/workflows/build-workflow.yaml`
  CI matrix (R6/F6 workflow-awareness held) and time_t/Y2038 in `duk_bi_date_unix.c`.

## REGRESSION CHECK (iter-15/16 fixes)
- **domainCorrect = no.** Primary is Crypto, not the expected Compilers/VMs (which is the top
  secondary — defensible-adjacent but not correct). New Compression pack DID appear (secondary, 11)
  but did not misfire as primary. The mis-pick is the headline finding of this run.
- **fixesHeld = mostly.** Evidence:
  - F1/R1 (C++ cats on pure-C): **HELD** — new/delete suppressed; `.cpp`=1 example did not trip C++ signal.
  - F4 (risk-scan exit 0): **HELD.**
  - R2 (comment/string strip): **HELD for C** — spot-read risk hits all real code, no prose FP.
  - R4 (macro-exported API): **HELD** — `duk_*` public surface surfaced.
  - R7 (cast prototype/sizeof FP): **HELD** — no single-pointer-decl or `sizeof(T*)` FP found; the
    lone `(T*)$`-trailing hit (`duk_js_compiler.c:1730`) is a real multi-line cast with a value.
  - W2 (api-ergonomics C label): **HELD.**
  - **R8/R9-vocab (case-sensitive distinctive tokens + pack vocabulary): DID NOT HOLD** — see #1.
  - **R6 (fuzz-harness awareness): DID NOT HOLD** — see #2.

## NEW weaknesses
1. **Crypto pack's broad single-word tokens win PRIMARY off non-code / non-C noise** (NOT R8 case-
   folding, NOT R9 missing-vocab — this is *over*-broad vocab matching outside C). The 90 Crypto
   matches are dominated by: `src-input/UnicodeData.txt` "CYRILLIC/ARMENIAN … LETTER SHA" (73 hits
   of `\bsha\b` in a Unicode data table) and `Makefile:894 @# SHA1: 774be8…` (a build-checksum
   comment). `\bsha\b|\bmd5\b|\bdigest\b|\bnonce\b|\bhmac\b` match prose/data, and "all" mode scans
   `.txt`/Makefile where the C-style comment-strip is a no-op (Makefile `#` not stripped). A pure-C
   JS engine with zero crypto code is classified Crypto. Fix: drop single-word `sha`/`md5`/`digest`/
   `nonce` to needing a crypto-API context, exclude `*.txt` data files from pack counting, and
   strip `#`-style comments in non-C build/data files.
2. **R6 regressed: backlog blind to Fuzzilli + over-matches internal `DUK_LOCAL` decoders.** 402
   `test-fuzz-coverage` hits claim "parser/decoder entry with no fuzz harness," but duktape ships
   `config/config-options/DUK_USE_FUZZILLI.yaml` (Fuzzilli coverage-guided JS-engine fuzzing) and
   `util/makeduk_fuzz.yaml` — first-class fuzzing the lane can't see (it only knows libFuzzer
   `.c`/`cifuzz.yml`). Worse, the `(…, size_t)` heuristic flags **internal static** functions
   (`DUK_LOCAL duk__cbor_decode_string`, `duk_util_bitdecoder.c` internals) as "entry points" —
   they are not public. Fix: detect `DUK_USE_FUZZILLI`/`makeduk_fuzz`; require the entry be exported.
3. **Cast lane has no volume cap/ranking (precision, low-sev).** 2066/2078 risk hits are casts; in a
   tagged-value VM nearly every `(void*)` printf-arg and `(duk_hobject*)` downcast is flagged, so the
   one real aliasing cast (`duk_util_hashbytes.c:27`) is drowned. Fix: rank `*(T*)`/aliasing casts
   above `(void*)`-for-`%p` and same-family downcasts; cap the dump.
4. **(minor, F7-class)** `misc/` (standalone compiler-probe programs) and `dukweb/` (Emscripten web
   wrapper) are auxiliary, not the shipped engine, yet not excluded — they supply 7/7 unsafe-str and
   2/2 alloc hits. EXCLUDE_GLOBS covers tests/examples/extras but not these repo-specific aux trees.

## Negative evidence (preserved)
- No C++ new/delete/span noise (the `.cpp`=1 example did not trip the C++ signal; new/delete lane
  empty). No comment/string-literal FP in spot-read risk hits (all real code). R7 cast-prototype
  FP did NOT recur. Compression pack did not falsely win primary. comprehension counted no
  doc-comment/example `main()` as a live core entry; exited 0 with the public API surfaced.

## Verdict
**PARTIAL.** Gates run clean (comprehension + risk exit 0; C++ correctly suppressed; R1/R2/R4/R7/W2
held), but **domain classification is wrong**: Crypto stole PRIMARY from the obvious Compilers/VM
domain purely on a Unicode data-table's "LETTER SHA" rows and a Makefile checksum comment (NEW #1) —
a fresh failure mode beyond R8/R9. R6 also regressed: 402 false "no fuzz harness" hits despite shipped
Fuzzilli support, many on internal statics (NEW #2). Findings #1 and #2 are the actionable fold-backs.
