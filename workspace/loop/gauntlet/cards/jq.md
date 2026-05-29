# jq — c-cpp-profi READ-ONLY gauntlet card

- **Repo:** jqlang/jq @ `df924eae91af10cc236a907cdadd97813827aa1f` (shallow, 2026-05-29)
- **Expected pack:** Parser or Compilers/VM
- **Size:** 26 `.c` + 21 `.h` + 2 `.cpp` (both test-only fuzzers); autotools; canonical `src/` (jv value core + jv_parse JSON parser + lexer/parser Flex/Bison frontend + compile/bytecode/execute VM + builtin/linker), public API in `src/jq.h`/`src/jv.h`

## Gate results
- **domain-detect (exit 0):** PRIMARY = **Parser / text-format / serialization** | `src/builtin.c:1980` (972 code matches). SECONDARY = Compilers/VMs (56, `bytecode.c:149`), Compression/codec (2, `jv.c:557`), Generic library (898). Decisive margin (972 vs 56); correct pack — jq is both a JSON serializer and a jq-language compiler/VM, and the gate ranks Parser primary with Compilers/VM secondary, exactly the expected dual signal.
- **comprehension (exit 0):** build=autotools; `compile_commands.json` absent (noted, L2 index-blind). lang `.c=26 .h=21 .cpp=2 .cc/.cxx=0`. **Exported API fully surfaced** (40 shown +229 capped): `jq_compile`/`jq_parse`/`jq_compile_args`, full `jv_*` value API (`jv_array`/`jv_mem_alloc`/...), `yyparse`/`yy_create_buffer` (Bison/Flex), `block_*` compiler API, `bytecode_*`, `load_program`. Entries: 7 `LLVMFuzzerTestOneInput` harnesses correctly tagged as fuzz entries, `main()` at `main.c:289`. Module map: `src/` (42), `tests/` (7).
- **risk-scan (clean, exit 0):** top hits with triage —
  - `compile.c:378-388` 4× `strcpy(matchname/tname,...)` — **SAFE**: `matchname` = `jv_mem_alloc(matchlen+2+1)`, `tname` = `alloc(strlen(symbol)+matchlen+1)` — both sized exactly to the copy (W3 "is the alloc sized?" → yes). Idiomatic.
  - `jv_dtoa.c:1656` `strcpy((char*)decimalpoint_cache, s0)` — **SAFE**: cache alloc'd `strlen(s0)+1` two lines up (David Gay dtoa, vendored numeric code).
  - `builtin.c:779` `(const unsigned char*)jv_string_value(input)` — **REAL cast, safe**: value-returning call cast to byte view; correctly flagged (not an R7 decl-param/sizeof FP).
  - `jv_dtoa.c:3431-3432` `(Bigint*)((int*)s-1)` / `*(int*)b` — **REAL** pointer-arithmetic casts (Bigint header trick); genuine aliasing surface, idiomatic to dtoa.
  - memcpy/memmove cluster (`jv.c`, `jv_print.c`, `exec_stack.h`) — **bounded**, all length-checked against jv string/array lengths.
  - process/shell-exec, new/delete: **no matches** (correct — pure-C, C++ signal suppressed).
- **backlog (exit 0):** hardening (3 malloc-with-multiply overflow candidates `jv.c:332/371/452`; 5 strcpy migration candidates); portability (CI covers 3 compilers/10 arches, one std exercised; ~17 `time_t`/Y2038 sites); api-ergonomics relabeled for C (ptr+len ownership doc, not span — W2 held); test-fuzz-coverage flags ~30 parser/decoder entries (see NEW).

## REGRESSION CHECK (iter-15/16)
- **domainCorrect = yes.** Parser primary with 972-vs-56 margin; Compilers/VM correctly secondary; the new Compression pack fired only as a 2-match secondary (R9-vocab pack present and did NOT over-fire to primary on a JSON tool). Expected pack hit cleanly.
- **fixesHeld = mostly.**
  - F1/R2 comment+string strip **HELD**: every risk hit is live code; no prose/string-literal FPs across a 530-line risk dump.
  - R1 C++ suppression **HELD strongly** (the iter-15/16 win): 2 `.cpp` files (`tests/jq_fuzz_execute.cpp`, `tests/jq_fuzz_fixed.cpp`) are test-only → `C++ signal: no (pure-C)` printed; new/delete category suppressed. No wren-style `.hpp`-shim re-arm.
  - R3/F7 test exclusion **HELD**: all 7 shipped fuzzers + `tests/` kept out of risk-scan scope; their `main`/`LLVMFuzzer` entries appear only in the comprehension map.
  - R7 cast lane **HELD**: `(sizeof(jvp_invalid))`/`malloc(sizeof(decContext))` (jv.c:154/511/833) NOT flagged as casts; only real value-applied casts reported.
  - F5/R4 exported-API **HELD strongly**: macro/paren idioms and Bison/Flex `yy*` decls surfaced; public `jq_*`/`jv_*` not buried.
  - N-cmphang / F2 brittleness **HELD**: autotools `-std` hint did not abort the gate (exit 0).
  - **R8 PARTIAL soft-spot:** `parser.c:87` `reinterpret_cast<Type>(Val)` (generated Bison boilerplate inside a `#ifdef __cplusplus` **dead branch** for jq's C build) leaked into the cast lane — a C++ token in unreachable code reported as a cast. Benign (1 line, no C++ category fired), but it is the R8-class "C++ token in C context" residual.

## NEW weakness
- **N-fuzzmap (new, R6 family but distinct manifestation):** backlog `test-fuzz-coverage` flags the public JSON parser entry — `jv_parse.c:729`, `jq_parser.h:6` (`jq_parse`), `jv.c:1360` (`jv_parse`) — as "parser/decoder entry point with no fuzz harness referencing it", yet jq ships **7 LLVMFuzzer harnesses** and `tests/jq_fuzz_parse.c:14` calls `jv_parse()` **directly** (filename literally `jq_fuzz_parse`). The mapping fails because (a) harnesses live in `tests/`, excluded from backlog scope, so the cross-reference set is empty, and (b) it keys on the flagged entry's own symbol, never resolving that the shipped harness exercises that exact public API. R6 noted "blind to shipped libFuzzer harnesses"; jq is the cleanest reproduction — the harness name matches the flagged function. Fix: when computing fuzz coverage, parse harness bodies in `tests/` (without re-scoping them as library code) and credit the public entries they call. file: `tests/jq_fuzz_parse.c:14` ↔ `src/jv.c:1360`.

## Negative evidence (preserved)
- No comment/prose/string-literal risk FPs. No C++ new/delete category fired (correctly — signal suppressed on the 2 test `.cpp`). No `runners/`-style harness leak into risk-scan. domain-detect did not misclassify off an incidental token; Compression secondary stayed at 2 matches (no over-fire). Cast lane raised zero sizeof/decl-param R7 FPs. The strcpy cluster, though flagged, is genuinely bounded — a correct "review, then dismiss" surfacing, not noise. Exported API not buried behind macros.

## Verdict: **PRODUCTIVE**
Canonical parser+VM; gates classified (Parser primary / Compilers-VM secondary — expected pack), mapped the full `jq_*`/`jv_*`/`yy*` API, and triaged cleanly at exit 0. iter-15/16 fixes held across comment-strip / R1 C++-suppression / test-exclusion / cast-lane / exported-API. Two residuals: R8-class dead-branch `reinterpret_cast` in generated Bison (benign), and N-fuzzmap (R6 family) — jq is the sharpest example of the fuzz-coverage lane mis-flagging an entry that a shipped, same-named harness fuzzes directly.
