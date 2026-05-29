# pcre2 — c-cpp-profi gauntlet card

- repo: PCRE2Project/pcre2 @ `ff92e0b9cea5b5ae3af12ba930d03556684f098b`
- expected pack: Parser / regex  |  detected primary: **Compilers / interpreters / VMs** (Parser secondary)
- size: 19M, 56 C/H TUs (42 `.c`, 14 `.h`), **zero C++ TUs** (no `.cpp`/`.cc`/`.cxx` anywhere) — pure C
- gates run READ-ONLY (no build); all four exit 0

## Gate results
- **domain-detect** primary `Compilers / interpreters / VMs` (157 code matches, anchor `pcre2_dfa_match.c:3691`
  `match_data->matchedby = PCRE2_MATCHEDBY_DFA_INTERPRETER;` — real code). Secondary: Parser/text-format (41,
  anchor `pcre2_compile.c:10761` `parse_regex(...)`), Generic-library (262), Filesystems (6), **Space/satellites (5)**.
- **comprehension** build=autotools+bazel+cmake; no compile_commands; lang .c=42/.h=14/.cpp=0. L2 exported-API block:
  33 `pcre2_*` entries but **all internal `_pcre2_*` (from `pcre2_internal.h`/`pcre2_compile.h`) or POSIX-shim
  (`pcre2_regcomp/regexec/regerror/regfree`)** + noise (`fprintf`/`cfprintf`/`if` from `*_inc.h` template fragments).
  Entry points: 4 `LLVMFuzzerTestOneInput` (shipped fuzzer recognized), 11 `main()` (incl. cmake-test fixtures, demo).
- **risk-scan** scope line correct ("C++ signal: no … pure-C"); new/delete category **suppressed**. Hits: unsafe-string
  (sprintf/strcat/strcpy), large alloc lane (mostly `memctl.malloc/free` — the library's pluggable allocator), memcpy/
  memmove lane (heavy, `CU2BYTES`-sized — bytecode buffer copies), cast lane, 1 `execv` (pcre2grep), assert lane.
- **backlog** api-ergonomics (ptr+len → "document contract", correct C relabel), hardening (no FORTIFY/CFI/stack-prot
  in build; `malloc` w/ multiply → overflow-guard candidates), portability (CI matrix 8 compilers/10 arches detected),
  test-fuzz-coverage (parser entry points w/o harness ref).

## Risk-scan top hits WITH triage
- `pcre2grep.c:633` `sprintf(val_buf,"%d",rc)` — **bounded** (int→fixed buf, VMS branch); low. FP-ish for "unsafe".
- `pcre2_context.c:55` `return malloc(size)` — **intentional** `default_malloc` (the pluggable allocator default); benign.
- `pcre2_compile.c:1138/1173` `code->memctl.malloc(...)` — library memctl indirection, sized from `blocksize`; benign.
- `pcre2_substring.c:407` `(PCRE2_SIZE *)((char *)listp + sizeof(...)*(count+1))` — **genuine** cast worth a bounds note.
- `pcre2_substitute.c:553/568` `memmove(... CU2BYTES(rest_len))` — real bytecode/output moves; the substitute path is
  the historically CVE-prone area — worth a manual bounds pass (legit, not a tool FP).

## REGRESSION CHECK
- **domainCorrect: partial.** Primary is Compilers/VMs, expected Parser/regex. This is **defensible, not a miss**:
  PCRE2 compiles patterns to bytecode and ships a real JIT (`pcre2_jit_compile.c`) + DFA interpreter, so it genuinely
  straddles both packs — Parser is correctly the secondary. This is exactly the F8 compiler-vs-parser overlap signal.
- **fixesHeld: mostly.** R1 held (C++ new/delete **suppressed**, "C++ signal: no" on this pure-C repo — the headline
  regression-guard works). F4 held (all gates exit 0). F1 held (no obvious comment/prose substring FPs in risk-scan
  top hits; `opcode`/`stack`/`interpreter` driving the Compilers pack are **real domain terms** here, not prose). F5
  partial (shipped fuzzer + .github CI matrix recognized). **R7 did NOT land** (still open per findings): cast lane FPs
  `pcre2_internal.h:2333/2344` (`extern size_t _pcre2_jit_get_size(void *)` — a **prototype**, not a cast),
  `pcre2_pattern_info.c:95` `return sizeof(const uint8_t *)` (sizeof, not cast), `pcre2posix.h:163` (prototype) —
  ~4/5 spot-checked cast hits are FPs. R4 did NOT land (see NEW-1).

## NEW weaknesses (not in F1-F7 / R1-R7)
- **NEW-1 (header-extension / generated-header blindness):** the canonical public header `pcre2.h` is **absent** — it is
  generated from `src/pcre2.h.in`, with `src/pcre2.h.generic` as the prebuilt fallback. Both carry non-`.h` extensions
  (`.in`, `.generic`), so comprehension's `*.h`/`*.hpp` glob skips them, and the **entire flagship API
  (`pcre2_compile`, `pcre2_match`, `pcre2_dfa_match`, `pcre2_substitute`, `pcre2_jit_compile`) is invisible** — L2
  backfills with `_pcre2_*` internals. Compounded by R4 (decls are `PCRE2_EXP_DECL … PCRE2_CALL_CONVENTION \` with the
  name on the **next line** via `\` continuation — `pcre2.h.in:687-692`). Fix: also scan `*.h.in`/`*.h.generic`
  (and reconstruct multi-line `\`-continued macro-wrapped decls). Distinct from R4's single-line macro idioms.
- **NEW-2 (`_inc.h` test-harness body in scope):** `src/pcre2test_inc.h` (202 KB) is the **body of the test driver**,
  `#include`d only by `src/pcre2test.c`; it dominates risk-scan (strcpy@3651/3735, dozens of malloc/memcpy) and backlog
  (9 of 10 api-ergonomics "owning malloc in a header" + 6 hardening rows). Suffix-name exclusion (R3) catches
  `*_test.*`/`*test*.c*` but **not `*test_inc.h`** (the `_inc.h` convention for an included source fragment that *is* a
  test). Fix: exclude `*test*inc.h` / treat `_inc.h` as the TU it is included into. (`pcre2demo.c`, a doc example, also
  leaks into entry points.)
- **NEW-3 (Unicode data tables drive a spurious SPACE secondary):** Space/satellites fired (5 matches) anchored on
  `maint/Unicode.tables/DerivedBidiClass.txt:1554` ("ARABIC POETIC VERSE SIGN…") — generator **input data**, not shipped
  C. domain-detect excludes `tests/` but not `maint/*.tables/*.txt`. Same root as F7 (non-shipped artifacts mixed in);
  NEW angle = a **non-source data dir under `maint/`** feeding a false domain pack. (Note: SPACE here is a FP, the
  opposite of the fprime/cFE case where it should fire.)

## Negative evidence (preserved)
- No threading primitives matched (correct — PCRE2 is single-threaded per call).
- No std:: / span / new[] fired (correct C suppression).
- CI matrix + shipped fuzz harness correctly recognized (F3/F6 hold).
- ptr+len lane correctly relabeled "document contract" for C (W2 hold) rather than proposing C++ span.

## Verdict: PRODUCTIVE
Breadth surfaced 3 distinct NEW weaknesses (generated-header blindness, `_inc.h` test-body scope leak, `maint/` data-
table domain pollution) and confirmed R7 + R4 are still open on a high-profile target. The headline regression guard
(C++ suppression on pure-C) and exit-0 held. domainCorrect = partial-but-defensible (Compilers primary / Parser
secondary is a fair regex-engine classification).
