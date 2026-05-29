# chibicc — gauntlet card

- Repo: rui314/chibicc @ `90d1f7f` ("Make struct member access to work with `=` and `?:`")
- Expected pack: Compilers / interpreters / VMs
- Detected primary: **Parser / text-format / serialization** (Compilers fired as secondary)
- Size: pure C, ~11.3k LOC across 10 shipped .c + 1 public header (chibicc.h); test/ holds 46 fixtures. `-std=c11`, Makefile build, no compile_commands.json, no CI matrix.
- Run: all 4 read-only gates EXIT=0.

## Gate results

**domain-detect** — ranked, 4 packs:
- primary: Parser / text-format / serialization (22 code matches, chibicc.h:104)
- secondary: Generic library / data-structures (30), Compilers/interpreters/VMs (3, chibicc.h:411), Embedded/real-time (3).
- Tests/ correctly excluded from the signal; ranking-by-match-count works.

**comprehension** — exported API surfaced cleanly (F5 fix holds): 50 non-static decls from chibicc.h listed incl. `tokenize()`, `parse()`, `codegen()`, `preprocess()`, `add_type()`, `hashmap_*`, `encode/decode_utf8()`. Entry points = 41 `main()` in test fixtures + the public header flagged as API surface. Module map: root(10)/include(7)/test(46). No doc-comment or `#ifdef _MAIN` false entries.

**risk-scan** — scope line correct ("shipped library code only"); C++ signal = no, so new/delete category suppressed (F1 holds). Hits, all triaged real-code (no comment/prose FPs):
- `preprocess.c:481` `strncpy(buf+pos, t->loc, t->len)` — REAL. `buf=calloc(1,len)` at :474 where `len` sums token lens + inter-token spaces; `buf[pos]='\0'` at :484. Bounded by the compiler's own token stream; potential 1-byte tightness on the trailing NUL but not attacker-reachable. Verdict: low, by-design.
- `main.c:402` `execvp(argv[0], argv)` — REAL, inside forked child invoking `as`/`ld`; args from internal argv build. Verdict: expected for a compiler driver, not a shell-injection.
- `codegen.c:1544` `assert(ty->size <= 16)` — assert-only validation; fine in a compiler invariant, but disabled under NDEBUG. Verdict: low.
- ~40 `calloc(1, sizeof(T))` arena-style allocs — idiomatic, none freed (compiler never frees; process-lifetime arena). Verdict: noise, correctly listed without alarm.

**backlog** — sample: api-ergonomics ptr+len (C-relabeled, F2 holds, 20 hits); hardening: no FORTIFY/CFI/stack-protector/sanitizer in build (true — bare Makefile); calloc-with-multiply overflow candidates (main.c:415, parse.c:271/283); portability: no CI matrix, single std, `time_t` width at preprocess.c:1109 (real — `__DATE__`/`__TIME__` macro uses `localtime`).

## REGRESSION CHECK

- **domainCorrect = partial.** Compilers/VMs pack DID fire and is ranked (3 matches, chibicc.h:411 `codegen`), but landed as *secondary* under Parser (primary, 22 matches). Defensible — a compiler front end is overwhelmingly lex/parse code, and chibicc's public surface is dominated by tokenize/parse signals — but the canonical answer for "a C compiler" should arguably top-rank Compilers. The compiler-pack signal set is too thin (only `codegen`/`emit`-class tokens); it does not credit `parse()`/`tokenize()`/AST/`Node`/`Type`/codegen-per-target as compiler evidence, so a compiler reads as a parser. NEW finding F8 below.
- **fixesHeld = yes.** F1: C++ new/delete category explicitly suppressed ("pure-C repo"), zero comment/string FPs across spot-reads (strncpy@481, execvp@402, assert@1544 all real calls). F4: risk-scan EXIT=0. F5: full exported C API surfaced from chibicc.h, no doc-comment/`_MAIN` entries. F7: test/ (46 files) excluded from shipped-code scope. F2: ptr+len lane C-relabeled, no C++ span noise.

## NEW weaknesses

- **F8 (new):** domain-detect cannot distinguish a *compiler* from a generic *parser*. The Compilers/VMs pack lacks front-end signals (AST/`Node`/`Type`, `tokenize`/`parse`/`codegen`, per-arch emit, register alloc), so a textbook C compiler ranks Parser-primary with Compilers a weak secondary. Fix: enrich the Compilers pack token set and let compiler-specific tokens outweigh generic parse tokens.
- Minor: `chibicc.h:103 new_file(char *name, int file_no, char *contents)` flagged as a ptr+len pair, but it is name/file_no/contents — not a buffer+length. ptr+len heuristic over-matches any `(T* , int)` adjacency. (Low; subsumed by F2's "noise" nature, not a regression.)

## Negative evidence (preserved)

- No threading primitives (correct — chibicc is single-threaded). No C++ constructs found (correct — pure C). No third_party/vendor dirs. Backlog hardening flags are all TRUE (bare Makefile genuinely has no FORTIFY/sanitizer/stack-protector). No false "uncovered fuzz harness" flag (none shipped).

## Verdict: PRODUCTIVE

All gates ran clean; F1/F4/F5/F7/F2 fixes held with evidence; surfaced one new, real classification gap (F8: compiler-vs-parser) and confirmed risk-scan is FP-clean on a 11k-LOC pure-C compiler.
